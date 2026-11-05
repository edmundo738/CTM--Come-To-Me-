extends SceneTree

# The main route below uses real movement/push/wait/undo/portal actions. The
# explicitly labelled collision and danger fixtures are separate adversarial
# arrangements, not claims that a solver exhausts all reachable states.
const Game = preload("res://game.gd")
const Installation = preload("res://submerged_installation.gd")
const DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

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


func _event(name: String, _context: Dictionary) -> void:
	events.append(name)


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.controller.vibration_enabled = false
	game.feedback_bus.event_emitted.connect(_event)
	await process_frame
	_test_authored_geometry()
	_test_complete_route_and_profile()
	_test_closed_gate_and_water_hazard()
	_test_corner_recovery()
	_test_bounded_undo()
	if failures.is_empty():
		print("SUBMERGED_INSTALLATION_TEST_PASS checks=", checks, " real route, doors, electricity, latches, drainage, undo, reset and campaign isolation")
	else:
		printerr("SUBMERGED_INSTALLATION_TEST_FAIL count=", failures.size(), " checks=", checks)
	game.persistence_enabled = false
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _move(direction: Vector2i, times: int = 1) -> void:
	for _i in times:
		if game.game_state != "playing":
			_expect(false, "move requires playing state; got " + game.game_state)
			return
		var before: Vector2i = game.player_position
		var turn: int = game.turn_number
		game.try_move(direction.x, direction.y)
		_expect(game.player_position == before + direction, "real move from %s to %s" % [before, before + direction])
		_expect(game.turn_number == turn + 1, "each accepted movement consumes exactly one turn")
		if game.player_position != before + direction:
			return


# Test navigation uses the actual current board, never a teleport. It avoids
# other consoles while walking to a requested target, so their side effects are
# checked at deliberate points. It is not a general state-space solver.
func _walk_to(goal: Vector2i) -> void:
	var start: Vector2i = game.player_position
	if start == goal:
		return
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var head := 0
	while head < queue.size() and not previous.has(goal):
		var point := queue[head]
		head += 1
		for direction in DIRS:
			var next: Vector2i = point + direction
			if previous.has(next) or not game._is_floor(next):
				continue
			var other_console := false
			for item in game.switches:
				if item.pos == next and next != goal and not bool(item.get("hidden", false)):
					other_console = true
					break
			if other_console:
				continue
			previous[next] = point
			queue.append(next)
	if not previous.has(goal):
		_expect(false, "walkable path from %s to %s" % [start, goal])
		return
	var reverse: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		var prior: Vector2i = previous[cursor]
		reverse.append(cursor - prior)
		cursor = prior
	reverse.reverse()
	for direction in reverse:
		var before: Vector2i = game.player_position
		_move(direction)
		if game.player_position != before + direction or game.game_state not in ["playing", "floor_clear"]:
			return
	_expect(game.player_position == goal, "reached %s using real turns" % goal)


func _gate(id: String) -> Dictionary:
	for gate in game.environment.gates:
		if gate.get("id", "") == id:
			return gate
	return {}


func _crate(id: String) -> Dictionary:
	for crate in game.environment.crates:
		if crate.get("id", "") == id:
			return crate
	return {}


func _switch(group: String, index: int) -> Dictionary:
	for item in game.switches:
		if item.get("group", "") == group and int(item.get("index", -1)) == index:
			return item
	return {}


func _door_state() -> Array[bool]:
	return [bool(_gate("door_a").open), bool(_gate("door_b").open), bool(_gate("door_c").open)]


func _test_authored_geometry() -> void:
	var spec: Dictionary = Installation.chamber()
	var size: Vector2i = spec.size
	_expect(size == Vector2i(25, 25), "the compact authored chamber retains its intended dimensions")
	var wall_cells: Dictionary = {}
	for point in spec.walls:
		_expect(point.x > 0 and point.y > 0 and point.x < size.x - 1 and point.y < size.y - 1 and not wall_cells.has(point), "authored wall is unique and inside the border")
		wall_cells[point] = true
	var interactive_cells: Dictionary = {}
	for category in ["crates", "plates", "gates", "switches"]:
		for item in spec[category]:
			var point: Vector2i = item.pos
			_expect(point.x > 0 and point.y > 0 and point.x < size.x - 1 and point.y < size.y - 1 and not wall_cells.has(point), "%s is on an interior non-wall cell" % category)
			_expect(not interactive_cells.has(point), "%s does not overlap another authored interaction" % category)
			interactive_cells[point] = true
	for point in [spec.start, spec.portal, Installation.PANEL, Installation.DRAIN_VALVE]:
		_expect(point.x > 0 and point.y > 0 and point.x < size.x - 1 and point.y < size.y - 1 and not wall_cells.has(point) and not interactive_cells.has(point), "start, portal and visual clues do not overlap walls or interactions")
	_expect(spec.cells.size() == 52 and spec.cells.has(Installation.SOURCE) and not bool(spec.cells[Installation.SOURCE].source), "all water and its initially unpowered source belong to this room")


func _test_complete_route_and_profile() -> void:
	# A unique prefix keeps this regression independent of real saves and other
	# test runs, including its campaign slots and backups.
	var path := "user://submerged-test-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.profile_path = path
	game.persistence_enabled = true
	game.new_game(705)
	var profile_before := FileAccess.get_file_as_bytes(path)
	var slot_path: String = game.campaign_storage.slot_path(game.active_slot)
	var slot_before := FileAccess.get_file_as_bytes(slot_path)
	var backup_path: String = game.campaign_storage.backup_path(game.active_slot)
	var backup_existed := FileAccess.file_exists(backup_path)
	var backup_before := FileAccess.get_file_as_bytes(backup_path) if backup_existed else PackedByteArray()
	_expect(not profile_before.is_empty() and not slot_before.is_empty(), "the disposable global profile and campaign slot were written before the test")
	var campaign_before := [game.has_resume, game.resume_floor, game.resume_coins, game.resume_charges,
		game.resume_breach_charges, game.resume_seed, game.resume_history.duplicate(),
		game.resume_powers.duplicate(true), game.floor_stars.duplicate(true), game.furthest_floor, game.best_score]
	game.handle_hud_action("submerged_installation")
	_expect(game.lab_active and game.lab_index == Installation.LAB_INDEX and game.objective_type == "submerged", "direct title entry uses the existing isolated chamber flow")
	_expect(game.enemies.is_empty() and game.charges == 0 and game.blink_charges == 0 and game.breach_charges == 0, "reference chamber starts without enemies or bypass resources")
	_expect(_door_state() == [true, false, false], "exactly door A starts open")
	_expect(not game.portal_open and not game.environment.is_electrified(Installation.SOURCE), "portal closed and initial water unpowered")
	_expect(_switch("drain", 0).hidden and _switch("drain", 1).hidden and _switch("drain", 2).hidden, "submerged terminals are hidden initially")
	var before_turn: int = game.turn_number
	var before_pos: Vector2i = game.player_position
	game.try_move(2, 0)
	_expect(game.turn_number == before_turn and game.player_position == before_pos, "invalid input consumes no turn")

	# A: take wood to its held plate, then verify the hatch latches even if the
	# crate is moved away, and that undo restores the complete prior state.
	_walk_to(Vector2i(4, 2))
	_move(Vector2i.DOWN, 7)
	_expect(_crate("wood_hatch").pos == Vector2i(4, 10), "wood reaches the hatch plate through A")
	_expect(game.submerged.hatch_open and _gate("hatch").open, "first plate opens the hatch")
	_walk_to(Vector2i(3, 10))
	_move(Vector2i.RIGHT)
	_expect(not game.environment.plates[0].active and _gate("hatch").open, "hatch remains open after its plate is released")
	game.undo_sokoban_move()
	_expect(_crate("wood_hatch").pos == Vector2i(4, 10) and game.environment.plates[0].active and game.submerged.hatch_open, "undo restores the crate, plate and latch")

	# Selecting and waiting never uses a timer, and the later hatch is not part
	# of the three-door group.
	_walk_to(Vector2i(12, 8))
	_expect(_door_state() == [false, true, false] and _gate("hatch").open, "B alone opens without closing the hatch")
	var event_count := events.count("SWITCH_ON")
	before_turn = game.turn_number
	for _i in 12:
		game.wait_turn()
	_expect(game.turn_number == before_turn + 12 and _door_state() == [false, true, false], "selection persists across twelve committed waits")
	_expect(events.count("SWITCH_ON") == event_count, "waiting on a console does not activate it again")
	_walk_to(Vector2i(20, 8))
	_expect(_door_state() == [false, false, true] and _gate("hatch").open, "C alone opens and independent hatch stays open")
	_walk_to(Vector2i(12, 8))
	_expect(_door_state() == [false, true, false], "B can be selected again")

	# B: the actual generator is pushed through B, turned in the hub, and
	# docked through the permanent hatch. Undo the docking and perform it again.
	_walk_to(Vector2i(12, 2))
	_move(Vector2i.DOWN, 6)
	_walk_to(Vector2i(13, 9))
	_move(Vector2i.LEFT, 6)
	_walk_to(Vector2i(6, 8))
	_move(Vector2i.DOWN, 6)
	_expect(_crate("generator").pos == Installation.SOCKET and _crate("generator").locked, "real pushes install and lock the same generator")
	_expect(game.submerged.generator_on and game.submerged.passage_open and _gate("powered_passage").open, "installation powers and permanently opens the independent passage")
	_expect(game.environment.is_electrified(Installation.SOURCE), "real source energizes connected water")
	game.undo_sokoban_move()
	_expect(not game.submerged.generator_installed and not game.submerged.passage_open and not game.environment.is_electrified(Installation.SOURCE), "undo docking restores power, source and passage")
	_expect(_crate("generator").pos == Vector2i(6, 14) and not bool(_crate("generator").get("locked", false)), "undo releases the generator at its previous cell")
	_move(Vector2i.DOWN)
	_expect(game.submerged.generator_installed and game.environment.is_electrified(Installation.SOURCE), "generator can be installed again after undo")
	before_turn = game.turn_number
	event_count = events.size()
	game._sync_environment_mechanisms()
	game._sync_environment_mechanisms()
	_expect(game.turn_number == before_turn and events.size() == event_count, "repeated mechanism synchronization is idempotent and costs no actions")

	# C: wrong entries reset only the sequence; waits do not repeat a terminal.
	_walk_to(Vector2i(20, 8))
	_expect(_door_state() == [false, false, true] and _gate("hatch").open and _gate("powered_passage").open, "C selection leaves both later passages open")
	_walk_to(Vector2i(18, 3))
	_expect(game.submerged.sequence_progress == 0 and game.last_notice.contains("ERRADA"), "wrong first terminal reports an error")
	_walk_to(Vector2i(20, 3))
	_expect(game.submerged.sequence_progress == 1 and _switch("sequence", 1).active, "II is accepted first")
	event_count = events.count("SWITCH_ON")
	game.wait_turn()
	_expect(game.submerged.sequence_progress == 1 and events.count("SWITCH_ON") == event_count, "waiting does not repeat a sequence entry")
	_walk_to(Vector2i(8, 15))
	_expect(not game.submerged.generator_on and game.submerged.sequence_progress == 1 and _switch("sequence", 1).active, "partial sequence survives turning the generator off")
	_walk_to(Vector2i(8, 14))
	_walk_to(Vector2i(8, 15))
	_expect(game.submerged.generator_on and game.submerged.sequence_progress == 1, "partial sequence survives turning the generator on again")
	_walk_to(Vector2i(20, 3))
	_walk_to(Vector2i(22, 3))
	_expect(game.submerged.sequence_progress == 0 and not _switch("sequence", 1).active, "wrong next terminal resets feedback and progress")
	_walk_to(Vector2i(20, 3))
	_walk_to(Vector2i(18, 3))
	_walk_to(Vector2i(22, 3))
	_expect(game.submerged.sequence_complete and game.submerged.sequence_progress == 3 and _gate("flooded_room").open, "II > I > III permanently opens the flooded room")
	_expect(events.has("PUZZLE_ERROR") and events.has("SWITCH_ON"), "correct and incorrect actions emit distinct feedback events")
	_walk_to(Vector2i(18, 16))
	_expect(game.environment.is_electrified(Vector2i(18, 17)) and game.submerged.hint().contains("FONTE"), "live water and its source are indicated before entry")

	# Return to I/O; changing the three-door selection afterward must not erase
	# any of the independent permanent unlocks or remove the installed generator.
	_walk_to(Vector2i(8, 15))
	_expect(not game.submerged.generator_on and _crate("generator").pos == Installation.SOCKET and _crate("generator").locked, "I/O turns power off without removing the generator")
	game.wait_turn()
	_expect(not game.submerged.generator_on, "waiting on I/O does not accidentally toggle power again")
	_expect(not game.environment.is_electrified(Installation.SOURCE) and game.submerged.sequence_complete, "power off makes water safe without erasing the sequence")
	_expect(_gate("hatch").open and _gate("powered_passage").open and _gate("flooded_room").open, "all earned passages remain open without power")
	_walk_to(Vector2i(7, 15))
	before_turn = game.turn_number
	game.try_move(-1, 0)
	_expect(game.turn_number == before_turn and _crate("generator").pos == Installation.SOCKET and game.last_notice.contains("GERADOR FIXO"), "installed generator cannot be pushed and the blocked action costs no turn")
	_walk_to(Vector2i(12, 8))
	_expect(_door_state() == [false, true, false] and _gate("flooded_room").open, "B selection does not close later gates")
	_walk_to(Vector2i(20, 8))
	_expect(_door_state() == [false, false, true] and _gate("powered_passage").open, "C selection does not close later gates")

	# Cross safe water and use the second wood crate. Undoing drainage restores
	# logical cells, visual terrain list, terminals, plate, crate and latches.
	_walk_to(Vector2i(12, 19))
	_move(Vector2i.RIGHT, 3)
	_expect(game.submerged.drained and not game.environment.is_water(Installation.SOURCE) and game.grid[17][18] == game.TILE_FLOOR, "second wood plate drains the water logically and visually")
	_expect(game.terrain_renderer.water_cells.is_empty() and not _switch("drain", 0).hidden, "drained terrain and newly revealed terminals agree")
	game.undo_sokoban_move()
	_expect(not game.submerged.drained and game.environment.is_water(Installation.SOURCE) and game.grid[17][18] == game.TILE_WATER, "undo restores water and drainage state")
	_expect(game.terrain_renderer.water_cells.size() == 52 and _switch("drain", 0).hidden and _crate("wood_drain").pos == Vector2i(15, 19), "undo restores the renderer, hidden terminal and crate")
	_move(Vector2i.RIGHT)
	_expect(game.submerged.drained and not _switch("drain", 2).hidden, "drainage can be repeated after undo")
	_walk_to(Vector2i(8, 15))
	_expect(game.submerged.generator_on and game.submerged.drained and not game.environment.is_water(Installation.SOURCE), "turning power on again cannot restore drained water")
	_expect(not game.environment.is_electrified(Installation.SOURCE) and _gate("flooded_room").open, "drainage and earned passages survive re-energizing")
	_walk_to(Vector2i(8, 14))
	_walk_to(Vector2i(8, 15))
	_expect(not game.submerged.generator_on and game.submerged.drained, "I/O can be turned off again by re-entering")
	_walk_to(Vector2i(12, 18))
	_walk_to(Vector2i(17, 18))
	_walk_to(Vector2i(22, 18))
	_expect(game.submerged.final_open and _gate("exit").open and game.portal_open, "all three revealed terminals open the final passage and portal")
	_expect(events.has("PORTAL_OPEN"), "portal opening emits the existing portal feedback")
	game.undo_sokoban_move()
	_expect(not game.submerged.final_open and not _gate("exit").open and not game.portal_open and not game.submerged.drain_switches[2], "undo of the final switch also closes its dependent passage and portal")
	_move(Vector2i(22, 18) - game.player_position)
	_expect(game.submerged.final_open and game.portal_open, "final terminal can be activated again after undo")
	_walk_to(Vector2i(18, 23))
	_expect(game.game_state == "floor_clear" and game.lab_active, "real movement reaches the real portal and completes the chamber")
	game.advance_floor()
	_expect(game.game_state == "title" and not game.lab_active, "the final chamber returns to the title")
	var campaign_after := [game.has_resume, game.resume_floor, game.resume_coins, game.resume_charges,
		game.resume_breach_charges, game.resume_seed, game.resume_history.duplicate(),
		game.resume_powers.duplicate(true), game.floor_stars.duplicate(true), game.furthest_floor, game.best_score]
	_expect(profile_before == FileAccess.get_file_as_bytes(path) and slot_before == FileAccess.get_file_as_bytes(slot_path) and campaign_before == campaign_after, "complete installation leaves global profile, campaign slot and checkpoint metadata unchanged")
	_expect(FileAccess.file_exists(backup_path) == backup_existed and (not backup_existed or FileAccess.get_file_as_bytes(backup_path) == backup_before), "complete installation leaves the existing campaign backup unchanged")
	game.continue_game()
	_expect(not game.lab_active and game.floor_number == 1, "campaign continue returns to its original floor")
	game.persistence_enabled = false
	var cleanup: Array[String] = [path, path + ".bak", path + ".legacy.bak"]
	for index in range(3):
		cleanup.append(game.campaign_storage.slot_path(index))
		cleanup.append(game.campaign_storage.backup_path(index))
		cleanup.append(game.campaign_storage.replaced_path(index))
	for candidate in cleanup:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _test_closed_gate_and_water_hazard() -> void:
	game.start_environment_lab(Installation.LAB_INDEX)
	# Adversarial fixture: a crate is deliberately placed in A's gate while the
	# player is on the hub side. A later selection must not delete or push it
	# through the closed gate; selecting A again recovers it.
	game.environment.crates[0].pos = Vector2i(4, 6)
	game.player_position = Vector2i(4, 7)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.submerged.last_cell = game.player_position
	game.submerged.selected_door = 1
	game._sync_environment_mechanisms()
	var turn: int = game.turn_number
	game.try_move(0, -1)
	_expect(game.turn_number == turn and _crate("wood_hatch").pos == Vector2i(4, 6), "closed selected-away gate preserves its crate and blocks a push")
	_walk_to(Vector2i(4, 8))
	_expect(_door_state() == [true, false, false], "reselecting A reopens the occupied gate")
	_move(Vector2i.UP, 2)
	_expect(_crate("wood_hatch").pos == Vector2i(4, 5), "crate can be recovered after reopening its gate")

	# Separate hazard fixture uses real entry into a live source, then the
	# ordinary captured/game-over/retry flow. It is not the reference route.
	game.restart_floor()
	game.environment.crates[1].pos = Installation.SOCKET
	game.submerged.hatch_open = true
	game._sync_environment_mechanisms()
	game.submerged.sequence_progress = 3
	game.submerged.sequence_complete = true
	game._sync_environment_mechanisms()
	game.player_position = Vector2i(18, 16)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.submerged.last_cell = game.player_position
	turn = game.turn_number
	game.try_move(0, 1)
	_expect(game.turn_number == turn + 1 and game.game_state == "captured", "entering live water applies the existing hazard after one turn")
	game._update_capture_sequence(game.CAPTURE_END_TIME + 0.1)
	_expect(game.game_state == "game_over", "hazard reaches the ordinary retry screen")
	game.continue_game()
	_expect(game.lab_active and game.lab_index == Installation.LAB_INDEX and game.game_state == "playing", "retry reloads this chamber rather than campaign")
	_expect(game.turn_number == 0 and _door_state() == [true, false, false] and not game.submerged.generator_installed and not game.submerged.drained, "retry resets all installation progress")
	_expect(game.environment.crates.size() == 3 and _crate("generator").pos == Vector2i(12, 3), "retry restores all authored objects")


func _test_corner_recovery() -> void:
	game.restart_floor()
	_walk_to(Vector2i(4, 4))
	_move(Vector2i.UP, 2)
	_expect(_crate("wood_hatch").pos == Vector2i(4, 1) and not game._is_floor(Vector2i(4, 0)), "an unfortunate push can strand the crate against the border")
	game.undo_sokoban_move()
	_expect(_crate("wood_hatch").pos == Vector2i(4, 2), "undo recovers the crate from the border")
	_walk_to(Vector2i(4, 1))
	_move(Vector2i.DOWN, 8)
	_expect(_crate("wood_hatch").pos == Vector2i(4, 10) and game.submerged.hatch_open, "the recovered crate can still open the hatch")


func _test_bounded_undo() -> void:
	game.restart_floor()
	for _i in 130:
		game.wait_turn()
	_expect(game.sokoban_history.size() == game.SOKOBAN_HISTORY_LIMIT and game.turn_number == 130, "undo history is bounded to 128 accepted actions")
	for _i in game.SOKOBAN_HISTORY_LIMIT:
		game.undo_sokoban_move()
	_expect(game.sokoban_history.is_empty() and game.turn_number == 2, "128 undos restore the oldest retained turn")
	game.undo_sokoban_move()
	_expect(game.turn_number == 2 and game.last_notice.contains("NAO HA"), "undo past the bound does not invent state")
	game.restart_floor()
	_expect(game.turn_number == 0 and game.sokoban_history.is_empty(), "R provides a complete restart after the undo bound")
