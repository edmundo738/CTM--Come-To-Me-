extends RefCounted

# Simple Tiled Model: each tile is a four-bit set of open passages.
# North/east/south/west are bits 1/2/4/8; matching edges must agree.
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BITS := [1, 2, 4, 8]
const OPPOSITE_BITS := [4, 8, 1, 2]
# Bitsets of tiles with an open edge in each direction. A domain is itself a
# 16-bit set of tile IDs, not a single tile's four-bit passage mask.
const OPEN_TILE_MASKS := [0xAAAA, 0xCCCC, 0xF0F0, 0xFF00]
const OPPOSITE_OPEN_TILE_MASKS := [0xF0F0, 0xFF00, 0xAAAA, 0xCCCC]
const WEIGHTS := [0.85, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.20, 0.20]
const MAX_RESTARTS := 5
const ROOM_PROFILES := [
	{"base": 3, "scale": 180.0, "min_rooms": 4, "max_rooms": 12, "min_w": 5, "max_w": 8, "min_h": 4, "max_h": 7, "min_link": 2, "max_link": 3, "loops": 0.16},
	{"base": 5, "scale": 165.0, "min_rooms": 5, "max_rooms": 14, "min_w": 4, "max_w": 7, "min_h": 4, "max_h": 6, "min_link": 1, "max_link": 2, "loops": 0.23},
	{"base": 2, "scale": 235.0, "min_rooms": 4, "max_rooms": 8, "min_w": 7, "max_w": 11, "min_h": 5, "max_h": 9, "min_link": 2, "max_link": 3, "loops": 0.14},
	{"base": 4, "scale": 175.0, "min_rooms": 5, "max_rooms": 12, "min_w": 5, "max_w": 9, "min_h": 5, "max_h": 8, "min_link": 2, "max_link": 4, "loops": 0.22},
	{"base": 3, "scale": 210.0, "min_rooms": 5, "max_rooms": 10, "min_w": 7, "max_w": 12, "min_h": 6, "max_h": 9, "min_link": 2, "max_link": 3, "loops": 0.25},
]

var rng := RandomNumberGenerator.new()
var last_attempts := 0
var last_failure := ""
var entropy_table := PackedFloat32Array()


func _init() -> void:
	entropy_table.resize(65536)
	entropy_table.fill(-1.0)


func generate(width: int, height: int, seed_value: int, profile: int = 0) -> Dictionary:
	rng.seed = seed_value
	profile = clampi(profile, 0, ROOM_PROFILES.size() - 1)
	last_failure = ""
	for attempt in MAX_RESTARTS:
		last_attempts = attempt + 1
		var domains: Array = []
		for y in height:
			for x in width:
				var domain := 65535
				for tile in 16:
					if not _fits_boundary(tile, x, y, width, height):
						domain &= ~(1 << tile)
				domains.append(domain)
		if _solve(domains, width, height):
			var layout: Array = []
			var tile_map: Array = []
			for y in height:
				var row: Array[int] = []
				var tile_row: Array[int] = []
				for x in width:
					var tile := _single_tile(domains[y * width + x])
					tile_row.append(tile)
					row.append(0 if tile == 0 else 1)
				layout.append(row)
				tile_map.append(tile_row)
			var graph_layout := _construct_room_graph(layout, width, height, profile)
			return {"ok": true, "grid": graph_layout.grid, "tiles": tile_map, "rooms": graph_layout.rooms, "edges": graph_layout.edges, "start": graph_layout.start, "goal": graph_layout.goal, "attempts": attempt + 1, "seed": seed_value}
		last_failure = "Contradicao de adjacencia no intento %d" % (attempt + 1)
	return {"ok": false, "grid": [], "attempts": MAX_RESTARTS, "seed": seed_value, "reason": last_failure}


func _solve(domains: Array, width: int, height: int) -> bool:
	var total := width * height
	# One deterministic tie-break value per cell avoids drawing a new random
	# number for every still-open cell on every collapse.
	var noise := PackedFloat32Array()
	noise.resize(total)
	var open: Array[int] = []
	for index in total:
		noise[index] = rng.randf() * 0.0001
		var options: int = domains[index]
		if options == 0:
			return false
		if (options & (options - 1)) != 0:
			open.append(index)
	while true:
		var chosen_slot := -1
		var best_entropy := INF
		var write := 0
		for read in open.size():
			var index: int = open[read]
			var options: int = domains[index]
			if options == 0:
				return false
			if (options & (options - 1)) == 0:
				continue
			open[write] = index
			var entropy: float = entropy_table[options]
			if entropy < 0.0:
				entropy = _entropy(options)
			entropy += noise[index]
			if entropy < best_entropy:
				best_entropy = entropy
				chosen_slot = write
			write += 1
		open.resize(write)
		if chosen_slot == -1:
			return true
		var chosen: int = open[chosen_slot]
		var collapsed := _weighted_choice(domains[chosen])
		domains[chosen] = 1 << collapsed
		if not _propagate(domains, width, height, chosen):
			return false
	return false


func _propagate(domains: Array, width: int, height: int, origin: int) -> bool:
	var queue: Array[int] = [origin]
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % width
		var y := index / width
		var source: int = domains[index]
		for direction in 4:
			var neighbor: Vector2i = Vector2i(x, y) + DIRS[direction]
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			var neighbor_index: int = neighbor.y * width + neighbor.x
			var target: int = domains[neighbor_index]
			var kept: int = target & _support(direction, source)
			if kept != target:
				if kept == 0:
					return false
				domains[neighbor_index] = kept
				queue.append(neighbor_index)
	return true


# All neighbour tiles compatible with at least one tile in the source domain.
# Matching depends only on whether an edge is open, so this is O(1) rather
# than checking all 16 x 16 pairs. An empty source correctly supports nothing.
func _support(direction: int, source: int) -> int:
	var source_open: int = OPEN_TILE_MASKS[direction]
	var target_open: int = OPPOSITE_OPEN_TILE_MASKS[direction]
	var supported := 0
	if (source & source_open) != 0:
		supported |= target_open
	if (source & (0xFFFF ^ source_open)) != 0:
		supported |= 0xFFFF ^ target_open
	return supported


func _edges_match(first: int, second: int, direction: int) -> bool:
	return ((first & BITS[direction]) != 0) == ((second & OPPOSITE_BITS[direction]) != 0)


func _fits_boundary(tile: int, x: int, y: int, width: int, height: int) -> bool:
	if y == 0 and (tile & BITS[0]) != 0: return false
	if x == width - 1 and (tile & BITS[1]) != 0: return false
	if y == height - 1 and (tile & BITS[2]) != 0: return false
	if x == 0 and (tile & BITS[3]) != 0: return false
	return true


func _entropy(options: int) -> float:
	if entropy_table[options] >= 0.0:
		return entropy_table[options]
	var sum_weights := 0.0
	var sum_weight_logs := 0.0
	for tile in 16:
		if (options & (1 << tile)) == 0:
			continue
		var weight: float = WEIGHTS[tile]
		sum_weights += weight
		sum_weight_logs += weight * log(weight)
	var result := log(sum_weights) - sum_weight_logs / sum_weights
	entropy_table[options] = result
	return entropy_table[options]


func _weighted_choice(options: int) -> int:
	var sum_weights := 0.0
	for tile in 16:
		if (options & (1 << tile)) != 0:
			sum_weights += WEIGHTS[tile]
	var draw := rng.randf() * sum_weights
	for tile in 16:
		if (options & (1 << tile)) == 0:
			continue
		draw -= WEIGHTS[tile]
		if draw <= 0.0:
			return tile
	return _single_tile(options)


func _single_tile(options: int) -> int:
	for tile in 16:
		if (options & (1 << tile)) != 0:
			return tile
	return 0


func _construct_room_graph(base_grid: Array, width: int, height: int, profile: int = 0) -> Dictionary:
	var layout: Array = []
	for row in base_grid:
		layout.append(row.duplicate())
	for x in width:
		layout[0][x] = 1
		layout[height - 1][x] = 1
	for y in height:
		layout[y][0] = 1
		layout[y][width - 1] = 1
	var rooms: Array[Dictionary] = []
	var shape: Dictionary = ROOM_PROFILES[clampi(profile, 0, ROOM_PROFILES.size() - 1)]
	var desired := clampi(int(shape.base + float(width * height) / float(shape.scale)), int(shape.min_rooms), int(shape.max_rooms))
	if profile == 4:
		var arena_size := Vector2i(mini(int(shape.max_w), width - 8), mini(int(shape.max_h), height - 8))
		var arena_position := Vector2i((width - arena_size.x) / 2, (height - arena_size.y) / 2)
		var arena_rect := Rect2i(arena_position, arena_size)
		rooms.append({"rect": arena_rect, "center": Vector2i(arena_rect.position.x + arena_rect.size.x / 2, arena_rect.position.y + arena_rect.size.y / 2)})
	for attempt in desired * 100:
		if rooms.size() >= desired:
			break
		var room_width := rng.randi_range(int(shape.min_w), mini(int(shape.max_w), width - 6))
		var room_height := rng.randi_range(int(shape.min_h), mini(int(shape.max_h), height - 6))
		var rect := Rect2i(rng.randi_range(2, width - room_width - 2), rng.randi_range(2, height - room_height - 2), room_width, room_height)
		var overlaps := false
		for room in rooms:
			if room.rect.grow(1).intersects(rect.grow(1)):
				overlaps = true
				break
		if not overlaps:
			rooms.append({"rect": rect, "center": Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)})
	if rooms.size() < 4:
		rooms.clear()
		var rw := mini(5, width - 6)
		var rh := mini(4, height - 6)
		for y in 2:
			for x in 2:
				var position := Vector2i(2 if x == 0 else width - rw - 2, 2 if y == 0 else height - rh - 2)
				var rect := Rect2i(position, Vector2i(rw, rh))
				rooms.append({"rect": rect, "center": Vector2i(position.x + rw / 2, position.y + rh / 2)})
	for room in rooms:
		var rect: Rect2i = room.rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				layout[y][x] = 0
	var start_index := 0
	var goal_index := 0
	for i in rooms.size():
		if rooms[i].center.x < rooms[start_index].center.x:
			start_index = i
		if rooms[i].center.x > rooms[goal_index].center.x:
			goal_index = i
	var connected: Array[int] = [start_index]
	var edges: Array[Dictionary] = []
	var edge_keys: Dictionary = {}
	while connected.size() < rooms.size():
		var best_distance := 2147483647
		var best_from := -1
		var best_to := -1
		for from_index in connected:
			for to_index in rooms.size():
				if connected.has(to_index):
					continue
				var from_pos: Vector2i = rooms[from_index].center
				var to_pos: Vector2i = rooms[to_index].center
				var distance: int = abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y)
				if distance < best_distance:
					best_distance = distance
					best_from = from_index
					best_to = to_index
		if best_to < 0:
			break
		connected.append(best_to)
		edge_keys[_edge_key(best_from, best_to)] = true
		edges.append({"from": best_from, "to": best_to, "main": true})
		_carve_corridor(layout, rooms[best_from].center, rooms[best_to].center, rng.randi_range(int(shape.min_link), int(shape.max_link)))
	for a in rooms.size():
		for b in range(a + 1, rooms.size()):
			if edge_keys.has(_edge_key(a, b)) or rng.randf() > float(shape.loops):
				continue
			edges.append({"from": a, "to": b, "main": false})
			_carve_corridor(layout, rooms[a].center, rooms[b].center, 2)
	return {"grid": layout, "rooms": rooms, "edges": edges, "start": rooms[start_index].center, "goal": rooms[goal_index].center}


func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


func _carve_corridor(layout: Array, first: Vector2i, second: Vector2i, width: int) -> void:
	var point := first
	var move_horizontal_first := rng.randf() < 0.5
	while point != second:
		var can_x := point.x != second.x
		var can_y := point.y != second.y
		var use_x := can_x and (not can_y or move_horizontal_first)
		if use_x:
			point.x += signi(second.x - point.x)
		else:
			point.y += signi(second.y - point.y)
		for offset in width:
			var side := offset - (width - 1) / 2
			var cell := point + (Vector2i(0, side) if use_x else Vector2i(side, 0))
			if cell.x > 0 and cell.x < layout[0].size() - 1 and cell.y > 0 and cell.y < layout.size() - 1:
				layout[cell.y][cell.x] = 0
