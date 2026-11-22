extends SceneTree

const Game = preload("res://game.gd")
const Rules = preload("res://environment_system.gd")
const Visual = preload("res://mechanism_presentation.gd")
const Installation = preload("res://submerged_installation.gd")

var checks := 0
var failures: Array[String] = []
var mechanism_cues: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _capture_cue(cue: String) -> void:
	if cue in ["plate_wood", "plate_metal", "gate_open", "gate_close", "water_drain"]:
		mechanism_cues.append(cue)


func _test_tracks() -> void:
	var visual = Visual.new()
	var env = Rules.new()
	var plate := Vector2i(2, 2)
	var gate := Vector2i(4, 2)
	var wet := Vector2i(3, 3)
	var terminal := Vector2i(5, 3)
	env.reset({"plates": [{"pos": plate, "required": "wood", "active": false}],
		"gates": [{"pos": gate, "open": false}], "cells": {wet: {"kind": "water"}}})
	var switches: Array[Dictionary] = [{"pos": terminal, "active": false, "hidden": true}]
	_expect(visual.observe(env, switches, false).is_empty(), "new room is primed without fabricated activation cues")
	_expect(visual.plate_amount(plate, false) == 0.0 and visual.gate_amount(gate, false) == 0.0, "inactive plate and closed gate start at their actual poses")
	_expect(visual.water_amount(wet, true) == 1.0 and visual.switch_visibility(terminal, true) == 0.0, "full water and hidden terminal start in the correct states")
	env.plates[0].active = true
	env.gates[0].open = true
	switches[0].active = true
	switches[0].hidden = false
	var logical_before := [env.plates.duplicate(true), env.gates.duplicate(true), env.cells.duplicate(true), switches.duplicate(true)]
	var events: Array[Dictionary] = visual.observe(env, switches, true)
	_expect(events.size() == 2 and events[0].kind == "plate" and events[1].kind == "gate", "a changed plate and gate each produce one visual cue")
	_expect(visual.observe(env, switches, true).is_empty(), "repeated sync does not duplicate cues")
	_expect(visual.plate_amount(plate, true) == 0.0 and visual.gate_amount(gate, true) == 0.0, "logical change does not teleport either visible pose")
	visual.advance(0.10)
	var plate_mid := visual.plate_amount(plate, true)
	var gate_mid := visual.gate_amount(gate, true)
	_expect(plate_mid > 0.0 and plate_mid < 1.0 and gate_mid > 0.0 and gate_mid < 1.0, "plate depresses and gate travels through intermediate poses")
	_expect(visual.switch_amount(terminal, true) > 0.0 and visual.switch_amount(terminal, true) < 1.0 and visual.switch_visibility(terminal, false) > 0.0 and visual.switch_visibility(terminal, false) < 1.0, "switch activation and reveal have intermediate states")
	_expect(visual.portal_amount(true) > 0.0 and visual.portal_amount(true) < 1.0, "portal status changes continuously")
	_expect(logical_before == [env.plates, env.gates, env.cells, switches], "advancing visual tracks never mutates authoritative objects")
	env.plates[0].active = false
	env.gates[0].open = false
	switches[0].active = false
	visual.observe(env, switches, false)
	_expect(is_equal_approx(visual.plate_amount(plate, false), plate_mid) and is_equal_approx(visual.gate_amount(gate, false), gate_mid), "reversal starts at the displayed pose without a jump")
	visual.advance(0.035)
	_expect(visual.gate_amount(gate, false) < gate_mid and visual.plate_amount(plate, false) < plate_mid, "reversal travels toward the new target")
	visual.advance(5.0)
	_expect(visual.gate_amount(gate, false) == 0.0 and visual.plate_amount(plate, false) == 0.0 and visual.portal_amount(false) == 0.0, "large frame completes safely at the authoritative endpoints")
	var still := visual.switch_visibility(terminal, false)
	visual.advance(0.0)
	visual.advance(-1.0)
	_expect(is_equal_approx(visual.switch_visibility(terminal, false), still), "zero or negative visual time cannot advance a track")

	env.cells.erase(wet)
	events = visual.observe(env, switches, false)
	_expect(events.size() == 1 and events[0].kind == "drain", "removing water emits one aggregate drain cue")
	_expect(visual.water_amount(wet, false) == 1.0 and visual.water_is_animating(wet), "water starts fully visible after logical removal")
	visual.advance(0.5)
	var receding := visual.water_amount(wet, false)
	_expect(receding > 0.0 and receding < 1.0 and not env.is_water(wet), "water fades while the logical cell is already dry")
	env.cells[wet] = {"kind": "water"}
	visual.observe(env, switches, false)
	_expect(is_equal_approx(visual.water_amount(wet, true), receding), "restoring water mid-fade is continuous")
	visual.advance(0.15)
	_expect(visual.water_amount(wet, true) > receding and visual.water_amount(wet, true) < 1.0, "restored water rises gradually")
	_expect(visual.advance(5.0) and visual.water_amount(wet, true) == 1.0, "completed refill requests one terrain rebake")
	_expect(not visual.advance(0.1), "settled water does not rebuild terrain every frame")
	env.cells.erase(wet)
	visual.observe(env, switches, false)
	visual.advance(5.0)
	_expect(not visual.water.has(wet) and visual.water_amount(wet, false) == 0.0, "fully drained ghosts are discarded")

	var pickup := Vector2i(8, 3)
	visual.collect_pickup("coin", pickup, 0.12)
	_expect(visual.pickup_amount("coin", pickup, false) == 1.0, "collected coin remains visually whole until the player arrives")
	visual.advance(0.08)
	_expect(visual.pickup_amount("coin", pickup, false) == 1.0, "arrival delay does not contract the echo early")
	visual.advance(0.10)
	var pickup_mid: float = visual.pickup_amount("coin", pickup, false)
	_expect(pickup_mid > 0.0 and pickup_mid < 1.0, "coin contracts through intermediate sizes after arrival")
	visual.restore_pickup("coin", pickup)
	_expect(is_equal_approx(visual.pickup_amount("coin", pickup, true), pickup_mid), "undo reverses a pickup at its displayed size")
	visual.advance(0.03)
	_expect(visual.pickup_amount("coin", pickup, true) > pickup_mid, "restored pickup grows back continuously")
	visual.advance(1.0)
	_expect(visual.pickup_amount("coin", pickup, true) == 1.0 and visual.pickups.is_empty(), "restored pickup settles without a permanent echo")
	visual.collect_pickup("shield", pickup)
	visual.advance(1.0)
	_expect(visual.pickup_amount("shield", pickup, false) == 0.0 and visual.pickups.is_empty(), "collected echo is removed at zero")
	visual.restore_pickup("shield", pickup)
	_expect(visual.pickup_amount("shield", pickup, true) == 0.0, "undo after an echo has finished begins from zero")
	visual.advance(0.1)
	_expect(visual.pickup_amount("shield", pickup, true) > 0.0 and visual.pickup_amount("shield", pickup, true) < 1.0, "late undo also restores progressively")
	for i in 100:
		visual.collect_pickup("coin", Vector2i(i, 7))
	_expect(visual.pickups.size() <= Visual.MAX_PICKUP_TRACKS, "pickup echo memory remains bounded")
	visual.clear()
	_expect(not visual.initialized and visual.water.is_empty() and visual.gates.is_empty() and visual.pickups.is_empty(), "room reset clears all presentation tracks")


func _test_real_game() -> void:
	var game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.audio.effects_enabled = false
	game.audio.cue_played.connect(_capture_cue)
	game.start_environment_lab(3)
	var gate: Vector2i = game.environment.gates[0].pos
	var first: Vector2i = game.environment.plates[0].pos
	var second: Vector2i = game.environment.plates[1].pos
	var original_rng: int = game.rng.state
	var original_turn: int = game.turn_number
	_expect(game.mechanism_presentation.gate_amount(gate, false) == 0.0 and game.environment.is_gate_closed(gate), "ordinary chamber starts with a closed physical gate")
	game.environment.crates[0].pos = first
	game.environment.crates[1].pos = second
	game._sync_environment_mechanisms()
	_expect(game.environment.gates[0].open and not game.environment.is_gate_closed(gate) and game.portal_open, "real rules open collision and portal immediately on plate activation")
	_expect(game.mechanism_presentation.gate_amount(gate, true) == 0.0, "the opening gate starts in its previous visible pose")
	game._process(0.10)
	var partial: float = game.mechanism_presentation.gate_amount(gate, true)
	_expect(partial > 0.0 and partial < 1.0, "real game advances a physical gate between endpoints")
	_expect(game.mechanism_presentation.plate_amount(first, true) > 0.0 and game.mechanism_presentation.plate_amount(first, true) < 1.0, "real game animates every plate via the shared renderer")
	_expect(game.rng.state == original_rng and game.turn_number == original_turn, "mechanism presentation consumes neither gameplay RNG nor turns")
	game.game_state = "paused"
	game._process(0.5)
	_expect(is_equal_approx(game.mechanism_presentation.gate_amount(gate, true), partial), "pause freezes gate presentation")
	game.game_state = "playing"
	game.environment.crates[0].pos = Vector2i(3, 3)
	game._sync_environment_mechanisms()
	_expect(game.environment.is_gate_closed(gate) and is_equal_approx(game.mechanism_presentation.gate_amount(gate, false), partial), "closing collision is immediate while the visual reverses continuously")
	game._process(0.08)
	_expect(game.mechanism_presentation.gate_amount(gate, false) < partial, "reversed gate travels back toward closed")
	_expect(mechanism_cues.is_empty(), "effects mute suppresses new mechanism audio")
	for cue in ["plate_wood", "plate_metal", "gate_open", "gate_close", "water_drain"]:
		_expect(game.audio.effects.has(cue) and game.audio.effects[cue].data.size() > 0, "mechanism cue exists: " + cue)
	game.audio.effects_enabled = true
	game.environment.crates[0].pos = first
	game._sync_environment_mechanisms()
	game._advance_mechanism_sounds(0.5)
	_expect(not mechanism_cues.is_empty(), "a pending nearby mechanism can emit its spatial cue")
	game.audio.set_mechanism_paused(true)
	# The headless Dummy driver does not report an actual paused playback;
	# verify the requested state here and leave audible behavior for hardware.
	_expect(game.audio.mechanism_paused, "mechanism audio receives the same pause request")
	game.audio.stop_mechanism_sounds()
	_expect(game.audio.mechanism_players.is_empty(), "room reset can stop all mechanism voices")
	game.audio.effects_enabled = false

	game.start_environment_lab(Installation.LAB_INDEX)
	var source := Installation.SOURCE
	var switch_pos: Vector2i = Installation.DRAIN_TERMINALS[0]
	var save := game._snapshot_sokoban()
	game._remember_sokoban(save)
	game.environment.crates[2].pos = Installation.DRAIN_PLATE
	game._sync_environment_mechanisms()
	_expect(game.submerged.drained and not game.environment.is_water(source) and game.grid[source.y][source.x] == game.TILE_FLOOR, "real drainage removes water and danger in the resolved action")
	_expect(game.mechanism_presentation.water_amount(source, false) == 1.0, "drainage preserves the last water surface at the start of its fade")
	_expect(game.mechanism_presentation.switch_visibility(switch_pos, false) == 0.0 and not game.switches[2].hidden, "newly available terminal begins a visible reveal")
	game._process(0.5)
	var faded: float = game.mechanism_presentation.water_amount(source, false)
	_expect(faded > 0.0 and faded < 1.0, "water visibly recedes over time in the real chamber")
	_expect(game.mechanism_presentation.switch_visibility(switch_pos, false) == 1.0, "revealed terminal settles during the drainage")
	game.undo_sokoban_move()
	_expect(not game.submerged.drained and game.environment.is_water(source) and game.grid[source.y][source.x] == game.TILE_WATER, "undo immediately restores the real water and hidden terminal rules")
	_expect(is_equal_approx(game.mechanism_presentation.water_amount(source, true), faded), "undo preserves the current water opacity before reversing")
	game._process(0.15)
	_expect(game.mechanism_presentation.water_amount(source, true) > faded and game.mechanism_presentation.water_amount(source, true) < 1.0, "undo refills smoothly instead of popping into place")
	game._process(3.0)
	_expect(game.mechanism_presentation.water_amount(source, true) == 1.0 and not game.mechanism_presentation.water_is_animating(source), "refill settles and terrain is ready for caching")

	var loot: Vector2i = game.player_position + Vector2i.RIGHT
	game.coins.append(loot)
	game._remember_sokoban(game._snapshot_sokoban())
	var total_before: int = game.total_coins
	_expect(game._collect_coin(loot) and not game.coins.has(loot) and game.total_coins > total_before, "coin reward and removal are immediate despite the visual echo")
	game._process(0.1)
	var coin_mid: float = game.mechanism_presentation.pickup_amount("coin", loot, false)
	_expect(coin_mid > 0.0 and coin_mid < 1.0, "real collected coin contracts instead of popping away")
	game.game_state = "paused"
	game._process(0.5)
	_expect(is_equal_approx(game.mechanism_presentation.pickup_amount("coin", loot, false), coin_mid), "pause freezes a pickup echo")
	game.game_state = "playing"
	game.undo_sokoban_move()
	_expect(game.coins.has(loot) and game.total_coins == total_before and is_equal_approx(game.mechanism_presentation.pickup_amount("coin", loot, true), coin_mid), "undo restores the real coin and reverses its current presentation")
	game._process(0.1)
	_expect(game.mechanism_presentation.pickup_amount("coin", loot, true) > coin_mid, "real coin grows back after undo")

	var more: Vector2i = game.player_position
	game.shields.append(more)
	game.breakers.append(more)
	game.powerups.append({"pos": more, "kind": "speed"})
	game._remember_sokoban(game._snapshot_sokoban())
	game._collect_pickups()
	_expect(not game.shields.has(more) and not game.breakers.has(more) and game.powerups.is_empty(), "shield, breaker and powerup rules resolve immediately")
	_expect(game.mechanism_presentation.pickup_amount("shield", more, false) == 1.0 and game.mechanism_presentation.pickup_amount("breaker", more, false) == 1.0 and game.mechanism_presentation.pickup_amount("power:speed", more, false) == 1.0, "each collected type retains its own echo")
	game._process(0.1)
	game.undo_sokoban_move()
	_expect(game.shields.has(more) and game.breakers.has(more) and game.powerups.size() == 1, "undo restores each authoritative pickup exactly once")
	_expect(game.mechanism_presentation.pickup_amount("power:speed", more, true) > 0.0 and game.mechanism_presentation.pickup_amount("power:speed", more, true) < 1.0, "powerup undo reverses the in-flight size")
	game._load_lab_chamber(0)
	_expect(not game.mechanism_presentation.water.has(source) and game.mechanism_presentation.gates.is_empty(), "changing rooms drops old water and gate tracks")
	game.audio.stop_all()
	game.queue_free()


func _run() -> void:
	_test_tracks()
	_test_real_game()
	await process_frame
	# Let the Dummy audio backend release stopped stream-playback references.
	await create_timer(0.12).timeout
	if failures.is_empty():
		print("MECHANISM_PRESENTATION_TEST_PASS checks=", checks, " continuous plates, doors, water, switches, portal, undo, pause, audio and unchanged rules")
		quit(0)
	else:
		printerr("MECHANISM_PRESENTATION_TEST_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
