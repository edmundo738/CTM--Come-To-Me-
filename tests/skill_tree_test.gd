extends SceneTree

const Game = preload("res://game.gd")
const Skills = preload("res://skill_tree.gd")
var failures: Array[String] = []
var checks := 0
var events: Array[String] = []
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _event(event: String, _context: Dictionary) -> void:
	events.append(event)


func _reset_arena() -> void:
	game.skills.load_state({})
	game.dev_load_sandbox_arena()
	game.lab_active = false
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
	game._reset_player_visual(game._cell_center(game.player_position))
	game.portal_position = Vector2i(16, 12)
	game.portal_open = false
	game.game_state = "playing"
	game.dev_god_mode = false
	game.dev_noclip = false
	game.facing = Vector2i.RIGHT
	game.charges = 0
	game.breach_charges = 0
	game.hearts_current = 0
	game.turn_number = 0
	game.hits_this_floor = 0
	game.damage_this_turn = false
	game._restore_power_state({})
	game.unresolved_contacts.clear()
	events.clear()


func _equip(id: String) -> void:
	var chain: Array[String] = []
	var current := id
	while not current.is_empty():
		chain.push_front(current)
		current = str(game.skills.node(current).parent)
	game.skills.points = 200
	for part in chain:
		if not game.skills.unlocked.has(part):
			var unlocked: Dictionary = game.skills.unlock(part)
			_expect(unlocked.ok, "fixture unlock " + part)
		if not game.skills.active.has(part):
			var activated: Dictionary = game.skills.toggle(part)
			_expect(activated.ok, "fixture activate " + part)
			game.hearts_current += int(activated.get("heart_credit", 0))


func _definitions_and_economy() -> void:
	var tree = Skills.new()
	_expect(tree.NODES.size() == 36 and tree.BRANCHES.size() == 6, "six genuinely forked branches contain 36 implemented skills")
	var ids := {}
	var effects := {}
	for definition in tree.NODES:
		_expect(not ids.has(definition.id), "unique node id " + str(definition.id))
		ids[definition.id] = true
		effects[definition.effect] = true
		_expect(definition.cost > 0 and not str(definition.desc).is_empty(), "each node has a cost and effect description")
		if not str(definition.parent).is_empty():
			_expect(ids.has(definition.parent) and tree.node(definition.parent).branch == definition.branch, "parent exists earlier in the same branch")
	for branch in tree.BRANCHES:
		var nodes: Array[Dictionary] = tree.branch_nodes(branch.id)
		_expect(nodes.size() == 6 and nodes.filter(func(n): return n.parent == nodes[0].id).size() == 2, "branch forks into two paths: " + str(branch.id))
	_expect(effects.size() == 17, "node effects cover distinct implemented modifier types")
	_expect(not tree.unlock("heart_1").ok and not tree.toggle("heart_1").ok, "cannot spend absent points or activate locked node")
	_expect(tree.award_floor(1) and not tree.award_floor(1) and tree.points == 1, "first completion gives one separate point exactly once")
	_expect(tree.unlock("heart_1").ok and tree.points == 0 and not tree.unlock("heart_1").ok, "unlock charges once and does not auto-equip")
	_expect(tree.active.is_empty(), "unlock and equip are distinct")
	var first: Dictionary = tree.toggle("heart_1")
	_expect(first.ok and first.heart_credit == 1 and tree.effect("heart_capacity") == 1, "first activation grants one heart credit")
	_expect(tree.toggle("heart_1").ok, "heart can be deactivated")
	var again: Dictionary = tree.toggle("heart_1")
	_expect(again.ok and again.heart_credit == 0, "reactivating a heart does not refill it")
	tree.points = 20
	_expect(not tree.unlock("heart_3").ok, "unlock respects prerequisites")
	_expect(tree.unlock("heart_2").ok and tree.unlock("heart_3").ok, "unlocks a dependent chain")
	_expect(not tree.toggle("heart_3").ok, "activation requires active parent")
	_expect(tree.toggle("heart_2").ok and tree.toggle("heart_3").ok, "activates valid chain")
	_expect(not tree.toggle("heart_1").ok, "cannot deactivate an active parent")
	var saved: Dictionary = tree.serialize()
	var other = Skills.new()
	_expect(other.load_state(saved) and other.serialize() == saved, "all tree state round-trips")
	var bad := saved.duplicate(true)
	bad.active.append("not-a-skill")
	_expect(not other.load_state(bad) and other.serialize() == saved, "unknown/corrupt nodes are rejected without changing the tree")
	bad = saved.duplicate(true)
	bad.version = 99
	_expect(not other.load_state(bad), "future skill schema is not silently downgraded")
	bad = saved.duplicate(true)
	bad.active.erase("heart_2")
	_expect(not other.load_state(bad), "corrupt active dependencies are rejected")
	tree.mark_legacy_floors({"2": 5, "3": 2})
	var balance: int = tree.points
	_expect(not tree.award_floor(2) and not tree.award_floor(3) and tree.points == balance, "legacy completed floors cannot be farmed for retroactive points")

	_reset_arena()
	for id in ["heart_3", "recovery_1", "shield_1", "speed_1", "freeze_1", "magnet_1"]:
		_equip(id)
	_expect(game.skills.active.size() == 8, "fixture fills eight equip slots")
	_expect(game.skills.unlock("breach_1").ok and not game.skills.toggle("breach_1").ok, "equip limit is enforced without charging twice")


func _damage_and_hearts() -> void:
	for count in 4:
		_reset_arena()
		if count > 0:
			_equip("heart_%d" % count)
		_expect(game.hearts_current == count and game.heart_capacity() == count, "initial heart credits match capacity %d" % count)
		for hit in count + 1:
			game.damage_this_turn = false
			var result: String = game._apply_damage("TESTE", Color.WHITE, Vector2i.RIGHT)
			_expect(result == ("heart" if hit < count else "capture"), "%d hearts: fatal event %d" % [count, hit + 1])
		_expect(game.hits_this_floor == count and events.count("HEART_LOST") == count, "one hit and feedback per lost heart")
	_reset_arena()
	_equip("heart_1")
	game.charges = 1
	_expect(game._apply_damage("TESTE", Color.WHITE) == "shield" and game.charges == 0 and game.hearts_current == 1, "shield is spent before heart")
	_expect(game._apply_damage("OUTRO", Color.WHITE) == "ignored" and game.hearts_current == 1, "two hazards in one action cost only one resource")
	game.damage_this_turn = false
	_expect(game._apply_damage("TESTE", Color.WHITE) == "heart" and game.hearts_current == 0, "next distinct hazard uses heart")
	game.damage_this_turn = false
	game.dev_god_mode = true
	_expect(game._apply_damage("TESTE", Color.WHITE) == "ignored" and game.game_state == "playing", "god mode spends nothing")

	_reset_arena()
	_equip("heart_1")
	var origin: Vector2i = game.player_position
	game.enemies.append(game._make_enemy(origin, "hunter"))
	game._check_enemy_collision(Vector2i.RIGHT)
	_expect(game.hearts_current == 0 and game.player_position == origin + Vector2i.LEFT and game.turn_number == 0, "enemy heart damage pushes player one legal cell without another turn")

	# No legal cell: the same enemy/body contact is guarded until separation.
	_reset_arena()
	_equip("heart_2")
	origin = game.player_position
	for direction in game.FOUR_WAY:
		game.grid[origin.y + direction.y][origin.x + direction.x] = game.TILE_WALL
	game.enemies.append(game._make_enemy(origin, "hunter"))
	game._check_enemy_collision(Vector2i.RIGHT)
	_expect(game.hearts_current == 1 and game.player_position == origin, "no-space recoil never crosses walls")
	game.damage_this_turn = false
	game._check_enemy_collision(Vector2i.ZERO)
	_expect(game.hearts_current == 1 and game.game_state == "playing", "same unseparated enemy cannot cause repeated damage on the next action")
	game.enemies.append(game._make_enemy(origin, "sentry"))
	game.damage_this_turn = false
	game._check_enemy_collision(Vector2i.ZERO)
	_expect(game.hearts_current == 0 and game.hits_this_floor == 2, "a different enemy is a new eligible contact")
	game.grid[origin.y][origin.x - 1] = game.TILE_FLOOR
	game._begin_player_move(origin + Vector2i.LEFT)
	game._begin_player_move(origin)
	game.damage_this_turn = false
	game._check_enemy_collision(Vector2i.RIGHT)
	_expect(game.game_state == "captured", "separation followed by a new contact is fatal without resources")

	_reset_arena()
	_equip("heart_2")
	origin = game.player_position
	for direction in game.FOUR_WAY:
		game.grid[origin.y + direction.y][origin.x + direction.x] = game.TILE_WALL
	game.traps.append({"pos": origin, "type": "one_shot", "armed": true, "revealed": false})
	game.enemies.append(game._make_enemy(origin, "hunter"))
	game.freeze_turns = 2
	game._take_turn()
	_expect(game.hearts_current == 1 and game.hits_this_floor == 1 and game.game_state == "playing", "trap plus enemy in one action consumes a single heart")
	game._take_turn()
	_expect(game.hearts_current == 1 and game.game_state == "playing", "suppressed overlapping contact is not charged on the next action")

	_reset_arena()
	_equip("heart_1")
	origin = game.player_position
	game.hearts_current = 1
	game.heart_pickups.append(origin + Vector2i.LEFT)
	game.traps.append({"pos": origin, "type": "one_shot", "armed": true, "revealed": true})
	game._take_turn(Vector2i.RIGHT)
	_expect(game.hearts_current == 1 and game.heart_pickups.is_empty(), "recoil collects an eligible heart on the landing cell")
	_expect(events.find("HEART_LOST") >= 0 and events.find("HEART_RECOVERED") > events.find("HEART_LOST"), "loss and recovery are separate, ordered semantic events")
	game.heart_pickups.append(game.player_position)
	game._collect_pickups()
	_expect(game.heart_pickups.has(game.player_position), "recovery pickup remains in place at full capacity")

	# Every new hot phase is a distinct trap activation, even when blocked in.
	_reset_arena()
	_equip("heart_3")
	origin = game.player_position
	for direction in game.FOUR_WAY:
		game.grid[origin.y + direction.y][origin.x + direction.x] = game.TILE_WALL
	game.traps.append({"pos": origin, "type": "rhythm", "phase": 2, "armed": true, "revealed": true})
	game._take_turn()
	game._take_turn()
	game._take_turn()
	_expect(game.hearts_current == 2, "one rhythm activation costs one heart; safe phases cost none")
	game._take_turn()
	_expect(game.hearts_current == 1 and events.count("HEART_LOST") == 2, "later hot rhythm phase is a new eligible event")

	_reset_arena()
	_equip("heart_1")
	origin = game.player_position
	var reserved_enemy: Dictionary = game._make_enemy(Vector2i(3, 3), "hunter")
	reserved_enemy.next = origin + Vector2i.LEFT
	game.enemies.append(reserved_enemy)
	game.traps.append({"pos": origin + Vector2i.UP, "type": "one_shot", "armed": true, "revealed": false})
	game.switches.append({"pos": origin + Vector2i.DOWN, "active": false})
	game.objective_type = "switches"
	game._apply_damage("TESTE", Color.WHITE, Vector2i.LEFT)
	_expect(game.player_position == origin + Vector2i.DOWN and game.switches[0].active, "heart recoil avoids reserved paths/hazards and activates a landing switch once")
	_expect(game.portal_open, "landing on the final switch opens the normal portal")

	_reset_arena()
	_equip("heart_1")
	game.lab_active = true
	game.charges = 0
	game._activate_powerup("speed")
	_expect(game.speed_turns == game.SPEED_DURATION and game.heart_capacity() == 0, "experimental chambers ignore campaign skills")
	_expect(game._apply_damage("LAB", Color.WHITE) == "capture" and game.hearts_current == 1, "laboratory damage cannot consume campaign hearts")


func _modifiers() -> void:
	_reset_arena()
	_equip("speed_3")
	game._activate_powerup("speed")
	_expect(game.speed_turns == game.SPEED_DURATION + 6, "three speed upgrades extend the actual pickup")
	_reset_arena()
	_equip("blink_2")
	game._activate_powerup("blink")
	_expect(game.blink_charges == 3, "blink charge upgrades add two real charges")
	game.try_blink()
	_expect(game.player_position == Vector2i(13, 7) and game.blink_charges == 2 and game.turn_number == 1, "blink range upgrade changes landing while retaining one charge and turn cost")
	_reset_arena()
	_equip("freeze_3")
	game._activate_powerup("time_freeze")
	_expect(game.freeze_turns == game.FREEZE_DURATION + 3, "freeze upgrades affect actual pickup duration")
	_reset_arena()
	_equip("freeze_4")
	game._activate_powerup("time_freeze")
	_expect(game.freeze_turns == game.FREEZE_DURATION + 2, "forked fourth freeze upgrade stacks with its root")
	var origin: Vector2i = game.player_position
	game.environment.reset({"cells": {origin: {"kind": "ice"}}})
	game._resolve_environment_displacement(Vector2i.RIGHT)
	_expect(game.player_position == origin, "ice grip suppresses actual forced slide")
	game.environment.reset({"cells": {origin: {"kind": "current", "flow": Vector2i.RIGHT}}})
	game._resolve_environment_displacement(Vector2i.RIGHT)
	_expect(game.player_position == origin, "anchor suppresses actual player current")
	_reset_arena()
	_equip("coin_bonus")
	game.coins.append(game.player_position + Vector2i(4, 0))
	game.magnet_turns = 4
	game.total_coins = 0
	game._collect_pickups()
	_expect(game.coins.is_empty() and game.coins_this_floor >= 1 and game.total_coins == 2, "magnet range uses reachable paths and coin bonus changes score")
	game._activate_powerup("magnet")
	_expect(game.magnet_turns == game.MAGNET_DURATION + 2, "magnet root extends pickup duration")
	_reset_arena()
	_equip("magnet_3")
	game._activate_powerup("magnet")
	_expect(game.magnet_turns == game.MAGNET_DURATION + 6, "magnet duration chain stacks")
	_reset_arena()
	_equip("breach_3")
	game.breakers.append(game.player_position)
	game._collect_pickups()
	_expect(game.breach_charges == 4, "demolition pickup chain grants real charges")
	_reset_arena()
	_equip("salvage")
	game.breach_charges = 1
	var elite: Dictionary = game._make_boss(game.player_position + Vector2i.RIGHT)
	elite.hp = 5
	elite.max_hp = 5
	game.enemies.append(elite)
	game.freeze_turns = 3
	game.try_break_wall()
	_expect(game.enemies.size() == 1 and game.enemies[0].hp == 2 and game.breach_charges == 0, "demolition damage upgrades apply to elites, spending charge")
	game.breach_charges = 1
	game.try_break_wall()
	_expect(game.enemies.is_empty() and game.breach_charges == 1, "recycling restores a charge only on an actual defeat")
	_reset_arena()
	_equip("shield_counter")
	game.charges = 1
	elite = game._make_boss(game.player_position)
	elite.hp = 5
	elite.max_hp = 5
	game.enemies.append(elite)
	game._check_enemy_collision()
	_expect(game.charges == 0 and game.enemies[0].hp == 3, "shield counter upgrade deals one extra elite damage")
	_reset_arena()
	_equip("shield_3")
	_expect(game.shield_capacity() == 6, "shield capacity chain expands base three")
	game.charges = 7
	game.shields.append(game.player_position)
	game._collect_pickups()
	_expect(game.charges == 7 and game.shields.has(game.player_position), "legacy over-cap shield balance is preserved and pickup stays")
	game.dev_give_resources()
	_expect(game.charges == 7, "developer resource helper does not delete legacy shields")
	_reset_arena()
	_equip("shield_pickup_2")
	game.charges = 0
	game.shields.append(game.player_position)
	game._collect_pickups()
	_expect(game.charges == 3, "shield pickup upgrades grant actual capped charges")
	game.charges = game.shield_capacity()
	game.shields.append(game.player_position)
	game._collect_pickups()
	_expect(game.shields.has(game.player_position), "full shield pickup stays on board")


func _generation_and_checkpoint() -> void:
	_reset_arena()
	game.new_game(923400)
	game.generate_floor(6)
	var baseline_grid: Array = game.grid.duplicate(true)
	var baseline_coins: Array = game.coins.duplicate()
	var baseline_shields: Array = game.shields.duplicate()
	var baseline_enemies: Array = game.enemies.duplicate(true)
	var baseline_rng: int = game.rng.state
	_equip("recovery_3")
	game.generate_floor(6)
	_expect(game.grid == baseline_grid and game.coins == baseline_coins and game.shields == baseline_shields and game.enemies == baseline_enemies and game.rng.state == baseline_rng, "heart pickup RNG does not change base generation or RNG state")
	var first_pickups: Array = game.heart_pickups.duplicate()
	game.generate_floor(6)
	_expect(game.heart_pickups == first_pickups, "heart spawn repeats for the same seed and skill state")
	var spawn_count := 0
	for seed_value in range(30):
		game.active_seed = 8000 + seed_value
		game.generate_floor(2)
		_expect(game.heart_pickups.size() <= 1, "at most one heart pickup per floor")
		if not game.heart_pickups.is_empty():
			spawn_count += 1
			_expect(game._reachable_cells(game.player_position).has(game.heart_pickups[0]) and game._is_floor(game.heart_pickups[0]), "spawned heart is reachable")
	_expect(spawn_count > 0 and spawn_count < 30, "sample contains both spawns and non-spawns; not a frequency/balance proof")

	_reset_arena()
	game.new_game(12345)
	game.portal_open = true
	game.player_position = game.portal_position
	game._check_portal()
	_expect(game.skills.points == 1 and game.last_skill_point_awarded, "real portal awards a point on first clear")
	game.handle_hud_action("skills")
	_expect(game.game_state == "skill_tree", "result opens the skill tree")
	game.handle_hud_action("skill_unlock")
	_expect(game.skills.unlocked.has("heart_1") and game.hearts_current == 0, "real UI action unlocks without activating")
	game.handle_hud_action("skill_toggle")
	_expect(game.hearts_current == 1 and game.resume_hearts == 1, "activation persists heart at the next-floor checkpoint")
	game.handle_hud_action("skill_toggle")
	_expect(game.game_state == "skill_confirm", "removing a full heart asks for confirmation")
	game.handle_hud_action("skill_remove_cancel")
	_expect(game.hearts_current == 1 and game.skills.active.has("heart_1"), "cancel loses no hearts")
	game.handle_hud_action("skill_toggle")
	game.handle_hud_action("skill_remove_confirm")
	_expect(game.hearts_current == 0 and not game.skills.active.has("heart_1"), "confirmed capacity reduction discards only the excess")
	game.handle_hud_action("skill_toggle")
	_expect(game.hearts_current == 0 and game.skills.active.has("heart_1"), "reactivation through UI cannot refill")
	# Continue the checkpoint test with a legitimately recovered heart.
	game.hearts_current = 1
	game._save_skill_choice()
	game.handle_hud_action("skill_back")
	game.advance_floor()
	_expect(game.hearts_current == 1 and game.floor_start_snapshot.hearts == 1, "next floor keeps remaining heart and snapshot")
	game.hearts_current = 0
	game.restart_floor()
	_expect(game.hearts_current == 1, "R restores the heart snapshot at entry, not a full heal")
	game.hearts_current = 0
	game.generate_floor(game.floor_number)
	game._save_resume(game.floor_number, game.total_coins, game.charges, game.breach_charges, game.floor_history, game.facing)
	game.hearts_current = 1
	game.restart_floor()
	_expect(game.hearts_current == 0 and game.resume_hearts == 0, "R does not heal a checkpoint that started with an empty heart")
	game.hearts_current = 1
	game.furthest_floor = 25
	game.total_coins = 27
	game.charges = 2
	game.breach_charges = 3
	game._restore_power_state({"speed_turns": 5, "speed_phase": 1, "magnet_turns": 6, "freeze_turns": 2, "blink_charges": 4})
	game.game_state = "paused"
	game.open_level_select()
	game.start_level(1)
	_expect(game.total_coins == 27 and game.charges == 2 and game.breach_charges == 3 and game.hearts_current == 1 and game.skills.active.has("heart_1"), "revisiting preserves campaign inventory, heart and active skill")
	_expect(game.speed_turns == 5 and game.speed_phase == 1 and game.magnet_turns == 6 and game.freeze_turns == 2 and game.blink_charges == 4, "revisiting preserves power durations, phase and charges")
	game.portal_open = true
	game.player_position = game.portal_position
	game._check_portal()
	_expect(game.skills.points == 0 and not game.last_skill_point_awarded, "replaying a completed floor does not award another point")


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.feedback_bus.event_emitted.connect(_event)
	_definitions_and_economy()
	_damage_and_hearts()
	_modifiers()
	_generation_and_checkpoint()
	if failures.is_empty():
		print("SKILL_TREE_TEST_PASS checks=%d: tree, hearts, effects, rewards, RNG and checkpoints" % checks)
	else:
		printerr("SKILL_TREE_TEST_FAIL %d/%d: %s" % [failures.size(), checks, "; ".join(failures)])
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
