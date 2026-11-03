extends RefCounted

# Presentation-only track. The caller has already resolved the board state;
# this object never stores or replays commands, collision checks or events.
# At most three visible segments are retained and their remaining time is
# bounded. If inputs exceed that capacity before a frame, obsolete segments
# are discarded at the last resolved origin instead of cutting a corner.
const MAX_SEGMENTS := 3
const MAX_REMAINING_TIME := 0.24
const MIN_DURATION := 0.008

var from := Vector2.ZERO
var to := Vector2.ZERO
var progress := 1.0
var duration := 0.14
var kind := "walk"
var surface := ""
var pending: Array[Dictionary] = []
var overflow_count := 0


func reset(position: Vector2) -> void:
	from = position
	to = position
	progress = 1.0
	duration = 0.14
	kind = "walk"
	surface = ""
	pending.clear()


func is_active() -> bool:
	return progress < 1.0


func final_target() -> Vector2:
	return pending.back().to if not pending.is_empty() else to


func position() -> Vector2:
	return from.lerp(to, eased_progress(progress, kind))


static func eased_progress(value: float, motion_kind: String) -> float:
	var t := clampf(value, 0.0, 1.0)
	var smooth := t * t * (3.0 - 2.0 * t)
	# A nonzero initial/end velocity makes successive steps continuous while
	# retaining a soft landing. Ice and current retain a little more momentum.
	var blend := 0.30 if motion_kind in ["ice", "current"] else 0.55 if motion_kind == "jump" else 0.42
	return lerpf(t, smooth, blend)


func enqueue(origin: Vector2, destination: Vector2, motion_kind: String, seconds: float, destination_surface: String = "") -> bool:
	if not final_target().is_equal_approx(origin):
		# A room reset, Blink or external debug reposition supersedes old art.
		reset(origin)
	if origin.is_equal_approx(destination):
		return false
	var spec := {"to": destination, "kind": motion_kind, "duration": maxf(seconds, MIN_DURATION), "surface": destination_surface}
	var overflowed := false
	if not is_active():
		_activate(origin, spec)
	elif pending.size() < MAX_SEGMENTS - 1:
		pending.append(spec)
	else:
		# There is no way to show an unbounded number of resolved moves without
		# delaying gameplay. Jump to the last actual origin, then animate the most
		# recent legal segment; never invent a diagonal across a corner/wall.
		reset(origin)
		overflow_count += 1
		overflowed = true
		_activate(origin, spec)
	_limit_remaining_time()
	return overflowed


func _activate(origin: Vector2, spec: Dictionary) -> void:
	from = origin
	to = spec.to
	kind = str(spec.kind)
	duration = float(spec.duration)
	surface = str(spec.surface)
	progress = 0.0


func _limit_remaining_time() -> void:
	var total := (1.0 - progress) * duration
	for segment in pending:
		total += float(segment.duration)
	if total <= MAX_REMAINING_TIME:
		return
	var factor := MAX_REMAINING_TIME / total
	duration = maxf(MIN_DURATION, duration * factor)
	for segment in pending:
		segment.duration = maxf(MIN_DURATION, float(segment.duration) * factor)


# Returns purely visual deltas and arrivals; the caller may update pose or
# material feedback. A long frame consumes all remaining segments safely.
func advance(delta: float) -> Dictionary:
	var steps: Array[Dictionary] = []
	var arrivals: Array[Dictionary] = []
	var left := maxf(0.0, delta)
	while left > 0.000001 and is_active():
		var before := position()
		var span := maxf(MIN_DURATION, duration)
		var consume := minf(left, (1.0 - progress) * span)
		progress = minf(1.0, progress + consume / span)
		left -= consume
		steps.append({"delta": position() - before, "direction": to - from, "kind": kind})
		if progress >= 0.999999:
			progress = 1.0
			arrivals.append({"position": to, "kind": kind, "surface": surface})
			if not pending.is_empty():
				var previous_destination := to
				var next: Dictionary = pending.pop_front()
				_activate(previous_destination, next)
	return {"steps": steps, "arrivals": arrivals}
