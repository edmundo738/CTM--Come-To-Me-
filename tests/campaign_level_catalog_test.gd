extends SceneTree

const GameScene = preload("res://main.tscn")
const CampaignCatalogScript = preload("res://content/campaign_level_catalog.gd")
const BlueprintScript = preload("res://components/level_blueprint.gd")
const DemoScene = preload("res://levels/editable_component_demo.tscn")

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
	var catalog = CampaignCatalogScript.new()
	_expect(catalog.blueprint_for_floor(1) == null and catalog.blueprint_for_floor(200) == null, "all 200 campaign slots begin procedural until a map is linked")
	var blueprint = DemoScene.instantiate()
	blueprint.set("mission_title", "Circuito de ensaio")
	blueprint.set("mission_hint", "Liga cada placa ao seu portao.")
	blueprint.set("mission_objective", "environment")
	var compiled: Dictionary = blueprint.compile_level()
	_expect(compiled.get("ok", false), "the linked authored mission compiles with real mechanism scenes")
	var packed := PackedScene.new()
	_expect(packed.pack(blueprint) == OK, "a Godot scene can be linked to a campaign slot")
	blueprint.free()
	catalog.register_floor(2, packed)
	_expect(catalog.blueprint_for_floor(2) == packed and catalog.entries.size() == 1, "the selected floor stores a sparse scene reference")
	catalog.register_floor(2, packed)
	_expect(catalog.entries.size() == 1, "relinking a floor does not duplicate its catalog entry")
	catalog.register_floor(200, packed)
	_expect(catalog.blueprint_for_floor(200) == packed and catalog.entries.size() == 2, "the final campaign floor is editable through the same sparse catalog")
	catalog.unregister_floor(200)
	var catalog_path := "user://ctm_campaign_level_catalog_test.tres"
	var save_error := ResourceSaver.save(catalog, catalog_path)
	_expect(save_error == OK, "campaign links persist as a Godot Resource")
	var saved_catalog: Resource = ResourceLoader.load(catalog_path)
	_expect(saved_catalog != null and saved_catalog.call("blueprint_for_floor", 2) != null, "a saved catalog reloads its floor scene reference")
	if FileAccess.file_exists(catalog_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog_path))
	var game: Node = GameScene.instantiate()
	game.persistence_enabled = false
	game.active_seed = 31871
	game.campaign_level_catalog = catalog
	root.add_child(game)
	game.audio.effects_enabled = false
	game.generate_floor(2)
	_expect(game.generation_report.begins_with("OFICINA / fase 002"), "campaign generation loads the linked manual scene instead of WFC")
	_expect(game.objective_type == "environment" and game.authored_mission_title == "Circuito de ensaio" and game.authored_mission_hint != "", "authored mission text and objective reach the live floor")
	var authored_title: String = game.authored_mission_title
	_expect(game.environment.crates.size() == 2 and game.environment.plates.size() == 3 and game.environment.gates.size() == 3, "mechanism scenes compile into the live turn system")
	_expect(not game.portal_open and not game.enemies.is_empty(), "an authored objective retains the campaign's ordinary pursuers")
	if game.environment.plates.size() == game.environment.crates.size() + 1:
		for index in game.environment.crates.size():
			game.environment.crates[index].pos = game.environment.plates[index].pos
		game._sync_environment_mechanisms()
		_expect(game.portal_open, "activating the authored circuit opens the actual campaign portal")
	else:
		_expect(false, "fixture contains the expected authored plates and crates")
	catalog.register_floor(6, packed)
	game.generate_floor(6)
	_expect(not game.environment_bonus_available and game.environment.cells.is_empty(), "manual maps do not receive hidden procedural landmarks or brittle terrain")
	catalog.unregister_floor(6)
	var spawn_blueprint: Node2D = Node2D.new()
	spawn_blueprint.set_script(BlueprintScript)
	spawn_blueprint.set("level_id", "entity_spawn_test")
	spawn_blueprint.set("campaign_floor", 7)
	spawn_blueprint.set("grid_size", Vector2i(19, 15))
	spawn_blueprint.set("start_cell", Vector2i(1, 7))
	spawn_blueprint.set("portal_cell", Vector2i(17, 7))
	spawn_blueprint.set("authoritative_spawns", true)
	var authored_spawns: Array[Dictionary] = [
		{"kind": "enemy", "subtype": "sentry", "cell": Vector2i(5, 7)},
		{"kind": "pickup", "subtype": "coin", "cell": Vector2i(8, 7)},
	]
	spawn_blueprint.set("entity_spawns", authored_spawns)
	var spawn_scene := PackedScene.new()
	_expect(spawn_blueprint.compile_level().get("ok", false) and spawn_scene.pack(spawn_blueprint) == OK, "enemy and pickup placements compile as part of an editable level")
	spawn_blueprint.free()
	catalog.register_floor(7, spawn_scene)
	game.generate_floor(7)
	_expect(game.enemies.size() == 1 and game.enemies[0].role == "sentry", "placed enemy appears at runtime and replaces random campaign enemies when requested")
	_expect(game.coins == [Vector2i(8, 7)] and game.shields.is_empty(), "placed pickup appears at runtime without random pickup clutter")
	catalog.unregister_floor(7)
	catalog.unregister_floor(2)
	game.generate_floor(2)
	_expect(game.generation_report.begins_with("WFC seed"), "unlinking restores the existing WFC generation path")
	_expect(game.authored_mission_title == "" and game.objective_type != "environment", "unlinked floors do not leak authored mission state")
	_expect(authored_title == "Circuito de ensaio", "test fixture mission was retained during the campaign run")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CAMPAIGN_LEVEL_CATALOG_PASS checks=", checks, " manual campaign map, mechanisms, live objective, pursuers and WFC fallback")
	else:
		printerr("CAMPAIGN_LEVEL_CATALOG_FAIL checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

