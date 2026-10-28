extends RefCounted

# Simple Tiled Model: each tile is a four-bit set of open passages.
# North/east/south/west are bits 1/2/4/8; matching edges must agree.
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BITS := [1, 2, 4, 8]
const OPPOSITE_BITS := [4, 8, 1, 2]
const WEIGHTS := [0.85, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.42, 0.20, 0.20]
const MAX_RESTARTS := 5

var rng := RandomNumberGenerator.new()
var last_attempts := 0
var last_failure := ""
var entropy_cache: Dictionary = {}


func generate(width: int, height: int, seed_value: int) -> Dictionary:
	rng.seed = seed_value
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
			var graph_layout := _construct_room_graph(layout, width, height)
			return {"ok": true, "grid": graph_layout.grid, "tiles": tile_map, "rooms": graph_layout.rooms, "edges": graph_layout.edges, "start": graph_layout.start, "goal": graph_layout.goal, "attempts": attempt + 1, "seed": seed_value}
		last_failure = "Contradicao de adjacencia no intento %d" % (attempt + 1)
	return {"ok": false, "grid": [], "attempts": MAX_RESTARTS, "seed": seed_value, "reason": last_failure}


func _solve(domains: Array, width: int, height: int) -> bool:
	var total := width * height
	while true:
		var chosen := -1
		var best_entropy := INF
		for index in total:
			var options: int = domains[index]
			if options == 0:
				return false
			if _popcount(options) <= 1:
				continue
			var entropy := _entropy(options) + rng.randf() * 0.0001
			if entropy < best_entropy:
				best_entropy = entropy
				chosen = index
		if chosen == -1:
			return true
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
		for direction in 4:
			var neighbor: Vector2i = Vector2i(x, y) + DIRS[direction]
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			var neighbor_index: int = neighbor.y * width + neighbor.x
			var source: int = domains[index]
			var target: int = domains[neighbor_index]
			var kept := 0
			for target_tile in 16:
				if (target & (1 << target_tile)) == 0:
					continue
				var supported := false
				for source_tile in 16:
					if (source & (1 << source_tile)) == 0:
						continue
					if _edges_match(source_tile, target_tile, direction):
						supported = true
						break
				if supported:
					kept |= 1 << target_tile
			if kept != target:
				if kept == 0:
					return false
				domains[neighbor_index] = kept
				queue.append(neighbor_index)
	return true


func _edges_match(first: int, second: int, direction: int) -> bool:
	return ((first & BITS[direction]) != 0) == ((second & OPPOSITE_BITS[direction]) != 0)


func _fits_boundary(tile: int, x: int, y: int, width: int, height: int) -> bool:
	if y == 0 and (tile & BITS[0]) != 0: return false
	if x == width - 1 and (tile & BITS[1]) != 0: return false
	if y == height - 1 and (tile & BITS[2]) != 0: return false
	if x == 0 and (tile & BITS[3]) != 0: return false
	return true


func _entropy(options: int) -> float:
	if entropy_cache.has(options):
		return entropy_cache[options]
	var sum_weights := 0.0
	var sum_weight_logs := 0.0
	for tile in 16:
		if (options & (1 << tile)) == 0:
			continue
		var weight: float = WEIGHTS[tile]
		sum_weights += weight
		sum_weight_logs += weight * log(weight)
	var result := log(sum_weights) - sum_weight_logs / sum_weights
	entropy_cache[options] = result
	return result


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


func _popcount(options: int) -> int:
	var result := 0
	for tile in 16:
		if (options & (1 << tile)) != 0:
			result += 1
	return result


func _single_tile(options: int) -> int:
	for tile in 16:
		if (options & (1 << tile)) != 0:
			return tile
	return 0


func _construct_room_graph(base_grid: Array, width: int, height: int) -> Dictionary:
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
	var desired := clampi(3 + int(float(width * height) / 180.0), 4, 12)
	for attempt in desired * 100:
		if rooms.size() >= desired:
			break
		var room_width := rng.randi_range(5, mini(8, width - 6))
		var room_height := rng.randi_range(4, mini(7, height - 6))
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
		_carve_corridor(layout, rooms[best_from].center, rooms[best_to].center, rng.randi_range(2, 3))
	for a in rooms.size():
		for b in range(a + 1, rooms.size()):
			if edge_keys.has(_edge_key(a, b)) or rng.randf() > 0.16:
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
