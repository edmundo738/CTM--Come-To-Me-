extends Node2D

const CELL := 56.0
const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_BORDER := 2
const FOUR_WAY := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const CHALLENGES := [
	"Atravesse sem saltar",
	"Chegue ao portal sem sofrer dano",
	"Escape em ate 14 movimentos",
]
const MAP_SIZES := [Vector2i(19, 15), Vector2i(25, 17), Vector2i(31, 21), Vector2i(37, 23), Vector2i(43, 27)]
const CAPTURE_POP_TIME := 0.92
const CAPTURE_END_TIME := 1.95
const Generator = preload("res://level_generator.gd")
const HudScript = preload("res://hud.gd")
const AudioScript = preload("res://audio_feedback.gd")
const BackgroundShader = preload("res://background.gdshader")
const CaptureOverlayShader = preload("res://capture_overlay.gdshader")
const SideScrollStage = preload("res://side_scroll_stage.gd")

var grid: Array = []
var world_size := Vector2i(0, 0)
var player_position := Vector2i.ZERO
var player_from := Vector2.ZERO
var player_to := Vector2.ZERO
var player_anim := 1.0
var facing := Vector2i.RIGHT
var portal_position := Vector2i.ZERO
var portal_open := true
var enemies: Array[Dictionary] = []
var shields: Array[Vector2i] = []
var breakers: Array[Vector2i] = []
var coins: Array[Vector2i] = []
var switches: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var room_graph_edges: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var camera: Camera2D
var hud: Control
var audio: Node
var side_stage = null
var game_mode := "top_down"
var capture_overlay: ColorRect
var capture_material: ShaderMaterial
var generator = Generator.new()
var rng := RandomNumberGenerator.new()
var active_seed := 0
var generation_report := ""
var charges := 0
var breach_charges := 0
var total_coins := 0
var floor_number := 1
var turn_number := 0
var moves_this_floor := 0
var jumps_this_floor := 0
var hits_this_floor := 0
var coins_this_floor := 0
var coins_spawned_this_floor := 0
var stars_last_floor := 0
var floor_reward := 0
var best_score := 0
var rescues_completed := 0
var flash_time := 0.0
var flash_color := Color.WHITE
var game_state := "ready"
var damage_this_turn := false
var objective_type := "escape"
var challenge_index := 0
var challenge_complete := false
var last_notice := ""
var notice_timer := 0.0
var floor_history: Array[int] = []
var animation_clock := 0.0
var shake_time := 0.0
var shake_strength := 0.0
var capture_time := 0.0
var capture_darkness := 0.0
var capture_flash := 0.0
var capture_origin := Vector2.ZERO
var capture_popped := false
var capture_puddle_active := false
var capture_puddle_points := PackedVector2Array()
var capture_splats: Array[Dictionary] = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	var background_layer := CanvasLayer.new()
	background_layer.layer = -2
	add_child(background_layer)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = BackgroundShader
	background.material = material
	background_layer.add_child(background)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = HudScript.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.game = self
	hud_layer.add_child(hud)
	var capture_layer := CanvasLayer.new()
	capture_layer.name = "CaptureOverlay"
	capture_layer.layer = 1
	add_child(capture_layer)
	capture_overlay = ColorRect.new()
	capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture_material = ShaderMaterial.new()
	capture_material.shader = CaptureOverlayShader
	capture_overlay.material = capture_material
	capture_layer.add_child(capture_overlay)
	audio = AudioScript.new()
	add_child(audio)
	_load_profile()
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	add_child(camera)
	new_game()


func new_game(seed_value: int = -1) -> void:
	if side_stage != null and is_instance_valid(side_stage):
		side_stage.queue_free()
	side_stage = null
	game_mode = "top_down"
	if camera != null:
		camera.enabled = true
	if seed_value >= 0:
		active_seed = seed_value
	else:
		active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	floor_history.clear()
	floor_number = 1
	charges = 0
	breach_charges = 0
	total_coins = 0
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	game_state = "playing"
	if audio != null and audio.has_method("reset_cinematic_mix"):
		audio.reset_cinematic_mix()
	generate_floor(1)


func generate_floor(number: int) -> void:
	game_mode = "top_down"
	floor_number = number
	world_size = MAP_SIZES[mini(number - 1, MAP_SIZES.size() - 1)]
	var level_seed := active_seed + number * 7919
	var result: Dictionary = generator.generate(world_size.x, world_size.y, level_seed)
	generation_report = "WFC seed %d; contradicoes tentadas: %d" % [level_seed, result.attempts]
	if result.ok:
		grid = result.grid
		rooms = result.rooms
		room_graph_edges = result.edges
		player_position = result.start
		portal_position = result.goal
	else:
		grid = _fallback_layout(world_size.x, world_size.y)
		rooms.clear()
		room_graph_edges.clear()
		player_position = Vector2i(1, world_size.y / 2)
		portal_position = Vector2i(world_size.x - 2, rng.randi_range(1, world_size.y - 2))
		generation_report += "; fallback: %s" % result.reason
	for x in world_size.x:
		grid[0][x] = TILE_BORDER
		grid[world_size.y - 1][x] = TILE_BORDER
	for y in world_size.y:
		grid[y][0] = TILE_BORDER
		grid[y][world_size.x - 1] = TILE_BORDER
	grid[player_position.y][player_position.x] = TILE_FLOOR
	grid[portal_position.y][portal_position.x] = TILE_FLOOR
	if not result.ok:
		_carve_route(player_position, portal_position)
	player_from = _cell_center(player_position)
	player_to = player_from
	player_anim = 1.0
	enemies.clear()
	shields.clear()
	breakers.clear()
	coins.clear()
	switches.clear()
	traps.clear()
	var required_switches := 0
	if number >= 2 and number % 3 != 1:
		required_switches = mini(1 + number / 2, 4)
	objective_type = "switches" if required_switches > 0 else "escape"
	portal_open = required_switches == 0
	var occupied: Array[Vector2i] = [player_position, portal_position]
	var walkable := _reachable_cells(player_position)
	for i in required_switches:
		var position: Vector2i = _pick_spaced(walkable, occupied, 7)
		if position != Vector2i(-1, -1):
			switches.append({"pos": position, "active": false})
			occupied.append(position)
	for i in mini(1 + number / 2, 5):
		var position: Vector2i = _pick_spaced(walkable, occupied, 5)
		if position != Vector2i(-1, -1):
			var role := "hunter"
			if number >= 2 and i % 3 == 1:
				role = "sentry"
			elif number >= 4 and i % 3 == 2:
				role = "wisp"
			enemies.append({"pos": position, "next": position, "from": _cell_center(position), "to": _cell_center(position), "t": 1.0, "role": role, "phase": rng.randi_range(0, 1)})
			occupied.append(position)
	if number == 5:
		var boss_position: Vector2i = _pick_spaced(walkable, occupied, 9)
		if boss_position != Vector2i(-1, -1):
			enemies.append({"pos": boss_position, "next": boss_position, "from": _cell_center(boss_position), "to": _cell_center(boss_position), "t": 1.0, "role": "warden", "phase": 0})
			occupied.append(boss_position)
	for i in rng.randi_range(2, 4):
		var position: Vector2i = _pick_spaced(walkable, occupied, 2)
		if position != Vector2i(-1, -1):
			shields.append(position)
			occupied.append(position)
	if number >= 3 and number % 2 == 1:
		var breaker_position: Vector2i = _pick_spaced(walkable, occupied, 8)
		if breaker_position != Vector2i(-1, -1):
			breakers.append(breaker_position)
			occupied.append(breaker_position)
	for i in 8 + number:
		var position: Vector2i = _pick_spaced(walkable, occupied, 1)
		if position != Vector2i(-1, -1):
			coins.append(position)
			occupied.append(position)
	coins_spawned_this_floor = coins.size()
	if number >= 3:
		for i in mini(1 + number / 4, 3):
			var position: Vector2i = _pick_spaced(walkable, occupied, 4)
			if position != Vector2i(-1, -1):
				traps.append({"pos": position, "armed": true, "revealed": false})
				occupied.append(position)
	moves_this_floor = 0
	turn_number = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	challenge_index = rng.randi_range(0, CHALLENGES.size() - 1)
	challenge_complete = false
	last_notice = "%s   /   seed %d" % [CHALLENGES[challenge_index], level_seed]
	notice_timer = 3.8
	_update_enemy_intents()
	_update_camera(1.0)
	queue_redraw()


func _fallback_layout(width: int, height: int) -> Array:
	var result: Array = []
	for y in height:
		var row: Array[int] = []
		for x in width:
			row.append(0 if (x % 5 != 0 or y % 4 == 0) else 1)
		result.append(row)
	return result


func _carve_route(start: Vector2i, goal: Vector2i) -> void:
	var point := start
	grid[point.y][point.x] = 0
	while point != goal:
		var move_x := point.x != goal.x
		var move_y := point.y != goal.y
		var choose_x := move_x and (not move_y or rng.randf() < 0.5)
		if choose_x:
			point.x += signi(goal.x - point.x)
		else:
			point.y += signi(goal.y - point.y)
		grid[point.y][point.x] = 0
		if rng.randf() < 0.38:
			var branch: Vector2i = point + FOUR_WAY[rng.randi_range(0, 3)]
			if _inside(branch):
				grid[branch.y][branch.x] = 0


func _reachable_cells(start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	while not queue.is_empty():
		var point: Vector2i = queue.pop_front()
		result.append(point)
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _inside(next) and grid[next.y][next.x] == 0 and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return result


func _pick_spaced(cells: Array[Vector2i], occupied: Array[Vector2i], min_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for point in cells:
		if point == player_position or point == portal_position or occupied.has(point):
			continue
		var far_enough := true
		for other in occupied:
			if abs(point.x - other.x) + abs(point.y - other.y) < min_distance:
				far_enough = false
				break
		if far_enough:
			candidates.append(point)
	if candidates.is_empty():
		for point in cells:
			if point != player_position and point != portal_position and not occupied.has(point):
				candidates.append(point)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _inside(point: Vector2i) -> bool:
	return point.x >= 0 and point.x < world_size.x and point.y >= 0 and point.y < world_size.y


func _enemy_at(point: Vector2i, except_enemy: Dictionary = {}) -> bool:
	for enemy in enemies:
		if enemy != except_enemy and enemy.pos == point:
			return true
	return false


func _update_enemy_intents() -> void:
	var reserved: Array[Vector2i] = []
	for enemy in enemies:
		var role: String = enemy.get("role", "hunter")
		var phase: int = enemy.get("phase", 0)
		if role == "wisp" and (turn_number + phase) % 2 == 1:
			enemy.next = enemy.pos
			continue
		var origin: Vector2i = enemy.pos
		var best := origin
		var target := player_position
		if role == "sentry":
			var switch_target := _nearest_inactive_switch(origin)
			if switch_target != Vector2i(-1, -1) and _manhattan(origin, player_position) > 5:
				target = switch_target
		var best_distance: int = _manhattan(origin, target)
		for direction in FOUR_WAY:
			var candidate: Vector2i = origin + direction
			if not _inside(candidate) or grid[candidate.y][candidate.x] != 0:
				continue
			if _enemy_at(candidate, enemy) or reserved.has(candidate):
				continue
			var distance: int = _manhattan(candidate, target)
			if distance < best_distance:
				best = candidate
				best_distance = distance
		enemy.next = best
		if best != origin:
			reserved.append(best)


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)


func _nearest_inactive_switch(origin: Vector2i) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var distance := 2147483647
	for item in switches:
		if item.active:
			continue
		var candidate_distance := _manhattan(origin, item.pos)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = item.pos
	return nearest


func try_move(dx: int, dy: int) -> void:
	if game_state != "playing":
		return
	facing = Vector2i(dx, dy)
	var next := player_position + facing
	if _inside(next) and grid[next.y][next.x] == 0:
		_begin_player_move(next)
		moves_this_floor += 1
		audio.play("step")
	else:
		last_notice = "TOC! A parede nao cedeu. Procura outra passagem."
		notice_timer = 1.0
		shake_time = 0.12
		shake_strength = 5.0
		audio.play("blocked")
		_spawn_burst(_cell_center(player_position), Color("70e9ff"), 5, 58.0)
	_take_turn()


func _begin_player_move(next: Vector2i) -> void:
	player_from = _player_visual_position()
	player_position = next
	player_to = _cell_center(next)
	player_anim = 0.0


func try_jump() -> void:
	if game_state != "playing":
		return
	if charges <= 0:
		last_notice = "Sem escudo para saltar"
		notice_timer = 1.5
		audio.play("blocked")
		queue_redraw()
		return
	var middle := player_position + facing
	var landing := player_position + facing * 2
	if not _inside(middle) or not _inside(landing) or grid[middle.y][middle.x] != TILE_FLOOR or grid[landing.y][landing.x] != TILE_FLOOR:
		last_notice = "Precisas de duas casas livres para saltar"
		notice_timer = 1.5
		shake_time = 0.12
		shake_strength = 3.5
		audio.play("blocked")
		queue_redraw()
		return
	charges -= 1
	jumps_this_floor += 1
	moves_this_floor += 1
	_begin_player_move(landing)
	_spawn_burst(_cell_center(player_position), Color("6bf4ff"), 14, 115.0)
	audio.play("jump")
	_take_turn()


func try_break_wall() -> void:
	if game_state != "playing":
		return
	var target := player_position + facing
	if not _inside(target) or grid[target.y][target.x] == TILE_BORDER:
		last_notice = "A FRONTEIRA DAS RUINAS NAO CEDE"
		notice_timer = 1.2
		shake_time = 0.1
		shake_strength = 4.0
		audio.play("blocked")
		queue_redraw()
		return
	if grid[target.y][target.x] != TILE_WALL:
		last_notice = "NAO HA PAREDE PARA DEMOLIR"
		notice_timer = 1.0
		audio.play("blocked")
		queue_redraw()
		return
	if breach_charges <= 0:
		last_notice = "CARGA DE DEMOLICAO EM FALTA"
		notice_timer = 1.4
		audio.play("blocked")
		queue_redraw()
		return
	breach_charges -= 1
	grid[target.y][target.x] = TILE_FLOOR
	moves_this_floor += 1
	shake_time = 0.22
	shake_strength = 10.0
	flash_time = 0.08
	flash_color = Color("ffb365")
	last_notice = "PAREDE ABERTA — OS PERSEGUIDORES AVANCAM"
	notice_timer = 1.7
	_spawn_burst(_cell_center(target), Color("ff9f59"), 32, 180.0)
	audio.play("break_wall")
	_take_turn()


func _take_turn() -> void:
	damage_this_turn = false
	turn_number += 1
	_collect_pickups()
	_trigger_traps()
	_activate_switches()
	var positions: Array[Vector2i] = []
	for enemy in enemies:
		positions.append(enemy.next)
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		enemy.from = _cell_center(enemy.pos)
		enemy.pos = positions[i]
		enemy.to = _cell_center(enemy.pos)
		enemy.t = 0.0
		enemies[i] = enemy
	_update_enemy_intents()
	_check_enemy_collision()
	_check_portal()
	queue_redraw()


func _collect_pickups() -> void:
	if coins.has(player_position):
		coins.erase(player_position)
		coins_this_floor += 1
		total_coins += 1
		if total_coins > best_score:
			best_score = total_coins
			_save_profile()
		last_notice = "+1 MOEDA"
		notice_timer = 1.0
		_spawn_burst(_cell_center(player_position), Color("ffd15d"), 18, 150.0)
		_audio_coin()
	if shields.has(player_position):
		shields.erase(player_position)
		charges += 1
		last_notice = "ESCUDO +1  /  a aura protege de um impacto e permite saltar"
		notice_timer = 2.2
		_spawn_burst(_cell_center(player_position), Color("53edff"), 22, 130.0)
		audio.play("shield")
	if breakers.has(player_position):
		breakers.erase(player_position)
		breach_charges += 1
		last_notice = "CARGA DE DEMOLICAO +1 — B PARA ABRIR UMA PAREDE"
		notice_timer = 2.6
		_spawn_burst(_cell_center(player_position), Color("ffad67"), 26, 155.0)
		audio.play("breaker")


func _audio_coin() -> void:
	audio.play("coin")


func _activate_switches() -> void:
	for i in switches.size():
		var item: Dictionary = switches[i]
		if not item.active and item.pos == player_position:
			item.active = true
			switches[i] = item
			last_notice = "INTERRUPTOR %d/%d ATIVADO" % [_active_switches(), switches.size()]
			notice_timer = 2.1
			_spawn_burst(_cell_center(player_position), Color("7bf4ff"), 20, 130.0)
			audio.play("switch")
	if objective_type == "switches" and _active_switches() >= switches.size():
		if not portal_open:
			portal_open = true
			last_notice = "TODOS OS INTERRUPTORES ATIVOS — PORTAL ABERTO"
			notice_timer = 3.0
			_spawn_burst(_cell_center(portal_position), Color("d57aff"), 32, 175.0)
			audio.play("portal")


func _active_switches() -> int:
	var count := 0
	for item in switches:
		if item.active:
			count += 1
	return count


func _trigger_traps() -> void:
	for i in traps.size():
		var trap: Dictionary = traps[i]
		if trap.armed and trap.pos == player_position:
			trap.armed = false
			trap.revealed = true
			traps[i] = trap
			_apply_damage("ARMADILHA!", Color("ff7456"))


func _check_enemy_collision() -> void:
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if enemy.pos != player_position:
			continue
		if enemy.get("role", "hunter") == "warden" and charges > 0:
			_stagger_warden(i)
		else:
			_apply_damage("FOSTE ALCANCADO", Color("ff4e70"))
		return


func _stagger_warden(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	charges -= 1
	hits_this_floor += 1
	damage_this_turn = true
	var best_position: Vector2i = enemy.pos
	var best_distance := _manhattan(enemy.pos, player_position)
	for direction in FOUR_WAY:
		var candidate: Vector2i = enemy.pos + direction
		if not _inside(candidate) or grid[candidate.y][candidate.x] != TILE_FLOOR or _enemy_at(candidate, enemy):
			continue
		var distance := _manhattan(candidate, player_position)
		if distance > best_distance:
			best_distance = distance
			best_position = candidate
	enemy.from = _cell_center(enemy.pos)
	enemy.pos = best_position
	enemy.to = _cell_center(best_position)
	enemy.next = best_position
	enemy.t = 0.0
	enemies[index] = enemy
	shake_time = 0.2
	shake_strength = 7.0
	flash_time = 0.13
	flash_color = Color("56ebff")
	last_notice = "O GUARDIAO RECUOU — O ESCUDO QUEBROU"
	notice_timer = 2.0
	_spawn_burst(_cell_center(best_position), Color("66eaff"), 24, 170.0)
	audio.play("hit")


func _apply_damage(message: String, color: Color) -> void:
	if damage_this_turn:
		return
	damage_this_turn = true
	shake_time = 0.25
	shake_strength = 9.0
	flash_time = 0.16
	flash_color = color
	_spawn_burst(_player_visual_position(), color, 26, 210.0)
	if charges > 0:
		charges -= 1
		hits_this_floor += 1
		last_notice = message + " — O ESCUDO ABSORVEU O IMPACTO"
		notice_timer = 2.0
		audio.play("hit")
	else:
		_begin_capture(message, color)


func _begin_capture(message: String, color: Color) -> void:
	game_state = "captured"
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_origin = _player_visual_position()
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	player_from = capture_origin
	player_to = capture_origin
	player_anim = 1.0
	last_notice = message
	shake_time = 0.18
	shake_strength = 5.0
	flash_time = 0.13
	flash_color = color
	audio.play("inflate")
	_update_capture_overlay()


func _trigger_capture_burst() -> void:
	if capture_popped:
		return
	capture_popped = true
	capture_puddle_active = true
	capture_puddle_points = _make_puddle_outline()
	capture_splats.clear()
	for i in 15:
		var angle := TAU * float(i) / 15.0 + rng.randf_range(-0.2, 0.2)
		var radius := rng.randf_range(CELL * 0.72, CELL * 1.52)
		var offset := Vector2(cos(angle) * radius * 1.03, sin(angle) * radius * 0.86)
		capture_splats.append({"pos": capture_origin + offset, "radius": rng.randf_range(2.5, 8.0)})
	_spawn_blood_burst(capture_origin)
	audio.play("balloon_pop")
	shake_time = 0.48
	shake_strength = 18.0
	flash_time = 0.26
	flash_color = Color("ff224d")
	capture_flash = 1.0


func _make_puddle_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	var points := 28
	for i in points:
		var angle := TAU * float(i) / points
		var roughness := rng.randf_range(0.955, 1.045)
		outline.append(capture_origin + Vector2(cos(angle) * CELL * 1.68 * roughness, sin(angle) * CELL * 1.48 * roughness))
	return outline


func _spawn_blood_burst(origin: Vector2) -> void:
	for i in 64:
		var angle := TAU * float(i) / 64.0 + rng.randf_range(-0.16, 0.16)
		var speed := rng.randf_range(72.0, 245.0)
		var color := Color("ff3154") if i % 4 == 0 else Color("b60d31") if i % 3 == 0 else Color("e81e43")
		particles.append({"kind": "blood", "pos": origin, "velocity": Vector2(cos(angle), sin(angle)) * speed, "life": rng.randf_range(0.48, 1.05), "max_life": 1.05, "color": color, "size": rng.randf_range(2.8, 6.2), "gravity": rng.randf_range(175.0, 330.0)})
	for i in 18:
		var offset := Vector2(rng.randf_range(-CELL * 0.56, CELL * 0.56), rng.randf_range(-CELL * 0.48, CELL * 0.48))
		particles.append({"kind": "blood", "pos": origin + offset, "velocity": Vector2(rng.randf_range(-42.0, 42.0), rng.randf_range(-52.0, 28.0)), "life": rng.randf_range(0.3, 0.62), "max_life": 0.62, "color": Color("ff5b70"), "size": rng.randf_range(1.6, 3.4), "gravity": 120.0})


func _update_capture_sequence(delta: float) -> void:
	if game_state == "captured":
		capture_time += delta
		if capture_time < CAPTURE_POP_TIME:
			var progress := clampf(capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
			capture_darkness = lerpf(0.0, 0.44, progress * progress)
			capture_flash = 0.035 + absf(sin(capture_time * 36.0)) * 0.11 if progress > 0.28 else 0.0
		else:
			if not capture_popped:
				_trigger_capture_burst()
			var aftermath := clampf((capture_time - CAPTURE_POP_TIME) / (CAPTURE_END_TIME - CAPTURE_POP_TIME), 0.0, 1.0)
			capture_darkness = lerpf(0.44, 0.91, smoothstep(0.0, 1.0, aftermath))
			capture_flash = maxf(0.0, 1.0 - (capture_time - CAPTURE_POP_TIME) / 0.22)
		if capture_time >= CAPTURE_END_TIME:
			game_state = "game_over"
			capture_darkness = 0.91
			capture_flash = 0.0
			last_notice = "FOSTE CAPTURADO — R PARA TENTAR DE NOVO"
	elif game_state == "game_over":
		capture_darkness = 0.91
		capture_flash = 0.0
	_update_capture_overlay()


func _update_capture_overlay() -> void:
	if audio != null and audio.has_method("set_capture_mix"):
		audio.set_capture_mix(capture_darkness)
	if capture_material == null:
		return
	var focus := Vector2(0.5, 0.5)
	var viewport := get_viewport_rect().size
	var focus_camera = side_stage.camera if game_mode == "side_scroll" and side_stage != null else camera
	if focus_camera != null and viewport.x > 0.0 and viewport.y > 0.0:
		var screen_offset: Vector2 = capture_origin - focus_camera.global_position
		focus += Vector2(screen_offset.x / viewport.x, screen_offset.y / viewport.y)
	capture_material.set_shader_parameter("darkness", capture_darkness)
	capture_material.set_shader_parameter("red_flash", capture_flash)
	capture_material.set_shader_parameter("focus_uv", focus)


func _check_portal() -> void:
	if player_position != portal_position or game_state != "playing":
		return
	if not portal_open:
		last_notice = "PORTAL BLOQUEADO — ATIVA OS INTERRUPTORES"
		notice_timer = 2.0
		return
	var challenge_ok := false
	match challenge_index:
		0: challenge_ok = jumps_this_floor == 0
		1: challenge_ok = hits_this_floor == 0
		2: challenge_ok = moves_this_floor <= 14
	if challenge_ok and not challenge_complete:
		challenge_complete = true
		total_coins += 5
		last_notice = "DESAFIO CUMPRIDO  +5 MOEDAS"
		_spawn_burst(_cell_center(portal_position), Color("ffd15d"), 26, 170.0)
		audio.play("switch")
	stars_last_floor = _stars_for_floor()
	floor_history.append(stars_last_floor)
	floor_reward = stars_last_floor * 2 + (5 if challenge_complete else 0)
	total_coins += floor_reward
	if total_coins > best_score:
		best_score = total_coins
	_spawn_burst(_cell_center(portal_position), Color("c476ff"), 42, 240.0)
	audio.play("portal")
	if floor_number >= 5:
		game_state = "rescued"
		rescues_completed += 1
		last_notice = "ENCONTRASTE LIA — JUNTOS, VOCES DEIXAM AS RUINAS"
	else:
		game_state = "floor_clear"
		last_notice = "ANDAR %d CONCLUIDO — ENTER PARA AVANCAR" % floor_number
	notice_timer = 999.0
	_save_profile()


func advance_floor() -> void:
	if game_state == "floor_clear":
		if floor_number == 3:
			_begin_side_scroll_interlude()
			return
		generate_floor(floor_number + 1)
		game_state = "playing"


func _begin_side_scroll_interlude() -> void:
	floor_number = 4
	game_mode = "side_scroll"
	game_state = "side_scroll"
	objective_type = "fragments"
	enemies.clear()
	particles.clear()
	if camera != null:
		camera.enabled = false
	side_stage = SideScrollStage.new()
	side_stage.name = "FourthFloorSideScroll"
	side_stage.host = self
	add_child(side_stage)
	last_notice = "RUPTURA DE PERSPECTIVA — RECOLHE 3 FRAGMENTOS"
	notice_timer = 999.0
	audio.play("portal")


func _finish_side_scroll(fragment_count: int) -> void:
	game_mode = "top_down"
	if side_stage != null and is_instance_valid(side_stage):
		side_stage.queue_free()
	side_stage = null
	if camera != null:
		camera.enabled = true
	stars_last_floor = mini(5, 2 + fragment_count)
	floor_history.append(stars_last_floor)
	floor_reward = stars_last_floor * 2 + fragment_count * 2
	total_coins += floor_reward
	if total_coins > best_score:
		best_score = total_coins
	game_state = "floor_clear"
	last_notice = "RUPTURA CONCLUIDA — ENTER PARA O ANDAR FINAL"
	notice_timer = 999.0
	_spawn_burst(_cell_center(portal_position), Color("71eaf8"), 42, 235.0)
	audio.play("portal")
	_save_profile()


func _stars_for_floor() -> int:
	var fraction := float(coins_this_floor) / maxf(1.0, float(coins.size() + coins_this_floor))
	if fraction >= 1.0: return 5
	if fraction >= 0.75: return 4
	if fraction >= 0.5: return 3
	if fraction >= 0.25: return 2
	return 1


func get_objective_text() -> String:
	if game_mode == "side_scroll" and side_stage != null:
		return "FRAGMENTOS %d/3   /   ALCANCA O PORTAL" % side_stage.collected_fragments
	if objective_type == "switches":
		return "INTERRUPTORES %d/%d   /   %s" % [_active_switches(), switches.size(), "PORTAL ABERTO" if portal_open else "PORTAL BLOQUEADO"]
	if game_state == "rescued":
		return "LIA ESTA AQUI. ENCONTRASTE A TUA AMADA."
	return "OBJETIVO: ALCANCA O PORTAL E ENCONTRA LIA"


func _load_profile() -> void:
	var profile := ConfigFile.new()
	if profile.load("user://come_to_me_profile.cfg") == OK:
		best_score = int(profile.get_value("progress", "best_score", 0))
		rescues_completed = int(profile.get_value("progress", "rescues", 0))


func _save_profile() -> void:
	var profile := ConfigFile.new()
	profile.set_value("progress", "best_score", best_score)
	profile.set_value("progress", "rescues", rescues_completed)
	profile.save("user://come_to_me_profile.cfg")


func _process(delta: float) -> void:
	animation_clock += delta
	player_anim = minf(1.0, player_anim + delta / 0.115)
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		enemy.t = minf(1.0, enemy.t + delta / 0.14)
		enemies[i] = enemy
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.life -= delta
		particle.pos += particle.velocity * delta
		if particle.get("kind", "") == "blood":
			particle.velocity += Vector2(0.0, float(particle.get("gravity", 220.0))) * delta
			particle.velocity *= pow(0.38, delta)
		else:
			particle.velocity *= pow(0.08, delta)
		if particle.life <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = particle
	if notice_timer > 0.0 and notice_timer < 900.0:
		notice_timer = maxf(0.0, notice_timer - delta)
		if notice_timer == 0.0:
			last_notice = ""
	flash_time = maxf(0.0, flash_time - delta)
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
	_update_capture_sequence(delta)
	if audio != null and audio.has_method("set_threat"):
		audio.set_threat(_current_threat_level())
	_update_camera(delta)
	queue_redraw()


func _current_threat_level() -> float:
	if game_mode == "side_scroll" and side_stage != null:
		return side_stage.get_threat_level()
	if game_state != "playing":
		return 0.0
	var intensity := 0.0
	for enemy in enemies:
		var distance := _manhattan(enemy.pos, player_position)
		if distance <= 8:
			intensity = maxf(intensity, 1.0 - float(distance) / 10.0)
		if enemy.get("role", "") == "warden":
			intensity = maxf(intensity, 0.72)
	return intensity


func _update_camera(delta: float) -> void:
	if camera == null or game_mode == "side_scroll":
		return
	var viewport := get_viewport_rect().size
	var world_pixels := Vector2(world_size) * CELL
	var half := viewport * 0.5
	var desired := _player_visual_position()
	if world_pixels.x <= viewport.x:
		desired.x = world_pixels.x * 0.5
	else:
		desired.x = clampf(desired.x, half.x, world_pixels.x - half.x)
	if world_pixels.y <= viewport.y:
		desired.y = world_pixels.y * 0.5
	else:
		desired.y = clampf(desired.y, half.y, world_pixels.y - half.y)
	if delta <= 0.0:
		camera.global_position = desired
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 8.5))


func _player_visual_position() -> Vector2:
	if game_mode == "side_scroll" and side_stage != null:
		return side_stage.player_position
	var t := clampf(player_anim, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return player_from.lerp(player_to, t)


func _cell_center(point: Vector2i) -> Vector2:
	return Vector2((point.x + 0.5) * CELL, (point.y + 0.5) * CELL)


func _spawn_burst(position: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var angle := TAU * float(i) / count + rng.randf_range(-0.22, 0.22)
		var velocity := Vector2(cos(angle), sin(angle)) * rng.randf_range(speed * 0.25, speed)
		particles.append({"pos": position, "velocity": velocity, "life": rng.randf_range(0.25, 0.7), "max_life": 0.7, "color": color, "size": rng.randf_range(2.0, 5.0)})


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if game_mode == "side_scroll" and side_stage != null:
		side_stage.handle_key(event)
		return
	if not event.pressed or event.echo:
		return
	if game_state == "captured":
		if event.keycode == KEY_R:
			new_game()
		return
	match event.keycode:
		KEY_UP, KEY_W:
			facing = Vector2i.UP
			try_move(0, -1)
		KEY_DOWN, KEY_S:
			facing = Vector2i.DOWN
			try_move(0, 1)
		KEY_LEFT, KEY_A:
			facing = Vector2i.LEFT
			try_move(-1, 0)
		KEY_RIGHT, KEY_D:
			facing = Vector2i.RIGHT
			try_move(1, 0)
		KEY_SPACE: try_jump()
		KEY_B: try_break_wall()
		KEY_ENTER, KEY_KP_ENTER: advance_floor()
		KEY_R: new_game()
		KEY_M: audio.toggle_music()


func _draw() -> void:
	if game_mode == "side_scroll" or world_size == Vector2i.ZERO:
		return
	var shake := Vector2.ZERO
	if shake_time > 0.0:
		shake = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_strength * shake_time / 0.25
	draw_set_transform(shake)
	var half_view := get_viewport_rect().size * 0.5
	var first_x := maxi(0, int(floor((camera.global_position.x - half_view.x) / CELL)) - 1)
	var last_x := mini(world_size.x - 1, int(ceil((camera.global_position.x + half_view.x) / CELL)) + 1)
	var first_y := maxi(0, int(floor((camera.global_position.y - half_view.y) / CELL)) - 1)
	var last_y := mini(world_size.y - 1, int(ceil((camera.global_position.y + half_view.y) / CELL)) + 1)
	for y in range(first_y, last_y + 1):
		for x in range(first_x, last_x + 1):
			_draw_cell(Vector2i(x, y), grid[y][x])
	_draw_blood_puddle()
	for trap in traps:
		_draw_trap(trap)
	for item in switches:
		_draw_switch(item)
	for position in coins:
		_draw_coin(position)
	for position in shields:
		_draw_shield(position)
	for position in breakers:
		_draw_breaker(position)
	_draw_portal()
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cell(point: Vector2i, tile_type: int) -> void:
	var top_left := Vector2(point) * CELL
	var rect := Rect2(top_left, Vector2(CELL - 1.0, CELL - 1.0))
	if tile_type != TILE_FLOOR:
		var border := tile_type == TILE_BORDER
		var frame_color := Color("252e47") if not border else Color("11172a")
		var face_color := Color("384260") if not border else Color("1b2237")
		draw_rect(rect, frame_color, true)
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, CELL - 8)), face_color, true)
		draw_rect(Rect2(top_left + Vector2(4, 4), Vector2(CELL - 8, 2)), Color("8290ad", 0.32 if not border else 0.16), true)
		draw_rect(Rect2(top_left + Vector2(4, CELL - 5), Vector2(CELL - 9, 1)), Color("11172d", 0.82), true)
		if not border:
			var crack := Color("a9b3c7", 0.22)
			draw_line(top_left + Vector2(15, 16), top_left + Vector2(22, 22), crack, 1.0, true)
			draw_line(top_left + Vector2(22, 22), top_left + Vector2(19, 29), crack, 1.0, true)
			draw_line(top_left + Vector2(19, 29), top_left + Vector2(28, 34), crack, 1.0, true)
	else:
		var base := Color("11182c") if (point.x + point.y) % 2 == 0 else Color("141d33")
		draw_rect(rect, base, true)
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, 1)), Color("6a80bd", 0.075), true)
		draw_rect(Rect2(top_left + Vector2(CELL - 4, 4), Vector2(1, CELL - 8)), Color("7a6bab", 0.055), true)


func _draw_coin(point: Vector2i) -> void:
	var center := _cell_center(point)
	var pulse := 1.0 + sin(animation_clock * 4.4 + point.x * 0.7) * 0.1
	var spin := 0.22 + absf(sin(animation_clock * 5.5 + point.y)) * 0.78
	draw_circle(center, 19.0 * pulse, Color("ffcb47", 0.08))
	draw_circle(center, 12.0 * pulse, Color("ffc843", 0.14))
	draw_set_transform(center, 0.0, Vector2(spin, 1.0))
	draw_circle(Vector2.ZERO, 8.5, Color("ffcc4e"))
	draw_circle(Vector2(-2, -2), 3.4, Color("fff3b3"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shield(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 3.0 + point.x) * 2.8
	draw_circle(center + Vector2(0, bob), 21.0, Color("38e8ff", 0.075))
	var outline := PackedVector2Array([center + Vector2(0, -14 + bob), center + Vector2(12, -5 + bob), center + Vector2(9, 9 + bob), center + Vector2(0, 16 + bob), center + Vector2(-9, 9 + bob), center + Vector2(-12, -5 + bob)])
	draw_colored_polygon(outline, Color("40ddf0"))
	draw_polyline(PackedVector2Array([outline[0], outline[1], outline[2], outline[3], outline[4], outline[5], outline[0]]), Color("d1fcff"), 1.4, true)


func _draw_breaker(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 3.8 + point.y) * 2.2
	draw_circle(center + Vector2(0, bob), 22.0, Color("ff9b5a", 0.11))
	draw_arc(center + Vector2(0, bob), 15.0, animation_clock * 1.4, animation_clock * 1.4 + TAU * 0.78, 32, Color("ffd3a3", 0.72), 1.6, true)
	draw_line(center + Vector2(-5, 7 + bob), center + Vector2(6, -6 + bob), Color("ffc276"), 4.2, true)
	draw_line(center + Vector2(-6, -9 + bob), center + Vector2(7, -9 + bob), Color("fff0ca"), 4.0, true)
	draw_line(center + Vector2(-6, -9 + bob), center + Vector2(-10, -3 + bob), Color("fff0ca"), 3.0, true)


func _draw_portal() -> void:
	var center := _cell_center(portal_position)
	var pulse := sin(animation_clock * 2.7) * 3.0
	var main_color := Color("c37aff") if portal_open else Color("c05e79")
	draw_circle(center, 27.0 + pulse, Color(main_color, 0.10))
	draw_arc(center, 20.0 + pulse, animation_clock * 0.7, animation_clock * 0.7 + TAU * 0.82, 48, Color(main_color, 0.88), 3.0, true)
	draw_arc(center, 14.0 - pulse * 0.35, -animation_clock * 0.9, -animation_clock * 0.9 + TAU * 0.76, 40, Color("efb6ff", 0.8), 1.8, true)
	draw_circle(center, 11.0, Color("591d82", 0.9))
	draw_circle(center, 5.0 + sin(animation_clock * 6.0) * 1.4, Color("f5d7ff", 0.95))
	for i in 5:
		var angle := animation_clock * 0.75 + i * TAU / 5.0
		var orbit := Vector2(cos(angle), sin(angle) * 0.65) * (25.0 + pulse)
		draw_circle(center + orbit, 1.6 + float(i % 2), Color("edb8ff", 0.8))
	if not portal_open:
		draw_circle(center, 7.0, Color("251323", 0.92))
		draw_arc(center, 17.0, 0.0, TAU, 40, Color("ff7990"), 2.0, true)


func _draw_switch(item: Dictionary) -> void:
	var center := _cell_center(item.pos)
	var color := Color("61edfa") if not item.active else Color("b0fb8b")
	var pulse := 1.0 + sin(animation_clock * 4.0 + center.x) * 0.08
	draw_circle(center, 21.0 * pulse, Color(color, 0.1))
	draw_rect(Rect2(center - Vector2(13, 10), Vector2(26, 20)), Color("202944"), true)
	draw_rect(Rect2(center - Vector2(10, 7), Vector2(20, 14)), color, true)
	draw_circle(center, 4.0, Color("f5ffff"))


func _draw_trap(trap: Dictionary) -> void:
	var center := _cell_center(trap.pos)
	if not trap.armed and not trap.revealed:
		return
	var alpha := 0.64 + sin(animation_clock * 5.0 + center.x) * 0.16
	draw_circle(center, 18.0, Color("ff684c", alpha * 0.12))
	draw_arc(center, 13.0, animation_clock * 0.25, animation_clock * 0.25 + TAU, 28, Color("ff775c", alpha), 2.0, true)
	for i in 4:
		var angle := i * TAU / 4.0
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 7.0, 2.0, Color("ffbd73", alpha))


func _draw_enemy(enemy: Dictionary) -> void:
	var t: float = enemy.t
	t = t * t * (3.0 - 2.0 * t)
	var center: Vector2 = enemy.from.lerp(enemy.to, t)
	var bob := sin(animation_clock * 4.0 + center.x * 0.01) * 1.3
	center.y += bob
	var role: String = enemy.get("role", "hunter")
	var size_scale := 1.42 if role == "warden" else 1.0
	var color := Color("ffb64d") if role == "sentry" else Color("b985ff") if role == "wisp" else Color("ff526f")
	var face_direction := signi(player_position.x - enemy.pos.x)
	if role == "wisp":
		draw_circle(center + Vector2(0, 3), 23.0, Color("b985ff", 0.12))
		var ghost := PackedVector2Array([Vector2(0, -17), Vector2(11, -12), Vector2(15, -3), Vector2(13, 6), Vector2(8, 11), Vector2(4, 7), Vector2(0, 12), Vector2(-5, 7), Vector2(-10, 11), Vector2(-14, 5), Vector2(-15, -4), Vector2(-11, -12)])
		_draw_player_polygon(center + Vector2(0, bob), ghost, 1.0, Color("9673e8", 0.84))
		draw_arc(center, 18.0, animation_clock * 1.4, animation_clock * 1.4 + TAU * 0.7, 28, Color("d7b5ff", 0.7), 1.4, true)
		draw_circle(center + Vector2(-5 + face_direction, -3), 2.1, Color("fff4ff"))
		draw_circle(center + Vector2(5 + face_direction, -3), 2.1, Color("fff4ff"))
		draw_circle(center + Vector2(-5 + face_direction, -3), 0.9, Color("472365"))
		draw_circle(center + Vector2(5 + face_direction, -3), 0.9, Color("472365"))
		return
	draw_circle(center + Vector2(0, 12), 15.0 * size_scale, Color("020611", 0.44))
	draw_circle(center, 22.0 * size_scale, Color(color, 0.13))
	var cloak := PackedVector2Array([Vector2(0, -16), Vector2(9, -13), Vector2(14, -4), Vector2(12, 7), Vector2(17, 13), Vector2(8, 11), Vector2(2, 16), Vector2(-3, 11), Vector2(-13, 14), Vector2(-11, 5), Vector2(-15, -3), Vector2(-10, -12)])
	_draw_player_polygon(center + Vector2(0, bob), cloak, size_scale, color.darkened(0.38))
	var armor := PackedVector2Array([Vector2(-9, -9), Vector2(-4, -13), Vector2(5, -13), Vector2(10, -8), Vector2(8, 4), Vector2(4, 10), Vector2(-5, 10), Vector2(-9, 4)])
	_draw_player_polygon(center + Vector2(0, bob), armor, size_scale, color)
	var eye_y := -4.0 + bob
	var eye_offset := Vector2(float(face_direction) * 2.5, 0.0)
	draw_circle(center + Vector2(-5, eye_y) * size_scale + eye_offset, 2.8 * size_scale, Color("ffe9ce"))
	draw_circle(center + Vector2(5, eye_y) * size_scale + eye_offset, 2.8 * size_scale, Color("ffe9ce"))
	draw_circle(center + Vector2(-5, eye_y) * size_scale + eye_offset, 1.35 * size_scale, Color("371a2b"))
	draw_circle(center + Vector2(5, eye_y) * size_scale + eye_offset, 1.35 * size_scale, Color("371a2b"))
	if role == "sentry":
		var helm := PackedVector2Array([Vector2(-13, -5), Vector2(-11, -14), Vector2(-5, -19), Vector2(0, -14), Vector2(6, -19), Vector2(12, -12), Vector2(13, -4), Vector2(6, -8), Vector2(-7, -8)])
		_draw_player_polygon(center + Vector2(0, bob), helm, size_scale, Color("ffd17a"))
		draw_line(center + Vector2(13, 7), center + Vector2(19, -15), Color("ffe2a4"), 2.4, true)
		draw_circle(center + Vector2(-13, 5), 5.2, Color("ff8b58"))
	elif role == "warden":
		var crown := PackedVector2Array([Vector2(-14, -9), Vector2(-18, -20), Vector2(-8, -15), Vector2(0, -23), Vector2(7, -15), Vector2(18, -20), Vector2(14, -8)])
		_draw_player_polygon(center + Vector2(0, bob), crown, size_scale, Color("e8bcff"))
		draw_circle(center + Vector2(0, 6), 5.0 * size_scale, Color("f0caff", 0.9))
		draw_circle(center + Vector2(0, 6), 2.3 * size_scale, Color("ffffff"))
		draw_arc(center + Vector2(0, 4), 15.0 * size_scale, 0.2, PI - 0.2, 20, Color("f1c5ff", 0.86), 2.0, true)
	else:
		draw_circle(center + Vector2(-13, 5), 4.4, Color("ff8b58"))
		draw_circle(center + Vector2(13, 5), 4.4, Color("ff8b58"))
		draw_line(center + Vector2(-4, 8), center + Vector2(4, 8), Color("5f1835"), 1.8, true)


func _draw_player() -> void:
	if capture_popped and game_state in ["captured", "game_over"]:
		return
	var center := _player_visual_position()
	var bob := sin(animation_clock * 9.0) * 1.1
	var frightened := _player_is_frightened()
	var size_scale := 1.0
	var visibility := 1.0
	if game_state == "captured":
		var inflation := clampf(capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
		size_scale = 1.0 + 0.78 * smoothstep(0.0, 1.0, inflation)
		if inflation > 0.3 and int(capture_time * 26.0) % 2 == 0:
			visibility = 0.3
	var shadow := Color("00040d", 0.42 * visibility)
	draw_circle(center + Vector2(0, 13.0 * size_scale), 12.0 * size_scale, shadow)
	if charges > 0:
		for i in mini(charges, 3):
			var radius := (19.0 + i * 4.0 + sin(animation_clock * 5.0 + i) * 1.5) * size_scale
			draw_arc(center, radius, animation_clock * (0.9 + i * 0.1), animation_clock * (0.9 + i * 0.1) + TAU * 0.77, 32, Color("63eeff", (0.43 - i * 0.08) * visibility), 1.7 * size_scale, true)
	var suit := Color("ff667d") if game_state == "captured" else Color("1b7890")
	if game_state != "captured":
		suit = Color("265b83")
	var skin := Color("ffbd83") if frightened else Color("e9ad83")
	var eye_color := Color("582734") if frightened else Color("172b3e")
	var torso := PackedVector2Array([Vector2(-7, -2), Vector2(-11, 1), Vector2(-10, 7), Vector2(-7, 8), Vector2(-6, 15), Vector2(6, 15), Vector2(7, 8), Vector2(10, 7), Vector2(11, 1), Vector2(7, -2), Vector2(4, 0), Vector2(-4, 0)])
	var fade_suit := suit
	fade_suit.a *= visibility
	_draw_player_polygon(center + Vector2(0, bob * size_scale), torso, size_scale, fade_suit)
	var arm_color := suit.darkened(0.22)
	arm_color.a *= visibility
	draw_circle(center + Vector2(-9, 5) * size_scale, 3.2 * size_scale, arm_color)
	draw_circle(center + Vector2(9, 5) * size_scale, 3.2 * size_scale, arm_color)
	draw_rect(Rect2(center + Vector2(-6.5, 13) * size_scale, Vector2(4.5, 7) * size_scale), Color("132c48", visibility))
	draw_rect(Rect2(center + Vector2(2, 13) * size_scale, Vector2(4.5, 7) * size_scale), Color("132c48", visibility))
	draw_circle(center + Vector2(-4, 20) * size_scale, 3.2 * size_scale, Color("101e35", visibility))
	draw_circle(center + Vector2(5, 20) * size_scale, 3.2 * size_scale, Color("101e35", visibility))
	draw_circle(center + Vector2(0, -7 + bob) * size_scale, 8.0 * size_scale, Color("f4c59a", visibility))
	draw_arc(center + Vector2(0, -8 + bob) * size_scale, 8.1 * size_scale, PI + 0.12, TAU - 0.12, 16, Color("27314a", visibility), 3.2 * size_scale, true)
	var eye_offset := Vector2(facing) * (2.3 * size_scale)
	draw_circle(center + Vector2(-2.2, -8 + bob) * size_scale + eye_offset, (2.0 if frightened else 1.35) * size_scale, Color(eye_color, visibility))
	draw_circle(center + Vector2(2.8, -8 + bob) * size_scale + eye_offset, (2.0 if frightened else 1.35) * size_scale, Color(eye_color, visibility))
	if frightened:
		draw_circle(center + Vector2(0.3, -3 + bob) * size_scale, 2.1 * size_scale, Color("592532", visibility))
		draw_circle(center + Vector2(10, -16) * size_scale, (2.4 + sin(animation_clock * 10.0) * 0.5) * size_scale, Color("ff785e", visibility))
	else:
		draw_line(center + Vector2(-2, -3) * size_scale, center + Vector2(2, -3) * size_scale, Color("673f43", visibility), 1.2 * size_scale, true)


func _draw_player_polygon(center: Vector2, shape: PackedVector2Array, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point * scale)
	draw_colored_polygon(points, color)


func _draw_blood_puddle() -> void:
	if not capture_puddle_active or capture_puddle_points.size() < 3:
		return
	draw_colored_polygon(capture_puddle_points, Color("6f0922", 0.96))
	var inset := PackedVector2Array()
	for point in capture_puddle_points:
		inset.append(capture_origin + (point - capture_origin) * 0.72)
	draw_colored_polygon(inset, Color("a80d2d", 0.93))
	var outline := capture_puddle_points.duplicate()
	outline.append(capture_puddle_points[0])
	draw_polyline(outline, Color("ff3a5c", 0.82), 2.2, true)
	for splat in capture_splats:
		draw_circle(splat.pos, splat.radius, Color("b90e31", 0.95))
		draw_circle(splat.pos + Vector2(-splat.radius * 0.22, -splat.radius * 0.28), splat.radius * 0.28, Color("ff5268", 0.75))


func _player_is_frightened() -> bool:
	for enemy in enemies:
		if _manhattan(enemy.pos, player_position) <= 4:
			return true
	return false


func _draw_particles() -> void:
	for particle in particles:
		var strength: float = clampf(particle.life / particle.max_life, 0.0, 1.0)
		var color: Color = particle.color
		color.a *= strength
		var radius: float = particle.size * strength
		if particle.get("kind", "") == "blood":
			var velocity: Vector2 = particle.velocity
			if velocity.length_squared() > 4.0:
				draw_line(particle.pos, particle.pos - velocity.normalized() * radius * 2.2, color, maxf(1.0, radius * 0.72), true)
			draw_circle(particle.pos, radius, color)
		else:
			draw_circle(particle.pos, radius, color)
