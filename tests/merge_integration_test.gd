extends SceneTree

# Integration regression tests for the two previously diverged branches. The
# rules remain authoritative in EnvironmentSystem and CampaignStorage; no
# independent shadow copies of crate/electric/campaign state are introduced.
const Game = preload("res://game.gd")
const Special = preload("res://special_levels.gd")
const Modules = preload("res://sokoban_generator.gd")
const Haptics = preload("res://haptic_mixer.gd")
const Feedback = preload("res://tactical_feedback.gd")

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
	_test_story()
	_test_environment_interactions()
	_test_sokoban_and_undo()
	_test_profile_and_sandbox()
	if failures.is_empty():
		print("MERGE_INTEGRATION_TEST_PASS checks=", checks, " story, campaign isolation, freeze, brittle ice, authored Sokoban and undo")
	else:
		printerr("MERGE_INTEGRATION_TEST_FAIL count=", failures.size(), " checks=", checks)
	game.persistence_enabled = false
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_story() -> void:
	game.new_game(2031)
	for cue in ["captor_reveal", "crate_wood", "crate_metal", "crate_push", "current", "ice_crack", "electric_water"]:
		_expect(game.audio.effects.has(cue) and game.audio.effects[cue].data.size() > 0, "merged audio cue exists: " + cue)
	_expect(Haptics.PATTERNS.has("crate_push") and Haptics.PATTERNS.has("current") and Haptics.PATTERNS.has("ice_crack"), "crate, current and ice haptic patterns coexist")
	_expect(Feedback.EVENTS.has("CRATE_PUSH_WOOD") and Feedback.EVENTS.has("CURRENT_DRIFT") and Feedback.EVENTS.has("ICE_CRACK"), "material, current and ice semantic events coexist")
	_expect(game.player_sphere_texture != null and game.lia_sphere_texture != null, "both orbs have a generated texture")
	var red: Image = game.player_sphere_texture.get_image()
	var pink: Image = game.lia_sphere_texture.get_image()
	_expect(red != null and pink != null and red.get_size() == pink.get_size() and red.get_data() != pink.get_data(), "Lia shares the orb resolution and volume but has her own palette")
	game.floor_number = 4
	game.game_state = "floor_clear"
	game.advance_floor()
	_expect(game.floor_number == 5 and game.captor_intro_seen and game.captor_flyover_time > 0.0, "first arrival on floor five starts the cinematic")
	var before_position: Vector2i = game.player_position
	var before_turn: int = game.turn_number
	var before_rng: int = game.rng.state
	game.try_move(1, 0)
	game.wait_turn()
	game._on_controller_action("up")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	game._unhandled_key_input(key)
	_expect(game.player_position == before_position and game.turn_number == before_turn and game.rng.state == before_rng, "cinematic blocks turns from direct, keyboard and controller input")
	game.handle_hud_action("skip_captor_flyover")
	_expect(is_zero_approx(game.captor_flyover_time), "touch/HUD skip finishes the flyover")
	game._begin_captor_flyover_if_needed()
	_expect(is_zero_approx(game.captor_flyover_time), "the scene does not repeat in the same campaign")
	game.captor_intro_seen = false
	game._begin_captor_flyover_if_needed()
	game._on_controller_action("cancel")
	_expect(is_zero_approx(game.captor_flyover_time), "controller can skip the cinematic")
	game.captor_intro_seen = false
	game._begin_captor_flyover_if_needed()
	key.keycode = KEY_ENTER
	game._unhandled_key_input(key)
	_expect(is_zero_approx(game.captor_flyover_time), "keyboard can skip the cinematic")
	game.game_state = "playing"
	game.player_position = game.portal_position
	game.portal_open = true
	game._check_portal()
	_expect(game.game_state == "rescued" and game.rescues_completed == 0, "floor five reveals Lia without counting a rescue")
	game.generate_floor(100)
	game.game_state = "playing"
	game.player_position = game.portal_position
	game.portal_open = true
	game._check_portal()
	_expect(game.game_state == "rescued" and game.rescues_completed == 1, "floor 100 records the rescue")
	game.generate_floor(100)
	game.game_state = "playing"
	game.player_position = game.portal_position
	game.portal_open = true
	game._check_portal()
	_expect(game.rescues_completed == 1, "revisiting floor 100 does not count another rescue")
	game.new_game(2032)
	_expect(not game.captor_intro_seen and game.rescues_completed == 0, "a new campaign has its own story flags")


func _clean_lab() -> void:
	game.start_environment_lab()
	game.enemies.clear()
	game.coins.clear()
	game.shields.clear()
	game.heart_pickups.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.traps.clear()
	game.switches.clear()
	game.charges = 0
	game.breach_charges = 0
	game._restore_power_state({})
	game.player_position = Vector2i(2, 4)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.portal_position = Vector2i(10, 4)
	game.game_state = "playing"
	game.turn_number = 0
	game.moves_this_floor = 0
	game.hits_this_floor = 0
	game.dev_god_mode = false
	game.dev_noclip = false


func _test_environment_interactions() -> void:
	_clean_lab()
	var entry := Vector2i(3, 4)
	var float_cell := Vector2i(5, 4)
	game.environment.reset({"cells": {
		entry: {"kind": "current", "flow": Vector2i.RIGHT, "source": true},
		float_cell: {"kind": "current", "flow": Vector2i.RIGHT},
	}, "crates": [{"pos": float_cell, "material": "wood"}]})
	game.grid[entry.y][entry.x] = game.TILE_WATER
	game.grid[float_cell.y][float_cell.x] = game.TILE_WATER
	game.powerups.append({"pos": entry, "kind": "time_freeze"})
	game.try_move(1, 0)
	_expect(game.player_position == entry and game.hits_this_floor == 0 and game.freeze_turns == 3, "freeze pickup protects from electricity and holds the current on the pickup action")
	_expect(game.environment.crates[0].pos == float_cell, "freeze pickup holds floating wood before the current phase")
	game.wait_turn()
	_expect(game.player_position == entry and game.environment.crates[0].pos == float_cell and game.freeze_turns == 2, "active freeze keeps player and floating crate still")
	game.wait_turn()
	game.wait_turn()
	_expect(game.freeze_turns == 0 and game.player_position == entry and game.environment.crates[0].pos == float_cell, "freeze protects through its final spent action")
	game.environment.cells[entry].source = false
	game.environment.refresh_electricity()
	game.wait_turn()
	_expect(game.player_position == Vector2i(4, 4) and game.environment.crates[0].pos == Vector2i(6, 4), "player and wood resume drifting after freeze expires")
	_clean_lab()
	game.environment.reset({"cells": {entry: {"kind": "water", "source": true}}})
	game.grid[entry.y][entry.x] = game.TILE_WATER
	game.charges = 1
	game.try_move(1, 0)
	_expect(game.hits_this_floor == 1 and game.charges == 0, "unfrozen electrical water still applies the ordinary shield impact")
	# Traps still operate under freeze; this is intentionally different from
	# electrical protection and does not suspend the rhythm clock.
	_clean_lab()
	game.environment.reset()
	game.player_position = Vector2i(3, 4)
	game.traps.append({"pos": game.player_position, "type": "rhythm", "phase": 2, "armed": true, "revealed": true})
	game.freeze_turns = 2
	game.charges = 1
	game.wait_turn()
	_expect(game.charges == 0 and game.hits_this_floor == 1 and game.freeze_turns == 1, "a rhythm trap still damages while time freeze is active")
	_clean_lab()
	var thin := Vector2i(3, 4)
	game.grid[thin.y][thin.x] = game.TILE_WATER
	game.environment.reset({"cells": {thin: {"kind": "ice", "brittle": true, "stress": 0, "broken": false}}})
	game.try_move(1, 0)
	_expect(game.player_position == Vector2i(4, 4) and int(game.environment.cells[thin].stress) == 1, "first brittle-ice crossing slides one cell and records one contact")
	game.try_move(-1, 0)
	_expect(game.player_position == Vector2i(2, 4) and int(game.environment.cells[thin].stress) == 2, "second crossing slides and records two contacts")
	game.try_move(1, 0)
	_expect(game.player_position == Vector2i(4, 4) and bool(game.environment.cells[thin].broken), "third crossing completes the slide before the tile breaks")
	game.try_move(-1, 0)
	_expect(game.player_position == thin and not game.environment.is_slippery_ice(thin), "broken ice remains walkable but no longer slides")
	game._load_lab_chamber(2)
	_expect(not bool(game.environment.cells[thin].broken) and int(game.environment.cells[thin].stress) == 0, "restarting the practice chamber resets brittle-ice state")
	# Seeded generation is deterministic and keeps the full original connected
	# area reachable even if the optional brittle cell is avoided.
	game.active_seed = 48211
	game.generate_floor(4)
	var first: Dictionary = game.environment.cells.duplicate(true)
	var first_grid: Array = game.grid.duplicate(true)
	var first_rng: int = game.rng.state
	game.generate_floor(4)
	_expect(game.environment.cells == first and game.grid == first_grid and game.rng.state == first_rng, "seeded brittle placement is deterministic without advancing the gameplay RNG")
	for point in game.environment.cells:
		if bool(game.environment.cells[point].get("brittle", false)):
			var reachable: Array[Vector2i] = game._reachable_cells(game.player_position)
			_expect(game._reachable_without_cell(game.player_position, point) == reachable.size() - 1, "the entire originally reachable floor remains connected without the optional brittle cell")


func _simple_sokoban() -> void:
	game.active_seed = 1
	game.floor_number = 7
	game.special_family = "sokoban"
	game.lab_active = false
	var spec: Dictionary = Special.make("sokoban", 1, 7)
	var plan: Dictionary = Special.solve(spec, spec.start, spec.crates)
	_expect(int(plan.length) > 0, "introductory Sokoban room has a solver-verified route")
	game._generate_special_room(spec, plan, 1234)
	game.game_state = "playing"
	game.charges = 0
	game.breach_charges = 0
	game._restore_power_state({})
	game.coins.clear()
	game.shields.clear()
	game.heart_pickups.clear()
	game.breakers.clear()
	game.powerups.clear()
	game.total_coins = 0
	game.best_score = 0
	game.best_score_dirty = false


func _test_sokoban_and_undo() -> void:
	# Both authored base modules and both orientations use the existing solver.
	for floor_number in [17, 23]:
		for seed_number in [1, 3]:
			var spec: Dictionary = Special.make("sokoban", seed_number, floor_number)
			var plan: Dictionary = Special.solve(spec, spec.start, spec.crates)
			_expect(int(plan.length) > 0 and not bool(plan.truncated), "imported Sokoban module is solver-verified for floor %d seed %d" % [floor_number, seed_number])
			var module: Dictionary = Modules.new().generate(floor_number, seed_number ^ (floor_number * 7919))
			_expect(spec.size == module.size and spec.crates.size() == module.boxes.size() and spec.plates.size() == module.goals.size(), "module boxes and goals use the shared environment system")
	_simple_sokoban()
	var origin: Vector2i = game.player_position
	var entered := origin + Vector2i.RIGHT
	game.coins.append(entered)
	game.powerups.append({"pos": entered, "kind": "time_freeze"})
	var before: Dictionary = game._snapshot_sokoban()
	game.try_move(1, 0)
	_expect(game.sokoban_pushes == 1 and game.sokoban_history.size() == 1 and game.total_coins == 1 and game.freeze_turns == 3, "a real push collects loot and records a single pre-action state")
	game.undo_sokoban_move()
	_expect(game._snapshot_sokoban() == before and game.sokoban_history.is_empty(), "undo restores box, power, loot, score, counts and RNG together")
	game.try_move(1, 0)
	var before_second: Dictionary = game._snapshot_sokoban()
	game.try_move(1, 0)
	_expect(game.portal_open and game.sokoban_pushes == 2, "two real pushes activate the held plate and open the portal")
	game.handle_hud_action("undo_sokoban")
	_expect(game._snapshot_sokoban() == before_second and not game.portal_open, "HUD undo restores the previously closed portal and plate")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_Z
	game._unhandled_key_input(key)
	_expect(game._snapshot_sokoban() == before, "Z undoes the earlier push and returns the pickup")
	var history_size: int = game.sokoban_history.size()
	game.player_position = Vector2i(1, 1)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.try_move(-1, 0)
	_expect(game.sokoban_history.size() == history_size, "blocked movement does not add undo history")
	_simple_sokoban()
	before = game._snapshot_sokoban()
	game.wait_turn()
	game.undo_sokoban_move()
	_expect(game._snapshot_sokoban() == before, "undo restores wait, turn and power durations")
	game.charges = 1
	game.facing = Vector2i.DOWN
	before = game._snapshot_sokoban()
	game.try_jump()
	_expect(game.player_position != before.player and game.charges == 0, "jump is still available in a Sokoban room")
	game.undo_sokoban_move()
	_expect(game._snapshot_sokoban() == before, "undo restores jump and its shield cost")
	game.blink_charges = 1
	game.facing = Vector2i.DOWN
	before = game._snapshot_sokoban()
	game.try_blink()
	_expect(game.player_position != before.player and game.blink_charges == 0, "blink is still available in a Sokoban room")
	game.undo_sokoban_move()
	_expect(game._snapshot_sokoban() == before, "undo restores blink and its charge")
	game.grid[2][2] = game.TILE_WALL
	game.facing = Vector2i.UP
	game.breach_charges = 1
	before = game._snapshot_sokoban()
	game.try_break_wall()
	_expect(game.grid[2][2] == game.TILE_FLOOR and game.breach_charges == 0, "demolition remains available in a Sokoban room")
	game.undo_sokoban_move()
	_expect(game._snapshot_sokoban() == before and game.grid[2][2] == game.TILE_WALL, "undo restores demolished wall and resource")
	_simple_sokoban()
	for _index in 140:
		game.wait_turn()
	_expect(game.sokoban_history.size() == game.SOKOBAN_HISTORY_LIMIT, "undo history is bounded")
	game.generate_floor(1)
	_expect(game.sokoban_history.is_empty() and game.sokoban_pushes == 0, "floor transitions discard undo history")


func _test_profile_and_sandbox() -> void:
	# Unique temporary profile: only files bearing this test's own prefix are
	# removed, so the user's actual save and other test runs are never touched.
	var path := "user://merge-integration-%d.cfg" % Time.get_ticks_usec()
	game.profile_path = path
	game.persistence_enabled = true
	game.profile_blocked = false
	game.active_slot = 0
	game.new_game(55231)
	game.furthest_floor = 5
	game.start_level(5)
	var slot_path: String = game.campaign_storage.slot_path(0)
	var stored: Dictionary = game.campaign_storage.read_slot(0)
	_expect(stored.status == "ok" and bool(stored.data.get("captor_intro_seen", false)), "cinematic flag is saved in the active campaign")
	var reader = Game.new()
	reader.profile_path = path
	root.add_child(reader)
	reader.audio.effects_enabled = false
	_expect(reader.captor_intro_seen and reader.furthest_floor >= 5, "cinematic flag survives a fresh profile load")
	reader.start_level(5)
	_expect(is_zero_approx(reader.captor_flyover_time), "loaded campaign does not replay the cinematic")
	reader.queue_free()
	game.handle_hud_action("skip_captor_flyover")
	_expect(game.select_campaign(1), "a second campaign can be selected")
	game.new_game(12389)
	_expect(not game.captor_intro_seen, "the second campaign has an independent unplayed introduction")
	_expect(game.select_campaign(0) and game.captor_intro_seen, "switching back restores the first campaign's introduction flag")
	game.continue_game()
	game.total_coins = 17
	game.charges = 1
	game.best_score = 23
	game.best_score_dirty = true
	game.dev_jump_floor(50)
	_expect(game.dev_sandbox_active and not game.best_score_dirty, "entering dev mode first preserves a legitimate pending record")
	var global_before := FileAccess.get_sha256(path)
	var slot_before := FileAccess.get_sha256(slot_path)
	var saved_campaign: Dictionary = game.dev_profile_snapshot.campaign.duplicate(true)
	game.total_coins = 777
	game.best_score = 777
	game.floor_stars["50"] = 5
	game.furthest_floor = 80
	game.skills.points = 12
	game._save_resume(51, 777, 3, 3, [5], Vector2i.RIGHT)
	_expect(FileAccess.get_sha256(path) == global_before and FileAccess.get_sha256(slot_path) == slot_before, "dev floor checkpoints never write the real global file or campaign slot")
	game.handle_hud_action("menu")
	_expect(not game.dev_sandbox_active and game._campaign_payload() == saved_campaign and game.total_coins == 17 and game.charges == 1, "leaving dev restores campaign, skills, score and in-memory resources")
	game.continue_game()
	_expect(game.floor_number == 5 and game.total_coins == game.resume_coins, "continue returns to the saved checkpoint rather than the dev floor")
	game.dev_load_sandbox_arena()
	_expect(game.objective_type == "escape" and game.portal_open and not game.environment_bonus_available, "the dev arena resets an inherited puzzle objective")
	game.dev_give_resources()
	game.dev_open_portal()
	game.player_position = game.portal_position
	game._check_portal()
	game.handle_hud_action("menu")
	_expect(FileAccess.get_sha256(path) == global_before and FileAccess.get_sha256(slot_path) == slot_before and game._campaign_payload() == saved_campaign, "completing the dev arena also leaves both saves untouched")
	game.profile_blocked = true
	game.best_score_dirty = true
	game.dev_jump_floor(10)
	_expect(not game.dev_sandbox_active and game.game_state == "title", "dev entry is refused when an unsaved legitimate record cannot be stored safely")
	game.profile_blocked = false
	game.best_score_dirty = false
	game.persistence_enabled = false
	var cleanup_paths: Array[String] = [path, path + ".bak", path + ".legacy.bak"]
	for index in range(3):
		cleanup_paths.append(game.campaign_storage.slot_path(index))
		cleanup_paths.append(game.campaign_storage.backup_path(index))
		cleanup_paths.append(game.campaign_storage.replaced_path(index))
	for candidate in cleanup_paths:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
