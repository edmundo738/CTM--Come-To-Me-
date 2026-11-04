extends RefCounted

# Turn rules only. No timers, drawing, random numbers or audio live here.
# Cells not explicitly described keep the legacy floor behavior.
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var cells: Dictionary = {}
var crates: Array[Dictionary] = []
var plates: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var powered: Dictionary = {}


func reset(data: Dictionary = {}) -> void:
	cells = data.get("cells", {}).duplicate(true)
	crates.assign(data.get("crates", []).duplicate(true))
	plates.assign(data.get("plates", []).duplicate(true))
	gates.assign(data.get("gates", []).duplicate(true))
	refresh_electricity()


func is_active() -> bool:
	return not cells.is_empty() or not crates.is_empty() or not plates.is_empty() or not gates.is_empty()


func kind_at(point: Vector2i) -> String:
	return str(cells.get(point, {}).get("kind", ""))


func is_water(point: Vector2i) -> bool:
	return kind_at(point) in ["water", "current"]


func crate_index_at(point: Vector2i) -> int:
	for index in crates.size():
		if crates[index].pos == point:
			return index
	return -1


func is_blocked(point: Vector2i) -> bool:
	if crate_index_at(point) >= 0:
		return true
	for gate in gates:
		if gate.pos == point and not gate.get("open", false):
			return true
	return false


func is_electrified(point: Vector2i) -> bool:
	return is_water(point) and powered.has(point)


# Electricity propagates through explicitly authored water and metal crates.
# A dry metal crate can bridge adjacent pools; wood and ice do not conduct.
func refresh_electricity() -> void:
	powered.clear()
	var queue: Array[Vector2i] = []
	for point in cells:
		if is_water(point) and bool(cells[point].get("source", false)):
			powered[point] = true
			queue.append(point)
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for direction in DIRECTIONS:
			var next: Vector2i = point + direction
			if powered.has(next):
				continue
			var index := crate_index_at(next)
			var metal: bool = index >= 0 and crates[index].get("material", "") == "metal"
			if is_water(next) or metal:
				powered[next] = true
				queue.append(next)


# Return the displacement for this action, not a loop. Currents also act on a
# wait; ice only carries an actor that entered/moved in a direction this turn.
func forced_direction(point: Vector2i, action_direction: Vector2i) -> Vector2i:
	var data: Dictionary = cells.get(point, {})
	if data.get("kind", "") == "current":
		var flow: Vector2i = data.get("flow", Vector2i.ZERO)
		return flow if flow in DIRECTIONS else Vector2i.ZERO
	if data.get("kind", "") == "ice" and action_direction in DIRECTIONS:
		return action_direction
	return Vector2i.ZERO


func push(index: int, direction: Vector2i, destination_free: Callable) -> bool:
	if index < 0 or index >= crates.size() or direction not in DIRECTIONS:
		return false
	var destination: Vector2i = crates[index].pos + direction
	if not destination_free.call(destination):
		return false
	crates[index].pos = destination
	refresh_electricity()
	return true


# Resolve each floating crate at most once. Destinations occupied at the
# start remain reserved, and same-target conflicts go to the first authored
# crate. This avoids chain moves, swaps and dependence on rendering frames.
func advance_currents(destination_free: Callable) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	for crate in crates:
		occupied[crate.pos] = true
	var reserved: Dictionary = {}
	var movements: Array[Dictionary] = []
	for index in crates.size():
		var crate: Dictionary = crates[index]
		if crate.get("material", "") != "wood" or kind_at(crate.pos) != "current":
			continue
		var direction: Vector2i = cells[crate.pos].get("flow", Vector2i.ZERO)
		if direction not in DIRECTIONS:
			continue
		var target: Vector2i = crate.pos + direction
		if occupied.has(target) or reserved.has(target) or not destination_free.call(target):
			continue
		reserved[target] = true
		movements.append({"index": index, "from": crate.pos, "to": target})
	for movement in movements:
		crates[movement.index].pos = movement.to
	if not movements.is_empty():
		refresh_electricity()
	return movements


# Plates are held, not latched. Gates cannot close on an occupant; they close
# as soon as the occupant leaves. Portal state is decided by the caller.
func update_mechanisms(player: Vector2i, enemy_positions: Array[Vector2i]) -> bool:
	var all_active := not plates.is_empty()
	for plate in plates:
		var index := crate_index_at(plate.pos)
		var required: String = plate.get("required", "crate")
		var material := str(crates[index].get("material", "")) if index >= 0 else ""
		var active := (index >= 0 and (required in ["crate", "any"] or required == material))
		if required == "powered":
			active = powered.has(plate.pos)
		if required == "any" and player == plate.pos:
			active = true
		plate["active"] = active
		all_active = all_active and active
	for gate in gates:
		var occupied: bool = gate.pos == player or enemy_positions.has(gate.pos) or crate_index_at(gate.pos) >= 0
		gate["open"] = all_active or (bool(gate.get("open", false)) and occupied)
	return all_active


func active_plate_count() -> int:
	var result := 0
	for plate in plates:
		if plate.get("active", false):
			result += 1
	return result
