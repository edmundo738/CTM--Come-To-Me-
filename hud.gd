extends Control

var game: Node
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var screen := get_viewport_rect().size
	_draw_header(screen)
	_draw_footer(screen)
	if game.game_state == "floor_clear":
		_draw_result(screen, false)
	elif game.game_state == "rescued":
		_draw_result(screen, true)
	elif game.game_state == "game_over":
		_draw_game_over(screen)
	if game.flash_time > 0.0:
		var alpha: float = 0.2 * minf(1.0, game.flash_time / 0.14)
		draw_rect(Rect2(Vector2.ZERO, screen), Color(game.flash_color, alpha))


func _draw_header(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 86)), Color("080d1f", 0.9))
	for i in 28:
		var progress := float(i) / 27.0
		var color := Color("5638a4", 0.025 + (1.0 - progress) * 0.055).lerp(Color("27d9ee", 0.075), progress)
		draw_line(Vector2(0, 83 + i * 0.075), Vector2(screen.x, 83 + i * 0.075), color, 1.0)
	draw_string(font, Vector2(26, 36), "COME TO ME", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("edfaff"))
	draw_string(font, Vector2(28, 61), "NEON RUINS  /  RESGATE TATICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("6ceaf4"))
	var central_x := screen.x * 0.33
	var max_width := screen.x * 0.41
	draw_string(font, Vector2(central_x, 34), "ANDAR %02d" % game.floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9e4ff"))
	draw_string(font, Vector2(central_x, 59), game.get_objective_text(), HORIZONTAL_ALIGNMENT_LEFT, max_width, 12, Color("9eafcf"))
	var right := screen.x - 28.0
	_draw_coin_icon(right - 174, 34)
	draw_string(font, Vector2(right - 159, 39), "%03d" % game.total_coins, HORIZONTAL_ALIGNMENT_LEFT, 46, 16, Color("ffe07b"))
	_draw_shield_icon(right - 103, 34)
	draw_string(font, Vector2(right - 88, 39), "%d" % game.charges, HORIZONTAL_ALIGNMENT_LEFT, 28, 16, Color("9bf6ff"))
	_draw_switch_icon(right - 48, 34)
	var switch_count := "%d/%d" % [game._active_switches(), game.switches.size()] if game.switches.size() > 0 else "--"
	draw_string(font, Vector2(right - 32, 39), switch_count, HORIZONTAL_ALIGNMENT_LEFT, 40, 14, Color("c7ffab"))
	draw_string(font, Vector2(right - 170, 63), "RECORDE %03d" % game.best_score, HORIZONTAL_ALIGNMENT_LEFT, 160, 10, Color("7787a7"))


func _draw_footer(screen: Vector2) -> void:
	var footer_y := screen.y - 22.0
	draw_rect(Rect2(Vector2(0, screen.y - 42.0), Vector2(screen.x, 42.0)), Color("080d1f", 0.76))
	draw_string(font, Vector2(26, footer_y), "WASD / SETAS  MOVER     ESPACO  SALTAR     R  REINICIAR     M  MUSICA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9eafc9"))
	if game.last_notice != "" and game.game_state == "playing":
		var center := Vector2(screen.x * 0.5, screen.y - 68.0)
		var width := minf(screen.x - 48.0, 690.0)
		draw_rect(Rect2(center.x - width * 0.5, center.y - 19, width, 38), Color("101a30", 0.94))
		draw_rect(Rect2(center.x - width * 0.5, center.y - 19, width, 1.5), Color("4bdbea", 0.55))
		draw_string(font, Vector2(center.x - width * 0.5 + 16, center.y + 5), game.last_notice, HORIZONTAL_ALIGNMENT_LEFT, width - 32, 13, Color("f2f5ff"))


func _draw_result(screen: Vector2, rescued: bool) -> void:
	_draw_modal_backdrop(screen, Color("08061a", 0.74))
	var panel := Rect2(screen * 0.5 - Vector2(295, 190), Vector2(590, 380))
	draw_rect(panel.grow(3), Color("bf78ff", 0.17))
	draw_rect(panel, Color("0c1227", 0.98))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3)), Color("6de9f5", 0.85))
	var title := "LIA ESTA AQUI" if rescued else "ANDAR %02d CONCLUIDO" % game.floor_number
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 50), title, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 27, Color("e8faff"))
	var subtitle := "A TUA AMADA ESTA A SALVO. JUNTOS, VOCES SAEM DAS RUINAS." if rescued else "Rota limpa. O portal seguinte ja esta a chamar."
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 78), subtitle, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 12, Color("9caecc"))
	var star_y := panel.position.y + 145
	for index in 5:
		var x := screen.x * 0.5 + (index - 2) * 52.0
		var filled: bool = index < game.stars_last_floor
		var color := Color("ffd35e") if filled else Color("303a54")
		_draw_star(Vector2(x, star_y), 20.0 if filled else 17.0, color)
	var reward_line := "+%d recompensa de estrelas" % game.floor_reward
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 195), "MOEDAS DO ANDAR  %02d       ESCUDOS  %d       %s" % [game.coins_this_floor, game.charges, reward_line], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 13, Color("f3df9c"))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 229), "TOTAL  %03d       RECORDE  %03d       RESGATES  %d" % [game.total_coins, game.best_score, game.rescues_completed], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 12, Color("b3c0d8"))
	var prompt := "R  JOGAR DE NOVO" if rescued else "ENTER  PROXIMO ANDAR"
	draw_rect(Rect2(panel.position.x + 120, panel.position.y + 278, panel.size.x - 240, 42), Color("182744"))
	draw_rect(Rect2(panel.position.x + 120, panel.position.y + 278, panel.size.x - 240, 1), Color("55e1f0", 0.72))
	draw_string(font, Vector2(panel.position.x + 120, panel.position.y + 304), prompt, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 240, 15, Color("baf9ff"))


func _draw_game_over(screen: Vector2) -> void:
	_draw_modal_backdrop(screen, Color("09040d", 0.84))
	var panel := Rect2(screen * 0.5 - Vector2(270, 155), Vector2(540, 310))
	draw_rect(panel.grow(3), Color("ff456d", 0.15))
	draw_rect(panel, Color("100d1c", 0.98))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3)), Color("ff536f", 0.92))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 65), "FOSTE CAPTURADO", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 30, Color("ffe7ec"))
	draw_string(font, Vector2(panel.position.x + 36, panel.position.y + 105), "A BOLA REBENTOU. A CIDADE FICA EM SILENCIO.", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 72, 13, Color("c89aa8"))
	draw_string(font, Vector2(panel.position.x + 30, panel.position.y + 165), "ANDARES  %02d       MOEDAS  %03d       RECORDE  %03d" % [game.floor_number, game.total_coins, game.best_score], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 60, 14, Color("d9ccda"))
	draw_rect(Rect2(panel.position.x + 112, panel.position.y + 215, panel.size.x - 224, 42), Color("3c1729"))
	draw_string(font, Vector2(panel.position.x + 112, panel.position.y + 242), "R  TENTAR OUTRA VEZ", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 224, 15, Color("ffd9e0"))


func _draw_modal_backdrop(screen: Vector2, color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), color)
	for i in 5:
		var inset := 8.0 + i * 9.0
		draw_rect(Rect2(inset, inset, screen.x - inset * 2, screen.y - inset * 2), Color("d95aff", 0.025 - i * 0.003), false, 1.0)


func _draw_coin_icon(x: float, y: float) -> void:
	draw_circle(Vector2(x, y), 10.0, Color("ffbf43", 0.16))
	draw_circle(Vector2(x, y), 6.5, Color("ffd35b"))
	draw_circle(Vector2(x - 1.5, y - 1.5), 2.0, Color("fff1b7"))


func _draw_shield_icon(x: float, y: float) -> void:
	var polygon := PackedVector2Array([Vector2(x, y - 10), Vector2(x + 8, y - 5), Vector2(x + 6, y + 6), Vector2(x, y + 10), Vector2(x - 6, y + 6), Vector2(x - 8, y - 5)])
	draw_colored_polygon(polygon, Color("4ce5f4"))
	draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[4], polygon[5], polygon[0]]), Color("d5fcff"), 1.2, true)


func _draw_switch_icon(x: float, y: float) -> void:
	draw_rect(Rect2(Vector2(x - 8, y - 6), Vector2(16, 12)), Color("7dec9c"))
	draw_circle(Vector2(x, y), 2.5, Color("f4fff0"))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + i * PI / 5.0
		var size := radius if i % 2 == 0 else radius * 0.44
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(points, color)
