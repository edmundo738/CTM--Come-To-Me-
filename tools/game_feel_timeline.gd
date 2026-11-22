extends SceneTree

# Real-renderer, manually stepped evidence; never substitutes for playtesting.
# Run with -- evidence=1 to emit cropped PNGs for a browser harness, or set
# TIMELINE_OUT to save individual PNGs. All sequences are silent.
const Game = preload("res://game.gd")

var game: Node
var evidence := false
var output := ""
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _arena() -> void:
	game.dev_load_sandbox_arena()
	game._reset_capture_state()
	game.set_process(false)
	game.enemies.clear()
	game.coins.clear()
	game.shields.clear()
	game.heart_pickups.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.switches.clear()
	game.traps.clear()
	game.environment.reset()
	game.player_position = Vector2i(9, 7)
	game.facing = Vector2i.RIGHT
	game._reset_player_visual(game._cell_center(game.player_position))
	game.portal_position = Vector2i(16, 12)
	game.portal_open = false
	game.game_state = "playing"
	game.floor_number = 1
	game.turn_number = 0
	game.charges = 0
	game.breach_charges = 0
	game.hearts_current = 0
	game.animation_clock = 0.0
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.camera.offset = Vector2.ZERO
	game._update_camera(0.0)
	game.terrain_renderer.rebuild()


func _frame(name: String, index: int) -> void:
	game.terrain_renderer.sync_view(game._visible_world_rect(), true)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var whole: Image = root.get_texture().get_image()
	var cropped := whole.get_region(Rect2i(440, 240, 400, 240))
	var id := "%s-%02d" % [name, index]
	if not output.is_empty():
		_expect(cropped.save_png(output.path_join(id + ".png")) == OK, "saved " + id)
	if evidence:
		print("TIMELINE_IMAGE ", id, " ", Marshalls.raw_to_base64(cropped.save_png_to_buffer()))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("GAME_FEEL_TIMELINE_NOT_TESTED: real renderer required")
		quit(2)
		return
	evidence = OS.get_cmdline_user_args().has("evidence=1")
	output = OS.get_environment("TIMELINE_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() != "web":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.audio.stop_all()
	const STEP := 0.04
	for scenario in ["movimento", "madeira", "metal", "escudo", "parede", "criatura", "eletricidade"]:
		_arena()
		match scenario:
			"madeira", "metal":
				var material := "wood" if scenario == "madeira" else "metal"
				game.environment.reset({"crates": [{"pos": Vector2i(10, 7), "material": material}]})
			"escudo":
				game.charges = 1
				var enemy: Dictionary = game._make_enemy(Vector2i(10, 7), "hunter")
				enemy.next = enemy.pos
				game.enemies.append(enemy)
			"parede":
				game.grid[7][10] = game.TILE_WALL
				game.terrain_renderer.rebuild()
				game.breach_charges = 1
			"criatura":
				game.enemies.append(game._make_enemy(Vector2i(10, 7), "rusher"))
				game.breach_charges = 1
			"eletricidade":
				var source := Vector2i(7, 7)
				var water := Vector2i(8, 7)
				game.grid[source.y][source.x] = game.TILE_WATER
				game.grid[water.y][water.x] = game.TILE_WATER
				game.environment.reset({"cells": {source: {"kind": "water", "source": true}, water: {"kind": "water"}}, "crates": [{"pos": Vector2i(8, 8), "material": "metal"}]})
				game.enemies.append(game._make_enemy(Vector2i(8, 6), "sentry"))
				game.terrain_renderer.rebuild()
		await process_frame
		game.terrain_renderer.sync_view(game._visible_world_rect(), true)
		await process_frame
		await RenderingServer.frame_post_draw
		if scenario == "eletricidade":
			game._advance_electric_visuals(0.25)
			game.electric_presentation.update_presentation(game._visible_world_rect(), true, 0.0)
		await _frame(scenario, 0)
		if scenario in ["movimento", "madeira", "metal", "escudo"]:
			game.try_move(1, 0)
		elif scenario in ["parede", "criatura"]:
			game.try_break_wall()
		var count := 18 if scenario == "eletricidade" else 16 if scenario in ["parede", "criatura"] else 14 if scenario == "escudo" else 12
		var brightness_samples: Array[float] = []
		for index in range(1, count + 1):
			game._process(STEP)
			if scenario == "eletricidade" and not game.electric_presentation.samples.is_empty():
				brightness_samples.append(float(game.electric_presentation.samples[0].energy))
			await _frame(scenario, index)
		if scenario == "eletricidade":
			_expect(game.turn_number == 0 and brightness_samples.size() > 1 and brightness_samples.max() - brightness_samples.min() > 0.05, "electrical pulse animates without inventing a turn")
		else:
			_expect(game.turn_number == 1, scenario + " keeps one committed turn across all shown frames")
		if scenario in ["madeira", "metal"]:
			_expect(game.environment.crates[0].pos == Vector2i(11, 7), scenario + " finishes at the resolved crate cell")
		elif scenario == "escudo":
			_expect(game.charges == 0 and game.enemies[0].pos == Vector2i(12, 7), "shield sequence retains actual recoil")
		elif scenario == "parede":
			_expect(game.grid[7][10] == game.TILE_FLOOR and game.breach_charges == 0, "wall sequence retains actual destruction")
		elif scenario == "criatura":
			_expect(game.enemies.is_empty() and game.breach_charges == 0, "defeat sequence retains actual consequence")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("GAME_FEEL_TIMELINE_PASS checks=", checks, " seven silent manually stepped sequences at 40 ms")
		quit(0)
	else:
		printerr("GAME_FEEL_TIMELINE_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
