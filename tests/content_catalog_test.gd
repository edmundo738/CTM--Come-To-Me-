extends SceneTree

const Content = preload("res://content/game_content_catalog.tres")
const Generator = preload("res://level_generator.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	_expect(Content.validate().is_empty(), "all editor-authored definitions validate: %s" % str(Content.validate()))
	_expect(Content.biomes.size() == 5 and Content.bosses.size() == 6 and Content.powerups.size() == 4 and Content.enemies.size() == 6, "catalog has authored biomes, bosses, powers and common enemies")
	_expect(Content.floor_name(1) == "AS RUINAS DE NEON" and Content.floor_name(5) == "TRONO DO GUARDIAO", "biome labels preserve campaign order")
	_expect(Content.floor_size(1) == Vector2i(19, 15) and Content.floor_size(5) == Vector2i(43, 27), "authored map sizes preserve the five current defaults")
	_expect(Content.floor_size(6) == Vector2i(44, 27) and Content.floor_size(8) == Vector2i(45, 28), "map growth follows the existing campaign rule")
	var pawn: Resource = Content.boss_for_floor(5)
	var rook: Resource = Content.boss_for_floor(10)
	var king: Resource = Content.boss_for_floor(30)
	_expect(pawn != null and str(pawn.get("id")) == "pawn" and int(pawn.get("hit_points")) == 2, "floor five selects the existing pawn boss definition")
	_expect(rook != null and str(rook.get("id")) == "rook" and str(rook.get("movement_profile")) == "rook", "boss selection and movement profile come from the resource")
	_expect(king != null and str(king.get("id")) == "king" and is_equal_approx(float(king.get("visual_scale")), 1.1), "boss portrait size is editable per definition")
	_expect(int(Content.powerup_definition("speed").get("duration_turns")) == 6, "speed duration remains six turns")
	_expect(int(Content.powerup_definition("magnet").get("duration_turns")) == 8, "magnet duration remains eight turns")
	_expect(int(Content.powerup_definition("time_freeze").get("duration_turns")) == 4, "freeze duration remains four turns")
	var rusher: Resource = Content.enemy_definition("rusher")
	var mirror: Resource = Content.enemy_definition("mirror")
	_expect(rusher != null and str(rusher.get("movement_profile")) == "rusher" and is_equal_approx(float(rusher.get("move_duration")), 0.12), "rusher behavior and movement presentation are resource-backed")
	_expect(mirror != null and str(mirror.get("movement_profile")) == "mirror" and is_equal_approx(float(mirror.get("visual_scale")), 1.02), "mirror behavior and visual scale are resource-backed")
	var default_generator = Generator.new()
	var biome_generator = Generator.new()
	var default_output: Dictionary = default_generator.generate(19, 15, 9234)
	var biome_output: Dictionary = biome_generator.generate(19, 15, 9234, Content.biomes[0].get("room_profile"), Content.biomes[0].get("wfc_tile_set"))
	_expect(default_output == biome_output, "explicit biome WFC resources preserve the current seeded output")
	_expect(Content.biomes.all(func(biome): return biome.get("room_profile") != null and biome.get("wfc_tile_set") != null), "each biome exposes room-shape and WFC compatibility resources")
	if failures.is_empty():
		print("CONTENT_CATALOG_PASS: %d checks" % 15)
	else:
		printerr("CONTENT_CATALOG_FAIL: %d: %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)
