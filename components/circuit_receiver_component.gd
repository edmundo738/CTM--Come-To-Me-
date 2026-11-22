@tool
extends "res://components/level_component.gd"


func component_kind() -> StringName:
	return &"circuit_receiver"


func preview_color() -> Color:
	return Color("ff78d8")
