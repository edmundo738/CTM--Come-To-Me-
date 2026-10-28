extends Node

const RATE := 22050
const TAU := 6.28318530718
var effects: Dictionary = {}
var rng := RandomNumberGenerator.new()
var music_player: AudioStreamPlayer
var music_muted := false
var effects_enabled := true


func _ready() -> void:
	rng.randomize()
	for cue in ["step", "blocked", "coin", "shield", "hit", "explosion", "portal", "switch", "jump"]:
		effects[cue] = _make_effect(cue)
	music_player = AudioStreamPlayer.new()
	music_player.stream = _make_music()
	music_player.volume_db = -24.0
	add_child(music_player)
	if DisplayServer.get_name() != "headless":
		music_player.play()


func play(cue: String) -> void:
	if not effects_enabled or not effects.has(cue):
		return
	var player := AudioStreamPlayer.new()
	player.stream = effects[cue]
	player.volume_db = -5.0 if cue in ["coin", "switch", "portal"] else -10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func toggle_music() -> void:
	music_muted = not music_muted
	if music_muted:
		music_player.stop()
	else:
		music_player.play()


func stop_all() -> void:
	if music_player != null:
		music_player.stop()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()


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


func _make_music() -> AudioStreamWAV:
	var duration := 16.0
	var chords := [[110.0, 164.81, 220.0], [87.31, 130.81, 174.61], [98.0, 146.83, 196.0], [73.42, 110.0, 146.83]]
	var arpeggio := [0, 2, 1, 2, 0, 1]
	var sample_count := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / RATE
		var section := mini(int(t / 4.0), 3)
		var local := fposmod(t, 4.0)
		var pad_envelope := sin(PI * minf(1.0, local / 0.55))
		var sample := 0.0
		for note in 3:
			sample += sin(TAU * chords[section][note] * t) * 0.019 * pad_envelope
		var step := int(local / 0.22)
		var step_time := fposmod(local, 0.22)
		var arp_frequency: float = chords[section][arpeggio[step % arpeggio.size()]] * 2.0
		var arp_envelope := minf(1.0, step_time / 0.025) * maxf(0.0, 1.0 - step_time / 0.2)
		sample += sin(TAU * arp_frequency * t) * 0.032 * arp_envelope
		# Tiny softened wrap keeps the four-chord ambience from clicking at the loop edge.
		if t > duration - 0.12:
			var fade := (duration - t) / 0.12
			sample *= fade
		bytes.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
