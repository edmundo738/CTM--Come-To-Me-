extends Node2D

const CELL := 56.0
const FOUR_WAY := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const CHALLENGES := [
	"Atravesse sem saltar",
	"Chegue ao portal sem sofrer dano",
	"Escape em ate 14 movimentos",
]
const MAP_SIZES := [Vector2i(19, 15), Vector2i(25, 17), Vector2i(31, 21), Vector2i(37, 23), Vector2i(43, 27)]
const Generator = preload("res://level_generator.gd")
const HudScript = preload("res://hud.gd")
const AudioScript = preload("res://audio_feedback.gd")
const BackgroundShader = preload("res://background.gdshader")

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
var coins: Array[Vector2i] = []
var switches: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var room_graph_edges: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var camera: Camera2D
var hud: Control
var audio: Node
var generator = Generator.new()
var rng := RandomNumberGenerator.new()
var active_seed := 0
var generation_report := ""
var charges := 0
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
	audio = AudioScript.new()
	add_child(audio)
	_load_profile()
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	add_child(camera)
	new_game()


func new_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		active_seed = seed_value
	else:
		active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	floor_history.clear()
	floor_number = 1
	charges = 0
	total_coins = 0
	game_state = "playing"
	generate_floor(1)


func generate_floor(number: int) -> void:
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
		grid[0][x] = 1
		grid[world_size.y - 1][x] = 1
	for y in world_size.y:
		grid[y][0] = 1
		grid[y][world_size.x - 1] = 1
	grid[player_position.y][player_position.x] = 0
	grid[portal_position.y][portal_position.x] = 0
	if not result.ok:
		_carve_route(player_position, portal_position)
	player_from = _cell_center(player_position)
	player_to = player_from
	player_anim = 1.0
	enemies.clear()
	shields.clear()
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
	if not _inside(middle) or not _inside(landing) or grid[middle.y][middle.x] == 1 or grid[landing.y][landing.x] == 1:
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
		if not _inside(candidate) or grid[candidate.y][candidate.x] == 1 or _enemy_at(candidate, enemy):
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
		game_state = "game_over"
		last_notice = message + " — R PARA TENTAR DE NOVO"
		notice_timer = 999.0
		audio.play("explosion")
		flash_time = 0.42
		flash_color = Color("ff234f")


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
		generate_floor(floor_number + 1)
		game_state = "playing"


func _stars_for_floor() -> int:
	var fraction := float(coins_this_floor) / maxf(1.0, float(coins.size() + coins_this_floor))
	if fraction >= 1.0: return 5
	if fraction >= 0.75: return 4
	if fraction >= 0.5: return 3
	if fraction >= 0.25: return 2
	return 1


func get_objective_text() -> String:
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
	_update_camera(delta)
	queue_redraw()


func _update_camera(delta: float) -> void:
	if camera == null:
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
	if not event is InputEventKey or not event.pressed or event.echo:
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
		KEY_ENTER, KEY_KP_ENTER: advance_floor()
		KEY_R: new_game()
		KEY_M: audio.toggle_music()


func _draw() -> void:
	if world_size == Vector2i.ZERO:
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
			_draw_cell(Vector2i(x, y), grid[y][x] == 1)
	for trap in traps:
		_draw_trap(trap)
	for item in switches:
		_draw_switch(item)
	for position in coins:
		_draw_coin(position)
	for position in shields:
		_draw_shield(position)
	_draw_portal()
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cell(point: Vector2i, wall: bool) -> void:
	var top_left := Vector2(point) * CELL
	var rect := Rect2(top_left, Vector2(CELL - 1.0, CELL - 1.0))
	if wall:
		draw_rect(rect, Color("202947"), true)
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, CELL - 8)), Color("30395d"), true)
		draw_rect(Rect2(top_left + Vector2(4, 4), Vector2(CELL - 8, 2)), Color("6573a0", 0.36), true)
		draw_rect(Rect2(top_left + Vector2(4, CELL - 5), Vector2(CELL - 9, 1)), Color("11172d", 0.78), true)
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
	var bounce := sin(animation_clock * 4.0 + center.x * 0.01) * 1.4
	center.y += bounce
	var role: String = enemy.get("role", "hunter")
	var scale := 1.35 if role == "warden" else 1.0
	var color := Color("ffb64d") if role == "sentry" else Color("b985ff") if role == "wisp" else Color("ff526f")
	draw_circle(center + Vector2(0, 3), 21.0 * scale, Color(color, 0.11))
	draw_rect(Rect2(center - Vector2(15, 15) * scale, Vector2(30, 30) * scale), color.darkened(0.48), true)
	draw_rect(Rect2(center - Vector2(12, 13) * scale, Vector2(24, 23) * scale), color, true)
	draw_rect(Rect2(center + Vector2(-7, -3), Vector2(4, 5)), Color("fff2e8"), true)
	draw_rect(Rect2(center + Vector2(4, -3), Vector2(4, 5)), Color("fff2e8"), true)
	draw_rect(Rect2(center + Vector2(-5, 7), Vector2(10, 2)), Color("78243f"), true)


func _draw_player() -> void:
	var center := _player_visual_position()
	var bob := sin(animation_clock * 9.0) * 1.2
	var frightened := _player_is_frightened()
	draw_circle(center + Vector2(0, 13), 13.0, Color("00040d", 0.48))
	if charges > 0:
		for i in mini(charges, 3):
			var radius := 19.0 + i * 4.0 + sin(animation_clock * 5.0 + i) * 1.5
			draw_arc(center, radius, animation_clock * (0.9 + i * 0.1), animation_clock * (0.9 + i * 0.1) + TAU * 0.77, 32, Color("63eeff", 0.43 - i * 0.08), 1.7, true)
	var skin := Color("ffb67a") if frightened else Color("54e9f6")
	draw_circle(center, 18.0, Color("ff7c66", 0.14) if frightened else Color("45eafa", 0.11))
	draw_circle(center + Vector2(0, bob), 12.0, skin)
	draw_circle(center + Vector2(-2, -2 + bob), 8.0, Color("ffe2c0") if frightened else Color("a7fbff"))
	var eye_offset := Vector2(facing) * 3.0
	var eye_color := Color("692b31") if frightened else Color("173646")
	var eye_size := 2.2 if frightened else 1.7
	draw_circle(center + Vector2(-2, -2) + eye_offset, eye_size, eye_color)
	draw_circle(center + Vector2(3, -2) + eye_offset, eye_size, eye_color)
	if frightened:
		draw_arc(center + Vector2(0, 5), 3.0, PI, TAU, 12, Color("7d3038"), 1.8, true)
		draw_circle(center + Vector2(0, -23), 3.5 + sin(animation_clock * 10.0) * 0.8, Color("ff785e"))


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
		draw_circle(particle.pos, particle.size * strength, color)
