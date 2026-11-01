extends Node

# Haptics are emitted even when sound effects are muted.
signal cue_played(cue: String)

const RATE := 22050
const HAPTIC_WINDOW := 0.035
const TAU := 6.28318530718
const MAIN_THEME = preload("res://audio/main_theme.wav")
const THREAT_LAYER = preload("res://audio/threat_layer.wav")
var effects: Dictionary = {}
var haptic_envelopes: Dictionary = {}
var rng := RandomNumberGenerator.new()
var music_player: AudioStreamPlayer
var threat_player: AudioStreamPlayer
var music_muted := false
var effects_enabled := true
var threat_target := 0.0
var threat_level := 0.0
var capture_duck_target := 0.0
var capture_duck := 0.0


func _ready() -> void:
	rng.randomize()
	for cue in ["step", "blocked", "coin", "shield", "hit", "explosion", "portal", "switch", "jump", "inflate", "balloon_pop", "breaker", "break_wall", "power_speed", "power_magnet", "power_blink", "power_time_freeze", "blink", "puzzle_error", "rhythm_trap", "near_miss"]:
		var effect := _make_effect(cue)
		effects[cue] = effect
		haptic_envelopes[cue] = _analyze_haptic_envelope(effect)
	music_player = AudioStreamPlayer.new()
	music_player.stream = _loop_track(MAIN_THEME)
	music_player.volume_db = -24.0
	add_child(music_player)
	threat_player = AudioStreamPlayer.new()
	threat_player.name = "ThreatScore"
	threat_player.stream = _loop_track(THREAT_LAYER)
	threat_player.volume_db = -48.0
	add_child(threat_player)
	if DisplayServer.get_name() != "headless":
		music_player.play()
		threat_player.play()


# Precomputed from the actual generated mono effects, not the music mix. A
# simple low/high split and RMS windows modulate authored rumble signatures;
# this is deliberately not advertised as FFT, positional audio or HD haptics.
# It remains available when audible effects are muted.
func _analyze_haptic_envelope(stream: AudioStreamWAV) -> PackedVector2Array:
	var result := PackedVector2Array()
	if stream == null or stream.stereo or stream.format != AudioStreamWAV.FORMAT_16_BITS:
		return result
	var bytes := stream.data
	var sample_count := bytes.size() / 2
	var window := maxi(1, int(stream.mix_rate * HAPTIC_WINDOW))
	# One-pole crossover, approximately 290 Hz at the synthesizer's 22050 Hz.
	var alpha := 1.0 - exp(-TAU * 290.0 / float(stream.mix_rate))
	var low := 0.0
	var low_energy := 0.0
	var high_energy := 0.0
	var in_window := 0
	var peak := 0.0
	for index in sample_count:
		var sample := float(bytes.decode_s16(index * 2)) / 32768.0
		low += alpha * (sample - low)
		var high := sample - low
		low_energy += low * low
		high_energy += high * high
		in_window += 1
		if in_window == window or index == sample_count - 1:
			var bands := Vector2(sqrt(low_energy / in_window), sqrt(high_energy / in_window))
			result.append(bands)
			peak = maxf(peak, maxf(bands.x, bands.y))
			low_energy = 0.0
			high_energy = 0.0
			in_window = 0
	if peak > 0.00001:
		for index in result.size():
			result[index] = result[index] / peak
	return result


func get_haptic_envelope(cue: String) -> PackedVector2Array:
	return haptic_envelopes.get(cue, PackedVector2Array())


func _loop_track(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream: AudioStreamWAV = source.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.mix_rate * stream.get_length())
	return stream


func _process(delta: float) -> void:
	threat_level = move_toward(threat_level, threat_target, delta * 1.7)
	capture_duck = move_toward(capture_duck, capture_duck_target, delta * 2.2)
	if music_player != null:
		music_player.volume_db = lerpf(-24.0, -48.0, capture_duck)
	if threat_player != null:
		threat_player.volume_db = lerpf(-48.0, -12.0, threat_level) - capture_duck * 15.0


func play(cue: String) -> void:
	cue_played.emit(cue)
	if not effects_enabled or not effects.has(cue):
		return
	var player := AudioStreamPlayer.new()
	player.stream = effects[cue]
	if cue == "balloon_pop":
		player.volume_db = -1.5
	elif cue == "inflate":
		player.volume_db = -7.0
	else:
		player.volume_db = -5.0 if cue in ["coin", "switch", "portal"] else -10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func toggle_music() -> void:
	music_muted = not music_muted
	if music_muted:
		music_player.stop()
		threat_player.stop()
	else:
		music_player.play()
		threat_player.play()


func stop_all() -> void:
	if music_player != null:
		music_player.stop()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()


func reset_cinematic_mix() -> void:
	capture_duck_target = 0.0
	threat_target = 0.0
	if not music_muted and DisplayServer.get_name() != "headless":
		if music_player != null and not music_player.playing:
			music_player.play()
		if threat_player != null and not threat_player.playing:
			threat_player.play()


func set_capture_mix(darkness: float) -> void:
	capture_duck_target = clampf(darkness, 0.0, 1.0)


func set_threat(amount: float) -> void:
	threat_target = clampf(amount, 0.0, 1.0)


func _make_effect(cue: String) -> AudioStreamWAV:
	var duration := 0.12
	var notes: Array[Dictionary] = []
	match cue:
		"step":
			duration = 0.075
			notes = [{"at": 0.0, "length": 0.055, "from": 330.0, "to": 250.0, "gain": 0.16, "shape": "sine"}]
		"blocked":
			duration = 0.16
			notes = [{"at": 0.0, "length": 0.12, "from": 115.0, "to": 62.0, "gain": 0.28, "shape": "triangle"}, {"at": 0.0, "length": 0.07, "from": 800.0, "to": 260.0, "gain": 0.08, "shape": "noise"}]
		"coin":
			duration = 0.28
			notes = [{"at": 0.0, "length": 0.08, "from": 780.0, "to": 970.0, "gain": 0.22, "shape": "square"}, {"at": 0.07, "length": 0.16, "from": 1175.0, "to": 1640.0, "gain": 0.2, "shape": "sine"}, {"at": 0.12, "length": 0.1, "from": 2480.0, "to": 2100.0, "gain": 0.06, "shape": "sine"}]
		"shield":
			duration = 0.42
			notes = [{"at": 0.0, "length": 0.35, "from": 120.0, "to": 540.0, "gain": 0.2, "shape": "saw"}, {"at": 0.1, "length": 0.24, "from": 720.0, "to": 1180.0, "gain": 0.09, "shape": "sine"}]
		"hit":
			duration = 0.3
			notes = [{"at": 0.0, "length": 0.22, "from": 160.0, "to": 48.0, "gain": 0.31, "shape": "square"}, {"at": 0.0, "length": 0.08, "from": 1000.0, "to": 180.0, "gain": 0.15, "shape": "noise"}]
		"explosion":
			duration = 0.62
			notes = [{"at": 0.0, "length": 0.44, "from": 230.0, "to": 35.0, "gain": 0.4, "shape": "noise"}, {"at": 0.0, "length": 0.54, "from": 92.0, "to": 24.0, "gain": 0.38, "shape": "saw"}, {"at": 0.03, "length": 0.22, "from": 1300.0, "to": 70.0, "gain": 0.18, "shape": "noise"}]
		"portal":
			duration = 0.9
			notes = [{"at": 0.0, "length": 0.8, "from": 480.0, "to": 55.0, "gain": 0.19, "shape": "sine"}, {"at": 0.05, "length": 0.52, "from": 950.0, "to": 130.0, "gain": 0.06, "shape": "triangle"}]
		"switch":
			duration = 0.48
			notes = [{"at": 0.0, "length": 0.12, "from": 530.0, "to": 530.0, "gain": 0.14, "shape": "sine"}, {"at": 0.11, "length": 0.14, "from": 790.0, "to": 790.0, "gain": 0.15, "shape": "sine"}, {"at": 0.23, "length": 0.2, "from": 1060.0, "to": 1320.0, "gain": 0.18, "shape": "sine"}]
		"jump":
			duration = 0.2
			notes = [{"at": 0.0, "length": 0.17, "from": 260.0, "to": 690.0, "gain": 0.13, "shape": "saw"}]
		"inflate":
			duration = 0.94
			notes = [{"at": 0.0, "length": 0.86, "from": 155.0, "to": 455.0, "gain": 0.18, "shape": "squeak"}, {"at": 0.12, "length": 0.72, "from": 310.0, "to": 915.0, "gain": 0.075, "shape": "squeak"}]
		"balloon_pop":
			duration = 0.48
			notes = [{"at": 0.0, "length": 0.035, "from": 1950.0, "to": 420.0, "gain": 0.5, "shape": "noise"}, {"at": 0.0, "length": 0.19, "from": 245.0, "to": 54.0, "gain": 0.3, "shape": "triangle"}, {"at": 0.018, "length": 0.31, "from": 870.0, "to": 90.0, "gain": 0.16, "shape": "noise"}, {"at": 0.0, "length": 0.075, "from": 1120.0, "to": 310.0, "gain": 0.14, "shape": "sine"}]
		"breaker":
			duration = 0.4
			notes = [{"at": 0.0, "length": 0.2, "from": 280.0, "to": 620.0, "gain": 0.18, "shape": "triangle"}, {"at": 0.13, "length": 0.2, "from": 740.0, "to": 1180.0, "gain": 0.11, "shape": "sine"}]
		"break_wall":
			duration = 0.52
			notes = [{"at": 0.0, "length": 0.34, "from": 118.0, "to": 43.0, "gain": 0.33, "shape": "noise"}, {"at": 0.0, "length": 0.31, "from": 156.0, "to": 61.0, "gain": 0.28, "shape": "saw"}, {"at": 0.16, "length": 0.19, "from": 530.0, "to": 205.0, "gain": 0.09, "shape": "triangle"}]
		"power_speed":
			duration = 0.32
			notes = [{"at": 0.0, "length": 0.24, "from": 350.0, "to": 1450.0, "gain": 0.18, "shape": "saw"}, {"at": 0.08, "length": 0.16, "from": 880.0, "to": 1760.0, "gain": 0.1, "shape": "sine"}]
		"power_magnet":
			duration = 0.4
			notes = [{"at": 0.0, "length": 0.32, "from": 680.0, "to": 320.0, "gain": 0.16, "shape": "sine"}, {"at": 0.09, "length": 0.26, "from": 420.0, "to": 880.0, "gain": 0.1, "shape": "triangle"}]
		"power_blink":
			duration = 0.34
			notes = [{"at": 0.0, "length": 0.24, "from": 1200.0, "to": 390.0, "gain": 0.15, "shape": "triangle"}, {"at": 0.12, "length": 0.18, "from": 700.0, "to": 1600.0, "gain": 0.1, "shape": "sine"}]
		"power_time_freeze":
			duration = 0.5
			notes = [{"at": 0.0, "length": 0.4, "from": 1100.0, "to": 210.0, "gain": 0.14, "shape": "sine"}, {"at": 0.05, "length": 0.33, "from": 780.0, "to": 145.0, "gain": 0.1, "shape": "triangle"}]
		"blink":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.1, "from": 900.0, "to": 100.0, "gain": 0.16, "shape": "noise"}, {"at": 0.06, "length": 0.15, "from": 420.0, "to": 1250.0, "gain": 0.15, "shape": "sine"}]
		"puzzle_error":
			duration = 0.3
			notes = [{"at": 0.0, "length": 0.12, "from": 330.0, "to": 270.0, "gain": 0.16, "shape": "square"}, {"at": 0.13, "length": 0.13, "from": 250.0, "to": 170.0, "gain": 0.16, "shape": "square"}]
		"rhythm_trap":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.14, "from": 920.0, "to": 120.0, "gain": 0.16, "shape": "noise"}, {"at": 0.0, "length": 0.2, "from": 180.0, "to": 65.0, "gain": 0.2, "shape": "triangle"}]
		"near_miss":
			duration = 0.19
			notes = [{"at": 0.0, "length": 0.15, "from": 1500.0, "to": 300.0, "gain": 0.075, "shape": "noise"}, {"at": 0.01, "length": 0.12, "from": 560.0, "to": 230.0, "gain": 0.045, "shape": "sine"}]
	return _render_notes(duration, notes, false)


func _render_notes(duration: float, notes: Array[Dictionary], looped: bool) -> AudioStreamWAV:
	var sample_count := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / RATE
		var sample := 0.0
		for note in notes:
			var local_t: float = t - note.at
			if local_t < 0.0 or local_t > note.length:
				continue
			var progress: float = local_t / note.length
			var phase: float = TAU * (note.from * local_t + (note.to - note.from) * local_t * local_t / (2.0 * note.length))
			var wave := sin(phase)
			match note.shape:
				"square": wave = 1.0 if sin(phase) >= 0.0 else -1.0
				"saw": wave = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
				"noise": wave = rng.randf_range(-1.0, 1.0)
				"triangle": wave = asin(sin(phase)) * 2.0 / PI
				"squeak":
					var wobble := sin(TAU * local_t * 7.2) * 0.78
					wave = sin(phase + wobble) * 0.78 + sin(phase * 2.03 + wobble * 0.5) * 0.22
			var attack := minf(1.0, local_t / 0.012)
			var release := minf(1.0, (note.length - local_t) / 0.05)
			sample += wave * note.gain * attack * release
		bytes.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream
