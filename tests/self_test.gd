extends SceneTree

const GameScript = preload("res://game.gd")
const Generator = preload("res://level_generator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_wfc()
	var game = GameScript.new()
	root.add_child(game)
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
	_expect(game.grid[0].all(func(tile): return tile == 1), "north world boundary is closed")
	_expect(not FileAccess.get_file_as_string("res://game.gd").contains("draw_line"), "enemy forecast lines are absent from game rendering")
	_expect(game.audio.effects.has("coin") and game.audio.effects.has("shield"), "action sound effects are synthesized")
	_expect(game.audio.music_player.stream.data.size() > 0, "ambient music stream is generated")
	game.audio.effects_enabled = false
	_test_turn_loop(game)
	_test_collectibles_and_jumping(game)
	_test_switch_level(game)
	_test_large_camera_and_rescue(game)
	if failures.is_empty():
		print("SELFTEST_PASS: WFC, boundaries, camera maps, pursuit, hidden intent, invalid moves, coin, shield, jump, switches, portal, music, rescue")
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
	_expect(game.enemies[0].next == Vector2i(3, 5), "pursuer chooses a one-cell step toward the player")
	game.try_move(0, 1)
	_expect(game.player_position == Vector2i(7, 6), "player moves one tile per action")
	_expect(game.enemies[0].pos == Vector2i(3, 5), "enemy reacts with one tile of movement")
	game.enemies[0].pos = Vector2i(6, 6)
	_expect(game._player_is_frightened(), "nearby enemy changes the player's expression state")
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
	game.generate_floor(2)
	_expect(game.objective_type == "switches", "second floor can use a locked-portal objective")
	_expect(game.switches.size() >= 2 and not game.portal_open, "switch requirement is configurable and closes the portal")
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
