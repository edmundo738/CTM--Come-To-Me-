extends SceneTree

# Microbenchmark for a shielded contact in an otherwise idle board. The same
# script can be copied into an older checkout to measure the same input there.
# Values are CPU wall-clock microseconds, not frame times or GPU measurements.
const GameScript = preload("res://game.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var iterations := 3000
	var enemy_count := 8
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", false, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		match parts[0]:
			"iterations": iterations = clampi(int(parts[1]), 100, 100000)
			"enemies": enemy_count = clampi(int(parts[1]), 1, 200)
	var game = GameScript.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.world_size = Vector2i(40, 25)
	game.grid.clear()
	for y in game.world_size.y:
		var row: Array[int] = []
		for x in game.world_size.x:
			row.append(game.TILE_BORDER if x == 0 or y == 0 or x == game.world_size.x - 1 or y == game.world_size.y - 1 else game.TILE_FLOOR)
		game.grid.append(row)
	game.game_state = "playing"
	game.dev_god_mode = false
	game.player_position = Vector2i(20, 12)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.facing = Vector2i.RIGHT
	game.enemies.clear()
	for i in enemy_count:
		var point := Vector2i(2 + i % 34, 2 + i / 34)
		game.enemies.append(game._make_enemy(point, "hunter"))
	var samples: Array[int] = []
	var warmup := mini(300, iterations)
	for i in range(-warmup, iterations):
		var enemy: Dictionary = game.enemies[0]
		enemy.pos = game.player_position
		enemy.next = enemy.pos
		enemy.from = game._cell_center(enemy.pos)
		enemy.to = enemy.from
		enemy.t = 1.0
		enemy["path"] = []
		game.enemies[0] = enemy
		game.charges = 1
		game.damage_this_turn = false
		game.particles.clear()
		var started := Time.get_ticks_usec()
		game._check_enemy_collision()
		var elapsed := Time.get_ticks_usec() - started
		if i >= 0:
			samples.append(elapsed)
	samples.sort()
	var median: int = samples[samples.size() / 2]
	var p95: int = samples[mini(samples.size() - 1, ceili(float(samples.size()) * 0.95) - 1)]
	print("SHIELD_BENCHMARK ", JSON.stringify({"enemies": enemy_count, "iterations": iterations, "median_us": median, "p95_us": p95}))
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit()
