extends RefCounted

# Presentation clock only: game rules, input, collision and semantic events never
# wait on it. A contact can freeze drawing-related motion for a few frames, not
# the SceneTree, physics clock or game state. No gameplay RNG is used here.
const HOLD_SECONDS := {
	"push": 0.028,
	"push_soft": 0.0,
	"pickup": 0.0,
	"block": 0.032,
	"shield": 0.048,
	"hurt": 0.055,
	"electric": 0.045,
	"capture": 0.065,
	"elite": 0.075,
	"defeat": 0.080,
	"wall": 0.070,
}
const LIFE_SECONDS := {
	"push": 0.24, "push_soft": 0.24, "pickup": 0.20, "block": 0.22, "shield": 0.32, "hurt": 0.30,
	"electric": 0.34, "capture": 0.34, "elite": 0.36,
	"defeat": 0.42, "wall": 0.52,
}
const MAX_HOLD := 0.10
const REFRACTORY_SECONDS := 0.18
const MAX_PENDING_DELAY := 0.30
const MAX_EFFECTS := 24

var effects: Array[Dictionary] = []
var hold_remaining := 0.0
var hold_elapsed := 0.0
var hold_total := 0.0
var refractory := 0.0
var serial := 0


func clear() -> void:
	effects.clear()
	hold_remaining = 0.0
	hold_elapsed = 0.0
	hold_total = 0.0
	refractory = 0.0


# Delay is expressed on the visual clock. `event` refers to a semantic event
# already emitted by the game; its audio/haptics can be played once at contact.
func add(kind: String, point: Vector2, direction: Vector2, delay: float = 0.0, material: String = "", event: String = "", context: Dictionary = {}) -> Dictionary:
	if not HOLD_SECONDS.has(kind):
		return {}
	var evicted: Dictionary = {}
	if effects.size() >= MAX_EFFECTS:
		# Prefer discarding an old, already-presented decoration to an unheard
		# contact. A burst of inputs is bounded regardless of frame rate.
		var oldest_presented := -1
		for i in effects.size():
			if bool(effects[i].contacted):
				oldest_presented = i
				break
		var evicted_index := oldest_presented if oldest_presented >= 0 else 0
		evicted = effects[evicted_index]
		effects.remove_at(evicted_index)
	serial += 1
	var heading := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	effects.append({
		"kind": kind, "point": point, "direction": heading,
		"age": -clampf(delay, 0.0, MAX_PENDING_DELAY),
		"life": float(LIFE_SECONDS[kind]), "material": material,
		"event": event, "context": context.duplicate(true),
		"contacted": false, "serial": serial,
	})
	return evicted


func _request_hold(duration: float) -> void:
	var requested := clampf(duration, 0.0, MAX_HOLD)
	if hold_remaining > 0.0:
		# Merge concurrent contacts into the longest hold measured from the
		# *original* start, never add durations or extend indefinitely.
		hold_total = maxf(hold_total, requested)
		hold_remaining = maxf(0.0, hold_total - hold_elapsed)
	elif refractory <= 0.0:
		hold_elapsed = 0.0
		hold_total = requested
		hold_remaining = requested
		refractory = REFRACTORY_SECONDS


# Returns a presentation delta and newly reached contacts. Large/stalled frames
# still expose a fresh contact for one frame; they cannot replay logical input.
# Pausing cancels an unfinished hold and flushes pending cues once (never replay
# on resume), while retaining the existing motion-completion policy in pause.
func advance(delta: float, paused: bool = false) -> Dictionary:
	var elapsed := maxf(0.0, delta) if is_finite(delta) else 0.0
	var held := 0.0
	var canceled: Array[Dictionary] = []
	if paused:
		hold_remaining = 0.0
		hold_elapsed = 0.0
		hold_total = 0.0
		refractory = 0.0
		for i in range(effects.size() - 1, -1, -1):
			if not bool(effects[i].contacted):
				if not str(effects[i].event).is_empty():
					var pending: Dictionary = effects[i].duplicate(true)
					pending["canceled"] = true
					canceled.append(pending)
				effects.remove_at(i)
		canceled.reverse()
	else:
		refractory = maxf(0.0, refractory - elapsed)
		held = minf(hold_remaining, elapsed)
		hold_elapsed += held
		hold_remaining = maxf(0.0, hold_remaining - held)
	var visual_delta := elapsed - held
	var contacts: Array[Dictionary] = []
	var strongest_hold := 0.0
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		var old_age := float(effect.age)
		if not bool(effect.contacted) and old_age + visual_delta >= -0.000001:
			# Keep the actual contact visible even if one long frame crosses the
			# whole animation. The excess is not turned into another event.
			effect.age = 0.0
			effect.contacted = true
			contacts.append(effect.duplicate(true))
			strongest_hold = maxf(strongest_hold, float(HOLD_SECONDS[effect.kind]))
		else:
			effect.age = old_age + visual_delta
		if bool(effect.contacted) and float(effect.age) >= float(effect.life):
			effects.remove_at(i)
		else:
			effects[i] = effect
	if not paused and strongest_hold > 0.0:
		_request_hold(strongest_hold)
	# Reverse the reverse traversal so cues keep their original semantic order.
	contacts.reverse()
	canceled.append_array(contacts)
	return {"visual_delta": visual_delta, "held": held, "contacts": canceled}


func draw(canvas: Node2D, view: Rect2) -> void:
	for effect in effects:
		var point: Vector2 = effect.point
		if not view.grow(100.0).has_point(point):
			continue
		var age := float(effect.age)
		var kind := str(effect.kind)
		if age < 0.0:
			if kind == "wall" and age > -0.075:
				_draw_wall_crack(canvas, effect, clampf((age + 0.075) / 0.075, 0.0, 1.0))
			continue
		var t := clampf(age / float(effect.life), 0.0, 1.0)
		if kind == "wall":
			_draw_wall_fragments(canvas, effect, t)
		elif kind == "electric":
			_draw_electric_contact(canvas, effect, t)
		elif kind in ["shield", "block"]:
			_draw_shield_contact(canvas, effect, t)
		elif kind in ["push", "push_soft"]:
			_draw_push_contact(canvas, effect, t)
		elif kind == "pickup":
			canvas.draw_arc(point, 8.0 + t * 12.0, 0.0, TAU, 16, Color("ffe7ae", (1.0 - t) * 0.45), 1.3, true)
		else:
			_draw_strike(canvas, effect, t)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wall_crack(canvas: Node2D, effect: Dictionary, amount: float) -> void:
	var p: Vector2 = effect.point
	var direction: Vector2 = effect.direction
	var side := Vector2(-direction.y, direction.x)
	var col := Color("b8f4ff", 0.38 * amount) if effect.material in ["glass", "ice"] else Color("ffcb93", 0.35 * amount)
	# The wall is already logically open: draw only a translucent fissure, not
	# a solid fake obstacle over the walkable cell.
	canvas.draw_polyline(PackedVector2Array([p - direction * 15.0, p - direction * 4.0 + side * 5.0, p + direction * 3.0 - side * 3.0, p + direction * 15.0]), col, 1.8, true)
	canvas.draw_line(p - direction * 4.0 + side * 5.0, p + side * 15.0, col, 1.2, true)


func _draw_wall_fragments(canvas: Node2D, effect: Dictionary, t: float) -> void:
	var p: Vector2 = effect.point
	var d: Vector2 = effect.direction
	var s := Vector2(-d.y, d.x)
	var material := str(effect.material)
	var fade := pow(1.0 - t, 1.35)
	var color := Color("bb9c87")
	match material:
		"glass": color = Color("8fdbe8")
		"ice": color = Color("b9ebff")
		"metal": color = Color("b797b5")
		"energy": color = Color("caa3ff")
	if t < 0.25:
		canvas.draw_arc(p, 8.0 + t * 45.0, 0.0, TAU, 20, Color(color, fade * 0.38), 1.5, true)
	# Readable on the very first frozen contact frame, not only after chips
	# have had time to travel. Keep it local to the struck cell.
	var contact_flash := maxf(0.0, 1.0 - t / 0.16)
	if contact_flash > 0.0:
		var bright := Color("ddfbff") if material in ["glass", "ice"] else Color("fff0dc")
		canvas.draw_circle(p, 8.0 + t * 12.0, Color(color, contact_flash * 0.22))
		for i in 4:
			var ray := (d * (1.0 if i < 2 else -0.45) + s * (1.0 if i % 2 == 0 else -1.0)).normalized()
			canvas.draw_line(p + ray * 7.0, p + ray * (18.0 + t * 9.0), Color(bright, contact_flash * 0.85), 2.1, true)
	# Directional, bounded chips: stone chunks, thin glass/ice triangles or
	# metal plates. Speeds and shapes are deterministic and never consume RNG.
	for i in 7:
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var spread := float((i * 7) % 5 + 1)
		var start := p + d * float((i % 3) * 3 - 3) + s * side_sign * spread * 2.0
		var chip := start + (d * (21.0 + float(i % 4) * 7.0) + s * side_sign * (15.0 + spread * 4.0)) * t
		chip.y += 12.0 * t * t
		var size := (3.0 + float(i % 3) * 1.0) * (1.0 - t * 0.55)
		var alpha := fade * (0.75 if material != "glass" else 0.57)
		if material in ["glass", "ice"]:
			canvas.draw_colored_polygon(PackedVector2Array([chip + d * size * 1.8, chip - d * size + s * size * 0.55, chip - d * size - s * size * 0.55]), Color(color, alpha))
		elif material in ["metal", "energy"]:
			canvas.draw_line(chip - s * size, chip + s * size + d * size * 0.45, Color(color, alpha), 2.2, true)
		else:
			canvas.draw_colored_polygon(PackedVector2Array([chip - d * size - s * size, chip + d * size - s * size * 0.5, chip + d * size * 0.7 + s * size, chip - d * size + s * size * 0.7]), Color(color, alpha))
	if material == "stone" and t < 0.75:
		for i in 3:
			canvas.draw_circle(p + s * float(i - 1) * 11.0 + d * t * 17.0, 4.0 + t * 5.0, Color("cbb5a8", fade * 0.09))


func _draw_shield_contact(canvas: Node2D, effect: Dictionary, t: float) -> void:
	var p: Vector2 = effect.point
	var d: Vector2 = effect.direction
	var shield: bool = str(effect.kind) == "shield"
	# Shield direction is the player's recoil, so face its arc toward the
	# incoming hit. Block effects already use the direction of the obstacle.
	if shield:
		d = -d
	var s := Vector2(-d.y, d.x)
	var fade := 1.0 - t
	var color := Color("7cf5ff") if shield else Color("a6cde7")
	if shield:
		# A curved contact surface, not an arrow pointing at the threat.
		var radius := 17.0 + t * 5.0
		canvas.draw_arc(p, radius, d.angle() - 0.95, d.angle() + 0.95, 24, Color(color, fade * 0.82), 3.0, true)
		canvas.draw_arc(p, radius + 4.0 + t * 5.0, d.angle() - 0.68, d.angle() + 0.68, 20, Color("dfffff", fade * 0.68), 1.5, true)
	else:
		# Compression against a surface, with tiny fragments spreading sideways.
		var contact := p + d * (1.5 + t * 2.0)
		canvas.draw_line(contact - s * 8.0, contact + s * 8.0, Color(color, fade * 0.78), 2.0, true)
		for sign in [-1.0, 1.0]:
			var chip: Vector2 = contact + s * float(sign) * (8.0 + t * 11.0) - d * t * 4.0
			canvas.draw_circle(chip, 1.6 * fade, Color(color, fade * 0.6))


func _draw_push_contact(canvas: Node2D, effect: Dictionary, t: float) -> void:
	var p: Vector2 = effect.point
	var d: Vector2 = effect.direction
	var s := Vector2(-d.y, d.x)
	var wood: bool = effect.material == "wood"
	var color := Color("f1c98e") if wood else Color("8bdff4")
	var fade := 1.0 - t
	# The contact patch compresses and releases; small fragments come from the
	# patch itself, rather than drawing a directional symbol over the action.
	canvas.draw_line(p - s * (7.0 + t * 2.0), p + s * (7.0 + t * 2.0), Color(color, fade * 0.65), 2.0, true)
	for index in 4:
		var sign := -1.0 if index % 2 == 0 else 1.0
		var chip := p + s * sign * (5.0 + float(index) * 1.8 + t * (8.0 + float(index) * 3.0)) - d * (t * 3.0)
		chip.y += t * t * 4.0
		if wood:
			canvas.draw_circle(chip, (1.6 + float(index % 2) * 0.5) * fade, Color(color, fade * 0.52))
		else:
			canvas.draw_line(chip - s * 1.6, chip + s * 1.6, Color(color, fade * 0.75), 1.2, true)


func _draw_electric_contact(canvas: Node2D, effect: Dictionary, t: float) -> void:
	var p: Vector2 = effect.point
	var fade := 1.0 - t
	for i in 3:
		var a := float(i) * TAU / 3.0 + 0.45
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x)
		var start := p + d * 8.0
		canvas.draw_polyline(PackedVector2Array([start, p + d * (15.0 + t * 5.0) + s * 3.0, p + d * (18.0 + t * 7.0) - s * 2.0, p + d * (25.0 + t * 10.0)]), Color("ffe88a", fade * 0.8), 1.8, true)


func _draw_strike(canvas: Node2D, effect: Dictionary, t: float) -> void:
	var p: Vector2 = effect.point
	var d: Vector2 = effect.direction
	var s := Vector2(-d.y, d.x)
	var kind := str(effect.kind)
	var fade := 1.0 - t
	var color := Color("ffb5bd") if kind in ["hurt", "capture"] else Color("ff8e9c")
	if kind == "elite":
		color = Color("dec0ff")
	var heavy := kind in ["defeat", "elite"]
	var radius := 7.0 + t * (24.0 if heavy else 17.0)
	var impact_flash := maxf(0.0, 1.0 - t / 0.16)
	if impact_flash > 0.0:
		# Local impact frame held with the contact, not a screen-wide strobe.
		canvas.draw_circle(p, 5.0 + impact_flash * (5.0 if heavy else 3.0), Color("fff6e8", impact_flash * (0.32 if heavy else 0.22)))
	canvas.draw_arc(p, radius, d.angle() - 1.08, d.angle() + 1.08, 20, Color(color, fade * 0.65), 2.2 if heavy else 1.6, true)
	if heavy:
		canvas.draw_arc(p, 10.0 + t * 36.0, 0.0, TAU, 28, Color(color, fade * 0.25), 1.5, true)
	for i in 3:
		var offset := float(i - 1) * 0.54
		var ray := (d + s * offset).normalized()
		var start := p + ray * (10.0 + t * 11.0)
		canvas.draw_line(start, start + ray * (4.0 + fade * 5.0), Color(color, fade * 0.75), 1.8, true)
