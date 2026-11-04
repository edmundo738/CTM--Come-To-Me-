extends SceneTree

# Runs on an actual Godot renderer (X11/OpenGL or WebGL), not --headless.
# Optional COMBAT_RENDER_TEST_OUT saves frames. `-- evidence=1` emits each
# exact captured PNG as base64 for a Web harness with a private filesystem.
const Game = preload("res://game.gd")

var game: Node
var checks := 0
var failures: Array[String] = []
var evidence_mode := false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
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
	game.damage_this_turn = false
	game.skills.load_state({})
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.camera.offset = Vector2.ZERO
	game._update_camera(0.0)
	game.terrain_renderer.rebuild()


func _capture(name: String) -> Image:
	# Let the viewport adopt its requested size before snapping the fixture's
	# camera. Automatic processing is disabled, so sync visible terrain here.
	await process_frame
	game._update_camera(0.0)
	game.terrain_renderer.sync_view(game._visible_world_rect(), game._world_is_visible())
	game.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), name + " has a real rendered image")
	if image == null or image.is_empty():
		return Image.new()
	var output := OS.get_environment("COMBAT_RENDER_TEST_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")
	print("COMBAT_RENDER_STAGE ", name)
	if evidence_mode and not image.is_empty():
		# Web's filesystem is private to the engine. Emit the exact captured
		# frame for the harness rather than racing an asynchronous screenshot.
		print("COMBAT_RENDER_IMAGE ", name, " ", Marshalls.raw_to_base64(image.save_png_to_buffer()))
	return image


func _changed_pixels(first: Image, second: Image, world_center: Vector2, radius: int = 62) -> int:
	if first.is_empty() or second.is_empty():
		return 0
	var screen: Vector2 = world_center - game.camera.global_position + Vector2(root.size) * 0.5 + game.camera.offset
	var center := Vector2i(roundi(screen.x), roundi(screen.y))
	var count := 0
	for y in range(maxi(0, center.y - radius), mini(first.get_height(), center.y + radius), 2):
		for x in range(maxi(0, center.x - radius), mini(first.get_width(), center.x + radius), 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.20:
				count += 1
	return count


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("COMBAT_RENDER_NOT_TESTED: a real rendering backend is required")
		quit(2)
		return
	evidence_mode = OS.get_cmdline_user_args().has("evidence=1")
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

	_arena()
	game.floor_number = 1
	game.grid[7][10] = game.TILE_WALL
	game.terrain_renderer.rebuild()
	game.breach_charges = 1
	var wall_before: Image = await _capture("01-parede-antes")
	game.try_break_wall()
	game._process(0.035)
	var wall_windup: Image = await _capture("02-parede-antecipacao")
	game._process(0.035)
	var wall_contact: Image = await _capture("03-parede-contacto")
	game._process(0.13)
	var wall_chips: Image = await _capture("04-parede-fragmentos")
	var wall_point: Vector2 = game._cell_center(Vector2i(10, 7))
	_expect(_changed_pixels(wall_before, wall_contact, wall_point) > 80, "stone opening/contact is visible in the actual board")
	_expect(_changed_pixels(wall_contact, wall_chips, wall_point) > 15, "stone fragments visibly evolve after contact")
	_expect(_changed_pixels(wall_before, wall_windup, game._cell_center(Vector2i(9, 7))) > 15, "player preparation renders before the contact")

	_arena()
	game.floor_number = 7
	game.grid[7][10] = game.TILE_WALL
	game.terrain_renderer.rebuild()
	game.breach_charges = 1
	game.try_break_wall()
	game._process(0.07)
	game._process(0.13)
	var glass_chips: Image = await _capture("05-vidro-fragmentos")
	_expect(_changed_pixels(wall_chips, glass_chips, wall_point) > 30, "glass and stone destruction render differently")

	_arena()
	game.floor_number = 1
	game.breach_charges = 1
	game.enemies.append(game._make_enemy(Vector2i(10, 7), "rusher"))
	var enemy_before: Image = await _capture("06-rusher-antes")
	game.try_break_wall()
	game._process(0.07)
	var enemy_contact: Image = await _capture("07-rusher-contacto")
	game._process(0.16)
	var enemy_breaking: Image = await _capture("08-rusher-reaccao")
	_expect(game.enemies.is_empty() and game.enemy_defeat_visuals.size() == 1, "defeat is already logical while the ghost remains visual")
	_expect(_changed_pixels(enemy_before, enemy_contact, wall_point) > 20, "enemy contact visibly changes its committed silhouette")
	_expect(_changed_pixels(enemy_contact, enemy_breaking, wall_point) > 15, "enemy defeat visibly progresses")

	_arena()
	game.charges = 1
	var hunter: Dictionary = game._make_enemy(Vector2i(10, 7), "hunter")
	hunter.next = game.player_position
	game.enemies.append(hunter)
	var shield_before: Image = await _capture("09-escudo-antes")
	game.try_move(1, 0)
	game._process(0.14)
	var shield_contact: Image = await _capture("10-escudo-contacto")
	_expect(game.charges == 0 and game.enemies[0].pos == Vector2i(12, 7), "shield recoil retains its actual logical outcome")
	_expect(_changed_pixels(shield_before, shield_contact, wall_point) > 20, "shield contact and recoil are actually rendered")
	var enemy_draw_position: Vector2 = game._enemy_contact_draw_position(game.enemies[0])
	_expect(enemy_draw_position.distance_to(game._player_visual_position()) >= 30.0, "enemy silhouette is kept beside the player at shield contact")
	var contact_enemy: Dictionary = game.enemies.pop_back()
	var without_enemy: Image = await _capture("10b-escudo-controlo-sem-inimigo")
	_expect(_changed_pixels(shield_contact, without_enemy, enemy_draw_position, 14) > 35, "the enemy body itself is visible in the rendered contact frame")
	game.enemies.append(contact_enemy)
	game._process(0.4)
	await _capture("11-escudo-recuperacao")

	_arena()
	game.grid[7][10] = game.TILE_WATER
	game.environment.reset({"cells": {Vector2i(10, 7): {"kind": "water", "source": true}}})
	game.terrain_renderer.rebuild()
	game.charges = 1
	await _capture("12-choque-fonte-antes")
	game.try_move(1, 0)
	game._process(0.15)
	var electricity: Image = await _capture("12-choque-electrico")
	_expect(game.charges == 0 and game.player_position == Vector2i(10, 7), "electric impact remains a real environmental rule")
	_expect(not electricity.is_empty() and game.impact_presentation.effects.size() >= 1, "electrical contact is shown without replacing the hazard")

	# Preserve and inspect grounded, hard, floating and elite silhouettes in
	# real captures, not merely the shared rusher/contact effect.
	for role in ["hunter", "sentry", "wisp", "warden"]:
		_arena()
		game.breach_charges = 1
		var actor: Dictionary = game._make_warden(Vector2i(10, 7)) if role == "warden" else game._make_enemy(Vector2i(10, 7), role)
		if role == "warden":
			actor.hp = 1
		game.enemies.append(actor)
		var before: Image = await _capture("13-" + role + "-antes")
		game.try_break_wall()
		game._process(0.035)
		await _capture("14-" + role + "-antecipacao")
		_expect(game.enemies.is_empty() and str(game.enemy_defeat_visuals[0].role) == role and float(game.enemy_defeat_visuals[0].age) < 0.0, role + " is logically defeated but keeps its original art before contact")
		game._process(0.035)
		var contact: Image = await _capture("15-" + role + "-contacto")
		game._process(0.27)
		var breakup: Image = await _capture("16-" + role + "-reaccao")
		_expect(_changed_pixels(before, contact, wall_point, 45) > 12, role + " contact changes its own visible silhouette")
		_expect(_changed_pixels(contact, breakup, wall_point, 45) > 10, role + " defeat visibly evolves after the hold")

	# The anticipation below is a move the enemy has already committed; no
	# predicted next/path is rendered. Include the actual L-shaped knight hop.
	for role in ["hunter", "rusher", "sentry", "wisp", "warden", "knight"]:
		_arena()
		game.charges = 1
		var origin := Vector2i(11, 8) if role == "knight" else Vector2i(10, 7)
		var attacker: Dictionary
		if role == "knight":
			game.floor_number = 15
			attacker = game._make_boss(origin)
		elif role == "warden":
			attacker = game._make_warden(origin)
		else:
			attacker = game._make_enemy(origin, role)
		attacker.next = game.player_position
		game.enemies.append(attacker)
		game.wait_turn()
		var track = game.enemies[0].get("_visual_motion")
		var expected := "enemy_jump_attack" if role == "knight" else "enemy_attack"
		_expect(track != null and track.kind == expected and game.charges == 0, role + " attack pose belongs to a resolved contact")
		var halfway: float = float(track.duration) * 0.5
		game._process(halfway)
		var attack_frame: Image = await _capture("25-ataque-" + role + "-aproximacao")
		var visible: Vector2 = game._enemy_visual_position(game.enemies[0])
		_expect(not attack_frame.is_empty() and not visible.is_equal_approx(game._cell_center(origin)) and not visible.is_equal_approx(game._cell_center(Vector2i(9, 7))), role + " visibly approaches its committed target")
		game._process(halfway)
		await _capture("26-ataque-" + role + "-contacto")

	for material in ["wood", "metal"]:
		_arena()
		game.environment.reset({"crates": [{"pos": Vector2i(10, 7), "material": material}]})
		await _capture("17-caixa-" + material + "-antes")
		game.try_move(1, 0)
		game._process(0.035)
		var push: Image = await _capture("18-caixa-" + material + "-contacto")
		_expect(not push.is_empty() and game.player_position == Vector2i(10, 7) and game.environment.crates[0].pos == Vector2i(11, 7), material + " push stays visually tied to the resolved crate")

	_arena()
	game.environment.reset({"crates": [{"pos": Vector2i(10, 7), "material": "metal"}]})
	game.grid[7][11] = game.TILE_WALL
	game.terrain_renderer.rebuild()
	game.try_move(1, 0)
	game._process(0.04)
	await _capture("19-caixa-bloqueada")
	_expect(game.turn_number == 0 and game.player_position == Vector2i(9, 7) and game.environment.crates[0].pos == Vector2i(10, 7), "blocked crate does not invent movement")

	_arena()
	game.skills.points = 2
	game.skills.unlock("heart_1")
	game.skills.toggle("heart_1")
	game.hearts_current = 1
	var attacker: Dictionary = game._make_enemy(Vector2i(10, 7), "hunter")
	attacker.next = game.player_position
	game.enemies.append(attacker)
	game.wait_turn()
	game._process(0.07)
	await _capture("20-coracao-aproximacao")
	game._process(0.07)
	var heart_contact: Image = await _capture("21-coracao-contacto")
	game._process(0.24)
	var heart_recoil: Image = await _capture("22-coracao-recuo")
	_expect(game.hearts_current == 0 and game.player_position == Vector2i(8, 7) and _changed_pixels(heart_contact, heart_recoil, game._cell_center(Vector2i(9, 7))) > 12, "heart loss and recoil are rendered without delaying their logical result")

	_arena()
	game.enemies.append(game._make_enemy(Vector2i(10, 7), "hunter"))
	game.try_move(1, 0)
	game._process(0.14)
	await _capture("23-captura-contacto")
	game._process(0.85)
	await _capture("24-captura-desfecho")
	_expect(game.game_state == "captured" and game.capture_popped, "capture still reaches its existing consequence")

	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_RENDER_PASS checks=", checks, " board, materials, enemy roles, crates, shield, heart, electricity and capture")
		quit(0)
	else:
		printerr("COMBAT_RENDER_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
