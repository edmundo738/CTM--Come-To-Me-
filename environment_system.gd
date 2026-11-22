extends RefCounted

# Turn rules only. No timers, drawing, random numbers or audio live here.
# Cells not explicitly described keep the legacy floor behavior.
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var cells: Dictionary = {}
var crates: Array[Dictionary] = []
var plates: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var circuit_nodes: Array[Dictionary] = []
var powered: Dictionary = {}
var powered_components: Dictionary = {}


func reset(data: Dictionary = {}) -> void:
	cells = data.get("cells", {}).duplicate(true)
	crates.assign(data.get("crates", []).duplicate(true))
	plates.assign(data.get("plates", []).duplicate(true))
	gates.assign(data.get("gates", []).duplicate(true))
	circuit_nodes.assign(data.get("circuit_nodes", []).duplicate(true))
	refresh_electricity()


func is_active() -> bool:
	return not cells.is_empty() or not crates.is_empty() or not plates.is_empty() or not gates.is_empty() or not circuit_nodes.is_empty()


func kind_at(point: Vector2i) -> String:
	return str(cells.get(point, {}).get("kind", ""))


func is_water(point: Vector2i) -> bool:
	return kind_at(point) in ["water", "current"]


func crate_index_at(point: Vector2i) -> int:
	for index in crates.size():
		if crates[index].pos == point:
			return index
	return -1


func is_gate_closed(point: Vector2i) -> bool:
	for gate in gates:
		if gate.pos == point and not gate.get("open", false):
			return true
	return false


func is_blocked(point: Vector2i) -> bool:
	return crate_index_at(point) >= 0 or is_gate_closed(point)


func is_electrified(point: Vector2i) -> bool:
	return is_water(point) and powered.has(point)


# Electricity uses one board state for authored water/metal conduction and
# explicit ID-linked generator circuits. A dry metal crate bridges adjacent
# pools; wood and ice do not conduct. Circuit links are edited on source scenes.
func refresh_electricity() -> void:
	powered.clear()
	powered_components.clear()
	var queue: Array[Vector2i] = []
	var component_queue: Array[String] = []
	var queued_components: Dictionary = {}
	var nodes_by_id: Dictionary = {}
	for node in circuit_nodes:
		var id := str(node.get("id", ""))
		if not id.is_empty():
			nodes_by_id[id] = node
			if str(node.get("kind", "")) == "power_source" and bool(node.get("active", false)):
				component_queue.append(id)
				queued_components[id] = true
	for point in cells:
		if is_water(point) and bool(cells[point].get("source", false)):
			powered[point] = true
			queue.append(point)
	var cell_head := 0
	var component_head := 0
	while cell_head < queue.size() or component_head < component_queue.size():
		if component_head < component_queue.size():
			var component_id := component_queue[component_head]
			component_head += 1
			var component: Dictionary = nodes_by_id.get(component_id, {})
			if component.is_empty() or powered_components.has(component_id):
				continue
			powered_components[component_id] = true
			if str(component.get("kind", "")) == "circuit_receiver":
				var receiver_cell: Vector2i = component.get("pos", Vector2i.ZERO)
				if not powered.has(receiver_cell):
					powered[receiver_cell] = true
					queue.append(receiver_cell)
			for target_id in component.get("outputs", []):
				var target := str(target_id)
				if nodes_by_id.has(target) and not queued_components.has(target):
					component_queue.append(target)
					queued_components[target] = true
			continue
		var point := queue[cell_head]
		cell_head += 1
		for node in circuit_nodes:
			var node_id := str(node.get("id", ""))
			if node.get("pos", Vector2i(-1, -1)) == point and str(node.get("kind", "")) in ["circuit_relay", "circuit_receiver"] and not queued_components.has(node_id):
				component_queue.append(node_id)
				queued_components[node_id] = true
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
	if data.get("kind", "") == "ice" and not bool(data.get("broken", false)) and action_direction in DIRECTIONS:
		return action_direction
	return Vector2i.ZERO


func is_slippery_ice(point: Vector2i) -> bool:
	var data: Dictionary = cells.get(point, {})
	return data.get("kind", "") == "ice" and not bool(data.get("broken", false))


# Thin ice remains an explicitly marked tile; after three contacts it is still
# solid and walkable, but no longer causes a slide. No second map is kept.
func stress_brittle(points: Array[Vector2i]) -> Array[Vector2i]:
	var broken: Array[Vector2i] = []
	var seen: Dictionary = {}
	for point in points:
		if seen.has(point):
			continue
		seen[point] = true
		var cell: Dictionary = cells.get(point, {})
		if cell.get("kind", "") != "ice" or not bool(cell.get("brittle", false)) or bool(cell.get("broken", false)):
			continue
		cell["stress"] = mini(3, int(cell.get("stress", 0)) + 1)
		if int(cell.stress) == 3:
			cell["broken"] = true
			broken.append(point)
		cells[point] = cell
	return broken


func push(index: int, direction: Vector2i, destination_free: Callable) -> bool:
	if index < 0 or index >= crates.size() or direction not in DIRECTIONS:
		return false
	# An authored installation may dock a crate permanently; ordinary crates
	# retain their existing push behavior and never acquire this flag.
	if bool(crates[index].get("locked", false)) or is_gate_closed(crates[index].pos):
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


# Plates are held, not latched. This calculation is shared with authored
# puzzles that latch different consequences from individual plates.
func update_plates(player: Vector2i) -> bool:
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
	return all_active


# Ordinary gates cannot close on an occupant; they close as soon as the
# occupant leaves. Portal state is decided by the caller.
func update_mechanisms(player: Vector2i, enemy_positions: Array[Vector2i]) -> bool:
	var all_active := update_plates(player)
	for gate in gates:
		var occupied: bool = gate.pos == player or enemy_positions.has(gate.pos) or crate_index_at(gate.pos) >= 0
		var wanted_open := all_active if str(gate.get("id", "")).is_empty() else _linked_gate_state(gate)
		gate["open"] = wanted_open or (bool(gate.get("open", false)) and occupied)
	return all_active


func _linked_gate_state(gate: Dictionary) -> bool:
	var gate_id := str(gate.get("id", ""))
	var incoming: Array[String] = []
	for plate in plates:
		if str(plate.get("id", "")).is_empty():
			continue
		if plate.get("outputs", []).has(gate_id):
			incoming.append(str(plate.id))
	for node in circuit_nodes:
		if str(node.get("id", "")).is_empty():
			continue
		if node.get("outputs", []).has(gate_id):
			incoming.append(str(node.id))
	if incoming.is_empty():
		return bool(gate.get("initially_open", false))
	var mode := str(gate.get("input_mode", "all"))
	var result := mode != "any"
	for source_id in incoming:
		var active := _linked_source_active(source_id)
		if mode == "any":
			result = result or active
		else:
			result = result and active
	return result


func _linked_source_active(source_id: String) -> bool:
	for plate in plates:
		if str(plate.get("id", "")) == source_id:
			return bool(plate.get("active", false))
	return powered_components.has(source_id)


func active_plate_count() -> int:
	var result := 0
	for plate in plates:
		if plate.get("active", false):
			result += 1
	return result
