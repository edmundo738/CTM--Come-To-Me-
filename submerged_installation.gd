extends RefCounted

# One authored installation, using the ordinary environment, movement and turn
# pipeline. This controller owns only the installation's latches and switches;
# crates, plates, gates and electrical propagation remain in EnvironmentSystem.
const LAB_INDEX := 4
const SOCKET := Vector2i(6, 15)
const SOURCE := Vector2i(18, 17)
const POWER_SWITCH := Vector2i(8, 15)
const HATCH_PLATE := Vector2i(4, 10)
const HATCH_GATE := Vector2i(6, 11)
const DRAIN_PLATE := Vector2i(16, 19)
const DRAIN_VALVE := Vector2i(16, 20) # Visual mechanical linkage, not a separate switch.
const PANEL := Vector2i(20, 5)
const DRAIN_TERMINALS := [Vector2i(12, 18), Vector2i(17, 18), Vector2i(22, 18)]
const EXIT_GATE := Vector2i(18, 21)
const ORDER := [1, 0, 2] # II, I, III
const ROMAN := ["I", "II", "III"]

var selected_door := 0
var hatch_open := false
var generator_installed := false
var generator_on := false
var passage_open := false
var sequence_progress := 0
var sequence_complete := false
var drained := false
var drain_switches: Array[bool] = [false, false, false]
var final_open := false
# Switches react to entry, not to a wait or another synchronization this turn.
var last_cell := Vector2i(-1, -1)


static func chamber() -> Dictionary:
	var data := {
		"name": "A INSTALACAO SUBMERSA",
		"hint": "PISA A, B OU C: CADA CONSOLA ABRE APENAS A SUA PORTA.",
		"size": Vector2i(25, 25), "start": Vector2i(12, 9), "portal": Vector2i(18, 23),
		"cells": {}, "crates": [], "plates": [], "gates": [], "walls": [], "traps": [], "switches": [],
		"biome_floor": 2,
	}
	# Three northern rooms and a shared central hall. Only the three labelled
	# gates cross the first partition. The industrial room, powered corridor,
	# flooded chamber and exit have their own independent gates.
	for x in [7, 16]:
		for y in range(1, 6):
			data.walls.append(Vector2i(x, y))
	for x in range(1, 24):
		if x not in [4, 12, 20]:
			data.walls.append(Vector2i(x, 6))
		if x not in [6, 18]:
			data.walls.append(Vector2i(x, 11))
	for y in range(12, 24):
		data.walls.append(Vector2i(10, y))
	for x in range(11, 24):
		if x != 18:
			data.walls.append(Vector2i(x, 16))
			data.walls.append(Vector2i(x, 21))
	for y in range(17, 21):
		for x in range(11, 24):
			data.cells[Vector2i(x, y)] = {"kind": "water"}
	data.cells[SOURCE] = {"kind": "water", "source": false}
	data.crates = [
		{"id": "wood_hatch", "pos": Vector2i(4, 3), "material": "wood"},
		{"id": "generator", "label": "G", "pos": Vector2i(12, 3), "material": "metal"},
		{"id": "wood_drain", "pos": Vector2i(13, 19), "material": "wood"},
	]
	data.plates = [
		{"id": "hatch", "pos": HATCH_PLATE, "required": "wood"},
		{"id": "drain", "pos": DRAIN_PLATE, "required": "wood"},
	]
	data.gates = [
		{"id": "door_a", "label": "A", "pos": Vector2i(4, 6), "open": true},
		{"id": "door_b", "label": "B", "pos": Vector2i(12, 6), "open": false},
		{"id": "door_c", "label": "C", "pos": Vector2i(20, 6), "open": false},
		{"id": "hatch", "label": "H", "pos": HATCH_GATE, "open": false},
		{"id": "powered_passage", "label": "E", "pos": Vector2i(18, 11), "open": false},
		{"id": "flooded_room", "label": "SEQ", "pos": Vector2i(18, 16), "open": false},
		{"id": "exit", "label": "D", "pos": EXIT_GATE, "open": false},
	]
	for index in 3:
		data.switches.append({"group": "door", "index": index, "label": ["A", "B", "C"][index],
			"pos": Vector2i(4 + index * 8, 8), "active": index == 0})
		data.switches.append({"group": "sequence", "index": index, "label": ROMAN[index],
			"pos": Vector2i(18 + index * 2, 3), "active": false})
		data.switches.append({"group": "drain", "index": index, "label": "D%d" % (index + 1),
			"pos": DRAIN_TERMINALS[index], "active": false, "hidden": true})
	data.switches.append({"group": "power", "index": 0, "label": "I/O", "pos": POWER_SWITCH, "active": false})
	return data


func reset(start: Vector2i) -> void:
	selected_door = 0
	hatch_open = false
	generator_installed = false
	generator_on = false
	passage_open = false
	sequence_progress = 0
	sequence_complete = false
	drained = false
	drain_switches.assign([false, false, false])
	final_open = false
	last_cell = start


func snapshot() -> Dictionary:
	return {"selected_door": selected_door, "hatch_open": hatch_open,
		"generator_installed": generator_installed, "generator_on": generator_on,
		"passage_open": passage_open, "sequence_progress": sequence_progress,
		"sequence_complete": sequence_complete, "drained": drained,
		"drain_switches": drain_switches.duplicate(), "final_open": final_open, "last_cell": last_cell}


func restore(state: Dictionary) -> void:
	selected_door = int(state.selected_door)
	hatch_open = bool(state.hatch_open)
	generator_installed = bool(state.generator_installed)
	generator_on = bool(state.generator_on)
	passage_open = bool(state.passage_open)
	sequence_progress = int(state.sequence_progress)
	sequence_complete = bool(state.sequence_complete)
	drained = bool(state.drained)
	drain_switches.assign(state.drain_switches)
	final_open = bool(state.final_open)
	last_cell = state.last_cell


# Call only during the existing mechanism phase. Persistent latches are set
# once; repeated syncs in one turn are idempotent and cannot create actions.
func sync(environment, grid: Array, switches: Array[Dictionary], player: Vector2i) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	environment.update_plates(player)
	if not hatch_open and bool(environment.plates[0].active):
		hatch_open = true
		events.append(_event("PLACA DE MADEIRA: ESCOTILHA H ABERTA, MESMO SE A CAIXA SAIR.", "SWITCH_ON", environment.plates[0].pos))
	var generator_index := _crate_index(environment, "generator")
	if not generator_installed and hatch_open and generator_index >= 0 and environment.crates[generator_index].pos == SOCKET:
		generator_installed = true
		generator_on = true
		passage_open = true
		# Once docked the generator stays installed. Its I/O console is separate.
		environment.crates[generator_index]["locked"] = true
		events.append(_event("GERADOR INSTALADO: ENERGIA LIGADA, PASSAGEM E ABERTA.", "SWITCH_ON", SOCKET))
	if not drained and bool(environment.plates[1].active):
		drained = true
		# Remove water from the sole logical board immediately. The presentation
		# may briefly draw a fading, non-interactive surface after this change.
		for point in environment.cells.keys():
			if environment.is_water(point):
				environment.cells.erase(point)
				grid[point.y][point.x] = 0 # TILE_FLOOR
		events.append(_event("DRENAGEM PERMANENTE: TRES TERMINAIS D REVELADOS.", "SWITCH_ON", environment.plates[1].pos, true))
	if environment.cells.has(SOURCE):
		environment.cells[SOURCE]["source"] = generator_installed and generator_on and not drained
	environment.refresh_electricity()
	for gate in environment.gates:
		match str(gate.get("id", "")):
			"door_a": gate.open = selected_door == 0
			"door_b": gate.open = selected_door == 1
			"door_c": gate.open = selected_door == 2
			"hatch": gate.open = hatch_open
			"powered_passage": gate.open = passage_open
			"flooded_room": gate.open = sequence_complete
			"exit": gate.open = final_open
	for item in switches:
		var index := int(item.get("index", 0))
		match str(item.get("group", "")):
			"door": item.active = index == selected_door
			"sequence": item.active = sequence_complete or ORDER.slice(0, sequence_progress).has(index)
			"power": item.active = generator_installed and generator_on
			"drain":
				item.hidden = not drained
				item.active = drain_switches[index]
	return events


func enter(player: Vector2i, switches: Array[Dictionary]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if player == last_cell:
		return events
	last_cell = player
	for item in switches:
		if item.pos != player or bool(item.get("hidden", false)):
			continue
		var index := int(item.get("index", 0))
		match str(item.get("group", "")):
			"door":
				selected_door = index
				events.append(_event("PORTA %s SELECIONADA — AS OUTRAS DUAS FECHAM." % ["A", "B", "C"][index], "SWITCH_ON", player))
			"power":
				if not generator_installed:
					events.append(_event("I/O SEM ALIMENTACAO — ENCAIXE VAZIO.", "BLOCKED", player))
				else:
					generator_on = not generator_on
					var message := "GERADOR LIGADO — AGUA ENERGIZADA." if generator_on and not drained else "GERADOR LIGADO — DRENAGEM MANTIDA." if generator_on else "GERADOR DESLIGADO, MAS INSTALADO — DESBLOQUEIOS MANTIDOS."
					events.append(_event(message, "SWITCH_ON", player))
			"sequence":
				# Crossing a terminal already accepted is harmless, like the
				# existing rune puzzle; only a new wrong terminal resets it.
				if sequence_complete or bool(item.get("active", false)):
					return events
				if not generator_on:
					events.append(_event("TERMINAIS SEM ENERGIA.", "BLOCKED", player))
				elif index == ORDER[sequence_progress]:
					sequence_progress += 1
					if sequence_progress == ORDER.size():
						sequence_complete = true
						events.append(_event("SEQUENCIA COMPLETA: SALA INUNDADA ABERTA — FONTE ! ATIVA.", "SWITCH_ON", player))
					else:
						events.append(_event("TERMINAL %s CORRETO — %d/3." % [ROMAN[index], sequence_progress], "SWITCH_ON", player))
				else:
					sequence_progress = 0
					events.append(_event("ORDEM ERRADA: RECOMECA E OBSERVA O PAINEL DA SALA C.", "PUZZLE_ERROR", player))
			"drain":
				if not drain_switches[index]:
					drain_switches[index] = true
					var count := 0
					for active in drain_switches:
						if active:
							count += 1
					if count == 3:
						final_open = true
						events.append(_event("TERMINAIS D 3/3: PASSAGEM FINAL E PORTAL ABERTOS.", "PORTAL_OPEN", player))
					else:
						events.append(_event("TERMINAL D%d ATIVO — %d/3." % [index + 1, count], "SWITCH_ON", player))
	return events


func hint() -> String:
	if not hatch_open:
		return "PORTAS A/B/C: PISA UMA CONSOLA. OBSERVA AS LIGACOES DA INSTALACAO."
	if not generator_installed:
		return "ESCOTILHA H ABERTA. ENCAIXE SEM ALIMENTACAO."
	if not sequence_complete:
		return "PAINEL DA SALA C  /  TERMINAIS %d/3  /  %s" % [sequence_progress, "ENERGIA LIGADA" if generator_on else "SEM ENERGIA"]
	if generator_on and not drained:
		return "AGUA ELETRIFICADA. OBSERVA A FONTE ! E OS CABOS."
	if not drained:
		return "AGUA SEGURA. INVESTIGA A SALA INUNDADA."
	if not final_open:
		return "DRENAGEM CONCLUIDA. TRES TERMINAIS D FORAM REVELADOS."
	return "PASSAGEM FINAL ABERTA. ALCANCA O PORTAL."


func objective() -> String:
	if final_open:
		return "ALCANCA O PORTAL"
	if drained:
		return "TERMINAIS D: %d/3" % drain_switches.count(true)
	if sequence_complete:
		return "FONTE ! ATIVA" if generator_on else "EXPLORA A SALA"
	if generator_installed:
		return "PAINEL: %d/3" % sequence_progress
	return "RESTAURA A ENERGIA" if hatch_open else "ABRE A ESCOTILHA"


static func _crate_index(environment, id: String) -> int:
	for index in environment.crates.size():
		if environment.crates[index].get("id", "") == id:
			return index
	return -1


static func _event(message: String, feedback: String, position: Vector2i, terrain_changed: bool = false) -> Dictionary:
	return {"message": message, "feedback": feedback, "pos": position, "terrain_changed": terrain_changed}
