extends SceneTree

const EnvironmentVFX = preload("res://environment_vfx.gd")

# Requires X11/OpenGL (or another actual rendering backend), never --headless.
# Optional ENV_RENDER_TEST_OUT writes screenshots for human review.
class EnvironmentCanvas extends "res://game.gd":
	var subject := Vector2i(2, 2)
	var top_left := Vector2(200, 100)

	func _ready() -> void:
		set_process(false)

	func _draw() -> void:
		_draw_environment_surface(self, subject, top_left)


var canvas: EnvironmentCanvas
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _capture(name: String) -> Image:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := OS.get_environment("ENV_RENDER_TEST_OUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")
	return image


func _orange_pixels(image: Image) -> int:
	var count := 0
	for y in range(100, 156):
		for x in range(200, 256):
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.7 and pixel.g > 0.3 and pixel.g < 0.8 and pixel.b < 0.3:
				count += 1
	return count


func _source_discharge_pixels(image: Image) -> int:
	var count := 0
	# Inside the orange triangle: pale yellow/white pixels must be from the
	# energized arc drawn over the still-present source marker.
	for y in range(115, 141):
		for x in range(214, 243):
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.85 and pixel.g > 0.65 and pixel.b > 0.35:
				count += 1
	return count


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ENVIRONMENT_RENDER_NOT_TESTED: a real rendering backend is required")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	RenderingServer.set_default_clear_color(Color.BLACK)
	canvas = EnvironmentCanvas.new()
	root.add_child(canvas)
	canvas.environment.reset({"cells": {canvas.subject: {"kind": "water", "source": true}}})
	var key := canvas.subject.x * 37 + canvas.subject.y * 79
	for index in 800:
		var clock := float(index) / 3600.0
		if EnvironmentVFX.arc_geometry(Vector2.ZERO, Vector2(20, 0), key, clock).opacity > 0.85:
			canvas.animation_clock = clock
			break
	var powered: Image = await _capture("fonte-ativa")
	_expect(_orange_pixels(powered) > 80, "the orange source triangle actually renders")
	_expect(_source_discharge_pixels(powered) > 3, "a bright arc stays visible over the source warning")
	canvas.animation_clock = 0.24
	var next_frame: Image = await _capture("arcos-segundo-instante")
	_expect(powered.get_data() != next_frame.get_data(), "powered electrical geometry changes between frames")
	canvas.environment.cells[canvas.subject].source = false
	canvas.environment.refresh_electricity()
	var off: Image = await _capture("fonte-desligada")
	_expect(_orange_pixels(off) < _orange_pixels(powered) / 3, "orange source marker and powered effects disappear when disconnected")
	canvas.environment.reset({"cells": {canvas.subject: {"kind": "current", "flow": Vector2i.RIGHT}}})
	canvas.animation_clock = 0.04
	var current_a: Image = await _capture("corrente-a")
	canvas.animation_clock = 0.24
	var current_b: Image = await _capture("corrente-b")
	_expect(current_a.get_data() != current_b.get_data(), "current particles move across rendered frames")
	canvas.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENVIRONMENT_RENDER_PASS checks=", checks, " real source triangle, animated arcs and current")
		quit(0)
	else:
		printerr("ENVIRONMENT_RENDER_FAIL count=", failures.size(), " checks=", checks)
		quit(1)
