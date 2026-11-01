extends SceneTree

const GameScript = preload("res://game.gd")
const HapticMixer = preload("res://haptic_mixer.gd")
var failures: Array[String] = []


class FakeInput extends RefCounted:
	var devices := {
		2: {"name": "Xbox Controller", "guid": "xbox"},
		7: {"name": "PlayStation Controller", "guid": "ps"},
	}
	var pulses: Array[Dictionary] = []
	var all_pulses: Array[Dictionary] = []
	var stopped: Array[int] = []

	func get_connected_joypads() -> Array:
		return devices.keys()

	func get_joy_name(id: int) -> String:
		return devices[id].name

	func get_joy_guid(id: int) -> String:
		return devices[id].guid

	func get_joy_info(_id: int) -> Dictionary:
		return {}

	func is_joy_known(_id: int) -> bool:
		return true

	func has_joy_vibration(_id: int) -> bool:
		return true

	func start_joy_vibration(id: int, weak: float, strong: float, duration: float) -> void:
		var pulse := {"id": id, "weak": weak, "strong": strong, "duration": duration}
		pulses.append(pulse)
		all_pulses.append(pulse)

	func stop_joy_vibration(id: int) -> void:
		stopped.append(id)


func _initialize() -> void:
	call_deferred("_run_tests")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _run_tests() -> void:
	var fake := FakeInput.new()
	var game = GameScript.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.controller.set_backend(fake)
	game.controller._activate_device(7)
	game.audio.effects_enabled = false
	var events: Array[Dictionary] = []
	var sounds: Array[String] = []
	game.feedback_bus.event_emitted.connect(func(event: String, context: Dictionary): events.append({"event": event, "context": context.duplicate()}))
	game.audio.cue_played.connect(func(cue: String): sounds.append(cue))

	_test_patterns(game, fake)
	_test_intensity_and_safety(game, fake)
	_test_audio_bands_and_bridge(game, fake, events, sounds)
	_test_threat_pulses(game, fake, events)
	_test_actual_turn_events(game, fake, events, sounds)
	_test_other_mechanics(game, fake, events)

	for pulse in fake.all_pulses:
		_expect(float(pulse.weak) >= 0.0 and float(pulse.weak) <= 1.0 and float(pulse.strong) >= 0.0 and float(pulse.strong) <= 1.0, "motor magnitudes remain in range")
		_expect(float(pulse.duration) > 0.0 and float(pulse.duration) <= HapticMixer.MAX_REQUEST_SECONDS + 0.0001, "every motor request is bounded and finite")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("TACTICAL_FEEDBACK_TEST_PASS: eventos, bandas sonoras, sequencias, prioridade, intensidade, perigo e seguranca simulada")
	else:
		printerr("TACTICAL_FEEDBACK_TEST_FAIL: %d check(s): %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)


func _fresh(game: Node, fake: FakeInput) -> void:
	game.controller.set_vibration_enabled(true)
	game.controller.set_vibration_intensity(1.0)
	game.controller.reset_held_inputs()
	game.controller._activate_device(7)
	fake.pulses.clear()
	fake.stopped.clear()


func _test_patterns(game: Node, fake: FakeInput) -> void:
	var signatures: Array[String] = []
	for cue in ["step", "blocked", "coin", "shield", "shield_impact", "elite_stagger", "break_wall", "portal", "inflate", "balloon_pop", "near_miss", "heartbeat"]:
		_expect(HapticMixer.PATTERNS.has(cue), "catalog contains " + cue)
		var signature := str(HapticMixer.PATTERNS[cue].segments)
		_expect(not signatures.has(signature), "signature is distinct: " + cue)
		signatures.append(signature)
	_fresh(game, fake)
	_expect(game.controller.feedback("blocked") and fake.pulses.back().strong > 0.8, "blocked move starts with a readable low-frequency impact")
	game.controller.tick(0.0) # First tick establishes the voice's start frame.
	game.controller.tick(0.12)
	_expect(fake.stopped.has(7), "blocked signature contains a true silent gap")
	var before := fake.pulses.size()
	game.controller.tick(0.06)
	_expect(fake.pulses.size() == before + 1 and fake.pulses.back().strong > 0.3, "blocked signature has a later echo")

	_fresh(game, fake)
	game.controller.feedback("step", false, -1, {"material": "garden"})
	var garden: Dictionary = fake.pulses.back().duplicate()
	game.controller.reset_held_inputs()
	game.controller.feedback("step", false, -1, {"material": "forge"})
	var forge: Dictionary = fake.pulses.back().duplicate()
	_expect(not is_equal_approx(garden.strong, forge.strong), "existing biome materials change the movement texture")

	_fresh(game, fake)
	game.controller.feedback("step")
	game.controller.feedback("shield_impact")
	var impact: Dictionary = fake.pulses.back().duplicate()
	game.controller.feedback("power_magnet")
	game.controller.tick(0.0)
	var composed: Dictionary = fake.pulses.back().duplicate()
	_expect(composed.strong >= impact.strong - 0.001 and composed.weak >= impact.weak - 0.001, "a lower-priority event cannot overwrite an impact")
	fake.stopped.clear()
	game.controller.tick(0.26)
	_expect(fake.stopped.has(7), "a lower-priority voice cannot fill the impact's intentional silence")
	game.controller.tick(0.07)
	_expect(fake.pulses.back().strong > 0.2, "impact resumes after its gap")

	_fresh(game, fake)
	game.controller.feedback("shield_impact")
	for cue in ["menu_move", "menu_confirm", "step", "wait", "coin", "switch", "jump", "heartbeat", "power_magnet"]:
		game.controller.feedback(cue)
	var found_impact := false
	for voice in game.controller.haptics.voices:
		found_impact = found_impact or voice.cue == "shield_impact"
	_expect(found_impact and game.controller.haptics.voices.size() <= HapticMixer.MAX_VOICES_PER_DEVICE, "voice cap preserves the important event under spam")

	_fresh(game, fake)
	game.controller.feedback("step", true, 2)
	game.controller.feedback("test", true, 7)
	fake.stopped.clear()
	game.controller.tick(0.0)
	game.controller.tick(0.08)
	game.controller.tick(0.01)
	game.controller.tick(0.03)
	_expect(fake.stopped.has(2), "a short voice stops on its own device even while another device is still playing")

	_fresh(game, fake)
	game.controller.feedback("step")
	game.controller.tick(0.4)
	_expect(not game.controller.haptics.voices.is_empty() and is_equal_approx(float(game.controller.haptics.voices[0].elapsed), 0.0), "a long input frame cannot erase a freshly requested pulse")
	game.controller.tick(0.1)
	_expect(game.controller.haptics.voices.is_empty() and fake.stopped.has(7), "the fresh pulse still ends normally on the next frame")


func _test_intensity_and_safety(game: Node, fake: FakeInput) -> void:
	_fresh(game, fake)
	game.controller.feedback("step")
	var full: Dictionary = fake.pulses.back().duplicate()
	game.controller.set_vibration_intensity(0.4)
	game.controller.feedback("step")
	var reduced: Dictionary = fake.pulses.back().duplicate()
	_expect(is_equal_approx(reduced.weak, full.weak * 0.4) and is_equal_approx(reduced.strong, full.strong * 0.4), "intensity scales both motors without changing the pattern")
	game.controller.set_vibration_intensity(0.0)
	var count := fake.pulses.size()
	_expect(not game.controller.feedback("test", true, 7) and fake.pulses.size() == count, "zero intensity stops and suppresses even a forced test")
	_expect(game.controller.vibration_enabled, "intensity zero does not silently change the separate on/off setting")
	game.controller.set_vibration_intensity(0.6)
	game.controller.set_vibration_enabled(false)
	_expect(not game.controller.feedback("step") and fake.stopped.has(7), "turning vibration off immediately stops the motor")
	game.controller.set_vibration_enabled(true)
	game.controller.note_keyboard_or_mouse()
	_expect(game.controller.feedback("test", true, 2) and fake.pulses.back().id == 2, "forced test targets the selected pad without gamepad input")
	game.controller.reset_held_inputs()
	game.controller._activate_device(7)
	game.controller.feedback("break_wall")
	game.controller.note_keyboard_or_mouse()
	count = fake.pulses.size()
	game.controller.tick(0.4)
	_expect(fake.pulses.size() == count and fake.stopped.has(7), "switching to keyboard or touch cancels pending gameplay segments")

	game.controller._activate_device(7)
	game.controller.feedback("break_wall")
	fake.devices.erase(7)
	game.controller._on_joy_connection_changed(7, false)
	count = fake.pulses.size()
	game.controller.tick(1.0)
	_expect(fake.pulses.size() == count and not game.controller.using_gamepad and fake.stopped.has(7), "disconnect cannot restart a motor or hand feedback to another pad")
	fake.devices[7] = {"name": "PlayStation Controller", "guid": "ps"}
	game.controller._on_joy_connection_changed(7, true)
	game.controller._activate_device(7)
	game.controller.feedback("portal")
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	count = fake.pulses.size()
	game.controller.tick(0.4)
	_expect(fake.pulses.size() == count and game.controller.haptics.voices.is_empty(), "focus loss clears every scheduled segment")


func _tone(frequency: float) -> AudioStreamWAV:
	var rate := 22050
	var sample_count := int(rate * 0.14)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var sample := sin(TAU * frequency * float(index) / rate) * 0.65
		bytes.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _mean_bands(samples: PackedVector2Array) -> Vector2:
	var result := Vector2.ZERO
	for sample in samples:
		result += sample
	return result / maxf(1.0, samples.size())


func _test_audio_bands_and_bridge(game: Node, fake: FakeInput, events: Array[Dictionary], sounds: Array[String]) -> void:
	var bass: Vector2 = _mean_bands(game.audio._analyze_haptic_envelope(_tone(100.0)))
	var treble: Vector2 = _mean_bands(game.audio._analyze_haptic_envelope(_tone(3500.0)))
	_expect(bass.x > bass.y and treble.y > treble.x, "low/high audio bands follow the frequency content of real samples")
	_expect(not game.audio.get_haptic_envelope("break_wall").is_empty(), "generated effects have precomputed time-varying envelopes")

	_fresh(game, fake)
	events.clear()
	sounds.clear()
	game.feedback_bus.emit_event("COIN_PICKUP")
	_expect(events.size() == 1 and events[0].event == "COIN_PICKUP" and sounds == ["coin"] and fake.pulses.size() == 1, "bus produces one sound, one event and one initial haptic, even muted")
	game.controller.reset_held_inputs()
	fake.pulses.clear()
	events.clear()
	sounds.clear()
	game.audio.play("coin")
	_expect(events.size() == 1 and events[0].event == "COIN_PICKUP" and sounds == ["coin"] and fake.pulses.size() == 1, "external audio.play remains bridged without double dispatch")
	_expect(not game.feedback_bus.emit_event("NOT_A_REAL_EVENT"), "unknown semantic events are ignored")


func _test_threat_pulses(game: Node, fake: FakeInput, events: Array[Dictionary]) -> void:
	_fresh(game, fake)
	events.clear()
	game.feedback_bus.heartbeat_cooldown = 0.0
	game.feedback_bus.threat_active = false
	game.feedback_bus.tick(0.01, 4, true, 0.6)
	_expect(events.size() == 1 and events[0].event == "ENEMY_NEAR" and is_equal_approx(game.audio.threat_target, 0.6), "danger coordinates its heartbeat and the existing music layer")
	var distant_gain: float = events[0].context.gain
	game.controller.tick(0.0)
	game.controller.tick(0.3)
	game.feedback_bus.tick(0.3, 4, true, 0.6)
	_expect(events.size() == 1 and game.controller.haptics.voices.is_empty(), "distant threat leaves a real silent interval")
	game.feedback_bus.tick(5.0, 1, true, 0.9)
	_expect(events.size() == 2 and float(events.back().context.gain) > distant_gain, "a long frame emits at most one stronger nearby warning")
	game.feedback_bus.tick(10.0, 1, true, 0.9)
	var reminders := events.size()
	game.feedback_bus.tick(10.0, 1, true, 0.9)
	_expect(events.size() == reminders, "stationary danger stops reminding after two double pulses")
	game.feedback_bus.emit_event("TURN_COMMITTED")
	game.feedback_bus.tick(1.0, 1, true, 0.9)
	_expect(events.back().event == "ENEMY_NEAR", "the next tactical turn can renew danger reminders")
	game.feedback_bus.tick(0.01, 1, false, 0.0)
	var has_threat := false
	for voice in game.controller.haptics.voices:
		has_threat = has_threat or voice.category == "threat"
	_expect(not has_threat and is_equal_approx(game.audio.threat_target, 0.0), "pausing or leaving danger cancels heartbeat segments")


func _event_names(events: Array[Dictionary]) -> Array:
	return events.map(func(item): return item.event)


func _test_actual_turn_events(game: Node, fake: FakeInput, events: Array[Dictionary], sounds: Array[String]) -> void:
	_fresh(game, fake)
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	game.switches.clear()
	game.traps.clear()
	game.coins.clear()
	game.shields.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.player_position = Vector2i(5, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.coins.append(Vector2i(6, 5))
	events.clear()
	sounds.clear()
	var turn: int = game.turn_number
	game.try_move(1, 0)
	_expect(game.turn_number == turn + 1 and game.player_position == Vector2i(6, 5) and game.coins.is_empty(), "move, pickup and turn resolve synchronously as before")
	_expect(_event_names(events) == ["MOVE", "TURN_COMMITTED", "COIN_PICKUP"] and sounds == ["step", "coin"], "actual move publishes ordered semantic consequences once")
	_expect(game.turn_pulse_time < 0.0 and game.turn_pulse_time > -1.0, "turn ring is delayed only visually until the ball lands")
	game.grid[5][7] = game.TILE_WALL
	events.clear()
	turn = game.turn_number
	game.try_move(1, 0)
	_expect(game.turn_number == turn and _event_names(events) == ["BLOCKED"], "blocked action emits feedback but spends no turn")

	game.grid[5][7] = game.TILE_FLOOR
	game.player_position = Vector2i(8, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.enemies.clear()
	var enemy: Dictionary = game._make_enemy(Vector2i(6, 5), "hunter")
	enemy.next = Vector2i(7, 5)
	game.enemies.append(enemy)
	game.feedback_bus.near_miss_cooldown = 0.0
	events.clear()
	sounds.clear()
	game.wait_turn()
	_expect(game.enemies[0].pos == Vector2i(7, 5) and game.game_state == "playing" and _event_names(events).has("NEAR_MISS"), "a pursuer advancing to an adjacent cell emits a near miss without altering the turn")
	_expect(game.near_miss_feedback_time > 0.0 and sounds == ["near_miss"], "near miss coordinates the brief visual and sound response")
	game.grid[5][7] = game.TILE_WALL
	game.enemies[0].pos = Vector2i(6, 5)
	_expect(game._nearest_visible_threat() == -1, "danger feedback does not reveal an enemy behind a wall")
	game.grid[5][7] = game.TILE_FLOOR
	_expect(game._nearest_visible_threat() == 2, "visible nearby enemy contributes to danger feedback")

	game.enemies.clear()
	game.damage_this_turn = false
	game.charges = 1
	events.clear()
	game._apply_damage("TESTE", Color.WHITE)
	_expect(game.charges == 0 and _event_names(events) == ["SHIELD_IMPACT"], "shield absorption has a distinct semantic impact")
	game.damage_this_turn = false
	game.charges = 1
	game.enemies.append(game._make_warden(Vector2i(9, 5)))
	events.clear()
	game._stagger_elite(0)
	_expect(_event_names(events) == ["ELITE_COUNTER"], "boss counter has a different signature from shield absorption")

	game.enemies.clear()
	game.damage_this_turn = false
	game.charges = 0
	game.game_state = "playing"
	events.clear()
	game._apply_damage("TESTE", Color.WHITE)
	game._process(game.CAPTURE_POP_TIME + 0.01)
	_expect(game.game_state == "captured" and _event_names(events) == ["CAPTURE_START", "CAPTURE_POP"], "capture crescendo and pop are tied to the existing cinematic")
	var pop_active := false
	for voice in game.controller.haptics.voices:
		pop_active = pop_active or (voice.cue == "balloon_pop" and is_equal_approx(float(voice.elapsed), 0.0))
	_expect(pop_active, "a long frame does not instantly skip a newly emitted capture pop")

	game.game_state = "playing"
	game.objective_type = "switches"
	game.switches.clear()
	game.switches.append({"pos": game.player_position, "active": false})
	game.portal_open = false
	events.clear()
	game._activate_switches()
	_expect(game.portal_open and _event_names(events) == ["SWITCH_ON", "PORTAL_OPEN"], "opening a portal is distinct from entering it")
	game.player_position = game.portal_position
	events.clear()
	game._check_portal()
	_expect(_event_names(events).has("PORTAL_ENTER") and game.game_state in ["floor_clear", "rescued"], "entering the portal still completes the floor immediately")


func _test_other_mechanics(game: Node, fake: FakeInput, events: Array[Dictionary]) -> void:
	_fresh(game, fake)
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	game.player_position = Vector2i(5, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.coins.clear()
	game.shields.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.shields.append(game.player_position)
	game.breakers.append(game.player_position)
	game.powerups.append({"pos": game.player_position, "kind": "speed"})
	events.clear()
	game._collect_pickups()
	_expect(_event_names(events) == ["SHIELD_PICKUP", "BREAKER_PICKUP", "POWER_SPEED"], "actual shield, breaker and power pickups publish separate events")
	events.clear()
	for kind in ["magnet", "blink", "time_freeze"]:
		game._activate_powerup(kind)
	_expect(_event_names(events) == ["POWER_MAGNET", "POWER_BLINK", "POWER_TIME_FREEZE"], "each existing power has its own semantic event")
	game._restore_power_state({})

	game.grid[5][6] = game.TILE_WALL
	game.facing = Vector2i.RIGHT
	game.breach_charges = 1
	events.clear()
	var turn: int = game.turn_number
	game.try_break_wall()
	_expect(game.grid[5][6] == game.TILE_FLOOR and game.breach_charges == 0 and game.turn_number == turn + 1, "demolition still consumes its charge and turn")
	_expect(_event_names(events) == ["DEMOLITION", "TURN_COMMITTED"], "actual wall demolition publishes its echo event")

	game.charges = 1
	game.player_position = Vector2i(5, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	events.clear()
	game.try_jump()
	_expect(game.player_position == Vector2i(7, 5) and _event_names(events) == ["JUMP", "TURN_COMMITTED"], "jump emits feedback but keeps its normal movement")
	game.player_position = Vector2i(5, 5)
	game.player_from = game._cell_center(game.player_position)
	game.player_to = game.player_from
	game.player_anim = 1.0
	game.blink_charges = 1
	events.clear()
	game.try_blink()
	_expect(game.player_position == Vector2i(8, 5) and _event_names(events) == ["BLINK", "TURN_COMMITTED"], "blink emits its own event without changing its landing")

	game.objective_type = "puzzle"
	game.switches.clear()
	game.switches.append({"pos": game.player_position, "active": false, "order": 1})
	events.clear()
	game._activate_switches()
	_expect(_event_names(events) == ["PUZZLE_ERROR"], "wrong rune emits the puzzle-error signature")
	game.traps.clear()
	game.traps.append({"pos": game.player_position, "type": "rhythm", "armed": true, "phase": posmod(-game.turn_number, 3)})
	game.damage_this_turn = false
	game.charges = 1
	events.clear()
	game._trigger_traps()
	_expect(game.charges == 0 and _event_names(events) == ["SHIELD_IMPACT", "RHYTHM_TRAP"], "rhythm trap and shield absorption keep their ordered feedback")
