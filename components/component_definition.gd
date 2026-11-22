@tool
extends Resource

@export var kind: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var family: StringName = &"mechanism"
@export var input_channel: StringName = &""
@export var output_channel: StringName = &""
@export var tags: PackedStringArray = PackedStringArray()
