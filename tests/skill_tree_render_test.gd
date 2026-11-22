extends SceneTree

# Requires a real renderer, e.g. xvfb-run with X11 + gl_compatibility.
# Optional: SKILL_RENDER_TEST_OUT=/absolute/path saves representative frames.
const Game = preload("res://game.gd")
var checks := 0
var failures: Array[String] = []
var game: Node


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
	game.hud.queue_redraw()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.get_width() == root.size.x and image.get_height() == root.size.y, name + " has expected resolution")
	var output := OS.get_environment("SKILL_RENDER_TEST_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")
	return image


func _buttons_inside(name: String) -> void:
	var area := Rect2(Vector2.ZERO, Vector2(root.size))
	for button in game.hud.buttons:
		_expect(area.encloses(button.rect), name + " button inside viewport: " + str(button.action))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SKILL_TREE_RENDER_NOT_TESTED: a real rendering backend is required")
		quit(2)
		return
	await _set_size(Vector2i(800, 540))
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.audio.stop_all()
	game.set_process(false)
	game.hud.set_process(false)
	game.new_game(31337)
	game.skills.points = 12
	game.game_state = "title"
	await _capture("01-titulo-800")
	_buttons_inside("title")
	game.handle_hud_action("skills")
	await _capture("02-arvore-vida-800")
	_buttons_inside("tree")
	_expect(game.hud.buttons.size() == 15, "tree exposes six tabs, six nodes and three actions")
	game.handle_hud_action("skill_unlock")
	game.handle_hud_action("skill_toggle")
	game.handle_hud_action("skill_node:heart_2")
	await _capture("03-arvore-ativas-800")
	_expect(game.skills.active.has("heart_1") and game.hearts_current == 1, "captured activated heart reflects actual game state")
	game.handle_hud_action("skill_node:heart_1")
	game.handle_hud_action("skill_toggle")
	await _capture("04-confirmar-coracao-800")
	_expect(game.game_state == "skill_confirm" and game.hud.focus_action == "skill_remove_cancel", "heart loss has a cancel-first confirmation")
	_buttons_inside("heart confirmation")
	game.handle_hud_action("skill_remove_cancel")
	game.handle_hud_action("skill_branch:engenharia")
	await _capture("05-arvore-engenharia-800")
	game.handle_hud_action("skill_back")
	game.handle_hud_action("new_run")
	await _capture("06-campanhas-800")
	_buttons_inside("campaigns")
	game.handle_hud_action("campaign:0")
	await _capture("07-confirmar-campanha-800")
	_expect(game.game_state == "campaign_confirm" and game.hud.focus_action == "campaign_cancel", "replacement has a cancel-first confirmation")
	game.handle_hud_action("campaign_cancel")
	game.game_state = "playing"
	game.charges = 2
	game._update_camera(0.0)
	game.camera.force_update_scroll()
	await _capture("08-hud-800")
	game.profile_message = "NAO FOI POSSIVEL GUARDAR. TENTE NOVAMENTE."
	var warning: Image = await _capture("09-aviso-save-800")
	var pixel := warning.get_pixel(12, 10)
	_expect(pixel.r > pixel.g * 1.5 and pixel.r > pixel.b * 1.2, "save warning rendered visibly on top of gameplay")
	game.game_state = "paused"
	warning = await _capture("10-aviso-save-pausa-800")
	pixel = warning.get_pixel(12, 10)
	_expect(pixel.r > pixel.g * 1.5 and pixel.r > pixel.b * 1.2, "save warning remains above the pause modal")
	game.profile_message = ""
	await _set_size(Vector2i(1280, 720))
	game.game_state = "title"
	game.handle_hud_action("skills")
	game.handle_hud_action("skill_branch:exploracao")
	await _capture("11-arvore-1280")
	_buttons_inside("wide tree")
	game.handle_hud_action("skill_back")
	game.handle_hud_action("campaigns")
	await _capture("12-campanhas-1280")
	_buttons_inside("wide campaigns")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("SKILL_TREE_RENDER_PASS checks=", checks, ": real renderer, two sizes, modals and save warning")
		quit(0)
	else:
		printerr("SKILL_TREE_RENDER_FAIL ", failures)
		quit(1)
