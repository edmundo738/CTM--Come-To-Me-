extends RefCounted

# Prototype economy: one point for the first completion of a floor, separate
# from score/coins. Each branch has a root and two independently developed
# paths. Data describes only effects implemented in game.gd.
const VERSION := 1
const EQUIP_LIMIT := 8
const BRANCHES := [
	{"id": "vida", "name": "SOBREVIVENCIA", "color": "ff718d"},
	{"id": "escudo", "name": "ESCUDOS", "color": "68e9f5"},
	{"id": "movimento", "name": "MOVIMENTO", "color": "ffca68"},
	{"id": "tempo", "name": "CONTROLO", "color": "afa5ff"},
	{"id": "exploracao", "name": "EXPLORACAO", "color": "f5e37d"},
	{"id": "engenharia", "name": "ENGENHARIA", "color": "f9946a"},
]

# Positions are (column,row): a root with a left and a right fork. Each effect
# is additive; names/descriptions, costs, dependencies and actual modifiers
# share this single source of truth.
const NODES := [
	{"id":"heart_1", "branch":"vida", "name":"CORACAO I", "desc":"+1 capacidade e 1 coracao na primeira ativacao.", "parent":"", "cost":1, "col":1, "row":0, "effect":"heart_capacity", "amount":1},
	{"id":"heart_2", "branch":"vida", "name":"CORACAO II", "desc":"+1 capacidade e 1 coracao na primeira ativacao.", "parent":"heart_1", "cost":2, "col":0, "row":1, "effect":"heart_capacity", "amount":1},
	{"id":"heart_3", "branch":"vida", "name":"CORACAO III", "desc":"+1 capacidade e 1 coracao na primeira ativacao.", "parent":"heart_2", "cost":3, "col":0, "row":2, "effect":"heart_capacity", "amount":1},
	{"id":"recovery_1", "branch":"vida", "name":"OLHO I", "desc":"+12% de chance de aparecer 1 coracao recuperavel no andar.", "parent":"heart_1", "cost":2, "col":2, "row":1, "effect":"heart_spawn", "amount":12},
	{"id":"recovery_2", "branch":"vida", "name":"OLHO II", "desc":"+12% de chance de aparecer 1 coracao recuperavel no andar.", "parent":"recovery_1", "cost":3, "col":2, "row":2, "effect":"heart_spawn", "amount":12},
	{"id":"recovery_3", "branch":"vida", "name":"OLHO III", "desc":"+12% de chance de aparecer 1 coracao recuperavel no andar.", "parent":"recovery_2", "cost":3, "col":2, "row":3, "effect":"heart_spawn", "amount":12},

	{"id":"shield_1", "branch":"escudo", "name":"RESERVA I", "desc":"+1 capacidade de transporte de escudos (base 3).", "parent":"", "cost":1, "col":1, "row":0, "effect":"shield_capacity", "amount":1},
	{"id":"shield_2", "branch":"escudo", "name":"RESERVA II", "desc":"+1 capacidade de transporte de escudos.", "parent":"shield_1", "cost":2, "col":0, "row":1, "effect":"shield_capacity", "amount":1},
	{"id":"shield_3", "branch":"escudo", "name":"RESERVA III", "desc":"+1 capacidade de transporte de escudos.", "parent":"shield_2", "cost":3, "col":0, "row":2, "effect":"shield_capacity", "amount":1},
	{"id":"shield_pickup_1", "branch":"escudo", "name":"COLETA I", "desc":"Cada escudo recolhido concede +1 carga, ate ao limite.", "parent":"shield_1", "cost":2, "col":2, "row":1, "effect":"shield_pickup", "amount":1},
	{"id":"shield_pickup_2", "branch":"escudo", "name":"COLETA II", "desc":"Cada escudo recolhido concede mais +1 carga, ate ao limite.", "parent":"shield_pickup_1", "cost":3, "col":2, "row":2, "effect":"shield_pickup", "amount":1},
	{"id":"shield_counter", "branch":"escudo", "name":"CONTRA-GOLPE", "desc":"Contra-ataque com escudo causa +1 dano a elites.", "parent":"shield_pickup_2", "cost":3, "col":2, "row":3, "effect":"shield_counter", "amount":1},

	{"id":"speed_1", "branch":"movimento", "name":"IMPULSO I", "desc":"O pickup de velocidade dura +2 acoes.", "parent":"", "cost":1, "col":1, "row":0, "effect":"speed_duration", "amount":2},
	{"id":"speed_2", "branch":"movimento", "name":"IMPULSO II", "desc":"O pickup de velocidade dura mais +2 acoes.", "parent":"speed_1", "cost":2, "col":0, "row":1, "effect":"speed_duration", "amount":2},
	{"id":"speed_3", "branch":"movimento", "name":"IMPULSO III", "desc":"O pickup de velocidade dura mais +2 acoes.", "parent":"speed_2", "cost":3, "col":0, "row":2, "effect":"speed_duration", "amount":2},
	{"id":"blink_1", "branch":"movimento", "name":"BLINK I", "desc":"Cada pickup de Blink concede +1 carga.", "parent":"speed_1", "cost":2, "col":2, "row":1, "effect":"blink_pickup", "amount":1},
	{"id":"blink_reach", "branch":"movimento", "name":"SALTO ESPACIAL", "desc":"Blink alcanca mais 1 casa; continua a gastar 1 carga.", "parent":"blink_1", "cost":3, "col":2, "row":2, "effect":"blink_range", "amount":1},
	{"id":"blink_2", "branch":"movimento", "name":"BLINK II", "desc":"Cada pickup de Blink concede mais +1 carga.", "parent":"blink_reach", "cost":3, "col":2, "row":3, "effect":"blink_pickup", "amount":1},

	{"id":"freeze_1", "branch":"tempo", "name":"TEMPO I", "desc":"O pickup de congelamento dura +1 acao.", "parent":"", "cost":1, "col":1, "row":0, "effect":"freeze_duration", "amount":1},
	{"id":"freeze_2", "branch":"tempo", "name":"TEMPO II", "desc":"O pickup de congelamento dura mais +1 acao.", "parent":"freeze_1", "cost":2, "col":0, "row":1, "effect":"freeze_duration", "amount":1},
	{"id":"freeze_3", "branch":"tempo", "name":"TEMPO III", "desc":"O pickup de congelamento dura mais +1 acao.", "parent":"freeze_2", "cost":3, "col":0, "row":2, "effect":"freeze_duration", "amount":1},
	{"id":"ice_grip", "branch":"tempo", "name":"ADERENCIA", "desc":"Impede o deslizamento automatico da bola no gelo.", "parent":"freeze_1", "cost":2, "col":2, "row":1, "effect":"ice_grip", "amount":1},
	{"id":"current_anchor", "branch":"tempo", "name":"ANCORA", "desc":"Impede a corrente de deslocar a bola; caixas nao mudam.", "parent":"ice_grip", "cost":3, "col":2, "row":2, "effect":"current_anchor", "amount":1},
	{"id":"freeze_4", "branch":"tempo", "name":"TEMPO IV", "desc":"O pickup de congelamento dura mais +1 acao.", "parent":"current_anchor", "cost":3, "col":2, "row":3, "effect":"freeze_duration", "amount":1},

	{"id":"magnet_1", "branch":"exploracao", "name":"IMA I", "desc":"O pickup de ima dura +2 acoes.", "parent":"", "cost":1, "col":1, "row":0, "effect":"magnet_duration", "amount":2},
	{"id":"magnet_2", "branch":"exploracao", "name":"IMA II", "desc":"O pickup de ima dura mais +2 acoes.", "parent":"magnet_1", "cost":2, "col":0, "row":1, "effect":"magnet_duration", "amount":2},
	{"id":"magnet_3", "branch":"exploracao", "name":"IMA III", "desc":"O pickup de ima dura mais +2 acoes.", "parent":"magnet_2", "cost":3, "col":0, "row":2, "effect":"magnet_duration", "amount":2},
	{"id":"magnet_reach_1", "branch":"exploracao", "name":"ALCANCE I", "desc":"Ima recolhe moedas a mais 1 passo por piso transitavel.", "parent":"magnet_1", "cost":2, "col":2, "row":1, "effect":"magnet_range", "amount":1},
	{"id":"magnet_reach_2", "branch":"exploracao", "name":"ALCANCE II", "desc":"Ima recolhe moedas a mais 1 passo por piso transitavel.", "parent":"magnet_reach_1", "cost":3, "col":2, "row":2, "effect":"magnet_range", "amount":1},
	{"id":"coin_bonus", "branch":"exploracao", "name":"PROSPECAO", "desc":"Cada moeda recolhida vale +1 moeda de pontuacao.", "parent":"magnet_reach_2", "cost":3, "col":2, "row":3, "effect":"coin_bonus", "amount":1},

	{"id":"breach_1", "branch":"engenharia", "name":"DEMOLICAO I", "desc":"Cada pickup de demolicao concede +1 carga.", "parent":"", "cost":1, "col":1, "row":0, "effect":"breach_pickup", "amount":1},
	{"id":"breach_2", "branch":"engenharia", "name":"DEMOLICAO II", "desc":"Cada pickup de demolicao concede mais +1 carga.", "parent":"breach_1", "cost":2, "col":0, "row":1, "effect":"breach_pickup", "amount":1},
	{"id":"breach_3", "branch":"engenharia", "name":"DEMOLICAO III", "desc":"Cada pickup de demolicao concede mais +1 carga.", "parent":"breach_2", "cost":3, "col":0, "row":2, "effect":"breach_pickup", "amount":1},
	{"id":"impact_1", "branch":"engenharia", "name":"IMPACTO I", "desc":"Demolicao causa +1 dano a elites; custa 1 carga.", "parent":"breach_1", "cost":2, "col":2, "row":1, "effect":"breach_damage", "amount":1},
	{"id":"impact_2", "branch":"engenharia", "name":"IMPACTO II", "desc":"Demolicao causa mais +1 dano a elites.", "parent":"impact_1", "cost":3, "col":2, "row":2, "effect":"breach_damage", "amount":1},
	{"id":"salvage", "branch":"engenharia", "name":"RECICLAGEM", "desc":"Ao derrotar inimigo por demolicao, recupera 1 carga.", "parent":"impact_2", "cost":3, "col":2, "row":3, "effect":"breach_salvage", "amount":1},
]

var points := 0
var unlocked: Array[String] = []
var active: Array[String] = []
# A heart node grants its initial charge only once for the whole campaign.
var credited: Array[String] = []
var rewarded_floors: Array[int] = []


func node(id: String) -> Dictionary:
	for definition in NODES:
		if definition.id == id:
			return definition
	return {}


func branch_nodes(branch: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in NODES:
		if definition.branch == branch:
			result.append(definition)
	return result


func effect(name: String) -> int:
	var result := 0
	for definition in NODES:
		if definition.effect == name and active.has(definition.id):
			result += int(definition.amount)
	return result


func award_floor(number: int) -> bool:
	if number < 1 or rewarded_floors.has(number):
		return false
	rewarded_floors.append(number)
	points += 1
	return true


func mark_legacy_floors(stars: Dictionary) -> void:
	# No retroactive points; prevent replaying old completed floors for a point.
	for key in stars:
		var number := int(str(key))
		if number > 0 and int(stars[key]) > 0 and not rewarded_floors.has(number):
			rewarded_floors.append(number)


func unlock(id: String) -> Dictionary:
	var definition := node(id)
	if definition.is_empty():
		return {"ok": false, "message": "HABILIDADE DESCONHECIDA"}
	if unlocked.has(id):
		return {"ok": false, "message": "JA DESBLOQUEADA"}
	if not str(definition.parent).is_empty() and not unlocked.has(definition.parent):
		return {"ok": false, "message": "DESBLOQUEIA PRIMEIRO O NO ANTERIOR"}
	if points < int(definition.cost):
		return {"ok": false, "message": "PONTOS INSUFICIENTES"}
	points -= int(definition.cost)
	unlocked.append(id)
	return {"ok": true, "message": "DESBLOQUEADA — ATIVA PARA USAR"}


func toggle(id: String) -> Dictionary:
	var definition := node(id)
	if definition.is_empty() or not unlocked.has(id):
		return {"ok": false, "message": "DESBLOQUEIA A HABILIDADE PRIMEIRO"}
	if active.has(id):
		for other in NODES:
			if other.parent == id and active.has(other.id):
				return {"ok": false, "message": "DESATIVA PRIMEIRO O NO DEPENDENTE"}
		active.erase(id)
		return {"ok": true, "message": "HABILIDADE DESATIVADA", "heart_credit": 0}
	if active.size() >= EQUIP_LIMIT:
		return {"ok": false, "message": "LIMITE DE HABILIDADES ATIVAS ATINGIDO"}
	if not str(definition.parent).is_empty() and not active.has(definition.parent):
		return {"ok": false, "message": "ATIVA PRIMEIRO O NO ANTERIOR"}
	active.append(id)
	var heart_credit := 0
	if definition.effect == "heart_capacity" and not credited.has(id):
		credited.append(id)
		heart_credit = 1
	return {"ok": true, "message": "HABILIDADE ATIVADA", "heart_credit": heart_credit}


func serialize() -> Dictionary:
	return {"version": VERSION, "points": points, "unlocked": unlocked.duplicate(), "active": active.duplicate(),
		"credited": credited.duplicate(), "rewarded_floors": rewarded_floors.duplicate()}


func load_state(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		points = 0
		unlocked.clear()
		active.clear()
		credited.clear()
		rewarded_floors.clear()
		return true
	if typeof(raw.get("version")) != TYPE_INT or raw.version != VERSION or typeof(raw.get("points")) != TYPE_INT or raw.points < 0:
		return false
	for key in ["unlocked", "active", "credited", "rewarded_floors"]:
		if not raw.get(key) is Array:
			return false
	var seen := {}
	for id in raw.unlocked:
		if not id is String or node(id).is_empty() or seen.has(id): return false
		seen[id] = true
	for id in raw.unlocked:
		var parent: String = node(id).parent
		if not parent.is_empty() and not seen.has(parent): return false
	var equipped := {}
	if raw.active.size() > EQUIP_LIMIT: return false
	for id in raw.active:
		if not id is String or not seen.has(id) or equipped.has(id): return false
		equipped[id] = true
	for id in raw.active:
		var parent: String = node(id).parent
		if not parent.is_empty() and not equipped.has(parent): return false
	var credits := {}
	for id in raw.credited:
		if not id is String or not seen.has(id) or node(id).effect != "heart_capacity" or credits.has(id): return false
		credits[id] = true
	for id in raw.active:
		if node(id).effect == "heart_capacity" and not credits.has(id): return false
	var rewards := {}
	for number in raw.rewarded_floors:
		if typeof(number) != TYPE_INT or number < 1 or rewards.has(number): return false
		rewards[number] = true
	points = raw.points
	unlocked.assign(raw.unlocked)
	active.assign(raw.active)
	credited.assign(raw.credited)
	rewarded_floors.assign(raw.rewarded_floors)
	return true
