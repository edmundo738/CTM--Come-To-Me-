extends RefCounted

# Godot exposes two *frequency* motors, not left/right positional channels:
# Vector3.x = weak/high-frequency, .y = strong/low-frequency, .z = seconds.
# Segments are intentionally long enough for ordinary eccentric-weight motors;
# every driver request is finite even if a frame, disconnect or the app stalls.
const UPDATE_INTERVAL := 0.035
const MAX_REQUEST_SECONDS := 0.24
const MAX_VOICES_PER_DEVICE := 8
const PATTERNS := {
	"menu_move": {"priority": 1, "segments": [Vector3(0.28, 0.05, 0.065)]},
	"menu_confirm": {"priority": 1, "segments": [Vector3(0.42, 0.12, 0.075)]},
	"step": {"priority": 1, "segments": [Vector3(0.56, 0.24, 0.085)]},
	"wait": {"priority": 1, "segments": [Vector3(0.20, 0.38, 0.10)]},
	"blocked": {"priority": 3, "segments": [Vector3(0.28, 0.90, 0.11), Vector3(0, 0, 0.055), Vector3(0.24, 0.48, 0.065)]},
	"coin": {"priority": 2, "segments": [Vector3(0.55, 0.08, 0.055), Vector3(0, 0, 0.06), Vector3(0.74, 0.07, 0.065)]},
	"shield": {"priority": 3, "segments": [Vector3(0.70, 0.28, 0.085), Vector3(0.48, 0.56, 0.12), Vector3(0.24, 0.20, 0.09)]},
	"shield_impact": {"priority": 5, "segments": [Vector3(0.92, 0.70, 0.09), Vector3(0.38, 0.98, 0.16), Vector3(0, 0, 0.06), Vector3(0.38, 0.35, 0.08)]},
	"elite_stagger": {"priority": 5, "segments": [Vector3(0.48, 0.95, 0.14), Vector3(0, 0, 0.06), Vector3(0.72, 0.55, 0.09)]},
	"hit": {"priority": 5, "segments": [Vector3(0.78, 1.0, 0.20), Vector3(0, 0, 0.06), Vector3(0.38, 0.65, 0.10)]},
	"explosion": {"priority": 6, "segments": [Vector3(1.0, 1.0, 0.21), Vector3(0.46, 0.83, 0.13), Vector3(0, 0, 0.08), Vector3(0.35, 0.54, 0.12)]},
	"balloon_pop": {"priority": 7, "segments": [Vector3(1.0, 1.0, 0.20), Vector3(0.42, 0.75, 0.14), Vector3(0, 0, 0.09), Vector3(0.22, 0.42, 0.10)]},
	"inflate": {"priority": 6, "segments": [Vector3(0.18, 0.24, 0.16), Vector3(0, 0, 0.06), Vector3(0.34, 0.42, 0.15), Vector3(0, 0, 0.06), Vector3(0.62, 0.70, 0.20)]},
	"portal": {"priority": 4, "segments": [Vector3(0.58, 0.28, 0.10), Vector3(0.76, 0.42, 0.12), Vector3(0.46, 0.60, 0.13), Vector3(0.24, 0.32, 0.12)]},
	"switch": {"priority": 2, "segments": [Vector3(0.48, 0.14, 0.07), Vector3(0, 0, 0.07), Vector3(0.72, 0.18, 0.09)]},
	"jump": {"priority": 2, "segments": [Vector3(0.48, 0.28, 0.09), Vector3(0.76, 0.20, 0.10)]},
	"breaker": {"priority": 3, "segments": [Vector3(0.38, 0.60, 0.12), Vector3(0, 0, 0.06), Vector3(0.62, 0.36, 0.10)]},
	"break_wall": {"priority": 5, "segments": [Vector3(0.66, 1.0, 0.18), Vector3(0, 0, 0.07), Vector3(0.28, 0.62, 0.10), Vector3(0, 0, 0.08), Vector3(0.18, 0.34, 0.08)]},
	"power_speed": {"priority": 3, "segments": [Vector3(0.48, 0.18, 0.07), Vector3(0.70, 0.24, 0.08), Vector3(0.88, 0.20, 0.09)]},
	"power_magnet": {"priority": 3, "segments": [Vector3(0.36, 0.54, 0.12), Vector3(0.68, 0.30, 0.12), Vector3(0.36, 0.54, 0.10)]},
	"power_blink": {"priority": 3, "segments": [Vector3(0.76, 0.18, 0.07), Vector3(0, 0, 0.09), Vector3(0.76, 0.18, 0.07)]},
	"power_time_freeze": {"priority": 3, "segments": [Vector3(0.26, 0.80, 0.16), Vector3(0.12, 0.42, 0.16)]},
	"blink": {"priority": 3, "segments": [Vector3(0.82, 0.24, 0.075), Vector3(0, 0, 0.08), Vector3(0.40, 0.28, 0.08)]},
	"puzzle_error": {"priority": 3, "segments": [Vector3(0.25, 0.68, 0.11), Vector3(0, 0, 0.07), Vector3(0.25, 0.68, 0.11)]},
	"rhythm_trap": {"priority": 4, "segments": [Vector3(0.64, 0.84, 0.13), Vector3(0, 0, 0.07), Vector3(0.42, 0.58, 0.09)]},
	"near_miss": {"priority": 3, "segments": [Vector3(0.62, 0.20, 0.06), Vector3(0, 0, 0.07), Vector3(0.34, 0.44, 0.07)]},
	"heartbeat": {"priority": 1, "segments": [Vector3(0.20, 0.64, 0.07), Vector3(0, 0, 0.09), Vector3(0.14, 0.42, 0.065)]},
	"test": {"priority": 7, "segments": [Vector3(0.85, 1.0, 0.20), Vector3(0, 0, 0.08), Vector3(1.0, 0.38, 0.13)]},
}

var backend: Variant = Input
var voices: Array[Dictionary] = []
var last_output: Dictionary = {}
var since_write: Dictionary = {}
var dirty_devices: Dictionary = {}
var update_accumulator := 0.0


func play(device: int, cue: String, intensity: float, force: bool = false, context: Dictionary = {}) -> bool:
	if not PATTERNS.has(cue) or intensity <= 0.0:
		return false
	var definition: Dictionary = PATTERNS[cue]
	var priority := int(definition.priority)
	# Retriggering replaces a prior copy. Major events remove less important
	# voices, so a coin/footstep cannot mask an impact or fill its silent gaps.
	for index in range(voices.size() - 1, -1, -1):
		var old: Dictionary = voices[index]
		if int(old.device) == device and (str(old.cue) == cue or (priority >= 4 and int(old.priority) < priority)):
			voices.remove_at(index)
	var segments: Array = definition.segments.duplicate()
	if cue == "step":
		# Existing floor themes supply material texture without changing rules.
		match str(context.get("material", "")):
			"forge": segments = [Vector3(0.38, 0.55, 0.10)]
			"garden": segments = [Vector3(0.48, 0.14, 0.075)]
			"ice": segments = [Vector3(0.72, 0.09, 0.065), Vector3(0, 0, 0.05), Vector3(0.35, 0.10, 0.06)]
			"void": segments = [Vector3(0.68, 0.18, 0.075), Vector3(0, 0, 0.06), Vector3(0.24, 0.08, 0.06)]
	var count := 0
	var lowest_index := -1
	var lowest_priority := 999
	for index in range(voices.size()):
		if int(voices[index].device) == device:
			count += 1
			if int(voices[index].priority) < lowest_priority:
				lowest_index = index
				lowest_priority = int(voices[index].priority)
	if count >= MAX_VOICES_PER_DEVICE and lowest_index >= 0:
		if priority < lowest_priority:
			return false
		voices.remove_at(lowest_index)
	voices.append({
		"device": device, "cue": cue, "priority": priority, "segments": segments,
		"elapsed": 0.0, "fresh": true, "gain": clampf(intensity * float(context.get("gain", 1.0)), 0.0, 1.0),
		"forced": force, "category": str(context.get("category", "gameplay")),
		"envelope": context.get("envelope", PackedVector2Array()),
	})
	_render(device, true)
	return true


func tick(delta: float, connected: Array[int]) -> void:
	var elapsed := maxf(0.0, delta)
	var ended := false
	for index in range(voices.size() - 1, -1, -1):
		var voice: Dictionary = voices[index]
		var device := int(voice.device)
		dirty_devices[device] = true
		# Input is delivered before _process; SDL may not see a new request
		# until the next frame. Do not age it by time that elapsed before it
		# was created, otherwise a stalled frame can erase the first pulse.
		if bool(voice.fresh):
			voice.fresh = false
		else:
			voice.elapsed = float(voice.elapsed) + elapsed
		if not connected.has(device) or float(voice.elapsed) >= _duration(voice.segments):
			voices.remove_at(index)
			ended = true
	for device in since_write.keys():
		since_write[device] = float(since_write[device]) + elapsed
	update_accumulator += elapsed
	if update_accumulator < UPDATE_INTERVAL and not voices.is_empty() and not ended:
		return
	update_accumulator = 0.0
	for device in dirty_devices.keys():
		if connected.has(int(device)):
			_render(int(device), false)
		else:
			last_output.erase(device)
			since_write.erase(device)
	dirty_devices.clear()


func cancel_device(device: int) -> void:
	for index in range(voices.size() - 1, -1, -1):
		if int(voices[index].device) == device:
			voices.remove_at(index)
	backend.stop_joy_vibration(device)
	last_output.erase(device)
	since_write.erase(device)
	dirty_devices.erase(device)


func cancel_gameplay() -> void:
	var touched: Dictionary = {}
	for index in range(voices.size() - 1, -1, -1):
		if not bool(voices[index].forced):
			touched[int(voices[index].device)] = true
			voices.remove_at(index)
	for device in touched.keys():
		_render(int(device), true)


func cancel_category(category: String) -> void:
	var touched: Dictionary = {}
	for index in range(voices.size() - 1, -1, -1):
		if str(voices[index].category) == category:
			touched[int(voices[index].device)] = true
			voices.remove_at(index)
	for device in touched.keys():
		_render(int(device), true)


func clear() -> void:
	voices.clear()
	last_output.clear()
	since_write.clear()
	dirty_devices.clear()
	update_accumulator = 0.0


func _duration(segments: Array) -> float:
	var total := 0.0
	for segment in segments:
		var part: Vector3 = segment
		total += part.z
	return total


func _segment_at(segments: Array, elapsed: float) -> Vector3:
	for segment in segments:
		var part: Vector3 = segment
		if elapsed < part.z:
			return Vector3(part.x, part.y, part.z - elapsed)
		elapsed -= part.z
	return Vector3.ZERO


func _render(device: int, force_write: bool) -> void:
	var highest := -1
	for voice in voices:
		if int(voice.device) == device:
			highest = maxi(highest, int(voice.priority))
	var high_audible := false
	for voice in voices:
		if int(voice.device) == device and int(voice.priority) == highest:
			var top := _segment_at(voice.segments, float(voice.elapsed))
			high_audible = high_audible or top.x > 0.0 or top.y > 0.0
	var mix := Vector2.ZERO
	var remaining := MAX_REQUEST_SECONDS
	for voice in voices:
		if int(voice.device) != device:
			continue
		var part := _segment_at(voice.segments, float(voice.elapsed))
		# Duck lower voices and preserve intentional gaps in the top signature.
		var weight := 1.0 if int(voice.priority) == highest else (0.18 if high_audible else 0.0)
		var weak := part.x
		var strong := part.y
		var envelope: PackedVector2Array = voice.envelope
		if not envelope.is_empty():
			var envelope_index := mini(int(float(voice.elapsed) / UPDATE_INTERVAL), envelope.size() - 1)
			var bands := envelope[envelope_index] # x = low, y = high
			weak *= 0.72 + 0.28 * bands.y
			strong *= 0.72 + 0.28 * bands.x
		var gain := float(voice.gain) * weight
		mix.x = maxf(mix.x, weak * gain)
		mix.y = maxf(mix.y, strong * gain)
		remaining = minf(remaining, part.z)
	mix.x = clampf(mix.x, 0.0, 1.0)
	mix.y = clampf(mix.y, 0.0, 1.0)
	var previous: Vector2 = last_output.get(device, Vector2.ZERO)
	if mix.length_squared() < 0.0001:
		if previous.length_squared() >= 0.0001:
			backend.stop_joy_vibration(device)
		last_output[device] = Vector2.ZERO
		since_write[device] = 0.0
		return
	var duration := clampf(remaining + 0.015, 0.05, MAX_REQUEST_SECONDS)
	if force_write or mix.distance_to(previous) > 0.015 or float(since_write.get(device, 1.0)) >= 0.07:
		backend.start_joy_vibration(device, mix.x, mix.y, duration)
		last_output[device] = mix
		since_write[device] = 0.0
