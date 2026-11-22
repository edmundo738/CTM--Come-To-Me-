extends SceneTree

const Game = preload("res://game.gd")
const EnvironmentVFX = preload("res://environment_vfx.gd")
const ElectricPresentation = preload("res://electric_presentation.gd")

var game: Node
var checks := 0
var failures: Array[String] = []
var cues: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _cue(name: String) -> void:
	if name == "electric_arc":
		cues.append(name)


func _bright_clock(point: Vector2i, metal: bool = false) -> float:
	var key := point.x * 79 + point.y * 37 if metal else point.x * 37 + point.y * 79
	# Search for a visible peak without assuming the key's phase or weak ticks.
	for index in 400:
		var clock := float(index) / 3600.0
		if EnvironmentVFX.arc_geometry(Vector2.ZERO, Vector2(20, 0), key, clock).opacity > 0.80:
			return clock
	return 0.0


func _setup_source(point: Vector2i) -> void:
	game.environment.reset({"cells": {point: {"kind": "water", "source": true}}})
	game.electric_visual_glow.clear()
	game.electric_visual_glow[point] = 1.0
	game.electric_presentation.clear()
	game.animation_clock = _bright_clock(point)


# Independent full-sort reference for the four closest samples. It deliberately
# does not use the production top-four selection or its crate position index.
func _reference_samples(view: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var focus: Vector2 = game._player_visual_position()
	var visible := view.grow(ElectricPresentation.LIGHT_RADIUS)
	for point in game.environment.powered:
		var cell: Vector2i = point
		var center: Vector2 = game._cell_center(cell)
		var index: int = game.environment.crate_index_at(cell)
		var metal: bool = index >= 0 and game.environment.crates[index].get("material", "") == "metal"
		if metal:
			center = game._crate_visual_position(index, game.environment.crates[index])
		elif not game.environment.is_electrified(cell):
			continue
		if not visible.has_point(center):
			continue
		var start := center + (Vector2(-13, -8) if metal else Vector2(-12, -8))
		var finish := center + (Vector2(13, 4) if metal else Vector2(11, 8))
		var key := cell.x * 79 + cell.y * 37 if metal else cell.x * 37 + cell.y * 79
		var arc: Dictionary = EnvironmentVFX.arc_geometry(start, finish, key, game.animation_clock)
		var points: PackedVector2Array = arc.points
		var opacity := maxf(0.0, float(arc.opacity))
		result.append({
			"cell": cell, "position": points[2].lerp(points[3], 0.5), "opacity": opacity,
			"energy": clampf(opacity * float(game.electric_visual_glow.get(cell, 0.25)) * ElectricPresentation.MAX_ENERGY, 0.0, ElectricPresentation.MAX_ENERGY),
			"distance_squared": center.distance_squared_to(focus),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.distance_squared), float(b.distance_squared)):
			return float(a.distance_squared) < float(b.distance_squared)
		var first: Vector2i = a.cell
		var second: Vector2i = b.cell
		return first.y < second.y if first.y != second.y else first.x < second.x
	)
	return result.slice(0, ElectricPresentation.MAX_LIGHTS)


func _samples_match(actual: Array[Dictionary], expected: Array[Dictionary]) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		if actual[i].cell != expected[i].cell or not Vector2(actual[i].position).is_equal_approx(expected[i].position):
			return false
		for field in ["opacity", "energy", "distance_squared"]:
			if not is_equal_approx(float(actual[i][field]), float(expected[i][field])):
				return false
	return true


func _run() -> void:
	game = Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.dev_load_sandbox_arena()
	game.game_state = "playing"
	game.player_position = Vector2i(9, 7)
	game._reset_player_visual(game._cell_center(game.player_position))
	game.audio.effects_enabled = false
	game.audio.cue_played.connect(_cue)
	var view := Rect2(Vector2.ZERO, Vector2(1500, 1000))
	var source := Vector2i(9, 7)
	_setup_source(source)
	var rng_before: int = game.rng.state
	var turn_before: int = game.turn_number
	game.electric_presentation.update_presentation(view, true, 0.01)
	_expect(game.electric_presentation.samples.size() == 1 and game.electric_presentation.lights[0].enabled, "live water produces one local point light")
	var sample: Dictionary = game.electric_presentation.samples[0]
	var center: Vector2 = game._cell_center(source)
	var key := source.x * 37 + source.y * 79
	var arc: Dictionary = EnvironmentVFX.arc_geometry(center + Vector2(-12, -8), center + Vector2(11, 8), key, game.animation_clock)
	_expect(is_equal_approx(float(sample.opacity), float(arc.opacity)), "light and drawn arc use the same discharge phase")
	var sparks: Array[Dictionary] = EnvironmentVFX.arc_sparks(arc, key, game.animation_clock)
	_expect(sparks.size() == 2 and sparks == EnvironmentVFX.arc_sparks(arc, key, game.animation_clock), "bright arc has two deterministic synchronized sparks")
	_expect(EnvironmentVFX.arc_sparks({"points": arc.points, "opacity": 0.10}, key, game.animation_clock).is_empty(), "weak arc does not invent bright detached particles")
	_expect(Vector2(sample.position).is_equal_approx(arc.points[2].lerp(arc.points[3], 0.5)), "light follows the actual lightning channel")
	_expect(is_equal_approx(float(sample.energy), float(arc.opacity) * ElectricPresentation.MAX_ENERGY), "light intensity follows arc opacity")
	_expect(game.rng.state == rng_before and game.turn_number == turn_before and game.environment.is_electrified(source), "light does not change RNG, turns or conduction")
	_expect(game.electric_presentation.lights[0].range_layer_min == 0 and game.electric_presentation.lights[0].range_layer_max == 0, "world light does not target HUD canvas layers")
	_expect(game.electric_presentation.listener.is_current() and game.electric_presentation.listener.global_position.is_equal_approx(game.to_global(game._player_visual_position())), "spatial listener follows the player rather than the viewport center")
	game.animation_clock = 0.0
	game.electric_presentation.update_presentation(view, true, 0.0)
	var next_sample: Dictionary = game.electric_presentation.samples[0]
	_expect(not is_equal_approx(float(next_sample.energy), float(sample.energy)), "illumination pulses as the actual discharge changes")

	game.environment.cells[source].source = false
	game.environment.refresh_electricity()
	game.electric_presentation.update_presentation(view, true, 0.01)
	_expect(game.electric_presentation.samples.is_empty() and not game.electric_presentation.lights[0].enabled, "disconnect immediately removes live illumination")
	_expect(not game.environment.is_electrified(source), "disconnected water is no longer logically dangerous")

	# Many connected cells cannot create an unbounded number of lights.
	var cells: Dictionary = {}
	for x in range(2, 16):
		cells[Vector2i(x, 7)] = {"kind": "water", "source": x == 2}
	game.environment.reset({"cells": cells})
	game.electric_presentation.update_presentation(view, true, 0.01)
	_expect(game.environment.powered.size() == 14 and game.electric_presentation.samples.size() == ElectricPresentation.MAX_LIGHTS, "large circuits use a fixed light budget")
	_expect(game.electric_presentation.lights.size() == ElectricPresentation.MAX_LIGHTS, "the light pool never grows per frame")
	var selected_cells: Array[Vector2i] = []
	for chosen in game.electric_presentation.samples:
		selected_cells.append(chosen.cell)
	_expect(selected_cells == [Vector2i(9, 7), Vector2i(8, 7), Vector2i(10, 7), Vector2i(7, 7)], "nearest four lights use deterministic cell order for equal distances")
	game.electric_presentation.update_presentation(view, true, 0.01)
	var repeated_cells: Array[Vector2i] = []
	for chosen in game.electric_presentation.samples:
		repeated_cells.append(chosen.cell)
	_expect(repeated_cells == selected_cells, "nearby light selection is stable across frames")
	game.electric_presentation.update_presentation(Rect2(Vector2(5000, 5000), Vector2(100, 100)), true, 0.01)
	_expect(game.electric_presentation.samples.is_empty(), "offscreen circuits do not consume light slots")
	game.electric_presentation.update_presentation(view, false, 0.01)
	var enabled := 0
	for light in game.electric_presentation.lights:
		if light.enabled:
			enabled += 1
	_expect(enabled == 0, "hidden world has no active point lights")

	# Compare the bounded selection with a full-sort reference across dense
	# circuits, multiple focus points, view edges, moving and overlapping crates.
	var dense: Dictionary = {}
	for y in range(3, 11):
		for x in range(4, 16):
			var p := Vector2i(x, y)
			dense[p] = {"kind": "water", "source": p == Vector2i(4, 3)}
	game.environment.reset({"cells": dense, "crates": [
		{"pos": Vector2i(7, 5), "material": "metal"},
		{"pos": Vector2i(10, 7), "material": "metal"},
		{"pos": Vector2i(12, 8), "material": "metal"},
		{"pos": Vector2i(13, 7), "material": "wood"},
		{"pos": Vector2i(13, 7), "material": "metal"},
	]})
	game._queue_crate_visual(1, Vector2i(9, 7), Vector2i(10, 7), "push")
	game._advance_crate_visuals(0.07)
	var old_rng: int = game.rng.state
	for focus_cell in [Vector2i(9, 7), Vector2i(4, 3), Vector2i(13, 7), Vector2i(15, 10)]:
		game.player_position = focus_cell
		game._reset_player_visual(game._cell_center(focus_cell))
		for test_view in [view, Rect2(game._cell_center(Vector2i(9, 7)) - Vector2(120, 110), Vector2(240, 220))]:
			var expected := _reference_samples(test_view)
			game.electric_presentation.update_presentation(test_view, true, 0.0)
			_expect(_samples_match(game.electric_presentation.samples, expected), "bounded selection matches full sort at " + str(focus_cell) + " and view " + str(test_view))
	_expect(game.rng.state == old_rng, "dense light selection leaves gameplay RNG unchanged")
	game.player_position = Vector2i(9, 7)
	game._reset_player_visual(game._cell_center(game.player_position))

	# A powered moving metal crate uses the same visual position as its arc.
	var water := Vector2i(8, 7)
	var metal := Vector2i(9, 7)
	game.environment.reset({"cells": {water: {"kind": "water", "source": true}}, "crates": [{"pos": metal, "material": "metal"}]})
	game.electric_presentation.clear()
	game.animation_clock = _bright_clock(metal, true)
	game._queue_crate_visual(0, Vector2i(10, 7), metal, "push")
	game._advance_crate_visuals(0.05)
	game.electric_visual_glow[metal] = 1.0
	game.electric_presentation.update_presentation(view, true, 0.0)
	var found_metal := false
	for metal_sample in game.electric_presentation.samples:
		if metal_sample.cell != metal:
			continue
		found_metal = true
		var crate_center: Vector2 = game._crate_visual_position(0, game.environment.crates[0])
		var metal_arc: Dictionary = EnvironmentVFX.arc_geometry(crate_center + Vector2(-13, -8), crate_center + Vector2(13, 4), metal.x * 79 + metal.y * 37, game.animation_clock)
		_expect(Vector2(metal_sample.position).is_equal_approx(metal_arc.points[2].lerp(metal_arc.points[3], 0.5)), "metal light follows its moving visual crate and discharge")
	_expect(found_metal, "powered metal has a light sample")

	# Ambient sound is aligned to a bright visible arc and globally rate-limited.
	_setup_source(source)
	game.audio.effects_enabled = true
	cues.clear()
	game.electric_presentation.update_presentation(view, true, 0.01)
	_expect(cues.size() == 1 and game.electric_presentation.samples[0].opacity >= ElectricPresentation.ARC_SOUND_THRESHOLD, "one quiet spatial crackle coincides with a bright discharge")
	var spatial_voices := 0
	for voice in game.audio.get_children():
		if voice is AudioStreamPlayer2D:
			spatial_voices += 1
			_expect(voice.global_position.is_equal_approx(game.to_global(game.electric_presentation.samples[0].position)) and is_equal_approx(voice.max_distance, 300.0), "crackle voice is at the real arc and has a bounded range")
	_expect(spatial_voices == 1, "one ambient spatial voice is created for the discharge")
	game.electric_presentation.update_presentation(view, true, 0.0)
	game.electric_presentation.update_presentation(view, true, 0.1)
	_expect(cues.size() == 1, "hitstop and short frames never repeat the crackle")
	game.game_state = "paused"
	game.electric_presentation.update_presentation(view, true, 5.0)
	_expect(cues.size() == 1, "pause never emits ambient electrical audio")
	game.game_state = "playing"
	game.audio.effects_enabled = false
	game.electric_presentation.update_presentation(view, true, 1.0)
	_expect(cues.size() == 1, "effects mute suppresses the ambient voice")
	game.electric_presentation.clear()
	_expect(game.electric_presentation.samples.is_empty() and not game.electric_presentation.lights[0].enabled, "reset clears active illumination")

	var audio_output := OS.get_environment("ELECTRIC_TEST_OUT")
	if not audio_output.is_empty():
		DirAccess.make_dir_recursive_absolute(audio_output)
		_expect(game.audio.effects["electric_arc"].save_to_wav(audio_output.path_join("electric-arc.wav")) == OK, "generated crackle can be exported for listening")
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ELECTRIC_PRESENTATION_TEST_PASS checks=", checks, " synchronized arcs, local light, mute, pause, conductor state and bounds")
		quit(0)
	else:
		printerr("ELECTRIC_PRESENTATION_TEST_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
