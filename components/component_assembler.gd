extends RefCounted

const Catalog = preload("res://components/component_catalog.tres")


static func compile_nodes(nodes: Array[Node]) -> Dictionary:
	return Catalog.compile_nodes(nodes)


static func normalize_legacy_spec(spec: Dictionary) -> Dictionary:
	var nodes: Array[Node] = []
	var gate_ids: Array[String] = []
	for index in spec.get("gates", []).size():
		var gate: Node = Catalog.create_instance(&"gate")
		var gate_id := str(spec.gates[index].get("id", "gate_%02d" % index))
		gate.set("component_id", gate_id)
		gate.set("cell", spec.gates[index].pos)
		gate.set("initially_open", bool(spec.gates[index].get("open", false)))
		gate.set("input_mode", str(spec.gates[index].get("input_mode", "all")))
		gate_ids.append(gate_id)
		nodes.append(gate)
	for index in spec.get("crates", []).size():
		var crate: Node = Catalog.create_instance(&"crate")
		crate.set("component_id", str(spec.crates[index].get("id", "crate_%02d" % index)))
		crate.set("cell", spec.crates[index].pos)
		crate.set("crate_material", str(spec.crates[index].get("material", "wood")))
		nodes.append(crate)
	for index in spec.get("plates", []).size():
		var plate: Node = Catalog.create_instance(&"pressure_plate")
		plate.set("component_id", str(spec.plates[index].get("id", "plate_%02d" % index)))
		plate.set("cell", spec.plates[index].pos)
		plate.set("required_material", str(spec.plates[index].get("required", "crate")))
		var outputs := PackedStringArray(spec.plates[index].get("outputs", []))
		if outputs.is_empty() and not gate_ids.is_empty():
			# Preserve the current legacy rule: every plate must be active for each gate.
			outputs = PackedStringArray(gate_ids)
		plate.set("output_ids", outputs)
		nodes.append(plate)
	var result := Catalog.compile_nodes(nodes)
	for node in nodes:
		node.free()
	if not result.errors.is_empty():
		return {"ok": false, "errors": result.errors}
	var normalized := spec.duplicate(true)
	for group in ["crates", "plates", "gates"]:
		normalized[group] = result.environment[group]
	normalized["circuit_nodes"] = result.environment.circuit_nodes
	return {"ok": true, "spec": normalized}
