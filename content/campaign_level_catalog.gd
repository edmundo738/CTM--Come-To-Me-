@tool
class_name CampaignLevelCatalog
extends Resource

@export var entries: Array[CampaignLevelEntry] = []


func entry_for_floor(floor_number: int) -> CampaignLevelEntry:
	for entry in entries:
		if entry != null and entry.floor_number == floor_number:
			return entry
	return null


func blueprint_for_floor(floor_number: int) -> PackedScene:
	var entry := entry_for_floor(floor_number)
	return entry.blueprint if entry != null else null


func register_floor(floor_number: int, scene: PackedScene) -> void:
	if floor_number < 1 or floor_number > 200 or scene == null:
		return
	var existing := entry_for_floor(floor_number)
	if existing != null:
		existing.blueprint = scene
		return
	var entry := CampaignLevelEntry.new()
	entry.floor_number = floor_number
	entry.blueprint = scene
	entries.append(entry)
	entries.sort_custom(func(a: CampaignLevelEntry, b: CampaignLevelEntry) -> bool: return a.floor_number < b.floor_number)


func set_floor(floor_number: int, scene: PackedScene) -> void:
	if scene == null:
		unregister_floor(floor_number)
	else:
		register_floor(floor_number, scene)


func unregister_floor(floor_number: int) -> bool:
	for index in entries.size():
		if entries[index] != null and entries[index].floor_number == floor_number:
			entries.remove_at(index)
			return true
	return false

