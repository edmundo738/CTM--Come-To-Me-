extends SceneTree

# Geometry and wall orientation are presentation only. Rendered appearance
# still needs a real renderer and human assessment; this test is not one.
const Game = preload("res://game.gd")
const Installation = preload("res://submerged_installation.gd")
const SpecialLevels = preload("res://special_levels.gd")

var game: Node
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.audio.stop_all()
	await process_frame

	# Actual authored gap: the wall above and below is continuous, while the
	# other two cells are floor. Its direction is independent of the leaf state.
	game.start_environment_lab(3)
	var gate: Vector2i = game.environment.gates[0].pos
	_expect(gate == Vector2i(8, 4), "two-plate gate stays in its original gap")
	_expect(game._is_wall(gate + Vector2i.UP) and game._is_wall(gate + Vector2i.DOWN), "two-plate wall continues on both vertical sides")
	_expect(not game._is_wall(gate + Vector2i.LEFT) and not game._is_wall(gate + Vector2i.RIGHT), "two-plate opening connects the floor on both horizontal sides")
	_expect(game._gate_in_vertical_wall(gate), "closed gate follows the vertical wall")
	_expect(not game._is_floor(gate), "closed gate remains logically blocked")
	game.environment.crates[0].pos = game.environment.plates[0].pos
	game.environment.crates[1].pos = game.environment.plates[1].pos
	game._sync_environment_mechanisms()
	_expect(bool(game.environment.gates[0].open) and game._is_floor(gate), "real plate activation opens the unchanged logical gate")
	_expect(game._gate_in_vertical_wall(gate), "open gate keeps its wall axis")

	game.start_environment_lab(Installation.LAB_INDEX)
	for door in game.environment.gates:
		var point: Vector2i = door.pos
		_expect(game._is_wall(point + Vector2i.LEFT) and game._is_wall(point + Vector2i.RIGHT), "installation gate %s is in a horizontal wall" % door.id)
		_expect(not game._gate_in_vertical_wall(point), "installation gate %s follows its horizontal wall" % door.id)

	# Reflected campaign versions of the two-plate workshop must retain the
	# same vertical orientation on both sides of the map.
	var reflected_positions: Array[Vector2i] = []
	for seed_number in range(6):
		var spec: Dictionary = SpecialLevels.make("mechanism", seed_number, 12)
		game.world_size = spec.size
		game.grid.clear()
		for y in game.world_size.y:
			var row: Array[int] = []
			for x in game.world_size.x:
				row.append(game.TILE_BORDER if x == 0 or y == 0 or x == game.world_size.x - 1 or y == game.world_size.y - 1 else game.TILE_FLOOR)
			game.grid.append(row)
		for wall in spec.walls:
			game.grid[wall.y][wall.x] = game.TILE_WALL
		var point: Vector2i = spec.gates[0].pos
		if not reflected_positions.has(point):
			reflected_positions.append(point)
		_expect(game._is_wall(point + Vector2i.UP) and game._is_wall(point + Vector2i.DOWN), "reflected workshop retains its real wall gap")
		_expect(game._gate_in_vertical_wall(point), "reflected workshop gate follows the vertical wall")
	_expect(reflected_positions.size() == 2, "reflections cover both sides of the workshop")

	# Partial wall at a T/end is enough to choose an axis; ties fall back to
	# the original horizontal representation rather than changing any rule.
	game.start_environment_lab(Installation.LAB_INDEX)
	var probe := Vector2i(12, 9)
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		game.grid[probe.y + d.y][probe.x + d.x] = game.TILE_FLOOR
	game.grid[probe.y - 1][probe.x] = game.TILE_WALL
	_expect(game._gate_in_vertical_wall(probe), "one vertical wall neighbor determines the axis")
	game.grid[probe.y - 1][probe.x] = game.TILE_FLOOR
	game.grid[probe.y][probe.x - 1] = game.TILE_WALL
	_expect(not game._gate_in_vertical_wall(probe), "one horizontal wall neighbor determines the axis")
	game.grid[probe.y - 1][probe.x] = game.TILE_WALL
	_expect(not game._gate_in_vertical_wall(probe), "ambiguous tie falls back to horizontal")

	for center in [Vector2.ZERO, Vector2(120.5, 80.25), Vector2(-50, 700)]:
		var crate_top: Rect2 = game._crate_top_rect(center)
		_expect(is_equal_approx(crate_top.size.x, crate_top.size.y), "crate and generator top remains square at %s" % center)
		for value in [-1.0, 0.0, 0.5, 1.0, 2.0]:
			var plate_top: Rect2 = game._plate_surface_rect(center, value)
			_expect(is_equal_approx(plate_top.size.x, plate_top.size.y), "plate top stays square at compression %s" % value)
		_expect(game._plate_surface_rect(center, 0).position.y < game._plate_surface_rect(center, 1).position.y, "plate visually settles when pressed")
		_expect(game._plate_surface_rect(center, -1) == game._plate_surface_rect(center, 0), "plate compression clamps below zero")
		_expect(game._plate_surface_rect(center, 2) == game._plate_surface_rect(center, 1), "plate compression clamps above one")

	if failures.is_empty():
		print("MECHANISM_GEOMETRY_TEST_PASS checks=", checks, " authored wall axes, square tops, plate travel and unchanged gate collision")
	else:
		printerr("MECHANISM_GEOMETRY_TEST_FAIL count=", failures.size(), " checks=", checks)
	game.persistence_enabled = false
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
