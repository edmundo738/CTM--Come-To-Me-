extends SceneTree

const ControllerScript = preload("res://controller_input.gd")
const GameScript = preload("res://game.gd")
var failures: Array[String] = []


class FakeInput extends RefCounted:
	var devices := {
		2: {"name": "Xbox Wireless Controller", "guid": "xbox-guid", "serial": "xbox-a", "known": true, "rumble": true},
		7: {"name": "Sony PlayStation 3 Controller", "guid": "ps3-guid", "serial": "ps3-b", "known": true, "rumble": true},
		11: {"name": "Generic Arcade Stick", "guid": "generic-guid", "serial": "", "known": false, "rumble": false},
	}
	var pulses: Array[Dictionary] = []
	var stopped: Array[int] = []

	func get_connected_joypads() -> Array:
		return devices.keys()

	func get_joy_name(id: int) -> String:
		return devices[id].name

	func get_joy_guid(id: int) -> String:
		return devices[id].guid

	func get_joy_info(id: int) -> Dictionary:
		var serial: String = devices[id].serial
		return {"serial_number": serial} if not serial.is_empty() else {}

	func is_joy_known(id: int) -> bool:
		return devices[id].known

	func has_joy_vibration(id: int) -> bool:
		return devices[id].rumble

	func start_joy_vibration(id: int, weak: float, strong: float, duration: float) -> void:
		pulses.append({"id": id, "weak": weak, "strong": strong, "duration": duration})

	func stop_joy_vibration(id: int) -> void:
		stopped.append(id)


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var fake := FakeInput.new()
	var manager = ControllerScript.new()
	manager.set_backend(fake)
	root.add_child(manager)
	var actions: Array[String] = []
	var calibration_results: Array[bool] = []
	manager.action_requested.connect(func(action: String): actions.append(action))
	manager.calibration_finished.connect(func(saved: bool): calibration_results.append(saved))

	_test_detection_and_navigation(manager, fake, actions)
	_test_haptics_and_multiple_devices(manager, fake, actions)
	_test_mapping_and_hotplug(manager, fake, actions, calibration_results)
	_test_game_integration(fake)
	_test_profile_settings()

	manager.queue_free()
	await process_frame
	await _test_rendered_menus(fake)
	if failures.is_empty():
		print("CONTROLLER_TEST_PASS: multiplos comandos, menus, eixos, remapeamento, persistencia e vibracao simulada")
	else:
		printerr("CONTROLLER_TEST_FAIL: %d check(s): %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _button(manager: Node, id: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = id
	event.button_index = index
	event.pressed = pressed
	manager.handle_event(event)


func _tap(manager: Node, id: int, index: int) -> void:
	_button(manager, id, index, true)
	_button(manager, id, index, false)


func _dispatch_tap(id: int, index: int) -> void:
	# Exercise the actual SceneTree input path as well as direct unit delivery.
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = id
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _axis(manager: Node, id: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = id
	event.axis = axis
	event.axis_value = value
	manager.handle_event(event)


func _test_detection_and_navigation(manager: Node, fake: FakeInput, actions: Array[String]) -> void:
	_expect(manager.connected_devices() == [2, 7, 11] and manager.active_device == 2, "detects all connected ids without assuming device zero")
	_expect(manager.device_family(2) == "XBOX" and manager.device_family(7) == "PLAYSTATION" and manager.device_family(11) == "GENERICO", "recognizes Xbox, PS3 and generic names")
	_expect(manager.device_is_known(2) and not manager.device_is_known(11), "distinguishes normalized and unknown gamepads")
	_expect(manager.device_has_vibration(7) and not manager.device_has_vibration(11), "reports driver-advertised rumble without claiming physical confirmation")
	fake.devices[3] = {"name": "Xbox Wireless Controller", "guid": "xbox-guid", "serial": "xbox-other", "known": true, "rumble": true}
	_expect(manager.device_key(2) != manager.device_key(3), "serials distinguish otherwise identical pads when available")
	fake.devices.erase(3)
	_tap(manager, 7, JOY_BUTTON_A)
	_expect(actions == ["confirm"] and manager.active_device == 7, "PS3 face button is normalized and activates its own id")
	_tap(manager, 2, JOY_BUTTON_RIGHT_SHOULDER)
	_expect(actions.back() == "blink" and manager.active_device == 2, "another pad becomes active when it is used")
	var count := actions.size()
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.25)
	_expect(actions.size() == count and manager.active_device == 2, "stick noise inside the deadzone does not navigate or steal focus")
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.8)
	_expect(actions.back() == "right" and manager.active_device == 7, "analog movement uses the actual event device and sign")
	count = actions.size()
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.48)
	manager.tick(0.31)
	_expect(actions.size() == count, "hysteresis holds direction without an early repeat")
	manager.tick(0.02)
	_expect(actions.size() == count + 1 and actions.back() == "right", "held stick repeats after its initial delay")
	manager.tick(2.0)
	_expect(actions.size() == count + 2, "a long frame cannot produce a burst of extra moves")
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.0)
	count = actions.size()
	manager.tick(0.6)
	_expect(actions.size() == count, "returning to neutral stops repeats")
	_axis(manager, 7, JOY_AXIS_LEFT_X, -0.8)
	_expect(actions.back() == "left", "negative fractional axis movement points left")
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.0)
	_tap(manager, 7, JOY_BUTTON_DPAD_UP)
	_expect(actions.back() == "up", "D-pad produces a directional action")
	_axis(manager, 7, JOY_AXIS_LEFT_X, -0.9)
	_axis(manager, 7, JOY_AXIS_LEFT_Y, -0.9)
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.9)
	_expect(actions.back() == "up", "a diagonal tie never keeps a direction that is no longer held")
	_axis(manager, 7, JOY_AXIS_LEFT_X, 0.0)
	_axis(manager, 7, JOY_AXIS_LEFT_Y, 0.0)

	var key: String = manager.device_key(7)
	manager.custom_mappings[key] = {"confirm": {"type": "axis", "index": 3, "sign": 1}}
	manager.reset_held_inputs()
	actions.clear()
	_axis(manager, 7, 3, 0.8)
	_axis(manager, 7, 3, 0.48)
	_axis(manager, 7, 3, 0.6)
	_expect(actions == ["confirm"], "an axis bound to a button uses hysteresis rather than repeating from threshold jitter")
	_tap(manager, 2, JOY_BUTTON_A)
	_axis(manager, 7, 3, 0.0)
	_axis(manager, 7, 3, 0.8)
	_expect(actions == ["confirm", "confirm", "confirm"] and manager.active_device == 7, "axis releases are tracked even while another gamepad is active")
	manager.custom_mappings[key] = {"confirm": 99}
	_expect(manager.button_label("confirm") == "CRUZ", "a malformed saved binding falls back to a safe default label")
	manager.custom_mappings.erase(key)
	manager.reset_held_inputs()


func _test_haptics_and_multiple_devices(manager: Node, fake: FakeInput, actions: Array[String]) -> void:
	_tap(manager, 7, JOY_BUTTON_A)
	fake.pulses.clear()
	_expect(manager.feedback("step"), "step feedback is sent for the active gamepad")
	_expect(manager.feedback("hit"), "hit feedback is sent for the active gamepad")
	_expect(fake.pulses.size() == 2 and fake.pulses[0].id == 7 and fake.pulses[1].id == 7, "rumble is routed to the last used pad, not zero")
	_expect(fake.pulses[0].strong < fake.pulses[1].strong and fake.pulses[0].duration < fake.pulses[1].duration, "steps and impacts have distinct patterns")
	for pulse in fake.pulses:
		_expect(pulse.duration > 0.0 and pulse.duration <= 0.5 and pulse.weak >= 0.0 and pulse.weak <= 1.0 and pulse.strong >= 0.0 and pulse.strong <= 1.0, "haptic strengths are bounded and durations finite")
	manager.select_active_device()
	manager.select_next_device()
	_expect(manager.selected_device == 11, "settings can select another connected device")
	_tap(manager, 2, JOY_BUTTON_A)
	_expect(manager.active_device == 2 and manager.selected_device == 11, "a menu operated by one pad retains the separately selected pad")
	_expect(manager.feedback("test", true, manager.selected_device) and fake.pulses.back().id == 11, "test pulse targets the selected generic pad even when support is unconfirmed")
	manager.note_keyboard_or_mouse()
	var count := fake.pulses.size()
	_expect(not manager.feedback("hit") and fake.pulses.size() == count, "keyboard or touch does not produce unexpected gamepad rumble")
	manager.set_vibration_enabled(false)
	_expect(not manager.feedback("test", true, 7) and fake.stopped.has(2) and fake.stopped.has(7), "disabling vibration stops motors and suppresses even test pulses")
	manager.set_vibration_enabled(true)
	_expect(manager.feedback("test", true, 7), "test vibration works without first using a gamepad")
	_tap(manager, 2, JOY_BUTTON_RIGHT_SHOULDER)
	_expect(actions.has("blink"), "other gamepad actions remain available")


func _test_mapping_and_hotplug(manager: Node, fake: FakeInput, actions: Array[String], results: Array[bool]) -> void:
	manager.reset_held_inputs()
	_expect(manager.begin_calibration(11), "can start the wizard on an unknown generic pad")
	_expect(not manager.skip_calibration_step() and manager.calibration_step == 0, "required mappings cannot be skipped")
	var count := actions.size()
	_tap(manager, 2, JOY_BUTTON_A)
	_expect(manager.calibration_step == 0 and actions.size() == count, "other pads cannot interfere with calibration")
	_axis(manager, 11, 5, -0.9)
	_axis(manager, 11, 5, 0.0)
	_axis(manager, 11, 5, 0.9)
	_axis(manager, 11, 5, 0.0)
	_axis(manager, 11, 4, -0.9)
	_axis(manager, 11, 4, 0.0)
	_expect(manager.calibration_step == 3, "wizard captures separate negative and positive axis directions")
	_axis(manager, 11, 4, -0.9)
	_expect(manager.calibration_step == 3 and "JA ESTA EM USO" in manager.calibration_message, "duplicate controls are rejected")
	_axis(manager, 11, 4, 0.0)
	_axis(manager, 11, 4, 0.9)
	_axis(manager, 11, 4, 0.0)
	_tap(manager, 11, 10)
	_tap(manager, 11, 11)
	_expect(manager.calibration_step == 6, "all required directions, confirm and cancel were captured")
	_button(manager, 11, 11, true)
	_expect(manager.calibration_step == 6, "optional skip waits for the mapped cancel button to be released")
	_button(manager, 11, 11, false)
	_expect(manager.calibration_step == 7 and manager.calibration_bindings["break"]["type"] == "none", "cancel button skips an optional action")
	_tap(manager, 11, 13)
	_tap(manager, 11, 14)
	_tap(manager, 11, 15)
	_tap(manager, 11, 16)
	_expect(results == [true] and manager.calibration_device < 0 and manager.has_custom_mapping(11), "completed mapping is saved atomically")
	var saved: Dictionary = manager.custom_mappings.duplicate(true)
	actions.clear()
	_tap(manager, 11, 10)
	_axis(manager, 11, 4, 0.8)
	_axis(manager, 11, 4, 0.0)
	_tap(manager, 11, 13)
	_expect(actions == ["confirm", "right", "wait"], "custom raw buttons and axes drive the same normalized actions")
	_tap(manager, 11, JOY_BUTTON_X)
	_expect(actions == ["confirm", "right", "wait"], "a skipped optional action does not fall back to a conflicting default")

	var reconnect: Dictionary = fake.devices[11].duplicate(true)
	fake.devices.erase(11)
	manager._on_joy_connection_changed(11, false)
	_expect(manager.active_device == 2 and not manager.using_gamepad and not manager.states.has(11), "unplugging the active pad clears held inputs without sending feedback to another player")
	fake.devices[14] = reconnect
	manager._on_joy_connection_changed(14, true)
	_expect(manager.has_custom_mapping(14), "GUID/name mapping survives a reconnect with a new device id")
	var fresh = ControllerScript.new()
	fresh.set_backend(fake)
	root.add_child(fresh)
	fresh.set_settings(false, saved)
	_expect(fresh.has_custom_mapping(14) and not fresh.vibration_enabled, "saved settings can initialize a new controller manager")
	_expect(fresh.clear_active_mapping(14) and not fresh.has_custom_mapping(14) and manager.has_custom_mapping(14), "restoring a mapping affects only that manager and selected device")
	fresh.queue_free()

	manager.selected_device = 14
	_expect(manager.begin_calibration(14), "can start another calibration")
	fake.devices.erase(14)
	manager._on_joy_connection_changed(14, false)
	_expect(manager.calibration_device < 0 and results.back() == false and manager.custom_mappings == saved, "disconnect cancels the wizard without replacing the saved mapping")
	fake.devices[11] = reconnect
	manager._on_joy_connection_changed(11, true)
	_expect(manager.begin_calibration(11), "can retry after reconnecting")
	_axis(manager, 11, 5, -0.9)
	_axis(manager, 11, 5, 0.0)
	_axis(manager, 11, 5, 0.9)
	_axis(manager, 11, 5, 0.0)
	_axis(manager, 11, 4, -0.9)
	_axis(manager, 11, 4, 0.0)
	_axis(manager, 11, 4, 0.9)
	_axis(manager, 11, 4, 0.0)
	_tap(manager, 11, 10)
	_tap(manager, 11, 11)
	_button(manager, 11, 11, true)
	manager.tick(1.0)
	_expect(manager.calibration_device < 0 and results.back() == false and manager.custom_mappings == saved, "holding cancel exits the wizard without overwriting its mapping")
	manager.reset_held_inputs()
	_expect(manager.begin_calibration(11), "wizard can be reopened")
	_axis(manager, 11, 5, -0.9)
	manager.tick(2.1)
	_expect(manager.calibration_device < 0 and results.back() == false and manager.custom_mappings == saved, "holding a control cancels even before cancel has been mapped")


func _prime_menu(game: Node, entries: Array, focused: String) -> void:
	game.hud.buttons.clear()
	for entry in entries:
		game.hud.buttons.append({"action": entry[0], "rect": entry[1]})
	game.hud.focus_context = game.hud._focus_context()
	game.hud.buttons_context = game.hud.focus_context
	game.hud.focus_action = focused


func _test_game_integration(fake: FakeInput) -> void:
	var game = GameScript.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.controller.set_backend(fake)
	game.audio.effects_enabled = false
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	game.switches.clear()
	game.traps.clear()
	game.coins.clear()
	game.shields.clear()
	game.powerups.clear()
	game.player_position = Vector2i(8, 7)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	fake.pulses.clear()
	var initial_turn: int = game.turn_number
	_dispatch_tap(7, JOY_BUTTON_DPAD_RIGHT)
	_expect(game.player_position == Vector2i(9, 7) and game.controller.active_device == 7 and game.turn_number == initial_turn + 1, "PS3 D-pad moves the actual game exactly once through SceneTree input")
	_expect(not fake.pulses.is_empty() and fake.pulses.back().id == 7, "muted audio still generates gameplay haptics on the active pad")
	game.blink_charges = 1
	_tap(game.controller, 2, JOY_BUTTON_RIGHT_SHOULDER)
	_expect(game.player_position == Vector2i(12, 7) and game.blink_charges == 0 and game.controller.active_device == 2, "Xbox shoulder performs Blink with the second gamepad")
	var turns: int = game.turn_number
	_tap(game.controller, 2, JOY_BUTTON_LEFT_SHOULDER)
	_expect(game.turn_number == turns + 1, "left shoulder waits a turn")
	_tap(game.controller, 2, JOY_BUTTON_B)
	_expect(game.game_state == "paused", "cancel pauses gameplay")

	# The HUD is drawn by the engine; these rects exercise the same focus logic
	# deterministically even on CI's dummy/headless renderer.
	_prime_menu(game, [["resume", Rect2(0, 0, 100, 30)], ["controller_settings", Rect2(0, 40, 100, 30)], ["menu", Rect2(0, 80, 100, 30)]], "resume")
	_tap(game.controller, 2, JOY_BUTTON_DPAD_DOWN)
	_expect(game.hud.focus_action == "controller_settings", "D-pad moves visible menu focus")
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.game_state == "controller_settings" and game.controller_return_state == "paused", "confirm opens controller settings from pause")
	_prime_menu(game, [["controller_device", Rect2(0, 0, 100, 30)], ["controller_test", Rect2(0, 40, 100, 30)], ["controller_back", Rect2(0, 80, 100, 30)]], "controller_device")
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.controller.selected_device == 7, "gamepad can choose a different pad in settings")
	_tap(game.controller, 2, JOY_BUTTON_DPAD_DOWN)
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(fake.pulses.back().id == 7 and "PULSO ENVIADO" in game.controller_message, "test from a different pad targets the selected device")
	_tap(game.controller, 2, JOY_BUTTON_B)
	_expect(game.game_state == "paused", "cancel returns to the menu that opened settings")
	_tap(game.controller, 2, JOY_BUTTON_START)
	_expect(game.game_state == "playing", "start resumes gameplay")

	game.dev_menu_open = true
	_prime_menu(game, [["dev_god", Rect2(0, 0, 100, 30)], ["dev_noclip", Rect2(110, 0, 100, 30)]], "dev_god")
	_tap(game.controller, 2, JOY_BUTTON_DPAD_RIGHT)
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.dev_noclip and game.hud.focus_action == "dev_noclip", "developer modal is navigable and activated with a gamepad")
	_tap(game.controller, 2, JOY_BUTTON_B)
	_expect(not game.dev_menu_open, "cancel closes the developer modal")

	game.game_state = "level_select"
	game.furthest_floor = 2
	_prime_menu(game, [["floor:1", Rect2(0, 0, 100, 100)], ["floor:2", Rect2(110, 0, 100, 100)], ["menu", Rect2(0, 120, 100, 30)]], "floor:1")
	_tap(game.controller, 2, JOY_BUTTON_DPAD_RIGHT)
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.game_state == "playing" and game.floor_number == 2, "gamepad can choose an unlocked journal card")
	game.game_state = "floor_clear"
	_prime_menu(game, [["next_floor", Rect2(0, 0, 100, 30)], ["menu", Rect2(110, 0, 100, 30)]], "next_floor")
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.game_state == "playing" and game.floor_number == 3, "gamepad can advance from a result screen")
	game.game_state = "title"
	game.has_resume = false
	_prime_menu(game, [["new_run", Rect2(0, 0, 100, 30)], ["levels", Rect2(0, 40, 100, 30)], ["controller_settings", Rect2(0, 80, 100, 30)]], "new_run")
	_tap(game.controller, 2, JOY_BUTTON_DPAD_DOWN)
	_tap(game.controller, 2, JOY_BUTTON_DPAD_DOWN)
	_tap(game.controller, 2, JOY_BUTTON_A)
	_expect(game.game_state == "controller_settings" and game.controller_return_state == "title", "title menu can open settings with a gamepad")
	_tap(game.controller, 2, JOY_BUTTON_B)
	_expect(game.game_state == "title", "settings opened from title return to title")
	game.game_state = "game_over"
	_prime_menu(game, [["continue", Rect2(0, 0, 100, 30)], ["menu", Rect2(0, 40, 100, 30)]], "continue")
	_tap(game.controller, 2, JOY_BUTTON_B)
	_expect(game.game_state == "title", "cancel exits the defeat screen")
	_axis(game.controller, 2, JOY_AXIS_LEFT_X, 0.9)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(game.controller.states.is_empty() and not game.controller.using_gamepad, "losing window focus clears held inputs and prevents unattended rumble")
	game.audio.stop_all()
	game.queue_free()


func _test_profile_settings() -> void:
	var path := "user://controller_test_profile.cfg"
	var writer = GameScript.new()
	writer.profile_path = path
	writer.controller_vibration_enabled = false
	writer.controller_mappings = {"generic-guid|Generic Arcade Stick": {"confirm": {"type": "button", "index": 10}}}
	writer.furthest_floor = 8
	writer._save_profile()
	var reader = GameScript.new()
	reader.profile_path = path
	reader._load_profile()
	_expect(not reader.controller_vibration_enabled and reader.controller_mappings == writer.controller_mappings and reader.furthest_floor == 8, "profile preserves controller preferences and game progress")
	var live = GameScript.new()
	live.profile_path = path
	root.add_child(live)
	_expect(not live.controller.vibration_enabled and live.controller.custom_mappings == writer.controller_mappings, "live game applies the saved settings on startup")
	live.controller.set_vibration_enabled(true)
	var changed := ConfigFile.new()
	changed.load(path)
	_expect(bool(changed.get_value("controller", "vibration", false)) and int(changed.get_value("progress", "furthest_floor", 0)) == 8, "changing vibration saves preferences without losing progress")
	live.audio.stop_all()
	live.queue_free()
	var old := ConfigFile.new()
	old.set_value("progress", "furthest_floor", 3)
	old.save(path)
	var legacy = GameScript.new()
	legacy.profile_path = path
	legacy._load_profile()
	_expect(legacy.controller_vibration_enabled and legacy.controller_mappings.is_empty() and legacy.furthest_floor == 3, "old profiles receive safe controller defaults")
	writer.free()
	reader.free()
	legacy.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_rendered_menus(fake: FakeInput) -> void:
	# Exercise the actual draw-generated controls and SceneTree input, not just
	# manually supplied rectangles. The dummy renderer still invokes _draw.
	var previous_window_size := root.size
	root.size = Vector2i(800, 540)
	var game = GameScript.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.controller.set_backend(fake)
	game.audio.effects_enabled = false
	game.furthest_floor = 2
	game.has_resume = true
	var menus := [
		{"state": "title", "expected": ["continue", "new_run", "levels", "music", "controller_settings"]},
		{"state": "level_select", "expected": ["floor:1", "floor:2", "menu"]},
		{"state": "paused", "expected": ["resume", "restart_floor", "levels", "controller_settings", "menu"]},
		{"state": "controller_settings", "expected": ["controller_device", "controller_vibration", "controller_test", "controller_calibrate", "controller_reset", "controller_back"]},
		{"state": "floor_clear", "expected": ["next_floor", "levels", "menu"]},
		{"state": "rescued", "expected": ["next_floor", "levels", "menu"]},
		{"state": "game_over", "expected": ["continue", "levels", "menu"]},
		{"state": "playing", "dev": true, "expected": ["dev_god", "dev_noclip", "dev_toggle"]},
	]
	for menu in menus:
		game.game_state = menu.state
		game.dev_menu_open = menu.get("dev", false)
		game.hud.queue_redraw()
		await process_frame
		await process_frame
		var drawn: Array = game.hud.buttons.map(func(button): return button.action)
		for action in menu.expected:
			_expect(drawn.has(action), "drawn %s menu contains %s" % [menu.state, action])
		if menu.get("dev", false):
			_expect(not drawn.has("blink") and not drawn.has("wait"), "developer modal does not leave underlying gameplay buttons clickable")
		var viewport := Rect2(Vector2.ZERO, game.hud.size)
		for button in game.hud.buttons:
			_expect(viewport.encloses(button.rect), "%s button %s stays inside the minimum-size viewport" % [menu.state, button.action])

	game.dev_menu_open = false
	game.game_state = "title"
	game.has_resume = false
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	for _step in 3:
		_dispatch_tap(2, JOY_BUTTON_DPAD_DOWN)
	_expect(game.hud.focus_action == "controller_settings", "real title buttons navigate to controller settings")
	_dispatch_tap(2, JOY_BUTTON_A)
	_expect(game.game_state == "controller_settings", "SceneTree confirm opens the drawn settings menu")
	await process_frame
	await process_frame
	_dispatch_tap(2, JOY_BUTTON_A)
	_expect(game.controller.selected_device == 7, "real settings button selects the next controller")
	_dispatch_tap(2, JOY_BUTTON_DPAD_DOWN)
	_dispatch_tap(2, JOY_BUTTON_DPAD_DOWN)
	fake.pulses.clear()
	_dispatch_tap(2, JOY_BUTTON_A)
	_expect(not fake.pulses.is_empty() and fake.pulses.back().id == 7, "real settings UI sends its test pulse to the selected controller")

	game.handle_hud_action("controller_calibrate")
	_expect(game.game_state == "controller_mapping", "selected controller opens the mapping wizard")
	await process_frame
	await process_frame
	var wizard_actions: Array = game.hud.buttons.map(func(button): return button.action)
	_expect(wizard_actions.has("controller_cancel_mapping") and not wizard_actions.has("controller_skip"), "drawn mandatory wizard step offers cancel but not skip")
	_axis(game.controller, 7, JOY_AXIS_LEFT_Y, -0.9)
	_expect(game.controller.calibration_step == 1, "real wizard captures an axis")
	game.controller.tick(2.1)
	_expect(game.game_state == "controller_settings" and "CANCELADO" in game.controller_message, "gamepad-only hold cancels the real wizard")
	game.handle_hud_action("controller_calibrate")
	_axis(game.controller, 7, JOY_AXIS_LEFT_Y, -0.9)
	_axis(game.controller, 7, JOY_AXIS_LEFT_Y, 0.0)
	_axis(game.controller, 7, JOY_AXIS_LEFT_Y, 0.9)
	_axis(game.controller, 7, JOY_AXIS_LEFT_Y, 0.0)
	_axis(game.controller, 7, JOY_AXIS_LEFT_X, -0.9)
	_axis(game.controller, 7, JOY_AXIS_LEFT_X, 0.0)
	_axis(game.controller, 7, JOY_AXIS_LEFT_X, 0.9)
	_axis(game.controller, 7, JOY_AXIS_LEFT_X, 0.0)
	_tap(game.controller, 7, JOY_BUTTON_A)
	_tap(game.controller, 7, JOY_BUTTON_B)
	await process_frame
	await process_frame
	wizard_actions = game.hud.buttons.map(func(button): return button.action)
	_expect(game.controller.calibration_step == 6 and wizard_actions.has("controller_skip"), "drawn optional wizard step offers skip")
	_tap(game.controller, 7, JOY_BUTTON_B)
	_expect(game.controller.calibration_step == 7, "a short mapped-cancel press skips an optional step in the drawn wizard")
	_button(game.controller, 7, JOY_BUTTON_B, true)
	game.controller.tick(1.0)
	_button(game.controller, 7, JOY_BUTTON_B, false)
	_expect(game.game_state == "controller_settings", "holding mapped cancel closes the drawn wizard")
	await process_frame
	await process_frame
	_dispatch_tap(2, JOY_BUTTON_B)
	_expect(game.game_state == "title", "cancel returns from the rendered settings screen to title")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	root.size = previous_window_size
