extends SceneTree

const GameScript = preload("res://game.gd")

func _initialize() -> void:
	var game = GameScript.new()
	root.add_child(game)
	game.new_game(472)
	assert(game.grid.size() == game.ROWS, "floor grid has the expected row count")
	assert(game.grid[0].size() == game.COLS, "floor grid has the expected column count")
	assert(game._reachable(game.player_position, game.portal_position), "portal is reachable")
	assert(game.enemies.size() >= 1, "floor starts with at least one enemy")
	for enemy in game.enemies:
		assert(game._inside(enemy.next), "enemy intent remains inside the floor")
	game.enemies.clear()
	var start: Vector2i = game.player_position
	game.try_move(-1, 0)
	assert(game.player_position == start, "blocked move does not move the player")
	assert(game.moves_this_floor == 0, "blocked move does not count as a step")
	game.charges = 1
	game.player_position = Vector2i(2, 4)
	game.facing = Vector2i.RIGHT
	game.coins.clear()
	game.shields.clear()
	for x in game.COLS:
		game.grid[4][x] = 0
	game.portal_position = Vector2i(game.COLS - 1, 4)
	game.try_jump()
	assert(game.player_position == Vector2i(4, 4), "jump advances two cells when the path is clear")
	assert(game.charges == 0, "jump spends one shield charge")
	game.game_state = "playing"
	game.player_position = game.portal_position
	game.enemies.clear()
	game._check_portal()
	assert(game.game_state == "floor_clear", "portal completes a non-final floor")
	game.advance_floor()
	assert(game.floor_number == 2 and game.game_state == "playing", "next floor begins")
	game.floor_number = 5
	game.player_position = game.portal_position
	game._check_portal()
	assert(game.game_state == "rescued", "fifth floor reaches the rescue ending")
	print("SELFTEST_PASS: grid, path, enemy intents, movement, jump, portal, progression, rescue")
	quit(0)
