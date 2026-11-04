extends SceneTree

# Deterministic generation and idle-frame benchmark. Run with the same Godot
# build, resolution and arguments before/after changes; headless/dummy rendering
# measures CPU script work only and is not a GPU or real-world FPS benchmark.
class TimedGame:
	extends "res://game.gd"
	var record_draw := false
	var draw_times: Array[int] = []

	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		if record_draw:
			draw_times.append(Time.get_ticks_usec() - start)


func _initialize() -> void:
	call_deferred("_run")


func _parse_ints(text: String) -> Array[int]:
	var result: Array[int] = []
	for value in text.split(",", false):
		result.append(int(value))
	return result


func _median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var middle := ordered.size() / 2
	if ordered.size() % 2 == 0:
		return (ordered[middle - 1] + ordered[middle]) / 2000.0
	return ordered[middle] / 1000.0


func _percentile_95(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * 0.95) - 1, 0, ordered.size() - 1)] / 1000.0


func _fingerprint(game: Node) -> String:
	# Include both RNG states and the items placed after the coins, so matching
	# hashes also catch changed random consumption and ordering on restart.
	var snapshot := {
		"grid": game.grid, "rooms": game.rooms, "edges": game.room_graph_edges,
		"player": game.player_position, "portal": game.portal_position,
		"objective": game.objective_type, "challenge": game.challenge_kind,
		"par": game.challenge_par, "portal_open": game.portal_open,
		"coins": game.coins, "shields": game.shields, "breakers": game.breakers,
		"powerups": game.powerups, "switches": game.switches, "traps": game.traps,
		"enemies": game.enemies, "nav": game.nav_chevrons,
		"rng": game.rng.state, "wfc_rng": game.generator.rng.state,
	}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(snapshot))
	return context.finish().hex_encode()


func _run() -> void:
	var floors: Array[int] = [1, 15, 30, 100, 200]
	var seeds: Array[int] = [12900, 48211, 77123]
	var frames := 100
	var motion := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("floors="):
			floors = _parse_ints(arg.trim_prefix("floors="))
		elif arg.begins_with("seeds="):
			seeds = _parse_ints(arg.trim_prefix("seeds="))
		elif arg.begins_with("frames="):
			frames = maxi(1, int(arg.trim_prefix("frames=")))
		elif arg.begins_with("motion="):
			motion = int(arg.trim_prefix("motion=")) != 0
	root.size = Vector2i(1280, 720)
	var game := TimedGame.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	print("BENCH_INFO godot=%s display=%s viewport=%s frames=%d motion=%s" % [Engine.get_version_info().string, DisplayServer.get_name(), root.size, frames, motion])
	for number in floors:
		var generation_times: Array[int] = []
		for seed_value in seeds:
			game.active_seed = seed_value
			var start := Time.get_ticks_usec()
			game.generate_floor(number)
			var elapsed := Time.get_ticks_usec() - start
			generation_times.append(elapsed)
			print("BENCH_GENERATE floor=%d seed=%d ms=%.3f size=%dx%d coins=%d fingerprint=%s" % [number, seed_value, elapsed / 1000.0, game.world_size.x, game.world_size.y, game.coins.size(), _fingerprint(game)])
		# Use the same deterministic room, with the camera settled and no input.
		# The actual gameplay and HUD process/draw normally during this sample.
		game.game_state = "playing"
		if not game.rooms.is_empty():
			game.player_position = game.rooms[game.rooms.size() / 2].center
		if motion:
			game.player_position = Vector2i(3, game.world_size.y / 2)
		game.player_from = game._cell_center(game.player_position)
		game.player_to = game.player_from
		game.player_anim = 1.0
		game._update_camera(0.0)
		game.record_draw = false
		for _i in 10:
			await process_frame
		game.draw_times.clear()
		game.record_draw = true
		var frame_times: Array[int] = []
		for i in frames:
			if motion:
				# A deterministic camera traverse stresses newly encountered chunks.
				# This is a rendering stress test, not simulated legal movement.
				var ratio := float(i) / maxf(1.0, float(frames - 1))
				var cell_x := lerpf(3.0, float(game.world_size.x - 4), ratio)
				var center := Vector2((cell_x + 0.5) * game.CELL, game.player_from.y)
				game.player_position.x = roundi(cell_x)
				game.player_from = center
				game.player_to = center
			var start := Time.get_ticks_usec()
			await process_frame
			frame_times.append(Time.get_ticks_usec() - start)
		game.record_draw = false
		print("BENCH_SUMMARY floor=%d generation_median_ms=%.3f frame_median_ms=%.3f frame_p95_ms=%.3f root_draw_median_ms=%.3f draw_samples=%d" % [number, _median(generation_times), _median(frame_times), _percentile_95(frame_times), _median(game.draw_times), game.draw_times.size()])
	game.queue_free()
	await process_frame
	quit()
