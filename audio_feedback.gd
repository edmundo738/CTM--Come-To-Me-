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
# Small, pausable spatial voices for already-committed environmental motions.
var mechanism_players: Array[AudioStreamPlayer2D] = []
var mechanism_paused := false


func _ready() -> void:
	rng.randomize()
	for cue in ["step", "blocked", "crate_wood", "crate_metal", "crate_push", "current", "ice_crack", "electric_water", "coin", "shield", "hit", "heart_lost", "heart_recovered", "explosion", "portal", "captor_reveal", "switch", "jump", "inflate", "balloon_pop", "breaker", "break_wall", "break_glass", "break_metal", "break_ice", "enemy_crush", "shield_contact", "electric_contact", "electric_arc", "power_speed", "power_magnet", "power_blink", "power_time_freeze", "blink", "puzzle_error", "rhythm_trap", "near_miss", "plate_wood", "plate_metal", "gate_open", "gate_close", "water_drain"]:
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


func play(cue: String, layer_gain_db: float = 0.0) -> void:
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
	# Optional supporting layers stay quieter than the primary cue.
	player.volume_db += minf(0.0, layer_gain_db)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# An ambient discharge is separate from tactical events and haptics. It uses
# the same effects mute, a quiet spatial voice and the real arc position.
func play_ambient_at(cue: String, world_position: Vector2) -> void:
	if not effects_enabled or not effects.has(cue):
		return
	cue_played.emit(cue)
	var player := AudioStreamPlayer2D.new()
	player.stream = effects[cue]
	player.volume_db = -23.0
	player.max_distance = 300.0
	add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()


# Mechanism sounds are distinct from tactical events: they are short, spatial,
# bounded and can pause with the visual mechanism they accompany.
func play_mechanism_at(cue: String, world_position: Vector2) -> void:
	if not effects_enabled or not effects.has(cue):
		return
	while mechanism_players.size() >= 4:
		var oldest: AudioStreamPlayer2D = mechanism_players.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()
	var player := AudioStreamPlayer2D.new()
	player.stream = effects[cue]
	player.volume_db = -17.0
	player.max_distance = 480.0
	add_child(player)
	player.global_position = world_position
	mechanism_players.append(player)
	player.finished.connect(_on_mechanism_finished.bind(player))
	cue_played.emit(cue)
	player.play()
	player.stream_paused = mechanism_paused


func _on_mechanism_finished(player: AudioStreamPlayer2D) -> void:
	mechanism_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()


func set_mechanism_paused(paused: bool) -> void:
	mechanism_paused = paused
	for index in range(mechanism_players.size() - 1, -1, -1):
		var player := mechanism_players[index]
		if not is_instance_valid(player):
			mechanism_players.remove_at(index)
		elif player.stream_paused != paused:
			player.stream_paused = paused


func stop_mechanism_sounds() -> void:
	for player in mechanism_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	mechanism_players.clear()


func toggle_music() -> void:
	music_muted = not music_muted
	if music_muted:
		music_player.stop()
		threat_player.stop()
	else:
		music_player.play()
		threat_player.play()


func stop_all() -> void:
	stop_mechanism_sounds()
	if music_player != null:
		music_player.stop()
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if child is AudioStreamPlayer:
			child.stop()
		elif child is AudioStreamPlayer2D:
			child.stop()
			child.queue_free()


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
		"plate_wood":
			duration = 0.20
			notes = [{"at": 0.0, "length": 0.14, "from": 165.0, "to": 78.0, "gain": 0.20, "shape": "triangle"}, {"at": 0.008, "length": 0.055, "from": 730.0, "to": 320.0, "gain": 0.065, "shape": "noise"}, {"at": 0.055, "length": 0.08, "from": 290.0, "to": 155.0, "gain": 0.055, "shape": "sine"}]
		"plate_metal":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.14, "from": 310.0, "to": 145.0, "gain": 0.16, "shape": "triangle"}, {"at": 0.012, "length": 0.18, "from": 1250.0, "to": 810.0, "gain": 0.08, "shape": "sine"}, {"at": 0.0, "length": 0.045, "from": 1800.0, "to": 680.0, "gain": 0.055, "shape": "noise"}]
		"gate_open", "gate_close":
			duration = 0.38
			var opening := cue == "gate_open"
			notes = [{"at": 0.0, "length": 0.28, "from": 125.0 if opening else 210.0, "to": 210.0 if opening else 115.0, "gain": 0.12, "shape": "triangle"}, {"at": 0.01, "length": 0.25, "from": 480.0, "to": 250.0, "gain": 0.045, "shape": "noise"}, {"at": 0.25, "length": 0.09, "from": 360.0, "to": 125.0, "gain": 0.10, "shape": "triangle"}]
		"water_drain":
			duration = 0.95
			notes = [{"at": 0.0, "length": 0.83, "from": 600.0, "to": 180.0, "gain": 0.065, "shape": "noise"}, {"at": 0.06, "length": 0.68, "from": 160.0, "to": 65.0, "gain": 0.09, "shape": "sine"}, {"at": 0.27, "length": 0.25, "from": 390.0, "to": 170.0, "gain": 0.045, "shape": "sine"}]
		"crate_wood":
			duration = 0.18
			notes = [{"at": 0.0, "length": 0.15, "from": 145.0, "to": 75.0, "gain": 0.19, "shape": "triangle"}, {"at": 0.015, "length": 0.09, "from": 610.0, "to": 220.0, "gain": 0.055, "shape": "noise"}]
		"crate_metal":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.19, "from": 390.0, "to": 260.0, "gain": 0.11, "shape": "triangle"}, {"at": 0.015, "length": 0.16, "from": 1180.0, "to": 890.0, "gain": 0.055, "shape": "sine"}]
		"coin":
			duration = 0.28
			notes = [{"at": 0.0, "length": 0.08, "from": 780.0, "to": 970.0, "gain": 0.22, "shape": "square"}, {"at": 0.07, "length": 0.16, "from": 1175.0, "to": 1640.0, "gain": 0.2, "shape": "sine"}, {"at": 0.12, "length": 0.1, "from": 2480.0, "to": 2100.0, "gain": 0.06, "shape": "sine"}]
		"shield":
			duration = 0.42
			notes = [{"at": 0.0, "length": 0.35, "from": 120.0, "to": 540.0, "gain": 0.2, "shape": "saw"}, {"at": 0.1, "length": 0.24, "from": 720.0, "to": 1180.0, "gain": 0.09, "shape": "sine"}]
		"hit":
			duration = 0.3
			notes = [{"at": 0.0, "length": 0.22, "from": 160.0, "to": 48.0, "gain": 0.31, "shape": "square"}, {"at": 0.0, "length": 0.08, "from": 1000.0, "to": 180.0, "gain": 0.15, "shape": "noise"}]
		"heart_lost":
			duration = 0.38
			notes = [{"at": 0.0, "length": 0.30, "from": 410.0, "to": 135.0, "gain": 0.23, "shape": "triangle"}, {"at": 0.08, "length": 0.22, "from": 270.0, "to": 110.0, "gain": 0.13, "shape": "sine"}]
		"heart_recovered":
			duration = 0.43
			notes = [{"at": 0.0, "length": 0.16, "from": 440.0, "to": 670.0, "gain": 0.16, "shape": "sine"}, {"at": 0.14, "length": 0.24, "from": 670.0, "to": 1050.0, "gain": 0.15, "shape": "sine"}]
		"explosion":
			duration = 0.62
			notes = [{"at": 0.0, "length": 0.44, "from": 230.0, "to": 35.0, "gain": 0.4, "shape": "noise"}, {"at": 0.0, "length": 0.54, "from": 92.0, "to": 24.0, "gain": 0.38, "shape": "saw"}, {"at": 0.03, "length": 0.22, "from": 1300.0, "to": 70.0, "gain": 0.18, "shape": "noise"}]
		"portal":
			duration = 0.9
			notes = [{"at": 0.0, "length": 0.8, "from": 480.0, "to": 55.0, "gain": 0.19, "shape": "sine"}, {"at": 0.05, "length": 0.52, "from": 950.0, "to": 130.0, "gain": 0.06, "shape": "triangle"}]
		"captor_reveal":
			duration = 1.55
			notes = [{"at": 0.0, "length": 1.35, "from": 74.0, "to": 42.0, "gain": 0.24, "shape": "sine"}, {"at": 0.0, "length": 1.1, "from": 148.0, "to": 96.0, "gain": 0.16, "shape": "triangle"}, {"at": 0.12, "length": 0.95, "from": 390.0, "to": 1120.0, "gain": 0.095, "shape": "sine"}, {"at": 0.42, "length": 0.72, "from": 1180.0, "to": 310.0, "gain": 0.06, "shape": "noise"}]
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
		"break_glass":
			duration = 0.35
			notes = [{"at": 0.0, "length": 0.08, "from": 2600.0, "to": 980.0, "gain": 0.12, "shape": "noise"}, {"at": 0.015, "length": 0.25, "from": 1880.0, "to": 1420.0, "gain": 0.11, "shape": "sine"}, {"at": 0.07, "length": 0.19, "from": 1320.0, "to": 970.0, "gain": 0.08, "shape": "triangle"}]
		"break_ice":
			duration = 0.36
			notes = [{"at": 0.0, "length": 0.10, "from": 1500.0, "to": 450.0, "gain": 0.13, "shape": "noise"}, {"at": 0.02, "length": 0.25, "from": 1120.0, "to": 720.0, "gain": 0.10, "shape": "sine"}, {"at": 0.0, "length": 0.20, "from": 240.0, "to": 90.0, "gain": 0.12, "shape": "triangle"}]
		"break_metal":
			duration = 0.44
			notes = [{"at": 0.0, "length": 0.18, "from": 220.0, "to": 90.0, "gain": 0.20, "shape": "triangle"}, {"at": 0.01, "length": 0.32, "from": 1020.0, "to": 720.0, "gain": 0.11, "shape": "sine"}, {"at": 0.03, "length": 0.20, "from": 1550.0, "to": 1110.0, "gain": 0.07, "shape": "sine"}]
		"enemy_crush":
			duration = 0.31
			notes = [{"at": 0.0, "length": 0.21, "from": 190.0, "to": 54.0, "gain": 0.25, "shape": "triangle"}, {"at": 0.005, "length": 0.075, "from": 1150.0, "to": 250.0, "gain": 0.11, "shape": "noise"}]
		"shield_contact":
			duration = 0.26
			notes = [{"at": 0.0, "length": 0.20, "from": 650.0, "to": 360.0, "gain": 0.16, "shape": "triangle"}, {"at": 0.015, "length": 0.16, "from": 1450.0, "to": 1070.0, "gain": 0.08, "shape": "sine"}]
		"electric_contact":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.07, "from": 1900.0, "to": 420.0, "gain": 0.13, "shape": "noise"}, {"at": 0.07, "length": 0.10, "from": 1250.0, "to": 500.0, "gain": 0.10, "shape": "saw"}, {"at": 0.02, "length": 0.18, "from": 330.0, "to": 95.0, "gain": 0.10, "shape": "triangle"}]
		"electric_arc":
			# A short dry crackle plus a low electrical body; spatialised quietly
			# and rate-limited by the presentation, never a loop or gameplay cue.
			duration = 0.16
			notes = [{"at": 0.0, "length": 0.055, "from": 2200.0, "to": 680.0, "gain": 0.18, "shape": "noise"}, {"at": 0.045, "length": 0.045, "from": 1500.0, "to": 440.0, "gain": 0.11, "shape": "noise"}, {"at": 0.0, "length": 0.14, "from": 170.0, "to": 125.0, "gain": 0.10, "shape": "saw"}]
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
		"crate_push":
			duration = 0.24
			notes = [{"at": 0.0, "length": 0.12, "from": 180.0, "to": 95.0, "gain": 0.25, "shape": "triangle"}, {"at": 0.025, "length": 0.08, "from": 680.0, "to": 310.0, "gain": 0.09, "shape": "noise"}]
		"current":
			duration = 0.3
			notes = [{"at": 0.0, "length": 0.24, "from": 280.0, "to": 540.0, "gain": 0.12, "shape": "sine"}, {"at": 0.04, "length": 0.18, "from": 860.0, "to": 420.0, "gain": 0.045, "shape": "noise"}]
		"ice_crack":
			duration = 0.33
			notes = [{"at": 0.0, "length": 0.09, "from": 1450.0, "to": 720.0, "gain": 0.19, "shape": "noise"}, {"at": 0.025, "length": 0.22, "from": 310.0, "to": 64.0, "gain": 0.2, "shape": "triangle"}]
		"electric_water":
			duration = 0.28
			notes = [{"at": 0.0, "length": 0.22, "from": 930.0, "to": 220.0, "gain": 0.19, "shape": "noise"}, {"at": 0.0, "length": 0.17, "from": 165.0, "to": 95.0, "gain": 0.16, "shape": "square"}]
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
