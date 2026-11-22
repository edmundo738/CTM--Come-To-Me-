@tool
extends VBoxContainer

signal playtest_requested(blueprint_path: String)

const BlueprintScript = preload("res://components/level_blueprint.gd")
const ComponentCatalog = preload("res://components/component_catalog.tres")
const Generator = preload("res://level_generator.gd")
const DefaultRoomProfile = preload("res://content/definitions/room_profile_neon_ruins.tres")
const GridView = preload("res://addons/ctm_workshop/workshop_grid.gd")
const WorkshopCatalog = preload("res://content/game_content_catalog.tres")
const CampaignCatalogResource = preload("res://content/campaign_level_catalog.tres")
const CAMPAIGN_CATALOG_PATH := "res://content/campaign_level_catalog.tres"

var undo_redo: EditorUndoRedoManager
var blueprint: Node
var grid_view: Control
var status_label: Label
var filename_edit: LineEdit
var mission_title_edit: LineEdit
var mission_hint_edit: TextEdit
var objective_picker: OptionButton
var width_spin: SpinBox
var height_spin: SpinBox
var seed_edit: LineEdit
var component_picker: OptionButton
var entity_picker: OptionButton
var authoritative_spawns_check: CheckButton
var source_picker: OptionButton
var target_picker: OptionButton
var tool_mode := "wall"
var file_dialog: FileDialog
var campaign_floor_picker: OptionButton
var campaign_map_button: Button
var campaign_link_button: Button
var campaign_unlink_button: Button
var campaign_status: Label
var left_tools_panel: ScrollContainer
var tools_toggle_button: Button
var _last_signature := ""
var _pending_move_index := -1


func _ready() -> void:
	name = "OficinaComeToMe"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_interface()
	refresh_from_editor()
	var poll := Timer.new()
	poll.wait_time = 0.3
	poll.timeout.connect(_poll_editor_changes)
	add_child(poll)
	poll.start()


func _build_interface() -> void:
	var heading := Label.new()
	heading.text = "OFICINA COME TO ME   /   MAPAS E MISSOES"
	heading.add_theme_font_size_override("font_size", 19)
	add_child(heading)
	var intro := Label.new()
	intro.text = "Monta o mapa por cliques. As pecas sao cenas reais; o teste usa as regras do jogo e nao grava a campanha."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	var campaign_row := HBoxContainer.new()
	add_child(campaign_row)
	var campaign_label := Label.new()
	campaign_label.text = "Fase"
	campaign_row.add_child(campaign_label)
	campaign_floor_picker = OptionButton.new()
	campaign_floor_picker.custom_minimum_size.x = 220.0
	campaign_floor_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_floor_picker.item_selected.connect(_on_campaign_floor_selected)
	campaign_row.add_child(campaign_floor_picker)
	campaign_map_button = Button.new()
	campaign_map_button.pressed.connect(_open_or_create_campaign_map)
	campaign_row.add_child(campaign_map_button)
	campaign_link_button = Button.new()
	campaign_link_button.text = "Ligar mapa atual"
	campaign_link_button.pressed.connect(_link_current_blueprint)
	campaign_row.add_child(campaign_link_button)
	campaign_unlink_button = Button.new()
	campaign_unlink_button.text = "Desligar"
	campaign_unlink_button.pressed.connect(_unlink_campaign_floor)
	campaign_row.add_child(campaign_unlink_button)
	tools_toggle_button = Button.new()
	tools_toggle_button.text = "Recolher ferramentas"
	tools_toggle_button.pressed.connect(_toggle_tools_panel)
	campaign_row.add_child(tools_toggle_button)
	campaign_status = Label.new()
	campaign_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(campaign_status)
	_populate_campaign_floors()
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	left_tools_panel = ScrollContainer.new()
	left_tools_panel.custom_minimum_size.x = 225.0
	split.add_child(left_tools_panel)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tools_panel.add_child(left)
	_add_section(left, "1. Mapa")
	filename_edit = LineEdit.new()
	filename_edit.text = "meu_mapa"
	filename_edit.placeholder_text = "nome simples do mapa"
	left.add_child(filename_edit)
	var create_row := HBoxContainer.new()
	left.add_child(create_row)
	_add_button(create_row, "Criar mapa", _create_map)
	_add_button(create_row, "Abrir mapa...", _open_map_dialog)
	_add_button(left, "Usar cena aberta", refresh_from_editor)
	width_spin = _add_spin(left, "Largura", 5, 64, 13)
	height_spin = _add_spin(left, "Altura", 5, 64, 9)
	width_spin.value_changed.connect(_on_size_changed)
	height_spin.value_changed.connect(_on_size_changed)
	seed_edit = LineEdit.new()
	seed_edit.text = "20261105"
	seed_edit.placeholder_text = "seed base da campanha"
	left.add_child(seed_edit)
	_add_button(left, "Gerar layout com WFC", _generate_wfc)
	_add_section(left, "2. Ferramenta de pintura")
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	left.add_child(tool_grid)
	for option in [["Parede", "wall"], ["Chao", "floor"], ["Inicio", "start"], ["Portal", "portal"], ["Inimigo/pickup", "entity"], ["Mover", "move"], ["Mecanismo", "piece"], ["Apagar", "erase"]]:
		var button := Button.new()
		button.text = option[0]
		button.pressed.connect(_choose_tool.bind(option[1]))
		tool_grid.add_child(button)
	component_picker = OptionButton.new()
	left.add_child(component_picker)
	_populate_component_picker()
	_add_section(left, "Inimigos e pickups")
	entity_picker = OptionButton.new()
	left.add_child(entity_picker)
	_populate_entity_picker()
	authoritative_spawns_check = CheckButton.new()
	authoritative_spawns_check.text = "Usar apenas os elementos colocados"
	authoritative_spawns_check.toggled.connect(_on_authoritative_spawns_toggled)
	left.add_child(authoritative_spawns_check)
	_add_section(left, "3. Ligacoes")
	source_picker = OptionButton.new()
	target_picker = OptionButton.new()
	source_picker.item_selected.connect(_on_link_source_selected)
	left.add_child(source_picker)
	left.add_child(target_picker)
	_add_button(left, "Ligar origem ao destino", _link_components)
	_add_section(left, "4. Objetivo e apresentacao")
	mission_title_edit = LineEdit.new()
	mission_title_edit.placeholder_text = "titulo da missao"
	left.add_child(mission_title_edit)
	mission_title_edit.text_submitted.connect(_apply_mission_text)
	mission_title_edit.focus_exited.connect(_apply_mission_title)
	mission_hint_edit = TextEdit.new()
	mission_hint_edit.custom_minimum_size.y = 65.0
	mission_hint_edit.placeholder_text = "nota curta que aparece no mapa"
	left.add_child(mission_hint_edit)
	mission_hint_edit.focus_exited.connect(_apply_mission_hint)
	objective_picker = OptionButton.new()
	objective_picker.add_item("Chegar ao portal")
	objective_picker.set_item_metadata(0, "escape")
	objective_picker.add_item("Abrir o portal com mecanismos")
	objective_picker.set_item_metadata(1, "environment")
	objective_picker.item_selected.connect(_apply_objective)
	left.add_child(objective_picker)
	_add_section(left, "5. Guardar e testar")
	var actions := HBoxContainer.new()
	left.add_child(actions)
	_add_button(actions, "Guardar", _save_map)
	_add_button(actions, "Validar", _validate_map)
	_add_button(actions, "Testar no jogo", _playtest)
	_add_button(left, "Abrir catalogo de conteudo", _open_content_catalog)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 58.0
	left.add_child(status_label)
	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(map_frame)
	grid_view = GridView.new()
	grid_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_view.cell_selected.connect(_on_cell_selected)
	map_frame.add_child(grid_view)
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tscn", "Cenas de mapa")
	file_dialog.file_selected.connect(_open_map_path)
	add_child(file_dialog)


func refresh_from_editor() -> void:
	var selected := EditorInterface.get_edited_scene_root()
	blueprint = selected if selected != null and selected.has_method("compile_level") else null
	if blueprint != null:
		var saved_floor := int(blueprint.get("campaign_floor"))
		if saved_floor >= 1 and saved_floor <= 200 and campaign_floor_picker != null:
			campaign_floor_picker.select(saved_floor - 1)
		width_spin.set_value_no_signal(blueprint.get("grid_size").x)
		height_spin.set_value_no_signal(blueprint.get("grid_size").y)
		mission_title_edit.text = str(blueprint.get("mission_title"))
		mission_hint_edit.text = str(blueprint.get("mission_hint"))
		objective_picker.select(0 if str(blueprint.get("mission_objective")) == "escape" else 1)
		authoritative_spawns_check.set_pressed_no_signal(bool(blueprint.get("authoritative_spawns")))
		status_label.text = "Mapa ativo: %s  |  %d pecas" % [blueprint.scene_file_path.get_file(), _components(blueprint).size()]
	else:
		status_label.text = "Abre ou cria uma cena de mapa para editar. O exemplo de componentes tambem pode ser aberto."
	if is_instance_valid(grid_view):
		grid_view.show_blueprint(blueprint)
	_refresh_link_pickers()
	_set_editor_controls_enabled(blueprint != null)
	_refresh_campaign_status()
	_last_signature = _scene_signature(blueprint)


func _poll_editor_changes() -> void:
	var selected := EditorInterface.get_edited_scene_root()
	var next := selected if selected != null and selected.has_method("compile_level") else null
	var signature := _scene_signature(next)
	if next != blueprint or signature != _last_signature:
		refresh_from_editor()
	else:
		_refresh_campaign_status()


func _scene_signature(root: Node) -> String:
	if not is_instance_valid(root):
		return ""
	var values: Array[String] = [str(root.get("campaign_floor")), str(root.get("layout_source")), str(root.get("layout_seed")), str(root.get("grid_size")), str(root.get("start_cell")), str(root.get("portal_cell")), str(root.get("wall_cells")), str(root.get("entity_spawns")), str(root.get("authoritative_spawns")), str(root.get("mission_title")), str(root.get("mission_hint")), str(root.get("mission_objective"))]
	for component in _components(root):
		values.append(str(component.to_component_data()))
	return "|".join(values)


func _set_editor_controls_enabled(enabled: bool) -> void:
	for control in [width_spin, height_spin, mission_title_edit, mission_hint_edit, objective_picker, component_picker, entity_picker, authoritative_spawns_check, source_picker, target_picker]:
		if control is LineEdit or control is TextEdit or control is SpinBox:
			control.editable = enabled
		else:
			control.disabled = not enabled


func _create_map() -> void:
	var base := filename_edit.text.strip_edges().to_lower().replace(" ", "_")
	if base.is_empty():
		base = "meu_mapa"
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		base = base.replace(character, "_")
	var directory := "res://levels/authored"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var requested_base := base
	var copy_index := 2
	while FileAccess.file_exists("%s/%s.tscn" % [directory, base]):
		base = "%s_%d" % [requested_base, copy_index]
		copy_index += 1
	filename_edit.text = base
	var root := Node2D.new()
	root.name = base.to_pascal_case()
	root.set_script(BlueprintScript)
	root.set("level_id", base)
	root.set("mission_title", base.replace("_", " ").capitalize())
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	if error == OK:
		error = ResourceSaver.save(packed, "%s/%s.tscn" % [directory, base])
	if error != OK:
		_set_status("Nao foi possivel criar a cena: %s" % error_string(error))
		return
	_open_map_path("%s/%s.tscn" % [directory, base])


func _open_map_dialog() -> void:
	file_dialog.popup_centered_ratio(0.72)


func _open_map_path(path: String) -> void:
	EditorInterface.open_scene_from_path(path)
	call_deferred("refresh_from_editor")


func _save_map() -> void:
	if blueprint == null:
		return
	EditorInterface.save_scene()
	_set_status("Mapa guardado em %s" % blueprint.scene_file_path)


func _on_size_changed(_value: float) -> void:
	if blueprint == null:
		return
	var value := Vector2i(int(width_spin.value), int(height_spin.value))
	_edit_property(blueprint, "grid_size", value, "Alterar tamanho do mapa")
	grid_view.show_blueprint(blueprint)


func _choose_tool(value: String) -> void:
	tool_mode = value
	_set_status("Ferramenta ativa: %s. Clica numa casa do mapa." % value.capitalize())
	_pending_move_index = -1


func _toggle_tools_panel() -> void:
	left_tools_panel.visible = not left_tools_panel.visible
	tools_toggle_button.text = "Ocultar ferramentas" if left_tools_panel.visible else "Mostrar ferramentas"


func _on_cell_selected(cell: Vector2i) -> void:
	if blueprint == null:
		return
	var walls: Array = blueprint.get("wall_cells").duplicate()
	match tool_mode:
		"wall":
			if not blueprint._inside_play_area(cell):
				_set_status("A borda do mundo e fixa. Pinta apenas as casas interiores.")
				return
			if cell == blueprint.get("start_cell") or cell == blueprint.get("portal_cell") or _component_at(cell) != null or _entity_at(cell) >= 0:
				_set_status("Essa casa ja tem inicio, portal ou peca. Move-a primeiro.")
				return
			if walls.has(cell): walls.erase(cell)
			else: walls.append(cell)
			_edit_property(blueprint, "wall_cells", walls, "Pintar parede")
		"floor":
			if not blueprint._inside_play_area(cell):
				return
			if walls.has(cell):
				walls.erase(cell)
				_edit_property(blueprint, "wall_cells", walls, "Limpar parede")
		"start", "portal":
			if _entity_at(cell) >= 0:
				_set_status("Move primeiro o elemento que ocupa essa casa.")
				return
			if walls.has(cell):
				walls.erase(cell)
				_edit_property(blueprint, "wall_cells", walls, "Abrir casa do objetivo")
			_edit_property(blueprint, "start_cell" if tool_mode == "start" else "portal_cell", cell, "Mover inicio" if tool_mode == "start" else "Mover portal")
		"entity": _place_entity(cell)
		"move": _move_entity(cell)
		"piece": _place_component(cell)
		"erase":
			if _entity_at(cell) >= 0:
				_remove_entity(cell)
			else:
				_remove_component(cell)
	grid_view.queue_redraw()
	_refresh_link_pickers()


func _place_component(cell: Vector2i) -> void:
	if blueprint.get("wall_cells").has(cell) or _entity_at(cell) >= 0:
		_set_status("A casa precisa de estar livre antes de colocar um mecanismo.")
		return
	var kind: StringName = component_picker.get_item_metadata(component_picker.selected)
	var instance: Node = ComponentCatalog.create_instance(kind)
	if instance == null:
		_set_status("Esta peca ainda nao tem uma cena valida no catalogo.")
		return
	var identifier := _next_component_id(str(kind))
	instance.set("component_id", identifier)
	instance.set("cell", cell)
	undo_redo.create_action("Colocar %s" % identifier)
	undo_redo.add_do_method(blueprint, "editor_attach_component", instance)
	undo_redo.add_undo_method(blueprint, "editor_detach_component", instance)
	undo_redo.add_do_reference(instance)
	undo_redo.commit_action()
	_set_status("Peca colocada: %s. Ctrl+Z desfaz." % identifier)


func _place_entity(cell: Vector2i) -> void:
	if entity_picker.item_count == 0 or entity_picker.selected < 0:
		return
	if not blueprint._inside_play_area(cell) or blueprint.get("wall_cells").has(cell) or cell == blueprint.get("start_cell") or cell == blueprint.get("portal_cell") or _entity_at(cell) >= 0 or _component_at(cell) != null:
		_set_status("Escolhe uma casa livre dentro do mapa.")
		return
	var definition: Dictionary = entity_picker.get_item_metadata(entity_picker.selected)
	var spawns: Array[Dictionary] = blueprint.get("entity_spawns").duplicate(true)
	spawns.append({"kind": str(definition.kind), "subtype": str(definition.subtype), "cell": cell})
	_edit_property(blueprint, "entity_spawns", spawns, "Colocar %s" % entity_picker.get_item_text(entity_picker.selected))
	grid_view.queue_redraw()
	_set_status("%s colocado. Usa Mover para reposicionar; Ctrl+Z desfaz." % entity_picker.get_item_text(entity_picker.selected))


func _move_entity(cell: Vector2i) -> void:
	var spawns: Array[Dictionary] = blueprint.get("entity_spawns").duplicate(true)
	if _pending_move_index < 0:
		_pending_move_index = _entity_at(cell)
		if _pending_move_index < 0:
			_set_status("Clica primeiro num inimigo ou pickup do mapa.")
		else:
			_set_status("Elemento selecionado. Clica na nova casa.")
		return
	if not blueprint._inside_play_area(cell) or blueprint.get("wall_cells").has(cell) or cell == blueprint.get("start_cell") or cell == blueprint.get("portal_cell") or (_entity_at(cell) >= 0 and _entity_at(cell) != _pending_move_index) or _component_at(cell) != null:
		_set_status("Essa casa não está livre. Escolhe outra.")
		return
	spawns[_pending_move_index].cell = cell
	_edit_property(blueprint, "entity_spawns", spawns, "Mover elemento")
	_pending_move_index = -1
	grid_view.queue_redraw()
	_set_status("Elemento movido. Ctrl+Z desfaz.")


func _remove_entity(cell: Vector2i) -> void:
	var index := _entity_at(cell)
	if index < 0:
		_remove_component(cell)
		return
	var spawns: Array[Dictionary] = blueprint.get("entity_spawns").duplicate(true)
	spawns.remove_at(index)
	_edit_property(blueprint, "entity_spawns", spawns, "Remover elemento")
	_pending_move_index = -1
	grid_view.queue_redraw()
	_set_status("Elemento removido. Ctrl+Z restaura-o.")


func _entity_at(cell: Vector2i) -> int:
	if blueprint == null:
		return -1
	var spawns: Array = blueprint.get("entity_spawns")
	for index in spawns.size():
		if spawns[index].get("cell", Vector2i(-1, -1)) == cell:
			return index
	return -1


func _on_authoritative_spawns_toggled(pressed: bool) -> void:
	if blueprint != null:
		_edit_property(blueprint, "authoritative_spawns", pressed, "Usar apenas elementos colocados")


func _remove_component(cell: Vector2i) -> void:
	var instance := _component_at(cell)
	if instance == null:
		_set_status("Nao ha peca nessa casa.")
		return
	undo_redo.create_action("Remover %s" % str(instance.get("component_id")))
	undo_redo.add_do_method(blueprint, "editor_detach_component", instance)
	undo_redo.add_undo_method(blueprint, "editor_attach_component", instance)
	undo_redo.add_undo_reference(instance)
	undo_redo.commit_action()
	_set_status("Peca removida. Ctrl+Z restaura-a.")


func _link_components() -> void:
	if source_picker.item_count == 0 or target_picker.item_count == 0:
		_set_status("Coloca primeiro uma origem e um destino compativeis.")
		return
	var source_id := str(source_picker.get_item_metadata(source_picker.selected))
	var target_id := str(target_picker.get_item_metadata(target_picker.selected))
	var source := _component_by_id(source_id)
	if source == null:
		return
	var outputs: PackedStringArray = source.get("output_ids").duplicate()
	if outputs.has(target_id):
		_set_status("Esta ligacao ja existe.")
		return
	outputs.append(target_id)
	_edit_property(source, "output_ids", outputs, "Ligar %s a %s" % [source_id, target_id])
	_refresh_link_pickers()
	_set_status("Ligacao criada: %s -> %s. O validador confirma os canais." % [source_id, target_id])


func _apply_mission_text(value: String = "") -> void:
	if blueprint == null:
		return
	var text := value if not value.is_empty() else mission_title_edit.text
	_edit_property(blueprint, "mission_title", text, "Alterar titulo da missao")


func _apply_mission_title() -> void:
	_apply_mission_text(mission_title_edit.text)


func _apply_mission_hint() -> void:
	if blueprint != null:
		_edit_property(blueprint, "mission_hint", mission_hint_edit.text, "Alterar nota da missao")


func _apply_objective(index: int) -> void:
	if blueprint != null:
		_edit_property(blueprint, "mission_objective", str(objective_picker.get_item_metadata(index)), "Alterar objetivo")


func _validate_map() -> bool:
	if blueprint == null:
		_set_status("Abre um mapa primeiro.")
		return false
	var result: Dictionary = blueprint.compile_level()
	if result.get("ok", false):
		_set_status("Mapa valido: %s pecas, objetivo %s. A validacao usa canais e regras reais." % [result.components.size(), result.level.objective_type])
		return true
	_set_status("Corrige estes pontos: %s" % " | ".join(result.errors))
	return false


func _generate_wfc() -> void:
	if blueprint == null:
		_set_status("Cria ou abre um mapa primeiro.")
		return
	var floor_number := _selected_campaign_floor()
	var campaign_size: Vector2i = WorkshopCatalog.floor_size(floor_number)
	var biome: Resource = WorkshopCatalog.biome_for_floor(floor_number)
	var profile: Resource = biome.get("room_profile") if biome != null else DefaultRoomProfile
	var tileset: Resource = biome.get("wfc_tile_set") if biome != null else null
	var campaign_seed := int(seed_edit.text) if seed_edit.text.is_valid_int() else 20261105
	var level_seed := campaign_seed + floor_number * 7919
	width_spin.set_value_no_signal(campaign_size.x)
	height_spin.set_value_no_signal(campaign_size.y)
	var result: Dictionary = Generator.new().generate(campaign_size.x, campaign_size.y, level_seed, profile, tileset)
	if not result.get("ok", false):
		_set_status("WFC nao encontrou uma composicao valida: %s" % result.get("reason", "sem detalhe"))
		return
	var walls: Array[Vector2i] = []
	for y in result.grid.size():
		for x in result.grid[y].size():
			if int(result.grid[y][x]) == 1 and x > 0 and y > 0 and x < campaign_size.x - 1 and y < campaign_size.y - 1:
				walls.append(Vector2i(x, y))
	_edit_multiple_properties(blueprint, {
		"grid_size": campaign_size,
		"campaign_floor": floor_number,
		"layout_source": "Base WFC editada",
		"layout_seed": level_seed,
		"start_cell": result.start,
		"portal_cell": result.goal,
		"wall_cells": walls,
	}, "Gerar mapa com WFC")
	grid_view.show_blueprint(blueprint)
	_set_status("Base WFC real da fase %03d aplicada (seed %d, %d tentativas). Agora podes editar, ligar ou manter o mapa manual." % [floor_number, level_seed, result.attempts])


func _playtest() -> void:
	if not _validate_map():
		return
	if blueprint.scene_file_path.is_empty():
		_set_status("Guarda este mapa como cena antes de testar.")
		return
	_save_map()
	playtest_requested.emit(blueprint.scene_file_path)


func _open_content_catalog() -> void:
	EditorInterface.edit_resource(WorkshopCatalog)


func _populate_campaign_floors() -> void:
	if campaign_floor_picker == null:
		return
	var selected_floor := _selected_campaign_floor()
	campaign_floor_picker.clear()
	for floor_number in range(1, 201):
		var linked := CampaignCatalogResource.blueprint_for_floor(floor_number) != null
		campaign_floor_picker.add_item("%03d  |  %s" % [floor_number, "MANUAL" if linked else "WFC"])
	campaign_floor_picker.select(clampi(selected_floor - 1, 0, 199))
	_refresh_campaign_status()


func _selected_campaign_floor() -> int:
	return campaign_floor_picker.selected + 1 if campaign_floor_picker != null and campaign_floor_picker.selected >= 0 else 1


func _on_campaign_floor_selected(_index: int) -> void:
	_refresh_campaign_status()


func _refresh_campaign_status() -> void:
	if campaign_floor_picker == null or campaign_map_button == null:
		return
	var floor_number := _selected_campaign_floor()
	var linked: PackedScene = CampaignCatalogResource.blueprint_for_floor(floor_number)
	var map_path := str(linked.resource_path) if linked != null else ""
	campaign_floor_picker.set_item_text(floor_number - 1, "%03d  |  %s" % [floor_number, "MANUAL" if linked != null else "WFC"])
	campaign_map_button.text = "Abrir mapa ligado" if linked != null else "Criar mapa desta fase"
	campaign_unlink_button.disabled = linked == null
	campaign_link_button.disabled = blueprint == null or blueprint.scene_file_path.is_empty()
	if linked != null:
		campaign_status.text = "Fase %03d: mapa manual ligado (%s). As outras fases continuam com WFC e agenda normais." % [floor_number, map_path.get_file()]
	else:
		campaign_status.text = "Fase %03d: usa WFC e a agenda habitual. Podes criar uma base WFC editavel ou um mapa manual." % floor_number


func _open_or_create_campaign_map() -> void:
	var floor_number := _selected_campaign_floor()
	var linked: PackedScene = CampaignCatalogResource.blueprint_for_floor(floor_number)
	if linked != null and not linked.resource_path.is_empty():
		_open_map_path(linked.resource_path)
		return
	var path := "res://levels/authored/floor_%03d_workshop.tscn" % floor_number
	if FileAccess.file_exists(path):
		_open_map_path(path)
		return
	var size: Vector2i = WorkshopCatalog.floor_size(floor_number)
	var root := Node2D.new()
	root.name = "CampaignFloor%03d" % floor_number
	root.set_script(BlueprintScript)
	root.set("level_id", "campaign_floor_%03d" % floor_number)
	root.set("campaign_floor", floor_number)
	root.set("grid_size", size)
	root.set("start_cell", Vector2i(1, size.y / 2))
	root.set("portal_cell", Vector2i(size.x - 2, size.y / 2))
	root.set("mission_title", "Fase %03d" % floor_number)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	if error == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/authored"))
		error = ResourceSaver.save(packed, path)
	if error != OK:
		_set_status("Nao foi possivel criar o mapa da fase: %s" % error_string(error))
		return
	_open_map_path(path)


func _link_current_blueprint() -> void:
	if not _validate_map():
		return
	if blueprint.scene_file_path.is_empty():
		_set_status("Guarda o mapa como cena antes de o ligar a uma fase da campanha.")
		return
	var floor_number := _selected_campaign_floor()
	if int(blueprint.get("campaign_floor")) != floor_number:
		_edit_property(blueprint, "campaign_floor", floor_number, "Definir fase da campanha")
	EditorInterface.save_scene()
	var packed := ResourceLoader.load(blueprint.scene_file_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		_set_status("Nao foi possivel carregar a cena guardada do mapa.")
		return
	var previous: PackedScene = CampaignCatalogResource.blueprint_for_floor(floor_number)
	if previous == packed:
		_set_status("Este mapa ja esta ligado a fase %03d." % floor_number)
		return
	undo_redo.create_action("Ligar mapa a fase %03d" % floor_number)
	undo_redo.add_do_method(CampaignCatalogResource, "set_floor", floor_number, packed)
	undo_redo.add_undo_method(CampaignCatalogResource, "set_floor", floor_number, previous)
	undo_redo.add_do_method(self, "_persist_campaign_catalog")
	undo_redo.add_undo_method(self, "_persist_campaign_catalog")
	undo_redo.commit_action()
	_populate_campaign_floors()
	_set_status("Mapa ligado a fase %03d. Desfazer/Refazer do Godot tambem controla esta ligacao." % floor_number)


func _unlink_campaign_floor() -> void:
	var floor_number := _selected_campaign_floor()
	var previous: PackedScene = CampaignCatalogResource.blueprint_for_floor(floor_number)
	if previous == null:
		return
	undo_redo.create_action("Voltar fase %03d a geracao procedural" % floor_number)
	undo_redo.add_do_method(CampaignCatalogResource, "set_floor", floor_number, null)
	undo_redo.add_undo_method(CampaignCatalogResource, "set_floor", floor_number, previous)
	undo_redo.add_do_method(self, "_persist_campaign_catalog")
	undo_redo.add_undo_method(self, "_persist_campaign_catalog")
	undo_redo.commit_action()
	_populate_campaign_floors()
	_set_status("Fase %03d voltou a usar a geracao WFC e a agenda habituais." % floor_number)


func _persist_campaign_catalog() -> void:
	var error := ResourceSaver.save(CampaignCatalogResource, CAMPAIGN_CATALOG_PATH)
	if error != OK:
		push_error("Nao foi possivel guardar o catalogo da campanha: %s" % error_string(error))


func _edit_property(object: Object, property: StringName, value: Variant, label: String) -> void:
	_edit_multiple_properties(object, {property: value}, label)


func _edit_multiple_properties(object: Object, values: Dictionary, label: String) -> void:
	if undo_redo == null:
		_set_status("O historico de desfazer do Godot nao esta disponivel.")
		return
	var has_changes := false
	for key in values:
		if object.get(key) != values[key]:
			has_changes = true
	if not has_changes:
		return
	undo_redo.create_action(label)
	for key in values:
		undo_redo.add_do_property(object, key, values[key])
		undo_redo.add_undo_property(object, key, object.get(key))
	undo_redo.commit_action()
	grid_view.queue_redraw()


func _populate_component_picker() -> void:
	component_picker.clear()
	for definition in ComponentCatalog.get("definitions"):
		component_picker.add_item(str(definition.get("display_name")))
		component_picker.set_item_metadata(component_picker.item_count - 1, definition.get("kind"))


func _populate_entity_picker() -> void:
	entity_picker.clear()
	for pickup in [["Moeda", "coin"], ["Escudo", "shield"], ["Carga de demolição", "breaker"], ["Coração", "heart"]]:
		_add_entity_option(pickup[0], "pickup", pickup[1])
	for definition in WorkshopCatalog.get("powerups"):
		_add_entity_option("Poder: %s" % str(definition.get("display_name")), "pickup", "powerup/" + str(definition.get("id")))
	for definition in WorkshopCatalog.get("enemies"):
		_add_entity_option("Inimigo: %s" % str(definition.get("display_name")), "enemy", str(definition.get("id")))
	_add_entity_option("Inimigo: Guardião", "enemy", "warden")
	for definition in WorkshopCatalog.get("bosses"):
		_add_entity_option("Chefe: %s" % str(definition.get("display_name")), "enemy", "boss/" + str(definition.get("id")))


func _add_entity_option(label: String, kind: String, subtype: String) -> void:
	entity_picker.add_item(label)
	entity_picker.set_item_metadata(entity_picker.item_count - 1, {"kind": kind, "subtype": subtype})


func _refresh_link_pickers() -> void:
	if source_picker == null or target_picker == null:
		return
	source_picker.clear()
	target_picker.clear()
	if blueprint == null:
		return
	for component in _components(blueprint):
		var identifier := str(component.get("component_id"))
		var kind := str(component.component_kind()) if component.has_method("component_kind") else ""
		var definition: Resource = ComponentCatalog.definition_for(StringName(kind))
		if definition == null:
			continue
		var output_channel := StringName(definition.get("output_channel"))
		if output_channel != &"":
			source_picker.add_item("%s  (%s)" % [identifier, kind])
			source_picker.set_item_metadata(source_picker.item_count - 1, identifier)
	if source_picker.item_count > 0:
		_on_link_source_selected(source_picker.selected)


func _on_link_source_selected(index: int) -> void:
	if target_picker == null:
		return
	target_picker.clear()
	if blueprint == null or index < 0 or index >= source_picker.item_count:
		return
	var source_id := str(source_picker.get_item_metadata(index))
	var source := _component_by_id(source_id)
	if source == null:
		return
	var source_definition: Resource = ComponentCatalog.definition_for(StringName(source.component_kind()))
	var output_channel := StringName(source_definition.get("output_channel")) if source_definition != null else &""
	for component in _components(blueprint):
		var kind := StringName(component.component_kind()) if component.has_method("component_kind") else &""
		var definition: Resource = ComponentCatalog.definition_for(kind)
		if definition == null or StringName(definition.get("input_channel")) != output_channel:
			continue
		var identifier := str(component.get("component_id"))
		target_picker.add_item("%s  (%s)" % [identifier, str(kind)])
		target_picker.set_item_metadata(target_picker.item_count - 1, identifier)


func _components(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if child.has_method("to_component_data"):
			result.append(child)
		else:
			result.append_array(_components(child))
	return result


func _component_at(cell: Vector2i) -> Node:
	for component in _components(blueprint):
		if component.get("cell") == cell:
			return component
	return null


func _component_by_id(identifier: String) -> Node:
	for component in _components(blueprint):
		if str(component.get("component_id")) == identifier:
			return component
	return null


func _next_component_id(kind: String) -> String:
	var index := 1
	while _component_by_id("%s_%d" % [kind, index]) != null:
		index += 1
	return "%s_%d" % [kind, index]


func _add_section(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color("71e6de"))
	parent.add_child(label)
	var line := HSeparator.new()
	parent.add_child(line)


func _add_button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _add_spin(parent: VBoxContainer, label: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 90.0
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
