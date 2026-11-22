@tool
extends Resource

@export_group("Conteúdo reutilizável")
@export var biomes: Array[Resource] = []
@export var bosses: Array[Resource] = []
@export var powerups: Array[Resource] = []
@export var enemies: Array[Resource] = []

@export_group("Crescimento da campanha")
@export_range(0, 128, 1) var max_width_growth: int = 14
@export_range(0, 128, 1) var max_height_growth: int = 8
@export_range(1, 99, 1) var width_growth_every_floors: int = 2
@export_range(1, 99, 1) var height_growth_every_floors: int = 3


func biome_index_for_floor(floor_number: int) -> int:
	return posmod(maxi(1, floor_number) - 1, biomes.size()) if not biomes.is_empty() else 0


func biome_for_floor(floor_number: int) -> Resource:
	if biomes.is_empty():
		return null
	return biomes[biome_index_for_floor(floor_number)]


func floor_name(floor_number: int) -> String:
	var biome := biome_for_floor(floor_number)
	return str(biome.get("display_name")) if biome != null else "BIOMA EM FALTA"


func floor_size(floor_number: int) -> Vector2i:
	if biomes.is_empty():
		return Vector2i(19, 15)
	var safe_floor := maxi(1, floor_number)
	if safe_floor <= biomes.size():
		return Vector2i(biomes[safe_floor - 1].get("initial_size"))
	var growth := safe_floor - biomes.size()
	var last_size: Vector2i = biomes.back().get("initial_size")
	var width_growth := mini(max_width_growth, ceili(float(growth) / float(width_growth_every_floors)))
	var height_growth := mini(max_height_growth, floori(float(growth) / float(height_growth_every_floors)))
	return Vector2i(last_size.x + width_growth, last_size.y + height_growth)


func boss_for_floor(floor_number: int) -> Resource:
	if bosses.is_empty():
		return null
	var boss_cycle := floori(float(maxi(5, floor_number)) / 5.0) - 1
	return bosses[posmod(boss_cycle, bosses.size())]


func boss_definition(boss_id: String) -> Resource:
	return _find_by_id(bosses, boss_id)


func powerup_definition(powerup_id: String) -> Resource:
	return _find_by_id(powerups, powerup_id)


func enemy_definition(enemy_id: String) -> Resource:
	return _find_by_id(enemies, enemy_id)


func powerup_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for definition in powerups:
		if definition != null:
			result.append(str(definition.get("id")))
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_records(biomes, "biome", errors)
	_validate_records(bosses, "boss", errors)
	_validate_records(powerups, "powerup", errors)
	_validate_records(enemies, "enemy", errors)
	for biome in biomes:
		if biome == null:
			continue
		if Vector2i(biome.get("initial_size")).x < 9 or Vector2i(biome.get("initial_size")).y < 9:
			errors.append("Bioma %s precisa de uma grelha mínima de 9x9" % biome.get("id"))
		var tile_set: Resource = biome.get("wfc_tile_set")
		if tile_set == null or not tile_set.has_method("build_tables"):
			errors.append("Bioma %s precisa de um WfcTileSet" % biome.get("id"))
		else:
			var tile_table: Dictionary = tile_set.call("build_tables")
			var tile_errors: Array = tile_table.get("errors", [])
			for tile_error in tile_errors:
				errors.append("Bioma %s: %s" % [biome.get("id"), tile_error])
		var room_profile: WfcRoomProfile = biome.get("room_profile")
		if room_profile == null:
			errors.append("Bioma %s precisa de um WfcRoomProfile" % biome.get("id"))
		else:
			for profile_error in room_profile.validate():
				errors.append("Bioma %s: %s" % [biome.get("id"), profile_error])
	for boss in bosses:
		if boss == null:
			continue
		if int(boss.get("hit_points")) < 1:
			errors.append("Chefe %s precisa de pelo menos 1 ponto de vida" % boss.get("id"))
		if boss.get("texture") == null:
			errors.append("Chefe %s precisa de uma textura" % boss.get("id"))
		if str(boss.get("movement_profile")) not in ["pawn", "rook", "knight", "bishop", "queen", "king"]:
			errors.append("Chefe %s tem perfil de movimento desconhecido" % boss.get("id"))
	for powerup in powerups:
		if powerup != null and int(powerup.get("duration_turns")) < 0:
			errors.append("Poder %s não pode ter duração negativa" % powerup.get("id"))
	for enemy in enemies:
		if enemy == null:
			continue
		if str(enemy.get("movement_profile")) not in ["hunter", "sentry", "wisp", "rusher", "patrol", "mirror"]:
			errors.append("Inimigo %s tem perfil de movimento desconhecido" % enemy.get("id"))
		if float(enemy.get("move_duration")) <= 0.0 or float(enemy.get("visual_scale")) <= 0.0:
			errors.append("Inimigo %s precisa de escala e duração positivas" % enemy.get("id"))
	return errors


func _find_by_id(records: Array[Resource], wanted: String) -> Resource:
	for record in records:
		if record != null and str(record.get("id")) == wanted:
			return record
	return null


func _validate_records(records: Array[Resource], family: String, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for record in records:
		if record == null:
			errors.append("O catálogo contém uma definição %s vazia" % family)
			continue
		var record_id := str(record.get("id"))
		if record_id.is_empty():
			errors.append("Definição %s sem ID" % family)
		elif seen.has(record_id):
			errors.append("ID %s duplicado na família %s" % [record_id, family])
		else:
			seen[record_id] = true
