import json
import sys
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import oficina_web
import oficina_ctm


class OficinaWebTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()

        class TestHandler(oficina_web.OficinaHandler):
            project_root = Path(self.temp.name)
            web_root = ROOT / "tools" / "oficina_web"

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), TestHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.temp.cleanup()

    def post(self, endpoint, payload, headers=None):
        request = Request(self.base + endpoint, data=json.dumps(payload).encode(),
                          headers={"Content-Type": "application/json", **(headers or {})})
        with urlopen(request, timeout=3) as response:
            return json.loads(response.read())

    def test_workshop_page_is_served_with_local_policy(self):
        with urlopen(self.base + "/", timeout=3) as response:
            page = response.read().decode()
            self.assertEqual(response.status, 200)
            self.assertIn("COME TO ME", page)
            self.assertIn("Content-Security-Policy", response.headers)

    def test_new_phase_loads_as_blank_map(self):
        with urlopen(self.base + "/api/floor?id=7", timeout=3) as response:
            result = json.loads(response.read())
        self.assertEqual(result["map"]["floor"], 7)
        self.assertEqual(result["source"], "mapa novo")
        self.assertEqual(oficina_ctm.validate_map(result["map"]), [])

    def test_save_writes_map_and_keeps_previous_version(self):
        data = oficina_ctm.blank_map(8)
        first = self.post("/api/save", {"map": data})
        self.assertTrue(first["ok"])
        data["name"] = "Fase revista"
        second = self.post("/api/save", {"map": data})
        target = Path(self.temp.name) / "levels" / "external_maps" / "floor_008.ctmmap.json"
        self.assertEqual(json.loads(target.read_text(encoding="utf-8"))["name"], "Fase revista")
        self.assertIsNotNone(second["backup"])
        backup = target.with_name(second["backup"])
        self.assertEqual(json.loads(backup.read_text(encoding="utf-8"))["name"], "Fase 008")

    def test_disabling_a_map_preserves_a_recoverable_copy(self):
        self.post("/api/save", {"map": oficina_ctm.blank_map(9)})
        result = self.post("/api/disable", {"floor": 9})
        active = Path(self.temp.name) / "levels" / "external_maps" / "floor_009.ctmmap.json"
        disabled = active.with_name(active.name + ".disabled")
        self.assertTrue(result["ok"])
        self.assertFalse(active.exists())
        self.assertEqual(json.loads(disabled.read_text(encoding="utf-8"))["floor"], 9)

    def test_foreign_origin_cannot_write_maps(self):
        request = Request(self.base + "/api/save", data=json.dumps({"map": oficina_ctm.blank_map()}).encode(),
                          headers={"Content-Type": "application/json", "Origin": "http://example.invalid"})
        with self.assertRaises(HTTPError) as result:
            urlopen(request, timeout=3)
        self.assertEqual(result.exception.code, 403)
        result.exception.close()


if __name__ == "__main__":
    unittest.main()
