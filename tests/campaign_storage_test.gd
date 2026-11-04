extends SceneTree

const Game = preload("res://game.gd")
const Storage = preload("res://campaign_storage.gd")
var checks := 0
var failures: Array[String] = []
var test_dir := ""
var path := ""


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _cleanup() -> void:
	var dir := DirAccess.open(test_dir)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))


func _legacy_file(target: String) -> PackedByteArray:
	var legacy := ConfigFile.new()
	legacy.set_value("controller", "vibration", false)
	legacy.set_value("cosmetics", "example_owned", ["global-unowned-placeholder"])
	legacy.set_value("progress", "best_score", 22)
	legacy.set_value("progress", "furthest_floor", 5)
	legacy.set_value("progress", "floor_stars", {"1": 5, "4": 2})
	legacy.set_value("progress", "has_resume", true)
	legacy.set_value("progress", "resume_floor", 5)
	legacy.set_value("progress", "resume_coins", 18)
	legacy.set_value("progress", "resume_charges", 6)
	legacy.set_value("progress", "resume_breach_charges", 2)
	legacy.set_value("progress", "resume_seed", 9321)
	legacy.set_value("progress", "resume_history", [5, 2])
	legacy.save(target)
	return FileAccess.get_file_as_bytes(target)


func _new_game_with_path(target: String) -> Node:
	var instance = Game.new()
	instance.profile_path = target
	root.add_child(instance)
	instance.audio.effects_enabled = false
	return instance


func _storage_and_migration() -> void:
	var legacy_bytes := _legacy_file(path)
	var game := _new_game_with_path(path)
	var store = Storage.new()
	store.profile_path = path
	_expect(FileAccess.get_file_as_bytes(path) == legacy_bytes and not FileAccess.file_exists(store.slot_path(0)), "loading legacy profile does not mutate or silently migrate it")
	_expect(game.legacy_profile_pending and game.resume_charges == 6 and game.resume_floor == 5, "legacy checkpoint and over-cap shields load intact")
	_expect(game.hearts_current == 0 and game.skills.points == 0 and game.skills.unlocked.is_empty(), "legacy profile receives no fabricated hearts, nodes or retroactive points")
	_expect(not game.skills.award_floor(1) and not game.skills.award_floor(4), "already completed legacy floors cannot award new points")
	_expect(game._save_profile(), "legacy migration saves successfully")
	_expect(FileAccess.get_file_as_bytes(path + ".legacy.bak") == legacy_bytes, "verified immutable backup contains exact original legacy bytes")
	_expect(store.read_slot(0).status == "ok" and store.read_slot(1).status == "empty" and store.read_slot(2).status == "empty", "legacy migration fills only campaign one")
	var global := ConfigFile.new()
	global.load(path)
	_expect(global.get_value("cosmetics", "example_owned", []) == ["global-unowned-placeholder"] and not bool(global.get_value("controller", "vibration", true)), "unknown global/cosmetic data and controller preference survive migration")

	var campaign_one: Dictionary = store.read_slot(0).data
	_expect(game.select_campaign(1), "can select an empty second campaign")
	game.new_game(777)
	_expect(game.has_resume and game.resume_floor == 1 and game.hearts_current == 0 and game.skills.points == 0 and game.skills.unlocked.is_empty() and game.furthest_floor == 1, "new campaign starts without previous campaign progression")
	_expect(store.read_slot(0).data == campaign_one and store.read_slot(1).status == "ok", "starting another campaign leaves the old slot unchanged")
	var second_bytes := FileAccess.get_file_as_bytes(store.slot_path(1))
	_expect(game.select_campaign(0) and game.resume_charges == 6 and game.resume_coins == 18, "switching back restores first campaign checkpoint")
	game.skills.points = 1
	_expect(game._save_profile(), "skill point at checkpoint saves")
	game.game_state = "title"
	game.handle_hud_action("skills")
	game.handle_hud_action("skill_unlock")
	game.handle_hud_action("skill_toggle")
	_expect(game.hearts_current == 1 and game.skills.active.has("heart_1"), "heart unlocked and activated through tree")
	var reader := _new_game_with_path(path)
	_expect(reader.active_slot == 0 and reader.resume_hearts == 1 and reader.skills.active.has("heart_1") and reader.skills.credited.has("heart_1"), "tree and heart credits survive reloading")
	_expect(FileAccess.get_file_as_bytes(store.slot_path(1)) == second_bytes, "skill changes do not touch campaign two")
	reader.audio.stop_all()
	reader.queue_free()

	game.handle_hud_action("skill_back")
	game.game_state = "title"
	var old_campaign := FileAccess.get_file_as_bytes(store.slot_path(0))
	game.handle_hud_action("new_run")
	game.handle_hud_action("campaign:0")
	_expect(game.game_state == "campaign_confirm" and game.slot_pending_action == "new", "occupied campaign requires explicit new-game confirmation")
	game.handle_hud_action("campaign_cancel")
	_expect(FileAccess.get_file_as_bytes(store.slot_path(0)) == old_campaign, "cancel does not modify campaign")
	game.handle_hud_action("campaign:0")
	game.handle_hud_action("campaign_confirm")
	_expect(game.game_state == "playing" and game.skills.unlocked.is_empty() and game.hearts_current == 0, "confirmed replacement starts clean")
	_expect(store.read_replaced(0).status == "ok" and FileAccess.get_file_as_bytes(store.replaced_path(0)) == old_campaign, "replaced campaign has an independently retained backup")
	game.total_coins = 5
	game._save_resume(1, 5)
	_expect(store.read_replaced(0).status == "ok" and FileAccess.get_file_as_bytes(store.replaced_path(0)) == old_campaign, "later checkpoint rotations do not erase replaced campaign backup")
	game.game_state = "campaign_select"
	game.handle_hud_action("campaign_restore_replaced:0")
	_expect(game.game_state == "campaign_confirm", "restoring a replaced campaign asks for confirmation")
	game.handle_hud_action("campaign_confirm")
	_expect(game.skills.active.has("heart_1") and game.resume_hearts == 1 and FileAccess.get_file_as_bytes(store.slot_path(1)) == second_bytes, "restoring replaced backup restores only requested campaign")

	# Structural truncation and an unsupported future version must never be
	# mistaken for an empty campaign or overwritten on an ordinary save.
	var broken := ConfigFile.new()
	broken.set_value("campaign", "version", 1)
	broken.save(store.slot_path(0))
	var broken_bytes := FileAccess.get_file_as_bytes(store.slot_path(0))
	_expect(store.read_slot(0).status == "corrupt", "truncated campaign is reported as corrupt")
	var saved: Dictionary = store.save_slot(0, campaign_one)
	_expect(not saved.ok and FileAccess.get_file_as_bytes(store.slot_path(0)) == broken_bytes, "saving cannot overwrite a corrupt campaign")
	var corrupt_sha := FileAccess.get_sha256(store.slot_path(0))
	var restored: Dictionary = store.restore_slot(0)
	_expect(restored.ok and store.read_slot(0).status == "ok", "explicit restore recovers valid prior checkpoint")
	_expect(FileAccess.file_exists(store.slot_path(0) + ".before-restore-" + corrupt_sha.substr(0, 12) + ".bak"), "damaged file is archived before restore")
	_expect(FileAccess.get_file_as_bytes(store.slot_path(1)) == second_bytes, "restoring a corrupt slot does not alter another slot")
	var future := ConfigFile.new()
	future.set_value("campaign", "version", 999)
	future.set_value("campaign", "data", {"unknown": true})
	future.save(store.slot_path(2))
	var future_bytes := FileAccess.get_file_as_bytes(store.slot_path(2))
	_expect(store.read_slot(2).status == "future" and not store.save_slot(2, campaign_one).ok and FileAccess.get_file_as_bytes(store.slot_path(2)) == future_bytes, "newer slot schema is preserved and cannot be overwritten")
	var unavailable = Storage.new()
	unavailable.profile_path = test_dir + "/missing/subdir/profile.cfg"
	_expect(not unavailable.save_slot(0, campaign_one).ok and not FileAccess.file_exists(unavailable.slot_path(0)), "write failure never invents a successful save")

	# A newer global schema is protected; explicit backup restoration archives
	# it and leaves all independently stored campaigns alone.
	_expect(store.global_backup_available(), "valid global backup is available")
	future = ConfigFile.new()
	future.set_value("meta", "version", 999)
	future.set_value("meta", "opaque", "do not overwrite")
	future.save(path)
	var newer_global := FileAccess.get_file_as_bytes(path)
	var before_global_sha := FileAccess.get_sha256(path)
	var guarded := _new_game_with_path(path)
	_expect(guarded.profile_blocked and not guarded._save_profile() and FileAccess.get_file_as_bytes(path) == newer_global, "newer global profile blocks writes without damage")
	guarded.game_state = "campaign_select"
	guarded.handle_hud_action("profile_restore")
	_expect(guarded.game_state == "campaign_confirm", "global recovery asks for confirmation")
	guarded.handle_hud_action("campaign_confirm")
	_expect(not guarded.profile_blocked and FileAccess.file_exists(path + ".before-restore-" + before_global_sha.substr(0, 12) + ".bak"), "explicit global restore preserves newer file in archive")
	_expect(FileAccess.get_file_as_bytes(store.slot_path(1)) == second_bytes, "global settings recovery does not touch other campaign files")
	guarded.audio.stop_all()
	guarded.queue_free()
	game.audio.stop_all()
	game.queue_free()

	var conflict_path := test_dir + "/legacy-conflict.cfg"
	var conflict_legacy := _legacy_file(conflict_path)
	var conflict_store = Storage.new()
	conflict_store.profile_path = conflict_path
	_expect(conflict_store.save_slot(0, campaign_one).ok, "fixture creates occupied migration destination")
	var conflict_slot := FileAccess.get_file_as_bytes(conflict_store.slot_path(0))
	var conflicted := _new_game_with_path(conflict_path)
	_expect(conflicted.profile_blocked and not conflicted._save_profile(), "migration refuses an occupied unrelated slot")
	_expect(FileAccess.get_file_as_bytes(conflict_path) == conflict_legacy and FileAccess.get_file_as_bytes(conflict_store.slot_path(0)) == conflict_slot, "migration conflict leaves both originals intact")
	conflicted.audio.stop_all()
	conflicted.queue_free()

	# Simulate a crash after writing the new slot but before writing global meta.
	var interrupted_path := test_dir + "/legacy-interrupted.cfg"
	var interrupted_bytes := _legacy_file(interrupted_path)
	var interrupted_store = Storage.new()
	interrupted_store.profile_path = interrupted_path
	var legacy_profile := ConfigFile.new()
	legacy_profile.load(interrupted_path)
	var builder = Game.new()
	var interrupted_payload: Dictionary = builder._legacy_campaign(legacy_profile)
	interrupted_payload.resume_coins = 19
	var hash := FileAccess.get_sha256(interrupted_path)
	_expect(interrupted_store.backup_legacy().ok and interrupted_store.save_slot(0, interrupted_payload, hash).ok, "fixture stages a verified slot before global metadata")
	var resumed := _new_game_with_path(interrupted_path)
	_expect(not resumed.profile_blocked and resumed.legacy_profile_pending and resumed.resume_coins == 19, "interrupted migration recognizes matching source hash and preserves newer checkpoint")
	_expect(resumed._save_profile() and FileAccess.get_file_as_bytes(interrupted_path + ".legacy.bak") == interrupted_bytes, "interrupted migration finishes idempotently without overwriting the original backup")
	builder.free()
	resumed.audio.stop_all()
	resumed.queue_free()


func _key(game: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	game._unhandled_key_input(event)


func _click(game: Node, action: String) -> bool:
	for button in game.hud.buttons:
		if button.action == action:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = button.rect.get_center()
			game.hud._gui_input(event)
			return true
	return false


func _rendered_controls() -> void:
	var previous_size := root.size
	root.size = Vector2i(800, 540)
	var game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.new_game(31337)
	game.skills.points = 1
	game.game_state = "title"
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	var actions: Array = game.hud.buttons.map(func(button): return button.action)
	_expect(actions.has("campaigns") and actions.has("skills"), "title exposes campaign selection and skill tree")
	_expect(_click(game, "skills") and game.game_state == "skill_tree", "mouse opens skill tree from actual drawn button")
	await process_frame
	await process_frame
	for branch in game.skills.BRANCHES:
		game.handle_hud_action("skill_branch:" + str(branch.id))
		game.hud.queue_redraw()
		await process_frame
		await process_frame
		var drawn: Array = game.hud.buttons.map(func(button): return button.action)
		_expect(drawn.has("skill_unlock") and drawn.has("skill_toggle") and drawn.has("skill_back"), "branch exposes unlock/equip/back controls")
		var nodes: Array[Dictionary] = game.skills.branch_nodes(branch.id)
		for node in nodes:
			_expect(drawn.has("skill_node:" + str(node.id)), "draws selectable skill " + str(node.id))
		for button in game.hud.buttons:
			_expect(Rect2(Vector2.ZERO, game.hud.size).encloses(button.rect), "skill button stays inside 800x540: " + str(button.action))
	game.handle_hud_action("skill_branch:vida")
	await process_frame
	await process_frame
	game.hud.focus_action = "skill_unlock"
	_key(game, KEY_ENTER)
	_expect(game.skills.unlocked.has("heart_1") and game.hearts_current == 0, "keyboard confirms separate unlock")
	game.hud.focus_action = "skill_toggle"
	_key(game, KEY_ENTER)
	_expect(game.hearts_current == 1 and game.skills.active.has("heart_1"), "keyboard confirms activation")
	game.hud.focus_action = "skill_node:heart_1"
	game._on_controller_action("down")
	_expect(game.hud.focus_action != "skill_node:heart_1", "gamepad direction navigates real skill controls")
	_key(game, KEY_ESCAPE)
	_expect(game.game_state == "title", "escape returns to the menu that opened the tree")
	game.game_state = "paused"
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	_key(game, KEY_DOWN)
	_key(game, KEY_DOWN)
	_key(game, KEY_RIGHT)
	_expect(game.hud.focus_action == "skills", "keyboard can focus skills from pause at the beginning of a floor")
	_key(game, KEY_ENTER)
	_expect(game.game_state == "skill_tree", "keyboard opens skills from pause instead of unexpectedly resuming")
	_key(game, KEY_ESCAPE)
	_expect(game.game_state == "paused", "skills return to pause when opened there")
	game.game_state = "floor_clear"
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	_key(game, KEY_RIGHT)
	_expect(game.hud.focus_action == "skills", "keyboard can focus skills after a floor")
	_key(game, KEY_ENTER)
	_expect(game.game_state == "skill_tree", "keyboard opens skills after a floor instead of unexpectedly advancing")
	_key(game, KEY_ESCAPE)
	game.game_state = "title"
	game.handle_hud_action("new_run")
	await process_frame
	await process_frame
	actions = game.hud.buttons.map(func(button): return button.action)
	_expect(actions.has("campaign:0") and actions.has("campaign:1") and actions.has("campaign:2"), "three campaign cards are selectable")
	for button in game.hud.buttons:
		_expect(Rect2(Vector2.ZERO, game.hud.size).encloses(button.rect), "campaign button stays inside minimum viewport")
	game.handle_hud_action("campaign:0")
	await process_frame
	await process_frame
	_expect(game.game_state == "campaign_confirm" and game.hud.focus_action == "campaign_cancel", "destructive confirmation defaults to Cancel")
	_key(game, KEY_ESCAPE)
	_expect(game.game_state == "campaign_select", "escape cancels replacement")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	root.size = previous_size


func _run() -> void:
	test_dir = "user://ctm-campaign-tests-%d" % OS.get_process_id()
	path = test_dir + "/profile.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	_storage_and_migration()
	await process_frame
	await _rendered_controls()
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN_STORAGE_TEST_PASS checks=%d: legacy, slots, backups, corruption and UI" % checks)
	else:
		printerr("CAMPAIGN_STORAGE_TEST_FAIL %d/%d: %s" % [failures.size(), checks, "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)
