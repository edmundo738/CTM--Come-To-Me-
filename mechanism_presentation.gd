extends RefCounted

# Presentation-only tracks. EnvironmentSystem and the turn pipeline remain the
# sole authority for collision, plates, electricity, water and gate states.
# Retarget from the currently displayed value so a rapid reversal or undo never
# jumps to a stale end pose. New rooms are explicitly primed instead of animated.
const PLATE_SECONDS := 0.20
const GATE_SECONDS := 0.34
const SWITCH_SECONDS := 0.22
const REVEAL_SECONDS := 0.24
const WATER_SECONDS := 1.25
const PORTAL_SECONDS := 0.35
const PICKUP_SECONDS := 0.26
const MAX_PICKUP_TRACKS := 64

var plates: Dictionary = {}
var gates: Dictionary = {}
var switches: Dictionary = {}
var visibility: Dictionary = {}
var water: Dictionary = {}
var portal: Dictionary = {}
# Short-lived visual echoes only. Collected objects are already gone from the
# authoritative arrays and cannot be collected again by touching the echo.
var pickups: Dictionary = {}
var initialized := false


func clear() -> void:
	plates.clear()
	gates.clear()
	switches.clear()
	visibility.clear()
	water.clear()
	portal.clear()
	pickups.clear()
	initialized = false


func _new_track(value: float) -> Dictionary:
	return {"value": value, "from": value, "target": value, "elapsed": 0.0, "duration": 0.0}


func _retarget(track: Dictionary, target: float, seconds: float) -> bool:
	if is_equal_approx(float(track.target), target):
		return false
	var current := clampf(float(track.value), 0.0, 1.0)
	track.from = current
	track.target = target
	track.elapsed = 0.0
	# Reversing near an endpoint should not take a full-duration crawl.
	track.duration = maxf(0.035, seconds * absf(target - current))
	return true


func _observe_items(tracks: Dictionary, items: Array, key: String, seconds: float, event_kind: String, events: Array[Dictionary]) -> void:
	var present := {}
	for item in items:
		var point: Vector2i = item.pos
		present[point] = true
		var target := 1.0 if bool(item.get(key, false)) else 0.0
		if not tracks.has(point):
			tracks[point] = _new_track(target)
		elif _retarget(tracks[point], target, seconds) and not event_kind.is_empty():
			events.append({"kind": event_kind, "pos": point, "active": target > 0.5, "material": str(item.get("required", ""))})
	for point in tracks.keys():
		if not present.has(point):
			tracks.erase(point)


# Returns presentation cues only for changes after initialisation. It never
# modifies the supplied arrays/dictionaries and does not consume gameplay RNG.
func observe(environment, items: Array[Dictionary], portal_open: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_observe_items(plates, environment.plates, "active", PLATE_SECONDS, "plate" if initialized else "", events)
	_observe_items(gates, environment.gates, "open", GATE_SECONDS, "gate" if initialized else "", events)
	_observe_items(switches, items, "active", SWITCH_SECONDS, "", events)
	var seen := {}
	for item in items:
		var point: Vector2i = item.pos
		seen[point] = true
		var visible := 0.0 if bool(item.get("hidden", false)) else 1.0
		if not visibility.has(point):
			visibility[point] = _new_track(visible)
		else:
			_retarget(visibility[point], visible, REVEAL_SECONDS)
	for point in visibility.keys():
		if not seen.has(point):
			visibility.erase(point)
	var water_now := {}
	for point in environment.cells:
		if environment.is_water(point):
			water_now[point] = true
			if not water.has(point):
				water[point] = _new_track(1.0 if not initialized else 0.0)
				if initialized:
					_retarget(water[point], 1.0, WATER_SECONDS)
			else:
				_retarget(water[point], 1.0, WATER_SECONDS)
	var drained_point := Vector2i(-1, -1)
	for point in water.keys():
		if not water_now.has(point) and _retarget(water[point], 0.0, WATER_SECONDS):
			if drained_point == Vector2i(-1, -1):
				drained_point = point
	if initialized and drained_point != Vector2i(-1, -1):
		events.append({"kind": "drain", "pos": drained_point})
	var portal_target := 1.0 if portal_open else 0.0
	if portal.is_empty():
		portal = _new_track(portal_target)
	else:
		_retarget(portal, portal_target, PORTAL_SECONDS)
	initialized = true
	return events


func _pickup_key(kind: String, point: Vector2i) -> String:
	return "%s:%d:%d" % [kind, point.x, point.y]


# Collection is logical immediately, while the same object contracts only after
# the visible player reaches it. The delay and track never block input.
func collect_pickup(kind: String, point: Vector2i, delay: float = 0.0) -> void:
	var key := _pickup_key(kind, point)
	if not pickups.has(key):
		if pickups.size() >= MAX_PICKUP_TRACKS:
			pickups.erase(pickups.keys()[0])
		pickups[key] = _new_track(1.0)
	var track: Dictionary = pickups[key]
	track.kind = kind
	track.pos = point
	track.wait = clampf(delay, 0.0, 1.0) if is_finite(delay) else 0.0
	_retarget(track, 0.0, PICKUP_SECONDS)


# Undo can occur after the echo was discarded; in that case grow the restored
# object from zero. If it is still contracting, reverse its current size.
func restore_pickup(kind: String, point: Vector2i) -> void:
	var key := _pickup_key(kind, point)
	if not pickups.has(key):
		if pickups.size() >= MAX_PICKUP_TRACKS:
			pickups.erase(pickups.keys()[0])
		pickups[key] = _new_track(0.0)
	var track: Dictionary = pickups[key]
	track.kind = kind
	track.pos = point
	track.wait = 0.0
	_retarget(track, 1.0, PICKUP_SECONDS)


func pickup_amount(kind: String, point: Vector2i, present: bool) -> float:
	if pickups.is_empty():
		return 1.0 if present else 0.0
	var key := _pickup_key(kind, point)
	return float(pickups[key].value) if pickups.has(key) else (1.0 if present else 0.0)


func _advance_track(track: Dictionary, delta: float) -> bool:
	if is_equal_approx(float(track.value), float(track.target)):
		track.value = float(track.target)
		return false
	track.elapsed = minf(float(track.duration), float(track.elapsed) + delta)
	var t := clampf(float(track.elapsed) / maxf(0.001, float(track.duration)), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	track.value = lerpf(float(track.from), float(track.target), eased)
	if t >= 1.0:
		track.value = float(track.target)
		return true
	return false


# Returns true when returning water needs to be baked into terrain chunks.
func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	for tracks in [plates, gates, switches, visibility]:
		for track in tracks.values():
			_advance_track(track, delta)
	if not portal.is_empty():
		_advance_track(portal, delta)
	for key in pickups.keys():
		var track: Dictionary = pickups[key]
		var waiting := float(track.get("wait", 0.0))
		track.wait = maxf(0.0, waiting - delta)
		_advance_track(track, maxf(0.0, delta - waiting))
		if is_equal_approx(float(track.value), float(track.target)):
			pickups.erase(key)
	var rebuild_water := false
	for point in water.keys():
		var track: Dictionary = water[point]
		var finished := _advance_track(track, delta)
		if finished and float(track.target) >= 1.0:
			rebuild_water = true
		if float(track.target) <= 0.0 and float(track.value) <= 0.0:
			water.erase(point)
	return rebuild_water


func plate_amount(point: Vector2i, active: bool) -> float:
	return float(plates[point].value) if plates.has(point) else (1.0 if active else 0.0)


func gate_amount(point: Vector2i, opened: bool) -> float:
	return float(gates[point].value) if gates.has(point) else (1.0 if opened else 0.0)


func switch_amount(point: Vector2i, active: bool) -> float:
	return float(switches[point].value) if switches.has(point) else (1.0 if active else 0.0)


func switch_visibility(point: Vector2i, hidden: bool) -> float:
	return float(visibility[point].value) if visibility.has(point) else (0.0 if hidden else 1.0)


func water_amount(point: Vector2i, is_water: bool) -> float:
	return float(water[point].value) if water.has(point) else (1.0 if is_water else 0.0)


func water_is_animating(point: Vector2i) -> bool:
	return water.has(point) and not is_equal_approx(float(water[point].value), float(water[point].target))


func portal_amount(opened: bool) -> float:
	return float(portal.value) if not portal.is_empty() else (1.0 if opened else 0.0)
