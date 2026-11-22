@tool
class_name WfcRoomProfile
extends Resource

@export_group("Identidade")
@export var id: StringName = &""

@export_group("Quantidade de salas")
@export_range(0, 64, 1) var base_rooms: int = 3
@export_range(1.0, 4096.0, 1.0) var area_scale: float = 180.0
@export_range(1, 128, 1) var min_rooms: int = 4
@export_range(1, 128, 1) var max_rooms: int = 12

@export_group("Dimensão das salas")
@export_range(1, 64, 1) var min_room_width: int = 5
@export_range(1, 64, 1) var max_room_width: int = 8
@export_range(1, 64, 1) var min_room_height: int = 4
@export_range(1, 64, 1) var max_room_height: int = 7

@export_group("Ligações")
@export_range(1, 16, 1) var min_link_width: int = 2
@export_range(1, 16, 1) var max_link_width: int = 3
@export_range(0.0, 1.0, 0.01) var extra_loop_chance: float = 0.16

@export_group("Composição especial")
@export var arena_layout: bool = false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("Perfil WFC sem ID")
	if area_scale <= 0.0:
		errors.append("Perfil %s precisa de area_scale positivo" % id)
	if min_rooms < 1 or max_rooms < min_rooms:
		errors.append("Perfil %s tem intervalo de salas inválido" % id)
	if min_room_width < 1 or max_room_width < min_room_width or min_room_height < 1 or max_room_height < min_room_height:
		errors.append("Perfil %s tem dimensões de sala inválidas" % id)
	if min_link_width < 1 or max_link_width < min_link_width:
		errors.append("Perfil %s tem largura de ligação inválida" % id)
	if extra_loop_chance < 0.0 or extra_loop_chance > 1.0:
		errors.append("Perfil %s tem probabilidade de ligação extra inválida" % id)
	return errors
