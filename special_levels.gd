extends RefCounted

const Rules = preload("res://environment_system.gd")
const Sokoban = preload("res://sokoban_generator.gd")
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const MAX_SEARCH_STATES := 120000


# Compact designed chambers alternate with the WFC-generated campaign floors.
# Reflections preserve the actual rules, and do not change the campaign seed.
static func make(family: String, seed_number: int, floor_number: int) -> Dictionary:
	var spec := {
		"size": Vector2i(11, 7), "start": Vector2i(2, 3), "portal": Vector2i(8, 3),
		"name": "", "hint": "", "walls": [], "cells": {}, "crates": [], "plates": [], "gates": [],
	}
	# The campaign scheduler remains authoritative. On some later Sokoban
	# events, adapt the other branch's authored modules into the SAME held-plate
	# environment rules and subject them to the normal bounded solver below.
	if family == "sokoban" and floor_number >= 12 and posmod(seed_number + floor_number, 2) == 0:
		var module: Dictionary = Sokoban.new().generate(floor_number, seed_number ^ (floor_number * 7919))
		spec.size = module.size
		spec.start = module.start
		spec.portal = module.portal
		spec.name = str(module.title)
		spec.hint = "EMPURRA CADA CAIXA A UMA PLACA DE MADEIRA; Z DESFAZ."
		for y in range(1, spec.size.y - 1):
			for x in range(1, spec.size.x - 1):
				if module.grid[y][x] == Sokoban.TILE_WALL:
					spec.walls.append(Vector2i(x, y))
		for point in module.boxes:
			spec.crates.append({"pos": point, "material": "wood"})
		for point in module.goals:
			spec.plates.append({"pos": point, "required": "wood"})
		return spec
	match family:
		"sokoban":
			spec.name = "OFICINA DE CAIXAS"
			if floor_number < 12:
				spec.crates = [{"pos": Vector2i(3, 3), "material": "wood"}]
				spec.plates = [{"pos": Vector2i(5, 3), "required": "wood"}]
			else:
				spec.crates = [{"pos": Vector2i(3, 2), "material": "wood"}, {"pos": Vector2i(3, 4), "material": "wood"}]
				spec.plates = [{"pos": Vector2i(5, 2), "required": "wood"}, {"pos": Vector2i(5, 4), "required": "wood"}]
			spec.hint = "EMPURRA MADEIRA ATE AS PLACAS DE MADEIRA; MANTEM-NAS ATIVAS."
		"mechanism":
			spec.name = "OFICINA DO PORTAO"
			spec.hint = "MADEIRA COM MADEIRA, METAL COM METAL: AS DUAS ABREM O PORTAO."
			spec.crates = [{"pos": Vector2i(3, 2), "material": "wood"}, {"pos": Vector2i(3, 4), "material": "metal"}]
			spec.plates = [{"pos": Vector2i(5, 2), "required": "wood"}, {"pos": Vector2i(5, 4), "required": "metal"}]
			for y in range(1, 6):
				if y != 3:
					spec.walls.append(Vector2i(7, y))
			spec.gates = [{"pos": Vector2i(7, 3), "open": false}]
		"circuit":
			spec.name = "PONTE DE ENERGIA"
			spec.hint = "LIGA AS AGUAS COM METAL; O TRIANGULO E A FONTE."
			spec.cells = {Vector2i(5, 2): {"kind": "water", "source": true}, Vector2i(5, 4): {"kind": "water"}}
			spec.crates = [{"pos": Vector2i(3, 3), "material": "metal"}]
			spec.plates = [{"pos": Vector2i(5, 4), "required": "powered"}]
		_:
			return {}
	var flip_x := posmod(seed_number + floor_number, 2) == 1
	var flip_y := posmod(seed_number / 3 + floor_number, 2) == 1
	spec.start = _reflect(spec.start, spec.size, flip_x, flip_y)
	spec.portal = _reflect(spec.portal, spec.size, flip_x, flip_y)
	for index in spec.walls.size():
		spec.walls[index] = _reflect(spec.walls[index], spec.size, flip_x, flip_y)
	for group in ["crates", "plates", "gates"]:
		for item in spec[group]:
			item.pos = _reflect(item.pos, spec.size, flip_x, flip_y)
	var cells := {}
	for point in spec.cells:
		cells[_reflect(point, spec.size, flip_x, flip_y)] = spec.cells[point]
	spec.cells = cells
	return spec


static func _reflect(point: Vector2i, size: Vector2i, flip_x: bool, flip_y: bool) -> Vector2i:
	return Vector2i(size.x - 1 - point.x if flip_x else point.x, size.y - 1 - point.y if flip_y else point.y)


static func _index(point: Vector2i, width: int) -> int:
	return point.y * width + point.x


static func _point(index: int, width: int) -> Vector2i:
	return Vector2i(index % width, index / width)


static func _inside_floor(point: Vector2i, size: Vector2i, walls: Dictionary) -> bool:
	return point.x > 0 and point.y > 0 and point.x < size.x - 1 and point.y < size.y - 1 and not walls.has(point)


# BFS over (player cell, crate cells). It follows the same material, powered
# water, held-plate and gate rules, and rejects any route that crosses live
# water without a shield. No enemies, currents or traps exist in these rooms.
# A bounded search returns an explicit 'truncated' status, not false solvability.
static func solve(spec: Dictionary, start: Vector2i, current_crates: Array) -> Dictionary:
	var size: Vector2i = spec.size
	if current_crates.is_empty() or current_crates.size() > 2:
		return {"length": -1, "step": Vector2i.ZERO, "path": [], "truncated": false}
	var walls := {}
	for point in spec.walls:
		walls[point] = true
	var env = Rules.new()
	env.reset({"cells": spec.cells, "crates": current_crates, "plates": spec.plates, "gates": spec.gates})
	var initial := Vector3i(_index(start, size.x), _index(env.crates[0].pos, size.x), _index(env.crates[1].pos, size.x) if env.crates.size() > 1 else -1)
	var queue: Array[Vector3i] = [initial]
	var parent := {initial: initial}
	var actions := {}
	var head := 0
	var goal := initial
	var found := false
	while head < queue.size() and queue.size() <= MAX_SEARCH_STATES:
		var state: Vector3i = queue[head]
		head += 1
		var player := _point(state.x, size.x)
		env.crates[0].pos = _point(state.y, size.x)
		if env.crates.size() > 1:
			env.crates[1].pos = _point(state.z, size.x)
		env.refresh_electricity()
		for gate in env.gates:
			gate.open = false
		var enemies: Array[Vector2i] = []
		var active: bool = env.update_mechanisms(player, enemies)
		if player == spec.portal and active:
			goal = state
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = player + direction
			if not _inside_floor(next, size, walls):
				continue
			var blocked_gate := false
			for gate in env.gates:
				if gate.pos == next and not gate.open:
					blocked_gate = true
			if blocked_gate:
				continue
			var crate_index: int = env.crate_index_at(next)
			var next_a := state.y
			var next_b := state.z
			if crate_index >= 0:
				var destination: Vector2i = next + direction
				if not _inside_floor(destination, size, walls) or env.is_blocked(destination):
					continue
				env.crates[crate_index].pos = destination
				env.refresh_electricity()
				var shock: bool = env.is_electrified(next)
				env.crates[crate_index].pos = next
				env.refresh_electricity()
				if shock:
					continue
				if crate_index == 0:
					next_a = _index(destination, size.x)
				else:
					next_b = _index(destination, size.x)
			elif env.is_electrified(next):
				continue
			var following := Vector3i(_index(next, size.x), next_a, next_b)
			if not parent.has(following):
				parent[following] = state
				actions[following] = direction
				queue.append(following)
	if not found:
		return {"length": -1, "step": Vector2i.ZERO, "path": [], "truncated": queue.size() > MAX_SEARCH_STATES, "states": queue.size()}
	var path: Array[Vector2i] = []
	while goal != initial:
		path.append(actions[goal])
		goal = parent[goal]
	path.reverse()
	return {"length": path.size(), "step": path[0] if not path.is_empty() else Vector2i.ZERO, "path": path, "truncated": false, "states": queue.size()}
