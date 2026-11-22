extends Node2D

const Chunk = preload("res://terrain_chunk.gd")
const Effects = preload("res://terrain_effects.gd")
const CHUNK_SIZE := 6

var game: Node
var palette: Dictionary = {}
var water_cells: Array[Vector2i] = []
# Keys are chunk coordinates; values contain floor, shadow and wall CanvasItems.
var chunks: Dictionary = {}
var underlay: Node2D
var ground: Node2D
var _loaded_bounds := Rect2i(-1, -1, 0, 0)


func setup(owner_game: Node) -> void:
	game = owner_game
	underlay = Effects.new()
	underlay.game = game
	underlay.terrain = self
	underlay.is_underlay = true
	underlay.z_index = -4
	add_child(underlay)
	ground = Effects.new()
	ground.game = game
	ground.terrain = self
	ground.z_index = -2
	add_child(ground)


func rebuild() -> void:
	# Detach old lists immediately so they cannot be drawn with the new grid.
	for layers in chunks.values():
		for chunk in layers:
			remove_child(chunk)
			chunk.queue_free()
	chunks.clear()
	_loaded_bounds = Rect2i(-1, -1, 0, 0)
	palette = game._get_biome_palette(game.get_biome_index(game.floor_number))
	water_cells.clear()
	for y in game.world_size.y:
		for x in game.world_size.x:
			if game.grid[y][x] == game.TILE_WATER:
				water_cells.append(Vector2i(x, y))
	underlay.queue_redraw()
	ground.queue_redraw()


func sync_view(view: Rect2, draw_world: bool) -> void:
	# These menus have an opaque cinematic background; the world would be
	# entirely covered. Paused/result/capture screens still show it as before.
	# Alpha zero lets the renderer skip this subtree without show()/hide(),
	# which would queue a redraw for every cached child on returning to play.
	var alpha := 1.0 if draw_world else 0.0
	if modulate.a != alpha:
		modulate = Color(1.0, 1.0, 1.0, alpha)
	if not draw_world or game.world_size == Vector2i.ZERO:
		return
	var margin: float = game.CELL * 2.0
	var expanded := view.grow(margin)
	var chunk_pixels: float = float(CHUNK_SIZE * game.CELL)
	var first := Vector2i(maxi(0, floori(expanded.position.x / chunk_pixels)), maxi(0, floori(expanded.position.y / chunk_pixels)))
	var max_chunk := Vector2i((game.world_size.x - 1) / CHUNK_SIZE, (game.world_size.y - 1) / CHUNK_SIZE)
	var last := Vector2i(mini(max_chunk.x, floori(expanded.end.x / chunk_pixels)), mini(max_chunk.y, floori(expanded.end.y / chunk_pixels)))
	var bounds := Rect2i(first, Vector2i(maxi(0, last.x - first.x + 1), maxi(0, last.y - first.y + 1)))
	if bounds != _loaded_bounds:
		_loaded_bounds = bounds
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				_ensure_chunk(Vector2i(x, y))
	underlay.queue_redraw()
	ground.queue_redraw()


func _ensure_chunk(key: Vector2i) -> void:
	if chunks.has(key):
		return
	var start := key * CHUNK_SIZE
	var cell_size := Vector2i(mini(CHUNK_SIZE, game.world_size.x - start.x), mini(CHUNK_SIZE, game.world_size.y - start.y))
	var rect := Rect2i(start, cell_size)
	var layers: Array[Node2D] = []
	for kind in 3:
		var chunk := Chunk.new()
		chunk.setup(game, rect, palette, kind)
		add_child(chunk)
		layers.append(chunk)
	chunks[key] = layers


func invalidate_cell(point: Vector2i) -> void:
	# Breaking a wall also changes adjacent floor shadows and the fronts/tube
	# connections of walls above and either side. Invalidate only those chunks.
	var affected: Dictionary = {}
	for y in range(point.y - 1, point.y + 2):
		for x in range(point.x - 1, point.x + 2):
			if x < 0 or y < 0 or x >= game.world_size.x or y >= game.world_size.y:
				continue
			var key := Vector2i(x / CHUNK_SIZE, y / CHUNK_SIZE)
			if chunks.has(key):
				affected[key] = true
	for key in affected:
		for chunk in chunks[key]:
			chunk.queue_redraw()
