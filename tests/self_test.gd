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
	# Do not read or modify the player's real profile while testing.
	game.persistence_enabled = false
	root.add_child(game)
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
	_test_challenges(game)
	_test_score_saving(game)
	_test_restart_and_checkpoints(game)
	_test_turn_edge_cases(game)
	_test_chess_bosses(game)
	_test_capture_sequence(game)
	if failures.is_empty():
		print("SELFTEST_PASS: WFC, biomas, desafios, recompensas, checkpoint, repeticao, turnos, danos, chefes de xadrez, demolicao, captura e audio")
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
	var warm: Dictionary = first.generate(15, 11, 472)
	_expect(result_a.tiles == warm.tiles and result_a.grid == warm.grid, "warm entropy cache does not alter seeded layouts")
	# Compare the optimized bitset support with the original pairwise rule.
	var masks: Array[int] = [0, 65535, 43690, 21845, 3855, 42405]
	for tile in 16:
		masks.append(1 << tile)
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 8094
	for i in 100:
		masks.append(test_rng.randi_range(0, 65535))
	for direction in 4:
		for source in masks:
			var expected := 0
			for target_tile in 16:
				for source_tile in 16:
					if (source & (1 << source_tile)) != 0 and first._edges_match(source_tile, target_tile, direction):
						expected |= 1 << target_tile
						break
			_expect(first._support(direction, source) == expected, "optimized WFC support matches pairwise edges")
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
	writer.resume_charges = 2
	writer.resume_breach_charges = 3
	writer.resume_facing = Vector2i.UP
	writer.resume_seed = 9001
	writer.resume_history.append(5)
	writer._save_profile()
	var reader = GameScript.new()
	reader.profile_path = path
	reader._load_profile()
	_expect(reader.furthest_floor == 4 and reader.floor_stars.get("1", 0) == 5 and reader.floor_stars.get("3", 0) == 2, "profile saves the unlocked campaign and best stars")
	_expect(reader.has_resume and reader.resume_floor == 4 and reader.resume_coins == 23 and reader.resume_seed == 9001 and reader.resume_history == [5], "profile restores the continue checkpoint")
	_expect(reader.resume_charges == 2 and reader.resume_breach_charges == 3 and reader.resume_facing == Vector2i.UP, "profile restores shield, demolition and facing at checkpoint")
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "has_resume", true)
	legacy.set_value("progress", "resume_floor", 3)
	legacy.set_value("progress", "resume_coins", 8)
	legacy.save(path)
	var old_reader = GameScript.new()
	old_reader.profile_path = path
	old_reader._load_profile()
	_expect(old_reader.resume_floor == 3 and old_reader.resume_coins == 8 and old_reader.resume_charges == 0 and old_reader.resume_breach_charges == 0 and old_reader.resume_facing == Vector2i.RIGHT, "legacy checkpoints load with safe inventory defaults")
	old_reader.free()
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


func _test_arena(game: Node) -> void:
	game.world_size = Vector2i(12, 10)
	game.grid.clear()
	for y in game.world_size.y:
		var row: Array[int] = []
		for x in game.world_size.x:
			row.append(game.TILE_BORDER if x == 0 or y == 0 or x == game.world_size.x - 1 or y == game.world_size.y - 1 else game.TILE_FLOOR)
		game.grid.append(row)
	game.game_state = "playing"
	game.dev_god_mode = false
	game.dev_noclip = false
	game.enemies.clear()
	game.coins.clear()
	game.shields.clear()
	game.breakers.clear()
	game.switches.clear()
	game.traps.clear()
	game.player_position = Vector2i(4, 4)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.portal_position = Vector2i(10, 8)
	game.portal_open = true
	game.objective_type = "escape"
	game.facing = Vector2i.RIGHT
	game.charges = 0
	game.breach_charges = 0
	game.turn_number = 0
	game.moves_this_floor = 0
	game.jumps_this_floor = 0
	game.hits_this_floor = 0
	game.coins_this_floor = 0
	game.coins_spawned_this_floor = 0
	game.damage_this_turn = false
	game.challenge_complete = false


func _test_challenges(game: Node) -> void:
	_test_arena(game)
	game.challenge_kind = "no_jump"
	_expect(game.is_challenge_met() and not game.is_challenge_failed(), "no-jump challenge begins eligible")
	game.jumps_this_floor = 1
	_expect(not game.is_challenge_met() and game.is_challenge_failed(), "jump invalidates no-jump challenge")
	game.challenge_kind = "no_hit"
	game.hits_this_floor = 1
	_expect(not game.is_challenge_met() and game.is_challenge_failed(), "damage invalidates no-hit challenge")
	game.challenge_kind = "moves"
	game.challenge_par = 19
	game.moves_this_floor = 19
	_expect(game.is_challenge_met(), "action challenge includes its exact limit")
	game.moves_this_floor = 20
	_expect(not game.is_challenge_met() and game.is_challenge_failed(), "action challenge fails above its limit")
	game.challenge_kind = "all_coins"
	game.coins_spawned_this_floor = 2
	game.coins.append(Vector2i(2, 2))
	_expect(not game.is_challenge_met(), "all-coins challenge requires every coin")
	game.coins.clear()
	_expect(game.is_challenge_met(), "all-coins challenge succeeds when the last coin is collected")
	game.challenge_kind = "no_jump"
	game.jumps_this_floor = 0
	game.total_coins = 10
	game.floor_number = 1
	game.player_position = game.portal_position
	var stars: int = game._stars_for_floor()
	game._check_portal()
	var reward: int = stars * 2 + 5
	_expect(game.floor_reward == reward and game.total_coins == 10 + reward, "challenge bonus is displayed and paid exactly once")
	game._check_portal()
	_expect(game.total_coins == 10 + reward, "rechecking a completed portal cannot pay twice")
	game.active_seed = 58231
	game.generate_floor(2)
	var route: int = game._estimate_route_length()
	_expect(route > 0 and game.challenge_par >= route, "action limit covers an actual path through switches to the portal")


func _test_score_saving(game: Node) -> void:
	_test_arena(game)
	var old_path: String = game.profile_path
	var path := "res://.godot/self_test_record.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.profile_path = path
	game.persistence_enabled = true
	game.best_score = 0
	game.best_score_dirty = false
	game.total_coins = 0
	game.coins.append(game.player_position)
	game._collect_pickups()
	_expect(game.best_score == 1 and game.best_score_dirty and not FileAccess.file_exists(path), "collecting a coin updates the record without a synchronous profile write")
	game._save_profile()
	_expect(FileAccess.file_exists(path) and not game.best_score_dirty, "checkpoint persists the pending record")
	game.persistence_enabled = false
	game.profile_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_restart_and_checkpoints(game: Node) -> void:
	game.new_game(28373)
	_expect(game.has_resume and game.resume_floor == 1, "new campaign immediately has a floor-start checkpoint")
	game.floor_history.assign([3, 4, 5])
	game.total_coins = 27
	game.charges = 2
	game.breach_charges = 3
	game.facing = Vector2i.UP
	game.generate_floor(4)
	game.game_state = "playing"
	var original_grid: Array = game.grid.duplicate(true)
	var original_coins: Array = game.coins.duplicate()
	var original_enemies: Array = game.enemies.duplicate(true)
	var original_challenge: String = game.challenge_kind
	var original_par: int = game.challenge_par
	game.total_coins = 99
	game.charges = 0
	game.breach_charges = 0
	game.floor_history.append(1)
	game.facing = Vector2i.LEFT
	game.coins.clear()
	var restart_key := InputEventKey.new()
	restart_key.pressed = true
	restart_key.keycode = KEY_R
	game._unhandled_key_input(restart_key)
	_expect(game.floor_number == 4 and game.active_seed == 28373 and game.total_coins == 27, "R restores floor, seed and pre-floor coins")
	_expect(game.charges == 2 and game.breach_charges == 3 and game.facing == Vector2i.UP and game.floor_history == [3, 4, 5], "R preserves inventory, facing and completed-floor history")
	_expect(game.grid == original_grid and game.coins == original_coins and game.enemies == original_enemies and game.challenge_kind == original_challenge and game.challenge_par == original_par, "R regenerates exactly the same seeded floor and challenge")
	game.total_coins = 88
	game.charges = 0
	game.breach_charges = 0
	game.floor_history.append(1)
	game._begin_capture("TEST", Color.WHITE)
	game._update_capture_sequence(game.CAPTURE_END_TIME + 0.1)
	_expect(game.game_state == "game_over" and game.resume_coins == 27 and game.resume_charges == 2 and game.resume_breach_charges == 3 and game.resume_history == [3, 4, 5], "defeat saves the complete floor-start snapshot")
	game.continue_game()
	_expect(game.floor_number == 4 and game.total_coins == 27 and game.charges == 2 and game.breach_charges == 3 and game.facing == Vector2i.UP, "continue restores the same floor-start resources")
	_expect(game.grid == original_grid and game.coins == original_coins, "continue regenerates the same map and pickups")
	game.portal_open = true
	game.player_position = game.portal_position
	game._check_portal()
	var completed_total: int = game.total_coins
	_expect(game.resume_floor == 5 and game.resume_coins == completed_total and game.resume_charges == 2 and game.resume_breach_charges == 3, "clearing saves next floor with carried inventory")
	game.continue_game()
	_expect(game.floor_number == 5 and game.total_coins == completed_total and game.charges == 2 and game.breach_charges == 3, "continuing next floor keeps carried inventory")


func _test_turn_edge_cases(game: Node) -> void:
	_test_arena(game)
	var enemy := {"pos": Vector2i(6, 4), "next": Vector2i(5, 4), "from": game._cell_center(Vector2i(6, 4)), "to": game._cell_center(Vector2i(6, 4)), "t": 1.0, "role": "hunter"}
	game.enemies.append(enemy)
	game.grid[4][3] = game.TILE_WALL
	game.try_move(-1, 0)
	_expect(game.turn_number == 0 and game.moves_this_floor == 0 and game.enemies[0].pos == Vector2i(6, 4), "bumping a wall gives feedback but does not spend a turn")
	game.try_move(0, 0)
	_expect(game.turn_number == 0 and game.facing == Vector2i.LEFT, "invalid movement does not become an accidental wait or change facing")
	game.wait_turn()
	_expect(game.turn_number == 1 and game.moves_this_floor == 1 and game.enemies[0].pos == Vector2i(5, 4) and game.facing == Vector2i.LEFT, "explicit wait spends one action and preserves facing")
	_test_arena(game)
	game.charges = 1
	game.enemies.append({"pos": Vector2i(5, 4), "next": Vector2i(4, 4), "from": game._cell_center(Vector2i(5, 4)), "to": game._cell_center(Vector2i(5, 4)), "t": 1.0, "role": "hunter"})
	game.try_move(1, 0)
	_expect(game.game_state == "playing" and game.charges == 0 and game.hits_this_floor == 1, "swapping cells with a pursuer counts as contact")
	_test_arena(game)
	game.floor_number = 5
	game.charges = 2
	var boss: Dictionary = game._make_boss(Vector2i(6, 4))
	boss.next = Vector2i(5, 4)
	game.enemies.append(boss)
	game.traps.append({"pos": Vector2i(5, 4), "armed": true, "revealed": false})
	game.try_move(1, 0)
	_expect(game.charges == 1 and game.hits_this_floor == 1 and game.enemies[0].hp == boss.max_hp, "trap and warden on the same turn consume only one shield")
	_test_arena(game)
	game.portal_position = Vector2i(5, 4)
	game.traps.append({"pos": game.portal_position, "armed": true, "revealed": false})
	game.try_move(1, 0)
	_expect(game.game_state == "captured", "a lethal trap on the portal cannot also finish the floor")
	_test_arena(game)
	game.player_position = Vector2i(4, 3)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.charges = 1
	game.enemies.append({"pos": Vector2i(2, 4), "next": Vector2i(5, 4), "path": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)], "from": game._cell_center(Vector2i(2, 4)), "to": game._cell_center(Vector2i(2, 4)), "t": 1.0, "role": "rusher"})
	game.try_move(0, 1)
	_expect(game.charges == 0 and game.hits_this_floor == 1, "a sliding enemy also hits a player crossed between endpoints")
	_test_arena(game)
	game.dev_god_mode = true
	game.traps.append({"pos": Vector2i(5, 4), "armed": true, "revealed": false})
	game.try_move(1, 0)
	_expect(game.game_state == "playing", "developer god mode also prevents trap capture")
	game.dev_god_mode = false


func _test_chess_bosses(game: Node) -> void:
	_test_arena(game)
	var types := ["pawn", "rook", "knight", "bishop", "queen", "king", "pawn"]
	for i in types.size():
		game.floor_number = (i + 1) * 5
		var piece: Dictionary = game._make_boss(Vector2i(2, 2))
		_expect(piece.boss_kind == types[i] and piece.hp >= 2, "chess bosses cycle every five floors and resist a single hit")
	game.player_position = Vector2i(8, 4)
	game.floor_number = 10
	var rook: Dictionary = game._make_boss(Vector2i(2, 4))
	game.enemies.append(rook)
	var reserved: Array[Vector2i] = []
	var move: Dictionary = game._boss_intent(rook, reserved)
	_expect(move.pos == Vector2i(5, 4) and move.path.size() == 3, "rook moves along a clear line up to three cells")
	game.grid[4][4] = game.TILE_WALL
	move = game._boss_intent(rook, reserved)
	_expect(move.pos == Vector2i(3, 4), "rook cannot cross a wall")
	_test_arena(game)
	game.floor_number = 15
	game.player_position = Vector2i(5, 4)
	var knight: Dictionary = game._make_boss(Vector2i(2, 2))
	game.enemies.append(knight)
	game.grid[2][3] = game.TILE_WALL
	move = game._boss_intent(knight, reserved)
	var delta: Vector2i = move.pos - knight.pos
	_expect((absi(delta.x) == 2 and absi(delta.y) == 1) or (absi(delta.x) == 1 and absi(delta.y) == 2), "knight jumps in an L to a free landing")
	_test_arena(game)
	game.floor_number = 20
	game.player_position = Vector2i(6, 6)
	var bishop: Dictionary = game._make_boss(Vector2i(2, 2))
	game.enemies.append(bishop)
	game.grid[2][3] = game.TILE_WALL
	move = game._boss_intent(bishop, reserved)
	_expect(move.pos != Vector2i(3, 3) and move.pos != Vector2i(4, 4), "bishop cannot cut through a blocked diagonal corner")
	_test_arena(game)
	game.floor_number = 10
	game.breach_charges = 2
	var target: Dictionary = game._make_boss(Vector2i(5, 4))
	target.next = target.pos
	game.enemies.append(target)
	game.try_break_wall()
	_expect(game.enemies.size() == 1 and game.enemies[0].hp == 2 and game.breach_charges == 1, "one demolition hit damages but does not instantly kill a boss")
	game.enemies[0].hp = 1
	game.try_break_wall()
	_expect(game.enemies.is_empty() and game.breach_charges == 0, "the last demolition hit can defeat a boss")
	_test_arena(game)
	game.floor_number = 5
	game.charges = 1
	var counter: Dictionary = game._make_boss(game.player_position)
	game.enemies.append(counter)
	game._check_enemy_collision()
	_expect(game.charges == 0 and game.enemies.size() == 1 and game.enemies[0].hp == 1 and game.enemies[0].pos != game.player_position, "shield counter damages and staggers a boss")


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
