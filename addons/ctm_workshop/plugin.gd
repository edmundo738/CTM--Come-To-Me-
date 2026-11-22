@tool
extends EditorPlugin

const WorkshopPanel = preload("res://addons/ctm_workshop/workshop_panel.gd")

var panel: Control


func _enter_tree() -> void:
	panel = WorkshopPanel.new()
	panel.name = "OficinaComeToMe"
	panel.undo_redo = get_undo_redo()
	panel.playtest_requested.connect(_playtest_blueprint)
	EditorInterface.get_editor_main_screen().add_child(panel)
	_make_visible(false)


func _exit_tree() -> void:
	if panel != null:
		panel.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if panel != null:
		panel.visible = visible
		if visible:
			panel.refresh_from_editor()


func _get_plugin_name() -> String:
	return "Oficina CTM"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")


func _playtest_blueprint(path: String) -> void:
	if path.is_empty():
		return
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null or scene_root.scene_file_path.is_empty():
		push_error("Guarda o mapa antes de iniciar o teste.")
		return
	EditorInterface.save_scene()
	var temporary_path := "res://.godot/ctm_workshop_playtest.tscn"
	var wrapper := """
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://main.tscn" id="1_main"]
[ext_resource type="PackedScene" path="%s" id="2_blueprint"]

[node name="ComeToMe" instance=ExtResource("1_main")]
editor_playtest_enabled = true
editor_playtest_blueprint = ExtResource("2_blueprint")
""" % path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Nao foi possivel criar a cena temporaria de teste.")
		return
	file.store_string(wrapper)
	file.close()
	EditorInterface.play_custom_scene(temporary_path)
