@tool
extends Resource

@export_group("Identidade")
@export var id: StringName = &""
@export var display_name: String = ""
@export var rule_summary: String = ""
@export var texture: Texture2D
@export var accent_color: Color = Color.WHITE
@export_range(0.25, 3.0, 0.05) var visual_scale: float = 1.0

@export_group("Comportamento")
@export_enum("pawn", "rook", "knight", "bishop", "queen", "king") var movement_profile: String = "pawn"
@export_range(1, 99, 1) var hit_points: int = 1
