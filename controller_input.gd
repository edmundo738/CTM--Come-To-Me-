extends Node

# Godot/SDL normalizes Xbox, PlayStation and many other gamepads. Unknown
# devices can be mapped in-game, per device identity, without replacing the
# engine's database or making assumptions about their raw button numbers.
signal action_requested(action: String)
signal calibration_finished(saved: bool)
signal settings_changed
signal device_changed(device: int, connected: bool)

const DEADZONE_ENTER := 0.55
const DEADZONE_RELEASE := 0.35
const CALIBRATION_THRESHOLD := 0.65
const INITIAL_REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.20
const HOLD_TO_CANCEL := 0.9
const HOLD_TO_CANCEL_REQUIRED := 2.0

const DIRECTION_ACTIONS := ["up", "down", "left", "right"]
const BUTTON_ACTIONS := ["confirm", "cancel", "break", "wait", "blink", "pause", "dev"]
const CALIBRATION_STEPS := [
	{"id": "up", "label": "CIMA", "required": true},
	{"id": "down", "label": "BAIXO", "required": true},
	{"id": "left", "label": "ESQUERDA", "required": true},
	{"id": "right", "label": "DIREITA", "required": true},
	{"id": "confirm", "label": "CONFIRMAR / SALTAR", "required": true},
	{"id": "cancel", "label": "VOLTAR / PAUSA", "required": true},
	{"id": "break", "label": "DEMOLIR", "required": false},
	{"id": "wait", "label": "ESPERAR", "required": false},
	{"id": "blink", "label": "BLINK", "required": false},
	{"id": "pause", "label": "PAUSA (START)", "required": false},
	{"id": "dev", "label": "MENU DEV", "required": false},
]
const DEFAULT_BINDINGS := {
	"up": [{"type": "button", "index": JOY_BUTTON_DPAD_UP}, {"type": "axis", "index": JOY_AXIS_LEFT_Y, "sign": -1}],
	"down": [{"type": "button", "index": JOY_BUTTON_DPAD_DOWN}, {"type": "axis", "index": JOY_AXIS_LEFT_Y, "sign": 1}],
	"left": [{"type": "button", "index": JOY_BUTTON_DPAD_LEFT}, {"type": "axis", "index": JOY_AXIS_LEFT_X, "sign": -1}],
	"right": [{"type": "button", "index": JOY_BUTTON_DPAD_RIGHT}, {"type": "axis", "index": JOY_AXIS_LEFT_X, "sign": 1}],
	"confirm": [{"type": "button", "index": JOY_BUTTON_A}],
	"cancel": [{"type": "button", "index": JOY_BUTTON_B}],
	"break": [{"type": "button", "index": JOY_BUTTON_X}],
	"wait": [{"type": "button", "index": JOY_BUTTON_LEFT_SHOULDER}],
	"blink": [{"type": "button", "index": JOY_BUTTON_RIGHT_SHOULDER}],
	"pause": [{"type": "button", "index": JOY_BUTTON_START}],
	"dev": [{"type": "button", "index": JOY_BUTTON_Y}, {"type": "button", "index": JOY_BUTTON_BACK}],
}
const HapticMixerScript = preload("res://haptic_mixer.gd")

# Kept injectable so simulated devices can exercise routing and haptics in CI.
var backend: Variant = Input
var haptics = HapticMixerScript.new()
var active_device := -1
# Settings can target another connected pad without changing the last user.
var selected_device := -1
var using_gamepad := false
var vibration_enabled := true
var vibration_intensity := 1.0
var custom_mappings: Dictionary = {}
var states: Dictionary = {}

var calibration_device := -1
var calibration_step := 0
var calibration_bindings: Dictionary = {}
var calibration_message := ""
var calibration_wait: Dictionary = {}
var calibration_cancel_pending := false
var calibration_cancel_elapsed := 0.0
var calibration_required_hold := 0.0


func _ready() -> void:
	haptics.backend = backend
	_connect_backend_signal()
	_refresh_active_device()


func _exit_tree() -> void:
	_disconnect_backend_signal()
	_stop_all_vibration()


func set_backend(source: Variant) -> void:
	_disconnect_backend_signal()
	_stop_all_vibration()
	backend = source
	haptics.backend = backend
	states.clear()
	active_device = -1
	selected_device = -1
	using_gamepad = false
	_connect_backend_signal()
	_refresh_active_device()


func _connect_backend_signal() -> void:
	if backend == Input and not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _disconnect_backend_signal() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func connected_devices() -> Array[int]:
	var devices: Array[int] = []
	for value in backend.get_connected_joypads():
		devices.append(int(value))
	devices.sort()
	return devices


func _refresh_active_device() -> void:
	var devices := connected_devices()
	if not devices.has(active_device):
		active_device = devices[0] if not devices.is_empty() else -1
		if active_device < 0:
			using_gamepad = false
	if not devices.has(selected_device):
		selected_device = active_device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		haptics.cancel_device(device)
		states.erase(device)
		if calibration_device == device:
			cancel_calibration()
		if active_device == device:
			active_device = -1
			# Do not send the disconnected player's feedback to a different pad
			# until that pad is actually used.
			using_gamepad = false
	_refresh_active_device()
	device_changed.emit(device, connected)


func select_active_device() -> void:
	_refresh_active_device()
	selected_device = active_device


func select_next_device() -> bool:
	var devices := connected_devices()
	if devices.is_empty():
		selected_device = -1
		return false
	var index := devices.find(selected_device)
	selected_device = devices[(index + 1) % devices.size()]
	return true


func device_name(device: int = -1) -> String:
	var selected := active_device if device < 0 else device
	if not connected_devices().has(selected):
		return "Nenhum comando ligado"
	var name: String = str(backend.get_joy_name(selected)).strip_edges()
	return name if not name.is_empty() else "Gamepad generico"


func device_family(device: int = -1) -> String:
	var name := device_name(device).to_lower()
	if "xbox" in name or "xinput" in name or "x-input" in name:
		return "XBOX"
	if "playstation" in name or "dualshock" in name or "dualsense" in name or "ps3" in name or "ps4" in name or "ps5" in name or "sony" in name or "wireless controller" in name:
		return "PLAYSTATION"
	return "GENERICO"


func device_is_known(device: int = -1) -> bool:
	var selected := active_device if device < 0 else device
	return connected_devices().has(selected) and bool(backend.is_joy_known(selected))


func device_has_vibration(device: int = -1) -> bool:
	var selected := active_device if device < 0 else device
	if not connected_devices().has(selected) or not backend.has_method("has_joy_vibration"):
		return false
	return bool(backend.has_joy_vibration(selected))


func device_key(device: int) -> String:
	if not connected_devices().has(device):
		return ""
	var guid: String = str(backend.get_joy_guid(device))
	var name := device_name(device)
	var info: Variant = backend.get_joy_info(device)
	var serial := ""
	if info is Dictionary:
		serial = str(info.get("serial_number", ""))
	# A serial, when the OS exposes one, separates two otherwise identical pads.
	# For devices without a serial, the GUID/name is stable across reconnects.
	return "%s|%s" % [guid if not guid.is_empty() else "sem-guid", serial if not serial.is_empty() else name]


func has_custom_mapping(device: int = -1) -> bool:
	var selected := active_device if device < 0 else device
	var key := device_key(selected)
	return not key.is_empty() and custom_mappings.has(key)


func set_settings(enabled: bool, mappings: Variant, intensity: float = 1.0) -> void:
	vibration_enabled = enabled
	vibration_intensity = clampf(intensity, 0.0, 1.0) if is_finite(intensity) else 1.0
	custom_mappings = mappings.duplicate(true) if mappings is Dictionary else {}
	states.clear()
	_stop_all_vibration()


func set_vibration_enabled(enabled: bool) -> void:
	vibration_enabled = enabled
	if not enabled:
		_stop_all_vibration()
	settings_changed.emit()


func set_vibration_intensity(value: float) -> void:
	var next := clampf(value, 0.0, 1.0) if is_finite(value) else 1.0
	if is_equal_approx(vibration_intensity, next):
		return
	vibration_intensity = next
	# Do not let already scheduled segments retain the old setting.
	_stop_all_vibration()
	settings_changed.emit()


func _stop_all_vibration() -> void:
	haptics.clear()
	for device in connected_devices():
		backend.stop_joy_vibration(device)


func feedback(cue: String, force: bool = false, device: int = -1, context: Dictionary = {}) -> bool:
	if not vibration_enabled or vibration_intensity <= 0.0 or (not using_gamepad and not force):
		return false
	var target := active_device if device < 0 else device
	if not connected_devices().has(target):
		return false
	# Some drivers under-report support. Requests are finite and may simply be
	# ignored by hardware/OS without compatible rumble motors.
	return haptics.play(target, cue, vibration_intensity, force, context)


func cancel_feedback_category(category: String) -> void:
	haptics.cancel_category(category)


func note_keyboard_or_mouse() -> void:
	if using_gamepad:
		using_gamepad = false
		haptics.cancel_gameplay()


func reset_held_inputs() -> void:
	states.clear()
	_stop_all_vibration()


func _state(device: int) -> Dictionary:
	if not states.has(device):
		states[device] = {"buttons": {}, "axes": {}, "axis_actions": {}, "direction": Vector2i.ZERO, "repeat": 0.0}
	return states[device]


func _activate_device(device: int) -> void:
	if device != active_device and connected_devices().has(active_device):
		haptics.cancel_device(active_device)
	active_device = device
	using_gamepad = true


func _bindings_for(device: int, action: String) -> Array:
	var key := device_key(device)
	if not key.is_empty() and custom_mappings.has(key):
		var mapping: Variant = custom_mappings[key]
		if mapping is Dictionary and mapping.has(action):
			var binding: Variant = mapping[action]
			if binding is Dictionary and _valid_binding(binding):
				return [] if binding.type == "none" else [binding]
	return DEFAULT_BINDINGS.get(action, [])


func _valid_binding(binding: Dictionary) -> bool:
	var kind: String = str(binding.get("type", ""))
	var index := int(binding.get("index", -1))
	if kind == "none":
		return true
	if kind == "button":
		return index >= 0 and index < JOY_BUTTON_MAX
	if kind == "axis":
		return index >= 0 and index < JOY_AXIS_MAX and int(binding.get("sign", 0)) in [-1, 1]
	return false


func _binding_strength(binding: Dictionary, state: Dictionary) -> float:
	var index := int(binding.get("index", -1))
	if binding.get("type", "") == "button":
		return 1.0 if state.buttons.get(index, false) else 0.0
	if binding.get("type", "") == "axis":
		return maxf(0.0, float(state.axes.get(index, 0.0)) * int(binding.get("sign", 1)))
	return 0.0


func _direction_for(device: int, state: Dictionary) -> Vector2i:
	var strengths := {}
	for action in DIRECTION_ACTIONS:
		var strength := 0.0
		for binding in _bindings_for(device, action):
			strength = maxf(strength, _binding_strength(binding, state))
		strengths[action] = strength
	var x := float(strengths.right) - float(strengths.left)
	var y := float(strengths.down) - float(strengths.up)
	var previous: Vector2i = state.direction
	var threshold := DEADZONE_RELEASE if previous != Vector2i.ZERO else DEADZONE_ENTER
	if maxf(absf(x), absf(y)) < threshold:
		return Vector2i.ZERO
	if absf(x) > absf(y):
		return Vector2i(1 if x > 0.0 else -1, 0)
	if absf(y) > absf(x):
		return Vector2i(0, 1 if y > 0.0 else -1)
	if previous.x != 0 and x * previous.x > 0.0:
		return previous
	if previous.y != 0 and y * previous.y > 0.0:
		return previous
	return Vector2i(0, 1 if y > 0.0 else -1)


func _emit_direction(direction: Vector2i) -> void:
	if direction == Vector2i.UP:
		action_requested.emit("up")
	elif direction == Vector2i.DOWN:
		action_requested.emit("down")
	elif direction == Vector2i.LEFT:
		action_requested.emit("left")
	elif direction == Vector2i.RIGHT:
		action_requested.emit("right")


func _update_direction(device: int, state: Dictionary) -> void:
	var direction := _direction_for(device, state)
	var previous: Vector2i = state.direction
	if direction == previous:
		return
	state.direction = direction
	state.repeat = INITIAL_REPEAT_DELAY
	if device == active_device and using_gamepad and direction != Vector2i.ZERO:
		_emit_direction(direction)


func _button_action(device: int, index: int) -> String:
	for action in BUTTON_ACTIONS:
		for binding in _bindings_for(device, action):
			if binding.get("type", "") == "button" and int(binding.get("index", -1)) == index:
				return action
	return ""


func _axis_is_bound_and_active(device: int, index: int, value: float) -> bool:
	for action in DIRECTION_ACTIONS + BUTTON_ACTIONS:
		for binding in _bindings_for(device, action):
			if binding.get("type", "") == "axis" and int(binding.get("index", -1)) == index and value * int(binding.get("sign", 1)) >= DEADZONE_ENTER:
				return true
	return false


func _axis_actions(device: int, state: Dictionary, emit_action: bool) -> void:
	for action in BUTTON_ACTIONS:
		var strength := 0.0
		for binding in _bindings_for(device, action):
			if binding.get("type", "") == "axis":
				strength = maxf(strength, _binding_strength(binding, state))
		var was_pressed: bool = state.axis_actions.get(action, false)
		var pressed := strength >= (DEADZONE_RELEASE if was_pressed else DEADZONE_ENTER)
		state.axis_actions[action] = pressed
		if pressed and not was_pressed and emit_action:
			action_requested.emit(action)


func handle_event(event: InputEvent) -> void:
	if not event is InputEventJoypadButton and not event is InputEventJoypadMotion:
		return
	var device := event.device
	if device < 0:
		return
	var state := _state(device)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		var index := int(button.button_index)
		var was_pressed: bool = state.buttons.get(index, false)
		state.buttons[index] = button.pressed
		if calibration_device >= 0:
			_handle_calibration_button(device, index, button.pressed, was_pressed)
			return
		if button.pressed and not was_pressed:
			_activate_device(device)
			var action := _button_action(device, index)
			if not action.is_empty():
				action_requested.emit(action)
		_update_direction(device, state)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var index := int(motion.axis)
		var old_value: float = state.axes.get(index, 0.0)
		var value := clampf(motion.axis_value, -1.0, 1.0)
		state.axes[index] = value
		if calibration_device >= 0:
			_handle_calibration_axis(device, index, old_value, value)
			return
		if _axis_is_bound_and_active(device, index, value):
			_activate_device(device)
		_axis_actions(device, state, device == active_device and using_gamepad)
		_update_direction(device, state)


func tick(delta: float) -> void:
	if not haptics.voices.is_empty():
		haptics.tick(delta, connected_devices())
	if calibration_device >= 0:
		if calibration_cancel_pending:
			calibration_cancel_elapsed += maxf(0.0, delta)
			if calibration_cancel_elapsed >= HOLD_TO_CANCEL:
				cancel_calibration()
		elif calibration_step <= 6 and not calibration_wait.is_empty():
			# Before cancel has been mapped, a sustained control gives a
			# gamepad-only player a way out without losing the previous mapping.
			calibration_required_hold += maxf(0.0, delta)
			if calibration_required_hold >= HOLD_TO_CANCEL_REQUIRED:
				cancel_calibration()
		else:
			calibration_required_hold = 0.0
		return
	if not using_gamepad or not states.has(active_device):
		return
	var state: Dictionary = states[active_device]
	var direction: Vector2i = state.direction
	if direction == Vector2i.ZERO:
		return
	state.repeat = float(state.repeat) - maxf(0.0, delta)
	if float(state.repeat) <= 0.0:
		state.repeat = REPEAT_INTERVAL
		_emit_direction(direction)


func begin_calibration(device: int = -1) -> bool:
	var target := active_device if device < 0 else device
	if not connected_devices().has(target):
		return false
	calibration_device = target
	calibration_step = 0
	calibration_bindings = {}
	calibration_message = "SOLTA O COMANDO ANTES DE CADA PASSO"
	calibration_wait = {}
	calibration_cancel_pending = false
	calibration_cancel_elapsed = 0.0
	calibration_required_hold = 0.0
	var state := _state(target)
	for index in state.buttons:
		if state.buttons[index]:
			calibration_wait = {"type": "button", "index": int(index)}
			break
	return true


func current_calibration_step() -> Dictionary:
	if calibration_device < 0 or calibration_step >= CALIBRATION_STEPS.size():
		return {}
	return CALIBRATION_STEPS[calibration_step]


func _same_binding(first: Dictionary, second: Dictionary) -> bool:
	if first.get("type", "") != second.get("type", "") or int(first.get("index", -1)) != int(second.get("index", -1)):
		return false
	return first.get("type", "") != "axis" or int(first.get("sign", 0)) == int(second.get("sign", 0))


func _is_skip_binding(binding: Dictionary) -> bool:
	return calibration_step >= 6 and calibration_bindings.has("cancel") and _same_binding(binding, calibration_bindings.cancel)


func _capture_calibration_binding(binding: Dictionary) -> void:
	if not calibration_wait.is_empty() or not _valid_binding(binding):
		return
	calibration_wait = binding.duplicate()
	if _is_skip_binding(binding):
		calibration_cancel_pending = true
		calibration_cancel_elapsed = 0.0
		calibration_message = "SOLTA PARA IGNORAR / MANTEM PARA CANCELAR"
		return
	for action in calibration_bindings:
		if _same_binding(binding, calibration_bindings[action]):
			calibration_message = "ESSE COMANDO JA ESTA EM USO; ESCOLHE OUTRO"
			return
	var step: Dictionary = CALIBRATION_STEPS[calibration_step]
	calibration_bindings[step.id] = binding.duplicate()
	_advance_calibration()


func _handle_calibration_button(device: int, index: int, pressed: bool, was_pressed: bool) -> void:
	if device != calibration_device:
		return
	if not pressed:
		if calibration_wait.get("type", "") == "button" and int(calibration_wait.get("index", -1)) == index:
			calibration_wait = {}
			calibration_required_hold = 0.0
			if calibration_cancel_pending:
				calibration_cancel_pending = false
				skip_calibration_step()
		return
	if not was_pressed:
		_capture_calibration_binding({"type": "button", "index": index})


func _handle_calibration_axis(device: int, index: int, old_value: float, value: float) -> void:
	if device != calibration_device:
		return
	if calibration_wait.get("type", "") == "axis" and int(calibration_wait.get("index", -1)) == index and value * int(calibration_wait.get("sign", 1)) <= DEADZONE_RELEASE:
		calibration_wait = {}
		calibration_required_hold = 0.0
		if calibration_cancel_pending:
			calibration_cancel_pending = false
			skip_calibration_step()
		return
	# Capture only a deliberate movement from neutral, not a resting trigger or
	# a stick that was already held when the wizard opened.
	if (absf(old_value) <= DEADZONE_RELEASE and absf(value) >= CALIBRATION_THRESHOLD) or old_value * value <= -CALIBRATION_THRESHOLD * CALIBRATION_THRESHOLD:
		_capture_calibration_binding({"type": "axis", "index": index, "sign": 1 if value > 0.0 else -1})


func skip_calibration_step() -> bool:
	if calibration_device < 0 or calibration_step >= CALIBRATION_STEPS.size():
		return false
	var step: Dictionary = CALIBRATION_STEPS[calibration_step]
	if step.required:
		calibration_message = "ESTE COMANDO E OBRIGATORIO"
		return false
	calibration_bindings[step.id] = {"type": "none"}
	calibration_wait = {}
	calibration_cancel_pending = false
	_advance_calibration()
	return true


func _advance_calibration() -> void:
	calibration_step += 1
	calibration_message = "SOLTA O COMANDO ANTES DE CADA PASSO"
	if calibration_step < CALIBRATION_STEPS.size():
		return
	var device := calibration_device
	var key := device_key(device)
	if key.is_empty():
		cancel_calibration()
		return
	custom_mappings[key] = calibration_bindings.duplicate(true)
	calibration_device = -1
	calibration_wait = {}
	calibration_cancel_pending = false
	states.erase(device)
	settings_changed.emit()
	calibration_finished.emit(true)


func cancel_calibration() -> void:
	if calibration_device < 0:
		return
	var device := calibration_device
	calibration_device = -1
	calibration_wait = {}
	calibration_cancel_pending = false
	states.erase(device)
	calibration_finished.emit(false)


func clear_active_mapping(device: int = -1) -> bool:
	var target := active_device if device < 0 else device
	var key := device_key(target)
	if key.is_empty() or not custom_mappings.has(key):
		return false
	custom_mappings.erase(key)
	states.erase(target)
	settings_changed.emit()
	return true


func button_label(action: String) -> String:
	var key := device_key(active_device)
	if custom_mappings.has(key) and custom_mappings[key] is Dictionary and custom_mappings[key].has(action):
		var saved: Variant = custom_mappings[key][action]
		if saved is Dictionary and _valid_binding(saved):
			var binding: Dictionary = saved
			if binding.get("type", "") == "button":
				return "BTN%d" % int(binding.get("index", 0))
			if binding.get("type", "") == "axis":
				return "EIXO%d%s" % [int(binding.get("index", 0)), "+" if int(binding.get("sign", 1)) > 0 else "-"]
			return "--"
	if device_family() == "PLAYSTATION":
		return {"confirm": "CRUZ", "cancel": "CIRCULO", "break": "QUAD", "wait": "L1", "blink": "R1", "pause": "START"}.get(action, "")
	return {"confirm": "A", "cancel": "B", "break": "X", "wait": "LB", "blink": "RB", "pause": "START"}.get(action, "")
