extends SceneTree

const Game = preload("res://game.gd")
const Impact = preload("res://impact_presentation.gd")
const Motion = preload("res://visual_motion.gd")

var game: Node
var failures: Array[String] = []
var checks := 0
var events: Array[String] = []
var cues: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _on_event(event: String, _context: Dictionary) -> void:
	events.append(event)


func _on_cue(cue: String) -> void:
	cues.append(cue)


func _reset_arena() -> void:
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
	game.moves_this_floor = 0
	game.hits_this_floor = 0
	game.charges = 0
	game.breach_charges = 0
	game.hearts_current = 0
	game.damage_this_turn = false
	game.skills.load_state({})
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.rng.seed = 981
	events.clear()
	cues.clear()


func _test_clock() -> void:
	var fx = Impact.new()
	for kind in ["push", "block", "shield", "hurt", "electric", "capture", "elite", "defeat", "wall"]:
		var duration := float(Impact.HOLD_SECONDS[kind])
		_expect(duration >= 0.025 and duration <= 0.10, kind + " hold is selective and bounded")
	_expect(float(Impact.HOLD_SECONDS.push_soft) == 0.0 and float(Impact.HOLD_SECONDS.pickup) == 0.0, "ordinary wood pushes and pickups do not freeze")
	var recoil = Motion.new()
	recoil.reset(Vector2.ZERO)
	for i in 6:
		recoil.enqueue(Vector2(i, 0), Vector2(i + 1, 0), "heart_recoil", 0.14, "", 0.30 if i == 0 else 0.0, false)
		_expect(recoil.remaining_time() <= Motion.MAX_RECOIL_REMAINING_TIME + 0.0001, "repeated heart recoils keep their visual delay bounded")
	fx.add("shield", Vector2.ZERO, Vector2.RIGHT, 0.05)
	var step: Dictionary = fx.advance(0.03)
	_expect(step.contacts.is_empty() and is_equal_approx(float(step.visual_delta), 0.03), "no contact before visual arrival")
	step = fx.advance(0.02)
	_expect(step.contacts.size() == 1 and is_equal_approx(fx.hold_remaining, 0.048), "contact starts its bounded hold")
	step = fx.advance(0.02)
	_expect(is_zero_approx(float(step.visual_delta)) and is_equal_approx(float(step.held), 0.02), "only presentation time is held")
	fx.add("defeat", Vector2.ZERO, Vector2.RIGHT)
	step = fx.advance(0.0)
	_expect(step.contacts.size() == 1 and is_equal_approx(fx.hold_total, 0.08) and is_equal_approx(fx.hold_remaining, 0.06), "a stronger simultaneous impact coalesces from the original start")
	for _i in 50:
		fx.add("defeat", Vector2.ZERO, Vector2.RIGHT)
		fx.advance(0.0)
	_expect(fx.effects.size() <= Impact.MAX_EFFECTS and fx.hold_remaining <= 0.08, "burst effects and hold cannot grow without bound")
	step = fx.advance(0.20)
	_expect(is_equal_approx(float(step.held), 0.06) and is_equal_approx(float(step.visual_delta), 0.14), "a long frame consumes only the remaining hold")
	_expect(is_zero_approx(fx.hold_remaining), "hold ends even after many simultaneous contacts")
	fx.clear()
	fx.add("wall", Vector2.ZERO, Vector2.RIGHT, 0.2)
	step = fx.advance(0.3, true)
	_expect(step.contacts.is_empty() and fx.effects.is_empty() and is_equal_approx(float(step.visual_delta), 0.3), "pause cancels pending presentation and retains existing motion-completion policy")
	_expect(fx.advance(0.5).contacts.is_empty() and is_zero_approx(fx.hold_remaining), "resume does not replay paused contacts")
	fx.add("wall", Vector2.ZERO, Vector2.RIGHT, 0.2, "stone", "DEMOLITION", {})
	step = fx.advance(0.01, true)
	_expect(step.contacts.size() == 1 and bool(step.contacts[0].get("canceled", false)) and is_zero_approx(fx.hold_remaining), "pause flushes a cue without creating a visual contact or hold")
	_expect(fx.advance(0.3).contacts.is_empty(), "a pause-flushed cue cannot replay")
	fx.add("wall", Vector2.ZERO, Vector2.RIGHT)
	step = fx.advance(1.0)
	_expect(step.contacts.size() == 1 and fx.effects.size() == 1 and is_zero_approx(float(fx.effects[0].age)), "a stalled frame still exposes one fresh contact")
	fx.clear()
	_expect(fx.effects.is_empty() and is_zero_approx(fx.hold_remaining) and is_zero_approx(fx.refractory), "transition clears all cosmetic timing")
	for hz in [30, 60, 144]:
		fx.clear()
		var held := 0.0
		var total := 2.0
		var frames := int(total * hz)
		for frame in frames:
			# More frequent than the refractory period: no per-input stacking.
			if frame % maxi(1, int(hz / 15)) == 0:
				fx.add("defeat", Vector2.ZERO, Vector2.RIGHT)
			var frame_result: Dictionary = fx.advance(1.0 / float(hz))
			held += float(frame_result.held)
		_expect(held > 0.0 and held < total * 0.55, "sustained rapid contacts keep progressing at %d Hz" % hz)
		_expect(fx.effects.size() <= Impact.MAX_EFFECTS, "effect budget remains bounded at %d Hz" % hz)


func _test_wall_and_cues() -> void:
	_reset_arena()
	game.grid[7][10] = game.TILE_WALL
	game.breach_charges = 1
	game.floor_number = 7 # glass biome
	var before_rng: int = game.rng.state
	game.try_break_wall()
	_expect(game.grid[7][10] == game.TILE_FLOOR and game.breach_charges == 0 and game.turn_number == 1, "wall opens and charge/turn resolve at input")
	_expect(events.count("DEMOLITION") == 1 and events.count("TURN_COMMITTED") == 1, "demolition and turn facts are immediate and unique")
	_expect(not cues.has("break_glass") and game.impact_presentation.effects.size() == 1, "glass cue waits for the drawn contact")
	_expect(str(game.impact_presentation.effects[0].material) == "glass", "wall impact uses the existing biome material")
	_expect(game.shake_time == 0.0, "camera does not shake before the physical contact")
	game._process(0.07)
	_expect(cues.count("break_glass") == 1 and events.count("DEMOLITION") == 1, "contact plays exactly one material cue without duplicating the event")
	_expect(cues.count("break_wall") == 1, "new material sound is layered with the prior impact body at contact")
	_expect(game.shake_time > 0.0 and game.shake_strength >= 6.0, "wall contact retains a camera response without shaking before contact")
	_expect(game.impact_presentation.hold_remaining > 0.0 and game.rng.state == before_rng, "impact is presentation only and does not consume AI RNG")
	# A fresh directional input during the hold commits immediately.
	game.try_move(1, 0)
	_expect(game.player_position == Vector2i(10, 7) and game.turn_number == 2, "input and collision are not blocked by hitstop")
	var frozen: Vector2 = game._player_visual_position()
	game._process(0.02)
	_expect(game._player_visual_position().is_equal_approx(frozen) and game.player_position == Vector2i(10, 7), "only the interpolated pose pauses")
	game._process(0.6)
	_expect(game._player_visual_position().is_equal_approx(game._cell_center(game.player_position)) and game.turn_number == 2, "visual path recovers at the true cell without another turn")

	for pair in [[1, "stone"], [7, "glass"], [13, "metal"], [19, "ice"], [25, "energy"]]:
		game.floor_number = int(pair[0])
		_expect(game._wall_impact_material() == str(pair[1]), "biome maps to " + str(pair[1]))


func _test_death_and_recoil() -> void:
	_reset_arena()
	game.breach_charges = 1
	var enemy: Dictionary = game._make_enemy(Vector2i(10, 7), "rusher")
	game.enemies.append(enemy)
	game.try_break_wall()
	_expect(game.enemies.is_empty() and game.breach_charges == 0 and game.turn_number == 1, "defeat and resource cost are immediate")
	_expect(game.enemy_defeat_visuals.size() == 1 and game.enemy_defeat_visuals[0].role == "rusher", "non-interactive ghost preserves enemy identity")
	_expect(events.count("DEMOLITION") == 1 and not cues.has("enemy_crush"), "defeat emits one event before its contact cue")
	game._process(0.07)
	_expect(cues.count("enemy_crush") == 1 and game.impact_presentation.hold_remaining > 0.0, "defeat sound and selective hold occur at contact")
	game._process(0.7)
	_expect(game.enemy_defeat_visuals.is_empty() and game.impact_presentation.effects.is_empty(), "defeat and particles recover within a bounded lifetime")

	_reset_arena()
	game.charges = 1
	enemy = game._make_enemy(Vector2i(10, 7), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	game.try_move(1, 0)
	_expect(game.charges == 0 and game.enemies[0].pos == Vector2i(12, 7) and game.turn_number == 1, "shield resolves its original two-cell recoil immediately")
	_expect(events.count("SHIELD_IMPACT") == 1 and not cues.has("shield_contact"), "shield semantic event is immediate but cue waits")
	game._process(0.07)
	_expect(game.impact_feedback_time == 0.0 and is_equal_approx(float(game.enemies[0].t), 0.0), "shielded enemy waits visually for contact")
	game._process(0.07)
	_expect(game.player_impact_kind == "shield" and cues.count("shield_contact") == 1, "shield has a distinct contact reaction and cue")
	_expect(cues.count("hit") == 1 and events.count("SHIELD_IMPACT") == 1, "shield layers the previous hit body without duplicating the event")
	var raw_contact: Vector2 = game._enemy_visual_position(game.enemies[0])
	var drawn_contact: Vector2 = game._enemy_contact_draw_position(game.enemies[0])
	_expect(raw_contact.distance_to(game._player_visual_position()) < 1.0 and drawn_contact.distance_to(game._player_visual_position()) >= 30.0, "drawn shield contact keeps both bodies visible without altering the resolved centers")
	game._process(0.5)
	_expect(game._enemy_visual_position(game.enemies[0]).is_equal_approx(game._cell_center(game.enemies[0].pos)), "shield recoil settles on the actual cell")
	_expect(game._enemy_contact_draw_position(game.enemies[0]).is_equal_approx(game._enemy_visual_position(game.enemies[0])), "art-space separation vanishes when recoil has settled")

	_reset_arena()
	game.charges = 1
	enemy = game._make_enemy(Vector2i(10, 7), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	var enemy_origin: Vector2 = game._cell_center(Vector2i(10, 7))
	game.wait_turn()
	_expect(game.enemies[0].pos == Vector2i(11, 7) and game.turn_number == 1, "incoming enemy shield recoil is resolved immediately")
	_expect(game._enemy_visual_position(game.enemies[0]).is_equal_approx(enemy_origin), "incoming enemy starts from its real visible origin rather than teleporting to contact")
	game._process(0.07)
	var approaching: Vector2 = game._enemy_visual_position(game.enemies[0])
	_expect(approaching.x < enemy_origin.x and approaching.x > game._cell_center(Vector2i(9, 7)).x and not cues.has("shield_contact"), "incoming enemy visibly approaches before shield contact")
	game._process(0.07)
	_expect(cues.count("shield_contact") == 1 and game.player_impact_kind == "shield", "incoming contact and cue coincide after the committed approach")
	_expect(game._enemy_contact_draw_position(game.enemies[0]).distance_to(game._player_visual_position()) >= 30.0, "incoming shield contact retains a visible enemy silhouette")
	game._process(0.5)
	_expect(game._enemy_visual_position(game.enemies[0]).is_equal_approx(game._cell_center(game.enemies[0].pos)), "incoming attacker completes its recoil without another turn")

	_reset_arena()
	game.skills.points = 5
	game.skills.unlock("heart_1")
	game.skills.toggle("heart_1")
	game.hearts_current = 1
	enemy = game._make_enemy(Vector2i(10, 7), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	game.wait_turn()
	var collision_cell: Vector2 = game._cell_center(Vector2i(9, 7))
	_expect(game.hearts_current == 0 and game.player_position == Vector2i(8, 7), "incoming damage and logical heart recoil resolve immediately")
	game._process(0.07)
	_expect(game._player_visual_position().is_equal_approx(collision_cell) and not cues.has("heart_lost"), "heart recoil waits visibly while the enemy approaches")
	game._process(0.07)
	_expect(game._player_visual_position().is_equal_approx(collision_cell) and cues.count("heart_lost") == 1, "heart recoil starts only after the actual contact")
	game._process(0.4)
	_expect(game._player_visual_position().is_equal_approx(game._cell_center(game.player_position)), "heart recoil finishes at the resolved cell")

	_reset_arena()
	game.skills.points = 5
	var unlocked: Dictionary = game.skills.unlock("heart_1")
	var enabled: Dictionary = game.skills.toggle("heart_1")
	_expect(unlocked.ok and enabled.ok, "heart fixture can be equipped")
	game.hearts_current = 1
	game.heart_pickups.append(Vector2i(8, 7))
	var result: String = game._apply_damage("TESTE", Color.RED, Vector2i.LEFT)
	_expect(result == "heart" and game.player_position == Vector2i(8, 7) and game.hearts_current == 1 and game.turn_number == 0, "heart recoil and recovery resolve without an extra turn")
	_expect(events == ["HEART_LOST", "HEART_RECOVERED"] and cues.is_empty(), "loss and recovery events retain their synchronous order")
	game._process(0.001)
	_expect(cues == ["heart_lost"], "loss cue is played once at contact")
	game._process(0.20)
	_expect(cues == ["heart_lost", "heart_recovered"], "recovery cue follows at the recoil landing")


func _test_pause_transition_and_capture() -> void:
	_reset_arena()
	game.grid[7][10] = game.TILE_WALL
	game.breach_charges = 1
	game.try_break_wall()
	game.game_state = "paused"
	game.try_move(0, 1)
	game._process(0.3)
	game.game_state = "playing"
	game._process(0.3)
	_expect(game.turn_number == 1 and game.player_position == Vector2i(9, 7), "pause never buffers input or changes resolved turns")
	_expect(game.impact_presentation.effects.is_empty() and cues.count("break_wall") == 1, "pause flushes the pending cue once and never replays it after resume")

	_reset_arena()
	game.grid[7][10] = game.TILE_WALL
	game.breach_charges = 1
	game.try_break_wall()
	game.generate_floor(2)
	_expect(game.impact_presentation.effects.is_empty() and is_zero_approx(float(game.impact_presentation.hold_remaining)), "floor change clears pending contacts and hold")
	_expect(cues.count("break_wall") == 1, "floor change flushes rather than drops the pending cue")
	game._process(0.4)
	_expect(cues.count("break_wall") == 1, "floor change never replays an old cue")

	_reset_arena()
	game.traps.append({"pos": Vector2i(10, 7), "armed": true, "revealed": true})
	game.try_move(1, 0)
	_expect(game.game_state == "captured" and game.turn_number == 1 and events.count("CAPTURE_START") == 1, "fatal state and capture event remain immediate")
	_expect(not cues.has("inflate"), "capture audio waits for its contact")
	game.try_move(0, 1)
	game._process(0.14)
	_expect(game.player_position == Vector2i(10, 7) and cues.count("inflate") == 1, "capture cue occurs once at the resolved cell; input stays locked")
	game._process(2.0)
	_expect(game.game_state == "game_over", "visual hitstop never delays capture's real-time transition")


func _test_visual_rng_and_budget() -> void:
	_reset_arena()
	var state: int = game.rng.state
	game._spawn_burst(game._cell_center(game.player_position), Color.RED, 20, 100.0)
	game._trigger_shake(0.2, 4.0)
	game._process(0.03)
	_expect(game.rng.state == state, "particles and camera shake use visual RNG, not AI/generation RNG")
	for _i in 100:
		game._queue_contact_feedback("BLOCKED", "block", Vector2.ZERO, Vector2.RIGHT, 0.2)
	_expect(game.impact_presentation.effects.size() == Impact.MAX_EFFECTS, "game caps pending impacts under extreme input")
	_expect(events.count("BLOCKED") == 100 and cues.count("blocked") == 100 - Impact.MAX_EFFECTS, "overflow preserves every fact and plays evicted cues exactly once")
	game._process(0.21)
	_expect(cues.count("blocked") == 100, "remaining capped contacts eventually play once")
	game._process(0.5)
	_expect(cues.count("blocked") == 100 and events.count("BLOCKED") == 100, "no queued sound or event is replayed")


func _snapshot_rules() -> Dictionary:
	var actors: Array[Dictionary] = []
	for enemy in game.enemies:
		actors.append({"pos": enemy.pos, "next": enemy.next, "role": enemy.get("role", ""), "hp": enemy.get("hp", -1), "path": enemy.get("path", []).duplicate()})
	var semantic: Array[String] = []
	for event in events:
		# These two are real-time accessibility reminders, not turn outcomes.
		if event not in ["ENEMY_NEAR", "NEAR_MISS"]:
			semantic.append(event)
	return {"state": game.game_state, "turn": game.turn_number, "player": game.player_position, "facing": game.facing,
		"charges": game.charges, "breach": game.breach_charges, "hearts": game.hearts_current,
		"hits": game.hits_this_floor, "grid": game.grid.duplicate(true), "crates": game.environment.crates.duplicate(true),
		"enemies": actors, "rng": game.rng.state, "events": semantic}


func _sample_frames(hz: float) -> void:
	if hz <= 0.0:
		return
	for _frame in int(ceil(hz * 0.22)):
		game._process(1.0 / hz)


func _sample_rule_scenarios(hz: float) -> Array:
	var trace: Array = []
	_reset_arena()
	game.grid[7][10] = game.TILE_WALL
	game.breach_charges = 1
	game.environment.reset({"crates": [{"pos": Vector2i(11, 7), "material": "wood"}]})
	game.try_break_wall()
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(1, 0)
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(1, 0)
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(0, 1)
	trace.append(_snapshot_rules())
	_sample_frames(hz)

	_reset_arena()
	game.charges = 1
	var enemy: Dictionary = game._make_enemy(Vector2i(10, 7), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	game.try_move(1, 0)
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(0, 1)
	trace.append(_snapshot_rules())
	_sample_frames(hz)

	_reset_arena()
	game.skills.points = 2
	game.skills.unlock("heart_1")
	game.skills.toggle("heart_1")
	game.hearts_current = 1
	enemy = game._make_enemy(Vector2i(10, 7), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	game.wait_turn()
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(0, 1)
	trace.append(_snapshot_rules())
	_sample_frames(hz)

	_reset_arena()
	game.grid[7][10] = game.TILE_WATER
	game.environment.reset({"cells": {Vector2i(10, 7): {"kind": "water", "source": true}}})
	game.charges = 1
	game.try_move(1, 0)
	trace.append(_snapshot_rules())
	_sample_frames(hz)
	game.try_move(0, 1)
	trace.append(_snapshot_rules())
	return trace


func _test_contact_visibility() -> void:
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_reset_arena()
		game.charges = 1
		var start: Vector2i = game.player_position
		var target: Vector2i = start + direction
		var enemy: Dictionary = game._make_enemy(target, "hunter")
		enemy.next = target
		game.enemies.append(enemy)
		game.try_move(direction.x, direction.y)
		var original: Vector2 = game._cell_center(target)
		_expect(game._enemy_contact_draw_position(game.enemies[0]).is_equal_approx(original), "no invented enemy displacement before " + str(direction) + " contact")
		game._process(0.14)
		var apart: Vector2 = game._enemy_contact_draw_position(game.enemies[0]) - game._player_visual_position()
		_expect(apart.dot(Vector2(direction)) >= 29.9, "visible shield contact separates bodies in direction " + str(direction))
		_expect(game.enemies[0].pos == target + direction * 2 and game.turn_number == 1, "visible separation preserves actual recoil and turn for " + str(direction))

	_reset_arena()
	game.charges = 1
	var target: Vector2i = game.player_position + Vector2i.RIGHT
	game.grid[target.y][target.x + 1] = game.TILE_WALL
	var enemy: Dictionary = game._make_enemy(target, "hunter")
	enemy.next = target
	game.enemies.append(enemy)
	game.try_move(1, 0)
	game._process(0.14)
	var apart: Vector2 = game._enemy_contact_draw_position(game.enemies[0]) - game._player_visual_position()
	_expect(absf(apart.x) < 1.0 and absf(apart.y) >= 29.9, "when forward recoil is blocked, art separation follows the legal side instead of entering the wall")

	for role in ["warden", "knight"]:
		_reset_arena()
		game.charges = 1
		game.floor_number = 15
		var elite: Dictionary = game._make_warden(Vector2i(10, 7)) if role == "warden" else game._make_boss(Vector2i(11, 8))
		elite.next = game.player_position
		var initial_hp: int = elite.hp
		game.enemies.append(elite)
		game.wait_turn()
		game._process(0.22)
		var elite_gap: float = game._enemy_contact_draw_position(game.enemies[0]).distance_to(game._player_visual_position())
		_expect(elite_gap >= 33.0, role + " stays visible beside the shield contact")
		_expect(game.enemies[0].hp == initial_hp - 1 and game.charges == 0 and game.turn_number == 1, role + " keeps the original counter, HP and turn")
		game._process(0.5)
		_expect(game._enemy_contact_draw_position(game.enemies[0]).is_equal_approx(game._enemy_visual_position(game.enemies[0])), role + " finishes on its original logical recoil")

	_reset_arena()
	game.charges = 1
	enemy = game._make_enemy(game.player_position, "hunter")
	game.enemies.append(enemy)
	for direction in game.FOUR_WAY:
		var blocked: Vector2i = game.player_position + direction
		game.grid[blocked.y][blocked.x] = game.TILE_WALL
	game._check_enemy_collision()
	_expect(game.enemies[0].pos == game.player_position and not game.enemies[0].shield_repel_visual, "fully boxed contact keeps its existing no-space rule")
	_expect(game._enemy_contact_draw_position(game.enemies[0]).is_equal_approx(game._enemy_visual_position(game.enemies[0])), "fully boxed contact does not invent a visual escape through walls")
	game.damage_this_turn = false
	game._check_enemy_collision()
	_expect(events.count("SHIELD_IMPACT") == 1 and game.game_state == "playing", "unresolved boxed contact does not apply a second collision")


func _test_camera_scope() -> void:
	_reset_arena()
	var distant := {"event": "", "kind": "defeat", "point": Vector2(50000, 50000), "direction": Vector2.RIGHT, "context": {"affects_player": false}}
	game._on_presentation_contact(distant)
	_expect(game.shake_time == 0.0 and game.flash_time == 0.0, "offscreen distant defeat does not shake or flash the player")
	var local := {"event": "", "kind": "wall", "point": game._cell_center(Vector2i(10, 7)), "direction": Vector2.RIGHT, "context": {"affects_player": false}}
	game._on_presentation_contact(local)
	_expect(game.shake_time > 0.0 and is_equal_approx(game.shake_strength, 6.0), "near-player wall contact works even before camera transform settles")
	game._process(0.3)
	game._trigger_shake(0.09, 1.8)
	_expect(is_equal_approx(game.shake_strength, 1.8), "a later light impact does not inherit an expired heavy shake")


func _test_frame_invariance() -> void:
	var immediate := _sample_rule_scenarios(0.0)
	for hz in [30.0, 60.0, 144.0]:
		_expect(_sample_rule_scenarios(hz) == immediate, "same rule/RNG/event trace with no presentation frames and at %d Hz" % hz)


func _run() -> void:
	_test_clock()
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.feedback_bus.event_emitted.connect(_on_event)
	game.audio.cue_played.connect(_on_cue)
	_test_wall_and_cues()
	_test_death_and_recoil()
	_test_pause_transition_and_capture()
	_test_visual_rng_and_budget()
	_test_contact_visibility()
	_test_camera_scope()
	_test_frame_invariance()
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_FEEL_TEST_PASS checks=", checks, " visual-only hitstop, cue ordering, collisions, defeat, pause, transitions, RNG and stress")
		quit(0)
	else:
		printerr("COMBAT_FEEL_TEST_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
