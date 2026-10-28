extends Node2D

const STAGE_WIDTH := 4620.0
const GROUND_Y := 560.0
const BODY_WIDTH := 28.0
const STAND_HEIGHT := 44.0
const CROUCH_HEIGHT := 25.0
const CAPTURE_POP_TIME := 0.92

var host
var camera: Camera2D
var player_position := Vector2(100.0, GROUND_Y - STAND_HEIGHT * 0.5)
var velocity := Vector2.ZERO
var platforms: Array[Rect2] = []
var hazards: Array[Dictionary] = []
var crystals: Array[Vector2] = []
var patrols: Array[Dictionary] = []
var checkpoints: Array[float] = [100.0, 2140.0, 3520.0]
var checkpoint_x := 100.0
var grounded := true
var crouched := false
var move_left := false
var move_right := false
var hold_crouch := false
var jump_queued := false
var collected_fragments := 0
var clock := 0.0
var hint := ""
var hint_time := 0.0


func _ready() -> void:
	_build_stage()
	camera = Camera2D.new()
	camera.name = "SideScrollCamera"
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.2
	add_child(camera)
	_update_camera(0.0)


func _build_stage() -> void:
	platforms = [
		Rect2(0, GROUND_Y, 680, 112), Rect2(770, GROUND_Y, 610, 112), Rect2(1450, GROUND_Y, 720, 112),
		Rect2(2240, GROUND_Y, 620, 112), Rect2(2930, GROUND_Y, 670, 112), Rect2(3690, GROUND_Y, 930, 112),
		Rect2(430, 455, 190, 18), Rect2(910, 455, 210, 18), Rect2(1585, 458, 220, 18),
		Rect2(1930, 455, 230, 18), Rect2(2510, 455, 205, 18), Rect2(3155, 455, 230, 18), Rect2(3820, 455, 210, 18),
	]
	hazards = [
		{"type": "spikes", "rect": Rect2(340, GROUND_Y - 24, 74, 24)},
		{"type": "laser", "rect": Rect2(1080, GROUND_Y - 43, 112, 12)},
		{"type": "spikes", "rect": Rect2(1272, GROUND_Y - 24, 66, 24)},
		{"type": "laser", "rect": Rect2(1845, GROUND_Y - 43, 128, 12)},
		{"type": "spikes", "rect": Rect2(2380, GROUND_Y - 24, 88, 24)},
		{"type": "laser", "rect": Rect2(3315, GROUND_Y - 43, 126, 12)},
		{"type": "spikes", "rect": Rect2(3890, GROUND_Y - 24, 82, 24)},
	]
	crystals = [Vector2(525, 420), Vector2(1685, 425), Vector2(3265, 360)]
	patrols = [
		{"x": 1410.0, "y": 522.0, "min_x": 1390.0, "max_x": 1750.0, "speed": 88.0},
		{"x": 2810.0, "y": 508.0, "min_x": 2740.0, "max_x": 3070.0, "speed": -106.0},
		{"x": 3590.0, "y": 512.0, "min_x": 3520.0, "max_x": 3820.0, "speed": 94.0},
	]


func handle_key(event: InputEventKey) -> void:
	var key := event.keycode
	if key in [KEY_LEFT, KEY_A]:
		move_left = event.pressed
	elif key in [KEY_RIGHT, KEY_D]:
		move_right = event.pressed
	elif key in [KEY_DOWN, KEY_S]:
		hold_crouch = event.pressed
	elif event.pressed and not event.echo and key in [KEY_SPACE, KEY_UP, KEY_W]:
		jump_queued = true
	elif event.pressed and not event.echo and key == KEY_R:
		host.new_game()
	elif event.pressed and not event.echo and key == KEY_M:
		host.audio.toggle_music()


func _physics_process(delta: float) -> void:
	if host == null or host.game_state != "side_scroll":
		return
	step_simulation(delta)


func step_simulation(delta: float) -> void:
	clock += delta
	if hint_time > 0.0:
		hint_time = maxf(0.0, hint_time - delta)
		if hint_time == 0.0:
			hint = ""
	_update_crouch()
	var axis := float(int(move_right) - int(move_left))
	var move_speed := 135.0 if crouched else 270.0
	var acceleration := 1500.0 if axis != 0.0 else 1850.0
	velocity.x = move_toward(velocity.x, axis * move_speed, acceleration * delta)
	if jump_queued:
		if grounded and not crouched:
			velocity.y = -560.0
			grounded = false
			host.audio.play("jump")
		jump_queued = false
	var half_height := _half_height()
	var old_position := player_position
	var next_x := player_position.x + velocity.x * delta
	var body_width := BODY_WIDTH
	for platform in platforms:
		if old_position.y + half_height <= platform.position.y + 2.0 or old_position.y - half_height >= platform.end.y - 2.0:
			continue
		if velocity.x > 0.0 and old_position.x + body_width * 0.5 <= platform.position.x and next_x + body_width * 0.5 > platform.position.x:
			next_x = platform.position.x - body_width * 0.5
			velocity.x = 0.0
		elif velocity.x < 0.0 and old_position.x - body_width * 0.5 >= platform.end.x and next_x - body_width * 0.5 < platform.end.x:
			next_x = platform.end.x + body_width * 0.5
			velocity.x = 0.0
	player_position.x = clampf(next_x, BODY_WIDTH * 0.5, STAGE_WIDTH - BODY_WIDTH * 0.5)
	velocity.y += 1380.0 * delta
	var next_y := player_position.y + velocity.y * delta
	grounded = false
	if velocity.y >= 0.0:
		for platform in platforms:
			var horizontal_overlap := player_position.x + body_width * 0.5 > platform.position.x and player_position.x - body_width * 0.5 < platform.end.x
			var old_bottom := old_position.y + half_height
			var next_bottom := next_y + half_height
			if horizontal_overlap and old_bottom <= platform.position.y + 3.0 and next_bottom >= platform.position.y:
				next_y = platform.position.y - half_height
				velocity.y = 0.0
				grounded = true
				break
	else:
		for platform in platforms:
			var horizontal_overlap := player_position.x + body_width * 0.5 > platform.position.x and player_position.x - body_width * 0.5 < platform.end.x
			var old_top := old_position.y - half_height
			var next_top := next_y - half_height
			if horizontal_overlap and old_top >= platform.end.y - 3.0 and next_top <= platform.end.y:
				next_y = platform.end.y + half_height
				velocity.y = 0.0
				break
	player_position.y = next_y
	if player_position.y > 740.0:
		_hit("CAISTE NAS RUINAS")
		return
	_update_patrols(delta)
	if host.game_state != "side_scroll":
		queue_redraw()
		return
	_collect_crystals()
	_check_hazards()
	if host.game_state == "side_scroll":
		_check_exit()
		_update_checkpoint()
	_update_camera(delta)
	queue_redraw()


func _update_crouch() -> void:
	var wants_crouch := hold_crouch and grounded
	if wants_crouch == crouched:
		return
	var old_half := _half_height()
	var new_half := CROUCH_HEIGHT * 0.5 if wants_crouch else STAND_HEIGHT * 0.5
	var candidate_y := player_position.y + old_half - new_half
	if not wants_crouch:
		var standing_box := Rect2(player_position.x - BODY_WIDTH * 0.5, candidate_y - new_half, BODY_WIDTH, new_half * 2.0)
		for platform in platforms:
			if standing_box.intersects(platform):
				return
	player_position.y = candidate_y
	crouched = wants_crouch


func _half_height() -> float:
	return CROUCH_HEIGHT * 0.5 if crouched else STAND_HEIGHT * 0.5


func _body_rect() -> Rect2:
	var half_height := _half_height()
	return Rect2(player_position.x - BODY_WIDTH * 0.5, player_position.y - half_height, BODY_WIDTH, half_height * 2.0)


func _update_patrols(delta: float) -> void:
	for i in patrols.size():
		var enemy: Dictionary = patrols[i]
		enemy.x += enemy.speed * delta
		if enemy.x < enemy.min_x:
			enemy.x = enemy.min_x
			enemy.speed = absf(enemy.speed)
		elif enemy.x > enemy.max_x:
			enemy.x = enemy.max_x
			enemy.speed = -absf(enemy.speed)
		patrols[i] = enemy
		if _body_rect().intersects(Rect2(enemy.x - 13.0, enemy.y - 18.0, 26.0, 36.0)):
			_hit("A SENTINELA APANHOU-TE")
			return


func _check_hazards() -> void:
	var body := _body_rect()
	for hazard in hazards:
		if body.intersects(hazard.rect):
			_hit("ARMADILHA DE LUZ")
			return


func _hit(message: String) -> void:
	if host.game_state != "side_scroll":
		return
	if host.charges > 0:
		host.charges -= 1
		host.hits_this_floor += 1
		host.flash_time = 0.18
		host.flash_color = Color("63e9f5")
		host.shake_time = 0.2
		host.shake_strength = 9.0
		host.audio.play("hit")
		host._spawn_burst(player_position, Color("62edfa"), 25, 175.0)
		player_position = Vector2(checkpoint_x, GROUND_Y - STAND_HEIGHT * 0.5)
		velocity = Vector2.ZERO
		grounded = true
		crouched = false
		hint = "ESCUDO QUEBRADO — VOLTASTE AO MARCO"
		hint_time = 2.0
	else:
		host._begin_capture(message, Color("ff4266"))
	queue_redraw()


func _collect_crystals() -> void:
	for i in range(crystals.size() - 1, -1, -1):
		if player_position.distance_to(crystals[i]) > 27.0:
			continue
		var collected := crystals[i]
		crystals.remove_at(i)
		collected_fragments += 1
		host.total_coins += 1
		host.coins_this_floor += 1
		host._spawn_burst(collected, Color("84f7ff"), 24, 155.0)
		host.audio.play("coin")
		hint = "FRAGMENTO %d/3 — PORTAL INSTAVEL" % collected_fragments
		hint_time = 2.0
	queue_redraw()


func _check_exit() -> void:
	if player_position.x < STAGE_WIDTH - 95.0:
		return
	if collected_fragments < 3:
		player_position.x = STAGE_WIDTH - 96.0
		velocity.x = 0.0
		hint = "FALTAM FRAGMENTOS PARA ABRIR O PORTAL"
		hint_time = 2.0
		return
	host._finish_side_scroll(collected_fragments)


func _update_checkpoint() -> void:
	for marker in checkpoints:
		if player_position.x >= marker:
			checkpoint_x = marker


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var view := get_viewport_rect().size
	var desired_x := clampf(player_position.x + 190.0, view.x * 0.5, STAGE_WIDTH - view.x * 0.5)
	var desired := Vector2(desired_x, view.y * 0.5 + 8.0)
	if delta <= 0.0:
		camera.global_position = desired
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.2))


func get_threat_level() -> float:
	var closest := 9999.0
	for enemy in patrols:
		var distance := Vector2(enemy.x, enemy.y).distance_to(player_position)
		closest = minf(closest, distance)
	if closest > 440.0:
		return 0.0
	return 1.0 - closest / 520.0


func _draw() -> void:
	_draw_parallax_city()
	_draw_stage_platforms()
	_draw_hazards()
	_draw_checkpoints()
	for crystal in crystals:
		_draw_crystal(crystal)
	_draw_exit_portal()
	for enemy in patrols:
		_draw_patrol(enemy)
	if host != null:
		_draw_capture_puddle()
		_draw_particles()
	_draw_player()
	if hint != "" and hint_time > 0.0:
		var view := get_viewport_rect().size
		var center := camera.global_position
		draw_rect(Rect2(center.x - view.x * 0.5 + 24, center.y + view.y * 0.29, view.x - 48, 36), Color("091328", 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - view.x * 0.5 + 42, center.y + view.y * 0.29 + 24), hint, HORIZONTAL_ALIGNMENT_LEFT, view.x - 84, 14, Color("dcfaff"))


func _draw_parallax_city() -> void:
	var view := get_viewport_rect().size
	var camera_x := camera.global_position.x if camera != null else view.x * 0.5
	var start_x := floori((camera_x * 0.18 - view.x) / 245.0) * 245.0
	var end_x := camera_x * 0.18 + view.x * 1.4
	var index := 0
	var x := start_x
	while x < end_x:
		var height := 170.0 + float((index * 37) % 105)
		var width := 65.0 + float((index * 19) % 62)
		draw_rect(Rect2(x, GROUND_Y - height, width, height), Color("171b3c", 0.62))
		for row in 4:
			for column in 2:
				var window_x := x + 11 + column * 24
				var window_y := GROUND_Y - height + 22 + row * 28
				if window_y < GROUND_Y - 12 and (index + row + column) % 3 != 0:
					draw_rect(Rect2(window_x, window_y, 5, 9), Color("4e7fbb", 0.28))
		x += 245.0
		index += 1


func _draw_stage_platforms() -> void:
	for platform in platforms:
		draw_rect(Rect2(platform.position + Vector2(0, 8), platform.size), Color("020610", 0.4))
		draw_rect(platform, Color("151e35"))
		draw_rect(Rect2(platform.position, Vector2(platform.size.x, 5)), Color("51c9d6", 0.78))
		draw_rect(Rect2(platform.position + Vector2(0, 5), Vector2(platform.size.x, 2)), Color("263c59"))
		for x in range(int(platform.position.x + 20), int(platform.end.x), 42):
			draw_line(Vector2(x, platform.position.y + 14), Vector2(x, platform.end.y - 5), Color("7085a4", 0.12), 1.0)


func _draw_hazards() -> void:
	for hazard in hazards:
		var rect: Rect2 = hazard.rect
		if hazard.type == "laser":
			draw_rect(rect.grow(7), Color("ff4969", 0.09))
			draw_rect(rect, Color("ff526d", 0.66))
			draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.35, rect.size.x, 2), Color("fff3e7", 0.94))
			draw_rect(Rect2(rect.position.x - 5, rect.position.y - 5, 6, rect.size.y + 10), Color("ff8a9a"))
			draw_rect(Rect2(rect.end.x - 1, rect.position.y - 5, 6, rect.size.y + 10), Color("ff8a9a"))
		else:
			var count := int(rect.size.x / 20.0)
			for i in count:
				var left := rect.position.x + i * 20.0
				var points := PackedVector2Array([Vector2(left, rect.end.y), Vector2(left + 10, rect.position.y), Vector2(left + 20, rect.end.y)])
				draw_colored_polygon(points, Color("df5872"))
				draw_polyline(PackedVector2Array([points[0], points[1], points[2]]), Color("ff9aa2", 0.75), 1.0, true)


func _draw_checkpoints() -> void:
	for marker in checkpoints:
		var active := marker <= checkpoint_x
		var color := Color("7af0db") if active else Color("64708b")
		var center := Vector2(marker, GROUND_Y - 35)
		draw_circle(center, 18.0, Color(color, 0.08))
		draw_arc(center, 12.0, animation_clock_angle(), animation_clock_angle() + TAU * 0.78, 28, Color(color, 0.74), 2.0, true)
		draw_line(center + Vector2(0, 11), center + Vector2(0, 48), Color(color, 0.58), 2.0)


func animation_clock_angle() -> float:
	return clock * 0.7


func _draw_crystal(center: Vector2) -> void:
	var pulse := sin(clock * 4.5 + center.x * 0.01) * 3.0
	draw_circle(center, 24.0 + pulse, Color("57eafa", 0.1))
	var diamond := PackedVector2Array([center + Vector2(0, -15 - pulse), center + Vector2(11, 0), center + Vector2(0, 16 + pulse), center + Vector2(-11, 0)])
	draw_colored_polygon(diamond, Color("54dff1"))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("d7fdff"), 1.6, true)
	draw_line(center + Vector2(-3, -7), center + Vector2(3, 7), Color("efffff", 0.86), 1.2)


func _draw_exit_portal() -> void:
	var center := Vector2(STAGE_WIDTH - 95.0, GROUND_Y - 50.0)
	var open := collected_fragments >= 3
	var color := Color("b586ff") if open else Color("ff667e")
	draw_circle(center, 39.0 + sin(clock * 3.0) * 4.0, Color(color, 0.12))
	draw_arc(center, 29.0, clock * 0.6, clock * 0.6 + TAU * 0.82, 48, Color(color, 0.88), 4.0, true)
	draw_arc(center, 21.0, -clock * 0.8, -clock * 0.8 + TAU * 0.75, 40, Color("e9caff", 0.76), 2.0, true)
	draw_circle(center, 15.0, Color("271744", 0.95))
	draw_circle(center, 7.0 + sin(clock * 5.0) * 2.0, Color("f6edff" if open else "ff9ba9"))


func _draw_patrol(enemy: Dictionary) -> void:
	var center := Vector2(enemy.x, enemy.y + sin(clock * 7.0 + enemy.x) * 2.0)
	draw_circle(center, 22.0, Color("ff506f", 0.11))
	var body := PackedVector2Array([center + Vector2(0, -16), center + Vector2(12, -8), center + Vector2(13, 7), center + Vector2(5, 14), center + Vector2(-8, 13), center + Vector2(-14, 3), center + Vector2(-11, -10)])
	draw_colored_polygon(body, Color("d94566"))
	draw_circle(center + Vector2(-4, -3), 2.3, Color("fff2e8"))
	draw_circle(center + Vector2(5, -3), 2.3, Color("fff2e8"))
	draw_line(center + Vector2(-3, 6), center + Vector2(4, 6), Color("651d39"), 1.5, true)


func _draw_player() -> void:
	if host.capture_popped and host.game_state in ["captured", "game_over"]:
		return
	var scale := 1.0
	var visibility := 1.0
	if host.game_state == "captured":
		var progress := clampf(host.capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
		scale = 1.0 + 0.72 * smoothstep(0.0, 1.0, progress)
		if progress > 0.3 and int(host.capture_time * 26.0) % 2 == 0:
			visibility = 0.3
	var body_height := CROUCH_HEIGHT if crouched else STAND_HEIGHT
	var center := player_position
	var suit := Color("2a6389")
	if host.game_state == "captured":
		suit = Color("ff667d")
	var trail := 1.0 if velocity.x >= 0.0 else -1.0
	draw_circle(center + Vector2(0, 15 * scale), 13 * scale, Color("00040d", 0.36 * visibility))
	draw_line(center + Vector2(-7 * scale, body_height * 0.28 * scale), center + Vector2(-9 * scale + trail * 4, body_height * 0.47 * scale), Color("11243c", visibility), 5.0 * scale, true)
	draw_line(center + Vector2(6 * scale, body_height * 0.28 * scale), center + Vector2(8 * scale + trail * 4, body_height * 0.47 * scale), Color("11243c", visibility), 5.0 * scale, true)
	var torso := PackedVector2Array([Vector2(-8, -4), Vector2(-11, 0), Vector2(-9, 8), Vector2(-6, 11), Vector2(6, 11), Vector2(9, 8), Vector2(11, 0), Vector2(7, -4)])
	_draw_polygon_at(center, torso, scale, Color(suit, visibility))
	draw_circle(center + Vector2(0, -11 * scale), 8.0 * scale, Color("f0bd94", visibility))
	draw_arc(center + Vector2(0, -12 * scale), 8.1 * scale, PI + 0.1, TAU - 0.1, 16, Color("263149", visibility), 3.2 * scale, true)
	draw_circle(center + Vector2(3 * trail, -12 * scale), 1.4 * scale, Color("172b3e", visibility))
	if host.game_state == "captured":
		draw_circle(center + Vector2(0.3 * scale, -7 * scale), 2.1 * scale, Color("592532", visibility))
	else:
		draw_line(center + Vector2(-2, -7) * scale, center + Vector2(2, -7) * scale, Color("673f43", visibility), 1.2 * scale, true)


func _draw_polygon_at(center: Vector2, shape: PackedVector2Array, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point * scale)
	draw_colored_polygon(points, color)


func _draw_capture_puddle() -> void:
	if not host.capture_puddle_active:
		return
	draw_colored_polygon(host.capture_puddle_points, Color("6f0922", 0.96))
	var inset := PackedVector2Array()
	for point in host.capture_puddle_points:
		inset.append(host.capture_origin + (point - host.capture_origin) * 0.72)
	draw_colored_polygon(inset, Color("a80d2d", 0.93))
	var outline: PackedVector2Array = host.capture_puddle_points.duplicate()
	outline.append(host.capture_puddle_points[0])
	draw_polyline(outline, Color("ff3a5c", 0.82), 2.2, true)
	for splat in host.capture_splats:
		draw_circle(splat.pos, splat.radius, Color("b90e31", 0.95))


func _draw_particles() -> void:
	for particle in host.particles:
		var strength: float = clampf(particle.life / particle.max_life, 0.0, 1.0)
		var color: Color = particle.color
		color.a *= strength
		var radius: float = particle.size * strength
		if particle.get("kind", "") == "blood" and particle.velocity.length_squared() > 4.0:
			draw_line(particle.pos, particle.pos - particle.velocity.normalized() * radius * 2.2, color, maxf(1.0, radius * 0.72), true)
		draw_circle(particle.pos, radius, color)
