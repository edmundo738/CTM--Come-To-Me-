extends RefCounted

# Hand-authored, repeatable test chambers. They use the normal turn pipeline
# but never grant campaign rewards or overwrite a campaign checkpoint.
const COUNT := 4


static func chamber(index: int) -> Dictionary:
	var common := {
		"size": Vector2i(13, 9),
		"start": Vector2i(2, 4),
		"portal": Vector2i(10, 4),
		"cells": {}, "crates": [], "plates": [], "gates": [], "walls": [], "traps": [],
	}
	match index:
		0:
			common["name"] = "CORRENTE / MADEIRA"
			common["hint"] = "Empurra madeira para a corrente; ela flutua uma casa por turno."
			common.cells[Vector2i(4, 4)] = {"kind": "current", "flow": Vector2i.RIGHT}
			common.cells[Vector2i(5, 4)] = {"kind": "water"}
			common.crates = [{"pos": Vector2i(3, 4), "material": "wood"}]
			common.plates = [{"pos": Vector2i(5, 4), "required": "wood"}]
		1:
			common["name"] = "CONDUTOR / METAL"
			common["hint"] = "Metal nao flutua; pode ligar duas aguas eletrificadas."
			common.cells[Vector2i(4, 3)] = {"kind": "water", "source": true}
			common.cells[Vector2i(4, 5)] = {"kind": "water"}
			common.cells[Vector2i(5, 4)] = {"kind": "current", "flow": Vector2i.RIGHT}
			common.crates = [{"pos": Vector2i(4, 4), "material": "metal"}]
			common.plates = [{"pos": Vector2i(6, 4), "required": "metal"}]
		2:
			common["name"] = "GELO / RITMO"
			common["hint"] = "Gelo desliza 1 casa e atrasa inimigos; armadilha pulsa a cada 3 turnos."
			common.cells[Vector2i(3, 4)] = {"kind": "ice"}
			common.walls = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 5), Vector2i(3, 5)]
			# Dangerous on the first action; wait once before entering.
			common.traps = [{"pos": Vector2i(3, 4), "type": "rhythm", "phase": 2, "armed": true, "revealed": true}]
			common.crates = [{"pos": Vector2i(5, 4), "material": "wood"}]
			common.plates = [{"pos": Vector2i(6, 4), "required": "wood"}]
		3:
			common["name"] = "DUAS PLACAS / PORTAO"
			common["hint"] = "Cada placa exige o material indicado; as duas abrem o portao."
			for y in range(1, 8):
				if y != 4:
					common.walls.append(Vector2i(8, y))
			common.crates = [
				{"pos": Vector2i(3, 3), "material": "wood"},
				{"pos": Vector2i(3, 5), "material": "metal"},
			]
			common.plates = [
				{"pos": Vector2i(5, 3), "required": "wood"},
				{"pos": Vector2i(5, 5), "required": "metal"},
			]
			common.gates = [{"pos": Vector2i(8, 4), "open": false}]
	return common
