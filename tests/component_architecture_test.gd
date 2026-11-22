extends SceneTree

const BlueprintScene = preload("res://levels/editable_component_demo.tscn")
const EnvironmentRules = preload("res://environment_system.gd")
const Generator = preload("res://level_generator.gd")
const WfcTiles = preload("res://components/wfc_default_tile_set.tres")
const SpecialLevels = preload("res://special_levels.gd")
const EnvironmentChambers = preload("res://environment_chambers.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	_test_scene_hierarchy()
	_test_authored_component_links()
	_test_blueprint_validation()
	_test_invalid_links()
	_test_legacy_component_migration()
	_test_wfc_resource_catalog()
	await _test_runtime_chamber()
	if failures.is_empty():
		print("COMPONENT_ARCHITECTURE_PASS: editor hierarchy, instances, links, circuit, legacy and WFC resources")
	else:
		printerr("COMPONENT_ARCHITECTURE_FAIL: %d: %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)


func _test_scene_hierarchy() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var game := main_scene.instantiate()
	_expect(game.get_node_or_null("World/TerrainRenderer") != null, "terrain renderer is a named scene node")
	_expect(game.get_node_or_null("World/LevelComponents") != null, "level components have a visible editor mount")
	_expect(game.get_node_or_null("World/Actors") != null, "actors have a named editor mount")
	_expect(game.get_node_or_null("HUDLayer/HUD") != null and game.get_node_or_null("RuntimeSystems") != null, "HUD and runtime systems are in the main scene tree")
	game.free()


func _test_authored_component_links() -> void:
	var blueprint = BlueprintScene.instantiate()
	var result: Dictionary = blueprint.compile_level()
	_expect(result.get("ok", false), "the authored level blueprint compiles: %s" % str(result.get("errors", [])))
	if not result.get("ok", false):
		blueprint.free()
		return
	var environment = EnvironmentRules.new()
	environment.reset(result.environment)
	environment.update_mechanisms(Vector2i(1, 4), [])
	_expect(environment.gates[0].open == false and environment.gates[1].open == false and environment.gates[2].open, "generator powers only its receiver, plate and linked gate")
	environment.crates[0].pos = environment.plates[0].pos
	environment.update_mechanisms(Vector2i(1, 4), [])
	_expect(environment.gates[0].open and not environment.gates[1].open and environment.gates[2].open, "one plate opens its assigned gate only")
	environment.crates[1].pos = environment.plates[1].pos
	environment.update_mechanisms(Vector2i(1, 4), [])
	_expect(environment.gates[0].open and environment.gates[1].open and environment.gates[2].open, "independent plate links can open separate gates")
	environment.crates[0].pos = Vector2i(3, 2)
	environment.crates[1].pos = Vector2i(3, 4)
	environment.update_mechanisms(Vector2i(1, 4), [])
	_expect(not environment.gates[0].open and not environment.gates[1].open and environment.gates[2].open, "linked gates close when their own plate releases")
	environment.circuit_nodes[0].active = false
	environment.refresh_electricity()
	environment.update_mechanisms(Vector2i(1, 4), [])
	_expect(not environment.powered.has(environment.plates[2].pos) and not environment.gates[2].open, "turning off the source removes power from its linked circuit")
	blueprint.free()


func _test_invalid_links() -> void:
	var blueprint = BlueprintScene.instantiate()
	var plate: Node = blueprint.get_node("WoodPlate")
	plate.output_ids = PackedStringArray(["missing_gate"])
	var result: Dictionary = blueprint.compile_level()
	_expect(not result.get("ok", false) and str(result.errors).contains("sem destino"), "a missing target is caught while editing the level")
	blueprint.free()


func _test_blueprint_validation() -> void:
	var blueprint = BlueprintScene.instantiate()
	var valid: Dictionary = blueprint.compile_level()
	_expect(valid.get("ok", false) and valid.level.get("objective_type") == "escape", "blueprint exports mission title, objective, grid and portal as playable data")
	var barrier: Array[Vector2i] = []
	for y in range(1, 8):
		barrier.append(Vector2i(6, y))
	blueprint.wall_cells = barrier
	var blocked: Dictionary = blueprint.compile_level()
	_expect(not blocked.get("ok", false) and str(blocked.errors).contains("caminho livre"), "editor validation rejects a wall layout that seals the portal")
	blueprint.free()
	var boundary = BlueprintScene.instantiate()
	boundary.wall_cells.append(Vector2i(0, 4))
	var boundary_result: Dictionary = boundary.compile_level()
	_expect(not boundary_result.get("ok", false) and str(boundary_result.errors).contains("borda externa"), "the permanent world boundary cannot be authored as destructible wall")
	var piece: Node = load("res://components/component_catalog.tres").create_instance(&"pressure_plate")
	piece.set("component_id", "test_plate")
	piece.set("cell", Vector2i(2, 2))
	boundary.editor_attach_component(piece)
	_expect(piece.get_parent() == boundary and piece.owner == boundary, "a placed component is a real, owned child scene in the map")
	boundary.editor_detach_component(piece)
	_expect(piece.get_parent() == null, "editor removal detaches a reusable component without freeing its scene")
	boundary.free()


func _test_legacy_component_migration() -> void:
	var spec: Dictionary = SpecialLevels.make("mechanism", 778, 12)
	_expect(not spec.is_empty(), "procedural special level is assembled through component definitions")
	if spec.is_empty():
		return
	_expect(spec.plates.all(func(plate: Dictionary) -> bool: return not str(plate.get("id", "")).is_empty() and plate.get("outputs", []).has(spec.gates[0].id)), "each legacy plate receives an explicit link to its gate")
	var environment = EnvironmentRules.new()
	environment.reset(spec)
	for index in environment.plates.size():
		environment.crates[index].pos = environment.plates[index].pos
	environment.update_mechanisms(spec.start, [])
	_expect(environment.gates[0].open, "the existing all-plates gate rule survives the component adapter")


func _test_wfc_resource_catalog() -> void:
	var tables: Dictionary = WfcTiles.build_tables()
	_expect(tables.errors.is_empty(), "WFC tile catalog has all 16 unique patterns")
	_expect(tables.open_masks == [0xAAAA, 0xCCCC, 0xF0F0, 0xFF00], "WFC neighbor rules match the previous four-edge masks")
	_expect(tables.weights[0] == 0.85 and tables.weights[7] == 0.42 and tables.weights[15] == 0.20, "WFC frequency weights are editable resources and preserve defaults")
	var generator = Generator.new()
	var first: Dictionary = generator.generate(19, 15, 9234)
	var second: Dictionary = generator.generate(19, 15, 9234)
	_expect(first.get("ok", false) and second.get("ok", false) and first.tiles == second.tiles and first.grid == second.grid, "resource-backed WFC remains deterministic for a fixed seed")
	var workshop_layout: Dictionary = generator.generate(13, 9, 20261105)
	_expect(workshop_layout.get("ok", false) and workshop_layout.grid.size() == 9 and workshop_layout.grid[0].size() == 13, "the workshop's default map dimensions generate a WFC layout")
	if workshop_layout.get("ok", false):
		var generated_blueprint: Node = load("res://components/level_blueprint.gd").new()
		generated_blueprint.grid_size = Vector2i(13, 9)
		generated_blueprint.start_cell = workshop_layout.start
		generated_blueprint.portal_cell = workshop_layout.goal
		var generated_walls: Array[Vector2i] = []
		for y in workshop_layout.grid.size():
			for x in workshop_layout.grid[y].size():
				if int(workshop_layout.grid[y][x]) == 1 and x > 0 and y > 0 and x < 12 and y < 8:
					generated_walls.append(Vector2i(x, y))
		generated_blueprint.wall_cells = generated_walls
		var compiled_layout: Dictionary = generated_blueprint.compile_level()
		_expect(compiled_layout.get("ok", false), "the WFC layout compiles into an editable blueprint with a free route: %s" % str(compiled_layout.get("errors", [])))
		generated_blueprint.free()


func _test_runtime_chamber() -> void:
	var game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	game.start_environment_lab(5)
	await process_frame
	_expect(game.lab_name == "LIGACOES / GERADOR" and game.environment.plates.size() == 3 and game.environment.gates.size() == 3, "the editor blueprint can be played through the existing laboratory")
	_expect(game.environment.gates[2].open and not game.environment.gates[0].open and not game.environment.gates[1].open, "the powered door is initially independent from both crate routes")
	game.try_move(0, -1)
	game.try_move(0, -1)
	game.try_move(1, 0)
	game.try_move(1, 0)
	game.try_move(1, 0)
	_expect(game.environment.gates[0].open and not game.environment.gates[1].open and game.environment.gates[2].open, "the real turn loop opens only the gate linked to the moved crate")
	var remaining: Dictionary = SpecialLevels.solve(EnvironmentChambers.chamber(5), game.player_position, game.environment.crates)
	_expect(remaining.length >= 0 and not remaining.truncated, "the remaining authored component room has a solver-confirmed route")
	if remaining.length >= 0 and not remaining.truncated:
		for direction in remaining.path:
			game.try_move(direction.x, direction.y)
		_expect(game.player_position == game.portal_position and game.portal_open, "the solver route completes the real turn-based room")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	var playtest = load("res://main.tscn").instantiate()
	playtest.editor_playtest_enabled = true
	playtest.editor_playtest_blueprint = BlueprintScene
	playtest.persistence_enabled = true
	root.add_child(playtest)
	await process_frame
	_expect(playtest.lab_active and playtest.game_state == "playing", "editor playtest opens the authored map directly without campaign menu")
	var isolated_profile_path := "user://ctm_workshop_test_%d.cfg" % Time.get_ticks_usec()
	playtest.profile_path = isolated_profile_path
	var transient_save_ok: bool = playtest._save_profile()
	_expect(not playtest.persistence_enabled and transient_save_ok and not FileAccess.file_exists(isolated_profile_path), "editor playtest leaves campaign profile on disk untouched")
	_expect(playtest.objective_type == "escape" and playtest.portal_open and playtest.lab_name == "Nova missão", "authored objective and title reach the real playtest chamber")
	playtest.restart_floor()
	_expect(playtest.lab_active and playtest.game_state == "playing" and playtest.lab_name == "Nova missão", "retry reloads the same edited blueprint")
	playtest.audio.stop_all()
	playtest.queue_free()
	await process_frame
