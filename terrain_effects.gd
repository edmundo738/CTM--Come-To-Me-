extends Node2D

# The animated parts between the three retained terrain layers. Redrawing
# these does not invalidate the static floor, shadows or walls.
var game: Node
var terrain: Node
var is_underlay := false


func _draw() -> void:
	if game == null or game.world_size == Vector2i.ZERO:
		return
	var view: Rect2 = game._visible_world_rect()
	if is_underlay:
		# Authored water/ice can carry turn rules; legacy biome tiles remain visual.
		var water_view := view.grow(game.CELL * 1.5)
		for point in terrain.water_cells:
			if not water_view.has_point(game._cell_center(point)):
				continue
			var top_left: Vector2 = Vector2(point) * game.CELL
			if game._surface_kind(point) == "ice":
				game._draw_ice_tile(self, point, top_left)
			elif game.mechanism_presentation.water_is_animating(point):
				game._draw_water_transition_tile(self, point, top_left, game.mechanism_presentation.water_amount(point, true))
			else:
				game._draw_water_tile(self, point, top_left)
			if game.environment.cells.has(point):
				# Hazard is always drawn from the current rule, never a fading ghost.
				game._draw_environment_surface(self, point, top_left)
		# Removed water lives here only as fading art; it is not a second board
		# and cannot conduct electricity or affect movement or collision.
		for point in game.mechanism_presentation.water:
			if not game._inside(point) or game.grid[point.y][point.x] == game.TILE_WATER:
				continue
			if water_view.has_point(game._cell_center(point)):
				game._draw_water_transition_tile(self, point, Vector2(point) * game.CELL, game.mechanism_presentation.water_amount(point, false))
		for nav in game.nav_chevrons:
			if view.grow(48.0).has_point(game._cell_center(nav.pos)):
				game._draw_nav_chevron(self, nav.pos, nav.dir, terrain.palette)
		return
	game._draw_floor_neon_glow(self, view)
	game._draw_surface_reactions(self, view)
	if game.turn_pulse_time >= 0.0:
		var progress: float = clampf(game.turn_pulse_time / 0.28, 0.0, 1.0)
		draw_arc(game.turn_pulse_position, 8.0 + progress * 24.0, 0.0, TAU, 40, Color("82f4ff", 0.30 * (1.0 - progress)), 1.4, true)
	game._draw_blood_puddle(self)
	var ground_view := view.grow(48.0)
	for trap in game.traps:
		if ground_view.has_point(game._cell_center(trap.pos)):
			game._draw_trap(self, trap)
	for item in game.switches:
		var visibility: float = game.mechanism_presentation.switch_visibility(item.pos, bool(item.get("hidden", false)))
		if visibility > 0.001 and ground_view.has_point(game._cell_center(item.pos)):
			game._draw_switch(self, item, visibility)
	for plate in game.environment.plates:
		if ground_view.has_point(game._cell_center(plate.pos)):
			game._draw_environment_plate(self, plate)
