extends RefCounted

## Reads the small, editor-independent CTM map format and adapts it to the
## existing campaign level contract. The Godot scene/catalog path remains a
## fallback for floors without an external map.
const MAP_DIRECTORY := "res://levels/external_maps"


static func campaign_path(floor_number: int) -> String:
	return "%s/floor_%03d.ctmmap.json" % [MAP_DIRECTORY, floor_number]


static func load_campaign_floor(floor_number: int, catalog: Resource) -> Dictionary:
	var path := campaign_path(floor_number)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"found": true, "ok": false, "errors": ["Nao foi possivel abrir %s" % path]}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"found": true, "ok": false, "errors": ["O ficheiro da Oficina nao contem um mapa valido"]}
	var result := compile_data(parsed, floor_number, catalog)
	result["found"] = true
	result["path"] = path
	return result


static func compile_data(data: Dictionary, expected_floor: int, catalog: Resource = null) -> Dictionary:
	var errors: Array[String] = []
	if str(data.get("format", "")) != "ctmmap" or int(data.get("version", 0)) != 1:
		errors.append("Formato de mapa CTM desconhecido")
	var floor_number := int(data.get("floor", expected_floor))
	if floor_number != expected_floor or floor_number < 1 or floor_number > 200:
		errors.append("O mapa pertence a outra fase (esperada %03d)" % expected_floor)
	var width := int(data.get("width", 0))
	var height := int(data.get("height", 0))
	if width < 5 or height < 5 or width > 160 or height > 160:
		errors.append("A grelha precisa de ter entre 5 e 160 casas por lado")
	var size := Vector2i(width, height)
	var start := _cell(data.get("start", [-1, -1]))
	var portal := _cell(data.get("portal", [-1, -1]))
	var walls: Array[Vector2i] = []
	var wall_lookup: Dictionary = {}
	for value in data.get("walls", []):
		var cell := _cell(value)
		if not _inside_play_area(cell, size):
			errors.append("Parede fora do interior da grelha: %s" % cell)
		elif wall_lookup.has(cell):
			errors.append("Parede repetida: %s" % cell)
		else:
			walls.append(cell)
			wall_lookup[cell] = true
	if not _inside_play_area(start, size) or not _inside_play_area(portal, size):
		errors.append("Inicio e portal precisam de ficar dentro da borda")
	elif start == portal:
		errors.append("Inicio e portal precisam de ficar em casas diferentes")
	if wall_lookup.has(start) or wall_lookup.has(portal):
		errors.append("Uma parede ocupa o inicio ou o portal")
	var entity_spawns: Array[Dictionary] = []
	var occupied: Dictionary = {start: "reserved", portal: "reserved"}
	for value in data.get("entity_spawns", []):
		if not value is Dictionary:
			errors.append("Elemento colocado com dados invalidos")
			continue
		var spawn: Dictionary = value.duplicate(true)
		var cell := _cell(spawn.get("cell", [-1, -1]))
		var kind := str(spawn.get("kind", ""))
		var subtype := str(spawn.get("subtype", ""))
		if not _inside_play_area(cell, size):
			errors.append("Elemento fora do interior da grelha: %s" % subtype)
		elif wall_lookup.has(cell) or (occupied.has(cell) and not (kind == "pickup" and occupied[cell] == "pickup")):
			errors.append("Elemento sobre uma parede, inicio, portal ou outro elemento: %s" % cell)
		if kind not in ["enemy", "pickup"]:
			errors.append("Tipo de elemento desconhecido: %s" % kind)
		elif not _valid_subtype(kind, subtype, catalog):
			errors.append("Elemento desconhecido: %s" % subtype)
		spawn["cell"] = cell
		entity_spawns.append(spawn)
		occupied[cell] = kind
	var environment := {"cells": {}, "crates": [], "plates": [], "gates": [], "circuit_nodes": []}
	var mechanisms_by_id: Dictionary = {}
	for value in data.get("mechanisms", []):
		if not value is Dictionary:
			errors.append("Mecanismo com dados invalidos")
			continue
		var item: Dictionary = value.duplicate(true)
		var cell := _cell(item.get("cell", [-1, -1]))
		var kind := str(item.get("kind", ""))
		var mechanism_id := str(item.get("id", ""))
		if not _inside_play_area(cell, size) or wall_lookup.has(cell) or occupied.has(cell):
			errors.append("Mecanismo fora da area ou sobreposto: %s" % cell)
			continue
		if mechanism_id.is_empty() or mechanisms_by_id.has(mechanism_id):
			errors.append("ID de mecanismo vazio ou repetido: %s" % mechanism_id)
		var compiled := {
			"kind": kind,
			"id": mechanism_id,
			"pos": cell,
			"outputs": item.get("outputs", []),
		}
		for key in ["material", "required", "input_mode", "open", "active"]:
			if item.has(key):
				compiled[key] = item[key]
		match kind:
			"crate": environment.crates.append(compiled)
			"pressure_plate": environment.plates.append(compiled)
			"gate": environment.gates.append(compiled)
			"power_source", "circuit_relay", "circuit_receiver": environment.circuit_nodes.append(compiled)
			_: errors.append("Mecanismo desconhecido: %s" % kind)
		mechanisms_by_id[mechanism_id] = compiled
		occupied[cell] = "mechanism"
	for mechanism in mechanisms_by_id.values():
		var source_channel := _output_channel(str(mechanism.kind))
		for target_id in mechanism.outputs:
			if not mechanisms_by_id.has(str(target_id)):
				errors.append("Ligacao %s -> %s sem destino" % [mechanism.id, target_id])
				continue
			var target: Dictionary = mechanisms_by_id[str(target_id)]
			if source_channel.is_empty() or source_channel != _input_channel(str(target.kind)):
				errors.append("Ligacao %s -> %s usa canais incompativeis" % [mechanism.id, target_id])
	var objective := str(data.get("objective", "escape"))
	if objective not in ["escape", "environment"]:
		errors.append("Objetivo de fase desconhecido")
	if objective == "environment" and environment.plates.is_empty():
		errors.append("O objetivo de abrir o portal precisa de pelo menos uma placa")
	if _inside_play_area(start, size) and _inside_play_area(portal, size) and not _has_wall_route(start, portal, size, wall_lookup):
		errors.append("Nao existe caminho livre entre o inicio e o portal")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var level := {
		"id": str(data.get("id", "external_floor_%03d" % floor_number)),
		"name": str(data.get("name", "Fase %03d" % floor_number)),
		"hint": str(data.get("hint", "")),
		"campaign_floor": floor_number,
		"layout_source": "Manual",
		"layout_seed": int(data.get("seed", 0)),
		"objective_type": objective,
		"size": size,
		"start": start,
		"portal": portal,
		"walls": walls,
		"authoritative_spawns": bool(data.get("authoritative_spawns", true)),
		"entity_spawns": entity_spawns,
		"mission_title": str(data.get("name", "Fase %03d" % floor_number)),
		"mission_hint": str(data.get("hint", "")),
	}
	return {"ok": true, "level": level, "environment": environment, "errors": []}


static func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _inside_play_area(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < size.x - 1 and cell.y < size.y - 1


static func _has_wall_route(origin: Vector2i, destination: Vector2i, size: Vector2i, walls: Dictionary) -> bool:
	var pending: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: true}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		if current == destination:
			return true
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if not _inside_play_area(next, size) or walls.has(next) or visited.has(next):
				continue
			visited[next] = true
			pending.append(next)
	return false


static func _valid_subtype(kind: String, subtype: String, catalog: Resource) -> bool:
	if kind == "enemy":
		if subtype == "warden":
			return true
		if subtype.begins_with("boss/"):
			return catalog != null and catalog.call("boss_definition", subtype.trim_prefix("boss/")) != null
		return catalog != null and catalog.call("enemy_definition", subtype) != null
	if subtype in ["coin", "shield", "breaker", "heart"]:
		return true
	if subtype.begins_with("powerup/"):
		return catalog != null and catalog.call("powerup_definition", subtype.trim_prefix("powerup/")) != null
	return false


static func _input_channel(kind: String) -> String:
	match kind:
		"crate": return "push"
		"pressure_plate": return "weight"
		"gate": return "logic"
		"circuit_relay", "circuit_receiver": return "power"
	return ""


static func _output_channel(kind: String) -> String:
	match kind:
		"crate": return "pressure"
		"pressure_plate": return "logic"
		"gate": return "passage"
		"power_source", "circuit_relay": return "power"
		"circuit_receiver": return "logic"
	return ""
