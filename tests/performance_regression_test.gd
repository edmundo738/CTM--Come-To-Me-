extends SceneTree

const GameScript = preload("res://game.gd")
const Generator = preload("res://level_generator.gd")
const Terrain = preload("res://terrain_renderer.gd")
# Captured from f3513b5 with the benchmark below: includes later traps and
# both RNG states, not just the room layout. In particular, seed 48211 on
# floor 1000 exhausts all available coin cells before 1008 attempts.
const BASELINE_FINGERPRINTS := {
	"1:12900": "e69284a6b7e55b3a711a31c6fdf2a03d1f3feefa987e65e0b0b9ae8fa373b68a",
	"2:48211": "c69cdd5b9a73f099b59e0711a5464dec8961f35ee52d706b935ca633c44bb78f",
	"3:12900": "d9afc10b4c9a8c76f9e7e5fdd27113d7939dd6d5394721e2a8b4e2fe7bc14e41",
	"4:48211": "6e281cd7d51d1ae0079d554991f8046e66973e38265a108d7e4243d9bc706450",
	"5:77123": "de0a45043ab20eba2d41a4bbf61eb136bd9fe7bbd5c99f9f31e282ef8d4325ff",
	"15:12900": "f4277378537d5cb77d6aa025ddb9e38e46d33a87886a4b09489fb77cf8b7de6f",
	"30:77123": "b3ee19c24a0cb280ee6a8dc9735a8a8333c7e8f14965cc3dafe4f663beb86ccf",
	"100:12900": "d8195b2d7b378fa52fa666de626ca8b9d8def9282b99426c566678547f834e61",
	"200:48211": "b6d53d17a429640771f3996f0e8d8d883421ba8368111d5495391c79ae96ed74",
	"1000:12900": "61df707408757e7437e8f12017083f72716e54e44ccb63b3052ee2872ec78c6f",
	"1000:48211": "6141101e8f232d38acff5a941bd10e99d6d83abac15e81c4fb62579da94892dc",
}
var failures: Array[String] = []

# Counts actual draw callbacks in the headless CanvasItem pipeline. This does
# not inspect pixels or measure the GPU; visual validation still needs a display.
class DrawProbe:
	extends "res://game.gd"
	var water_draws := 0
	var ice_draws := 0
	var coin_draws: Array[Vector2i] = []

	func _draw_water_tile(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
		water_draws += 1
		super._draw_water_tile(target, point, top_left)

	func _draw_ice_tile(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
		ice_draws += 1
		super._draw_ice_tile(target, point, top_left)

	func _draw_coin(point: Vector2i) -> void:
		coin_draws.append(point)
		super._draw_coin(point)


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _domain_grid(generator: RefCounted, size: Vector2i) -> Array:
	# Construct the old boundary condition independently of the optimized one.
	var domains: Array = []
	for y in size.y:
		for x in size.x:
			var domain := 0
			for tile in 16:
				if generator._fits_boundary(tile, x, y, size.x, size.y):
					domain |= 1 << tile
			domains.append(domain)
	return domains


func _test_solver_equivalence() -> void:
	var scan = Generator.new()
	var heap = Generator.new()
	for size in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(8, 7), Vector2i(19, 15), Vector2i(43, 27)]:
		for seed_value in [17, 2718, 48211]:
			var original := _domain_grid(scan, size)
			var optimized := original.duplicate()
			scan.rng.seed = seed_value
			heap.rng.seed = seed_value
			scan._heap_active = false
			heap._heap_active = true
			var old_ok: bool = scan._solve_scan(original, size.x, size.y)
			var new_ok: bool = heap._solve_heap(optimized, size.x, size.y)
			_expect(old_ok == new_ok and original == optimized and scan.rng.state == heap.rng.state, "heap matches row-major WFC and RNG for %s, seed %d" % [size, seed_value])
	# Explicitly cover an initial contradiction and its partial RNG consumption.
	var impossible: Array = [65535, 0, 65535, 65535]
	var same := impossible.duplicate()
	scan.rng.seed = 42
	heap.rng.seed = 42
	scan._heap_active = false
	heap._heap_active = true
	_expect(not scan._solve_scan(impossible, 2, 2) and not heap._solve_heap(same, 2, 2) and scan.rng.state == heap.rng.state, "both solvers consume RNG identically on contradiction")


func _old_pick(cells: Array[Vector2i], occupied: Dictionary, distance: int, rng: RandomNumberGenerator) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for point in cells:
		if occupied.has(point):
			continue
		var far_enough := true
		for other in occupied:
			if absi(point.x - other.x) + absi(point.y - other.y) < distance:
				far_enough = false
				break
		if far_enough:
			candidates.append(point)
	if candidates.is_empty():
		for point in cells:
			if not occupied.has(point):
				candidates.append(point)
	return Vector2i(-1, -1) if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]


func _test_item_equivalence() -> void:
	var game = GameScript.new()
	var cells: Array[Vector2i] = []
	for y in 12:
		for x in 14:
			cells.append(Vector2i(x, y))
	for count in [0, 1, 40, 200]:
		var previous: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 1): true}
		var current := previous.duplicate()
		var old_coins: Array[Vector2i] = []
		var old_rng := RandomNumberGenerator.new()
		old_rng.seed = 500 + count
		game.rng.seed = 500 + count
		game.coins.clear()
		for _i in count:
			var point := _old_pick(cells, previous, 1, old_rng)
			if point != Vector2i(-1, -1):
				old_coins.append(point)
				previous[point] = true
		game._place_coins(cells, current, count)
		_expect(game.coins == old_coins and current == previous and game.rng.state == old_rng.state, "coin list and RNG remain identical, including exhaustion (%d)" % count)
	# Exercise both the sparse scan and dense local-diamond path, including
	# fallback when no cell can satisfy the requested spacing.
	for occupied_count in [2, 35, 150, 168]:
		for distance in [1, 2, 4, 7, 30]:
			var occupied: Dictionary = {}
			for index in occupied_count:
				occupied[cells[index]] = true
			var old_rng := RandomNumberGenerator.new()
			old_rng.seed = occupied_count * 91 + distance
			game.rng.seed = occupied_count * 91 + distance
			var old_point := _old_pick(cells, occupied, distance, old_rng)
			var new_point: Vector2i = game._pick_spaced(cells, occupied, distance)
			_expect(old_point == new_point and old_rng.state == game.rng.state, "spacing preserves candidate order and RNG (%d, %d)" % [occupied_count, distance])
	game.free()


func _fingerprint(game: Node) -> String:
	# Keep this in sync with tools/performance_benchmark.gd.
	var snapshot := {
		"grid": game.grid, "rooms": game.rooms, "edges": game.room_graph_edges,
		"player": game.player_position, "portal": game.portal_position,
		"objective": game.objective_type, "challenge": game.challenge_kind,
		"par": game.challenge_par, "portal_open": game.portal_open,
		"coins": game.coins, "shields": game.shields, "breakers": game.breakers,
		"powerups": game.powerups, "switches": game.switches, "traps": game.traps,
		"enemies": game.enemies, "nav": game.nav_chevrons,
		"rng": game.rng.state, "wfc_rng": game.generator.rng.state,
	}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(snapshot))
	return context.finish().hex_encode()


func _test_baseline_fingerprints(game: Node) -> void:
	for key in BASELINE_FINGERPRINTS:
		var parts: PackedStringArray = String(key).split(":")
		game.active_seed = int(parts[1])
		game.generate_floor(int(parts[0]))
		_expect(_fingerprint(game) == BASELINE_FINGERPRINTS[key], "floor and RNG match pre-optimization snapshot " + key)


func _counts(terrain: Node) -> Dictionary:
	var result := {}
	for key in terrain.chunks:
		var counts: Array[int] = []
		for chunk in terrain.chunks[key]:
			counts.append(chunk.redraw_count)
		result[key] = counts
	return result


func _wait_frames(count: int = 3) -> void:
	for _i in count:
		await process_frame


func _test_terrain_and_culling(game: DrawProbe) -> void:
	game.game_state = "playing"
	game.active_seed = 12900
	game.generate_floor(200)
	game.player_position = Vector2i(3, 17)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game._update_camera(0.0)
	await _wait_frames()
	var terrain = game.terrain_renderer
	game._update_background_visibility(Rect2(Vector2(100, 100), Vector2(400, 300)), true)
	_expect(not game.background_rect.visible, "full-screen background is skipped behind an opaque map")
	game._update_background_visibility(Rect2(Vector2(-20, 0), Vector2(400, 300)), true)
	_expect(game.background_rect.visible, "background remains visible beyond a world edge")
	game._update_background_visibility(Rect2(Vector2(-20, 0), Vector2(400, 300)), false)
	_expect(not game.background_rect.visible, "opaque menus skip the hidden background")
	var total_chunks := ceili(float(game.world_size.x) / Terrain.CHUNK_SIZE) * ceili(float(game.world_size.y) / Terrain.CHUNK_SIZE)
	_expect(not terrain.chunks.is_empty() and terrain.chunks.size() < total_chunks, "large floor initially caches only chunks near the view")
	var first_counts := _counts(terrain)
	await _wait_frames(6)
	_expect(_counts(terrain) == first_counts, "idle animation does not redraw static terrain")

	var near := Vector2i(3, 17)
	var far := Vector2i(game.world_size.x - 2, game.world_size.y - 2)
	game.coins.assign([near, far])
	game.coin_draws.clear()
	await _wait_frames()
	_expect(game.coin_draws.has(near) and not game.coin_draws.has(far), "offscreen coin is not drawn but a visible coin is")
	_expect(game.coins == [near, far], "culling does not remove gameplay items")
	var view: Rect2 = game._visible_world_rect()
	var enemy := {"pos": far, "from": game._cell_center(far), "to": game._cell_center(far), "t": 1.0, "role": "hunter", "alert": false}
	_expect(not game._enemy_draw_visible(enemy, view), "distant enemy body is culled")
	enemy.role = "warden"
	enemy.alert = true
	_expect(game._enemy_draw_visible(enemy, view), "offscreen alert Warden retains its targeting line and reticle")
	enemy.role = "sentry"
	enemy.alert = true
	enemy.from = Vector2(view.end.x + 110.0, view.get_center().y)
	enemy.to = enemy.from
	_expect(game._enemy_draw_visible(enemy, view), "sentry scan remains visible outside the viewport")
	enemy.from = game._cell_center(far)
	enemy.to = view.get_center()
	enemy.t = 0.9
	_expect(game._enemy_draw_visible(enemy, view), "culling follows interpolated enemy position")

	var normal_size: Vector2 = game._visible_world_rect().size
	game.camera.zoom = Vector2(2.0, 2.0)
	game.camera.force_update_scroll()
	var zoomed: Rect2 = game._visible_world_rect()
	_expect(zoomed.size.x < normal_size.x * 0.6 and zoomed.size.y < normal_size.y * 0.6, "culling follows camera zoom")
	var center_before: Vector2 = zoomed.get_center()
	game.camera.offset = Vector2(40.0, 20.0)
	game.camera.force_update_scroll()
	_expect(game._visible_world_rect().get_center().distance_to(center_before) > 10.0, "culling follows camera shake/offset")
	game.camera.zoom = Vector2.ONE
	game.camera.offset = Vector2.ZERO
	game.camera.force_update_scroll()

	game.player_position = far
	game.player_from = game._cell_center(far)
	game.player_to = game.player_from
	game._update_camera(0.0)
	await _wait_frames()
	_expect(terrain.chunks.size() > first_counts.size(), "camera travel creates additional chunks")
	var after_move := _counts(terrain)
	for key in first_counts:
		_expect(after_move[key] == first_counts[key], "revisiting terrain does not rebuild its retained commands")
	game.game_state = "title"
	await _wait_frames()
	_expect(terrain.modulate.a == 0.0, "opaque menu skips the terrain subtree")
	game.game_state = "playing"
	await _wait_frames()
	_expect(terrain.modulate.a == 1.0 and _counts(terrain) == after_move, "returning from an opaque menu keeps cached chunks")

	# Break a wall exactly where four chunks meet. All affected floors, shadows
	# and neighboring wall fronts must redraw, and distant chunks must not.
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	game.grid[6][6] = game.TILE_WALL
	terrain.rebuild()
	game.player_position = Vector2i(5, 6)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.facing = Vector2i.RIGHT
	game.breach_charges = 1
	game._update_camera(0.0)
	await _wait_frames()
	var before_break := _counts(terrain)
	var affected := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	for key in affected:
		_expect(before_break.has(key), "wall boundary test loaded chunk %s" % key)
	game.try_break_wall()
	await _wait_frames()
	_expect(game.grid[6][6] == game.TILE_FLOOR, "demolition still opens the wall")
	var after_break := _counts(terrain)
	for key in before_break:
		for layer in 3:
			var expected: int = before_break[key][layer] + (1 if key in affected else 0)
			_expect(after_break[key][layer] == expected, "demolition invalidates exactly the affected neighboring chunk layers")


func _test_biomes_and_capture(game: DrawProbe) -> void:
	for floor_number in [2, 4]:
		game.active_seed = 12900
		game.generate_floor(floor_number)
		game.game_state = "playing"
		var terrain = game.terrain_renderer
		var grid_water := 0
		for row in game.grid:
			for tile in row:
				if tile == game.TILE_WATER:
					grid_water += 1
		_expect(grid_water > 0 and terrain.water_cells.size() == grid_water, "all biome landmark cells are indexed")
		if not terrain.water_cells.is_empty():
			game.player_position = terrain.water_cells[0]
			game.player_from = game._cell_center(game.player_position)
			game.player_to = game.player_from
			game.player_anim = 1.0
			game._update_camera(0.0)
		game.water_draws = 0
		game.ice_draws = 0
		await _wait_frames()
		_expect((game.water_draws > 0 and game.ice_draws == 0) if floor_number == 2 else (game.ice_draws > 0 and game.water_draws == 0), "garden uses water and glacier uses ice without changing tile rules")
		_expect(game._is_floor(game.player_position), "visual water/ice remains traversable")
	game._reset_capture_state()
	game._update_capture_overlay()
	_expect(not game.capture_overlay.visible, "transparent capture shader is hidden during ordinary play")
	game._begin_capture("teste", Color.RED)
	game._update_capture_sequence(0.55)
	_expect(game.capture_overlay.visible and game.capture_darkness > 0.0, "capture cinematic restores the overlay")
	game.capture_darkness = 0.0
	game.capture_flash = 0.0
	game.capture_noise = 0.2
	game.capture_shockwave_radius = 0.0
	game._update_capture_overlay()
	_expect(game.capture_overlay.visible, "noise alone can still contribute to shader alpha")
	game._reset_capture_state()
	_expect(not game.capture_overlay.visible, "capture reset hides the overlay immediately")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_test_solver_equivalence()
	_test_item_equivalence()
	var game := DrawProbe.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	_test_baseline_fingerprints(game)
	await _test_terrain_and_culling(game)
	await _test_biomes_and_capture(game)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PERFORMANCE_REGRESSION_PASS: WFC, RNG, coins, culling, cached terrain, demolition, biomes and capture")
		quit(0)
	else:
		print("PERFORMANCE_REGRESSION_FAIL: %d errors" % failures.size())
		quit(1)
