@tool
extends Resource

@export_group("Identidade")
@export var id: StringName = &""
@export var display_name: String = ""
@export var accent_color: Color = Color.WHITE

@export_group("Efeito")
@export_range(0, 999, 1) var duration_turns: int = 0
