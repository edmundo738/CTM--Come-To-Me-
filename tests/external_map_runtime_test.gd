extends SceneTree

const GameScene = preload("res://main.tscn")
const ExternalMapLoader = preload("res://components/external_map_loader.gd")

var failures: Array[String] = []
var checks := 0
var test_path := ExternalMapLoader.campaign_path(7)


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var directory := ProjectSettings.globalize_path(ExternalMapLoader.MAP_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(directory)
	if FileAccess.file_exists(test_path):
		printerr("Refusing to overwrite an existing user map: ", test_path)
		quit(2)
		return
	var fixture := {
		"format": "ctmmap", "version": 1, "floor": 7, "id": "runtime_test",
		"name": "Ensaio da Oficina externa", "hint": "Ficheiro editado fora do Godot",
		"objective": "escape", "width": 19, "height": 15,
		"start": [1, 7], "portal": [17, 7], "walls": [],
		"authoritative_spawns": true,
		"entity_spawns": [
			{"kind": "enemy", "subtype": "sentry", "cell": [5, 7]},
			{"kind": "pickup", "subtype": "coin", "cell": [8, 7]},
		], "mechanisms": [],
	}
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	if file == null:
		printerr("Could not create a temporary project map: ", FileAccess.get_open_error())
		quit(2)
		return
	file.store_string(JSON.stringify(fixture))
	file.close()
	var game: Node = GameScene.instantiate()
	game.persistence_enabled = false
	game.active_seed = 31871
	root.add_child(game)
	game.audio.effects_enabled = false
	game.generate_floor(7)
	_expect(game.generation_report.begins_with("OFICINA / fase 007"), "campaign reads a map file saved by the standalone editor")
	_expect(game.authored_mission_title == "Ensaio da Oficina externa", "external map title reaches the live floor")
	_expect(game.enemies.size() == 1 and game.enemies[0].role == "sentry" and game.enemies[0].pos == Vector2i(5, 7), "placed enemy reaches gameplay without procedural duplicates")
	_expect(game.coins == [Vector2i(8, 7)] and game.shields.is_empty(), "placed pickup reaches gameplay without random clutter")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty():
		print("EXTERNAL_MAP_RUNTIME_PASS checks=%d" % checks)
		quit(0)
	else:
		printerr("EXTERNAL_MAP_RUNTIME_FAIL %d/%d" % [failures.size(), checks])
		quit(1)
