extends SceneTree

# Stress generation and play complete turns with two simple bots.
# Example: godot --headless --path . --script res://tests/sweep.gd -- floors=1-30 seeds=3 bots=1
const GameScript = preload("res://game.gd")

var problems: Dictionary = {}
var generation_ms: Dictionary = {}
var floors_from := 1
var floors_to := 40
var seed_count := 3
var run_bots := true
var bot_turns := 0


func _initialize() -> void:
	call_deferred("_run_sweep")


func _run_sweep() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("floors="):
			var parts := arg.trim_prefix("floors=").split("-")
			floors_from = maxi(1, int(parts[0]))
			floors_to = maxi(floors_from, int(parts[1])) if parts.size() > 1 else floors_from
		elif arg.begins_with("seeds="):
			seed_count = maxi(1, int(arg.trim_prefix("seeds=")))
		elif arg == "bots=0":
			run_bots = false
	var game = GameScript.new()
	# Do not read or modify the player's real profile while testing.
	game.persistence_enabled = false
	root.add_child(game)
	game.audio.effects_enabled = false
	_sweep_generation(game)
	if run_bots:
		_sweep_bots(game)
	_report()
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if problems.is_empty() else 1)


func _flag(kind: String, detail: String) -> void:
	if not problems.has(kind):
		problems[kind] = {"count": 0, "examples": []}
	problems[kind].count += 1
	if problems[kind].examples.size() < 3:
		problems[kind].examples.append(detail)


func _sweep_generation(game: Node) -> void:
	for floor_number in range(floors_from, floors_to + 1):
		for seed_index in seed_count:
			game.active_seed = 1000 + seed_index * 7717 + floor_number * 31
			var start := Time.get_ticks_usec()
			game.generate_floor(floor_number)
			var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
			generation_ms[floor_number] = maxf(float(generation_ms.get(floor_number, 0.0)), elapsed)
			var tag := "andar %d seed %d" % [floor_number, game.active_seed]
			_check_floor(game, tag)
			if seed_index == 0 and floor_number in [1, 5, 30, 100, 200]:
				var before := {
					"grid": game.grid.duplicate(true), "coins": game.coins.duplicate(),
					"enemies": game.enemies.duplicate(true), "switches": game.switches.duplicate(true),
					"powerups": game.powerups.duplicate(true), "traps": game.traps.duplicate(true),
					"challenge": game.challenge_kind, "par": game.challenge_par,
				}
				game.generate_floor(floor_number)
				if before.grid != game.grid or before.coins != game.coins or before.enemies != game.enemies or before.switches != game.switches or before.powerups != game.powerups or before.traps != game.traps or before.challenge != game.challenge_kind or before.par != game.challenge_par:
					_flag("seed_nao_reproduzivel", tag)


func _mark(seen: Dictionary, point: Vector2i, label: String, tag: String) -> void:
	if seen.has(point):
		_flag("sobreposicao", "%s: %s sobre %s em %s" % [tag, label, seen[point], str(point)])
	seen[point] = label


func _check_floor(game: Node, tag: String) -> void:
	var world: Vector2i = game.world_size
	if game.grid.size() != world.y or game.grid.is_empty() or game.grid[0].size() != world.x:
		_flag("dimensao_do_mapa", tag)
		return
	if not game._is_floor(game.player_position) or not game._is_floor(game.portal_position):
		_flag("inicio_ou_portal_fora_do_chao", tag)
	var reachable: Dictionary = {}
	for point in game._reachable_cells(game.player_position):
		reachable[point] = true
	if not reachable.has(game.portal_position):
		_flag("portal_inalcancavel", tag)
	if game.generation_report.contains("fallback"):
		_flag("gerador_usou_fallback", tag + " " + game.generation_report)
	var seen: Dictionary = {}
	_mark(seen, game.player_position, "jogador", tag)
	_mark(seen, game.portal_position, "portal", tag)
	var groups := {"moeda": game.coins, "escudo": game.shields, "demolicao": game.breakers}
	for name in groups:
		for point in groups[name]:
			if not reachable.has(point):
				_flag("item_inalcancavel", "%s: %s em %s" % [tag, name, str(point)])
			_mark(seen, point, name, tag)
	if game.powerups.size() != 1 or game.powerups[0].kind != game.POWERUP_TYPES[posmod(game.floor_number - 1, game.POWERUP_TYPES.size())]:
		_flag("poder_em_falta", tag)
	for item in game.powerups:
		if not reachable.has(item.pos):
			_flag("poder_inalcancavel", tag)
		_mark(seen, item.pos, "poder", tag)
	if game.floor_number % 5 == 3:
		if game.objective_type != "puzzle" or not game.enemies.is_empty() or not game.traps.is_empty() or game.switches.size() != 3 or game.portal_open:
			_flag("puzzle_invalido", tag)
		elif int(game._plan_puzzle_route().length) < 0:
			_flag("puzzle_sem_solucao", tag)
		else:
			for i in 3:
				if int(game.switches[i].get("order", -1)) != i:
					_flag("ordem_de_puzzle_invalida", tag)
	for item in game.switches:
		if not reachable.has(item.pos):
			_flag("interruptor_inalcancavel", tag)
		_mark(seen, item.pos, "interruptor", tag)
	for trap in game.traps:
		if not reachable.has(trap.pos):
			_flag("armadilha_inalcancavel", tag)
		_mark(seen, trap.pos, "armadilha", tag)
	for enemy in game.enemies:
		if not reachable.has(enemy.pos):
			_flag("inimigo_inalcancavel", tag)
		if game._manhattan(enemy.pos, game.player_position) < 5:
			_flag("inimigo_perto_do_inicio", tag)
		_mark(seen, enemy.pos, "inimigo", tag)
	if game.coins.size() < 6:
		_flag("poucas_moedas", "%s: %d" % [tag, game.coins.size()])
	var route: int = game._estimate_route_length()
	if route < 0 or game.challenge_par < route:
		_flag("limite_de_desafio_invalido", "%s: limite %d rota %d" % [tag, game.challenge_par, route])
	var wardens := 0
	var enemy_roles: Array[String] = []
	for enemy in game.enemies:
		var role: String = enemy.get("role", "")
		enemy_roles.append(role)
		if role == "warden":
			wardens += 1
			if int(enemy.get("hp", 0)) < 2:
				_flag("mini_chefe_fragil", tag)
	if game.floor_number % 5 == 4 and wardens != 1:
		_flag("mini_chefe_em_falta", tag)
	elif game.floor_number % 5 != 4 and wardens > 0:
		_flag("mini_chefe_em_andar_errado", tag)
	if game.floor_number >= 7 and game.floor_number % 5 != 3 and (not enemy_roles.has("patrol") or not enemy_roles.has("mirror")):
		_flag("novos_inimigos_em_falta", tag)
	var boss: Dictionary = game.get_active_boss()
	if game.floor_number % 5 == 0:
		if boss.is_empty() or int(boss.get("hp", 0)) < 2:
			_flag("chefe_em_falta", tag)
		else:
			var index := posmod(game.floor_number / 5 - 1, game.BOSS_TYPES.size())
			if boss.get("role", "") != "chess_boss" or boss.get("boss_kind", "") != game.BOSS_TYPES[index].id:
				_flag("tipo_de_chefe_incorreto", tag)
	elif not boss.is_empty():
		_flag("chefe_em_andar_errado", tag)


func _sweep_bots(game: Node) -> void:
	var rng := RandomNumberGenerator.new()
	for floor_number in [1, 2, 3, 4, 5, 6, 8, 9, 10, 13, 15, 18, 20, 23, 25, 28, 30, 33, 35, 38, 40, 100, 200]:
		if floor_number < floors_from or floor_number > floors_to:
			continue
		for seed_index in 2:
			for style in ["rota", "aleatorio", "explorador"]:
				# An invulnerable explorer verifies the whole objective can be completed;
				# the other bots still exercise normal damage and capture.
				if style == "explorador" and seed_index > 0:
					continue
				game.dev_god_mode = style == "explorador"
				game.active_seed = 555 + seed_index * 991 + floor_number
				game.floor_history.clear()
				game.total_coins = 0
				game.charges = 2 if seed_index == 0 else 0
				game.breach_charges = 1
				game._restore_power_state({})
				game.generate_floor(floor_number)
				game.game_state = "playing"
				rng.seed = game.active_seed + (7 if style == "aleatorio" else 0)
				var turns := 0
				var turn_limit := maxi(260, game._estimate_route_length() * 2 + 80)
				var tag := "bot %s andar %d seed %d" % [style, floor_number, game.active_seed]
				while turns < turn_limit and game.game_state == "playing":
					turns += 1
					if style == "aleatorio":
						var action := rng.randi_range(0, 12)
						var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
						var direction: Vector2i = dirs[rng.randi_range(0, 3)]
						game.facing = direction
						if action == 8:
							game.try_jump()
						elif action == 9:
							game.try_break_wall()
						elif action == 10:
							game.wait_turn()
						elif action == 11:
							game.try_blink()
						else:
							game.try_move(direction.x, direction.y)
					else:
						var step := Vector2i.ZERO
						if game.objective_type == "puzzle":
							step = game._plan_puzzle_route().step
						else:
							var target: Vector2i = game.portal_position
							if not game.portal_open:
								var sw: Vector2i = game._nearest_inactive_switch(game.player_position)
								if sw != Vector2i(-1, -1):
									target = sw
							step = _next_step(game, game.player_position, target)
						if step == Vector2i.ZERO:
							game.wait_turn()
						else:
							game.try_move(step.x, step.y)
					if game.game_state == "captured":
						game._update_capture_sequence(game.CAPTURE_END_TIME + 0.1)
				if style != "aleatorio" and game.game_state == "playing" and turns >= turn_limit:
					_flag("bot_de_rota_preso", tag)
				if style == "explorador" and game.game_state not in ["floor_clear", "rescued"]:
					_flag("bot_nao_concluiu_objetivo", tag)
				bot_turns += turns
	game.dev_god_mode = false
	game.game_state = "title"


func _next_step(game: Node, from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var previous := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		if point == to:
			break
		for direction in game.FOUR_WAY:
			var next: Vector2i = point + direction
			if game._is_floor(next) and not previous.has(next):
				previous[next] = point
				queue.append(next)
	if not previous.has(to):
		return Vector2i.ZERO
	var current: Vector2i = to
	while previous[current] != from:
		current = previous[current]
	return current - from


func _report() -> void:
	print("--- tempo maximo de geracao por andar (ms) ---")
	var keys: Array = generation_ms.keys()
	keys.sort()
	var line := ""
	for key in keys:
		line += "%d:%d  " % [key, int(generation_ms[key])]
	print(line)
	print("Bot actions: %d" % bot_turns)
	if problems.is_empty():
		print("SWEEP_PASS")
		return
	print("SWEEP_PROBLEMS: %d tipo(s)" % problems.size())
	for kind in problems:
		print("  [%s] x%d" % [kind, problems[kind].count])
		for example in problems[kind].examples:
			print("      ", example)
