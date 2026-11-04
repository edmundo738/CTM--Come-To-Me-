extends SceneTree

# Diagnostic microbenchmark of CPU-side electric presentation only. It is NOT
# a game FPS or GPU benchmark, and uses intentionally synthetic circuits.
# godot --headless --path . --script res://tools/benchmark_electric.gd
const Game = preload("res://game.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := Game.new()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.dev_load_sandbox_arena()
	game.game_state = "playing"
	game.audio.effects_enabled = false
	var view := Rect2(Vector2(-100, -100), Vector2(2600, 1400))
	var fixtures := [
		{"cells": 1, "crates": 0}, {"cells": 14, "crates": 0},
		{"cells": 180, "crates": 0}, {"cells": 400, "crates": 40},
	]
	for fixture in fixtures:
		var cells := {}
		var crates: Array[Dictionary] = []
		var count := int(fixture.cells)
		for i in count:
			var point := Vector2i(i % 40, i / 40)
			cells[point] = {"kind": "water", "source": i == 0}
		for i in int(fixture.crates):
			crates.append({"pos": Vector2i((i * 9) % count % 40, (i * 9) % count / 40), "material": "metal"})
		game.environment.reset({"cells": cells, "crates": crates})
		if game.environment.powered.size() != count:
			printerr("ELECTRIC_BENCH_FAIL: fixture was not connected")
			quit(1)
			return
		game.electric_presentation.clear()
		for i in 20:
			game.animation_clock = float(i) * 0.016
			game.electric_presentation.update_presentation(view, true, 0.016)
		var times: Array[int] = []
		for i in 200:
			game.animation_clock = float(i + 20) * 0.016
			var started := Time.get_ticks_usec()
			game.electric_presentation.update_presentation(view, true, 0.016)
			times.append(Time.get_ticks_usec() - started)
		var total := 0
		for time in times:
			total += time
		times.sort()
		print("ELECTRIC_BENCH cells=", count, " crates=", crates.size(), " calls=", times.size(), " mean_us=", snappedf(float(total) / times.size(), 0.1), " median_us=", times[100], " p95_us=", times[189], " max_us=", times[199], " lights=", game.electric_presentation.samples.size())
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	print("ELECTRIC_BENCH_DONE: synthetic CPU timings, no FPS or GPU measurement")
	quit(0)
