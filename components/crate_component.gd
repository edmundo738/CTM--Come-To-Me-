@tool
extends "res://components/level_component.gd"

@export_enum("wood", "metal", "ice") var crate_material: String = "wood"


func component_kind() -> StringName:
	return &"crate"


func component_fields() -> Dictionary:
	return {"material": crate_material}


func preview_color() -> Color:
	return Color("d0a274") if crate_material == "wood" else Color("82d9ec")
