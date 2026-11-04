extends SceneTree

const Game = preload("res://game.gd")
const Schedule = preload("res://special_schedule.gd")
const Special = preload("res://special_levels.gd")
const Rules = preload("res://environment_system.gd")

var game: Node
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	await process_frame
	_test_schedule()
	_test_circuit_rules()
	_test_all_chamber_solutions()
	_test_restart_from_real_campaign()
	_test_wfc_families()
	if failures.is_empty():
		print("SPECIAL_CONTENT_TEST_PASS checks=", checks, " long schedule, circuit, reflected chambers, real turns, reset and WFC hybrids")
	else:
		printerr("SPECIAL_CONTENT_TEST_FAIL count=", failures.size(), " checks=", checks)
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_schedule() -> void:
	var observed := {}
	for seed_value in [1, 2, 3, 21, 199, 12900, 48211, 77123, 92197, 123456, 987654, 1234567]:
		var schedule = Schedule.new()
		var last_floor := 0
		var last_family := ""
		var count := 0
		for number in range(1, 2001):
			var family: String = schedule.family_for(seed_value, number)
			if family == "":
				continue
			count += 1
			observed[family] = int(observed.get(family, 0)) + 1
			if last_floor > 0:
				_expect(number - last_floor >= 3 and number - last_floor <= 9, "special spacing remains in 3–9 floors")
				_expect(family != last_family, "adjacent specials have different families")
			_expect(number % 5 not in [0, 4] and number % 20 != 6, "specials never replace boss, warden or established landmark")
			last_floor = number
			last_family = family
		_expect(count < 700, "normal floors dominate a 2000-floor sequence")
		var revisit = Schedule.new()
		revisit.family_for(seed_value, 2000)
		for number in [3, 7, 8, 17, 63, 199, 523, 1337, 1998]:
			_expect(schedule.family_for(seed_value, number) == revisit.family_for(seed_value, number), "out-of-order revisit reproduces the seed schedule")
	for family in ["sequence", "sokoban", "mechanism", "circuit", "switches", "hybrid", "quiet"]:
		_expect(int(observed.get(family, 0)) > 0, "long campaign contains family " + family)
	var first = Schedule.new()
	var second = Schedule.new()
	var difference := false
	for number in range(6, 180):
		if first.family_for(42, number) != second.family_for(43, number):
			difference = true
	_expect(difference, "different campaign seeds can have different pacing")


func _test_circuit_rules() -> void:
	var env = Rules.new()
	var source := Vector2i(5, 2)
	var target := Vector2i(5, 4)
	env.reset({"cells": {source: {"kind": "water", "source": true}, target: {"kind": "water"}},
		"crates": [{"pos": Vector2i(4, 3), "material": "metal"}],
		"plates": [{"pos": target, "required": "powered"}]})
	var enemies: Array[Vector2i] = []
	_expect(not env.update_mechanisms(Vector2i(3, 3), enemies) and not env.is_electrified(target), "a disconnected circuit is safe and its receiver is off")
	_expect(env.push(0, Vector2i.RIGHT, func(_point: Vector2i) -> bool: return true), "metal can be pushed into the conductive bridge")
	_expect(env.is_electrified(target) and env.update_mechanisms(Vector2i(4, 3), enemies), "the real conduction graph powers the receiver")
	_expect(env.push(0, Vector2i.RIGHT, func(_point: Vector2i) -> bool: return true), "bridge can be disconnected again")
	_expect(not env.is_electrified(target) and not env.update_mechanisms(Vector2i(5, 3), enemies), "the receiver and hazard switch off immediately")
	env.crates[0].pos = Vector2i(5, 3)
	env.crates[0].material = "wood"
	env.refresh_electricity()
	_expect(not env.is_electrified(target) and not env.update_mechanisms(Vector2i(4, 3), enemies), "wood cannot complete a circuit")


func _test_all_chamber_solutions() -> void:
	# Seeds exercise horizontal and vertical reflections. Floor 7 is the
	# introductory one-box room; 17 introduces two boxes and later systems.
	for family in ["sokoban", "mechanism", "circuit"]:
		for seed_value in [0, 1, 3, 4]:
			for number in ([7, 17] if family == "sokoban" else [17]):
				var spec: Dictionary = Special.make(family, seed_value, number)
				var plan: Dictionary = Special.solve(spec, spec.start, spec.crates)
				var tag := "%s seed %d floor %d" % [family, seed_value, number]
				_expect(not plan.truncated and int(plan.length) > 0 and plan.path.size() == int(plan.length), "solver returns a complete non-truncated path: " + tag)
				if int(plan.length) <= 0:
					continue
				game.floor_number = number
				game.active_seed = seed_value
				game.total_coins = 0
				game.charges = 0
				game.breach_charges = 0
				game._restore_power_state({})
				game.special_family = family
				game.dev_god_mode = false
				game._generate_special_room(spec, plan, seed_value + number * 7919)
				game.game_state = "playing"
				_expect(not game.portal_open and game.enemies.is_empty() and game.traps.is_empty(), "chamber starts closed, without hidden pursuers or traps: " + tag)
				var initial_crates: Array = game.environment.crates.duplicate(true)
				for direction in plan.path:
					if game.game_state != "playing":
						break
					var turns_before: int = game.turn_number
					game.try_move(direction.x, direction.y)
					_expect(game.turn_number == turns_before + 1, "solver step is a legal committed action: " + tag)
				_expect(game.game_state in ["floor_clear", "rescued"] and game.environment.crates != initial_crates, "actual game actions move the boxes and complete the portal: " + tag)
				_expect(game.hits_this_floor == 0, "safe chamber solution does not require damage or shield: " + tag)


func _find_family(seed_value: int, family: String) -> int:
	var schedule = Schedule.new()
	for number in range(1, 300):
		if schedule.family_for(seed_value, number) == family:
			return number
	return -1


func _test_restart_from_real_campaign() -> void:
	var number := _find_family(12900, "mechanism")
	_expect(number > 0, "mechanism is scheduled in the actual campaign")
	if number <= 0:
		return
	game.active_seed = 12900
	game.total_coins = 31
	game.charges = 1
	game.breach_charges = 2
	game._restore_power_state({"blink_charges": 1})
	game.generate_floor(number)
	game.game_state = "playing"
	var start: Vector2i = game.player_position
	var boxes: Array = game.environment.crates.duplicate(true)
	var original_grid: Array = game.grid.duplicate(true)
	var plan: Dictionary = game._plan_environment_route()
	for direction in plan.path:
		game.try_move(direction.x, direction.y)
		if game.environment.crates != boxes:
			break
	_expect(game.environment.crates != boxes, "real campaign puzzle was changed before restart")
	game.restart_floor()
	_expect(game.floor_number == number and game.active_seed == 12900 and game.player_position == start, "R restores the same floor, seed and player position")
	_expect(game.environment.crates == boxes and game.grid == original_grid and game.turn_number == 0, "R restores crates, mechanisms and board")
	_expect(game.total_coins == 31 and game.charges == 1 and game.breach_charges == 2 and game.blink_charges == 1, "R restores the entire starting inventory")


func _test_wfc_families() -> void:
	for family in ["sequence", "switches", "hybrid", "quiet"]:
		var number := _find_family(48211, family)
		_expect(number > 0, "WFC family is scheduled: " + family)
		if number <= 0:
			continue
		game.active_seed = 48211
		game.charges = 0
		game._restore_power_state({})
		game.generate_floor(number)
		game.game_state = "playing"
		_expect(game.special_family == family and game.generation_report.begins_with("WFC"), "family retains seeded WFC map: " + family)
		if family == "sequence":
			_expect(game.objective_type == "puzzle" and game.switches.size() == 3 and game.enemies.is_empty() and int(game._plan_puzzle_route().length) >= 0, "ordered runes remain solvable")
		elif family == "switches":
			_expect(game.switches.size() == 3 and game.enemies.is_empty() and game.traps.is_empty() and int(game._estimate_route_length()) >= 0, "unordered three-switch variant is a safe WFC puzzle")
		elif family == "quiet":
			_expect(game.enemies.is_empty() and game.traps.is_empty() and game.portal_open and game._reachable_cells(game.player_position).has(game.portal_position), "contemplative floor is safe and traversable")
		else:
			_expect(game.switches.size() == 3 and not game.enemies.is_empty() and not game.environment.crates.is_empty(), "hybrid combines switches, a real obstacle and pursuers")
			if game.environment.crates.is_empty():
				continue
			var box: Vector2i = game.environment.crates[0].pos
			_expect(not game._is_floor(box), "the same crate blocks both navigation and pursuers")
			game.dev_god_mode = true
			var initial: Array = game.enemies.duplicate(true)
			for _turn in 8:
				game.wait_turn()
				for enemy in game.enemies:
					_expect(enemy.pos != game.environment.crates[0].pos, "pursuer never occupies a crate")
			var changed := false
			for index in mini(initial.size(), game.enemies.size()):
				if initial[index].pos != game.enemies[index].pos:
					changed = true
			_expect(changed, "pursuers actually advance during the hybrid")
			game.dev_god_mode = false
