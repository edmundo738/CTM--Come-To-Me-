extends SceneTree

const ExternalMapLoader = preload("res://components/external_map_loader.gd")
const Content = preload("res://content/game_content_catalog.tres")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var data := {
		"format": "ctmmap", "version": 1, "floor": 1, "name": "Teste externo",
		"objective": "environment", "width": 9, "height": 9,
		"start": [1, 1], "portal": [7, 7], "walls": [[4, 1]],
		"authoritative_spawns": true,
		"entity_spawns": [
			{"kind": "enemy", "subtype": "hunter", "cell": [2, 2]},
			{"kind": "pickup", "subtype": "shield", "cell": [3, 2]},
			{"kind": "pickup", "subtype": "powerup/blink", "cell": [4, 2]},
		],
		"mechanisms": [
			{"kind": "pressure_plate", "id": "plate_1", "cell": [2, 4], "required": "any", "outputs": ["gate_1"]},
			{"kind": "gate", "id": "gate_1", "cell": [3, 4], "open": false, "outputs": []},
			{"kind": "crate", "id": "crate_1", "cell": [4, 4], "material": "wood", "outputs": []},
			{"kind": "power_source", "id": "source_1", "cell": [5, 4], "active": true, "outputs": ["receiver_1"]},
			{"kind": "circuit_receiver", "id": "receiver_1", "cell": [6, 4], "outputs": []},
		],
	}
	var compiled: Dictionary = ExternalMapLoader.compile_data(data, 1, Content)
	_expect(compiled.get("ok", false), "a valid standalone map compiles")
	if compiled.get("ok", false):
		_expect(compiled.level.size == Vector2i(9, 9), "map dimensions become the campaign grid size")
		_expect(compiled.level.walls == [Vector2i(4, 1)], "wall coordinates become Godot cells")
		_expect(compiled.level.entity_spawns[0].cell == Vector2i(2, 2), "enemy placement becomes a gameplay spawn")
		_expect(compiled.level.entity_spawns[2].subtype == "powerup/blink", "power pickups retain their selected type")
		_expect(compiled.environment.plates.size() == 1 and compiled.environment.gates.size() == 1, "plate and gate become functional environment data")
		_expect(compiled.environment.crates.size() == 1 and compiled.environment.circuit_nodes.size() == 2, "crate and circuit pieces become functional environment data")
		_expect(compiled.level.authoritative_spawns, "map placement is authoritative when selected")
	var wrong_floor: Dictionary = ExternalMapLoader.compile_data(data, 2, Content)
	_expect(not wrong_floor.get("ok", false), "a map cannot load into a different campaign floor")
	var blocked := data.duplicate(true)
	blocked["objective"] = "escape"
	blocked["mechanisms"] = []
	blocked["entity_spawns"] = []
	blocked["walls"] = []
	for y in range(1, 8):
		blocked.walls.append([4, y])
	var blocked_result: Dictionary = ExternalMapLoader.compile_data(blocked, 1, Content)
	_expect(not blocked_result.get("ok", false), "a wall barrier with no route is rejected")
	var bad_entity := data.duplicate(true)
	bad_entity["entity_spawns"] = [{"kind": "enemy", "subtype": "made_up_enemy", "cell": [2, 2]}]
	_expect(not ExternalMapLoader.compile_data(bad_entity, 1, Content).get("ok", false), "unsupported actor types are rejected")
	var bad_link := data.duplicate(true)
	bad_link["mechanisms"][3]["outputs"] = ["gate_1"]
	_expect(not ExternalMapLoader.compile_data(bad_link, 1, Content).get("ok", false), "mechanism links with incompatible channels are rejected")
	if failures.is_empty():
		print("EXTERNAL_MAP_LOADER_PASS checks=%d" % checks)
		quit(0)
	else:
		printerr("EXTERNAL_MAP_LOADER_FAIL %d/%d" % [failures.size(), checks])
		quit(1)
