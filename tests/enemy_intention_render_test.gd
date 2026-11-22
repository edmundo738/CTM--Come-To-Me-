extends SceneTree

# Run with a real renderer (e.g. X11 + gl_compatibility), not --headless.
# This isolates the actual enemy drawing code on a black canvas so comparisons
# detect projected graphics as well as changes to the body itself.
class EnemyCanvas extends "res://game.gd":
	var subject: Dictionary = {}

	func _ready() -> void:
		set_process(false)

	func _draw() -> void:
		if not subject.is_empty():
			_draw_enemy(subject)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var failures: Array[String] = []
var checks := 0
var canvas: EnemyCanvas


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _capture() -> Image:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _pixel_bounds(image: Image, center: Vector2, radius: float) -> Vector2i:
	var inside := 0
	var outside := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) <= 0.02:
				continue
			if Vector2(x, y).distance_squared_to(center) <= radius * radius:
				inside += 1
			else:
				outside += 1
	return Vector2i(inside, outside)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ENEMY_INTENTION_RENDER_NOT_TESTED: a real rendering backend is required")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
	# The game normally stretches a 1280x720 canvas. Make world coordinates
	# map 1:1 to this smaller capture before testing the spatial bounds.
	root.content_scale_size = Vector2i(640, 360)
	RenderingServer.set_default_clear_color(Color.BLACK)
	canvas = EnemyCanvas.new()
	canvas.animation_clock = 0.73
	canvas.player_position = Vector2i(9, 3)
	canvas._reset_player_visual(canvas._cell_center(canvas.player_position))
	root.add_child(canvas)
	var origin := Vector2i(4, 3)
	for role in ["hunter", "rusher", "wisp", "sentry", "patrol", "mirror", "warden", "chess_boss"]:
		var enemy: Dictionary
		if role == "warden":
			enemy = canvas._make_warden(origin)
		elif role == "chess_boss":
			canvas.floor_number = 15
			enemy = canvas._make_boss(origin)
		else:
			enemy = canvas._make_enemy(origin, role)
		enemy.alert = true
		enemy.face = Vector2i.RIGHT
		canvas._queue_enemy_visual(enemy, origin, origin + Vector2i.RIGHT)
		enemy["_visual_motion"].advance(0.055)
		enemy.next = Vector2i(1, 1)
		enemy.path = [Vector2i(1, 1), Vector2i(2, 1)]
		canvas.subject = enemy
		var first: Image = await _capture()
		enemy.next = Vector2i(10, 5)
		enemy.path = [Vector2i(9, 5), Vector2i(10, 5)]
		var second: Image = await _capture()
		_expect(first.get_data() == second.get_data(), "%s pixels must not depend on enemy.next/path" % role)
		var bounds := _pixel_bounds(first, canvas._enemy_visual_position(enemy), 95.0)
		_expect(bounds.x > 30, "%s body actually rendered; a blank frame cannot pass" % role)
		_expect(bounds.y == 0, "%s alert draws no remote line, reticle, path or cell indicator" % role)
		var output_dir := OS.get_environment("ENEMY_RENDER_TEST_OUT")
		if not output_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(output_dir)
			first.save_png(output_dir.path_join(role + ".png"))
	canvas.queue_free()
	await process_frame

	# Also exercise the normal board draw and HUD, not only the isolated body.
	var full_game = load("res://game.gd").new()
	full_game.persistence_enabled = false
	root.add_child(full_game)
	full_game.dev_load_sandbox_arena()
	full_game.audio.effects_enabled = false
	full_game.audio.stop_all()
	full_game.set_process(false)
	full_game.hud.set_process(false)
	full_game.enemies.clear()
	full_game.player_position = Vector2i(9, 7)
	full_game._reset_player_visual(full_game._cell_center(full_game.player_position))
	full_game.animation_clock = 0.73
	full_game._update_camera(0.0)
	full_game.camera.force_update_scroll()
	full_game.background_rect.visible = false
	var actual_enemy: Dictionary = full_game._make_enemy(Vector2i(7, 7), "hunter")
	actual_enemy.alert = true
	actual_enemy.next = Vector2i(6, 7)
	actual_enemy.path = [Vector2i(6, 7)]
	full_game.enemies.append(actual_enemy)
	full_game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var board_before: Image = root.get_texture().get_image()
	actual_enemy.next = Vector2i(8, 7)
	actual_enemy.path = [Vector2i(8, 7)]
	full_game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var board_after: Image = root.get_texture().get_image()
	_expect(board_before.get_data() == board_after.get_data(), "normal board and HUD pixels must not depend on enemy.next/path")
	actual_enemy.alert = false
	full_game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var changed_body: Image = root.get_texture().get_image()
	_expect(board_after.get_data() != changed_body.get_data(), "positive control: the normal board actually shows the enemy alert change")
	full_game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_INTENTION_RENDER_PASS checks=", checks, " (8 visible roles, changed next/path, no remote graphics, normal board/HUD)")
		quit(0)
	else:
		printerr("ENEMY_INTENTION_RENDER_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
