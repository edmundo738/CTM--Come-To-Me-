@tool
extends Resource

@export_group("Identidade")
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Comportamento")
@export_enum("hunter", "sentry", "wisp", "rusher", "patrol", "mirror") var movement_profile: String = "hunter"

@export_group("Apresentação")
@export_range(0.01, 1.0, 0.01) var move_duration: float = 0.14
@export_range(0.25, 3.0, 0.05) var visual_scale: float = 1.0
@export_range(1.0, 256.0, 1.0) var glow_radius: float = 42.0
@export var idle_core_color: Color = Color.WHITE
@export var alert_core_color: Color = Color.WHITE
@export var glow_color: Color = Color.WHITE
