extends SceneTree

const Game = preload("res://game.gd")
const Motion = preload("res://visual_motion.gd")

var game: Node
var failures: Array[String] = []
var checks := 0
var events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _on_event(event: String, _context: Dictionary) -> void:
	events.append(event)


func _reset_arena() -> void:
	game.dev_load_sandbox_arena()
	game.enemies.clear()
	game.coins.clear()
	game.shields.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.switches.clear()
	game.traps.clear()
	game.environment.reset()
	game.portal_position = Vector2i(16, 12)
	game.player_position = Vector2i(9, 7)
	game._reset_player_visual(game._cell_center(game.player_position))
	game._reset_capture_state()
	game.turn_number = 0
	game.moves_this_floor = 0
	game.hits_this_floor = 0
	game.charges = 0
	game.breach_charges = 0
	game.blink_charges = 0
	game.freeze_turns = 0
	game.speed_turns = 0
	game.game_state = "playing"
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.rng.seed = 981
	events.clear()


func _near(a: Vector2, b: Vector2, tolerance: float = 0.02) -> bool:
	return a.distance_to(b) <= tolerance


func _test_directions() -> void:
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_reset_arena()
		var origin: Vector2i = game.player_position
		var center: Vector2 = game._cell_center(origin)
		game.try_move(direction.x, direction.y)
		_expect(game.player_position == origin + direction and game.turn_number == 1, "direction resolves exactly one cell and turn: %s" % direction)
		_expect(events == ["MOVE", "TURN_COMMITTED"], "direction emits events once and in order: %s" % direction)
		_expect(_near(game._player_visual_position(), center), "first visual frame starts at origin: %s" % direction)
		game._process(1.0 / 60.0)
		var offset: Vector2 = game._player_visual_position() - center
		_expect(offset.dot(Vector2(direction)) > 0.5, "visible response starts on first 60Hz frame: %s" % direction)
		_expect(absf(offset.cross(Vector2(direction))) < 0.01, "visual movement follows cardinal axis: %s" % direction)
		var signed_roll := wrapf(float(game.player_roll_angle), -PI, PI)
		var expected_sign: int = direction.x + direction.y
		_expect(signed_roll * expected_sign > 0.0, "rolling reverses for opposite directions: %s" % direction)
		game._process(0.25)
		_expect(_near(game._player_visual_position(), game._cell_center(origin + direction)) and not game.player_motion.is_active(), "single step reaches its logical destination: %s" % direction)
		_expect(game.turn_number == 1 and game.landing_feedback_time > 0.0, "landing is visual, not another action")


func _test_corner_and_reversal() -> void:
	_reset_arena()
	var origin: Vector2 = game._cell_center(Vector2i(9, 7))
	var corner: Vector2 = game._cell_center(Vector2i(10, 7))
	var end: Vector2 = game._cell_center(Vector2i(10, 8))
	game.grid[8][9] = game.TILE_WALL
	game.try_move(1, 0)
	game._process(0.04)
	var before: Vector2 = game._player_visual_position()
	game.try_move(0, 1)
	_expect(_near(before, game._player_visual_position()), "turn input does not teleport the current visible pose")
	_expect(game.player_position == Vector2i(10, 8) and game.turn_number == 2, "corner consumes two immediate logical turns")
	_expect(_near(game.player_motion.to, corner) and game.player_motion.pending.size() == 1, "corner retains its actual first waypoint")
	var crossed_corner := false
	for _frame in 40:
		game._process(0.01)
		var point: Vector2 = game._player_visual_position()
		if point.y > origin.y + 0.05:
			_expect(absf(point.x - corner.x) < 0.05, "corner never cuts through adjacent blocked cell")
			crossed_corner = true
	_expect(crossed_corner and _near(game._player_visual_position(), end), "corner reaches the final cell within bounded time")
	_expect(events == ["MOVE", "TURN_COMMITTED", "MOVE", "TURN_COMMITTED"], "corner never duplicates or delays events")

	_reset_arena()
	game.try_move(1, 0)
	game._process(0.04)
	game.try_move(-1, 0)
	var reached_first := false
	for _frame in 40:
		game._process(0.01)
		if game._player_visual_position().x >= corner.x - 0.05:
			reached_first = true
	_expect(reached_first and _near(game._player_visual_position(), origin), "reversal shows the first resolved cell before returning")
	_expect(game.turn_number == 2 and game.player_position == Vector2i(9, 7), "visual reversal never changes logical turns")


func _test_fast_overflow() -> void:
	_reset_arena()
	var previous_overflows: int = game.player_motion.overflow_count
	for i in 20:
		game.try_move(1 if i % 2 == 0 else -1, 0)
		_expect(game.player_motion.pending.size() <= Motion.MAX_SEGMENTS - 1, "visual queue stays bounded under input stress")
	_expect(game.turn_number == 20 and game.player_position == Vector2i(9, 7), "all synthetic inputs resolve without loss or duplication")
	_expect(events.count("MOVE") == 20 and events.count("TURN_COMMITTED") == 20, "overflow does not replay or suppress events")
	_expect(game.player_motion.overflow_count > previous_overflows, "overflow takes the documented last-origin fallback")
	game._process(1.0)
	_expect(_near(game._player_visual_position(), game._cell_center(game.player_position)) and not game.player_motion.is_active(), "long frame converges to resolved state")


func _test_ice_water_and_crates() -> void:
	_reset_arena()
	var entry := Vector2i(10, 7)
	var end := Vector2i(11, 7)
	game.grid[entry.y][entry.x] = game.TILE_WATER
	game.environment.reset({"cells": {entry: {"kind": "ice"}}})
	game.try_move(1, 0)
	_expect(game.player_position == end and game.turn_number == 1, "ice still moves an extra cell in the same turn")
	_expect(_near(game.player_motion.to, game._cell_center(entry)) and game.player_motion.pending.size() == 1, "ice preserves entry and slide segments")
	_expect(game.player_motion.pending[0].kind == "ice", "forced slide has its own presentation type")
	_expect(_near(game.turn_pulse_position, game._cell_center(end)) and game.turn_pulse_pending, "existing turn ring points to ice's final cell")
	game._process(0.13)
	var ice_visual: Vector2 = game._player_visual_position()
	_expect(ice_visual.x > game._cell_center(entry).x and ice_visual.x < game._cell_center(end).x, "ice continues visibly after entering the first cell")
	_expect(game.turn_pulse_time < 0.0 and game.surface_reactions.size() >= 1, "ice contact occurs before the final landing ring")
	game._process(0.12)
	_expect(_near(game._player_visual_position(), game._cell_center(end)) and game.turn_pulse_time == 0.0, "ice converges and releases the ring after landing")

	_reset_arena()
	game.grid[entry.y][entry.x] = game.TILE_WATER
	game.grid[end.y][end.x] = game.TILE_WATER
	game.environment.reset({"cells": {entry: {"kind": "current", "flow": Vector2i.RIGHT}, end: {"kind": "water"}}})
	game.try_move(1, 0)
	_expect(game.player_position == end and game.turn_number == 1 and game.player_motion.pending[0].kind == "current", "current remains one action with visible drift")
	game._process(0.13)
	_expect(game.surface_reactions.size() >= 1 and game.surface_reactions[0].material == "water", "water ripple starts when the visual body arrives")
	game._process(0.12)
	_expect(_near(game._player_visual_position(), game._cell_center(end)) and game.surface_reactions.size() >= 2, "current landing creates a second bounded water reaction")

	game.start_environment_lab()
	game.audio.effects_enabled = false
	game.set_process(false)
	events.clear()
	var crate_before: Vector2 = game._cell_center(Vector2i(3, 4))
	game.try_move(1, 0)
	_expect(game.environment.crates[0].pos == Vector2i(5, 4) and game.player_position == Vector2i(3, 4) and game.turn_number == 1, "wood push plus current retains the original immediate rules")
	_expect(_near(game._crate_visual_position(0, game.environment.crates[0]), crate_before), "crate no longer jumps instantly to the final current cell")
	_expect(game.crate_visual_tracks[0].pending.size() == 1, "crate presentation includes push and current")
	game._process(0.13)
	var crate_mid: Vector2 = game._crate_visual_position(0, game.environment.crates[0])
	_expect(crate_mid.x > game._cell_center(Vector2i(4, 4)).x and crate_mid.x < game._cell_center(Vector2i(5, 4)).x, "floating crate visibly continues after the push")
	game._process(0.12)
	_expect(_near(game._crate_visual_position(0, game.environment.crates[0]), game._cell_center(Vector2i(5, 4))) and game.crate_visual_tracks.is_empty(), "crate track finishes and is released")
	_expect(game.portal_open and game.environment.active_plate_count() == 1, "animation does not defer the plate or portal rule")


func _test_push_weight_and_blocking() -> void:
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_reset_arena()
		var origin: Vector2i = game.player_position
		var box: Vector2i = origin + direction
		game.environment.reset({"crates": [{"pos": box, "material": "wood"}]})
		game.try_move(direction.x, direction.y)
		_expect(game.turn_number == 1 and game.player_position == box and game.environment.crates[0].pos == box + direction, "pushing resolves exactly once in " + str(direction))
		_expect(events.count("MOVE") == 1 and events.count("CRATE_PUSH_WOOD") == 1 and events.count("TURN_COMMITTED") == 1, "push events are singular")
		_expect(game.player_motion.kind == "push" and game.crate_visual_tracks[0].kind == "push", "player and box share the push motion")
		for _frame in 6:
			game._process(0.02)
			var spacing: Vector2 = game._crate_visual_position(0, game.environment.crates[0]) - game._player_visual_position()
			_expect(_near(spacing, Vector2(direction) * game.CELL, 0.06), "push presentation preserves contact spacing")
		game._process(0.2)
		_expect(game.turn_number == 1 and not game.player_motion.is_active(), "push recovery never consumes a second turn")

	_reset_arena()
	game.environment.reset({"crates": [{"pos": Vector2i(12, 7), "material": "wood"}]})
	game.try_move(1, 0)
	game.try_move(1, 0)
	game.try_move(1, 0)
	_expect(game.turn_number == 3 and game.player_position == Vector2i(12, 7) and game.environment.crates[0].pos == Vector2i(13, 7), "rapid approach and push resolve without waiting for animation")
	_expect(game.crate_visual_tracks[0].kind == "hold", "the box waits visually for the already-committed approach")
	var prior: Vector2 = game._crate_visual_position(0, game.environment.crates[0])
	game._process(0.04)
	_expect(_near(game._crate_visual_position(0, game.environment.crates[0]), prior), "box does not depart before visible contact")
	game._process(0.4)
	_expect(_near(game._crate_visual_position(0, game.environment.crates[0]), game._cell_center(Vector2i(13, 7))) and game.crate_visual_tracks.is_empty(), "rapid push settles without replaying a turn")

	_reset_arena()
	game.environment.reset({"crates": [{"pos": Vector2i(10, 7), "material": "metal"}]})
	game.grid[7][11] = game.TILE_WALL
	game.try_move(1, 0)
	_expect(game.turn_number == 0 and game.player_position == Vector2i(9, 7) and game.environment.crates[0].pos == Vector2i(10, 7), "blocked box changes neither turns nor positions")
	_expect(game.blocked_crate_index == 0 and game.blocked_crate_time > 0.0 and events == ["BLOCKED"], "blocked box receives a matching brief response without invented motion")
	game._process(0.3)
	_expect(game.blocked_crate_time == 0.0, "blocked box settles")


func _test_block_pause_jump_blink_capture_reset() -> void:
	_reset_arena()
	game.grid[7][10] = game.TILE_WALL
	game.try_move(1, 0)
	_expect(game.turn_number == 0 and game.player_position == Vector2i(9, 7) and events == ["BLOCKED"], "blocked action stays put, emits one event and costs no turn")
	_expect(game.blocked_feedback_time > 0.0 and not game.blocked_feedback_pending, "blocked action has a short visual reaction")
	game._process(0.08)
	_expect(game.blocked_feedback_time > 0.0 and game.turn_number == 0, "blocked response is presentation only")
	game._process(0.20)
	_expect(game.blocked_feedback_time == 0.0, "blocked reaction recovers")

	_reset_arena()
	game.grid[7][11] = game.TILE_WALL
	game.try_move(1, 0)
	game.try_move(1, 0)
	_expect(game.blocked_feedback_pending and game.blocked_feedback_time == 0.0 and game.turn_number == 1, "blocked bump waits visually for the previous step without adding a turn")
	game._process(0.15)
	_expect(not game.blocked_feedback_pending and game.blocked_feedback_time > 0.0 and _near(game._player_visual_position(), game._cell_center(Vector2i(10, 7))), "bump starts at the resolved obstacle contact")

	_reset_arena()
	game.try_move(1, 0)
	game.game_state = "paused"
	game.try_move(0, 1)
	game._process(0.3)
	_expect(game.player_position == Vector2i(10, 7) and game.turn_number == 1 and _near(game._player_visual_position(), game._cell_center(game.player_position)), "pause rejects input and preserves existing visual completion policy")
	game.game_state = "playing"
	game.try_move(0, 1)
	_expect(game.player_position == Vector2i(10, 8) and game.turn_number == 2, "resume does not replay a buffered command")

	_reset_arena()
	game.charges = 1
	game.facing = Vector2i.RIGHT
	game.try_jump()
	_expect(game.player_position == Vector2i(11, 7) and game.charges == 0 and game.turn_number == 1 and game.player_motion.kind == "jump", "jump retains cost/distance and gets its own arc")
	game._process(0.30)
	_expect(_near(game._player_visual_position(), game._cell_center(game.player_position)), "jump lands at its real cell")

	_reset_arena()
	game.try_move(1, 0)
	game.try_move(0, 1)
	game.blink_charges = 1
	game.facing = Vector2i.RIGHT
	game.try_blink()
	_expect(game.player_position == Vector2i(13, 8) and game.blink_charges == 0 and game.turn_number == 3, "Blink keeps its logical landing and turn during an existing path")
	_expect(not game.player_motion.is_active() and game.player_motion.pending.is_empty() and _near(game._player_visual_position(), game._cell_center(game.player_position)), "Blink cancels stale visual path and never slides through cells")

	_reset_arena()
	game.traps.append({"pos": Vector2i(10, 7), "armed": true, "revealed": true})
	game.try_move(1, 0)
	_expect(game.game_state == "captured" and game.turn_number == 1 and game.player_position == Vector2i(10, 7), "fatal contact and input lock stay immediate")
	_expect(_near(game.capture_origin, game._cell_center(Vector2i(10, 7))) and game.player_motion.is_active(), "capture presents the actual contact cell without teleporting the previous pose")
	game.try_move(1, 0)
	game._process(0.2)
	_expect(game.player_position == Vector2i(10, 7) and _near(game._player_visual_position(), game.capture_origin), "captured ball arrives at the fatal cell, no further input")
	game._update_capture_sequence(game.CAPTURE_END_TIME)
	_expect(game.game_state == "game_over", "capture sequence still ends normally")

	game.start_environment_lab()
	game.try_move(1, 0)
	game.restart_floor()
	_expect(game.turn_number == 0 and not game.player_motion.is_active() and game.player_motion.pending.is_empty(), "restart clears player visual path")
	_expect(game.crate_visual_tracks.is_empty() and game.surface_reactions.is_empty() and game.enemy_defeat_visuals.is_empty(), "restart clears transient entity and surface visuals")


func _test_entities_and_combat() -> void:
	_reset_arena()
	var enemy: Dictionary = game._make_enemy(Vector2i(4, 4), "hunter")
	enemy.next = Vector2i(5, 4)
	game.enemies.append(enemy)
	game.wait_turn()
	_expect(game.enemies[0].pos == Vector2i(5, 4) and _near(game._enemy_visual_position(game.enemies[0]), game._cell_center(Vector2i(4, 4))), "enemy rule moves immediately while its presentation starts at origin")
	game._process(0.04)
	var before: Vector2 = game._enemy_visual_position(game.enemies[0])
	game.enemies[0].next = Vector2i(5, 5)
	game.wait_turn()
	var track = game.enemies[0].get("_visual_motion")
	_expect(_near(before, game._enemy_visual_position(game.enemies[0])) and track.pending.size() == 1, "rapid enemy turn keeps its current pose and logical waypoint")
	_expect(game.enemies[0].from == game._cell_center(Vector2i(5, 4)) and game.enemies[0].pos == Vector2i(5, 5), "enemy logical origin remains available for shield collision")
	game._process(0.30)
	_expect(_near(game._enemy_visual_position(game.enemies[0]), game._cell_center(Vector2i(5, 5))) and game.turn_number == 2, "enemy visual path finishes without new turns")

	_reset_arena()
	game.player_position = Vector2i(4, 4)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.facing = Vector2i.RIGHT
	game.breach_charges = 1
	enemy = game._make_enemy(Vector2i(5, 4), "hunter")
	game.enemies.append(enemy)
	game.try_break_wall()
	_expect(game.enemies.is_empty() and game.breach_charges == 0 and game.turn_number == 1, "demolition removes enemy and spends its original charge/turn immediately")
	_expect(game.enemy_defeat_visuals.size() == 1 and game.attack_feedback_time > 0.0, "demolition leaves a short non-interactive defeat and player reaction")
	_expect(events == ["DEMOLITION", "TURN_COMMITTED"], "combat event order is unchanged")
	game._process(0.31)
	_expect(game.enemy_defeat_visuals.size() == 1, "defeat remains visible briefly after the already-resolved hit")
	game._process(0.35)
	_expect(game.enemy_defeat_visuals.is_empty() and game.attack_feedback_time == 0.0, "combat presentation has a bounded lifetime")

	_reset_arena()
	game.environment.reset({"cells": {Vector2i(4, 4): {"kind": "water", "source": true}}})
	enemy = game._make_enemy(Vector2i(4, 4), "hunter")
	game.enemies.append(enemy)
	game._resolve_electrified_enemies()
	_expect(game.enemies.is_empty() and game.enemy_defeat_visuals.size() == 1 and game.enemy_defeat_visuals[0].material == "electricity", "electric water immediately resolves enemy but retains a short visual response")

	_reset_arena()
	game.player_position = Vector2i(4, 4)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.charges = 1
	enemy = game._make_enemy(Vector2i(5, 4), "hunter")
	enemy.next = game.player_position
	game.enemies.append(enemy)
	game.try_move(1, 0)
	_expect(game.charges == 0 and game.enemies[0].pos == Vector2i(7, 4) and game.impact_feedback_time == 0.0, "shield contact repels immediately; its body reaction waits for visible contact")
	_expect(not game.enemies[0].has("_visual_motion") and game.enemies[0].from == game._cell_center(Vector2i(5, 4)), "shield contact supersedes old enemy presentation without changing recoil rules")
	game._process(0.14)
	_expect(game.impact_feedback_time > 0.0 and game.impact_presentation.hold_remaining > 0.0, "shield body reaction and visual-only hold begin on contact")


func _test_enemy_pose_and_knight() -> void:
	_reset_arena()
	var origin := Vector2i(4, 4)
	var enemy: Dictionary = game._make_enemy(origin, "hunter")
	var center: Vector2 = game._cell_center(origin)
	game._queue_enemy_visual(enemy, origin, origin + Vector2i.RIGHT)
	var track = enemy["_visual_motion"]
	track.advance(0.07)
	var pose: Transform2D = game._enemy_pose_transform(enemy, center, 1.0, 0.0)
	enemy.next = Vector2i(12, 10)
	enemy.path = [Vector2i(10, 10), Vector2i(12, 10)]
	var changed_intent_pose: Transform2D = game._enemy_pose_transform(enemy, center, 1.0, 0.0)
	_expect(pose.is_equal_approx(changed_intent_pose), "body pose depends on resolved visual motion, not future next/path")
	var resting_pose: Transform2D = game._enemy_pose_transform(enemy, center, 0.0, 0.0)
	_expect(not pose.is_equal_approx(resting_pose), "body deforms while the actual segment is in progress")
	var enemy_before: Vector2 = game._enemy_visual_position(enemy)
	var rng_before: int = game.rng.state
	game._enemy_pose_transform(enemy, center, 1.0, 0.0)
	_expect(_near(game._enemy_visual_position(enemy), enemy_before) and game.rng.state == rng_before, "procedural enemy pose changes neither resolved position nor gameplay RNG")
	var rusher: Dictionary = enemy.duplicate()
	rusher.role = "rusher"
	var sentry: Dictionary = enemy.duplicate()
	sentry.role = "sentry"
	var agile_pose: Transform2D = game._enemy_pose_transform(rusher, center, 1.0, 0.0)
	var heavy_pose: Transform2D = game._enemy_pose_transform(sentry, center, 1.0, 0.0)
	_expect(not agile_pose.is_equal_approx(heavy_pose), "agile and heavy enemies use distinct motion stiffness")

	game.floor_number = 15
	var knight: Dictionary = game._make_boss(origin)
	_expect(knight.boss_kind == "knight", "fifteenth-floor chess boss is the knight")
	game._queue_enemy_visual(knight, origin, origin + Vector2i(2, 1))
	var jump_track = knight["_visual_motion"]
	_expect(jump_track.kind == "enemy_jump" and is_equal_approx(jump_track.duration, 0.18), "knight's resolved move gets its own bounded jump presentation")
	jump_track.advance(0.09)
	_expect(jump_track.is_active() and is_equal_approx(jump_track.progress, 0.5), "knight jump reaches its midpoint without changing gameplay")
	jump_track.advance(0.10)
	_expect(not jump_track.is_active() and _near(jump_track.position(), game._cell_center(origin + Vector2i(2, 1))), "knight jump reaches the already-resolved landing")


func _test_delta_rng_and_caps() -> void:
	for hz in [30.0, 60.0, 144.0]:
		_reset_arena()
		game.try_move(1, 0)
		game.try_move(0, 1)
		for _frame in int(ceil(hz * 0.4)):
			game._process(1.0 / hz)
		_expect(game.turn_number == 2 and game.player_position == Vector2i(10, 8) and _near(game._player_visual_position(), game._cell_center(game.player_position)), "same result at %.0fHz simulated" % hz)
	_reset_arena()
	game.try_move(1, 0)
	var rng_before: int = game.rng.state
	game._process(0.04)
	_expect(game.rng.state == rng_before, "pose and movement consume no gameplay RNG without pre-existing shake")
	for i in 30:
		game._add_surface_reaction(Vector2(i, 0), "water")
	_expect(game.surface_reactions.size() == 8, "surface reactions have a fixed cap")


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.feedback_bus.event_emitted.connect(_on_event)
	await process_frame
	_test_directions()
	_test_corner_and_reversal()
	_test_fast_overflow()
	_test_ice_water_and_crates()
	_test_push_weight_and_blocking()
	_test_block_pause_jump_blink_capture_reset()
	_test_entities_and_combat()
	_test_enemy_pose_and_knight()
	_test_delta_rng_and_caps()
	game.queue_redraw()
	await process_frame
	if failures.is_empty():
		print("EXPRESSIVE_MOVEMENT_TEST_PASS checks=", checks, " directions, continuity, overflow, ice, water, crates, block, pause, jump, blink, capture, combat, enemies and RNG")
		game.queue_free()
		await process_frame
		quit(0)
	else:
		printerr("EXPRESSIVE_MOVEMENT_TEST_FAIL count=", failures.size(), " checks=", checks)
		game.queue_free()
		await process_frame
		quit(1)
