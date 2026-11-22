@tool
extends Resource

const DIRECTIONS := [1, 2, 4, 8]

@export var tiles: Array[Resource] = []


func build_tables() -> Dictionary:
	var weights := PackedFloat64Array()
	weights.resize(16)
	var open_masks: Array[int] = [0, 0, 0, 0]
	var errors: Array[String] = []
	var found: Dictionary = {}
	for tile in tiles:
		if tile == null:
			continue
		var tile_id := int(tile.get("tile_id"))
		if tile_id < 0 or tile_id > 15 or found.has(tile_id):
			errors.append("Tile WFC com ID inválido ou repetido: %d" % tile_id)
			continue
		found[tile_id] = true
		weights[tile_id] = float(tile.get("weight"))
		var passage_mask := int(tile.get("passage_mask"))
		for direction in 4:
			if (passage_mask & DIRECTIONS[direction]) != 0:
				open_masks[direction] |= 1 << tile_id
	for tile_id in 16:
		if not found.has(tile_id):
			errors.append("Falta definicao do tile WFC %d" % tile_id)
	var opposite_masks: Array[int] = [open_masks[2], open_masks[3], open_masks[0], open_masks[1]]
	return {"weights": weights, "open_masks": open_masks, "opposite_masks": opposite_masks, "errors": errors}
