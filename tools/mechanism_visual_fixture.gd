extends Node
const Game = preload("res://game.gd")
const Installation = preload("res://submerged_installation.gd")
var game: Node

func _ready() -> void:
	game = Game.new()
	game.persistence_enabled = false
	add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.audio.effects_enabled = false
	game.audio.stop_all()
	await _run()

func _frame(label: String) -> void:
	game._update_camera(0.0)
	game.camera.force_update_scroll()
	game.terrain_renderer.sync_view(game._visible_world_rect(), true)
	game.queue_redraw()
	game.hud.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output := OS.get_environment("MECHANISM_FIXTURE_OUT")
	if output.is_empty():
		# Web runners can collect PNGs from the console without filesystem access.
		print("FEEL_IMAGE ", label, " ", Marshalls.raw_to_base64(image.save_png_to_buffer()))
	else:
		DirAccess.make_dir_recursive_absolute(output)
		if image.save_png(output.path_join(label + ".png")) != OK:
			push_error("Could not save fixture image: " + label)
		else:
			print("CAPTURE ", label)

func _move_camera_to(point: Vector2i) -> void:
	game.player_position = point
	game.submerged.last_cell = point
	game._reset_player_visual(game._cell_center(point))

func _run() -> void:
	# Laboratory 4 has a gate in a vertical wall, and two material plates.
	game.start_environment_lab(3)
	await _frame("01-camara-porta-fechada")
	game.environment.crates[0].pos = game.environment.plates[0].pos
	game.environment.crates[1].pos = game.environment.plates[1].pos
	game._sync_environment_mechanisms()
	game.mechanism_presentation.advance(0.10)
	await _frame("02-porta-a-abrir")
	game.mechanism_presentation.advance(1.0)
	await _frame("03-porta-aberta")
	# Isolated pressed tread with the crate moved aside for visual inspection.
	# This prepared diagnostic is NOT a naturally reachable logical state.
	game.start_environment_lab(3)
	game.environment.plates[0].active = true
	game.mechanism_presentation.observe(game.environment, game.switches, false)
	game.mechanism_presentation.advance(1.0)
	await _frame("04-placa-pressionada-diagnostico")
	# The powered plate appears in a real special-room template. Loading a
	# template here is a prepared renderer fixture, not a played route.
	game.lab_active = false
	game.floor_number = 12
	game.special_family = "circuit"
	var circuit: Dictionary = game.SpecialLevels.make("circuit", 2, 12)
	var plan: Dictionary = game.SpecialLevels.solve(circuit, circuit.start, circuit.crates)
	game._generate_special_room(circuit, plan, 2)
	await _frame("11-placa-de-energia")

	game.start_environment_lab(Installation.LAB_INDEX)
	_move_camera_to(Vector2i(12, 4))
	await _frame("05-gerador-e-portas-horizontais")
	game.submerged.selected_door = 1
	game._sync_environment_mechanisms()
	game.mechanism_presentation.advance(0.10)
	await _frame("09-porta-horizontal-a-abrir")
	game.mechanism_presentation.advance(1.0)
	await _frame("10-porta-horizontal-aberta")
	_move_camera_to(Vector2i(7, 16))
	await _frame("06-encaixe-vazio")
	# Prepare an installed state using the existing actual synchronization.
	game.submerged.hatch_open = true
	game.environment.crates[1].pos = Installation.SOCKET
	game._sync_environment_mechanisms()
	game.mechanism_presentation.advance(1.0)
	await _frame("07-encaixe-ocupado-e-aviso")
	_move_camera_to(Vector2i(18, 18))
	await _frame("08-perigo-agua")
	print("CTM_FEEL_FIXTURE_DONE")
	get_tree().quit()
