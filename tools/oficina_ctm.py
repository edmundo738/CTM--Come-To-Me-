"""Oficina CTM: standalone, visual map editor for Come To Me."""
from __future__ import annotations

import argparse
import ast
import copy
import json
import os
import re
import shutil
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

FORMAT = "ctmmap"
VERSION = 1
ENEMIES = ["hunter", "sentry", "wisp", "rusher", "patrol", "mirror", "warden",
           "boss/pawn", "boss/rook", "boss/knight", "boss/bishop", "boss/queen", "boss/king"]
PICKUPS = ["coin", "shield", "breaker", "heart", "powerup/blink", "powerup/magnet",
           "powerup/speed", "powerup/time_freeze"]
MECHANISMS = ["crate", "pressure_plate", "gate", "power_source", "circuit_relay", "circuit_receiver"]
MECHANISM_LABELS = {"crate": "Caixa", "pressure_plate": "Placa", "gate": "Portão",
                    "power_source": "Gerador", "circuit_relay": "Relé", "circuit_receiver": "Recetor"}
MODE_LABELS = {"enemy": "Inimigo", "pickup": "Recolha", "mechanism": "Mecanismo"}
OBJECTIVE_LABELS = {"escape": "Alcançar o portal", "environment": "Abrir com mecanismos"}
ENTITY_LABELS = {"hunter": "Caçador", "sentry": "Sentinela", "wisp": "Espectro", "rusher": "Investida",
                 "patrol": "Patrulha", "mirror": "Reflexo", "warden": "Guardião", "coin": "Moeda",
                 "shield": "Escudo", "breaker": "Ruptor", "heart": "Coração", "boss/pawn": "Boss Peão",
                 "boss/rook": "Boss Torre", "boss/knight": "Boss Cavalo", "boss/bishop": "Boss Bispo",
                 "boss/queen": "Boss Dama", "boss/king": "Boss Rei", "powerup/blink": "Poder: Salto",
                 "powerup/magnet": "Poder: Íman", "powerup/speed": "Poder: Velocidade",
                 "powerup/time_freeze": "Poder: Parar tempo"}
COLORS = {"wall": "#45495d", "start": "#62e8dd", "portal": "#c784ff", "enemy": "#ff617d",
          "pickup": "#ffd86e", "crate": "#d4a36b", "pressure_plate": "#6ce6d4", "gate": "#ffb85d",
          "power_source": "#ffe16a", "circuit_relay": "#c5a0ff", "circuit_receiver": "#ff87d0"}
GLYPHS = {"crate": "C", "pressure_plate": "P", "gate": "G", "power_source": "E",
          "circuit_relay": "R", "circuit_receiver": "T"}


def blank_map(floor: int = 1, width: int = 19, height: int = 15) -> dict:
    floor = max(1, min(200, int(floor)))
    width, height = max(9, int(width)), max(9, int(height))
    return {"format": FORMAT, "version": VERSION, "floor": floor,
            "id": f"external_floor_{floor:03d}", "name": f"Fase {floor:03d}", "hint": "",
            "objective": "escape", "width": width, "height": height,
            "start": [1, 1], "portal": [width - 2, height - 2], "walls": [],
            "authoritative_spawns": True, "entity_spawns": [], "mechanisms": []}


def _cell(value):
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        try:
            return int(value[0]), int(value[1])
        except (TypeError, ValueError):
            pass
    return None


def validate_map(data: dict) -> list[str]:
    errors = []
    if data.get("format") != FORMAT or int(data.get("version", 0)) != VERSION:
        errors.append("Formato de mapa não reconhecido.")
        return errors
    width, height = int(data.get("width", 0)), int(data.get("height", 0))
    if not 5 <= width <= 160 or not 5 <= height <= 160:
        errors.append("A grelha deve ter entre 5 e 160 casas em cada lado.")
        return errors
    inside = lambda p: p is not None and 0 < p[0] < width - 1 and 0 < p[1] < height - 1
    start, portal = _cell(data.get("start")), _cell(data.get("portal"))
    if not inside(start) or not inside(portal):
        errors.append("Início e portal precisam de ficar dentro da borda.")
        return errors
    if start == portal:
        errors.append("Início e portal têm de ficar em casas diferentes.")
    walls = set()
    for raw in data.get("walls", []):
        point = _cell(raw)
        if not inside(point):
            errors.append(f"Parede fora da área jogável: {raw}.")
        elif point in walls:
            errors.append(f"Parede repetida em {point}.")
        else:
            walls.add(point)
    if start in walls or portal in walls:
        errors.append("Uma parede ocupa o início ou o portal.")
    occupied = {start: "reserved", portal: "reserved"}
    entities = data.get("entity_spawns", [])
    for entity in entities:
        point = _cell(entity.get("cell"))
        kind, subtype = entity.get("kind"), entity.get("subtype")
        allowed = ENEMIES if kind == "enemy" else PICKUPS if kind == "pickup" else []
        if subtype not in allowed:
            errors.append(f"Elemento desconhecido: {subtype}.")
        if not inside(point):
            errors.append(f"Elemento fora da área jogável: {subtype}.")
        elif point in walls or (point in occupied and not (kind == "pickup" and occupied[point] == "pickup")):
            errors.append(f"Casas sobrepostas em {point}; move um dos elementos.")
        if point is not None:
            occupied[point] = kind
    mechanisms = data.get("mechanisms", [])
    mechanism_ids = set()
    mechanisms_by_id = {}
    for item in mechanisms:
        point = _cell(item.get("cell"))
        kind, component_id = item.get("kind"), str(item.get("id", ""))
        if kind not in MECHANISMS:
            errors.append(f"Mecanismo desconhecido: {kind}.")
        if not inside(point):
            errors.append(f"Mecanismo fora da área jogável: {kind}.")
        elif point in walls or point in occupied:
            errors.append(f"Mecanismo sobreposto em {point}.")
        if not component_id or component_id in mechanism_ids:
            errors.append(f"ID de mecanismo vazio ou repetido: {component_id}.")
        mechanism_ids.add(component_id)
        mechanisms_by_id[component_id] = item
        if point is not None:
            occupied[point] = "mechanism"
    for item in mechanisms:
        for output in item.get("outputs", []):
            if output not in mechanism_ids:
                errors.append(f"Ligação sem destino: {item.get('id')} → {output}.")
                continue
            source_channel = {"crate": "pressure", "pressure_plate": "logic", "gate": "passage",
                              "power_source": "power", "circuit_relay": "power", "circuit_receiver": "logic"}.get(item.get("kind"), "")
            target_channel = {"crate": "push", "pressure_plate": "weight", "gate": "logic",
                              "power_source": "", "circuit_relay": "power", "circuit_receiver": "power"}.get(mechanisms_by_id[output].get("kind"), "")
            if source_channel != target_channel:
                errors.append(f"Ligação incompatível: {item.get('id')} não pode ligar a {output}.")
    if data.get("objective") == "environment" and not any(m.get("kind") == "pressure_plate" for m in mechanisms):
        errors.append("O objetivo de mecanismos precisa de pelo menos uma placa.")
    if not errors:
        seen = {start}
        pending = [start]
        while pending:
            x, y = pending.pop(0)
            for point in ((x, y-1), (x+1, y), (x, y+1), (x-1, y)):
                if inside(point) and point not in walls and point not in seen:
                    seen.add(point)
                    pending.append(point)
        if portal not in seen:
            errors.append("As paredes bloqueiam o caminho entre início e portal.")
    return errors


def _balanced_value(text: str, key: str) -> str | None:
    match = re.search(rf"(?m)^\s*{re.escape(key)}\s*=\s*", text)
    if not match:
        return None
    value_start = match.end()
    start = value_start
    initial_stack = []
    generic = re.match(r"Array\[[^\]]+\]\(", text[start:])
    if generic:
        open_at = start + generic.end() - 1
        initial_stack.append("(")
        start = open_at + 1
    opening = "([{"
    closing = ")] }".replace(" ", "")
    stack, quoted, escaped = initial_stack, False, False
    for index in range(start, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char in opening:
            stack.append(char)
        elif char in closing:
            if stack:
                stack.pop()
            if not stack:
                return text[value_start:index + 1].strip()
        elif char in "\r\n" and not stack:
            return text[value_start:index].strip()
    return text[value_start:].strip()


def _parse_godot_value(value: str):
    value = re.sub(r"Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", r"[\1,\2]", value)
    value = re.sub(r"Array\[[^\]]+\]\(", "(", value)
    value = re.sub(r"PackedStringArray\((.*?)\)", r"[\1]", value, flags=re.S)
    value = re.sub(r"&\"([^\"]+)\"", r"\"\1\"", value)
    value = re.sub(r"\btrue\b", "True", value, flags=re.I)
    value = re.sub(r"\bfalse\b", "False", value, flags=re.I)
    value = re.sub(r"\bnull\b", "None", value, flags=re.I)
    try:
        return ast.literal_eval(value)
    except (ValueError, SyntaxError):
        return None


def import_godot_scene(path: str | Path) -> dict:
    """Import a text Godot blueprint, keeping its authored spawns/mechanisms."""
    text = Path(path).read_text(encoding="utf-8-sig")
    resources = {rid: resource for resource, rid in re.findall(
        r'\[ext_resource[^\]]*?path="([^"]+)"[^\]]*?id="([^"]+)"', text)}
    get = lambda key, default: _parse_godot_value(_balanced_value(text, key) or "") if _balanced_value(text, key) else default
    size = get("grid_size", [19, 15])
    floor = get("campaign_floor", 1) or 1
    data = blank_map(floor, size[0], size[1])
    data["id"] = get("level_id", data["id"])
    data["name"] = get("mission_title", data["name"])
    data["hint"] = get("mission_hint", "")
    data["objective"] = get("mission_objective", "escape")
    data["seed"] = get("layout_seed", 0)
    data["start"] = get("start_cell", data["start"])
    data["portal"] = get("portal_cell", data["portal"])
    data["walls"] = get("wall_cells", []) or []
    data["authoritative_spawns"] = bool(get("authoritative_spawns", False))
    data["entity_spawns"] = get("entity_spawns", []) or []
    aliases = {"crate.tscn": "crate", "pressure_plate.tscn": "pressure_plate", "gate.tscn": "gate",
               "power_source.tscn": "power_source", "circuit_relay.tscn": "circuit_relay",
               "circuit_receiver.tscn": "circuit_receiver", "crate_component.gd": "crate",
               "pressure_plate_component.gd": "pressure_plate", "gate_component.gd": "gate",
               "power_source_component.gd": "power_source", "circuit_relay_component.gd": "circuit_relay",
               "circuit_receiver_component.gd": "circuit_receiver"}
    node_blocks = re.split(r"(?=\[node )", text)
    for block in node_blocks[1:]:
        header = block.splitlines()[0]
        refs = re.findall(r'(?:instance|script)=ExtResource\("([^"]+)"\)', header + "\n" + "\n".join(block.splitlines()[1:12]))
        kind = next((aliases.get(Path(resources.get(ref, "")).name) for ref in refs
                     if aliases.get(Path(resources.get(ref, "")).name)), None)
        if not kind:
            continue
        cell_value = _parse_godot_value(_balanced_value(block, "cell") or "")
        cell = _cell(cell_value)
        if cell is None:
            continue
        component_id = _parse_godot_value(_balanced_value(block, "component_id") or "")
        outputs = _parse_godot_value(_balanced_value(block, "output_ids") or "") or []
        item = {"kind": kind, "id": component_id or f"{kind}_{len(data['mechanisms']) + 1}",
                "cell": list(cell), "outputs": list(outputs)}
        for source, target in (("crate_material", "material"), ("required_material", "required"),
                               ("input_mode", "input_mode"), ("initially_open", "initially_open"),
                               ("active", "active")):
            value = _balanced_value(block, source)
            if value:
                parsed = _parse_godot_value(value)
                if source == "initially_open":
                    item["open"] = parsed
                else:
                    item[target] = parsed
        data["mechanisms"].append(item)
    return data


class Oficina:
    def __init__(self, root: tk.Tk, project_root: Path):
        self.root, self.project_root = root, project_root
        self.data = blank_map()
        self.tool = tk.StringVar(value="wall")
        self.mode = tk.StringVar(value="enemy")
        self.mode_label = tk.StringVar(value=MODE_LABELS["enemy"])
        self.choice = tk.StringVar(value=ENEMIES[0])
        self.choice_label = tk.StringVar(value=ENTITY_LABELS[ENEMIES[0]])
        self.status = tk.StringVar(value="Clica numa casa para a editar. A borda exterior é fixa.")
        self.undo_stack, self.redo_stack = [], []
        self.move_selection = None
        self.selected_item = None
        self.item_refs = []
        self.cell_size = 40
        self._make_ui()
        self._refresh_fields()
        self.open_campaign_floor()
        self.draw()

    def _make_ui(self):
        self.root.title("Oficina CTM — Mapas e Missões")
        self.root.geometry("1180x720")
        self.root.minsize(920, 600)
        self.root.configure(bg="#171b27")
        style = ttk.Style(self.root)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background="#171b27")
        style.configure("TLabel", background="#171b27", foreground="#e6e8f1")
        style.configure("TLabelframe", background="#171b27", foreground="#69ddd4")
        style.configure("TLabelframe.Label", background="#171b27", foreground="#69ddd4")
        style.configure("TButton", padding=6)
        style.configure("TRadiobutton", background="#171b27", foreground="#e6e8f1")
        bar = ttk.Frame(self.root, padding=(8, 7))
        bar.pack(fill="x")
        for label, command in (("Novo", self.new_map), ("Abrir fase", self.open_campaign_floor), ("Abrir mapa", self.open_map),
                               ("Importar cena Godot", self.import_scene), ("Guardar na campanha", self.save_campaign),
                               ("Desligar fase", self.disable_campaign_floor),
                               ("Guardar cópia…", self.save_copy), ("Validar", self.validate_dialog),
                               ("↶ Desfazer", self.undo), ("↷ Refazer", self.redo)):
            ttk.Button(bar, text=label, command=command).pack(side="left", padx=3)
        body = ttk.Frame(self.root)
        body.pack(fill="both", expand=True, padx=8, pady=(0, 7))
        self.side = ttk.Frame(body, width=290)
        self.side.pack(side="left", fill="y")
        self.side.pack_propagate(False)
        self.side_canvas = tk.Canvas(self.side, bg="#171b27", highlightthickness=0, width=270)
        self.side_scroll = ttk.Scrollbar(self.side, orient="vertical", command=self.side_canvas.yview)
        self.side_canvas.configure(yscrollcommand=self.side_scroll.set)
        self.side_canvas.pack(side="left", fill="both", expand=True)
        self.side_scroll.pack(side="right", fill="y")
        self.side_content = ttk.Frame(self.side_canvas, padding=10)
        self.side_window = self.side_canvas.create_window((0, 0), window=self.side_content, anchor="nw")
        self.side_content.bind("<Configure>", self._sidebar_content_changed)
        self.side_canvas.bind("<Configure>", self._sidebar_resized)
        self.side_canvas.bind("<MouseWheel>", lambda e: self.side_canvas.yview_scroll(-1 if e.delta > 0 else 1, "units"))
        self.canvas_frame = ttk.Frame(body)
        self.canvas_frame.pack(side="left", fill="both", expand=True)
        self.canvas = tk.Canvas(self.canvas_frame, bg="#111725", highlightthickness=0)
        sx = ttk.Scrollbar(self.canvas_frame, orient="horizontal", command=self.canvas.xview)
        sy = ttk.Scrollbar(self.canvas_frame, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(xscrollcommand=sx.set, yscrollcommand=sy.set)
        self.canvas.grid(row=0, column=0, sticky="nsew")
        sy.grid(row=0, column=1, sticky="ns")
        sx.grid(row=1, column=0, sticky="ew")
        self.canvas_frame.rowconfigure(0, weight=1)
        self.canvas_frame.columnconfigure(0, weight=1)
        self.canvas.bind("<Button-1>", self.click_map)
        self.canvas.bind("<Configure>", lambda _e: self.draw())
        self.canvas.bind("<MouseWheel>", self.zoom)
        self.canvas.bind("<ButtonPress-2>", self.pan_start)
        self.canvas.bind("<B2-Motion>", self.pan_move)
        self.root.bind("<Control-s>", lambda _e: self.save_campaign())
        self.root.bind("<Control-z>", lambda _e: self.undo())
        self.root.bind("<Control-y>", lambda _e: self.redo())
        self.root.bind("<Control-o>", lambda _e: self.open_map())
        self._build_sidebar()
        self._bind_sidebar_wheel(self.side_content)
        ttk.Label(self.root, textvariable=self.status, anchor="w", padding=(10, 5)).pack(fill="x")

    def _build_sidebar(self):
        ttk.Label(self.side_content, text="OFICINA CTM", font=("Segoe UI", 17, "bold"), foreground="#69ddd4").pack(anchor="w")
        ttk.Label(self.side_content, text="Editor independente de mapas", foreground="#aeb7ca").pack(anchor="w", pady=(0, 8))
        info = ttk.LabelFrame(self.side_content, text="Fase", padding=8)
        info.pack(fill="x", pady=5)
        self.floor_var = tk.IntVar(value=1)
        self.name_var = tk.StringVar()
        self.hint_var = tk.StringVar()
        self.width_var, self.height_var = tk.IntVar(value=19), tk.IntVar(value=15)
        self.objective_var = tk.StringVar(value="escape")
        self.objective_label = tk.StringVar(value=OBJECTIVE_LABELS["escape"])
        self.authoritative_var = tk.BooleanVar(value=True)
        self._entry_row(info, "Número", self.floor_var, row=0, spin=(1, 200))
        self._entry_row(info, "Nome", self.name_var, row=1)
        self._entry_row(info, "Pista", self.hint_var, row=2)
        ttk.Label(info, text="Grelha").grid(row=3, column=0, sticky="w", pady=2)
        size_row = ttk.Frame(info)
        size_row.grid(row=3, column=1, sticky="ew")
        ttk.Spinbox(size_row, textvariable=self.width_var, from_=5, to=160, width=5).pack(side="left", fill="x", expand=True)
        ttk.Label(size_row, text="×").pack(side="left", padx=4)
        ttk.Spinbox(size_row, textvariable=self.height_var, from_=5, to=160, width=5).pack(side="left", fill="x", expand=True)
        ttk.Button(info, text="Aplicar tamanho", command=self.resize_map).grid(row=4, column=0, columnspan=2, sticky="ew", pady=4)
        ttk.Label(info, text="Objetivo").grid(row=5, column=0, sticky="w")
        objective_box = ttk.Combobox(info, textvariable=self.objective_label, values=tuple(OBJECTIVE_LABELS.values()), state="readonly", width=22)
        objective_box.grid(row=5, column=1, sticky="ew")
        objective_box.bind("<<ComboboxSelected>>", self._objective_changed)
        ttk.Label(info, text="escape = portal · environment = mecanismo", foreground="#aeb7ca", wraplength=240).grid(row=6, column=0, columnspan=2, sticky="w", pady=3)
        ttk.Checkbutton(info, text="Usar só o que coloquei", variable=self.authoritative_var, command=self.commit_fields).grid(row=7, column=0, columnspan=2, sticky="w")
        palette = ttk.LabelFrame(self.side_content, text="Ferramentas", padding=8)
        palette.pack(fill="x", pady=5)
        tools = [("Parede", "wall"), ("Chão", "floor"), ("Início", "start"), ("Portal", "portal"),
                 ("Colocar", "place"), ("Mover", "move"), ("Ligar mecanismo", "link"), ("Apagar", "erase")]
        for i, (label, value) in enumerate(tools):
            ttk.Radiobutton(palette, text=label, value=value, variable=self.tool, command=self._tool_changed).grid(row=i//2, column=i%2, sticky="w", padx=2, pady=2)
        ttk.Separator(palette).grid(row=4, column=0, columnspan=2, sticky="ew", pady=5)
        self.mode_box = ttk.Combobox(palette, textvariable=self.mode_label, values=tuple(MODE_LABELS.values()), state="readonly")
        self.mode_box.grid(row=5, column=0, columnspan=2, sticky="ew")
        self.mode_box.bind("<<ComboboxSelected>>", self._mode_changed)
        self.choice_box = ttk.Combobox(palette, textvariable=self.choice_label, values=tuple(ENTITY_LABELS[item] for item in ENEMIES), state="readonly")
        self.choice_box.grid(row=6, column=0, columnspan=2, sticky="ew", pady=4)
        self.choice_box.bind("<<ComboboxSelected>>", self._choice_changed)
        ttk.Label(palette, text="Roda do rato: zoom · botão do meio: mover mapa", foreground="#aeb7ca", wraplength=245).grid(row=7, column=0, columnspan=2, sticky="w", pady=(4, 0))
        ttk.Label(self.side_content, text="MAPA LIGADO AO JOGO", foreground="#69ddd4", font=("Segoe UI", 10, "bold")).pack(anchor="w", pady=(12, 0))
        ttk.Label(self.side_content, text="Guardar na campanha cria o mapa ativo desta fase. A roda aproxima; o botão do meio move o tabuleiro.", wraplength=250, foreground="#aeb7ca", justify="left").pack(anchor="w", pady=4)
        contents = ttk.LabelFrame(self.side_content, text="Elementos no mapa", padding=5)
        contents.pack(fill="both", expand=True, pady=(5, 0))
        list_area = ttk.Frame(contents)
        list_area.pack(fill="both", expand=True)
        self.item_list = tk.Listbox(list_area, height=5, bg="#101722", fg="#e5e9f2",
                                    selectbackground="#1c827d", relief="flat", activestyle="none")
        item_scroll = ttk.Scrollbar(list_area, orient="vertical", command=self.item_list.yview)
        self.item_list.configure(yscrollcommand=item_scroll.set)
        self.item_list.pack(side="left", fill="both", expand=True)
        item_scroll.pack(side="right", fill="y")
        self.item_list.bind("<<ListboxSelect>>", self.select_list_item)
        item_actions = ttk.Frame(contents)
        item_actions.pack(fill="x", pady=(5, 0))
        ttk.Button(item_actions, text="Mover", command=self.move_selected).pack(side="left", fill="x", expand=True, padx=(0, 2))
        ttk.Button(item_actions, text="Remover", command=self.delete_selected).pack(side="left", fill="x", expand=True, padx=(2, 0))

    def _sidebar_content_changed(self, _event=None):
        self.side_canvas.configure(scrollregion=self.side_canvas.bbox("all"))

    def _sidebar_resized(self, event):
        self.side_canvas.itemconfigure(self.side_window, width=event.width)

    def _bind_sidebar_wheel(self, widget):
        widget.bind("<MouseWheel>", self._sidebar_wheel)
        for child in widget.winfo_children():
            self._bind_sidebar_wheel(child)

    def _sidebar_wheel(self, event):
        self.side_canvas.yview_scroll(-1 if event.delta > 0 else 1, "units")

    def _entry_row(self, parent, label, variable, row, spin=None):
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", pady=2)
        widget = ttk.Spinbox(parent, textvariable=variable, from_=spin[0], to=spin[1], width=8) if spin else ttk.Entry(parent, textvariable=variable, width=18)
        widget.grid(row=row, column=1, sticky="ew", pady=2)
        widget.bind("<FocusOut>", self.commit_fields)
        parent.columnconfigure(1, weight=1)

    def _refresh_fields(self):
        self.floor_var.set(self.data["floor"])
        self.name_var.set(self.data["name"])
        self.hint_var.set(self.data.get("hint", ""))
        self.width_var.set(self.data["width"])
        self.height_var.set(self.data["height"])
        self.objective_var.set(self.data["objective"])
        self.objective_label.set(OBJECTIVE_LABELS.get(self.data["objective"], OBJECTIVE_LABELS["escape"]))
        self.authoritative_var.set(self.data.get("authoritative_spawns", True))

    def snapshot(self):
        self.undo_stack.append(copy.deepcopy(self.data))
        if len(self.undo_stack) > 80:
            self.undo_stack.pop(0)
        self.redo_stack.clear()

    def undo(self):
        if self.undo_stack:
            self.redo_stack.append(copy.deepcopy(self.data))
            self.data = self.undo_stack.pop()
            self._refresh_fields(); self.draw()
            self.status.set("Alteração desfeita.")

    def redo(self):
        if self.redo_stack:
            self.undo_stack.append(copy.deepcopy(self.data))
            self.data = self.redo_stack.pop()
            self._refresh_fields(); self.draw()
            self.status.set("Alteração refeita.")

    def _sync_fields(self):
        try:
            self.data["floor"] = max(1, min(200, self.floor_var.get()))
            self.data["name"] = self.name_var.get().strip() or f"Fase {self.data['floor']:03d}"
            self.data["objective"] = self.objective_var.get()
            self.data["authoritative_spawns"] = bool(self.authoritative_var.get())
        except (tk.TclError, ValueError):
            pass

    def commit_fields(self, _event=None):
        before = (self.data.get("floor"), self.data.get("name"), self.data.get("hint"),
                  self.data.get("objective"), self.data.get("authoritative_spawns"))
        try:
            after = (max(1, min(200, self.floor_var.get())), self.name_var.get().strip(),
                     self.hint_var.get().strip(), self.objective_var.get(), bool(self.authoritative_var.get()))
        except (tk.TclError, ValueError):
            return
        if before != after:
            self.snapshot()
            self._sync_fields()
            self.data["hint"] = after[2]

    def resize_map(self):
        w, h = self.width_var.get(), self.height_var.get()
        if not 5 <= w <= 160 or not 5 <= h <= 160:
            messagebox.showerror("Tamanho inválido", "Usa um tamanho entre 5 e 160 casas.")
            return
        self.snapshot()
        old_w, old_h = self.data["width"], self.data["height"]
        self._sync_fields()
        self.data["hint"] = self.hint_var.get().strip()
        self.data["width"], self.data["height"] = w, h
        self.data["walls"] = [p for p in self.data["walls"] if 0 < p[0] < w-1 and 0 < p[1] < h-1]
        self.data["entity_spawns"] = [e for e in self.data["entity_spawns"] if 0 < e["cell"][0] < w-1 and 0 < e["cell"][1] < h-1]
        self.data["mechanisms"] = [m for m in self.data["mechanisms"] if 0 < m["cell"][0] < w-1 and 0 < m["cell"][1] < h-1]
        self.data["start"] = [min(max(1, self.data["start"][0]), w-2), min(max(1, self.data["start"][1]), h-2)]
        self.data["portal"] = [min(max(1, self.data["portal"][0]), w-2), min(max(1, self.data["portal"][1]), h-2)]
        if self.data["start"] == self.data["portal"]:
            self.data["portal"] = [w-2, h-2]
        self.draw()
        self.status.set(f"Grelha redimensionada de {old_w}×{old_h} para {w}×{h}.")

    def _mode_changed(self, _event=None):
        self.mode.set({label: key for key, label in MODE_LABELS.items()}.get(self.mode_label.get(), "enemy"))
        mode = self.mode.get()
        options = ENEMIES if mode == "enemy" else PICKUPS if mode == "pickup" else MECHANISMS
        labels = ENTITY_LABELS if mode in ["enemy", "pickup"] else MECHANISM_LABELS
        self.choice_box.configure(values=tuple(labels.get(item, item) for item in options))
        self.choice.set(options[0])
        self.choice_label.set(labels.get(options[0], options[0]))
        self._update_status()

    def _choice_changed(self, _event=None):
        options = ENEMIES if self.mode.get() == "enemy" else PICKUPS if self.mode.get() == "pickup" else MECHANISMS
        labels = ENTITY_LABELS if self.mode.get() in ["enemy", "pickup"] else MECHANISM_LABELS
        self.choice.set(next((item for item in options if labels.get(item, item) == self.choice_label.get()), options[0]))
        self._update_status()

    def _objective_changed(self, _event=None):
        self.objective_var.set({label: key for key, label in OBJECTIVE_LABELS.items()}.get(self.objective_label.get(), "escape"))
        self.commit_fields()

    def _tool_changed(self):
        if self.tool.get() == "move" and self.selected_item is not None:
            self.move_selection = self.selected_item
        elif self.tool.get() != "link":
            self.move_selection = None
        self._update_status()

    def _refresh_item_list(self):
        selected = self.selected_item[1] if self.selected_item else None
        self.item_refs = []
        self.item_list.delete(0, "end")
        for item in self.data["entity_spawns"]:
            group = "Inimigo" if item.get("kind") == "enemy" else "Recolha"
            label = ENTITY_LABELS.get(item.get("subtype"), item.get("subtype", "?"))
            self.item_refs.append(("entity", item))
            self.item_list.insert("end", f"{group}: {label}  ·  {item.get('cell')}")
        for item in self.data["mechanisms"]:
            self.item_refs.append(("mechanism", item))
            self.item_list.insert("end", f"Peça: {MECHANISM_LABELS.get(item.get('kind'), item.get('kind'))}  ·  {item.get('cell')}")
        if selected is not None:
            for index, reference in enumerate(self.item_refs):
                if reference[1] is selected:
                    self.item_list.selection_set(index)
                    self.item_list.see(index)
                    self.selected_item = reference
                    return
        self.selected_item = None

    def select_list_item(self, _event=None):
        selection = self.item_list.curselection()
        if selection:
            self.selected_item = self.item_refs[selection[0]]

    def move_selected(self):
        if self.selected_item is None:
            self.status.set("Escolhe primeiro um elemento na lista.")
            return
        self.tool.set("move")
        self.move_selection = self.selected_item
        self.status.set("Agora clica numa casa livre no mapa para mover o elemento selecionado.")

    def delete_selected(self):
        if self.selected_item is None:
            self.status.set("Escolhe primeiro um elemento na lista.")
            return
        kind, item = self.selected_item
        self.snapshot()
        if kind == "entity":
            self.data["entity_spawns"].remove(item)
        else:
            self.data["mechanisms"].remove(item)
            for other in self.data["mechanisms"]:
                other["outputs"] = [output for output in other.get("outputs", []) if output != item.get("id")]
        self.selected_item = None
        self.move_selection = None
        self.draw()
        self.status.set("Elemento removido.")

    def _update_status(self):
        tool = self.tool.get()
        if tool == "place":
            self.status.set(f"Clica para colocar: {self.choice_label.get()}.")
        elif tool == "link":
            self.status.set("Clica no mecanismo de origem e depois no mecanismo de destino.")
        elif tool == "move":
            self.status.set("Clica num inimigo, pickup ou mecanismo; depois clica no destino.")
        else:
            self.status.set("Clica numa casa para editar. A borda exterior é fixa.")

    def _entity_at(self, point):
        for item in self.data["entity_spawns"]:
            if _cell(item.get("cell")) == point:
                return "entity", item
        for item in self.data["mechanisms"]:
            if _cell(item.get("cell")) == point:
                return "mechanism", item
        return None, None

    def click_map(self, event):
        self._sync_fields()
        x = int(self.canvas.canvasx(event.x) // self.cell_size)
        y = int(self.canvas.canvasy(event.y) // self.cell_size)
        point = (x, y)
        if x <= 0 or y <= 0 or x >= self.data["width"]-1 or y >= self.data["height"]-1:
            self.status.set("A borda é fixa e não pode ser editada.")
            return
        tool = self.tool.get()
        if tool == "move":
            kind, item = self._entity_at(point)
            if self.move_selection is None:
                if item is None:
                    self.status.set("Escolhe primeiro um elemento colocado.")
                    return
                self.move_selection = (kind, item)
                self.selected_item = self.move_selection
                self.status.set(f"{item.get('subtype', item.get('kind'))} selecionado; escolhe a casa de destino.")
            else:
                _kind, selected = self.move_selection
                if self._is_blocked(point, ignore=selected):
                    self.status.set("Essa casa está ocupada. Escolhe um espaço livre.")
                    return
                self.snapshot(); selected["cell"] = list(point); self.move_selection = None
                self.selected_item = ("mechanism" if "kind" in selected and selected in self.data["mechanisms"] else "entity", selected)
                self.draw(); self.status.set(f"Elemento movido para {point}.")
            return
        if tool == "link":
            kind, item = self._entity_at(point)
            if kind != "mechanism":
                self.status.set("Escolhe uma caixa, placa, portão ou peça elétrica.")
                return
            if self.move_selection is None:
                self.move_selection = (kind, item)
                self.selected_item = self.move_selection
                self.status.set(f"Origem {item['id']} selecionada; agora escolhe o destino.")
            else:
                source = self.move_selection[1]
                if source is item:
                    self.status.set("A origem e o destino têm de ser diferentes.")
                    return
                self.snapshot()
                source.setdefault("outputs", [])
                if item["id"] not in source["outputs"]:
                    source["outputs"].append(item["id"])
                self.move_selection = None; self.draw(); self.status.set(f"Ligação criada: {source['id']} → {item['id']}.")
                self.selected_item = ("mechanism", source)
            return
        if tool == "erase":
            if not self.data["walls"] and not self.data["entity_spawns"] and not self.data["mechanisms"]:
                return
            self.snapshot()
            self.data["walls"] = [p for p in self.data["walls"] if _cell(p) != point]
            self.data["entity_spawns"] = [e for e in self.data["entity_spawns"] if _cell(e.get("cell")) != point]
            removed_ids = {m["id"] for m in self.data["mechanisms"] if _cell(m.get("cell")) == point}
            self.data["mechanisms"] = [m for m in self.data["mechanisms"] if _cell(m.get("cell")) != point]
            for item in self.data["mechanisms"]:
                item["outputs"] = [out for out in item.get("outputs", []) if out not in removed_ids]
            self.selected_item = None
            self.draw(); self.status.set(f"Casa {point} limpa."); return
        if tool == "wall":
            if self._is_blocked(point):
                self.status.set("Move ou apaga o elemento antes de colocar uma parede."); return
            self.snapshot(); walls = {_cell(p) for p in self.data["walls"]}
            if point in walls: walls.remove(point)
            else: walls.add(point)
            self.data["walls"] = [list(p) for p in sorted(walls)]
        elif tool == "floor":
            self.snapshot(); self.data["walls"] = [p for p in self.data["walls"] if _cell(p) != point]
        elif tool in ("start", "portal"):
            if self._is_blocked(point):
                self.status.set("Move ou apaga o elemento antes de usar essa casa."); return
            self.snapshot(); self.data[tool] = list(point)
        elif tool == "place":
            if self._is_blocked(point):
                self.status.set("Essa casa já está ocupada."); return
            self.snapshot()
            value = self.choice.get()
            if self.mode.get() == "enemy":
                self.data["entity_spawns"].append({"kind": "enemy", "subtype": value, "cell": list(point)})
            elif self.mode.get() == "pickup":
                self.data["entity_spawns"].append({"kind": "pickup", "subtype": value, "cell": list(point)})
            else:
                self._place_mechanism(value, point)
        self.draw()

    def _place_mechanism(self, kind, point):
        suffix = 1
        used_ids = {str(mechanism.get("id", "")) for mechanism in self.data["mechanisms"]}
        while f"{kind}_{suffix}" in used_ids:
            suffix += 1
        item = {"kind": kind, "id": f"{kind}_{suffix}", "cell": list(point), "outputs": []}
        if kind == "crate": item["material"] = "wood"
        if kind == "pressure_plate": item["required"] = "any"
        if kind == "gate": item.update(input_mode="all", open=False)
        if kind == "power_source": item["active"] = True
        self.data["mechanisms"].append(item)

    def _is_blocked(self, point, ignore=None):
        if point in {_cell(p) for p in self.data["walls"]}:
            return True
        for key in ("start", "portal"):
            if _cell(self.data[key]) == point and (ignore is None or ignore is not self.data):
                return True
        kind, item = self._entity_at(point)
        return item is not None and item is not ignore

    def draw(self):
        if not hasattr(self, "canvas"):
            return
        self.canvas.delete("all")
        w, h = self.data["width"], self.data["height"]
        cell = self.cell_size
        self.canvas.configure(scrollregion=(0, 0, w*cell, h*cell))
        walls = {_cell(p) for p in self.data["walls"]}
        for y in range(h):
            for x in range(w):
                x0, y0 = x*cell, y*cell
                boundary = x == 0 or y == 0 or x == w-1 or y == h-1
                color = "#303747" if boundary else "#202a3b" if (x+y) % 2 == 0 else "#1b2535"
                if (x, y) in walls:
                    color = COLORS["wall"]
                self.canvas.create_rectangle(x0+1, y0+1, x0+cell-1, y0+cell-1, fill=color, outline="#344158", width=1)
                if not boundary and (x, y) not in walls:
                    self.canvas.create_oval(x0+cell-4, y0+cell-4, x0+cell-2, y0+cell-2, fill="#40506a", outline="")
        self._marker(self.data["start"], COLORS["start"], "●", "INÍCIO")
        self._marker(self.data["portal"], COLORS["portal"], "✦", "PORTAL")
        for item in self.data["mechanisms"]:
            kind = item.get("kind", "")
            self._marker(item["cell"], COLORS.get(kind, "#ffffff"), GLYPHS.get(kind, "?"), MECHANISM_LABELS.get(kind, kind), square=True)
        for item in self.data["entity_spawns"]:
            kind, subtype = item.get("kind", ""), item.get("subtype", "?")
            color = COLORS.get(kind, "#ffffff")
            glyph = "◆" if kind == "enemy" else "★"
            self._marker(item["cell"], color, glyph, ENTITY_LABELS.get(subtype, subtype))
        for item in self.data["mechanisms"]:
            for output in item.get("outputs", []):
                target = next((m for m in self.data["mechanisms"] if m.get("id") == output), None)
                if target:
                    a = self._center(item["cell"]); b = self._center(target["cell"])
                    self.canvas.create_line(*a, *b, fill="#58d9cb", width=2, dash=(5, 3), arrow="last", tags="wires")
        self._refresh_item_list()

    def _center(self, point):
        return (point[0]*self.cell_size+self.cell_size/2, point[1]*self.cell_size+self.cell_size/2)

    def _marker(self, point, color, glyph, label, square=False):
        if _cell(point) is None: return
        x, y = self._center(point); r = self.cell_size*.30
        if square:
            self.canvas.create_rectangle(x-r, y-r, x+r, y+r, fill="#17202d", outline=color, width=3)
        else:
            self.canvas.create_oval(x-r, y-r, x+r, y+r, fill="#171d2b", outline=color, width=3)
        self.canvas.create_text(x, y, text=glyph, fill=color, font=("Segoe UI Symbol", max(10, int(self.cell_size*.40)), "bold"))
        if self.cell_size >= 35:
            self.canvas.create_text(x, y+self.cell_size*.39, text=label[:14], fill="#f1f2f8", font=("Segoe UI", 8), width=self.cell_size*1.8)

    def zoom(self, event):
        self.cell_size = max(24, min(76, self.cell_size + (4 if event.delta > 0 else -4)))
        self.draw()

    def pan_start(self, event):
        self.canvas.scan_mark(event.x, event.y)

    def pan_move(self, event):
        self.canvas.scan_dragto(event.x, event.y, gain=1)

    def _read_file(self, path):
        path = Path(path)
        if path.suffix.lower() == ".tscn":
            return import_godot_scene(path)
        data = json.loads(path.read_text(encoding="utf-8"))
        errors = validate_map(data)
        if errors:
            raise ValueError("Mapa inválido:\n" + "\n".join(errors))
        return data

    def open_campaign_floor(self):
        try:
            floor = max(1, min(200, int(self.floor_var.get())))
        except (tk.TclError, ValueError):
            floor = 1
        external = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
        scene = self.project_root / "levels" / "authored" / f"floor_{floor:03d}_workshop.tscn"
        try:
            if external.exists():
                self._load_data(self._read_file(external), f"Fase {floor:03d} aberta da Oficina independente.")
            elif scene.exists():
                self._load_data(import_godot_scene(scene), f"Fase {floor:03d} importada da cena Godot.")
            else:
                self._load_data(blank_map(floor), f"A fase {floor:03d} ainda não tem mapa manual. Criado um mapa vazio.")
        except Exception as exc:
            messagebox.showerror("Não foi possível abrir a fase", str(exc))

    def _load_data(self, data, message):
        self.data = data
        self.undo_stack.clear(); self.redo_stack.clear(); self.move_selection = None
        self.selected_item = None
        self._refresh_fields(); self.draw(); self.status.set(message)

    def new_map(self):
        if not messagebox.askyesno("Novo mapa", "Criar um mapa vazio? As alterações não guardadas serão descartadas."):
            return
        floor = max(1, min(200, self.floor_var.get()))
        self._load_data(blank_map(floor), "Mapa vazio criado. Coloca paredes, inimigos, recolhas e mecanismos.")

    def open_map(self):
        path = filedialog.askopenfilename(title="Abrir mapa", filetypes=(("Mapas CTM", "*.ctmmap.json"),
            ("Cópias recuperáveis", "*.ctmmap.json.disabled* *.ctmmap.json.bak*"), ("JSON", "*.json"), ("Todos", "*.*")))
        if not path: return
        try: self._load_data(self._read_file(path), f"Mapa aberto: {Path(path).name}")
        except Exception as exc: messagebox.showerror("Não foi possível abrir", str(exc))

    def import_scene(self):
        path = filedialog.askopenfilename(title="Importar blueprint do Godot", filetypes=(("Cena Godot", "*.tscn"),))
        if not path: return
        try: self._load_data(import_godot_scene(path), f"Cena importada: {Path(path).name}. Revê o mapa e guarda no formato da Oficina.")
        except Exception as exc: messagebox.showerror("Importação incompleta", str(exc))

    def _save_to(self, path):
        self._sync_fields()
        self.data["hint"] = self.hint_var.get().strip()
        self.data["id"] = f"external_floor_{self.data['floor']:03d}"
        errors = validate_map(self.data)
        if errors:
            messagebox.showerror("Mapa precisa de correções", "\n".join(errors[:12]))
            return False
        path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".writing")
        try:
            if path.exists():
                backup = path.with_name(path.name + ".bak")
                suffix = 1
                while backup.exists():
                    backup = path.with_name(path.name + f".bak.{suffix}")
                    suffix += 1
                shutil.copy2(path, backup)
            temporary.write_text(json.dumps(self.data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            os.replace(temporary, path)
        except OSError as exc:
            try: temporary.unlink(missing_ok=True)
            except OSError: pass
            messagebox.showerror("Não foi possível guardar", str(exc))
            return False
        self.status.set(f"Guardado: {path}")
        return True

    def save_campaign(self):
        self._sync_fields()
        floor = self.data["floor"]
        target = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
        if self._save_to(target):
            messagebox.showinfo("Mapa guardado", f"Fase {floor:03d} ligada ao jogo.\n\n{target}\n\nAo jogar essa fase, este mapa tem prioridade sobre a cena Godot existente.")

    def disable_campaign_floor(self):
        try:
            floor = max(1, min(200, int(self.floor_var.get())))
        except (tk.TclError, ValueError):
            floor = self.data["floor"]
        target = self.project_root / "levels" / "external_maps" / f"floor_{floor:03d}.ctmmap.json"
        if not target.exists():
            self.status.set(f"A fase {floor:03d} não tem mapa externo ativo.")
            return
        if not messagebox.askyesno("Desligar fase", f"Desligar o mapa externo da fase {floor:03d}? Uma cópia ficará guardada como .disabled."):
            return
        backup = target.with_name(target.name + ".disabled")
        suffix = 1
        while backup.exists():
            backup = target.with_name(target.name + f".disabled.{suffix}")
            suffix += 1
        target.rename(backup)
        self.status.set(f"Mapa externo desligado. Cópia guardada em {backup.name}.")

    def save_copy(self):
        path = filedialog.asksaveasfilename(title="Guardar cópia", defaultextension=".ctmmap.json",
            initialfile=f"floor_{self.data['floor']:03d}.ctmmap.json", filetypes=(("Mapa CTM", "*.ctmmap.json"),))
        if path: self._save_to(path)

    def validate_dialog(self):
        self._sync_fields()
        errors = validate_map(self.data)
        if errors:
            self.status.set(f"Validação: {len(errors)} problema(s).")
            messagebox.showerror("Mapa precisa de correções", "\n".join(errors[:12]))
        else:
            self.status.set("Mapa válido: caminho, borda, elementos e ligações conferidos.")
            messagebox.showinfo("Mapa válido", "A rota ao portal está livre e os elementos têm posições válidas.")


def main():
    parser = argparse.ArgumentParser(description="Editor visual independente de mapas Come To Me")
    parser.add_argument("--project-root", default=str(Path(__file__).resolve().parents[1]))
    args = parser.parse_args()
    root = tk.Tk()
    Oficina(root, Path(args.project_root).resolve())
    root.mainloop()


if __name__ == "__main__":
    main()
