@tool
extends Node2D

const DefaultCatalog = preload("res://components/component_catalog.tres")

@export_group("Missao")
@export var mission_title: String = "Nova missão"
@export_multiline var mission_hint: String = ""
@export_enum("Alcançar o portal:escape", "Abrir com mecanismos:environment") var mission_objective: String = "escape"

@export_group("Mapa")
@export var level_id: String = ""
@export_range(0, 200, 1) var campaign_floor: int = 0
@export_enum("Manual", "Base WFC editada") var layout_source: String = "Manual"
@export var layout_seed: int = 0
@export var grid_size: Vector2i = Vector2i(13, 9)
@export var start_cell: Vector2i = Vector2i(1, 4)
@export var portal_cell: Vector2i = Vector2i(11, 4)
@export var wall_cells: Array[Vector2i] = []
@export var authoritative_spawns: bool = false
@export var entity_spawns: Array[Dictionary] = []

@export_group("Biblioteca")
@export var component_catalog: Resource = DefaultCatalog


func compile_level() -> Dictionary:
	var instances: Array[Node] = []
	_collect_components(self, instances)
	var result: Dictionary = component_catalog.compile_nodes(instances)
	if grid_size.x < 5 or grid_size.y < 5:
		result.errors.append("A grelha precisa de pelo menos 5x5 celulas para ter interior jogavel")
	if not _inside(start_cell) or not _inside(portal_cell):
		result.errors.append("Inicio ou portal fora da grelha")
	if not _inside_play_area(start_cell) or not _inside_play_area(portal_cell):
		result.errors.append("Inicio e portal precisam de ficar dentro da borda solida")
	if start_cell == portal_cell:
		result.errors.append("Inicio e portal precisam de casas diferentes")
	var seen_walls: Dictionary = {}
	for cell in wall_cells:
		if not _inside(cell):
			result.errors.append("Parede fora da grelha: %s" % cell)
		elif not _inside_play_area(cell):
			result.errors.append("A borda externa e fixa; paredes so podem ficar no interior")
		elif cell == start_cell or cell == portal_cell:
			result.errors.append("Parede ocupa o inicio ou o portal: %s" % cell)
		elif seen_walls.has(cell):
			result.errors.append("Parede repetida: %s" % cell)
		seen_walls[cell] = true
	for component in result.components:
		if not _inside(component.pos):
			result.errors.append("Componente %s fora da grelha: %s" % [component.id, component.pos])
		elif not _inside_play_area(component.pos):
			result.errors.append("Componente %s ocupa a borda fixa do mundo" % component.id)
		elif seen_walls.has(component.pos):
			result.errors.append("Componente %s ocupa uma parede: %s" % [component.id, component.pos])
		elif component.pos == start_cell or component.pos == portal_cell:
			result.errors.append("Componente %s ocupa o inicio ou o portal" % component.id)
	for spawn in entity_spawns:
		var cell: Vector2i = spawn.get("cell", Vector2i(-1, -1))
		if not _inside(cell) or not _inside_play_area(cell):
			result.errors.append("Elemento %s fora da area jogavel: %s" % [spawn.get("subtype", spawn.get("kind", "?")), cell])
		elif seen_walls.has(cell):
			result.errors.append("Elemento ocupa uma parede: %s" % cell)
		elif cell == start_cell or cell == portal_cell:
			result.errors.append("Elemento ocupa o inicio ou portal: %s" % cell)
	if mission_objective == "environment" and result.environment.plates.is_empty():
		result.errors.append("Missao de mecanismos precisa de pelo menos uma placa")
	if _inside(start_cell) and _inside(portal_cell) and not _has_wall_route(start_cell, portal_cell, seen_walls):
		result.errors.append("Nao existe caminho livre entre o inicio e o portal")
	if result.errors.is_empty():
		result["ok"] = true
		result["level"] = {
			"id": level_id, "name": mission_title, "hint": mission_hint,
			"campaign_floor": campaign_floor, "layout_source": layout_source, "layout_seed": layout_seed,
			"objective_type": mission_objective, "size": grid_size,
			"start": start_cell, "portal": portal_cell, "walls": wall_cells.duplicate(),
			"authoritative_spawns": authoritative_spawns,
			"entity_spawns": entity_spawns.duplicate(true),
		"mission_title": mission_title, "mission_hint": mission_hint,
		}
	return result


func _collect_components(root: Node, result: Array[Node]) -> void:
	for child in root.get_children():
		if child.has_method("to_component_data"):
			result.append(child)
		else:
			_collect_components(child, result)


func editor_attach_component(component: Node) -> void:
	if component == null:
		return
	if component.get_parent() != self:
		add_child(component)
	component.owner = self


func editor_detach_component(component: Node) -> void:
	if component != null and component.get_parent() == self:
		remove_child(component)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func _inside_play_area(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < grid_size.x - 1 and cell.y < grid_size.y - 1


func _has_wall_route(origin: Vector2i, destination: Vector2i, walls: Dictionary) -> bool:
	if not _inside_play_area(origin) or not _inside_play_area(destination):
		return false
	var pending: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: true}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		if current == destination:
			return true
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if not _inside_play_area(next) or walls.has(next) or visited.has(next):
				continue
			visited[next] = true
			pending.append(next)
	return false
