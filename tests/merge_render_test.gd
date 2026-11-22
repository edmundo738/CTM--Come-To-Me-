extends SceneTree

# Requires a real renderer. Optional MERGE_RENDER_TEST_OUT saves screenshots;
# browser-evidence emits the frames from the isolated Web harness as well.
const Game = preload("res://game.gd")
const Special = preload("res://special_levels.gd")

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


func _set_size(target: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target)
	root.size = target
	root.content_scale_size = target
	await process_frame
	await process_frame


func _capture(name: String) -> Image:
	game.queue_redraw()
	game.hud.queue_redraw()
	game.terrain_renderer.sync_view(game._visible_world_rect(), true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(not image.is_empty(), name + " is a rendered frame")
	var output := OS.get_environment("MERGE_RENDER_TEST_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")
	if OS.get_cmdline_user_args().has("browser-evidence") and not image.is_empty():
		print("MERGE_IMAGE ", name, " ", Marshalls.raw_to_base64(image.save_png_to_buffer()))
	return image


func _button(action: String) -> Dictionary:
	for button in game.hud.buttons:
		if str(button.action) == action:
			return button
	return {}


func _changed_pixels(first: Image, second: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(maxi(0, area.position.y), mini(first.get_height(), area.end.y)):
		for x in range(maxi(0, area.position.x), mini(first.get_width(), area.end.x)):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("MERGE_RENDER_NOT_TESTED: a real rendering backend is required")
		quit(2)
		return
	await _set_size(Vector2i(1280, 720))
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.audio.stop_all()
	game.set_process(false)
	game.hud.set_process(false)
	game.new_game(19372)
	game.floor_number = 4
	game.game_state = "floor_clear"
	game.advance_floor()
	game.enemies.clear()
	game.animation_clock = 0.0
	game._update_camera(0.0)
	game.camera.force_update_scroll()
	await process_frame
	game.hud.visible = false
	game.captor_flyover_time = 0.0
	var without: Image = await _capture("01-andar-sem-cena")
	game.captor_flyover_time = game.CAPTOR_FLYOVER_SECONDS * 0.70710678
	var with_scene: Image = await _capture("02-lia-e-capturador")
	var region := Rect2i(300, 80, 680, 480)
	var changed := _changed_pixels(without, with_scene, region)
	_expect(changed > 500, "captor and cage actually render into the world layer")
	print("MERGE_RENDER_MEASURE cinematic_changed_pixels=", changed)
	game.hud.visible = true
	await _capture("03-cena-e-controlo-1280")
	var button := _button("skip_captor_flyover")
	_expect(not button.is_empty() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get("rect", Rect2())), "cinematic skip is visible and inside the wide viewport")
	await _set_size(Vector2i(800, 540))
	game._update_camera(0.0)
	game.camera.force_update_scroll()
	await _capture("04-cena-e-controlo-800")
	button = _button("skip_captor_flyover")
	_expect(not button.is_empty() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get("rect", Rect2())), "cinematic skip is visible and inside the narrow viewport")
	game.handle_hud_action("skip_captor_flyover")
	_expect(is_zero_approx(game.captor_flyover_time), "rendered skip action ends the cinematic")
	game.active_seed = 1
	game.floor_number = 7
	game.special_family = "sokoban"
	var spec: Dictionary = Special.make("sokoban", 1, 7)
	var plan: Dictionary = Special.solve(spec, spec.start, spec.crates)
	game._generate_special_room(spec, plan, 123)
	game.game_state = "playing"
	game._update_camera(0.0)
	game.camera.force_update_scroll()
	await _capture("05-sokoban-800")
	button = _button("undo_sokoban")
	_expect(not button.is_empty() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get("rect", Rect2())), "Sokoban undo button is inside the narrow viewport")
	var start: Vector2i = game.player_position
	game.try_move(1, 0)
	await _capture("06-caixa-empurrada")
	game.handle_hud_action("undo_sokoban")
	_expect(game.player_position == start and game.sokoban_pushes == 0, "the displayed undo button invokes the real rollback")
	game.dev_load_sandbox_arena()
	await _capture("07-indicador-dev")
	_expect(game.dev_sandbox_active, "dev banner frame corresponds to an isolated sandbox")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("MERGE_RENDER_PASS checks=", checks, " cinematic, skip, Sokoban undo and dev indicator at two sizes")
		quit(0)
	else:
		printerr("MERGE_RENDER_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
