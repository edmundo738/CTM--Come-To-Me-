@tool
extends Resource

@export var definitions: Array[Resource] = []


func definition_for(kind: StringName) -> Resource:
	for definition in definitions:
		if definition != null and StringName(definition.get("kind")) == kind:
			return definition
	return null


func create_instance(kind: StringName) -> Node:
	var definition := definition_for(kind)
	if definition == null:
		return null
	var packed: PackedScene = definition.get("scene")
	return packed.instantiate() if packed != null else null


func compile_nodes(nodes: Array[Node]) -> Dictionary:
	var compiled := {"components": [], "environment": {"crates": [], "plates": [], "gates": [], "circuit_nodes": []}, "errors": []}
	var ids: Dictionary = {}
	var data_by_id: Dictionary = {}
	for node in nodes:
		if node == null or not node.has_method("to_component_data"):
			continue
		var data: Dictionary = node.to_component_data()
		var id := str(data.get("id", ""))
		if id.is_empty():
			compiled.errors.append("Componente sem ID: %s" % node.name)
		elif ids.has(id):
			compiled.errors.append("ID duplicado: %s" % id)
		else:
			ids[id] = true
			data_by_id[id] = data
		compiled.components.append(data)
	for data in compiled.components:
		for target_id in data.get("outputs", PackedStringArray()):
			var target := str(target_id)
			if not ids.has(target):
				compiled.errors.append("Ligacao %s -> %s sem destino" % [data.get("id", "?"), target_id])
				continue
			var source_definition := definition_for(StringName(data.get("kind", "")))
			var target_definition := definition_for(StringName(data_by_id[target].get("kind", "")))
			var source_channel := StringName(source_definition.get("output_channel")) if source_definition != null else &""
			var target_channel := StringName(target_definition.get("input_channel")) if target_definition != null else &""
			if source_channel != target_channel:
				compiled.errors.append("Ligacao %s -> %s usa canais incompatíveis (%s / %s)" % [data.get("id", "?"), target, source_channel, target_channel])
		match str(data.get("kind", "")):
			"crate": compiled.environment.crates.append(data)
			"pressure_plate": compiled.environment.plates.append(data)
			"gate": compiled.environment.gates.append(data)
			"power_source", "circuit_relay", "circuit_receiver": compiled.environment.circuit_nodes.append(data)
	return compiled
