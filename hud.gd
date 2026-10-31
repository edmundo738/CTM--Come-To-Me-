extends Control

const MenuBackdrop = preload("res://assets/menu_background.png")

var game: Node
var font: Font
var buttons: Array[Dictionary] = []
var pointer := Vector2(-1000, -1000)


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	pointer = get_local_mouse_position()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	for index in range(buttons.size() - 1, -1, -1):
		var button: Dictionary = buttons[index]
		if button.rect.has_point(event.position):
			accept_event()
			game.handle_hud_action(button.action)
			return


func _draw() -> void:
	if game == null:
		return
	buttons.clear()
	var screen := size
	match game.game_state:
		"title":
			_draw_title(screen)
			return
		"level_select":
			_draw_level_select(screen)
			return
		"paused":
			_draw_header(screen)
			_draw_footer(screen)
			_draw_pause(screen)
			return
		"playing", "floor_clear", "rescued", "captured", "game_over":
			_draw_header(screen)
			_draw_footer(screen)
	if game.game_state == "floor_clear":
		_draw_result(screen, false)
	elif game.game_state == "rescued":
		_draw_result(screen, true)
	elif game.game_state == "game_over":
		_draw_game_over(screen)
	if game.flash_time > 0.0:
		var alpha: float = 0.16 * minf(1.0, game.flash_time / 0.14)
		draw_rect(Rect2(Vector2.ZERO, screen), Color(game.flash_color, alpha))


func _draw_header(screen: Vector2) -> void:
	# ── Fundo translúcido do header ──────────────────────────────────────────────
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 74)), Color("06091a", 0.93))
	# Linha neon inferior do header
	draw_rect(Rect2(Vector2(0, 72), Vector2(screen.x, 2)), Color("b060ff", 0.7))
	draw_rect(Rect2(Vector2(0, 73), Vector2(screen.x, 1)), Color("e0a0ff", 0.25))
	
	# ── LOGO top-left: Diamante Neon + COME TO ME / NEON RUINS ───────────────────
	var logo_cx := 22.0
	var logo_cy := 36.0
	# Diamante (dois triângulos)
	draw_colored_polygon(PackedVector2Array([
		Vector2(logo_cx, logo_cy - 12), Vector2(logo_cx + 9, logo_cy), Vector2(logo_cx, logo_cy + 12), Vector2(logo_cx - 9, logo_cy)
	]), Color("c060ff", 0.9))
	draw_polyline(PackedVector2Array([
		Vector2(logo_cx, logo_cy - 12), Vector2(logo_cx + 9, logo_cy), Vector2(logo_cx, logo_cy + 12), Vector2(logo_cx - 9, logo_cy), Vector2(logo_cx, logo_cy - 12)
	]), Color("eeb0ff"), 1.5, true)
	draw_circle(Vector2(logo_cx, logo_cy), 3.5, Color("ffffff", 0.9))
	
	# Texto principal
	draw_string(font, Vector2(38, 30), "COME TO ME", HORIZONTAL_ALIGNMENT_LEFT, 180, 15, Color("f0e8ff"))
	draw_string(font, Vector2(38, 49), "NEON RUINS", HORIZONTAL_ALIGNMENT_LEFT, 180, 10, Color("c060ff"))
	# Subtítulo: andar e bioma
	draw_string(font, Vector2(38, 66), "ANDAR %02d  /  %s" % [game.floor_number, game.get_floor_name(game.floor_number)], HORIZONTAL_ALIGNMENT_LEFT, 240, 9, Color("9060d0"))
	
	# ── OBJETIVO (centro) ─────────────────────────────────────────────────────────
	var obj_x := 300.0
	var obj_w := maxf(200.0, screen.x * 0.3)
	# Caixa de objetivo chanfrada
	var obj_rect := Rect2(obj_x - 8, 8, obj_w + 16, 58)
	draw_rect(obj_rect, Color("08061a", 0.85), true)
	draw_rect(Rect2(obj_x - 8, 8, obj_w + 16, 2), Color("5030a0", 0.8), true)
	draw_string(font, Vector2(obj_x, 26), "OBJETIVO", HORIZONTAL_ALIGNMENT_LEFT, obj_w, 9, Color("7050c0"))
	draw_string(font, Vector2(obj_x, 47), game.get_objective_text(), HORIZONTAL_ALIGNMENT_LEFT, obj_w, 11, Color("d0b0ff"))
	
	# ── STATS top-right: Shield | Coin | Switch | Key ─────────────────────────────
	var chip_w := 70.0
	var chip_h := 40.0
	var chip_gap := 4.0
	var chip_start_x := screen.x - (chip_w + chip_gap) * 4 - 120.0
	_draw_stat_chip(Rect2(chip_start_x, 16, chip_w, chip_h), "shield", "%d" % game.charges, Color("8cf4ff"))
	_draw_stat_chip(Rect2(chip_start_x + chip_w + chip_gap, 16, chip_w, chip_h), "coin", "%03d" % game.total_coins, Color("ffe17a"))
	var sw_val := "%d/%d" % [game._active_switches(), game.switches.size()] if game.switches.size() > 0 else "--"
	_draw_stat_chip(Rect2(chip_start_x + (chip_w + chip_gap) * 2.0, 16, chip_w, chip_h), "switch", sw_val, Color("b9f39c"))
	_draw_stat_chip(Rect2(chip_start_x + (chip_w + chip_gap) * 3.0, 16, chip_w, chip_h), "breaker", "%d" % game.breach_charges, Color("ffc58c"))
	
	# ── MINI-MAP top-right corner ──────────────────────────────────────────────────
	var map_size := 96.0
	var map_x := screen.x - map_size - 10.0
	var map_y := 8.0
	_draw_minimap(Rect2(map_x, map_y, map_size, map_size))


func _draw_minimap(rect: Rect2) -> void:
	# Fundo do mini-mapa
	draw_rect(rect.grow(2), Color("c060ff", 0.25), true)
	draw_rect(rect, Color("05030f", 0.95), true)
	draw_rect(rect, Color("8040c0", 0.6), false, 1.5)
	
	if game.world_size == Vector2i.ZERO:
		return
	
	# Escala para caber na caixa
	var scale_x := rect.size.x / float(game.world_size.x)
	var scale_y := rect.size.y / float(game.world_size.y)
	
	# Desenhar salas como retângulos de cor
	for r in game.rooms:
		var rx := rect.position.x + float(r.rect.position.x) * scale_x
		var ry := rect.position.y + float(r.rect.position.y) * scale_y
		var rw := float(r.rect.size.x) * scale_x
		var rh := float(r.rect.size.y) * scale_y
		draw_rect(Rect2(rx, ry, rw, rh), Color("2a1850", 0.9), true)
		draw_rect(Rect2(rx, ry, rw, rh), Color("6040a0", 0.5), false, 1.0)
	
	# Linhas de ligação entre salas (corredor graph)
	for edge in game.room_graph_edges:
		var ra: Dictionary = game.rooms[edge.from]
		var rb: Dictionary = game.rooms[edge.to]
		var ca := rect.position + Vector2(float(ra.center.x) * scale_x, float(ra.center.y) * scale_y)
		var cb := rect.position + Vector2(float(rb.center.x) * scale_x, float(rb.center.y) * scale_y)
		draw_line(ca, cb, Color("4020a0", 0.6), 1.0, true)
	
	# Portal (ponto vermelho/magenta)
	var portal_px := rect.position + Vector2(float(game.portal_position.x) * scale_x, float(game.portal_position.y) * scale_y)
	draw_circle(portal_px, 3.5, Color("ff3090"))
	draw_circle(portal_px, 2.0, Color("ffb0e0"))
	
	# Jogador (ponto azul ciano)
	var player_px := rect.position + Vector2(float(game.player_position.x) * scale_x, float(game.player_position.y) * scale_y)
	draw_circle(player_px, 3.5, Color("40c8ff"))
	draw_circle(player_px, 1.8, Color("ffffff"))


func _draw_stat_chip(rect: Rect2, icon: String, value: String, tint: Color) -> void:
	# Caixa do chip com borda neon sutil
	draw_rect(rect, Color("0b0d20", 0.96), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.5)), Color(tint, 0.55), true)
	draw_rect(rect, Color(tint, 0.08), false, 1.0)
	var icon_center := Vector2(rect.position.x + 15, rect.position.y + rect.size.y * 0.5)
	match icon:
		"shield": _draw_shield_icon(icon_center.x, icon_center.y, 0.68)
		"coin": _draw_coin_icon(icon_center.x, icon_center.y, 0.68)
		"switch": _draw_switch_icon(icon_center.x, icon_center.y, 0.68)
		"breaker": _draw_breaker_icon(icon_center.x, icon_center.y, 0.68)
	draw_string(font, Vector2(rect.position.x + 28, rect.position.y + 26), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 13, tint)


func _draw_footer(screen: Vector2) -> void:
	var footer_height := 38.0
	# Fundo footer
	draw_rect(Rect2(0, screen.y - footer_height, screen.x, footer_height), Color("06091a", 0.92))
	draw_rect(Rect2(0, screen.y - footer_height, screen.x, 1.5), Color("8040c0", 0.6))
	
	# ── Corações (vidas) no lado esquerdo ──────────────────────────────────────
	var heart_y := screen.y - footer_height * 0.5 + 2.0
	var max_hp := 3 # pode ser expandido futuramente
	for i in max_hp:
		var hx := 18.0 + float(i) * 28.0
		_draw_heart(Vector2(hx, heart_y), true)
	
	# ── Controlos centrais ──────────────────────────────────────────────────────
	var controls := "W A S D  MOVER     ESPACO  SALTAR     B  DEMOLIR     ESC  PAUSA     R  REPETIR     M  MUSICA"
	draw_string(font, Vector2(screen.x * 0.5, screen.y - 12), controls, HORIZONTAL_ALIGNMENT_CENTER, screen.x * 0.6, 9, Color("6050a0"))
	
	# ── Ícone do Personagem + Vidas no canto direito ────────────────────────────
	var char_x := screen.x - 55.0
	var char_y := screen.y - footer_height * 0.5 + 2.0
	draw_circle(Vector2(char_x, char_y), 8.0, Color("5c081e"))
	draw_circle(Vector2(char_x - 0.5, char_y - 0.5), 7.0, Color("e01b3c"))
	draw_circle(Vector2(char_x - 2.5, char_y - 2.5), 2.0, Color("ffffff", 0.9))
	draw_string(font, Vector2(char_x + 12, char_y + 4), "x 3", HORIZONTAL_ALIGNMENT_LEFT, 30, 11, Color("e0d0ff"))
	
	# ── Aviso / Notícia central ─────────────────────────────────────────────────
	if game.last_notice != "" and game.game_state == "playing":
		var center := Vector2(screen.x * 0.5, screen.y - footer_height - 32.0)
		var width := minf(screen.x - 48.0, 720.0)
		draw_rect(Rect2(center.x - width * 0.5, center.y - 16, width, 32), Color("08061a", 0.96))
		draw_rect(Rect2(center.x - width * 0.5, center.y - 16, width, 1.5), Color("c060ff", 0.75))
		# Ícone de exclamação
		draw_circle(Vector2(center.x - width * 0.5 + 14, center.y), 5.0, Color("c060ff", 0.4))
		draw_string(font, Vector2(center.x - width * 0.5 + 9, center.y + 4), "!", HORIZONTAL_ALIGNMENT_LEFT, 12, 11, Color("e090ff"))
		draw_string(font, Vector2(center.x - width * 0.5 + 28, center.y + 5), game.last_notice, HORIZONTAL_ALIGNMENT_CENTER, width - 42, 11, Color("e0d0ff"))


func _draw_heart(pos: Vector2, filled: bool) -> void:
	# Coração estilo pixel art usando polígono
	var col := Color("ff3060") if filled else Color("3d1830")
	var out_col := Color("ff80a0") if filled else Color("2a0f22")
	# Coração aproximado com círculos e triângulo
	draw_circle(pos + Vector2(-5, -3), 5.5, col)
	draw_circle(pos + Vector2(5, -3), 5.5, col)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-10, 0), pos + Vector2(10, 0), pos + Vector2(0, 11)
	]), col)
	if filled:
		# Brilho especular
		draw_circle(pos + Vector2(-5, -5), 2.0, Color("ffb0c0", 0.7))


func _draw_title(screen: Vector2) -> void:
	_draw_cinematic_backdrop(screen, 0.12)
	var menu_x := maxf(112.0, screen.x * 0.10)
	var menu_width := minf(340.0, screen.x * 0.33)
	var menu_top := screen.y * 0.315
	draw_string(font, Vector2(menu_x, menu_top), "/// SINAL DE RESGATE  /  SETOR 01", HORIZONTAL_ALIGNMENT_LEFT, menu_width, 9, Color("77e8f1", 0.86))
	draw_rect(Rect2(menu_x, menu_top + 12, 56, 2), Color("ffe600", 0.86))
	var button_y := menu_top + 28.0
	var button_height := 38.0
	var gap := 7.0
	if game.has_resume:
		_draw_button(Rect2(menu_x, button_y, menu_width, button_height), "CONTINUAR JORNADA   [ANDAR %02d]" % game.resume_floor, "continue", "menu_primary")
		button_y += button_height + gap
		_draw_button(Rect2(menu_x, button_y, menu_width, button_height), "INICIAR NOVA EXPEDICAO", "new_run", "menu")
	else:
		_draw_button(Rect2(menu_x, button_y, menu_width, button_height), "INICIAR EXPEDICAO", "new_run", "menu_primary")
	button_y += button_height + gap
	_draw_button(Rect2(menu_x, button_y, menu_width, button_height), "MATRIZ DE ANDARES", "levels", "menu")
	button_y += button_height + gap
	var music_label := "MUSICA  /  LIGADA" if not game.audio.music_muted else "MUSICA  /  DESLIGADA"
	_draw_button(Rect2(menu_x, button_y, menu_width, button_height), music_label, "music", "menu")
	draw_string(font, Vector2(maxf(46.0, screen.x * 0.045), screen.y - 55), "CLIQUE  SELECIONAR     ENTER  JOGAR / CONTINUAR     N  NOVO JOGO     M  SOM", HORIZONTAL_ALIGNMENT_LEFT, screen.x * 0.75, 9, Color("a7b5ce", 0.84))
	draw_string(font, Vector2(screen.x - 22, 30), "%d ANDARES DESBLOQUEADOS" % game.furthest_floor, HORIZONTAL_ALIGNMENT_RIGHT, 280, 9, Color("d7e5ef", 0.78))


func _draw_level_select(screen: Vector2) -> void:
	_draw_cinematic_backdrop(screen, 0.7)
	var panel_width := minf(900.0, screen.x - 34.0)
	var panel_height := minf(450.0, screen.y - 36.0)
	var panel := Rect2((screen - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))
	_draw_panel(panel, Color("61e9f3", 0.38))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 48), "DIARIO DAS RUINAS", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 26, Color("f0f7ff"))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 74), "Campanha procedural sem fim  /  cada andar guarda as tuas estrelas.", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 11, Color("aab7d0"))
	var gap := 10.0
	var card_width := minf(150.0, (panel.size.x - 64.0 - gap * 4.0) / 5.0)
	var card_height := minf(190.0, panel.size.y - 150.0)
	var row_width := card_width * 5.0 + gap * 4.0
	var row_x := screen.x * 0.5 - row_width * 0.5
	var row_y := panel.position.y + 112.0
	for index in 5:
		_draw_floor_card(Rect2(row_x + index * (card_width + gap), row_y, card_width, card_height), game.level_page_start + index)
	var nav_y := panel.position.y + panel.size.y - 48
	_draw_button(Rect2(panel.position.x + 22, nav_y, 142, 34), "VOLTAR AO MENU", "menu", "secondary")
	if panel.size.x >= 650.0:
		if game.level_page_start > 1:
			_draw_button(Rect2(panel.position.x + 180, nav_y, 124, 34), "← ANTERIORES", "levels_previous", "secondary")
		if game.level_page_start + 4 < game.furthest_floor:
			_draw_button(Rect2(panel.position.x + 312, nav_y, 120, 34), "SEGUINTES →", "levels_next", "secondary")
		draw_string(font, Vector2(panel.position.x + 448, panel.position.y + panel.size.y - 25), "ANDARES %d–%d  /  %d" % [game.level_page_start, game.level_page_start + 4, game.furthest_floor], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 470, 9, Color("71829e"))
	draw_string(font, Vector2(panel.position.x + panel.size.x - 225, panel.position.y + 24), "1–5 ESCOLHER  /  ← → PAGINAR", HORIZONTAL_ALIGNMENT_RIGHT, 205, 9, Color("71829e"))


func _draw_floor_card(rect: Rect2, number: int) -> void:
	var unlocked: bool = number <= game.furthest_floor
	var stars: int = int(game.floor_stars.get(str(number), 0))
	var base := Color("16263c") if unlocked else Color("101522")
	draw_rect(rect.grow(2), Color("6de9f4", 0.08 if unlocked else 0.02))
	draw_rect(rect, base)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("68e8f4", 0.65) if unlocked else Color("4a5365", 0.3))
	draw_string(font, Vector2(rect.position.x + 8, rect.position.y + 29), "ANDAR %02d" % number, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 15, Color("eef7ff") if unlocked else Color("69758b"))
	draw_string(font, Vector2(rect.position.x + 8, rect.position.y + 52), game.get_floor_name(number), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 9, Color("7ee8ef") if unlocked else Color("596276"))
	for star in 5:
		var x := rect.position.x + rect.size.x * 0.5 + (star - 2) * minf(20.0, rect.size.x * 0.14)
		_draw_star(Vector2(x, rect.position.y + rect.size.y * 0.64), 7.0, Color("ffd35e") if star < stars else Color("344055"))
	var status := "%d ESTRELAS" % stars if stars > 0 else "DISPONIVEL" if unlocked else "FECHADO"
	draw_string(font, Vector2(rect.position.x + 7, rect.position.y + rect.size.y - 20), status, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 14, 9, Color("c3d7e4") if unlocked else Color("657087"))
	if unlocked:
		buttons.append({"rect": rect, "action": "floor:%d" % number})


func _draw_pause(screen: Vector2) -> void:
	_draw_modal_backdrop(screen, Color("050916", 0.76))
	var panel := Rect2(screen * 0.5 - Vector2(220, 172), Vector2(440, 344))
	_draw_panel(panel, Color("61e9f3", 0.4))
	draw_string(font, Vector2(panel.position.x + 24, panel.position.y + 60), "PAUSA", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 48, 30, Color("eef7ff"))
	draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 90), "%s  /  ANDAR %02d" % [game.get_floor_name(game.floor_number), game.floor_number], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 56, 11, Color("8be8f1"))
	_draw_button(Rect2(panel.position.x + 48, panel.position.y + 116, panel.size.x - 96, 44), "VOLTAR AO JOGO", "resume", "primary")
	_draw_button(Rect2(panel.position.x + 48, panel.position.y + 170, panel.size.x - 96, 40), "DIARIO DE ANDARES", "levels", "secondary")
	_draw_button(Rect2(panel.position.x + 48, panel.position.y + 220, panel.size.x - 96, 40), "SAIR PARA O MENU", "menu", "secondary")


func _draw_result(screen: Vector2, rescued: bool) -> void:
	_draw_modal_backdrop(screen, Color("08061a", 0.78))
	var panel_width := minf(610.0, screen.x - 34.0)
	var panel_height := minf(410.0, screen.y - 32.0)
	var panel := Rect2((screen - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))
	_draw_panel(panel, Color("bd78ff", 0.45))
	var title: String = ""
	var subtitle: String = ""
	if rescued:
		if game.floor_number == 5:
			title = "LIA FOI AVISTADA!"
			subtitle = "Presa numa capsula pelo Warden-Prime! Ele foge: 'Ela pertence ao abismo... so no Andar 100 a salvaras!'."
		elif game.floor_number == 100:
			title = "LIA FOI LIBERTADA!"
			subtitle = "A capsula quebrou-se! Lia esta a salvo e junta-se a ti! A jornada continua ate ao Andar 200!"
		else:
			title = "SETOR %02d CONCLUIDO" % game.floor_number
			subtitle = "Mais perto de libertar Lia no Andar 100. Novos desafios e inimigos desbloqueados."
	else:
		title = "ANDAR %02d CONCLUIDO" % game.floor_number
		subtitle = game.get_floor_name(game.floor_number)
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 80), subtitle, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 12, Color("9caecc"))
	var star_y := panel.position.y + 139
	for index in 5:
		var x := screen.x * 0.5 + (index - 2) * 50.0
		_draw_star(Vector2(x, star_y), 19.0 if index < game.stars_last_floor else 16.0, Color("ffd35e") if index < game.stars_last_floor else Color("303a54"))
	draw_string(font, Vector2(panel.position.x + 26, panel.position.y + 184), "+%d RECOMPENSA     MOEDAS %02d     TOTAL %03d" % [game.floor_reward, game.coins_this_floor, game.total_coins], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 52, 12, Color("f3df9c"))
	draw_string(font, Vector2(panel.position.x + 26, panel.position.y + 211), "RECORDE %03d     RESGATES %d" % [game.best_score, game.rescues_completed], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 52, 10, Color("b3c0d8"))
	var button_y := panel.position.y + panel.size.y - 70
	var button_width := minf(170.0, (panel.size.x - 58.0) / 3.0)
	var gap := 10.0
	var row_x := screen.x * 0.5 - (button_width * 3.0 + gap * 2.0) * 0.5
	_draw_button(Rect2(row_x, button_y, button_width, 42), "PROXIMO SETOR" if rescued else "PROXIMO ANDAR", "next_floor", "primary")
	_draw_button(Rect2(row_x + button_width + gap, button_y, button_width, 42), "DIARIO", "levels", "secondary")
	_draw_button(Rect2(row_x + (button_width + gap) * 2.0, button_y, button_width, 42), "MENU", "menu", "secondary")


func _draw_game_over(screen: Vector2) -> void:
	_draw_modal_backdrop(screen, Color("09040d", 0.84))
	var panel_width := minf(540.0, screen.x - 32.0)
	var panel_height := minf(340.0, screen.y - 32.0)
	var panel := Rect2((screen - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))
	_draw_panel(panel, Color("ff536f", 0.55))
	draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 59), "FOSTE CAPTURADO", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 56, 27, Color("ffe7ec"))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 90), "%s  /  CONTINUA DO ANDAR %02d" % [game.get_floor_name(game.floor_number), game.floor_number], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 11, Color("d7a7b8"))
	draw_string(font, Vector2(panel.position.x + 28, panel.position.y + 128), "MOEDAS %03d       RECORDE %03d       ESTRELAS %d" % [game.total_coins, game.best_score, game.floor_stars.get(str(game.floor_number), 0)], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 56, 12, Color("e3d7e1"))
	var button_x := panel.position.x + 44.0
	var button_width := panel.size.x - 88.0
	var button_y := panel.position.y + panel.size.y - 150.0
	_draw_button(Rect2(button_x, button_y, button_width, 42), "CONTINUAR NO ANDAR %02d" % game.resume_floor, "continue", "primary")
	_draw_button(Rect2(button_x, button_y + 51, button_width, 38), "ESCOLHER ANDAR", "levels", "secondary")
	_draw_button(Rect2(button_x, button_y + 98, button_width, 38), "VOLTAR AO MENU", "menu", "secondary")


func _draw_panel(rect: Rect2, accent: Color) -> void:
	draw_rect(rect.grow(5), Color(accent, 0.12))
	draw_rect(rect, Color("0b1222", 0.98))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), accent)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), Color("d7ecff", 0.10))


func _draw_button(rect: Rect2, label: String, action: String, style: String) -> void:
	var hovered := rect.has_point(pointer)
	if style == "menu" or style == "menu_primary":
		var active := hovered or style == "menu_primary"
		var text_color := Color("ffe600") if active else Color("d0d9e4", 0.9)
		if active:
			draw_rect(Rect2(rect.position.x, rect.position.y + 5, 2, rect.size.y - 10), Color("ffe600", 0.92))
			draw_string(font, Vector2(rect.position.x + 10, rect.position.y + rect.size.y * 0.5 + 4), ">", HORIZONTAL_ALIGNMENT_LEFT, 12, 14, Color("ffe600"))
		draw_string(font, Vector2(rect.position.x + 30, rect.position.y + rect.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36, 12, text_color)
		if hovered:
			draw_rect(Rect2(rect.position.x + 30, rect.position.y + rect.size.y - 3, minf(rect.size.x - 42, label.length() * 7.0), 1), Color("ffe600", 0.62))
		buttons.append({"rect": rect, "action": action})
		return
	var fill := Color("15354b") if style == "primary" else Color("151e31")
	var accent := Color("54e2f0") if style == "primary" else Color("536581")
	if hovered:
		fill = Color("1a455a") if style == "primary" else Color("202d44")
		accent = Color("9af7ff") if style == "primary" else Color("9bb1d5")
	draw_rect(rect.grow(2) if hovered else rect, Color(accent, 0.12 if hovered else 0.04))
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(accent, 0.82))
	draw_string(font, Vector2(rect.position.x + 8, rect.position.y + rect.size.y * 0.5 + 5), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 12, Color("f0f8ff"))
	if action != "":
		buttons.append({"rect": rect, "action": action})


func _draw_modal_backdrop(screen: Vector2, color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), color)
	for i in 5:
		var inset := 8.0 + i * 9.0
		draw_rect(Rect2(inset, inset, screen.x - inset * 2, screen.y - inset * 2), Color("d95aff", 0.022 - i * 0.003), false, 1.0)


func _draw_cinematic_backdrop(screen: Vector2, tint_strength: float) -> void:
	draw_texture_rect(MenuBackdrop, Rect2(Vector2.ZERO, screen), false)
	draw_rect(Rect2(Vector2.ZERO, screen), Color("050810", tint_strength))
	var scrim_width := screen.x * 0.64
	for index in 28:
		var progress := float(index) / 27.0
		var alpha := 0.68 * pow(1.0 - progress, 2.2)
		draw_rect(Rect2(scrim_width * progress, 0, scrim_width / 28.0 + 1, screen.y), Color("050811", alpha), true)
	for y in range(0, int(screen.y), 8):
		draw_rect(Rect2(0, y, screen.x, 1), Color("d9fbff", 0.018), true)


func _draw_coin_icon(x: float, y: float, scale: float = 1.0) -> void:
	draw_circle(Vector2(x, y), 10.0 * scale, Color("ffbf43", 0.16))
	draw_circle(Vector2(x, y), 6.5 * scale, Color("ffd35b"))
	draw_circle(Vector2(x - 1.5 * scale, y - 1.5 * scale), 2.0 * scale, Color("fff1b7"))


func _draw_shield_icon(x: float, y: float, scale: float = 1.0) -> void:
	var polygon := PackedVector2Array([Vector2(x, y - 10 * scale), Vector2(x + 8 * scale, y - 5 * scale), Vector2(x + 6 * scale, y + 6 * scale), Vector2(x, y + 10 * scale), Vector2(x - 6 * scale, y + 6 * scale), Vector2(x - 8 * scale, y - 5 * scale)])
	draw_colored_polygon(polygon, Color("4ce5f4"))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color("d5fcff"), 1.2 * scale, true)


func _draw_switch_icon(x: float, y: float, scale: float = 1.0) -> void:
	draw_rect(Rect2(x - 8 * scale, y - 6 * scale, 16 * scale, 12 * scale), Color("7dec9c"))
	draw_circle(Vector2(x, y), 2.5 * scale, Color("f4fff0"))


func _draw_breaker_icon(x: float, y: float, scale: float = 1.0) -> void:
	draw_line(Vector2(x - 5 * scale, y + 7 * scale), Vector2(x + 5 * scale, y - 6 * scale), Color("ffc276"), 3.3 * scale, true)
	draw_line(Vector2(x - 7 * scale, y - 8 * scale), Vector2(x + 7 * scale, y - 8 * scale), Color("fff0ca"), 3.3 * scale, true)
	draw_line(Vector2(x - 7 * scale, y - 8 * scale), Vector2(x - 10 * scale, y - 2 * scale), Color("fff0ca"), 2.5 * scale, true)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI / 2.0 + index * PI / 5.0
		var size := radius if index % 2 == 0 else radius * 0.44
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(points, color)
