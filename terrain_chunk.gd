extends Node2D

# One retained display list for a small rectangle of the map. Floors, wall
# shadows and walls are separate CanvasItems so animated ground effects retain
# their original ordering between them. Positions are chunk-local; adjacency
# and deterministic decoration still use the global grid coordinates.
const FLOOR := 0
const SHADOW := 1
const WALL := 2

var game: Node
var cells := Rect2i()
var palette: Dictionary = {}
var layer_kind := FLOOR
var redraw_count := 0


func setup(owner_game: Node, rect: Rect2i, biome_palette: Dictionary, kind: int) -> void:
	game = owner_game
	cells = rect
	palette = biome_palette
	layer_kind = kind
	position = Vector2(cells.position) * game.CELL
	z_index = [-5, -3, -1][kind]


func _draw() -> void:
	redraw_count += 1
	if game == null:
		return
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var point := Vector2i(x, y)
			var top_left: Vector2 = Vector2(point - cells.position) * game.CELL
			var tile: int = game.grid[y][x]
			match layer_kind:
				FLOOR:
					if tile == game.TILE_FLOOR or tile == game.TILE_WATER:
						game._draw_floor_tile(self, point, top_left, palette)
						if tile == game.TILE_WATER:
							if game._surface_kind(point) == "ice":
								game._draw_ice_base(self, point, top_left)
							else:
								game._draw_water_base(self, point, top_left)
				SHADOW:
					if tile == game.TILE_FLOOR or tile == game.TILE_WATER:
						game._draw_floor_shadows(self, point, top_left)
				WALL:
					if tile == game.TILE_WALL or tile == game.TILE_BORDER:
						game._draw_wall_tile(self, point, top_left, palette, tile == game.TILE_BORDER)
