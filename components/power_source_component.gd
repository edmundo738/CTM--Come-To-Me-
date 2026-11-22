@tool
extends "res://components/level_component.gd"

@export var active: bool = true


func component_kind() -> StringName:
	return &"power_source"


func component_fields() -> Dictionary:
	return {"active": active}


func preview_color() -> Color:
	return Color("ffd65b")
