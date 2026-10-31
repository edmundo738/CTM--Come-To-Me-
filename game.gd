extends Node2D

const CELL := 56.0
const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_BORDER := 2
const TILE_WATER := 3
const FOUR_WAY := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const CHALLENGES := [
	"Atravesse sem saltar",
	"Chegue ao portal sem sofrer dano",
	"Escape em ate 14 movimentos",
]
const MAP_SIZES := [Vector2i(19, 15), Vector2i(25, 17), Vector2i(31, 21), Vector2i(37, 23), Vector2i(43, 27)]
const FLOOR_NAMES := ["AS RUINAS DE NEON", "JARDIM DE VIDRO", "FORNALHA VIOLETA", "CATEDRAL DE GELO", "TRONO DO GUARDIAO"]
const LEVELS_PER_PAGE := 5
const CAPTURE_POP_TIME := 0.92
const CAPTURE_END_TIME := 1.95
const Generator = preload("res://level_generator.gd")
const HudScript = preload("res://hud.gd")
const AudioScript = preload("res://audio_feedback.gd")
const BackgroundShader = preload("res://background.gdshader")
const CaptureOverlayShader = preload("res://capture_overlay.gdshader")

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
var floor_stars: Dictionary = {}
var furthest_floor := 1
var has_resume := false
var resume_floor := 1
var resume_coins := 0
var resume_seed := 0
var resume_history: Array[int] = []
var coins_at_floor_start := 0
var persistence_enabled := true
var profile_path := "user://come_to_me_profile.cfg"
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
var level_page_start := 1
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
var capture_shockwave_radius := 0.0
var capture_chromatic := 0.0
var capture_noise := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	var background_layer := CanvasLayer.new()
	background_layer.layer = -2
	add_child(background_layer)
	var background := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = BackgroundShader
	background.material = material
	background_layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = HudScript.new()
	hud.game = self
	hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var capture_layer := CanvasLayer.new()
	capture_layer.name = "CaptureOverlay"
	capture_layer.layer = 1
	add_child(capture_layer)
	capture_overlay = ColorRect.new()
	capture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture_material = ShaderMaterial.new()
	capture_material.shader = CaptureOverlayShader
	capture_overlay.material = capture_material
	capture_layer.add_child(capture_overlay)
	capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio = AudioScript.new()
	add_child(audio)
	_load_profile()
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	add_child(camera)
	active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	generate_floor(1)
	game_state = "title"


func new_game(seed_value: int = -1) -> void:
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
	coins_at_floor_start = 0
	has_resume = false
	resume_floor = 1
	resume_coins = 0
	resume_seed = active_seed
	resume_history.clear()
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	capture_shockwave_radius = 0.0
	capture_chromatic = 0.0
	capture_noise = 0.0
	game_state = "playing"
	if audio != null and audio.has_method("reset_cinematic_mix"):
		audio.reset_cinematic_mix()
	generate_floor(1)
	_save_profile()


func continue_game() -> void:
	if not has_resume:
		new_game()
		return
	active_seed = resume_seed
	total_coins = resume_coins
	floor_history = resume_history.duplicate()
	charges = 0
	breach_charges = 0
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	capture_shockwave_radius = 0.0
	capture_chromatic = 0.0
	capture_noise = 0.0
	if audio != null and audio.has_method("reset_cinematic_mix"):
		audio.reset_cinematic_mix()
	generate_floor(resume_floor)
	game_state = "playing"


func start_level(number: int) -> void:
	if number < 1 or number > furthest_floor:
		return
	active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	floor_history.clear()
	total_coins = 0
	charges = 0
	breach_charges = 0
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	capture_shockwave_radius = 0.0
	capture_chromatic = 0.0
	capture_noise = 0.0
	if audio != null and audio.has_method("reset_cinematic_mix"):
		audio.reset_cinematic_mix()
	generate_floor(number)
	game_state = "playing"


func handle_hud_action(action: String) -> void:
	if action == "new_run":
		new_game()
	elif action == "continue":
		continue_game()
	elif action == "levels":
		open_level_select()
	elif action == "levels_previous":
		level_page_start = maxi(1, level_page_start - LEVELS_PER_PAGE)
	elif action == "levels_next":
		level_page_start = mini(maxi(1, furthest_floor - LEVELS_PER_PAGE + 1), level_page_start + LEVELS_PER_PAGE)
	elif action == "levels_previous":
		level_page_start = maxi(1, level_page_start - LEVELS_PER_PAGE)
	elif action == "levels_next":
		level_page_start = mini(maxi(1, furthest_floor - LEVELS_PER_PAGE + 1), level_page_start + LEVELS_PER_PAGE)
	elif action == "menu":
		capture_darkness = 0.0
		capture_flash = 0.0
		game_state = "title"
	elif action == "resume":
		game_state = "playing"
	elif action == "pause":
		game_state = "paused"
	elif action == "next_floor":
		advance_floor()
	elif action == "restart_floor":
		start_level(floor_number)
	elif action == "music":
		audio.toggle_music()
	elif action.begins_with("floor:"):
		start_level(int(action.trim_prefix("floor:")))
	queue_redraw()


func open_level_select() -> void:
	capture_darkness = 0.0
	capture_flash = 0.0
	level_page_start = maxi(1, furthest_floor - LEVELS_PER_PAGE + 1)
	game_state = "level_select"


func get_biome_index(number: int) -> int:
	return posmod(maxi(1, number) - 1, FLOOR_NAMES.size())


func get_floor_name(number: int) -> String:
	var safe_number := maxi(1, number)
	var name: String = FLOOR_NAMES[get_biome_index(safe_number)]
	var cycle := floori(float(safe_number - 1) / FLOOR_NAMES.size()) + 1
	return name if cycle == 1 else "%s / CICLO %d" % [name, cycle]


func get_floor_size(number: int) -> Vector2i:
	var safe_number := maxi(1, number)
	if safe_number <= MAP_SIZES.size():
		return MAP_SIZES[safe_number - 1]
	var growth := safe_number - MAP_SIZES.size()
	var max_width_growth := 14
	var max_height_growth := 8
	var width_growth := mini(max_width_growth, ceili(float(growth) / 2.0))
	var height_growth := mini(max_height_growth, floori(float(growth) / 3.0))
	var last_size: Vector2i = MAP_SIZES[MAP_SIZES.size() - 1]
	return Vector2i(last_size.x + width_growth, last_size.y + height_growth)


func _save_resume(number: int, coins: int) -> void:
	has_resume = true
	resume_floor = maxi(1, number)
	resume_coins = maxi(0, coins)
	resume_seed = active_seed
	resume_history = floor_history.duplicate()
	_save_profile()


func generate_floor(number: int) -> void:
	floor_number = maxi(1, number)
	world_size = get_floor_size(floor_number)
	var level_seed := active_seed + number * 7919
	rng.seed = level_seed
	coins_at_floor_start = total_coins
	var result: Dictionary = generator.generate(world_size.x, world_size.y, level_seed, get_biome_index(floor_number))
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
	_add_biome_landmarks(number)
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
	if number >= 2 and (number % 3 != 1 or number == 4):
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
	for i in mini(1 + int(number / 2), 7):
		var position: Vector2i = _pick_spaced(walkable, occupied, 5)
		if position != Vector2i(-1, -1):
			var role := "hunter"
			if number >= 2 and i % 3 == 1:
				role = "sentry"
			elif number >= 4 and i % 3 == 2:
				role = "wisp"
			if number >= 6 and i % 4 == 3:
				role = "rusher"
			enemies.append({"pos": position, "next": position, "from": _cell_center(position), "to": _cell_center(position), "t": 1.0, "role": role, "phase": rng.randi_range(0, 1)})
			occupied.append(position)
	if number % 5 == 0:
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


func _add_biome_landmarks(number: int) -> void:
	var biome_index := get_biome_index(number)
	if biome_index != 1 and biome_index != 3:
		return
	var candidates: Array[Dictionary] = []
	for room in rooms:
		var rect: Rect2i = room.rect
		if (biome_index == 1 and rect.size.x >= 4 and rect.size.y >= 4) or (biome_index == 3 and rect.size.x >= 6 and rect.size.y >= 5):
			candidates.append(room)
	var feature_count := mini(2 if biome_index == 1 else 3, candidates.size())
	for _index in feature_count:
		if candidates.is_empty():
			break
		var room_index := rng.randi_range(0, candidates.size() - 1)
		var rect: Rect2i = candidates[room_index].rect
		candidates.remove_at(room_index)
		var shape_rows: PackedStringArray = PackedStringArray(["011", "111", "011"]) if biome_index == 1 else PackedStringArray(["0110", "1111", "1111", "0110"])
		var feature_size := Vector2i(shape_rows[0].length(), shape_rows.size())
		var low := rect.position
		var high := rect.end - feature_size
		if high.x < low.x or high.y < low.y:
			continue
		for _attempt in 18:
			var top_left := Vector2i(rng.randi_range(low.x, high.x), rng.randi_range(low.y, high.y))
			var patch: Array[Vector2i] = []
			var clear_patch := true
			for y in feature_size.y:
				for x in feature_size.x:
					if shape_rows[y].substr(x, 1) != "1":
						continue
					var point := top_left + Vector2i(x, y)
					if point == player_position or point == portal_position or grid[point.y][point.x] != TILE_FLOOR:
						clear_patch = false
						break
					patch.append(point)
				if not clear_patch:
					break
			if not clear_patch:
				continue
			for point in patch:
				grid[point.y][point.x] = TILE_WATER
			if _reachable_cells(player_position).has(portal_position):
				break
			for point in patch:
				grid[point.y][point.x] = TILE_FLOOR


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
		var origin: Vector2i = enemy.pos
		var face_vector: Vector2i = player_position - origin
		if face_vector != Vector2i.ZERO:
			enemy.face = Vector2i(signi(face_vector.x), signi(face_vector.y))
		enemy.alert = _enemy_sees_player(origin)
		if role == "wisp" and (turn_number + phase) % 2 == 1:
			enemy.next = enemy.pos
			continue
		if role == "rusher" and enemy.alert:
			var delta_to_player: Vector2i = player_position - origin
			var distance := absi(delta_to_player.x) + absi(delta_to_player.y)
			var dash_direction := Vector2i.ZERO
			if delta_to_player.x == 0 and distance >= 2 and distance <= 5:
				dash_direction.y = signi(delta_to_player.y)
			elif delta_to_player.y == 0 and distance >= 2 and distance <= 5:
				dash_direction.x = signi(delta_to_player.x)
			if dash_direction != Vector2i.ZERO:
				var middle := origin + dash_direction
				var landing := origin + dash_direction * 2
				if _inside(middle) and _inside(landing) and grid[middle.y][middle.x] == TILE_FLOOR and grid[landing.y][landing.x] == TILE_FLOOR and not _enemy_at(middle, enemy) and not _enemy_at(landing, enemy) and not reserved.has(middle) and not reserved.has(landing):
					enemy.next = landing
					reserved.append(landing)
					continue
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


func _enemy_sees_player(origin: Vector2i) -> bool:
	if not _inside(origin) or not _inside(player_position):
		return false
	if Vector2(origin - player_position).length() > 7.0:
		return false
	var x := origin.x
	var y := origin.y
	var dx := absi(player_position.x - x)
	var sx := 1 if x < player_position.x else -1
	var dy := -absi(player_position.y - y)
	var sy := 1 if y < player_position.y else -1
	var error := dx + dy
	while x != player_position.x or y != player_position.y:
		var twice := 2 * error
		if twice >= dy:
			error += dy
			x += sx
		if twice <= dx:
			error += dx
			y += sy
		if (x != player_position.x or y != player_position.y) and grid[y][x] != TILE_FLOOR:
			return false
	return true


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
	capture_shockwave_radius = 0.0
	capture_chromatic = 0.0
	capture_noise = 0.0
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
		var radius := rng.randf_range(CELL * 0.50, CELL * 1.10)
		var offset := Vector2(cos(angle) * radius * 0.98, sin(angle) * radius * 0.84)
		capture_splats.append({"pos": capture_origin + offset, "radius": rng.randf_range(2.5, 8.0)})
	_spawn_blood_burst(capture_origin)
	audio.play("balloon_pop")
	shake_time = 0.55
	shake_strength = 22.0
	flash_time = 0.28
	flash_color = Color("ff224d")
	capture_flash = 1.0
	capture_shockwave_radius = 0.05
	capture_chromatic = 1.0
	capture_noise = 0.85


func _make_puddle_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	var points := 28
	for i in points:
		var angle := TAU * float(i) / points
		var roughness := rng.randf_range(0.965, 1.035)
		outline.append(capture_origin + Vector2(cos(angle) * CELL * 1.28 * roughness, sin(angle) * CELL * 1.16 * roughness))
	return outline


func _spawn_blood_burst(origin: Vector2) -> void:
	# Onda de choque no sistema de partículas
	particles.append({
		"kind": "shockwave",
		"pos": origin,
		"velocity": Vector2.ZERO,
		"radius": 10.0,
		"max_radius": CELL * 3.2,
		"life": 0.45,
		"max_life": 0.45,
		"color": Color("ff3b65")
	})
	# Estilhaços arteriais em alta velocidade
	for i in 75:
		var angle := TAU * float(i) / 75.0 + rng.randf_range(-0.18, 0.18)
		var speed := rng.randf_range(90.0, 310.0)
		var color := Color("ff3154") if i % 4 == 0 else Color("8a051e") if i % 3 == 0 else Color("d6123a")
		particles.append({
			"kind": "blood",
			"pos": origin,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": rng.randf_range(0.55, 1.15),
			"max_life": 1.15,
			"color": color,
			"size": rng.randf_range(3.2, 7.5),
			"gravity": rng.randf_range(160.0, 360.0)
		})
	# Gotas pesadas viscosas perto do ponto de impacto
	for i in 25:
		var offset := Vector2(rng.randf_range(-CELL * 0.65, CELL * 0.65), rng.randf_range(-CELL * 0.55, CELL * 0.55))
		particles.append({
			"kind": "blood",
			"pos": origin + offset,
			"velocity": Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(-65.0, 35.0)),
			"life": rng.randf_range(0.35, 0.8),
			"max_life": 0.8,
			"color": Color("ff637b"),
			"size": rng.randf_range(2.0, 4.5),
			"gravity": 140.0
		})


func _update_capture_sequence(delta: float) -> void:
	if game_state == "captured":
		capture_time += delta
		if capture_time < CAPTURE_POP_TIME:
			var progress := clampf(capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
			capture_darkness = lerpf(0.0, 0.44, progress * progress)
			capture_flash = 0.035 + absf(sin(capture_time * 36.0)) * 0.11 if progress > 0.28 else 0.0
			capture_chromatic = progress * 0.25
			capture_noise = progress * 0.20
		else:
			if not capture_popped:
				_trigger_capture_burst()
			var aftermath := clampf((capture_time - CAPTURE_POP_TIME) / (CAPTURE_END_TIME - CAPTURE_POP_TIME), 0.0, 1.0)
			capture_darkness = lerpf(0.44, 0.91, smoothstep(0.0, 1.0, aftermath))
			capture_flash = maxf(0.0, 1.0 - (capture_time - CAPTURE_POP_TIME) / 0.22)
			capture_shockwave_radius += delta * 1.6
			capture_chromatic = maxf(0.0, 1.0 - (capture_time - CAPTURE_POP_TIME) / 0.65)
			capture_noise = lerpf(0.65, 0.25, aftermath)
		if capture_time >= CAPTURE_END_TIME:
			game_state = "game_over"
			capture_darkness = 0.91
			capture_flash = 0.0
			capture_chromatic = 0.0
			capture_noise = 0.25
			last_notice = "FOSTE CAPTURADO — R CONTINUA NO ANDAR %d" % floor_number
			_save_resume(floor_number, coins_at_floor_start)
	elif game_state == "game_over":
		capture_darkness = 0.91
		capture_flash = 0.0
		capture_chromatic = 0.0
		capture_noise = 0.20
	_update_capture_overlay()


func _update_capture_overlay() -> void:
	if audio != null and audio.has_method("set_capture_mix"):
		audio.set_capture_mix(capture_darkness)
	if capture_material == null:
		return
	var focus := Vector2(0.5, 0.5)
	var viewport := get_viewport_rect().size
	if camera != null and viewport.x > 0.0 and viewport.y > 0.0:
		var screen_offset: Vector2 = capture_origin - camera.global_position
		focus += Vector2(screen_offset.x / viewport.x, screen_offset.y / viewport.y)
	capture_material.set_shader_parameter("darkness", capture_darkness)
	capture_material.set_shader_parameter("red_flash", capture_flash)
	capture_material.set_shader_parameter("focus_uv", focus)
	capture_material.set_shader_parameter("shockwave_radius", capture_shockwave_radius)
	capture_material.set_shader_parameter("chromatic_aberration", capture_chromatic)
	capture_material.set_shader_parameter("noise_strength", capture_noise)


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
	var rescue_milestone := floor_number % 5 == 0
	if rescue_milestone:
		game_state = "rescued"
		if floor_number == 5:
			rescues_completed += 1
			last_notice = "ENCONTRASTE LIA — A JORNADA CONTINUA"
		else:
			last_notice = "CICLO %d CONCLUIDO — SETOR SEGUINTE DESBLOQUEADO" % (floori(float(floor_number - 1) / 5.0) + 1)
	else:
		game_state = "floor_clear"
		last_notice = "ANDAR %d CONCLUIDO — ENTER PARA AVANCAR" % floor_number
	furthest_floor = maxi(furthest_floor, floor_number + 1)
	resume_floor = floor_number + 1
	resume_coins = total_coins
	resume_seed = active_seed
	resume_history = floor_history.duplicate()
	has_resume = true
	var star_key := str(floor_number)
	floor_stars[star_key] = maxi(int(floor_stars.get(star_key, 0)), stars_last_floor)
	notice_timer = 999.0
	_save_profile()


func advance_floor() -> void:
	if game_state == "floor_clear" or game_state == "rescued":
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
	if profile.load(profile_path) == OK:
		best_score = int(profile.get_value("progress", "best_score", 0))
		rescues_completed = int(profile.get_value("progress", "rescues", 0))
		furthest_floor = maxi(1, int(profile.get_value("progress", "furthest_floor", 1)))
		var stored_stars = profile.get_value("progress", "floor_stars", {})
		floor_stars = stored_stars.duplicate(true) if stored_stars is Dictionary else {}
		has_resume = bool(profile.get_value("progress", "has_resume", false))
		resume_floor = maxi(1, int(profile.get_value("progress", "resume_floor", 1)))
		resume_coins = int(profile.get_value("progress", "resume_coins", 0))
		resume_seed = int(profile.get_value("progress", "resume_seed", 0))
		var stored_history = profile.get_value("progress", "resume_history", [])
		resume_history.clear()
		for value in stored_history:
			resume_history.append(int(value))
		# Old saves treated floor five as the campaign ending. Open the next procedural floor for those players.
		if rescues_completed > 0 and furthest_floor <= 5:
			furthest_floor = 6
			if not has_resume:
				has_resume = true
				resume_floor = 6
				resume_coins = 0
				resume_seed = int(Time.get_ticks_usec()) ^ randi()
				resume_history.clear()
			_save_profile()


func _save_profile() -> void:
	if not persistence_enabled:
		return
	var profile := ConfigFile.new()
	profile.set_value("progress", "best_score", best_score)
	profile.set_value("progress", "rescues", rescues_completed)
	profile.set_value("progress", "furthest_floor", furthest_floor)
	profile.set_value("progress", "floor_stars", floor_stars)
	profile.set_value("progress", "has_resume", has_resume)
	profile.set_value("progress", "resume_floor", resume_floor)
	profile.set_value("progress", "resume_coins", resume_coins)
	profile.set_value("progress", "resume_seed", resume_seed)
	profile.set_value("progress", "resume_history", resume_history)
	profile.save(profile_path)


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
		var vel: Vector2 = particle.get("velocity", Vector2.ZERO)
		particle.pos += vel * delta
		if particle.get("kind", "") == "blood":
			vel += Vector2(0.0, float(particle.get("gravity", 220.0))) * delta
			vel *= pow(0.38, delta)
			particle["velocity"] = vel
		elif particle.get("kind", "") == "shockwave":
			pass
		else:
			vel *= pow(0.08, delta)
			particle["velocity"] = vel
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
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if game_state == "captured":
		return
	if game_state == "title":
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if has_resume:
					continue_game()
				else:
					new_game()
			KEY_N: new_game()
			KEY_L: open_level_select()
			KEY_M: audio.toggle_music()
		return
	if game_state == "level_select":
		if event.keycode == KEY_ESCAPE:
			game_state = "title"
		elif event.keycode == KEY_LEFT:
			level_page_start = maxi(1, level_page_start - LEVELS_PER_PAGE)
		elif event.keycode == KEY_RIGHT:
			level_page_start = mini(maxi(1, furthest_floor - LEVELS_PER_PAGE + 1), level_page_start + LEVELS_PER_PAGE)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			start_level(level_page_start + event.keycode - KEY_1)
		return
	if game_state == "paused":
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			game_state = "playing"
		elif event.keycode == KEY_L:
			open_level_select()
		elif event.keycode == KEY_M:
			audio.toggle_music()
		return
	if game_state == "game_over":
		if event.keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER]:
			continue_game()
		elif event.keycode == KEY_L:
			open_level_select()
		elif event.keycode == KEY_ESCAPE:
			capture_darkness = 0.0
			capture_flash = 0.0
			game_state = "title"
		return
	if game_state == "floor_clear":
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			advance_floor()
		elif event.keycode == KEY_ESCAPE:
			game_state = "title"
		return
	if game_state == "rescued":
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			advance_floor()
		elif event.keycode == KEY_N:
			new_game()
		elif event.keycode == KEY_ESCAPE:
			game_state = "title"
		return
	match event.keycode:
		KEY_ESCAPE: game_state = "paused"
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
		KEY_R: start_level(floor_number)
		KEY_N: new_game()
		KEY_L: open_level_select()
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
	var floor_a := Color("11182c")
	var floor_b := Color("141d33")
	var floor_glint := Color("6a80bd", 0.08)
	var wall_frame := Color("252e47")
	var wall_face := Color("384260")
	var wall_glint := Color("8290ad", 0.35)
	var neon_accent := Color("4de3ff")
	var biome_idx := get_biome_index(floor_number)
	match biome_idx:
		1:
			floor_a = Color("10242a"); floor_b = Color("132c31"); floor_glint = Color("77d9c8", 0.08)
			wall_frame = Color("243d43"); wall_face = Color("35545a"); wall_glint = Color("9ae2d3", 0.30)
			neon_accent = Color("4effd2")
		2:
			floor_a = Color("241a2d"); floor_b = Color("2b1e32"); floor_glint = Color("e68a87", 0.08)
			wall_frame = Color("493044"); wall_face = Color("60404a"); wall_glint = Color("f0a08e", 0.30)
			neon_accent = Color("ff7e5a")
		3:
			floor_a = Color("132239"); floor_b = Color("172941"); floor_glint = Color("71d9ee", 0.09)
			wall_frame = Color("263956"); wall_face = Color("374b6b"); wall_glint = Color("a8d8ef", 0.32)
			neon_accent = Color("6de9ff")
		4:
			floor_a = Color("211934"); floor_b = Color("2a1d3c"); floor_glint = Color("e8bf72", 0.09)
			wall_frame = Color("43304c"); wall_face = Color("5c415e"); wall_glint = Color("e9bd7c", 0.32)
			neon_accent = Color("f5ca68")
	if tile_type == TILE_WATER:
		if biome_idx == 3:
			_draw_ice_tile(point, top_left)
		else:
			_draw_water_tile(point, top_left)
		return
	if tile_type != TILE_FLOOR:
		var border := tile_type == TILE_BORDER
		var frame_color := wall_frame if not border else floor_a.darkened(0.15)
		var face_color := wall_face if not border else floor_b.darkened(0.18)
		var top_glint := wall_glint
		top_glint.a *= 0.16 if border else 1.0
		# Sombra 3D-ish inferior
		draw_rect(Rect2(top_left + Vector2(0, CELL - 4), Vector2(CELL, 6)), Color(0, 0, 0, 0.45), true)
		# Estrutura do bloco
		draw_rect(rect, frame_color, true)
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, CELL - 9)), face_color, true)
		# Topo chanfrado e iluminado
		draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, 3)), top_glint, true)
		draw_rect(Rect2(top_left + Vector2(3, CELL - 7), Vector2(CELL - 7, 2)), Color("0a0f1e", 0.85), true)
		if not border:
			# Tubos e condutas de néon tecnológicas
			var wall_variant := (point.x * 23 + point.y * 41) % 4
			if wall_variant == 1:
				# Cabo néon horizontal
				draw_line(top_left + Vector2(5, CELL * 0.5), top_left + Vector2(CELL - 6, CELL * 0.5), Color(neon_accent, 0.45), 2.0, true)
				draw_line(top_left + Vector2(5, CELL * 0.5), top_left + Vector2(CELL - 6, CELL * 0.5), Color("ffffff", 0.65), 1.0, true)
			elif wall_variant == 2:
				# Painel de ventilação / grelha no bloco
				draw_rect(Rect2(top_left + Vector2(8, 8), Vector2(CELL - 16, CELL - 18)), Color("111624", 0.8), true)
				for g in 3:
					draw_line(top_left + Vector2(10, 12 + g * 8), top_left + Vector2(CELL - 11, 12 + g * 8), Color(neon_accent, 0.35), 1.2, true)
			elif wall_variant == 3:
				# Nicho luminoso vertical
				draw_rect(Rect2(top_left + Vector2(CELL * 0.5 - 2, 8), Vector2(4, CELL - 18)), Color(neon_accent, 0.28), true)
				draw_line(top_left + Vector2(CELL * 0.5, 8), top_left + Vector2(CELL * 0.5, CELL - 10), Color("ffffff", 0.7), 1.2, true)
	else:
		var base := floor_a if (point.x + point.y) % 2 == 0 else floor_b
		draw_rect(rect, base, true)
		# Grelha de borda subtil
		draw_rect(rect, Color("080d1a", 0.5), false, 1.0)
		var floor_variant := (point.x * 37 + point.y * 19) % 6
		match floor_variant:
			0:
				# Parafusos/rebites nos 4 cantos
				var rivet_color := Color(floor_glint.r, floor_glint.g, floor_glint.b, 0.45)
				draw_circle(top_left + Vector2(6, 6), 1.5, rivet_color)
				draw_circle(top_left + Vector2(CELL - 7, 6), 1.5, rivet_color)
				draw_circle(top_left + Vector2(6, CELL - 7), 1.5, rivet_color)
				draw_circle(top_left + Vector2(CELL - 7, CELL - 7), 1.5, rivet_color)
			1:
				# Grelha de ventilação com brilho do subsolo
				var vent_rect := Rect2(top_left + Vector2(8, 8), Vector2(CELL - 17, CELL - 17))
				draw_rect(vent_rect, Color("070b16", 0.75), true)
				draw_rect(vent_rect, Color(neon_accent, 0.06), true)
				for i in 4:
					draw_line(top_left + Vector2(10, 11 + i * 8), top_left + Vector2(CELL - 11, 11 + i * 8), Color(neon_accent, 0.22), 1.2, true)
			2:
				# Fio condutor de dados com pulso
				var pulse := 0.15 + 0.15 * sin(animation_clock * 2.5 + point.x * 0.5 + point.y * 0.3)
				draw_line(top_left + Vector2(CELL * 0.5, 4), top_left + Vector2(CELL * 0.5, CELL - 5), Color(neon_accent, pulse), 1.4, true)
			3:
				# Placa chanfrada dupla
				draw_line(top_left + Vector2(4, CELL * 0.5), top_left + Vector2(CELL - 5, CELL * 0.5), Color("080d1c", 0.65), 1.5, true)
				draw_rect(Rect2(top_left + Vector2(4, 4), Vector2(CELL - 9, CELL * 0.5 - 5)), Color(floor_glint, 0.035), true)
			4:
				# Ranhura diagonal tática
				draw_line(top_left + Vector2(6, CELL - 8), top_left + Vector2(CELL - 8, 6), Color(floor_glint, 0.12), 1.2, true)
			_:
				# Glint subtil padrão
				draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 7, 1)), floor_glint, true)
				var side_glint := floor_glint
				side_glint.a *= 0.65
				draw_rect(Rect2(top_left + Vector2(CELL - 4, 4), Vector2(1, CELL - 8)), side_glint, true)


func _draw_water_tile(point: Vector2i, top_left: Vector2) -> void:
	var is_garden := get_biome_index(floor_number) == 1
	var deep := Color("082029") if is_garden else Color("0d2538")
	var water := Color("134c56") if is_garden else Color("21536b")
	var caustic := Color("7bf6e4", 0.32) if is_garden else Color("8de4ff", 0.34)
	var shore := Color("8bfad0", 0.65) if is_garden else Color("9fe9ff", 0.68)
	# Fundo abissal
	draw_rect(Rect2(top_left, Vector2(CELL - 1.0, CELL - 1.0)), deep, true)
	draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL - 5, CELL - 5)), water, true)
	# Caustics procedurais animadas (redes de luz de água)
	var phase := animation_clock * 1.6 + point.x * 0.8 + point.y * 0.6
	var cy1 := 14.0 + sin(phase) * 3.2
	var cy2 := 32.0 + cos(phase * 1.3) * 3.0
	draw_line(top_left + Vector2(6, cy1), top_left + Vector2(CELL - 8, cy1 + 2.0), caustic, 1.8, true)
	draw_line(top_left + Vector2(8, cy2), top_left + Vector2(CELL - 6, cy2 - 2.5), caustic, 1.6, true)
	draw_line(top_left + Vector2(18, 6), top_left + Vector2(22 + sin(phase) * 4.0, CELL - 8), Color(caustic, 0.18), 1.2, true)
	# Bolhas de luz cintilantes
	var bubble_y := fposmod(CELL - 6.0 - (animation_clock * 16.0 + (point.x + point.y) * 12.0), CELL - 8.0)
	draw_circle(top_left + Vector2(15.0 + sin(animation_clock * 3.0) * 3.0, bubble_y), 1.6, Color(caustic, 0.7))
	# Contornos de margem e espuma neon
	for direction in FOUR_WAY:
		var neighbor: Vector2i = point + direction
		if _inside(neighbor) and grid[neighbor.y][neighbor.x] == TILE_WATER:
			continue
		var start := Vector2.ZERO
		var finish := Vector2.ZERO
		if direction == Vector2i.UP:
			start = top_left + Vector2(3, 2); finish = top_left + Vector2(CELL - 4, 2)
		elif direction == Vector2i.DOWN:
			start = top_left + Vector2(3, CELL - 3); finish = top_left + Vector2(CELL - 4, CELL - 3)
		elif direction == Vector2i.LEFT:
			start = top_left + Vector2(2, 3); finish = top_left + Vector2(2, CELL - 4)
		else:
			start = top_left + Vector2(CELL - 3, 3); finish = top_left + Vector2(CELL - 3, CELL - 4)
		draw_line(start, finish, shore, 2.2, true)


func _draw_ice_tile(point: Vector2i, top_left: Vector2) -> void:
	var ice_deep := Color("0b1e33")
	var ice_surface := Color("1a3d5e")
	var crack_color := Color("c6f3ff", 0.65)
	var glow := Color("6ee3ff", 0.40)
	draw_rect(Rect2(top_left, Vector2(CELL - 1.0, CELL - 1.0)), ice_deep, true)
	draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL - 5, CELL - 5)), ice_surface, true)
	# Rachas cristalinas procedurais deterministas
	var seed_val := (point.x * 47 + point.y * 89)
	var r1 := float(seed_val % 10) / 10.0
	var r2 := float((seed_val / 10) % 10) / 10.0
	draw_line(top_left + Vector2(6, 8 + r1 * 10), top_left + Vector2(24, 22), crack_color, 1.4, true)
	draw_line(top_left + Vector2(24, 22), top_left + Vector2(CELL - 8, 16 + r2 * 14), crack_color, 1.2, true)
	draw_line(top_left + Vector2(24, 22), top_left + Vector2(18 + r1 * 8, CELL - 8), Color(crack_color, 0.45), 1.0, true)
	# Brilho especular dinâmico que desliza sobre o gelo
	var sweep := fposmod(animation_clock * 0.45 + point.x * 0.12 - point.y * 0.08, 1.8)
	if sweep < 1.0:
		var glint_x := top_left.x + sweep * (CELL + 16.0) - 8.0
		draw_line(Vector2(glint_x, top_left.y + 4), Vector2(glint_x - 14.0, top_left.y + CELL - 4), Color("ffffff", 0.28), 2.5, true)
	# Contorno de geada e cristalização nas margens
	for direction in FOUR_WAY:
		var neighbor: Vector2i = point + direction
		if _inside(neighbor) and grid[neighbor.y][neighbor.x] == TILE_WATER:
			continue
		var start := Vector2.ZERO
		var finish := Vector2.ZERO
		if direction == Vector2i.UP:
			start = top_left + Vector2(3, 2); finish = top_left + Vector2(CELL - 4, 2)
		elif direction == Vector2i.DOWN:
			start = top_left + Vector2(3, CELL - 3); finish = top_left + Vector2(CELL - 4, CELL - 3)
		elif direction == Vector2i.LEFT:
			start = top_left + Vector2(2, 3); finish = top_left + Vector2(2, CELL - 4)
		else:
			start = top_left + Vector2(CELL - 3, 3); finish = top_left + Vector2(CELL - 3, CELL - 4)
		draw_line(start, finish, glow, 2.0, true)


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
	var role: String = enemy.get("role", "hunter")
	var alert: bool = enemy.get("alert", _enemy_sees_player(enemy.pos))
	var size_scale := 1.35 if role == "warden" else 0.88 if role == "wisp" else 0.95 if role == "rusher" else 1.05 if role == "sentry" else 1.0
	var bob := sin(animation_clock * (5.5 if alert else 3.0) + center.x * 0.015) * (3.0 if role == "wisp" else 1.4)
	center.y += bob
	var color := Color("ff914d") if role == "rusher" else Color("ffb64d") if role == "sentry" else Color("c088ff") if role == "wisp" else Color("b84eff") if role == "warden" else Color("ff3e5e")
	var face: Vector2i = enemy.get("face", Vector2i(signi(player_position.x - enemy.pos.x), signi(player_position.y - enemy.pos.y)))
	var face_offset := Vector2(face) * (2.2 if alert else 0.9)
	var half_size := 15.5 * size_scale
	var shell_alpha := 0.85 if role == "wisp" else 1.0
	var glow := Color(color, 0.28 if alert else 0.10)
	
	# Sombra de chão dinâmica
	draw_circle(center + Vector2(0, 11 * size_scale), half_size * 1.05, Color("020611", 0.45))
	# Halo de alerta / emissivo
	draw_circle(center, half_size * (1.55 if alert else 1.25), glow)
	
	if role == "wisp":
		# Fantasma flutuante etéreo com cauda fluida
		var flame_wobble := sin(animation_clock * 8.0 + center.x) * 2.5
		var wisp_radius := half_size * 0.95
		draw_circle(center, wisp_radius * 1.15, Color(color, 0.25))
		draw_circle(center, wisp_radius, Color(color.lightened(0.2), 0.85))
		draw_circle(center + Vector2(0, -2), wisp_radius * 0.65, Color("ffffff", 0.75))
		# Cauda de plasma
		var tail := PackedVector2Array([
			center + Vector2(-wisp_radius * 0.6, 2),
			center + Vector2(wisp_radius * 0.6, 2),
			center + Vector2(flame_wobble, wisp_radius * 1.6 + 4)
		])
		draw_colored_polygon(tail, Color(color, 0.7))
		# Olhos místicos de Wisp
		var eye_col := Color("ffffff") if alert else Color("f5e8ff")
		draw_circle(center + Vector2(-4.5, -1) + face_offset * 0.7, 2.8, eye_col)
		draw_circle(center + Vector2(4.5, -1) + face_offset * 0.7, 2.8, eye_col)
		draw_circle(center + Vector2(-4.5, -1) + face_offset * 1.2, 1.4, Color("340a45"))
		draw_circle(center + Vector2(4.5, -1) + face_offset * 1.2, 1.4, Color("340a45"))
		return
	
	if role == "hunter":
		# Drone tático agressivo com armadura angular e cornos/antenas
		var shell := _chamfered_square_points(center, half_size, half_size * 0.28)
		draw_colored_polygon(shell, Color("1d0914"))
		var inner := _chamfered_square_points(center, half_size * 0.82, half_size * 0.22)
		draw_colored_polygon(inner, color)
		# Chifres/Antenas mecânicas superiores
		draw_line(center + Vector2(-half_size * 0.7, -half_size * 0.8), center + Vector2(-half_size * 1.0, -half_size * 1.3), color, 2.5, true)
		draw_line(center + Vector2(half_size * 0.7, -half_size * 0.8), center + Vector2(half_size * 1.0, -half_size * 1.3), color, 2.5, true)
		# Olhos angulares ferozes
		var eye_y := center.y - 1.5 + face_offset.y
		var le := Vector2(center.x - 5.0 + face_offset.x, eye_y)
		var re := Vector2(center.x + 5.0 + face_offset.x, eye_y)
		draw_line(le + Vector2(-3, -2), le + Vector2(3, 1), Color("ffffff"), 2.2, true)
		draw_line(re + Vector2(-3, 1), re + Vector2(3, -2), Color("ffffff"), 2.2, true)
		if alert:
			draw_circle(le, 1.6, Color("ffe085"))
			draw_circle(re, 1.6, Color("ffe085"))
		return
		
	if role == "sentry":
		# Sentinela blindada pesada com visor horizontal dourado
		var shell := _chamfered_square_points(center, half_size * 1.1, half_size * 0.15)
		draw_colored_polygon(shell, Color("201b0b"))
		var plate := _chamfered_square_points(center, half_size * 0.88, half_size * 0.12)
		draw_colored_polygon(plate, color.darkened(0.2))
		# Placas de ombro blindadas
		draw_rect(Rect2(center + Vector2(-half_size * 1.15, -4), Vector2(3, 8)), color, true)
		draw_rect(Rect2(center + Vector2(half_size * 1.15 - 3, -4), Vector2(3, 8)), color, true)
		# Visor scanner cilíndrico
		var visor_rect := Rect2(center + Vector2(-half_size * 0.65, -3) + face_offset, Vector2(half_size * 1.3, 6))
		draw_rect(visor_rect, Color("0b0c10"), true)
		var scan_pos := center.x + sin(animation_clock * 6.0) * (half_size * 0.45) + face_offset.x
		draw_circle(Vector2(scan_pos, center.y + face_offset.y), 2.8, Color("fff6bd"))
		draw_circle(Vector2(scan_pos, center.y + face_offset.y), 1.2, Color("ffffff"))
		return
		
	if role == "rusher":
		# Assassino pontiagudo aerodinâmico em lâmina
		var nose := center + Vector2(face.x, face.y) * (half_size * 1.25)
		var left_wing := center + Vector2(-face.y, face.x) * (half_size * 0.95) - Vector2(face.x, face.y) * (half_size * 0.6)
		var right_wing := center + Vector2(face.y, -face.x) * (half_size * 0.95) - Vector2(face.x, face.y) * (half_size * 0.6)
		var ship := PackedVector2Array([nose, left_wing, center - Vector2(face.x, face.y) * (half_size * 0.4), right_wing])
		draw_colored_polygon(ship, Color("291102"))
		var inner_ship := PackedVector2Array([
			nose - Vector2(face.x, face.y) * 2,
			left_wing + Vector2(face.x, face.y) * 3 + Vector2(face.y, -face.x) * 2,
			center - Vector2(face.x, face.y) * 3,
			right_wing + Vector2(face.x, face.y) * 3 - Vector2(face.y, -face.x) * 2
		])
		draw_colored_polygon(inner_ship, color)
		# Rastro de chamas/plasma traseiro
		var flame := center - Vector2(face.x, face.y) * (half_size * 0.8 + sin(animation_clock * 20.0) * 4.0)
		draw_line(center - Vector2(face.x, face.y) * (half_size * 0.4), flame, Color("ffe37a"), 3.0, true)
		# Visor vermelho afiado
		draw_circle(center + Vector2(face.x, face.y) * 3, 2.5, Color("ffffff"))
		return
		
	if role == "warden":
		# Boss colossal com anéis orbitais, espinhos e núcleo de fusão
		var shell := _chamfered_square_points(center, half_size, half_size * 0.35)
		draw_colored_polygon(shell, Color("1f0933"))
		var plate := _chamfered_square_points(center, half_size * 0.85, half_size * 0.28)
		draw_colored_polygon(plate, color.darkened(0.25))
		# Espinhos flutuantes / Spikes de Boss
		for s in 4:
			var angle := animation_clock * 1.5 + float(s) * TAU / 4.0
			var spike_pos := center + Vector2(cos(angle), sin(angle)) * (half_size * 1.4)
			draw_circle(spike_pos, 3.5, Color("ff7bf0"))
			draw_line(center, spike_pos, Color("df52ff", 0.4), 1.2, true)
		# Anel de contenção gravitacional
		draw_arc(center, half_size * 1.25, animation_clock * 3.0, animation_clock * 3.0 + TAU * 0.7, 24, Color("f1b5ff", 0.75), 2.0, true)
		# Núcleo pulsante no centro
		var core_pulse := 1.0 + sin(animation_clock * 8.0) * 0.25
		draw_circle(center, 6.0 * core_pulse, Color("ffffff"))
		draw_circle(center, 4.0 * core_pulse, Color("f48aff"))
		return
	
	# Fallback para outros tipos
	var shell := _chamfered_square_points(center, half_size, half_size * 0.20)
	draw_colored_polygon(shell, color.darkened(0.3))
	var face_points := _chamfered_square_points(center, half_size * 0.8, half_size * 0.18)
	draw_colored_polygon(face_points, color)
	draw_circle(center + Vector2(-4, -2) + face_offset, 2.5, Color("ffffff"))
	draw_circle(center + Vector2(4, -2) + face_offset, 2.5, Color("ffffff"))


func _chamfered_square_points(center: Vector2, half_size: float, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half_size + cut, -half_size), center + Vector2(half_size - cut, -half_size),
		center + Vector2(half_size, -half_size + cut), center + Vector2(half_size, half_size - cut),
		center + Vector2(half_size - cut, half_size), center + Vector2(-half_size + cut, half_size),
		center + Vector2(-half_size, half_size - cut), center + Vector2(-half_size, -half_size + cut),
	])


func _draw_player() -> void:
	if capture_popped and game_state in ["captured", "game_over"]:
		return
	var center := _player_visual_position()
	var frightened := _player_is_frightened()
	var size_scale := 1.0
	var stretch := Vector2.ONE
	var visibility := 1.0
	var movement := clampf(1.0 - player_anim, 0.0, 1.0)
	var travel := player_to - player_from
	var roll := 0.0
	if travel.length_squared() > 1.0:
		roll = movement * travel.length() / 17.0 * (1.0 if travel.x * travel.y <= 0.0 else -1.0)
	var hop := sin(movement * PI) * 4.0
	if game_state == "captured":
		var inflation := clampf(capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
		size_scale = 1.0 + 0.78 * smoothstep(0.0, 1.0, inflation)
		stretch = Vector2(1.0 + inflation * 0.04, 1.0 - inflation * 0.025)
		if inflation > 0.3 and int(capture_time * 26.0) % 2 == 0:
			visibility = 0.3
	else:
		var squash := sin(movement * PI)
		stretch = Vector2(1.0 + squash * 0.09, 1.0 - squash * 0.07)
		hop += sin(animation_clock * 7.0) * 0.8
	var shadow_color := Color("00040d", 0.36 * visibility)
	draw_set_transform(center + Vector2(0, 13.0), 0.0, Vector2(1.0 + movement * 0.08, 0.46))
	draw_circle(Vector2.ZERO, 12.5 * size_scale, shadow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if charges > 0:
		for i in mini(charges, 3):
			var hex_radius := (20.0 + i * 4.5 + sin(animation_clock * 4.0 + i) * 1.5) * size_scale
			var rot := animation_clock * (0.8 + i * 0.3)
			var hex_points := PackedVector2Array()
			for v in 6:
				var a := rot + float(v) * TAU / 6.0
				hex_points.append(center + Vector2(cos(a), sin(a)) * hex_radius)
			hex_points.append(hex_points[0])
			var hex_alpha := (0.55 - i * 0.12) * visibility
			draw_polyline(hex_points, Color("52f4ff", hex_alpha), 1.6 * size_scale, true)
			# Vértices de energia cibernética
			for v in 6:
				var a := rot + float(v) * TAU / 6.0
				draw_circle(center + Vector2(cos(a), sin(a)) * hex_radius, 1.8 * size_scale, Color("ffffff", hex_alpha * 1.2))
	var bob := sin(animation_clock * 8.5) * 1.0
	var shell_transform := center + Vector2(0, bob - hop)
	draw_set_transform(shell_transform, roll, stretch * size_scale)
	draw_circle(Vector2.ZERO, 17.2, Color("781c3b", visibility))
	draw_circle(Vector2(-0.3, -0.7), 15.7, Color("ed4050", visibility))
	draw_circle(Vector2(-1.7, 2.1), 12.6, Color("d82c49", 0.92 * visibility))
	draw_arc(Vector2(-1.0, 0.0), 14.2, 0.20, 2.55, 28, Color("ff9a69", 0.84 * visibility), 2.1, true)
	draw_arc(Vector2.ZERO, 17.1, 0.0, TAU, 40, Color("ffbd85", 0.52 * visibility), 1.1, true)
	draw_circle(Vector2(-5.8, -7.0), 4.5, Color("fff1cb", 0.42 * visibility))
	draw_circle(Vector2(-7.3, -8.3), 1.8, Color("ffffff", 0.76 * visibility))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var eye_offset := Vector2(facing) * (2.0 * size_scale)
	var eye_y := -2.6 - hop + bob
	var eye_radius := 4.0 if frightened else 3.3
	var eye_left := center + Vector2(-5.1, eye_y) * size_scale + eye_offset
	var eye_right := center + Vector2(5.1, eye_y) * size_scale + eye_offset
	var face_visibility := visibility
	var sclera := Color("fff5e6", face_visibility)
	var pupil := Color("35203a", face_visibility)
	draw_circle(eye_left, eye_radius * size_scale, sclera)
	draw_circle(eye_right, eye_radius * size_scale, sclera)
	var gaze := Vector2(facing) * (1.05 if frightened else 0.72) * size_scale
	draw_circle(eye_left + gaze, (1.75 if frightened else 1.45) * size_scale, pupil)
	draw_circle(eye_right + gaze, (1.75 if frightened else 1.45) * size_scale, pupil)
	if frightened:
		draw_line(eye_left + Vector2(-2.0, -5.6) * size_scale, eye_left + Vector2(1.0, -6.4) * size_scale, Color("72253f", visibility), 1.5 * size_scale, true)
		draw_line(eye_right + Vector2(-1.0, -6.4) * size_scale, eye_right + Vector2(2.0, -5.6) * size_scale, Color("72253f", visibility), 1.5 * size_scale, true)
		draw_circle(center + Vector2(0.0, 6.0 - hop + bob) * size_scale, (2.3 + sin(animation_clock * 10.0) * 0.35) * size_scale, Color("70243f", visibility))
		draw_circle(center + Vector2(0, 5.5 - hop + bob) * size_scale, 0.8 * size_scale, Color("ffb184", visibility))
	else:
		draw_arc(center + Vector2(0, 4.5 - hop + bob) * size_scale, 3.0 * size_scale, 0.15, PI - 0.15, 16, Color("78243e", visibility), 1.3 * size_scale, true)


func _draw_blood_puddle() -> void:
	if not capture_puddle_active or capture_puddle_points.size() < 3:
		return
	# Sombra profunda sob a poça
	var shadow_outline := PackedVector2Array()
	for point in capture_puddle_points:
		shadow_outline.append(point + Vector2(0, 3.5))
	draw_colored_polygon(shadow_outline, Color("000000", 0.45))
	
	# Camada viscosa base
	draw_colored_polygon(capture_puddle_points, Color("590519", 0.98))
	
	# Camada interna arterial
	var inset := PackedVector2Array()
	for point in capture_puddle_points:
		inset.append(capture_origin + (point - capture_origin) * 0.74)
	draw_colored_polygon(inset, Color("a10b2a", 0.95))
	
	# Centro líquido reflexivo
	var center_inset := PackedVector2Array()
	for point in capture_puddle_points:
		center_inset.append(capture_origin + (point - capture_origin) * 0.48)
	draw_colored_polygon(center_inset, Color("c91638", 0.90))
	
	# Reflexos especulares de líquido fresco
	var spec1 := capture_origin + Vector2(-CELL * 0.35, -CELL * 0.28)
	draw_circle(spec1, 4.2, Color("ffffff", 0.65))
	draw_circle(spec1 + Vector2(7, 2), 2.2, Color("ffffff", 0.45))
	
	# Contorno neon arterial pulsante
	var outline := capture_puddle_points.duplicate()
	outline.append(capture_puddle_points[0])
	draw_polyline(outline, Color("ff365c", 0.88), 2.4, true)
	
	# Gotículas e respingos periféricos com mini-brilho
	for splat in capture_splats:
		draw_circle(splat.pos + Vector2(0, 1.5), splat.radius, Color("000000", 0.35))
		draw_circle(splat.pos, splat.radius, Color("ab0c2e", 0.96))
		draw_circle(splat.pos + Vector2(-splat.radius * 0.25, -splat.radius * 0.25), maxf(1.0, splat.radius * 0.35), Color("ff6379", 0.85))


func _player_is_frightened() -> bool:
	for enemy in enemies:
		if _manhattan(enemy.pos, player_position) <= 4 and _enemy_sees_player(enemy.pos):
			return true
	return false


func _draw_particles() -> void:
	for particle in particles:
		var strength: float = clampf(particle.life / particle.max_life, 0.0, 1.0)
		var color: Color = particle.color
		color.a *= strength
		var kind: String = particle.get("kind", "")
		
		if kind == "shockwave":
			var progress := 1.0 - strength
			var cur_radius: float = lerpf(particle.radius, particle.max_radius, progress)
			draw_arc(particle.pos, cur_radius, 0.0, TAU, 36, Color(color, strength * 0.85), 3.5 * strength, true)
			draw_arc(particle.pos, cur_radius * 0.88, 0.0, TAU, 30, Color("ffffff", strength * 0.65), 1.8 * strength, true)
			continue
			
		var radius: float = particle.size * strength
		if kind == "blood":
			var velocity: Vector2 = particle.velocity
			if velocity.length_squared() > 4.0:
				draw_line(particle.pos, particle.pos - velocity.normalized() * radius * 2.5, color, maxf(1.2, radius * 0.75), true)
			draw_circle(particle.pos, radius, color)
			draw_circle(particle.pos + Vector2(-radius * 0.25, -radius * 0.25), maxf(0.8, radius * 0.3), Color("ffffff", 0.6 * strength))
		else:
			draw_circle(particle.pos, radius, color)
