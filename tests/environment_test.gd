extends SceneTree

const Game = preload("res://game.gd")
const EnvironmentRules = preload("res://environment_system.gd")

var failures: Array[String] = []
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func _move(direction: Vector2i, times: int = 1) -> void:
	for _i in times:
		game.try_move(direction.x, direction.y)


func _go_around_crate_to_portal(start_x: int) -> void:
	_move(Vector2i.DOWN)
	_move(Vector2i.RIGHT, 10 - start_x)
	_move(Vector2i.UP)


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	await process_frame
	_test_chambers_and_profile()
	_test_rules()
	_test_enemy_and_hazards()
	_test_displacement_pickups_and_hazards()
	_test_teleports_and_reset()
	_test_campaign_landmark()
	_test_escape_preserves_campaign()
	await _test_draw_callbacks()
	if failures.is_empty():
		print("ENVIRONMENT_TEST_PASS: four chamber solutions, profile isolation, crates, currents, ice, electricity, gates, enemies and reset")
	else:
		printerr("ENVIRONMENT_TEST_FAIL: %d: %s" % [failures.size(), "; ".join(failures)])
	game.persistence_enabled = false
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_chambers_and_profile() -> void:
	# Use a disposable profile, not the player's. Check disk bytes as well as
	# in-memory resume metadata across success, failure, retry and all rooms.
	var test_profile := "user://environment_test_profile.cfg"
	game.profile_path = test_profile
	game.persistence_enabled = true
	game.new_game(12345)
	var before := FileAccess.get_file_as_string(test_profile)
	var resume_before := [game.has_resume, game.resume_floor, game.resume_coins, game.resume_charges,
		game.resume_breach_charges, game.resume_seed, game.resume_history.duplicate(), game.resume_powers.duplicate(true),
		game.floor_stars.duplicate(true), game.furthest_floor, game.best_score]
	game.handle_hud_action("experimental")
	_expect(game.lab_active and game.lab_index == 0 and not game.portal_open, "experimental menu opens first closed chamber")
	_move(Vector2i.RIGHT)
	_expect(game.environment.crates[0].pos == Vector2i(5, 4) and game.portal_open, "wood floats onto the held plate in the same action")
	_go_around_crate_to_portal(3)
	_expect(game.game_state == "floor_clear", "water chamber reaches the actual portal")
	game.advance_floor()
	_expect(game.lab_index == 1 and game.environment.is_electrified(Vector2i(4, 5)), "metal bridges the two water cells")
	_move(Vector2i.RIGHT, 2)
	_expect(game.environment.crates[0].pos == Vector2i(5, 4) and not game.portal_open, "metal remains on the current instead of floating")
	_expect(not game.environment.is_electrified(Vector2i(4, 5)), "moving the metal breaks the electrical bridge")
	game.restart_floor()
	_expect(game.environment.crates[0].pos == Vector2i(4, 4) and game.turn_number == 0 and game.environment.is_electrified(Vector2i(4, 5)), "R resets metal, current, electricity and turn")
	_move(Vector2i.RIGHT, 3)
	_expect(game.environment.crates[0].pos == Vector2i(6, 4) and game.portal_open, "metal plate opens the portal")
	_go_around_crate_to_portal(5)
	_expect(game.game_state == "floor_clear", "conduction chamber reaches portal")
	game.advance_floor()
	_expect(game.lab_index == 2, "ice chamber follows")
	_move(Vector2i.RIGHT)
	_expect(game.game_state == "captured", "entering the hot rhythm trap on ice is fatal without a shield")
	game._update_capture_sequence(game.CAPTURE_END_TIME + 0.1)
	_expect(game.game_state == "game_over", "environmental death reaches retry screen")
	game.continue_game()
	_expect(game.lab_index == 2 and game.game_state == "playing" and game.turn_number == 0, "continue retries the same chamber, not campaign")
	game.wait_turn()
	_move(Vector2i.RIGHT)
	_expect(game.player_position == Vector2i(4, 4) and game.game_state == "playing", "wait then enter ice safely; slide resolves one extra cell")
	_move(Vector2i.RIGHT)
	_expect(game.portal_open and game.environment.crates[0].pos == Vector2i(6, 4), "ice chamber crate holds its plate")
	_go_around_crate_to_portal(5)
	_expect(game.game_state == "floor_clear", "pressure chamber reaches portal")
	game.advance_floor()
	_expect(game.lab_index == 3 and not game.portal_open, "two-plate gate chamber begins closed")
	_move(Vector2i.UP)
	_move(Vector2i.RIGHT, 2)
	_expect(game.environment.active_plate_count() == 1 and not game.portal_open, "one plate alone does not open the gate")
	_move(Vector2i.DOWN)
	_move(Vector2i.LEFT, 2)
	_move(Vector2i.DOWN)
	_move(Vector2i.RIGHT, 2)
	_expect(game.environment.active_plate_count() == 2 and game.portal_open and game.environment.gates[0].open, "both correct materials open gate and portal")
	_move(Vector2i.UP)
	_move(Vector2i.RIGHT, 6)
	_expect(game.game_state == "floor_clear", "two-plate chamber crosses gate and reaches portal")
	game.advance_floor()
	_expect(game.game_state == "title" and not game.lab_active, "final chamber returns to title")
	var resume_after := [game.has_resume, game.resume_floor, game.resume_coins, game.resume_charges,
		game.resume_breach_charges, game.resume_seed, game.resume_history.duplicate(), game.resume_powers.duplicate(true),
		game.floor_stars.duplicate(true), game.furthest_floor, game.best_score]
	_expect(before == FileAccess.get_file_as_string(test_profile) and resume_after == resume_before, "chambers, failure, retry and completion do not alter campaign/profile")
	game.continue_game()
	_expect(game.floor_number == 1 and not game.lab_active and not game.environment.is_active(), "campaign continue restores normal generated floor")
	game.persistence_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_profile))


func _test_rules() -> void:
	var env = EnvironmentRules.new()
	env.reset({"cells": {
		Vector2i(2, 2): {"kind": "current", "flow": Vector2i.RIGHT},
		Vector2i(4, 2): {"kind": "current", "flow": Vector2i.LEFT},
	}, "crates": [
		{"pos": Vector2i(2, 2), "material": "wood"},
		{"pos": Vector2i(4, 2), "material": "wood"},
	]})
	var moves: Array[Dictionary] = env.advance_currents(func(_point: Vector2i) -> bool: return true)
	_expect(moves.size() == 1 and env.crates[0].pos == Vector2i(3, 2) and env.crates[1].pos == Vector2i(4, 2), "simultaneous current conflict has deterministic first-crate winner")
	env.reset({"crates": [{"pos": Vector2i(2, 2), "material": "wood"}],
		"plates": [{"pos": Vector2i(2, 2), "required": "wood"}],
		"gates": [{"pos": Vector2i(4, 2), "open": false}]})
	var enemies: Array[Vector2i] = []
	_expect(env.update_mechanisms(Vector2i(1, 1), enemies) and env.gates[0].open, "crate holds correct plate")
	env.crates[0].pos = Vector2i(3, 2)
	_expect(not env.update_mechanisms(Vector2i(4, 2), enemies) and env.gates[0].open, "gate remains open while player occupies it")
	env.update_mechanisms(Vector2i(5, 2), enemies)
	_expect(not env.gates[0].open, "gate closes after occupant leaves")
	env.crates[0].pos = Vector2i(2, 2)
	env.update_mechanisms(Vector2i(1, 1), enemies)
	env.crates[0].pos = Vector2i(3, 2)
	enemies.append(Vector2i(4, 2))
	env.update_mechanisms(Vector2i(1, 1), enemies)
	_expect(env.gates[0].open, "gate remains open for an enemy occupant")
	enemies.clear()
	env.update_mechanisms(Vector2i(1, 1), enemies)
	_expect(not env.gates[0].open, "gate closes when the enemy leaves")
	env.crates[0].pos = Vector2i(2, 2)
	env.update_mechanisms(Vector2i(1, 1), enemies)
	env.crates[0].pos = Vector2i(4, 2)
	env.update_mechanisms(Vector2i(1, 1), enemies)
	_expect(env.gates[0].open, "gate remains open for a crate occupant")
	env.crates[0].pos = Vector2i(3, 2)
	env.update_mechanisms(Vector2i(1, 1), enemies)
	_expect(not env.gates[0].open, "gate closes when the crate leaves")


func _test_enemy_and_hazards() -> void:
	game.start_environment_lab()
	game.environment.reset({"crates": [{"pos": Vector2i(4, 4), "material": "wood"}]})
	game.player_position = Vector2i(3, 4)
	game.enemies.clear()
	var enemy: Dictionary = game._make_enemy(Vector2i(6, 4), "hunter")
	enemy.next = Vector2i(5, 4)
	game.enemies.append(enemy)
	_move(Vector2i.RIGHT)
	_expect(game.environment.crates[0].pos == Vector2i(5, 4) and game.enemies[0].pos == Vector2i(6, 4), "new crate position cancels previously telegraphed enemy move")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(5, 4): {"kind": "water", "source": true}}})
	game.player_position = Vector2i(2, 4)
	game.enemies.clear()
	enemy = game._make_enemy(Vector2i(6, 4), "hunter")
	enemy.next = Vector2i(5, 4)
	game.enemies.append(enemy)
	game.wait_turn()
	_expect(game.enemies.is_empty(), "electrified water defeats ordinary enemy after movement")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(5, 4): {"kind": "water", "source": true}}})
	game.enemies.clear()
	game.enemies.append(game._make_warden(Vector2i(5, 4)))
	game.freeze_turns = 5
	game.wait_turn()
	_expect(game.enemies.size() == 1 and game.enemies[0].hp == 2, "electricity removes one elite HP per committed action")
	game.wait_turn()
	_expect(game.enemies.size() == 1 and game.enemies[0].hp == 1, "electricity does not remove the entire elite in one action")
	game.wait_turn()
	_expect(game.enemies.is_empty(), "electricity defeats an elite after its final HP")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(6, 4): {"kind": "ice"}}})
	game.enemies.clear()
	enemy = game._make_enemy(Vector2i(6, 4), "hunter")
	game.enemies.append(enemy)
	game.turn_number = 1
	game._update_enemy_intents()
	_expect(game.enemies[0].next == Vector2i(6, 4), "ice telegraphs a stationary enemy intent for even action")
	game.wait_turn()
	_expect(game.enemies[0].pos == Vector2i(6, 4) and game.enemies[0].next != Vector2i(6, 4), "enemy waits on ice then announces its following move")
	game.wait_turn()
	_expect(game.enemies[0].pos != Vector2i(6, 4), "ice does not permanently trap enemies")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(6, 4): {"kind": "ice"}}})
	game.enemies.clear()
	game.enemies.append(game._make_enemy(Vector2i(6, 4), "mirror"))
	game.turn_number = 1
	game._update_enemy_intents()
	_move(Vector2i.RIGHT)
	_expect(game.enemies[0].pos == Vector2i(6, 4), "reactive mirror cannot override the ice delay on an even action")
	_move(Vector2i.RIGHT)
	_expect(game.enemies[0].pos == Vector2i(5, 4), "mirror resumes its opposite move on the next odd action")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(3, 4): {"kind": "water", "source": true}}})
	game.charges = 1
	game.traps.assign([{"pos": Vector2i(3, 4), "armed": true, "revealed": true}])
	_move(Vector2i.RIGHT)
	_expect(game.charges == 0 and game.hits_this_floor == 1 and game.game_state == "playing", "trap plus electricity uses one shield on the action")
	game.wait_turn()
	_expect(game.game_state == "captured", "a new turn on electrified water is a legitimate new hit")


func _test_displacement_pickups_and_hazards() -> void:
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {
		Vector2i(3, 4): {"kind": "current", "flow": Vector2i.RIGHT},
		Vector2i(4, 4): {"kind": "water", "source": true},
	}})
	game.coins.assign([Vector2i(3, 4), Vector2i(4, 4)])
	game.traps.assign([
		{"pos": Vector2i(3, 4), "armed": true},
		{"pos": Vector2i(4, 4), "armed": true},
	])
	game.charges = 2
	_move(Vector2i.RIGHT)
	_expect(game.player_position == Vector2i(4, 4) and game.coins.is_empty() and game.coins_this_floor == 2, "pickups are collected on both current entry and landing cells")
	_expect(game.charges == 1 and game.hits_this_floor == 1 and not game.traps[0].armed and not game.traps[1].armed, "hazards on both cells resolve but spend at most one shield")

	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(3, 4): {"kind": "current", "flow": Vector2i.RIGHT}}})
	game.coins.assign([Vector2i(3, 4), Vector2i(4, 4)])
	game.traps.assign([{"pos": Vector2i(3, 4), "armed": true}])
	game.charges = 0
	_move(Vector2i.RIGHT)
	_expect(game.game_state == "captured" and game.player_position == Vector2i(3, 4) and game.coins == [Vector2i(4, 4)], "fatal entry hazard stops displacement before the landing pickup")

	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(3, 4): {"kind": "current", "flow": Vector2i.RIGHT}}})
	game.player_position = Vector2i(3, 4)
	game.wait_turn()
	_expect(game.player_position == Vector2i(4, 4), "current carries a waiting player one cell")
	game._load_lab_chamber(0)
	game.environment.reset({"cells": {Vector2i(3, 4): {"kind": "ice"}}})
	game.player_position = Vector2i(3, 4)
	game.wait_turn()
	_expect(game.player_position == Vector2i(3, 4), "waiting on ice does not invent a movement direction")


func _test_teleports_and_reset() -> void:
	game._load_lab_chamber(0)
	game.environment.reset({"crates": [{"pos": Vector2i(3, 4), "material": "metal"}]})
	game.charges = 1
	game.facing = Vector2i.RIGHT
	game.try_jump()
	_expect(game.player_position == Vector2i(2, 4) and game.charges == 1 and game.turn_number == 0, "jump cannot pass through a crate or spend a charge")
	game.grid[4][4] = game.TILE_WALL
	game.grid[4][5] = game.TILE_WALL
	game.blink_charges = 1
	game.try_blink()
	_expect(game.player_position == Vector2i(2, 4) and game.blink_charges == 1, "blink cannot land on a crate")
	game._load_lab_chamber(0)
	game.grid[4][4] = game.TILE_WALL
	var turns: int = game.turn_number
	_move(Vector2i.RIGHT)
	_expect(game.player_position == Vector2i(2, 4) and game.environment.crates[0].pos == Vector2i(3, 4) and game.turn_number == turns, "blocked push changes no occupancy and spends no turn")
	game.restart_floor()
	_expect(game.grid[4][4] == game.TILE_WATER and game.environment.crates[0].pos == Vector2i(3, 4), "reset reconstructs authored level, not mutated grid")


# Paths in the selected campaign floors are tested through the real movement
# methods. God mode removes combat randomness only; it is not a balance test.
func _route_to(target: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = game.player_position
	var previous := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size() and not previous.has(target):
		var point := queue[head]
		head += 1
		for direction in game.FOUR_WAY:
			var next: Vector2i = point + direction
			if game._is_floor(next) and game.environment.kind_at(next) != "current" and not previous.has(next):
				previous[next] = point
				queue.append(next)
	var path: Array[Vector2i] = []
	if not previous.has(target):
		return path
	var cursor := target
	while cursor != start:
		var from: Vector2i = previous[cursor]
		path.push_front(cursor - from)
		cursor = from
	return path


func _test_campaign_landmark() -> void:
	for floor_number in [6, 26]:
		for seed_value in [1, 21, 199, 12900, 48211, 77123, 92197, 123456]:
			game.active_seed = seed_value
			game.charges = 2
			game.generate_floor(floor_number)
			game.game_state = "playing"
			_expect(game.environment_bonus_available, "campaign optional landmark exists on floor %d seed %d" % [floor_number, seed_value])
			if not game.environment_bonus_available:
				continue
			var initial_grid: Array = game.grid.duplicate(true)
			var initial_crates: Array = game.environment.crates.duplicate(true)
			var cells: Dictionary = game.environment.cells.duplicate(true)
			var point: Vector2i = game.environment.crates[0].pos
			var flow := Vector2i.ZERO
			for cell in cells:
				if cells[cell].kind == "current":
					flow = cells[cell].flow
			var approach := point - flow
			var route := _route_to(approach)
			_expect(flow in game.FOUR_WAY and (not route.is_empty() or game.player_position == approach), "push approach reachable without moving crate on floor %d seed %d" % [floor_number, seed_value])
			game.enemies.clear()
			game.dev_god_mode = true
			for direction in route:
				_move(direction)
			var shield_before: int = game.charges
			var portal_before: bool = game.portal_open
			_move(flow)
			_expect(game.environment_bonus_claimed and game.charges == shield_before + 1, "one real push earns exactly one shield on floor %d seed %d" % [floor_number, seed_value])
			_expect(game.portal_open == portal_before, "optional pressure plate does not replace campaign portal objective")
			var updated_nav: Array = game.nav_chevrons.duplicate(true)
			game._build_nav_chevrons()
			_expect(game.nav_chevrons == updated_nav, "navigation reflects the settled crate and current")
			game.wait_turn()
			_expect(game.charges == shield_before + 1, "held plate cannot award repeatedly")
			game.restart_floor()
			_expect(game.charges == 2 and not game.environment_bonus_claimed and game.grid == initial_grid and game.environment.crates == initial_crates and game.environment.cells == cells, "campaign reset restores entry resources and identical landmark")
			# Actually finish the ordinary objective after earning the reward. The
			# route avoids the current rather than assuming it is bidirectional.
			game.enemies.clear()
			game.dev_god_mode = true
			for direction in _route_to(approach):
				_move(direction)
			_move(flow)
			for item in game.switches.duplicate(true):
				var path := _route_to(item.pos)
				_expect(not path.is_empty() or game.player_position == item.pos, "switch is reachable without crossing current on floor %d seed %d" % [floor_number, seed_value])
				for direction in path:
					_move(direction)
			var exit_route := _route_to(game.portal_position)
			_expect(not exit_route.is_empty() or game.player_position == game.portal_position, "portal remains reachable without crossing current on floor %d seed %d" % [floor_number, seed_value])
			for direction in exit_route:
				_move(direction)
			_expect(game.game_state == "floor_clear", "campaign objective can be completed after the bonus on floor %d seed %d" % [floor_number, seed_value])
			game.dev_god_mode = false


func _test_escape_preserves_campaign() -> void:
	game.new_game(24680)
	var saved_floor: int = game.resume_floor
	var saved_seed: int = game.resume_seed
	game.start_environment_lab()
	game.game_state = "floor_clear"
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_key_input(event)
	_expect(game.game_state == "title" and not game.lab_active, "escape from chamber result returns cleanly to title")
	game.continue_game()
	_expect(not game.lab_active and game.floor_number == saved_floor and game.active_seed == saved_seed, "continue after escape resumes campaign, not chamber")


func _test_draw_callbacks() -> void:
	for index in 4:
		game._load_lab_chamber(index)
		await process_frame
		await process_frame
		_expect(not game.terrain_renderer.chunks.is_empty(), "retained terrain chunks created for chamber %d" % index)
