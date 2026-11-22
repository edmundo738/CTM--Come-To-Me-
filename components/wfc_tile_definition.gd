@tool
extends Resource

@export_range(0, 15, 1) var tile_id: int = 0
@export_range(0, 15, 1) var passage_mask: int = 0
@export_range(0.01, 100.0, 0.01) var weight: float = 1.0
@export var biome_tags: PackedStringArray = PackedStringArray()
@export var editor_color: Color = Color("657385")
