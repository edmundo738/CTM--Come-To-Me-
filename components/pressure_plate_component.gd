@tool
extends "res://components/level_component.gd"

@export_enum("crate", "wood", "metal", "ice", "powered", "any") var required_material: String = "wood"


func component_kind() -> StringName:
	return &"pressure_plate"


func component_fields() -> Dictionary:
	return {"required": required_material}


func preview_color() -> Color:
	return Color("58e8da")
