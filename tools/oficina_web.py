"""Serve the standalone CTM map workshop using only Python's standard library."""
from __future__ import annotations

import json
import os
import shutil
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import oficina_ctm as model


class OficinaHandler(SimpleHTTPRequestHandler):
    project_root = Path(__file__).resolve().parents[1]
    web_root = Path(__file__).resolve().parent / "oficina_web"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.web_root), **kwargs)

    def log_message(self, _format, *_args):
        return

    def end_headers(self):
        self.send_header("Content-Security-Policy", "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        super().end_headers()

    def do_GET(self):
        request = urlparse(self.path)
        if request.path == "/api/status":
            self._json({"ok": True, "project": self.project_root.name})
            return
        if request.path == "/api/floor":
            values = parse_qs(request.query)
            try:
                floor = max(1, min(200, int(values.get("id", ["1"])[0])))
            except ValueError:
                floor = 1
            self._json(self._load_floor(floor))
            return
        super().do_GET()

    def do_POST(self):
        origin = self.headers.get("Origin")
        if origin and origin != f"http://{self.headers.get('Host', '')}":
            # Drain the request body before replying so the client receives
            # the HTTP 403 response instead of a TCP reset on Windows.
            try:
                length = min(int(self.headers.get("Content-Length", "0")), 5_000_000)
                if length > 0:
                    self.rfile.read(length)
            except OSError:
                pass
            self._json({"ok": False, "error": "Pedido externo recusado."}, 403)
            return
        request = urlparse(self.path)
        payload = self._read_json()
        if payload is None:
            return
        if request.path == "/api/validate":
            data = payload.get("map", {})
            errors = model.validate_map(data)
            self._json({"ok": not errors, "errors": errors})
        elif request.path == "/api/save":
            self._save_map(payload.get("map", {}))
        elif request.path == "/api/disable":
            try:
                floor = max(1, min(200, int(payload.get("floor", 1))))
                target = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
                if not target.is_file():
                    self._json({"ok": False, "error": f"A fase {floor:03d} não tem um mapa externo ativo."}, 404)
                    return
                disabled = target.with_name(target.name + ".disabled")
                index = 1
                while disabled.exists():
                    disabled = target.with_name(target.name + f".disabled.{index}")
                    index += 1
                target.rename(disabled)
                self._json({"ok": True, "path": str(disabled), "message": f"O mapa externo da fase {floor:03d} foi desligado. A cópia ficou guardada."})
            except (OSError, TypeError, ValueError) as exc:
                self._json({"ok": False, "error": f"Não consegui desligar esta fase: {exc}"}, 400)
        elif request.path == "/api/blueprint":
            try:
                floor = max(1, min(200, int(payload.get("floor", 1))))
                source = self.project_root / "levels" / "authored" / f"floor_{floor:03d}_workshop.tscn"
                if not source.is_file():
                    self._json({"ok": False, "error": f"A fase {floor:03d} ainda não tem blueprint para importar."}, 404)
                    return
                self._json({"ok": True, "map": model.import_godot_scene(source), "source": source.name})
            except Exception as exc:
                self._json({"ok": False, "error": str(exc)}, 400)
        elif request.path == "/api/open-json":
            try:
                data = payload.get("map", {})
                errors = model.validate_map(data)
                if errors:
                    self._json({"ok": False, "errors": errors}, 400)
                else:
                    self._json({"ok": True, "map": data})
            except Exception as exc:
                self._json({"ok": False, "error": str(exc)}, 400)
        else:
            self._json({"ok": False, "error": "Ação desconhecida."}, 404)

    def _read_json(self):
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 5_000_000)
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
            self._json({"ok": False, "error": "Não consegui ler estes dados."}, 400)
            return None

    def _json(self, value, status=200):
        content = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def _load_floor(self, floor):
        external = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
        blueprint = self.project_root / "levels" / "authored" / f"floor_{floor:03d}_workshop.tscn"
        if external.is_file():
            try:
                data = json.loads(external.read_text(encoding="utf-8"))
                errors = model.validate_map(data)
                if not errors:
                    return {"ok": True, "map": data, "source": "mapa da Oficina", "saved": True}
                return {"ok": False, "error": "O mapa existente precisa de correção: " + " ".join(errors[:4])}
            except (OSError, json.JSONDecodeError) as exc:
                return {"ok": False, "error": f"Não consegui abrir o mapa: {exc}"}
        if blueprint.is_file():
            try:
                return {"ok": True, "map": model.import_godot_scene(blueprint), "source": "blueprint importado", "saved": False}
            except Exception as exc:
                return {"ok": False, "error": f"Não consegui importar o blueprint: {exc}"}
        return {"ok": True, "map": model.blank_map(floor), "source": "mapa novo", "saved": False}

    def _save_map(self, data):
        try:
            errors = model.validate_map(data)
            if errors:
                self._json({"ok": False, "errors": errors}, 400)
                return
            floor = max(1, min(200, int(data.get("floor", 1))))
            data["floor"] = floor
            data["id"] = f"external_floor_{floor:03d}"
            target = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_name(target.name + ".writing")
            backup_name = None
            try:
                if target.exists():
                    backup = target.with_name(target.name + ".bak")
                    index = 1
                    while backup.exists():
                        backup = target.with_name(target.name + f".bak.{index}")
                        index += 1
                    shutil.copy2(target, backup)
                    backup_name = backup.name
                temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                os.replace(temp, target)
            finally:
                if temp.exists():
                    temp.unlink()
            self._json({"ok": True, "path": str(target), "backup": backup_name,
                        "message": f"Fase {floor:03d} guardada no jogo."})
        except (OSError, TypeError, ValueError) as exc:
            self._json({"ok": False, "error": f"Não consegui guardar: {exc}"}, 400)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), OficinaHandler)
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/"
    print("Oficina CTM pronta. Mantém esta janela aberta enquanto editas.", flush=True)
    print("A abrir no navegador: " + url, flush=True)
    threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
