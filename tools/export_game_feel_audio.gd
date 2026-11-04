extends SceneTree

# Exports synthesized examples from the game's own AudioFeedback generator.
# This is NOT a recording of gameplay or its final bus/spatial/music mix.
# AUDIO_EXAMPLE_OUT=/absolute/path godot --headless --path . --script res://tools/export_game_feel_audio.gd
const AudioFeedback = preload("res://audio_feedback.gd")

var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _write_example(stream: AudioStreamWAV, path: String) -> void:
	if stream == null or stream.save_to_wav(path) != OK:
		errors.append("Could not save " + path)


# Offline approximation of simultaneous voices at the player gains, before
# buses/music/spatialization. Never presented as an actual in-game recording.
func _mix(primary: AudioStreamWAV, primary_db: float, original: AudioStreamWAV = null, original_db: float = 0.0) -> AudioStreamWAV:
	var first := primary.data
	var second := original.data if original != null else PackedByteArray()
	var data := PackedByteArray()
	data.resize(maxi(first.size(), second.size()))
	var first_gain := db_to_linear(primary_db)
	var second_gain := db_to_linear(original_db)
	for offset in range(0, data.size(), 2):
		var value := 0.0
		if offset < first.size():
			value += float(first.decode_s16(offset)) * first_gain
		if offset < second.size():
			value += float(second.decode_s16(offset)) * second_gain
		data.encode_s16(offset, int(clampf(value, -32768.0, 32767.0)))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = primary.mix_rate
	result.stereo = false
	result.data = data
	return result


func _run() -> void:
	var output := OS.get_environment("AUDIO_EXAMPLE_OUT")
	if output.is_empty() or not output.is_absolute_path():
		printerr("AUDIO_EXAMPLES_FAIL: provide an absolute AUDIO_EXAMPLE_OUT path")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("AUDIO_EXAMPLES_FAIL: cannot create ", output)
		quit(2)
		return
	var audio := AudioFeedback.new()
	root.add_child(audio)
	await process_frame
	var cues := {
		"passo": "step", "bloqueio": "blocked", "caixa-madeira": "crate_wood",
		"caixa-metal": "crate_metal", "escudo-contato": "shield_contact",
		"impacto-original": "hit", "criatura": "enemy_crush", "parede": "break_wall",
		"vidro": "break_glass", "metal": "break_metal", "gelo": "break_ice",
		"arco-eletrico": "electric_arc",
	}
	for label in cues:
		_write_example(audio.effects[cues[label]], output.path_join("sintetizado-%s-bruto.wav" % label))
	# TacticalFeedback layers the old hit/wall body 10 dB below the new cue;
	# AudioFeedback plays both at -10 dB before that relative adjustment.
	_write_example(_mix(audio.effects["shield_contact"], -10.0, audio.effects["hit"], -20.0), output.path_join("aproximacao-escudo-com-corpo-original.wav"))
	_write_example(_mix(audio.effects["enemy_crush"], -10.0, audio.effects["break_wall"], -20.0), output.path_join("aproximacao-criatura-com-corpo-original.wav"))
	_write_example(_mix(audio.effects["break_glass"], -10.0, audio.effects["break_wall"], -20.0), output.path_join("aproximacao-vidro-com-corpo-original.wav"))
	_write_example(_mix(audio.effects["electric_arc"], -23.0), output.path_join("aproximacao-arco-ganho-ambiente.wav"))
	audio.stop_all()
	audio.queue_free()
	await process_frame
	if errors.is_empty():
		print("AUDIO_EXAMPLES_PASS files=16 synthesized, not in-game recordings")
		quit(0)
	else:
		for error in errors:
			printerr("AUDIO_EXAMPLES_FAIL: ", error)
		quit(1)
