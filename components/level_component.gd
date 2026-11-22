@tool
extends Node2D

const EDITOR_CELL := 56.0

@export_group("Instância")
@export var component_id: String = ""
@export var cell: Vector2i = Vector2i.ZERO:
	set(value):
		cell = value
		position = Vector2(value) * EDITOR_CELL + Vector2.ONE * (EDITOR_CELL * 0.5)
		queue_redraw()
@export var output_ids: PackedStringArray = PackedStringArray():
	set(value):
		output_ids = value
		queue_redraw()


func component_kind() -> StringName:
	return &""


func component_fields() -> Dictionary:
	return {}


func to_component_data() -> Dictionary:
	var data := {"kind": str(component_kind()), "id": component_id, "pos": cell, "outputs": output_ids.duplicate()}
	data.merge(component_fields(), true)
	return data


func set_component_data(data: Dictionary) -> void:
	component_id = str(data.get("id", component_id))
	cell = data.get("pos", cell)
	output_ids = PackedStringArray(data.get("outputs", output_ids))
	queue_redraw()


func preview_color() -> Color:
	return Color("66dbcf")


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-23.0, -23.0, 46.0, 46.0), Color("111520"), true)
	draw_rect(Rect2(-23.0, -23.0, 46.0, 46.0), preview_color(), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-21.0, 37.0), "%s  (%d,%d)" % [component_id, cell.x, cell.y], HORIZONTAL_ALIGNMENT_LEFT, 200.0, 10, Color("f4f1ff"))
	if not output_ids.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-21.0, -27.0), "→ " + ", ".join(output_ids), HORIZONTAL_ALIGNMENT_LEFT, 200.0, 9, preview_color())
