extends SceneTree

# Requires a real renderer. Optional ELECTRIC_RENDER_TEST_OUT saves evidence.
const Game = preload("res://game.gd")
const EnvironmentVFX = preload("res://environment_vfx.gd")

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


func _capture(name: String) -> Image:
	game.queue_redraw()
	game.terrain_renderer.sync_view(game._visible_world_rect(), true)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := OS.get_environment("ELECTRIC_RENDER_TEST_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")
	if OS.get_cmdline_user_args().has("browser-evidence") and not image.is_empty():
		# Web's filesystem is private to the engine; emit the actual frame for
		# the evidence harness, as the combat render test does.
		print("ELECTRIC_IMAGE ", name, " ", Marshalls.raw_to_base64(image.save_png_to_buffer()))
	return image


func _brightness(image: Image, position: Vector2, radius: int = 4) -> float:
	var total := 0.0
	var count := 0
	for y in range(int(position.y) - radius, int(position.y) + radius + 1):
		for x in range(int(position.x) - radius, int(position.x) + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var pixel := image.get_pixel(x, y)
			total += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			count += 1
	return total / maxf(1.0, float(count))


func _screen(point: Vector2) -> Vector2:
	return game.get_global_transform_with_canvas() * point


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ELECTRIC_RENDER_NOT_TESTED: a real renderer is required")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.audio.effects_enabled = false
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	var source := Vector2i(7, 7)
	var live_water := Vector2i(8, 7)
	game.grid[source.y][source.x] = game.TILE_WATER
	game.grid[live_water.y][live_water.x] = game.TILE_WATER
	game.environment.reset({"cells": {source: {"kind": "water", "source": true}, live_water: {"kind": "water"}}})
	game.electric_visual_glow[source] = 1.0
	game.electric_visual_glow[live_water] = 1.0
	var key := live_water.x * 37 + live_water.y * 79
	for index in 800:
		var clock := float(index) / 3600.0
		if EnvironmentVFX.arc_geometry(Vector2.ZERO, Vector2(20, 0), key, clock).opacity > 0.85:
			game.animation_clock = clock
			break
	game._update_camera(0.0)
	game.terrain_renderer.rebuild()
	# Let the camera transform and retained terrain chunks settle before either
	# measurement; otherwise the first frame can still be populating the view.
	await process_frame
	game.terrain_renderer.sync_view(game._visible_world_rect(), true)
	await process_frame
	await RenderingServer.frame_post_draw
	game.electric_presentation.update_presentation(game._visible_world_rect(), true, 0.0)
	var light_on: Image = await _capture("01-arco-luz-ativa")
	for light in game.electric_presentation.lights:
		light.enabled = false
	var light_off: Image = await _capture("02-mesmo-arco-sem-luz")
	var actor_pos := _screen(game._cell_center(game.player_position) + Vector2(-8, 2))
	var floor_pos := _screen(game._cell_center(live_water) + Vector2(26, 22))
	var far_pos := _screen(game._cell_center(Vector2i(13, 7)))
	var actor_delta := _brightness(light_on, actor_pos, 4) - _brightness(light_off, actor_pos, 4)
	var floor_delta := _brightness(light_on, floor_pos, 4) - _brightness(light_off, floor_pos, 4)
	var far_delta := absf(_brightness(light_on, far_pos, 4) - _brightness(light_off, far_pos, 4))
	var hud_delta := absf(_brightness(light_on, Vector2(820, 28), 4) - _brightness(light_off, Vector2(820, 28), 4))
	print("ELECTRIC_RENDER_MEASURE actor_delta=", actor_delta, " floor_delta=", floor_delta, " far_delta=", far_delta, " hud_delta=", hud_delta)
	_expect(actor_delta > 0.003, "arc light visibly affects the nearby ball")
	_expect(floor_delta > 0.003, "arc light visibly affects a nearby floor patch")
	_expect(far_delta < 0.012, "illumination remains local rather than flashing the whole board")
	_expect(hud_delta < 0.003, "the separate HUD is not illuminated by world arcs")

	# The baked highlight belongs to the body texture, not the rotation angle.
	# At rest, changing accumulated roll must leave the body pixels unchanged.
	game.player_roll_angle = 0.0
	var still_a: Image = await _capture("03-bola-repouso")
	game.player_roll_angle = PI * 0.5
	var still_b: Image = await _capture("04-bola-mesma-luz")
	var center := _screen(game._cell_center(game.player_position))
	var changed := 0
	for y in range(int(center.y) - 20, int(center.y) + 21):
		for x in range(int(center.x) - 20, int(center.x) + 21):
			if x < 0 or y < 0 or x >= still_a.get_width() or y >= still_a.get_height():
				continue
			if still_a.get_pixel(x, y) != still_b.get_pixel(x, y):
				changed += 1
	_expect(changed == 0, "resting ball lighting does not spin with accumulated roll")

	# At the same in-motion pose, alter only accumulated roll. A small rolling
	# seam should change, but the highlight patch must remain fixed on screen.
	for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
		game.player_position = Vector2i(9, 7)
		game.facing = direction
		game._reset_player_visual(game._cell_center(game.player_position))
		game.turn_number = 0
		game.try_move(direction.x, direction.y)
		game._process(0.07)
		_expect(game.player_motion.is_active(), "movement fixture is genuinely in flight for " + str(direction))
		var axis_name := "horizontal" if direction == Vector2i.RIGHT else "vertical"
		game.player_roll_angle = 0.0
		var moving_a: Image = await _capture("04b-movimento-%s-roll0" % axis_name)
		game.player_roll_angle = PI * 0.5
		var moving_b: Image = await _capture("04c-movimento-%s-roll90" % axis_name)
		var moving_center := _screen(game._player_visual_position())
		var highlight := moving_center + Vector2(-7, -10)
		var highlight_delta := absf(_brightness(moving_a, highlight, 2) - _brightness(moving_b, highlight, 2))
		var body_changed := 0
		for y in range(int(moving_center.y) - 15, int(moving_center.y) + 16):
			for x in range(int(moving_center.x) - 15, int(moving_center.x) + 16):
				if x >= 0 and y >= 0 and x < moving_a.get_width() and y < moving_a.get_height() and moving_a.get_pixel(x, y) != moving_b.get_pixel(x, y):
					body_changed += 1
		print("PLAYER_ROLL_RENDER_MEASURE direction=", direction, " highlight_delta=", highlight_delta, " changed_pixels=", body_changed)
		_expect(highlight_delta < 0.002, "highlight remains fixed during moving roll " + str(direction))
		_expect(body_changed > 0, "rolling surface seam remains visible while moving " + str(direction))
	game.player_position = Vector2i(9, 7)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.turn_number = 0
	game._update_camera(0.0)

	# Also exercise a creature and a conducting crate on the real world layer.
	var enemy_cell := Vector2i(8, 6)
	var crate_cell := Vector2i(8, 8)
	game.enemies.append(game._make_enemy(enemy_cell, "sentry"))
	game.environment.reset({"cells": {source: {"kind": "water", "source": true}, live_water: {"kind": "water"}}, "crates": [{"pos": crate_cell, "material": "metal"}]})
	game.electric_visual_glow[crate_cell] = 1.0
	game.electric_presentation.update_presentation(game._visible_world_rect(), true, 0.0)
	var actors_lit: Image = await _capture("05-inimigo-e-metal-iluminados")
	for light in game.electric_presentation.lights:
		light.enabled = false
	var actors_unlit: Image = await _capture("06-inimigo-e-metal-sem-luz")
	var enemy_delta := _brightness(actors_lit, _screen(game._cell_center(enemy_cell) + Vector2(0, 11)), 4) - _brightness(actors_unlit, _screen(game._cell_center(enemy_cell) + Vector2(0, 11)), 4)
	var crate_delta := _brightness(actors_lit, _screen(game._cell_center(crate_cell) + Vector2(0, -7)), 4) - _brightness(actors_unlit, _screen(game._cell_center(crate_cell) + Vector2(0, -7)), 4)
	print("ELECTRIC_RENDER_MEASURE enemy_delta=", enemy_delta, " crate_delta=", crate_delta)
	_expect(enemy_delta > 0.003, "world lighting reaches a nearby creature")
	_expect(crate_delta > 0.003, "world lighting reaches the nearby metal crate")

	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ELECTRIC_RENDER_PASS checks=", checks, " real local light and stable highlight at rest and in motion")
		quit(0)
	else:
		printerr("ELECTRIC_RENDER_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
