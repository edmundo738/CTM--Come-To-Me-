extends RefCounted

# Stateless presentation: no gameplay RNG, timers or changes to the board.
# Each discharge lives for a fraction of a second and has a main channel and
# two short branches. The caller decides which real conductive nodes are live.
static func arc_geometry(start: Vector2, finish: Vector2, key: int, clock: float) -> Dictionary:
	var tick := floori(clock * 9.0)
	var life := fposmod(clock * 9.0 + float(posmod(key, 7)) * 0.083, 1.0)
	var opacity := sin(life * PI) * (0.9 if posmod(tick + key, 4) != 0 else 0.2)
	var along := finish - start
	var side := Vector2(-along.y, along.x).normalized()
	var points := PackedVector2Array([start])
	for index in range(1, 5):
		var noise := sin(float(key * 13 + tick * 31 + index * 71) * 0.37)
		points.append(start.lerp(finish, float(index) / 5.0) + side * noise * 4.5)
	points.append(finish)
	var branches: Array[PackedVector2Array] = []
	for index in [2, 4]:
		var branch_dir := -1.0 if posmod(key + index + tick, 2) == 0 else 1.0
		var base: Vector2 = points[index]
		var tip := base + side * branch_dir * (7.0 + float(posmod(key + tick + index, 5))) + along.normalized() * 4.0
		branches.append(PackedVector2Array([base, base.lerp(tip, 0.55) + along.normalized() * 2.0, tip]))
	return {"points": points, "branches": branches, "opacity": opacity}


# Two tiny, bounded motes belong to the same discharge phase as the arc and
# its local light. They are computed, not spawned into the game particle list.
static func arc_sparks(geometry: Dictionary, key: int, clock: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var opacity := float(geometry.opacity)
	var intensity := clampf((opacity - 0.50) / 0.40, 0.0, 1.0)
	if intensity <= 0.0:
		return result
	var points: PackedVector2Array = geometry.points
	var along := (points[points.size() - 1] - points[0]).normalized()
	var side := Vector2(-along.y, along.x)
	var tick := floori(clock * 9.0)
	var life := fposmod(clock * 9.0 + float(posmod(key, 7)) * 0.083, 1.0)
	for index in 2:
		var sign := -1.0 if posmod(key + tick + index, 2) == 0 else 1.0
		var base: Vector2 = points[1 + posmod(key + tick + index * 2, 4)]
		var direction := (side * sign + along * 0.35).normalized()
		result.append({"position": base + direction * (2.0 + life * (4.0 + index * 1.5)), "alpha": intensity * (1.0 - life * 0.35)})
	return result


static func draw_arc(target: CanvasItem, start: Vector2, finish: Vector2, key: int, clock: float) -> void:
	if start.distance_squared_to(finish) < 1.0:
		return
	var geometry := arc_geometry(start, finish, key, clock)
	var opacity := float(geometry.opacity)
	if opacity < 0.025:
		return
	var points: PackedVector2Array = geometry.points
	target.draw_polyline(points, Color("ff9c31", 0.17 * opacity), 6.0, true)
	target.draw_polyline(points, Color("ffd64d", 0.85 * opacity), 1.7, true)
	target.draw_polyline(points, Color("fff7c9", 0.82 * opacity), 0.75, true)
	for branch in geometry.branches:
		target.draw_polyline(branch, Color("ffd95c", 0.67 * opacity), 1.1, true)
	var sparkle: Vector2 = points[1 + posmod(key + floori(clock * 9.0), 4)]
	target.draw_circle(sparkle, 1.3 + opacity, Color("fff4ae", 0.72 * opacity))
	for mote in arc_sparks(geometry, key, clock):
		target.draw_circle(mote.position, 0.8 + 0.6 * float(mote.alpha), Color("fff2b0", 0.72 * float(mote.alpha)))


static func current_particles(center: Vector2, direction: Vector2i, cell_size: float, clock: float, key: int) -> Array[Dictionary]:
	var forward := Vector2(direction)
	var side := Vector2(-forward.y, forward.x)
	var result: Array[Dictionary] = []
	for lane in 3:
		var progress := fposmod(clock * 17.0 + float(key * 7 + lane * 13), cell_size - 10.0)
		var distance := progress - (cell_size - 10.0) * 0.5
		var position := center + forward * distance + side * (float(lane - 1) * 9.0)
		result.append({"position": position, "tail": position - forward * 5.0, "alpha": 0.32 + 0.25 * sin(progress * PI / (cell_size - 10.0))})
	return result
