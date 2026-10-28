extends Node2D

const COLS := 11
const ROWS := 9
const CELL := 58.0
const BOARD_ORIGIN := Vector2(231, 153)
const FOUR_WAY := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const CHALLENGES := [
	"Desafio: atravesse sem usar salto",
	"Desafio: termine sem perder escudo",
	"Desafio: alcance o portal em ate 14 passos",
]

var grid: Array = []
var player_position := Vector2i.ZERO
var portal_position := Vector2i.ZERO
var enemies: Array[Dictionary] = []
var shields: Array[Vector2i] = []
var coins: Array[Vector2i] = []
var charges := 0
var total_coins := 0
var floor_number := 1
var moves_this_floor := 0
var jumps_this_floor := 0
var hits_this_floor := 0
var coins_this_floor := 0
var game_state := "ready"
var challenge_index := 0
var challenge_complete := false
var last_notice := ""
var notice_timer := 0.0
var floor_history: Array[int] = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	new_game()


func new_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		seed(seed_value)
	else:
		randomize()
	floor_history.clear()
	floor_number = 1
	charges = 0
	total_coins = 0
	game_state = "playing"
	generate_floor(1)


func generate_floor(number: int) -> void:
	floor_number = number
	var attempts := 0
	var start := Vector2i(0, ROWS / 2)
	var exit := Vector2i(COLS - 1, randi_range(0, ROWS - 1))
	while attempts < 100:
		attempts += 1
		grid.clear()
		for y in ROWS:
			var row: Array[int] = []
			for x in COLS:
				row.append(1 if randf() < 0.16 else 0)
			grid.append(row)
		grid[start.y][start.x] = 0
		grid[exit.y][exit.x] = 0
		if _reachable(start, exit) and _free_sides(start) >= 2 and _free_sides(exit) >= 1:
			break
	player_position = start
	portal_position = exit
	enemies.clear()
	shields.clear()
	coins.clear()
	var enemy_count := mini(1 + ceili(float(number) / 2.0), 5)
	var occupied: Array[Vector2i] = [player_position, portal_position]
	for i in enemy_count:
		var enemy_spot := _random_empty(occupied)
		if enemy_spot.distance_to(player_position) >= 3:
			enemies.append({"pos": enemy_spot, "next": enemy_spot})
			occupied.append(enemy_spot)
	var shield_count := randi_range(1, 3)
	for i in shield_count:
		var shield_spot := _random_empty(occupied)
		shields.append(shield_spot)
		occupied.append(shield_spot)
	for i in 7:
		var coin_spot := _random_empty(occupied)
		coins.append(coin_spot)
		occupied.append(coin_spot)
	moves_this_floor = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	challenge_index = randi_range(0, CHALLENGES.size() - 1)
	challenge_complete = false
	last_notice = CHALLENGES[challenge_index]
	notice_timer = 3.0
	_update_enemy_intents()
	queue_redraw()


func _reachable(start: Vector2i, goal: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	while not queue.is_empty():
		var point: Vector2i = queue.pop_front()
		if point == goal:
			return true
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _inside(next) and grid[next.y][next.x] == 0 and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return false


func _free_sides(point: Vector2i) -> int:
	var count := 0
	for direction in FOUR_WAY:
		var next: Vector2i = point + direction
		if _inside(next) and grid[next.y][next.x] == 0:
			count += 1
	return count


func _random_empty(occupied: Array[Vector2i]) -> Vector2i:
	for attempt in 500:
		var point := Vector2i(randi_range(0, COLS - 1), randi_range(0, ROWS - 1))
		if grid[point.y][point.x] == 0 and _free_sides(point) > 0 and not occupied.has(point):
			return point
	return Vector2i(1, 1)


func _inside(point: Vector2i) -> bool:
	return point.x >= 0 and point.x < COLS and point.y >= 0 and point.y < ROWS


func _update_enemy_intents() -> void:
	var reserved: Array[Vector2i] = []
	for enemy in enemies:
		var from: Vector2i = enemy.pos
		var best := from
		var best_distance := from.distance_to(player_position)
		for direction in FOUR_WAY:
			var candidate: Vector2i = from + direction
			if not _inside(candidate) or grid[candidate.y][candidate.x] == 1:
				continue
			if _enemy_at(candidate, enemy) or reserved.has(candidate):
				continue
			var distance: int = abs(candidate.x - player_position.x) + abs(candidate.y - player_position.y)
			if distance < best_distance:
				best = candidate
				best_distance = distance
		enemy.next = best
		if best != from:
			reserved.append(best)


func _enemy_at(point: Vector2i, except_enemy: Dictionary = {}) -> bool:
	for enemy in enemies:
		if enemy != except_enemy and enemy.pos == point:
			return true
	return false


func try_move(dx: int, dy: int) -> void:
	if game_state != "playing":
		return
	facing = Vector2i(dx, dy)
	var next := player_position + Vector2i(dx, dy)
	if _inside(next) and grid[next.y][next.x] == 0:
		player_position = next
		moves_this_floor += 1
	_take_turn()


func try_jump() -> void:
	if game_state != "playing" or charges <= 0:
		last_notice = "Encontre um escudo para saltar"
		notice_timer = 1.8
		queue_redraw()
		return
	var direction := Vector2i.RIGHT
	if enemies.size() > 0:
		# The jump follows the last movement direction, kept in facing.
		direction = facing
	var middle := player_position + direction
	var landing := player_position + direction * 2
	if _inside(middle) and _inside(landing) and grid[middle.y][middle.x] == 0 and grid[landing.y][landing.x] == 0:
		charges -= 1
		jumps_this_floor += 1
		moves_this_floor += 1
		player_position = landing
		_take_turn()
	else:
		last_notice = "O salto precisa de dois espacos livres"
		notice_timer = 1.8
		queue_redraw()


var facing := Vector2i.RIGHT


func _take_turn() -> void:
	_collect_pickups()
	var intended: Array[Vector2i] = []
	for enemy in enemies:
		intended.append(enemy.next)
	for i in enemies.size():
		enemies[i].pos = intended[i]
	_update_enemy_intents()
	_check_enemy_collision()
	_check_portal()
	queue_redraw()


func _collect_pickups() -> void:
	if coins.has(player_position):
		coins.erase(player_position)
		coins_this_floor += 1
		total_coins += 1
	if shields.has(player_position):
		shields.erase(player_position)
		charges += 1
		last_notice = "Escudo recolhido: agora voce pode saltar ou se proteger"
		notice_timer = 2.4


func _check_enemy_collision() -> void:
	if not _enemy_at(player_position):
		return
	if charges > 0:
		charges -= 1
		hits_this_floor += 1
		last_notice = "O escudo absorveu o ataque. Planeje o proximo passo"
		notice_timer = 2.4
	else:
		game_state = "game_over"
		last_notice = "Voce foi alcancado. Pressione R para tentar de novo"
		notice_timer = 999.0


func _check_portal() -> void:
	if player_position != portal_position or game_state != "playing":
		return
	var challenge_ok := false
	match challenge_index:
		0: challenge_ok = jumps_this_floor == 0
		1: challenge_ok = hits_this_floor == 0
		2: challenge_ok = moves_this_floor <= 14
	if challenge_ok and not challenge_complete:
		challenge_complete = true
		total_coins += 5
	floor_history.append(_stars_for_floor())
	if floor_number >= 5:
		game_state = "rescued"
		last_notice = "Voce encontrou Lia. Juntos, voces deixam as ruinas. Pressione R para jogar de novo"
		notice_timer = 999.0
	else:
		game_state = "floor_clear"
		last_notice = "Andar %d concluido. Pressione Enter para avancar" % floor_number
		notice_timer = 999.0


func advance_floor() -> void:
	if game_state == "floor_clear":
		generate_floor(floor_number + 1)
		game_state = "playing"


func _stars_for_floor() -> int:
	var fraction := float(coins_this_floor) / 7.0
	if fraction >= 1.0: return 5
	if fraction >= 0.75: return 4
	if fraction >= 0.5: return 3
	if fraction >= 0.25: return 2
	return 1


func _process(delta: float) -> void:
	if notice_timer > 0.0 and notice_timer < 900.0:
		notice_timer = maxf(0.0, notice_timer - delta)
		if notice_timer == 0.0:
			last_notice = ""
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_W: facing = Vector2i.UP; try_move(0, -1)
		KEY_DOWN, KEY_S: facing = Vector2i.DOWN; try_move(0, 1)
		KEY_LEFT, KEY_A: facing = Vector2i.LEFT; try_move(-1, 0)
		KEY_RIGHT, KEY_D: facing = Vector2i.RIGHT; try_move(1, 0)
		KEY_SPACE: try_jump()
		KEY_ENTER, KEY_KP_ENTER: advance_floor()
		KEY_R: new_game()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1100, 760)), Color("090d1b"))
	draw_rect(Rect2(Vector2(0, 0), Vector2(1100, 112)), Color("111a31"))
	draw_string(font, Vector2(44, 51), "COME TO ME", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("eaf7ff"))
	draw_string(font, Vector2(46, 79), "NEON RUINS  /  RESGATE TATICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("64e6f5"))
	draw_string(font, Vector2(640, 52), "ANDAR %d     MOEDAS %d     ESCUDOS %d" % [floor_number, total_coins, charges], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d7deef"))
	draw_string(font, Vector2(640, 80), "Objetivo: encontre o portal e chegue ate Lia", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aab6cf"))
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(10, 10), Vector2(COLS * CELL + 20, ROWS * CELL + 20)), Color("131a2e"))
	for y in ROWS:
		for x in COLS:
			var rect := Rect2(BOARD_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL - 2, CELL - 2))
			var wall: bool = grid.size() > y and grid[y][x] == 1
			draw_rect(rect, Color("293754") if wall else (Color("151d32") if (x + y) % 2 == 0 else Color("11192b")))
	for coin in coins:
		var center := _center(coin)
		draw_circle(center, 8.0, Color("ffd15c"))
		draw_circle(center, 3.0, Color("fff1b7"))
	for shield in shields:
		var center := _center(shield)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(11, -5), center + Vector2(8, 9), center + Vector2(0, 14), center + Vector2(-8, 9), center + Vector2(-11, -5)]), Color("50e6f2"))
	if _inside(portal_position):
		var portal_rect := Rect2(BOARD_ORIGIN + Vector2(portal_position.x * CELL + 11, portal_position.y * CELL + 11), Vector2(34, 34))
		draw_rect(portal_rect, Color("bd75ff"))
		draw_rect(portal_rect.grow(-7), Color("301b54"))
	for enemy in enemies:
		var center := _center(enemy.pos)
		var next: Vector2i = enemy.next
		if next != enemy.pos:
			var end := _center(next)
			draw_line(center, end, Color("ff6179", 0.65), 3.0, true)
			draw_circle(end, 3.0, Color("ff6179"))
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color("ff526d"))
		draw_circle(center, 4.0, Color("301620"))
	var player_center := _center(player_position)
	draw_circle(player_center, 17.0, Color("6bf4ff", 0.23))
	draw_circle(player_center, 11.0, Color("78f4ff"))
	draw_circle(player_center + Vector2(3, -3), 3.5, Color.WHITE)
	if last_notice != "" and notice_timer > 0.0:
		draw_rect(Rect2(Vector2(190, 694), Vector2(720, 38)), Color("202a43"))
		draw_string(font, Vector2(207, 719), last_notice, HORIZONTAL_ALIGNMENT_LEFT, 690, 15, Color("f2f5ff"))
	else:
		draw_string(font, Vector2(231, 706), "WASD/Setas: mover  |  Espaco: saltar  |  R: reiniciar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9caac3"))
	if game_state == "floor_clear":
		_draw_overlay("ANDAR CONCLUIDO", "As pistas dos inimigos aparecem antes de cada turno. Enter para continuar")
	elif game_state == "rescued":
		_draw_overlay("LIA ESTA AQUI", "Voce atravessou cinco andares e encontrou sua amada. R para jogar de novo")
	elif game_state == "game_over":
		_draw_overlay("FIM DA JORNADA", "Sem escudos, um inimigo encerrou a tentativa. R para recomecar")


func _center(point: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(point.x * CELL + CELL / 2.0, point.y * CELL + CELL / 2.0)


func _draw_overlay(title: String, subtitle: String) -> void:
	draw_rect(Rect2(Vector2(245, 300), Vector2(610, 140)), Color("0b1020", 0.94))
	draw_string(font, Vector2(285, 354), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("7cf2ff"))
	draw_string(font, Vector2(285, 391), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 540, 15, Color("e5ebfa"))
