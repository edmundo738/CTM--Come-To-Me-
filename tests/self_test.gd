extends SceneTree

const GameScript = preload("res://game.gd")
const Generator = preload("res://level_generator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_wfc()
	_test_profile_roundtrip()
	var game = GameScript.new()
	root.add_child(game)
	game.persistence_enabled = false
	_expect(game.game_state == "title", "game opens on the cinematic title menu")
	_expect(int(ProjectSettings.get_setting("display/window/size/mode")) == DisplayServer.WINDOW_MODE_MAXIMIZED, "game opens maximized for the available display")
	_expect(game.world_size.x > 18 and game.world_size.y > 14, "world is larger than the old compact board")
	_expect(game._reachable_cells(game.player_position).has(game.portal_position), "portal remains reachable after WFC repair")
	_expect(game.enemies.size() >= 1, "floor contains pursuers")
	_expect(game.rooms.size() >= 4, "level contains several tactical rooms")
	_expect(game.room_graph_edges.size() >= game.rooms.size() - 1, "room links include a connected spanning tree")
	var floor_cells := 0
	for row in game.grid:
		for cell in row:
			if cell == 0:
				floor_cells += 1
	_expect(float(floor_cells) / (game.world_size.x * game.world_size.y) > 0.25, "walkable space is not reduced to thin corridors")
	_expect(game.grid[0].all(func(tile): return tile == game.TILE_BORDER), "north world boundary is closed and indestructible")
	var game_source := FileAccess.get_file_as_string("res://game.gd")
	_expect(not game_source.contains("_draw_enemy_intent") and not game_source.contains("_draw_enemy_forecast"), "enemy forecast renderers are absent from game rendering")
	_expect(game.audio.effects.has("coin") and game.audio.effects.has("shield"), "action sound effects are synthesized")
	_expect(game.audio.effects.has("inflate") and game.audio.effects.has("balloon_pop"), "capture has its own rising squeak and pop cues")
	_expect(game.audio.effects.has("break_wall") and game.audio.effects.has("breaker"), "wall breaking and its power-up have separate sound cues")
	_expect(game.capture_overlay != null and game.capture_material != null, "capture has a camera-darkening overlay")
	_expect(game.audio.music_player.stream.get_length() >= 38.0 and game.audio.music_player.stream.stereo, "music is an arranged 40-second stereo track with bass, melody and percussion")
	_expect(is_equal_approx(game.audio.threat_player.stream.get_length(), game.audio.music_player.stream.get_length()), "enemy-tension layer stays synchronized with the score")
	game.audio.effects_enabled = false
	_test_turn_loop(game)
	_test_collectibles_and_jumping(game)
	_test_switch_level(game)
	_test_large_camera_and_rescue(game)
	_test_progression(game)
	_test_wall_destruction(game)
	_test_capture_sequence(game)
	if failures.is_empty():
		print("SELFTEST_PASS: WFC, biome rooms and water landmarks, boundaries, camera maps, alert expressions, pursuit, movement, shield, jump, demolition, switches, portal, adaptive music, rescue, level stars, continue checkpoint, capture inflation, balloon pop, smaller blood pool, dark fade")
	else:
		printerr("SELFTEST_FAIL: %d check(s): %s" % [failures.size(), "; ".join(failures)])
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _test_wfc() -> void:
	var first = Generator.new()
	var second = Generator.new()
	var result_a: Dictionary = first.generate(15, 11, 472)
	var result_b: Dictionary = second.generate(15, 11, 472)
	_expect(result_a.ok and result_b.ok, "WFC solves a reproducible tile map")
	_expect(result_a.tiles == result_b.tiles, "same WFC seed produces the same tile masks")
	_expect(result_a.grid.size() == 11 and result_a.grid[0].size() == 15, "WFC respects requested dimensions")
	for y in 11:
		for x in 15:
			var tile: int = result_a.tiles[y][x]
			if x + 1 < 15:
				var east: int = result_a.tiles[y][x + 1]
				_expect(((tile & 2) != 0) == ((east & 8) != 0), "east-west WFC adjacency is reciprocal")
			if y + 1 < 11:
				var south: int = result_a.tiles[y + 1][x]
				_expect(((tile & 4) != 0) == ((south & 1) != 0), "north-south WFC adjacency is reciprocal")
	for profile_index in 5:
		var profiled = Generator.new().generate(19, 15, 8050 + profile_index, profile_index)
		_expect(profiled.ok and profiled.rooms.size() >= 4, "each biome profile produces connected tactical rooms")
		if profiled.ok:
			_expect(profiled.grid.size() == 15 and profiled.grid[0].size() == 19, "biome generation preserves requested world size")


func _test_profile_roundtrip() -> void:
	var path := "res://.godot/self_test_progress.cfg"
	var writer = GameScript.new()
	writer.profile_path = path
	writer.furthest_floor = 4
	writer.floor_stars = {"1": 5, "3": 2}
	writer.has_resume = true
	writer.resume_floor = 4
	writer.resume_coins = 23
	writer.resume_seed = 9001
	writer.resume_history.append(5)
	writer._save_profile()
	var reader = GameScript.new()
	reader.profile_path = path
	reader._load_profile()
	_expect(reader.furthest_floor == 4 and reader.floor_stars.get("1", 0) == 5 and reader.floor_stars.get("3", 0) == 2, "profile saves the unlocked campaign and best stars")
	_expect(reader.has_resume and reader.resume_floor == 4 and reader.resume_coins == 23 and reader.resume_seed == 9001 and reader.resume_history == [5], "profile restores the continue checkpoint")
	writer.free()
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_turn_loop(game: Node) -> void:
	game.game_state = "playing"
	game.world_size = Vector2i(15, 11)
	game.grid.clear()
	for y in game.world_size.y:
		var row: Array[int] = []
		for x in game.world_size.x:
			row.append(0)
		game.grid.append(row)
	game.enemies.clear()
	game.enemies.append({"pos": Vector2i(2, 5), "next": Vector2i(2, 5), "from": game._cell_center(Vector2i(2, 5)), "to": game._cell_center(Vector2i(2, 5)), "t": 1.0})
	game.player_position = Vector2i(7, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.coins.clear()
	game.shields.clear()
	game.switches.clear()
	game.traps.clear()
	game._update_enemy_intents()
	_expect(game._current_threat_level() > 0.0, "nearby pursuers raise the music threat layer")
	_expect(game.enemies[0].next == Vector2i(3, 5), "pursuer chooses a one-cell step toward the player")
	game.try_move(0, 1)
	_expect(game.player_position == Vector2i(7, 6), "player moves one tile per action")
	_expect(game.enemies[0].pos == Vector2i(3, 5), "enemy reacts with one tile of movement")
	game.enemies[0].pos = Vector2i(6, 6)
	_expect(game._player_is_frightened(), "nearby enemy changes the player's expression state")
	game.player_position = Vector2i(7, 5)
	game.enemies[0].pos = Vector2i(3, 5)
	game.grid[5][5] = game.TILE_WALL
	_expect(not game._enemy_sees_player(game.enemies[0].pos), "solid wall blocks enemy sight and alert face")
	game.grid[5][5] = game.TILE_FLOOR
	_expect(game._enemy_sees_player(game.enemies[0].pos), "enemy sees the player down a clear lane")
	game.enemies[0].pos = Vector2i(3, 5)
	var moves_before: int = game.moves_this_floor
	game.player_position = Vector2i(0, 5)
	game.try_move(-1, 0)
	_expect(game.player_position == Vector2i(0, 5), "world edge blocks movement")
	_expect(game.moves_this_floor == moves_before, "blocked move does not count as movement")
	_expect(game.shake_time > 0.0 and game.audio.effects.has("blocked"), "invalid move triggers feedback")
	game.enemies.clear()


func _test_collectibles_and_jumping(game: Node) -> void:
	game.game_state = "playing"
	game.player_position = Vector2i(3, 3)
	game.coins.clear()
	game.coins.append(game.player_position)
	game.shields.clear()
	game.total_coins = 0
	game.particles.clear()
	game._collect_pickups()
	_expect(game.total_coins == 1 and game.coins.is_empty(), "coin updates score and is removed")
	_expect(game.particles.size() >= 18, "coin creates visible burst particles")
	game.shields.clear()
	game.shields.append(game.player_position)
	game._collect_pickups()
	_expect(game.charges == 1 and game.shields.is_empty(), "shield pickup grants a charge")
	game.grid[3][4] = 0
	game.grid[3][5] = 0
	game.facing = Vector2i.RIGHT
	game.charges = 1
	game._begin_player_move(Vector2i(3, 3))
	game.try_jump()
	_expect(game.player_position == Vector2i(5, 3), "jump crosses two open cells")
	_expect(game.charges == 0 and game.jumps_this_floor == 1, "jump spends one charge and counts its use")
	game.enemies.clear()


func _test_switch_level(game: Node) -> void:
	game.active_seed = 48211
	game.generate_floor(2)
	_expect(game.objective_type == "switches", "second floor can use a locked-portal objective")
	_expect(game.switches.size() >= 2 and not game.portal_open, "switch requirement is configurable and closes the portal")
	var water_cells := 0
	for row in game.grid:
		for tile in row:
			if tile == game.TILE_WATER:
				water_cells += 1
	_expect(water_cells >= 6, "garden biome places broad water landmarks that create route choices")
	var available: Array[Vector2i] = game._reachable_cells(game.player_position)
	for item in game.switches:
		_expect(available.has(item.pos), "required switch is reachable")
	game.player_position = game.portal_position
	game.game_state = "playing"
	game._check_portal()
	_expect(game.game_state == "playing" and not game.portal_open, "closed portal cannot finish the floor")
	for i in game.switches.size():
		var item: Dictionary = game.switches[i]
		item.active = true
		game.switches[i] = item
	game._activate_switches()
	_expect(game.portal_open, "all active switches unlock the portal")


func _test_large_camera_and_rescue(game: Node) -> void:
	game.generate_floor(4)
	_expect(game.world_size.x >= 37 and game.world_size.y >= 23, "later floor expands beyond the visible area")
	_expect(game.objective_type == "switches" and game.switches.size() >= 2, "fourth floor stays top-down and uses a switch-hunt objective")
	var ice_water_cells := 0
	for row in game.grid:
		for tile in row:
			if tile == game.TILE_WATER:
				ice_water_cells += 1
	_expect(ice_water_cells >= 12, "ice biome adds larger water landmarks without sealing the portal route")
	_expect(game._reachable_cells(game.player_position).has(game.portal_position), "natural landmarks preserve a route to the portal")
	game.player_position = Vector2i(game.world_size.x - 1, game.world_size.y - 1)
	game._update_camera(0.0)
	var half: Vector2 = game.get_viewport_rect().size * 0.5
	_expect(game.camera.global_position.x <= game.world_size.x * game.CELL - half.x + 0.1, "camera stops at the world's east edge")
	_expect(game.camera.global_position.y <= game.world_size.y * game.CELL - half.y + 0.1, "camera stops at the world's south edge")
	var roles: Array[String] = []
	for enemy in game.enemies:
		roles.append(enemy.get("role", "hunter"))
	_expect(roles.has("sentry") and roles.has("wisp"), "later floors add sentries and slower wisp pursuers")
	game.generate_floor(5)
	var warden_index := -1
	for i in game.enemies.size():
		if game.enemies[i].get("role", "") == "warden":
			warden_index = i
			break
	_expect(warden_index >= 0, "final floor spawns a distinct warden boss")
	if warden_index >= 0:
		var warden: Dictionary = game.enemies[warden_index]
		var contact: Vector2i = warden.pos
		game.player_position = contact
		game.charges = 1
		game._check_enemy_collision()
		_expect(game.charges == 0 and game.enemies[warden_index].pos != contact, "shield staggers the warden and creates an escape opening")
	game.floor_number = 5
	game.portal_open = true
	game.game_state = "playing"
	game.player_position = game.portal_position
	game._check_portal()
	_expect(game.game_state == "rescued", "portal on the fifth floor reaches the rescue ending")


func _test_capture_sequence(game: Node) -> void:
	game.game_state = "playing"
	game.charges = 0
	game.damage_this_turn = false
	game.enemies.clear()
	game.particles.clear()
	game.player_position = Vector2i(7, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game._apply_damage("FOSTE ALCANCADO", Color("ff4e70"))
	_expect(game.game_state == "captured", "capture begins with a staged animation instead of an instant menu")
	_expect(game.audio.effects["inflate"].data.size() > 0 and game.audio.effects["balloon_pop"].data.size() > 0, "inflation and balloon pop have generated audio")
	var blocked_move := InputEventKey.new()
	blocked_move.pressed = true
	blocked_move.keycode = KEY_RIGHT
	game._unhandled_key_input(blocked_move)
	_expect(game.player_position == Vector2i(7, 5), "player cannot move during the capture sequence")
	game._process(0.55)
	_expect(game.capture_darkness > 0.0 and not game.capture_popped, "camera darkens while the player inflates and flickers")
	game._process(0.42)
	_expect(game.capture_popped and game.capture_puddle_active, "capture pops into a persistent red pool")
	_expect(game.particles.size() >= 80, "capture burst throws a dense spray of droplets")
	var min_x: float = game.capture_puddle_points[0].x
	var max_x: float = min_x
	for point in game.capture_puddle_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	var puddle_width := max_x - min_x
	_expect(puddle_width >= game.CELL * 2.3 and puddle_width <= game.CELL * 2.9, "blood pool is smaller than before while staying clearly visible")
	game._process(1.0)
	_expect(game.game_state == "game_over" and game.capture_darkness >= 0.9, "capture ends on the dark defeat screen")


func _test_wall_destruction(game: Node) -> void:
	game.game_state = "playing"
	game.generate_floor(3)
	_expect(game.breakers.size() == 1, "a demolition charge appears on the third floor")
	game.breach_charges = 0
	game.breakers.clear()
	game.breakers.append(game.player_position)
	game._collect_pickups()
	_expect(game.breach_charges == 1 and game.breakers.is_empty(), "demolition pickup grants one wall-breaking charge")
	game.world_size = Vector2i(15, 11)
	game.grid.clear()
	for y in game.world_size.y:
		var row: Array[int] = []
		for x in game.world_size.x:
			row.append(game.TILE_FLOOR)
		game.grid.append(row)
	for x in game.world_size.x:
		game.grid[0][x] = game.TILE_BORDER
		game.grid[game.world_size.y - 1][x] = game.TILE_BORDER
	for y in game.world_size.y:
		game.grid[y][0] = game.TILE_BORDER
		game.grid[y][game.world_size.x - 1] = game.TILE_BORDER
	game.player_position = Vector2i(1, 5)
	game.facing = Vector2i.LEFT
	game.grid[5][0] = game.TILE_BORDER
	game.try_break_wall()
	_expect(game.grid[5][0] == game.TILE_BORDER and game.breach_charges == 1, "world boundary cannot be destroyed or consume the charge")
	game.player_position = Vector2i(5, 5)
	game.facing = Vector2i.RIGHT
	game.grid[5][6] = game.TILE_WALL
	game.enemies.clear()
	game.enemies.append({"pos": Vector2i(10, 5), "next": Vector2i(9, 5), "from": game._cell_center(Vector2i(10, 5)), "to": game._cell_center(Vector2i(9, 5)), "t": 1.0, "role": "hunter", "phase": 0})
	var turn_before: int = game.turn_number
	game.try_break_wall()
	_expect(game.grid[5][6] == game.TILE_FLOOR and game.breach_charges == 0, "a demolition charge opens an internal wall")
	_expect(game.turn_number == turn_before + 1 and game.enemies[0].pos == Vector2i(9, 5), "breaking a wall costs a turn and the pursuer advances")


func _test_progression(game: Node) -> void:
	var saved_state: String = game.game_state
	var unlocked_before: int = game.furthest_floor
	game.furthest_floor = 2
	game.game_state = "level_select"
	var floor_before: int = game.floor_number
	game.start_level(3)
	_expect(game.game_state == "level_select" and game.floor_number == floor_before, "locked floors cannot be selected")
	game.furthest_floor = maxi(unlocked_before, 2)
	game.active_seed = 48211
	game.floor_history.clear()
	game.floor_history.append(2)
	game.floor_history.append(4)
	game._save_resume(4, 19)
	game.continue_game()
	_expect(game.game_state == "playing" and game.floor_number == 4, "continue returns to the saved floor after defeat")
	_expect(game.total_coins == 19 and game.active_seed == 48211, "continue preserves previous coins and deterministic level seed")
	_expect(game.floor_history == [2, 4], "continue carries the completed star record through the run")
	game.floor_stars["4"] = 3
	_expect(game.floor_stars.get("4", 0) == 3 and game.furthest_floor >= 4, "level journal stores stars and unlock progress")
	if saved_state == "paused":
		game.game_state = "paused"
