extends Node2D

# Presentation only: existing conductors and arcs remain the authority. A small
# pool of real 2D lights illuminates the world, not the HUD or game rules.
const EnvironmentVFX = preload("res://environment_vfx.gd")
const MAX_LIGHTS := 4
const LIGHT_RADIUS := 92.0
const MAX_ENERGY := 0.62
const ARC_SOUND_INTERVAL := 0.85
const ARC_SOUND_DISTANCE := 260.0
const ARC_SOUND_THRESHOLD := 0.58

var game: Node2D
var listener: AudioListener2D
var lights: Array[PointLight2D] = []
# The selected samples are exposed for deterministic diagnostics. Each uses
# exactly the endpoints, key and clock used by the corresponding drawn arc.
var samples: Array[Dictionary] = []
var sound_cooldown := 0.0


func setup(owner_game: Node2D, texture: Texture2D) -> void:
	game = owner_game
	# The viewport's default listener is the screen centre, which can be far
	# from the player on small maps. Keep this ambient cue spatial to the ball.
	listener = AudioListener2D.new()
	add_child(listener)
	listener.make_current()
	for _index in MAX_LIGHTS:
		var light := PointLight2D.new()
		light.texture = texture
		light.texture_scale = LIGHT_RADIUS * 2.0 / float(texture.get_width())
		light.color = Color("ffd578")
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.shadow_enabled = false
		# World is canvas layer 0; the HUD and cinematic overlays are separate.
		light.range_layer_min = 0
		light.range_layer_max = 0
		light.enabled = false
		add_child(light)
		lights.append(light)


func clear() -> void:
	samples.clear()
	sound_cooldown = 0.0
	for light in lights:
		light.enabled = false


func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.distance_squared), float(b.distance_squared)):
		return float(a.distance_squared) < float(b.distance_squared)
	var first: Vector2i = a.cell
	var second: Vector2i = b.cell
	return first.y < second.y if first.y != second.y else first.x < second.x


func update_presentation(view: Rect2, draw_world: bool, visual_delta: float) -> void:
	samples.clear()
	if game == null or not draw_world:
		for light in lights:
			light.enabled = false
		return
	var candidates: Array[Dictionary] = []
	var focus: Vector2 = game._player_visual_position()
	if listener != null:
		listener.global_position = game.to_global(focus)
	var visible := view.grow(LIGHT_RADIUS)
	# Build a per-frame position index once. If malformed input ever contains
	# overlapping crates, retain crate_index_at's first-match semantics.
	var crate_indices := {}
	for index in game.environment.crates.size():
		var crate_cell: Vector2i = game.environment.crates[index].pos
		if not crate_indices.has(crate_cell):
			crate_indices[crate_cell] = index
	for point in game.environment.powered:
		var cell: Vector2i = point
		var center: Vector2 = game._cell_center(cell)
		var index := int(crate_indices.get(cell, -1))
		var metal: bool = index >= 0 and game.environment.crates[index].get("material", "") == "metal"
		if metal:
			center = game._crate_visual_position(index, game.environment.crates[index])
		elif not game.environment.is_electrified(cell):
			continue
		if not visible.has_point(center):
			continue
		var candidate := {"cell": cell, "center": center, "metal": metal, "distance_squared": center.distance_squared_to(focus)}
		# Keep only the four nearest, in the same deterministic distance/cell
		# order as the former full sort. No game RNG or rules are touched.
		var insert_at := candidates.size()
		for slot in candidates.size():
			if _candidate_before(candidate, candidates[slot]):
				insert_at = slot
				break
		if insert_at < MAX_LIGHTS:
			candidates.insert(insert_at, candidate)
			if candidates.size() > MAX_LIGHTS:
				candidates.pop_back()
	for index in lights.size():
		var light := lights[index]
		if index >= candidates.size():
			light.enabled = false
			continue
		var candidate: Dictionary = candidates[index]
		var cell: Vector2i = candidate.cell
		var center: Vector2 = candidate.center
		var metal: bool = candidate.metal
		var start := center + (Vector2(-13, -8) if metal else Vector2(-12, -8))
		var finish := center + (Vector2(13, 4) if metal else Vector2(11, 8))
		var key := cell.x * 79 + cell.y * 37 if metal else cell.x * 37 + cell.y * 79
		# Computing full branch geometry is only necessary for the lights that
		# will actually be shown; the world still draws every existing arc.
		var geometry: Dictionary = EnvironmentVFX.arc_geometry(start, finish, key, game.animation_clock)
		var points: PackedVector2Array = geometry.points
		var opacity: float = maxf(0.0, float(geometry.opacity))
		var glow: float = float(game.electric_visual_glow.get(cell, 0.25))
		var sample := {
			"cell": cell, "position": points[2].lerp(points[3], 0.5),
			"opacity": opacity, "energy": clampf(opacity * glow * MAX_ENERGY, 0.0, MAX_ENERGY),
			"distance_squared": candidate.distance_squared,
		}
		samples.append(sample)
		light.position = sample.position
		light.energy = float(sample.energy)
		light.enabled = float(sample.energy) > 0.002
	# Audible accents occur only on a visible bright arc, close to the player,
	# with one global cooldown. Large frames do not replay missed crackles.
	# A visual hold cannot repeatedly trigger an unchanged electrical frame.
	if game.game_state != "playing" or game.dev_menu_open:
		return
	sound_cooldown = maxf(0.0, sound_cooldown - maxf(0.0, visual_delta))
	if sound_cooldown > 0.0 or visual_delta <= 0.0:
		return
	for sample in samples:
		if float(sample.opacity) >= ARC_SOUND_THRESHOLD and float(sample.distance_squared) <= ARC_SOUND_DISTANCE * ARC_SOUND_DISTANCE:
			if game.audio != null and game.audio.effects_enabled:
				game.audio.play_ambient_at("electric_arc", game.to_global(sample.position))
			sound_cooldown = ARC_SOUND_INTERVAL
			break
