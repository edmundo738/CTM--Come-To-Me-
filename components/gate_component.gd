@tool
extends "res://components/level_component.gd"

@export_enum("all", "any") var input_mode: String = "all"
@export var initially_open: bool = false


func component_kind() -> StringName:
	return &"gate"


func component_fields() -> Dictionary:
	return {"input_mode": input_mode, "open": initially_open, "initially_open": initially_open}


func preview_color() -> Color:
	return Color("ffbd62")
