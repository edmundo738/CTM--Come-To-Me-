@tool
extends "res://components/level_component.gd"


func component_kind() -> StringName:
	return &"circuit_relay"


func preview_color() -> Color:
	return Color("e6b6ff")
