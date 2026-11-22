@tool
extends Control

signal cell_selected(cell: Vector2i)

const MAX_CELL_PIXELS := 44.0
var blueprint: Node
var _cell_pixels := 20.0
var _board_origin := Vector2.ZERO


func show_blueprint(value: Node) -> void:
	blueprint = value
	custom_minimum_size = Vector2.ZERO
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(blueprint):
		draw_string(ThemeDB.fallback_font, Vector2(18.0, 30.0), "Cria ou abre um mapa para comecar.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("d8d9e8"))
		return
	var size: Vector2i = blueprint.get("grid_size")
	_cell_pixels = maxf(6.0, minf(MAX_CELL_PIXELS, minf(get_size().x / maxf(1.0, size.x), get_size().y / maxf(1.0, size.y))))
	_board_origin = (get_size() - Vector2(size) * _cell_pixels) * 0.5
	var walls: Array = blueprint.get("wall_cells")
	var start: Vector2i = blueprint.get("start_cell")
	var portal: Vector2i = blueprint.get("portal_cell")
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			var fill := Color("182033") if (x + y) % 2 == 0 else Color("1c2639")
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				fill = Color("111827")
			if walls.has(cell):
				fill = Color("454456")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color("29364a"), false, maxf(0.5, _cell_pixels * 0.025))
			if cell == start:
				draw_circle(rect.get_center(), _cell_pixels * 0.27, Color("68f0c5"))
				draw_circle(rect.get_center(), _cell_pixels * 0.34, Color("b3ffe2"), false, maxf(1.0, _cell_pixels * 0.05))
			elif cell == portal:
				draw_circle(rect.get_center(), _cell_pixels * 0.31, Color("d48aff"), false, maxf(1.0, _cell_pixels * 0.08))
				draw_circle(rect.get_center(), _cell_pixels * 0.17, Color("782db5"))
	var components := _components(blueprint)
	var by_id: Dictionary = {}
	for component in components:
		by_id[str(component.get("component_id"))] = component
	for component in components:
		var from_cell: Vector2i = component.get("cell")
		var from_point := _cell_rect(from_cell).get_center()
		for target_id in component.get("output_ids"):
			if not by_id.has(str(target_id)):
				continue
			var target: Node = by_id[str(target_id)]
			var to_cell: Vector2i = target.get("cell")
			var to_point := _cell_rect(to_cell).get_center()
			draw_line(from_point, to_point, Color("73e9e0", 0.85), maxf(1.0, _cell_pixels * 0.05), true)
	for component in components:
		var cell: Vector2i = component.get("cell")
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			continue
		var center := _cell_rect(cell).get_center()
		var color: Color = component.preview_color() if component.has_method("preview_color") else Color("f3cb73")
		var radius := _cell_pixels * 0.31
		draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color("0b1020"), true)
		draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, false, maxf(1.0, _cell_pixels * 0.06))
		if _cell_pixels >= 16.0:
			draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.35, radius * 0.35), _kind_mark(component), HORIZONTAL_ALIGNMENT_LEFT, radius, mini(12, int(_cell_pixels * 0.35)), color)
	for spawn in blueprint.get("entity_spawns"):
		var cell: Vector2i = spawn.get("cell", Vector2i(-1, -1))
		if cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y:
			_draw_entity(cell, str(spawn.get("kind", "")), str(spawn.get("subtype", "")))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_instance_valid(blueprint):
		var local: Vector2 = event.position - _board_origin
		var cell := Vector2i(floori(local.x / _cell_pixels), floori(local.y / _cell_pixels))
		var size: Vector2i = blueprint.get("grid_size")
		if cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y:
			cell_selected.emit(cell)
			accept_event()


func _components(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if child.has_method("to_component_data"):
			result.append(child)
		else:
			result.append_array(_components(child))
	return result


func _kind_mark(component: Node) -> String:
	if component.has_method("component_kind"):
		return str(component.component_kind()).left(1).to_upper()
	return "?"


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_board_origin + Vector2(cell) * _cell_pixels, Vector2.ONE * _cell_pixels)


func _draw_entity(cell: Vector2i, kind: String, subtype: String) -> void:
	var center := _cell_rect(cell).get_center()
	var radius := maxf(2.5, _cell_pixels * 0.32)
	var color := Color("ffd15c")
	var mark := "C"
	if kind == "enemy":
		color = Color("ff5269")
		mark = subtype.trim_prefix("boss/").left(1).to_upper()
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		draw_colored_polygon(diamond, Color("321521"))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), color, maxf(1.0, _cell_pixels * 0.07), true)
	else:
		match subtype:
			"coin": color = Color("ffd15c"); mark = "C"
			"shield": color = Color("69eaff"); mark = "S"
			"breaker": color = Color("ff9c56"); mark = "B"
			"heart": color = Color("ff718f"); mark = "H"
			_: color = Color("b48aff"); mark = subtype.left(1).to_upper()
		draw_circle(center, radius, Color("111827"))
		draw_circle(center, radius, color, false, maxf(1.0, _cell_pixels * 0.07))
	if _cell_pixels >= 16.0:
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.38, radius * 0.34), mark, HORIZONTAL_ALIGNMENT_LEFT, radius * 1.4, mini(12, int(_cell_pixels * 0.36)), color)


func _signature() -> String:
	if not is_instance_valid(blueprint):
		return ""
	var values: Array[String] = [str(blueprint.get("grid_size")), str(blueprint.get("start_cell")), str(blueprint.get("portal_cell")), str(blueprint.get("wall_cells")), str(blueprint.get("entity_spawns"))]
	for component in _components(blueprint):
		values.append(str(component.to_component_data()))
	return "|".join(values)
