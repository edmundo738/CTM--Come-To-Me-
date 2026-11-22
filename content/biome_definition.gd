@tool
extends Resource

const DEFAULT_WFC_TILE_SET = preload("res://components/wfc_default_tile_set.tres")
const DEFAULT_ROOM_PROFILE = preload("res://content/definitions/room_profile_neon_ruins.tres")

@export_group("Identidade")
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Geração")
@export var initial_size: Vector2i = Vector2i(19, 15)
@export var wfc_tile_set: Resource = DEFAULT_WFC_TILE_SET
@export var room_profile: WfcRoomProfile = DEFAULT_ROOM_PROFILE
