extends Node2D

const CELL := 56.0
const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_BORDER := 2
const TILE_WATER := 3
const FOUR_WAY := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const DIAGONALS := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const KNIGHT_OFFSETS := [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2)]
# Every fifth floor features the next piece in this cycle. The portal remains
# an escape route: defeating the boss is optional, not a soft-lock condition.
const BOSS_TYPES := [
	{"id": "pawn", "name": "PEAO", "hp": 2, "rule": "1 CASA ORTOGONAL"},
	{"id": "rook", "name": "TORRE", "hp": 3, "rule": "LINHAS DE ATE 3 CASAS"},
	{"id": "knight", "name": "CAVALO", "hp": 4, "rule": "SALTO EM L"},
	{"id": "bishop", "name": "BISPO", "hp": 5, "rule": "DIAGONAIS DE ATE 3 CASAS"},
	{"id": "queen", "name": "RAINHA", "hp": 6, "rule": "LINHAS E DIAGONAIS"},
	{"id": "king", "name": "REI", "hp": 7, "rule": "1 CASA EM QUALQUER DIRECAO"},
]
# Each chess piece has its own original silhouette; the Warden remains a
# separate mini-boss, not a reskinned chess piece.
const BOSS_TEXTURES := {
	"pawn": preload("res://assets/bosses/pawn.svg"),
	"rook": preload("res://assets/bosses/rook.svg"),
	"knight": preload("res://assets/bosses/knight.svg"),
	"bishop": preload("res://assets/bosses/bishop.svg"),
	"queen": preload("res://assets/bosses/queen.svg"),
	"king": preload("res://assets/bosses/king.svg"),
}
const BOSS_COLORS := {"pawn": "5ff6ef", "rook": "ffb65b", "knight": "5cbfff", "bishop": "84f3bd", "queen": "f578dc", "king": "ffd474"}
const POWERUP_TYPES := ["speed", "magnet", "blink", "time_freeze"]
const POWERUP_COLORS := {"speed": "ffce5c", "magnet": "ff68aa", "blink": "9af4ff", "time_freeze": "92a4ff"}
const SPEED_DURATION := 6
const MAGNET_DURATION := 8
const FREEZE_DURATION := 4
const PUZZLE_COLORS := ["5df4f2", "ffbe60", "d78aff"]
const PUZZLE_NAMES := ["CIANO", "AMBAR", "VIOLETA"]
const PATROL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const CHALLENGE_KINDS := ["no_jump", "no_hit", "moves", "all_coins"]
const MAP_SIZES := [Vector2i(19, 15), Vector2i(25, 17), Vector2i(31, 21), Vector2i(37, 23), Vector2i(43, 27)]
const FLOOR_NAMES := ["AS RUINAS DE NEON", "JARDIM DE VIDRO", "FORNALHA VIOLETA", "CATEDRAL DE GELO", "TRONO DO GUARDIAO"]
const LEVELS_PER_PAGE := 5
const CAPTURE_POP_TIME := 0.92
const CAPTURE_END_TIME := 1.95
const CAPTOR_FLYOVER_SECONDS := 5.5
const DIVINE_CAPTOR_TEXTURE = preload("res://assets/story/divine_captor.svg")
const CAPTIVE_CAGE_TEXTURE = preload("res://assets/story/captive_cage.svg")
const Generator = preload("res://level_generator.gd")
const HudScript = preload("res://hud.gd")
const AudioScript = preload("res://audio_feedback.gd")
const ControllerScript = preload("res://controller_input.gd")
const VIBRATION_PROFILE_VERSION := 2
const TacticalFeedbackScript = preload("res://tactical_feedback.gd")
const BackgroundShader = preload("res://background.gdshader")
const CaptureOverlayShader = preload("res://capture_overlay.gdshader")
const TerrainRenderer = preload("res://terrain_renderer.gd")
const EnvironmentSystem = preload("res://environment_system.gd")
const EnvironmentChambers = preload("res://environment_chambers.gd")
const VisualMotion = preload("res://visual_motion.gd")
const ImpactPresentation = preload("res://impact_presentation.gd")
const EnvironmentVFX = preload("res://environment_vfx.gd")
const ElectricPresentation = preload("res://electric_presentation.gd")
const SpecialSchedule = preload("res://special_schedule.gd")
const SpecialLevels = preload("res://special_levels.gd")
const SkillTree = preload("res://skill_tree.gd")
const CampaignStorage = preload("res://campaign_storage.gd")
const WALK_VISUAL_TIME := 0.14
const SLIDE_VISUAL_TIME := 0.16
const JUMP_VISUAL_TIME := 0.21

var environment = EnvironmentSystem.new()
var special_schedule = SpecialSchedule.new()
var special_family := ""
var special_hint := ""
var special_spec: Dictionary = {}
var special_route_cache: Dictionary = {}
# Bounded undo applies only to actual Sokoban chambers, not campaign combat.
var sokoban_history: Array[Dictionary] = []
var sokoban_pushes := 0
const SOKOBAN_HISTORY_LIMIT := 128
# At most the handful of reflected, hand-authored templates in this version.
var special_template_plans: Dictionary = {}
var lab_active := false
var lab_index := 0
var lab_name := ""
var lab_hint := ""
# Optional campaign landmark, separate from the main portal objective.
var environment_bonus_available := false
var environment_bonus_claimed := false
var grid: Array = []
var world_size := Vector2i(0, 0)
var player_position := Vector2i.ZERO
var player_from := Vector2.ZERO
var player_to := Vector2.ZERO
var player_anim := 1.0
# Presentation only. The grid position, turn and collision resolve immediately.
var player_motion = VisualMotion.new()
var impact_presentation = ImpactPresentation.new()
# Visual randomness must not perturb the generator, enemy AI or combat rules.
var visual_rng := RandomNumberGenerator.new()
var player_visual_direction := Vector2.RIGHT
var player_roll_angle := 0.0
var blocked_feedback_time := 0.0
var blocked_feedback_pending := false
var blocked_feedback_direction := Vector2.RIGHT
var attack_feedback_time := 0.0
var attack_feedback_delay := 0.0
var impact_feedback_time := 0.0
var player_impact_kind := ""
var player_impact_direction := Vector2.LEFT
# Pickup facts during a resolved knockback remain immediate, while their cues
# follow the already-committed visual landing rather than preceding the hit.
var pickup_feedback_delay := -1.0
var turn_pulse_pending := false
var crate_visual_tracks: Dictionary = {}
var blocked_crate_index := -1
var blocked_crate_time := 0.0
var blocked_crate_pending := false
var blocked_crate_direction := Vector2.ZERO
var surface_reactions: Array[Dictionary] = []
var electric_visual_glow: Dictionary = {}
var enemy_defeat_visuals: Array[Dictionary] = []
var facing := Vector2i.RIGHT
var portal_position := Vector2i.ZERO
var portal_open := true
var enemies: Array[Dictionary] = []
var shields: Array[Vector2i] = []
var breakers: Array[Vector2i] = []
var powerups: Array[Dictionary] = []
var coins: Array[Vector2i] = []
var switches: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var room_graph_edges: Array[Dictionary] = []
var nav_chevrons: Array[Dictionary] = []
var player_sphere_texture: ImageTexture = null
var lia_sphere_texture: ImageTexture = null
var radial_light_texture: ImageTexture = null
var electric_presentation: Node2D
var particles: Array[Dictionary] = []
var camera: Camera2D
var hud: Control
var audio: Node
var controller
var feedback_bus: Node
var capture_overlay: ColorRect
var capture_material: ShaderMaterial
var background_rect: ColorRect
var terrain_renderer: Node2D
var generator = Generator.new()
var rng := RandomNumberGenerator.new()
var active_seed := 0
var generation_report := ""
var charges := 0
var breach_charges := 0
var speed_turns := 0
# Zero means the next speed-affected action prevents enemy movement.
var speed_phase := 0
var magnet_turns := 0
var freeze_turns := 0
var blink_charges := 0
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
var resume_charges := 0
var resume_breach_charges := 0
var resume_facing := Vector2i.RIGHT
var resume_seed := 0
var resume_history: Array[int] = []
var resume_powers: Dictionary = {}
var resume_hearts := 0
var hearts_current := 0
var heart_pickups: Array[Vector2i] = []
var shield_full_notice_turn := -1
var skills = SkillTree.new()
var campaign_storage = CampaignStorage.new()
var transient_campaigns: Array[Dictionary] = [{}, {}, {}]
var active_slot := 0 # 0-based, displayed as campaigns 1–3
var profile_blocked := false
var profile_message := ""
var legacy_profile_pending := false
var legacy_profile_hash := ""
var slot_select_mode := "select"
var slot_message := ""
var slot_pending := -1
var slot_pending_action := ""
var skill_return_state := "floor_clear"
var skill_branch := "vida"
var skill_selected := "heart_1"
var skill_message := ""
var skill_pending_remove := ""
var last_skill_point_awarded := false
var level_select_source := "title"
# Dictionary identity is stable within a floor without changing enemy data or RNG.
var unresolved_contacts: Array[Dictionary] = []
var dev_menu_open: bool = false
var dev_sandbox_active := false
var dev_profile_snapshot: Dictionary = {}
var dev_god_mode: bool = false
var dev_noclip: bool = false
var controller_vibration_enabled := true
var controller_vibration_intensity := ControllerScript.MAX_VIBRATION_INTENSITY
var controller_mappings: Dictionary = {}
var controller_return_state := "title"
var controller_message := ""
# Snapshot of the run at entry, used both by R and by the defeat checkpoint.
var floor_start_snapshot: Dictionary = {}
var persistence_enabled := true
var profile_path := "user://come_to_me_profile.cfg"
var flash_time := 0.0
var flash_color := Color.WHITE
var game_state := "ready"
# Persisted separately per campaign. The visual scene does not advance turns.
var captor_intro_seen := false
var captor_flyover_time := 0.0
var damage_this_turn := false
var objective_type := "escape"
var challenge_kind := "no_jump"
var challenge_par := 0
var challenge_complete := false
var best_score_dirty := false
var last_notice := ""
var notice_timer := 0.0
var floor_history: Array[int] = []
var level_page_start := 1
var animation_clock := 0.0
var shake_time := 0.0
var shake_strength := 0.0
var turn_pulse_time := -1.0
var turn_pulse_position := Vector2.ZERO
var landing_feedback_time := 0.0
var near_miss_feedback_time := 0.0
var visible_threat_distance := -1
var threat_aura := 0.0
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
	background_rect = ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = BackgroundShader
	background_rect.material = material
	background_layer.add_child(background_rect)
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	capture_overlay.visible = false
	capture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture_material = ShaderMaterial.new()
	capture_material.shader = CaptureOverlayShader
	capture_overlay.material = capture_material
	capture_layer.add_child(capture_overlay)
	capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controller = ControllerScript.new()
	add_child(controller)
	controller.action_requested.connect(_on_controller_action)
	controller.settings_changed.connect(_on_controller_settings_changed)
	controller.calibration_finished.connect(_on_controller_calibration_finished)
	controller.device_changed.connect(_on_controller_device_changed)
	audio = AudioScript.new()
	add_child(audio)
	feedback_bus = TacticalFeedbackScript.new()
	add_child(feedback_bus)
	feedback_bus.configure(audio, controller)
	feedback_bus.event_emitted.connect(_on_tactical_feedback)
	_init_player_sphere_texture()
	_init_radial_light_texture()
	electric_presentation = ElectricPresentation.new()
	electric_presentation.setup(self, radial_light_texture)
	add_child(electric_presentation)
	_load_profile()
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	add_child(camera)
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.setup(self)
	add_child(terrain_renderer)
	active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	generate_floor(1)
	game_state = "title"


func new_game(seed_value: int = -1) -> void:
	_leave_dev_sandbox()
	if persistence_enabled:
		campaign_storage.profile_path = profile_path
		if profile_blocked or campaign_storage.read_slot(active_slot).status not in ["empty", "ok"]:
			profile_message = "NAO E POSSIVEL SUBSTITUIR UM PERFIL DANIFICADO OU MAIS RECENTE."
			return
	lab_active = false
	if camera != null:
		camera.enabled = true
	if seed_value >= 0:
		active_seed = seed_value
	else:
		active_seed = int(Time.get_ticks_usec()) ^ randi()
	rng.seed = active_seed
	floor_history.clear()
	floor_number = 1
	# A confirmed new campaign starts a genuinely independent progression.
	best_score = 0
	best_score_dirty = false
	rescues_completed = 0
	captor_intro_seen = false
	captor_flyover_time = 0.0
	furthest_floor = 1
	floor_stars.clear()
	skills.load_state({})
	hearts_current = 0
	resume_hearts = 0
	last_skill_point_awarded = false
	charges = 0
	breach_charges = 0
	_restore_power_state({})
	total_coins = 0
	facing = Vector2i.RIGHT
	has_resume = false
	resume_floor = 1
	resume_coins = 0
	resume_charges = 0
	resume_breach_charges = 0
	resume_powers = _capture_power_state()
	resume_facing = facing
	resume_seed = active_seed
	resume_history.clear()
	_reset_capture_state()
	game_state = "playing"
	generate_floor(1)
	_save_resume(1, total_coins, charges, breach_charges, floor_history, facing)


func continue_game() -> void:
	_leave_dev_sandbox()
	if lab_active:
		_load_lab_chamber(lab_index)
		return
	if not has_resume:
		new_game()
		return
	active_seed = resume_seed
	total_coins = resume_coins
	floor_history = resume_history.duplicate()
	charges = resume_charges
	breach_charges = resume_breach_charges
	_restore_power_state(resume_powers)
	hearts_current = resume_hearts
	facing = resume_facing
	_reset_capture_state()
	generate_floor(resume_floor)
	game_state = "playing"
	_begin_captor_flyover_if_needed()


func start_level(number: int) -> void:
	_leave_dev_sandbox()
	if number < 1 or number > furthest_floor:
		return
	if not has_resume and number == 1 and furthest_floor == 1 and floor_stars.is_empty():
		new_game()
		return
	if has_resume and level_select_source in ["title", "game_over"]:
		# The running world at the title/defeat screen is not the checkpoint.
		active_seed = resume_seed
		total_coins = resume_coins
		charges = resume_charges
		breach_charges = resume_breach_charges
		_restore_power_state(resume_powers)
		hearts_current = resume_hearts
		floor_history.assign(resume_history)
		facing = resume_facing
	# From pause or a completed floor use the actual current inventory. Revisits
	# preserve the seed, skills, hearts, powers, resources and campaign journal.
	_reset_capture_state()
	generate_floor(number)
	game_state = "playing"
	_save_resume(number, total_coins, charges, breach_charges, floor_history, facing)
	_begin_captor_flyover_if_needed()


func _begin_captor_flyover_if_needed() -> void:
	captor_flyover_time = 0.0
	if floor_number != 5 or captor_intro_seen or lab_active:
		return
	captor_intro_seen = true
	captor_flyover_time = CAPTOR_FLYOVER_SECONDS
	last_notice = "LIA NA JAULA — O CAPTURADOR ATRAVESSA AS RUINAS!"
	notice_timer = CAPTOR_FLYOVER_SECONDS
	if audio != null:
		audio.play("captor_reveal")
	_save_profile()


func _finish_captor_flyover() -> void:
	captor_flyover_time = 0.0
	last_notice = "ENCONTRA LIA NO ANDAR 100"
	notice_timer = 2.0
	queue_redraw()


func _reset_capture_state() -> void:
	captor_flyover_time = 0.0
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
	damage_this_turn = false
	unresolved_contacts.clear()
	particles.clear()
	flash_time = 0.0
	shake_time = 0.0
	turn_pulse_time = -1.0
	turn_pulse_pending = false
	landing_feedback_time = 0.0
	blocked_feedback_time = 0.0
	blocked_feedback_pending = false
	attack_feedback_time = 0.0
	attack_feedback_delay = 0.0
	impact_feedback_time = 0.0
	crate_visual_tracks.clear()
	blocked_crate_index = -1
	blocked_crate_time = 0.0
	blocked_crate_pending = false
	surface_reactions.clear()
	electric_visual_glow.clear()
	if electric_presentation != null:
		electric_presentation.clear()
	enemy_defeat_visuals.clear()
	_flush_pending_impact_cues()
	impact_presentation.clear()
	player_impact_kind = ""
	pickup_feedback_delay = -1.0
	player_motion.reset(_cell_center(player_position))
	near_miss_feedback_time = 0.0
	threat_aura = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	if audio != null and audio.has_method("reset_cinematic_mix"):
		audio.reset_cinematic_mix()
	if capture_overlay != null:
		capture_overlay.visible = false


func restart_floor() -> void:
	if lab_active and game_state in ["playing", "paused", "game_over"]:
		_load_lab_chamber(lab_index)
		return
	if floor_start_snapshot.is_empty() or game_state not in ["playing", "paused"]:
		return
	# Copy before generate_floor replaces the snapshot. Do not call start_level:
	# it intentionally starts a fresh run with a new seed and no inventory.
	var snapshot := floor_start_snapshot.duplicate(true)
	active_seed = int(snapshot.seed)
	total_coins = int(snapshot.coins)
	charges = int(snapshot.charges)
	breach_charges = int(snapshot.breach_charges)
	_restore_power_state(snapshot.get("powers", {}))
	skills.load_state(snapshot.get("skills", skills.serialize()))
	hearts_current = clampi(int(snapshot.get("hearts", 0)), 0, skills.effect("heart_capacity"))
	floor_history.assign(snapshot.history)
	facing = snapshot.facing
	_reset_capture_state()
	game_state = "playing"
	generate_floor(int(snapshot.floor))
	_save_resume(floor_number, total_coins, charges, breach_charges, floor_history, facing)
	last_notice = "ANDAR REINICIADO — PROGRESSO ANTERIOR PRESERVADO"
	notice_timer = 2.5


func handle_hud_action(action: String) -> void:
	if captor_flyover_time > 0.0 and game_state == "playing":
		if action == "skip_captor_flyover":
			_finish_captor_flyover()
		return
	if action == "experimental":
		start_environment_lab()
	elif action == "new_run":
		slot_select_mode = "new"
		slot_message = "ESCOLHE UMA CAMPANHA. UMA OCUPADA EXIGE CONFIRMACAO."
		game_state = "campaign_select"
	elif action == "campaigns":
		slot_select_mode = "select"
		slot_message = "CADA CAMPANHA TEM PROGRESSO E BACKUP PROPRIOS."
		game_state = "campaign_select"
	elif action.begins_with("campaign:"):
		_request_campaign(int(action.trim_prefix("campaign:")))
	elif action.begins_with("campaign_restore:"):
		slot_pending = int(action.trim_prefix("campaign_restore:"))
		slot_pending_action = "restore"
		game_state = "campaign_confirm"
	elif action.begins_with("campaign_restore_replaced:"):
		slot_pending = int(action.trim_prefix("campaign_restore_replaced:"))
		slot_pending_action = "restore_replaced"
		game_state = "campaign_confirm"
	elif action == "profile_restore":
		slot_pending = -1
		slot_pending_action = "profile_restore"
		game_state = "campaign_confirm"
	elif action == "campaign_confirm":
		_confirm_campaign_action()
	elif action == "campaign_cancel":
		game_state = "campaign_select"
	elif action == "skills":
		_open_skills()
	elif action.begins_with("skill_branch:") and game_state == "skill_tree":
		var branch := action.trim_prefix("skill_branch:")
		var nodes: Array[Dictionary] = skills.branch_nodes(branch)
		if not nodes.is_empty():
			skill_branch = branch
			skill_selected = nodes[0].id
			skill_message = ""
	elif action.begins_with("skill_node:") and game_state == "skill_tree":
		var id := action.trim_prefix("skill_node:")
		var definition: Dictionary = skills.node(id)
		if not definition.is_empty() and definition.branch == skill_branch:
			skill_selected = id
			skill_message = ""
	elif action == "skill_unlock" and game_state == "skill_tree":
		_unlock_selected_skill()
	elif action == "skill_toggle" and game_state == "skill_tree":
		_request_skill_toggle()
	elif action == "skill_remove_confirm" and game_state == "skill_confirm":
		game_state = "skill_tree"
		_apply_skill_toggle(skill_pending_remove)
		skill_pending_remove = ""
	elif action == "skill_remove_cancel" and game_state == "skill_confirm":
		skill_pending_remove = ""
		game_state = "skill_tree"
	elif action == "skill_back" and game_state == "skill_tree":
		game_state = skill_return_state
	elif action == "continue":
		continue_game()
	elif action == "levels":
		open_level_select()
	elif action == "levels_previous":
		level_page_start = maxi(1, level_page_start - LEVELS_PER_PAGE)
		hud.focus_action = "floor:%d" % level_page_start
	elif action == "levels_next":
		level_page_start = mini(maxi(1, furthest_floor - LEVELS_PER_PAGE + 1), level_page_start + LEVELS_PER_PAGE)
		hud.focus_action = "floor:%d" % level_page_start
	elif action == "menu":
		_leave_dev_sandbox()
		lab_active = false
		environment.reset()
		capture_darkness = 0.0
		capture_flash = 0.0
		dev_menu_open = false
		game_state = "title"
	elif action == "resume":
		game_state = "playing"
	elif action == "pause":
		game_state = "paused"
	elif action == "next_floor":
		advance_floor()
	elif action == "restart_floor":
		restart_floor()
	elif action == "wait":
		wait_turn()
	elif action == "undo_sokoban":
		undo_sokoban_move()
	elif action == "blink":
		try_blink()
	elif action == "music":
		audio.toggle_music()
	elif action == "controller_settings":
		controller_return_state = "paused" if game_state == "paused" else "title"
		controller.select_active_device()
		controller_message = ""
		game_state = "controller_settings"
	elif action == "controller_device":
		controller_message = "COMANDO SELECIONADO" if controller.select_next_device() else "LIGA UM COMANDO PRIMEIRO"
	elif action == "controller_vibration":
		controller.set_vibration_enabled(not controller.vibration_enabled)
		controller_message = "VIBRACAO LIGADA" if controller.vibration_enabled else "VIBRACAO DESLIGADA"
	elif action.begins_with("controller_intensity:"):
		set_controller_vibration_intensity(float(action.trim_prefix("controller_intensity:")))
	elif action == "controller_test":
		if controller.selected_device < 0:
			controller_message = "LIGA UM COMANDO PRIMEIRO"
		elif not controller.vibration_enabled:
			controller_message = "LIGA A VIBRACAO ANTES DE TESTAR"
		elif controller.vibration_intensity <= 0.0:
			controller_message = "AUMENTA A INTENSIDADE ANTES DE TESTAR"
		elif controller.feedback("test", true, controller.selected_device):
			controller_message = "PULSO ENVIADO; A RESPOSTA DEPENDE DO COMANDO E DO SISTEMA"
	elif action == "controller_calibrate":
		if controller.begin_calibration(controller.selected_device):
			game_state = "controller_mapping"
		else:
			controller_message = "LIGA UM COMANDO PRIMEIRO"
	elif action == "controller_reset":
		controller_message = "MAPEAMENTO ORIGINAL RESTAURADO" if controller.clear_active_mapping(controller.selected_device) else "ESTE COMANDO JA USA O MAPEAMENTO ORIGINAL"
	elif action == "controller_skip":
		controller.skip_calibration_step()
	elif action == "controller_cancel_mapping":
		controller.cancel_calibration()
	elif action == "controller_back":
		game_state = controller_return_state
	elif action.begins_with("floor:"):
		start_level(int(action.trim_prefix("floor:")))
	elif action == "dev_toggle":
		dev_toggle_menu()
	elif action == "dev_god":
		dev_toggle_god_mode()
	elif action == "dev_noclip":
		dev_toggle_noclip()
	elif action == "dev_floor_minus_10":
		dev_jump_floor(floor_number - 10)
	elif action == "dev_floor_minus_1":
		dev_jump_floor(floor_number - 1)
	elif action == "dev_floor_plus_1":
		dev_jump_floor(floor_number + 1)
	elif action == "dev_floor_plus_10":
		dev_jump_floor(floor_number + 10)
	elif action.begins_with("dev_floor:"):
		dev_jump_floor(int(action.trim_prefix("dev_floor:")))
	elif action.begins_with("dev_spawn:"):
		dev_spawn_enemy(action.trim_prefix("dev_spawn:"))
	elif action == "dev_clear_mobs":
		dev_clear_enemies()
	elif action == "dev_resources":
		dev_give_resources()
	elif action == "dev_open_portal":
		dev_open_portal()
	elif action == "dev_arena":
		dev_load_sandbox_arena()
	queue_redraw()


func _request_campaign(slot: int) -> void:
	if slot < 0 or slot > 2:
		return
	if profile_blocked:
		slot_message = profile_message
		return
	var info := campaign_status(slot)
	if info.status not in ["ok", "empty"]:
		slot_message = "CAMPANHA %d INDISPONIVEL. O ORIGINAL NAO SERA SUBSTITUIDO." % (slot + 1)
		return
	if slot_select_mode == "new" and info.status == "ok":
		slot_pending = slot
		slot_pending_action = "new"
		game_state = "campaign_confirm"
		return
	if not select_campaign(slot):
		return
	if info.status == "empty":
		if profile_blocked:
			slot_message = profile_message
			return
		new_game()
	elif has_resume:
		continue_game()
	else:
		game_state = "title"


func _confirm_campaign_action() -> void:
	var action := slot_pending_action
	var slot := slot_pending
	game_state = "campaign_select"
	if action == "new":
		if not select_campaign(slot) or profile_blocked:
			slot_message = profile_message if profile_blocked else slot_message
			return
		# Save/migrate the old checkpoint before the confirmed replacement so the
		# per-campaign backup can recover it. Never replace on a failed write.
		if not _save_profile():
			slot_message = "NAO FOI POSSIVEL GUARDAR BACKUP; CAMPANHA INTACTA."
			return
		if persistence_enabled:
			campaign_storage.profile_path = profile_path
			var archive := campaign_storage.archive_before_new(slot)
			if not archive.ok:
				slot_message = str(archive.error)
				return
		new_game()
	elif action == "restore" or action == "restore_replaced":
		restore_campaign(slot, "replaced" if action == "restore_replaced" else "checkpoint")
	elif action == "profile_restore":
		campaign_storage.profile_path = profile_path
		var result := campaign_storage.restore_global()
		if result.ok:
			profile_blocked = false
			profile_message = ""
			legacy_profile_pending = false
			_load_profile()
			slot_message = "BACKUP GLOBAL RESTAURADO; FICHEIRO ANTERIOR ARQUIVADO."
		else:
			slot_message = str(result.error)
	slot_pending = -1
	slot_pending_action = ""


func _open_skills() -> void:
	if lab_active or not has_resume:
		return
	if game_state not in ["title", "floor_clear", "rescued", "paused"]:
		return
	if game_state == "paused" and turn_number != 0:
		last_notice = "ALTERA HABILIDADES ENTRE ANDARES, OU NO INICIO DO ANDAR."
		notice_timer = 2.5
		return
	if game_state == "title":
		hearts_current = resume_hearts
	skill_return_state = game_state
	skill_message = "ESCOLHE UM NO; DESBLOQUEAR E ATIVAR SAO ACOES SEPARADAS."
	game_state = "skill_tree"


func _save_skill_choice() -> void:
	resume_hearts = clampi(hearts_current, 0, skills.effect("heart_capacity"))
	if skill_return_state == "paused" and turn_number == 0 and not floor_start_snapshot.is_empty():
		floor_start_snapshot["skills"] = skills.serialize()
		floor_start_snapshot["hearts"] = resume_hearts
	if not _save_profile():
		skill_message = "NAO FOI POSSIVEL GUARDAR: " + profile_message


func _unlock_selected_skill() -> void:
	if profile_blocked:
		skill_message = profile_message
		return
	var result: Dictionary = skills.unlock(skill_selected)
	skill_message = str(result.message)
	if result.ok:
		_save_skill_choice()


func _request_skill_toggle() -> void:
	if profile_blocked:
		skill_message = profile_message
		return
	var definition: Dictionary = skills.node(skill_selected)
	if definition.is_empty():
		return
	if skills.active.has(skill_selected) and definition.effect == "heart_capacity" and hearts_current > skills.effect("heart_capacity") - 1:
		# A full heart would be discarded; require an explicit confirmation.
		for other in skills.NODES:
			if other.parent == skill_selected and skills.active.has(other.id):
				skill_message = "DESATIVA PRIMEIRO O NO DEPENDENTE"
				return
		skill_pending_remove = skill_selected
		game_state = "skill_confirm"
		return
	_apply_skill_toggle(skill_selected)


func _apply_skill_toggle(id: String) -> void:
	var result: Dictionary = skills.toggle(id)
	skill_message = str(result.message)
	if not result.ok:
		return
	hearts_current = mini(skills.effect("heart_capacity"), hearts_current + int(result.get("heart_credit", 0)))
	_save_skill_choice()


func _begin_dev_sandbox() -> bool:
	if dev_sandbox_active:
		return true
	# Preserve a legitimate unsaved record before isolating dev changes. If
	# saving fails, refuse the experiment rather than risk losing that record.
	if best_score_dirty and not _save_profile():
		last_notice = "TESTE DEV CANCELADO: NAO FOI POSSIVEL GUARDAR O RECORDE"
		notice_timer = 3.0
		return false
	dev_profile_snapshot = {
		"campaign": _campaign_payload().duplicate(true),
		"best_score_dirty": best_score_dirty,
		"floor_number": floor_number,
		"active_seed": active_seed,
		"coins": total_coins,
		"charges": charges,
		"breach_charges": breach_charges,
		"powers": _capture_power_state(),
		"hearts": hearts_current,
		"history": floor_history.duplicate(),
		"facing": facing,
		"god": dev_god_mode,
		"noclip": dev_noclip,
	}
	dev_sandbox_active = true
	return true


func _leave_dev_sandbox() -> void:
	if not dev_sandbox_active:
		return
	var saved := dev_profile_snapshot
	_apply_campaign_payload(saved.campaign)
	best_score_dirty = bool(saved.best_score_dirty)
	floor_number = int(saved.floor_number)
	active_seed = int(saved.active_seed)
	total_coins = int(saved.coins)
	charges = int(saved.charges)
	breach_charges = int(saved.breach_charges)
	_restore_power_state(saved.powers)
	hearts_current = int(saved.hearts)
	floor_history.assign(saved.history)
	facing = saved.facing
	dev_god_mode = bool(saved.god)
	dev_noclip = bool(saved.noclip)
	dev_sandbox_active = false
	dev_profile_snapshot = {}


func dev_toggle_menu() -> void:
	dev_menu_open = not dev_menu_open
	last_notice = "MENU DEV: %s [F1]" % ("ABERTO" if dev_menu_open else "FECHADO")
	notice_timer = 2.0
	queue_redraw()


func dev_toggle_god_mode() -> void:
	if not _begin_dev_sandbox():
		return
	dev_god_mode = not dev_god_mode
	last_notice = "MODO DEUS: %s" % ("ATIVADO (IMORTAL)" if dev_god_mode else "DESATIVADO")
	notice_timer = 2.0
	queue_redraw()


func dev_toggle_noclip() -> void:
	if not _begin_dev_sandbox():
		return
	dev_noclip = not dev_noclip
	last_notice = "NO-CLIP: %s" % ("ATIVADO (ATRAVESSA PAREDES)" if dev_noclip else "DESATIVADO")
	notice_timer = 2.0
	queue_redraw()


func dev_jump_floor(target_floor: int) -> void:
	if not _begin_dev_sandbox():
		return
	target_floor = clampi(target_floor, 1, 200)
	floor_number = target_floor
	generate_floor(target_floor)
	game_state = "playing"
	dev_menu_open = false
	last_notice = "TELEPORTE DEV: ANDAR %02d" % target_floor
	notice_timer = 2.5
	queue_redraw()


func dev_spawn_enemy(role: String) -> void:
	if not _begin_dev_sandbox():
		return
	var spawn_pos: Vector2i = player_position + facing
	if not _is_floor(spawn_pos) or _enemy_at(spawn_pos):
		spawn_pos = Vector2i(-1, -1)
		for dir in FOUR_WAY:
			var cand: Vector2i = player_position + dir
			if _is_floor(cand) and not _enemy_at(cand):
				spawn_pos = cand
				break
	if spawn_pos == Vector2i(-1, -1):
		last_notice = "SEM CASA LIVRE PARA O INIMIGO"
		notice_timer = 2.0
		return
	var enemy: Dictionary
	if role == "warden":
		enemy = _make_warden(spawn_pos)
	elif role == "chess_boss":
		enemy = _make_boss(spawn_pos)
	else:
		enemy = _make_enemy(spawn_pos, role)
	enemies.append(enemy)
	_spawn_burst(_cell_center(spawn_pos), Color("ff59c7"), 20, 120.0)
	last_notice = "SPAWN DEV: %s" % role.to_upper()
	notice_timer = 2.0
	_update_enemy_intents()
	queue_redraw()


func dev_clear_enemies() -> void:
	if not _begin_dev_sandbox():
		return
	enemies.clear()
	last_notice = "INIMIGOS ELIMINADOS"
	notice_timer = 2.0
	queue_redraw()


func dev_give_resources() -> void:
	if not _begin_dev_sandbox():
		return
	total_coins += 10
	charges = maxi(charges, mini(charges + 1, shield_capacity()))
	breach_charges = maxi(breach_charges, mini(breach_charges + 1, 3))
	blink_charges += 1
	last_notice = "RECURSOS CONCEDIDOS (+10 MOEDAS, ESCUDO, DEMOLICAO E BLINK)"
	notice_timer = 2.5
	_emit_feedback("COIN_PICKUP")
	queue_redraw()


func dev_open_portal() -> void:
	if not _begin_dev_sandbox():
		return
	portal_open = true
	last_notice = "PORTAL DESTRANCADO"
	notice_timer = 2.5
	_spawn_shockwave(_cell_center(portal_position), 10.0, 60.0, Color("c37aff"), 0.5)
	queue_redraw()


func dev_load_sandbox_arena() -> void:
	if not _begin_dev_sandbox():
		return
	sokoban_history.clear()
	sokoban_pushes = 0
	special_family = ""
	special_hint = ""
	special_spec.clear()
	special_route_cache.clear()
	lab_active = false
	_clear_transient_motion_effects()
	environment.reset()
	world_size = Vector2i(18, 14)
	grid.clear()
	for y in world_size.y:
		var row: Array[int] = []
		for x in world_size.x:
			if x == 0 or x == world_size.x - 1 or y == 0 or y == world_size.y - 1:
				row.append(TILE_BORDER)
			else:
				row.append(TILE_FLOOR)
		grid.append(row)
	player_position = Vector2i(9, 7)
	_reset_player_visual(_cell_center(player_position))
	portal_position = Vector2i(15, 7)
	portal_open = true
	objective_type = "escape"
	challenge_kind = "no_hit"
	challenge_par = 0
	challenge_complete = false
	environment_bonus_available = false
	environment_bonus_claimed = false
	turn_number = 0
	moves_this_floor = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	coins_spawned_this_floor = 0
	rooms.clear()
	room_graph_edges.clear()
	enemies.clear()
	enemies.append({"pos": Vector2i(5, 5), "from": _cell_center(Vector2i(5, 5)), "to": _cell_center(Vector2i(5, 5)), "next": Vector2i(5, 5), "t": 1.0, "role": "hunter", "phase": 0})
	enemies.append({"pos": Vector2i(13, 5), "from": _cell_center(Vector2i(13, 5)), "to": _cell_center(Vector2i(13, 5)), "next": Vector2i(13, 5), "t": 1.0, "role": "sentry", "phase": 0})
	enemies.append({"pos": Vector2i(5, 9), "from": _cell_center(Vector2i(5, 9)), "to": _cell_center(Vector2i(5, 9)), "next": Vector2i(5, 9), "t": 1.0, "role": "wisp", "phase": 0})
	enemies.append({"pos": Vector2i(13, 9), "from": _cell_center(Vector2i(13, 9)), "to": _cell_center(Vector2i(13, 9)), "next": Vector2i(13, 9), "t": 1.0, "role": "rusher", "phase": 0})
	coins.clear()
	shields.clear()
	heart_pickups.clear()
	breakers.clear()
	powerups.clear()
	switches.clear()
	traps.clear()
	nav_chevrons.clear()
	_restore_power_state({})
	charges = 2
	breach_charges = 2
	game_state = "playing"
	dev_menu_open = false
	last_notice = "SALA DE TESTES DEV CARREGADA (ARENA LIMPA)"
	notice_timer = 3.0
	_update_enemy_intents()
	_update_camera(1.0)
	if terrain_renderer != null:
		terrain_renderer.rebuild()
	queue_redraw()


func _trigger_shake(time: float, strength: float) -> void:
	# A completed heavy impact must not make the next light touch heavy too.
	shake_strength = maxf(shake_strength, strength) if shake_time > 0.0 else strength
	shake_time = maxf(shake_time, time)


func _handle_world_click(screen_pos: Vector2) -> void:
	if game_state != "playing" or camera == null:
		return
	var viewport := get_viewport_rect().size
	var world_pos := camera.global_position - (viewport * 0.5) + screen_pos
	var cell := Vector2i(int(floor(world_pos.x / CELL)), int(floor(world_pos.y / CELL)))
	var diff := cell - player_position
	if diff in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		facing = diff
		try_move(diff.x, diff.y)
	elif diff in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]:
		facing = diff / 2
		try_jump()


func _handle_swipe(start_pos: Vector2, end_pos: Vector2) -> void:
	if game_state != "playing":
		return
	var diff := end_pos - start_pos
	if diff.length() < 30.0:
		return
	if absf(diff.x) > absf(diff.y):
		facing = Vector2i(signi(diff.x), 0)
		try_move(signi(diff.x), 0)
	else:
		facing = Vector2i(0, signi(diff.y))
		try_move(0, signi(diff.y))


func open_level_select() -> void:
	if dev_sandbox_active:
		_leave_dev_sandbox()
		game_state = "title"
	level_select_source = game_state
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


func _save_resume(number: int, coins: int, shield_charges: int = 0, demolition_charges: int = 0, history: Variant = null, start_facing: Vector2i = Vector2i.RIGHT, powers: Variant = null) -> void:
	has_resume = true
	resume_floor = maxi(1, number)
	resume_coins = maxi(0, coins)
	resume_charges = maxi(0, shield_charges)
	resume_breach_charges = maxi(0, demolition_charges)
	resume_hearts = clampi(hearts_current, 0, skills.effect("heart_capacity"))
	resume_powers = _normalized_power_state(_capture_power_state() if powers == null else powers)
	resume_facing = start_facing if start_facing in FOUR_WAY else Vector2i.RIGHT
	resume_seed = active_seed
	var saved_history: Array = (floor_history if history == null else history).duplicate()
	resume_history.clear()
	for value in saved_history:
		resume_history.append(int(value))
	_save_profile()


func _capture_power_state() -> Dictionary:
	return {"speed_turns": speed_turns, "speed_phase": speed_phase, "magnet_turns": magnet_turns,
		"freeze_turns": freeze_turns, "blink_charges": blink_charges}


func _normalized_power_state(raw: Variant) -> Dictionary:
	var state: Dictionary = raw if raw is Dictionary else {}
	var speed := maxi(0, int(state.get("speed_turns", 0)))
	return {"speed_turns": speed, "speed_phase": posmod(int(state.get("speed_phase", 0)), 2) if speed > 0 else 0,
		"magnet_turns": maxi(0, int(state.get("magnet_turns", 0))),
		"freeze_turns": maxi(0, int(state.get("freeze_turns", 0))),
		"blink_charges": maxi(0, int(state.get("blink_charges", 0)))}


func _restore_power_state(raw: Variant) -> void:
	var state := _normalized_power_state(raw)
	speed_turns = state.speed_turns
	speed_phase = state.speed_phase
	magnet_turns = state.magnet_turns
	freeze_turns = state.freeze_turns
	blink_charges = state.blink_charges


# Experimental chambers deliberately bypass campaign generation/checkpoints.
# They use the same actions, collision, hazards and portal loop as normal play.
func start_environment_lab() -> void:
	_leave_dev_sandbox()
	lab_active = true
	_load_lab_chamber(0)


func _load_lab_chamber(index: int) -> void:
	sokoban_history.clear()
	sokoban_pushes = 0
	special_family = ""
	special_hint = ""
	special_spec.clear()
	special_route_cache.clear()
	lab_active = true
	lab_index = clampi(index, 0, EnvironmentChambers.COUNT - 1)
	environment_bonus_available = false
	environment_bonus_claimed = false
	var spec: Dictionary = EnvironmentChambers.chamber(lab_index)
	lab_name = spec.name
	lab_hint = spec.hint
	floor_number = [2, 2, 4, 1][lab_index]
	world_size = spec.size
	grid.clear()
	for y in world_size.y:
		var row: Array[int] = []
		for x in world_size.x:
			row.append(TILE_BORDER if x == 0 or y == 0 or x == world_size.x - 1 or y == world_size.y - 1 else TILE_FLOOR)
		grid.append(row)
	for wall in spec.walls:
		grid[wall.y][wall.x] = TILE_WALL
	for point in spec.cells:
		grid[point.y][point.x] = TILE_WATER
	environment.reset(spec)
	player_position = spec.start
	_reset_player_visual(_cell_center(player_position))
	facing = Vector2i.RIGHT
	portal_position = spec.portal
	enemies.clear()
	shields.clear()
	heart_pickups.clear()
	breakers.clear()
	powerups.clear()
	coins.clear()
	switches.clear()
	traps.assign(spec.traps.duplicate(true))
	rooms.clear()
	room_graph_edges.clear()
	nav_chevrons.clear()
	charges = 0
	breach_charges = 0
	_restore_power_state({})
	objective_type = "environment"
	turn_number = 0
	moves_this_floor = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	coins_spawned_this_floor = 0
	challenge_complete = false
	dev_god_mode = false
	dev_noclip = false
	dev_menu_open = false
	_reset_capture_state()
	game_state = "playing"
	_sync_environment_mechanisms()
	last_notice = lab_hint
	notice_timer = 5.0
	_update_enemy_intents()
	_update_camera(0.0)
	if terrain_renderer != null:
		terrain_renderer.rebuild()
	queue_redraw()


func _crate_destination_free(point: Vector2i) -> bool:
	return point != player_position and _is_floor(point) and not _enemy_at(point)


func _sync_environment_mechanisms() -> void:
	var enemy_positions: Array[Vector2i] = []
	for enemy in enemies:
		enemy_positions.append(enemy.pos)
	var active: bool = environment.update_mechanisms(player_position, enemy_positions)
	if environment_bonus_available and not environment_bonus_claimed and active and charges < shield_capacity():
		environment_bonus_claimed = true
		charges += 1
		last_notice = "PLACA DA CORRENTE ATIVADA — ESCUDO +1"
		notice_timer = 2.8
		_spawn_burst(_cell_center(environment.plates[0].pos), Color("81f4d0"), 12, 90.0)
		_emit_feedback("SHIELD_PICKUP")
	if objective_type == "environment":
		var was_open := portal_open
		portal_open = active
		if portal_open and not was_open:
			last_notice = "PLACAS ATIVAS — PORTAL ABERTO"
			notice_timer = 2.0
			_emit_feedback("PORTAL_OPEN")


# Resolve a single environmental displacement after the entry cell. Hazards,
# pickups and contacts are resolved on both cells before enemy movement.
func _resolve_environment_displacement(action_direction: Vector2i) -> void:
	var surface: String = environment.kind_at(player_position)
	if (surface == "ice" and _skill_effect("ice_grip") > 0) or (surface == "current" and (freeze_turns > 0 or _skill_effect("current_anchor") > 0)):
		return
	var direction: Vector2i = environment.forced_direction(player_position, action_direction)
	if direction == Vector2i.ZERO or _enemy_at(player_position):
		return
	var destination := player_position + direction
	if not _is_floor(destination) or _enemy_at(destination):
		return
	var movement_surface: String = environment.kind_at(player_position)
	_begin_player_move(destination, movement_surface)
	if movement_surface == "current":
		_emit_feedback("CURRENT_DRIFT")
	# The semantic event was already emitted; align only its visual ring with
	# the actual final cell, including a current that moves a waiting player.
	turn_pulse_position = _cell_center(player_position)
	turn_pulse_time = -0.001
	turn_pulse_pending = true
	last_notice = "CORRENTE: +1 CASA" if environment.kind_at(player_position - direction) == "current" else "GELO: +1 CASA"
	notice_timer = 1.2
	_collect_pickups()
	_trigger_traps(direction)
	if game_state == "playing" and freeze_turns <= 0 and environment.is_electrified(player_position):
		_apply_damage("AGUA ELETRIFICADA!", Color("ffe46a"), -direction)
	if game_state != "playing":
		return
	_activate_switches()
	_sync_environment_mechanisms()
	_check_enemy_collision(direction)


func _stress_brittle_ice(visited: Array[Vector2i]) -> void:
	for point in environment.stress_brittle(visited):
		_spawn_burst(_cell_center(point), Color("b5f5ff"), 12, 104.0)
		last_notice = "GELO FRAGIL PARTIU — JA NAO DESLIZA"
		notice_timer = 1.8
		_emit_feedback("ICE_CRACK")


# Water hazards affect enemies too. Ordinary enemies are defeated; elites lose
# one HP per committed turn. The resolution is after contact/crossing checks.
func _resolve_electrified_enemies() -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		if not environment.is_electrified(enemy.pos):
			continue
		var contact_delay := _enemy_contact_delay(enemy)
		var contact_point := _cell_center(enemy.pos)
		if _is_elite(enemy):
			enemy["hp"] = maxi(0, int(enemy.get("hp", 1)) - 1)
			if enemy.hp > 0:
				enemy["_visual_reaction"] = 0.0
				enemy["_visual_reaction_delay"] = contact_delay
				enemy["_visual_reaction_direction"] = Vector2.UP
				enemies[index] = enemy
				_queue_contact_feedback("", "electric", contact_point, Vector2.UP, contact_delay, "electricity", "", false)
				continue
		_record_enemy_defeat(enemy, "electricity", contact_delay)
		_queue_contact_feedback("", "electric", contact_point, Vector2.UP, contact_delay, "electricity", "", false)
		enemies.remove_at(index)


# Authored surfaces override the legacy biome-based water/ice appearance.
func _surface_kind(point: Vector2i) -> String:
	if not environment.cells.is_empty():
		var explicit: String = environment.kind_at(point)
		if explicit != "":
			return explicit
	return "ice" if get_biome_index(floor_number) == 3 else "water"


# Try a straight, four-cell push in an otherwise connected existing map. No
# RNG is consumed. The original floor must remain connected with BOTH the
# current and either crate position treated as blocked. Thus the existing
# objectives never depend on fighting a one-way current to cross a bottleneck.
# If no candidate is safe, omit it rather than damaging the generated floor.
func _place_environment_bonus(walkable: Array[Vector2i], occupied: Dictionary) -> void:
	var candidates := walkable.duplicate()
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _manhattan(a, player_position)
		var db := _manhattan(b, player_position)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x)
	)
	for crate_pos in candidates:
		for direction in FOUR_WAY:
			var approach: Vector2i = crate_pos - direction
			var current: Vector2i = crate_pos + direction
			var plate: Vector2i = current + direction
			var clear := true
			for point in [approach, crate_pos, current, plate]:
				if not _inside(point) or grid[point.y][point.x] != TILE_FLOOR or occupied.has(point):
					clear = false
					break
			if not clear:
				continue
			var spec := {"crates": [{"pos": crate_pos, "material": "wood"}],
				"plates": [{"pos": plate, "required": "wood"}],
				"cells": {current: {"kind": "current", "flow": direction}, plate: {"kind": "water"}}}
			environment.reset(spec)
			if _reachable_without_cell(player_position, current) != walkable.size() - 2:
				continue
			environment.crates[0].pos = plate
			var connected_after: bool = _reachable_without_cell(player_position, current) == walkable.size() - 2
			environment.crates[0].pos = crate_pos
			if not connected_after:
				continue
			grid[current.y][current.x] = TILE_WATER
			grid[plate.y][plate.x] = TILE_WATER
			environment_bonus_available = true
			generation_report += "; corrente opcional validada"
			return
	environment.reset()


# Optional brittle ice on a legacy ice patch. Avoiding the cell must still
# leave the complete reachable area connected, so it cannot gate progression.
# Deterministic scan consumes no WFC or enemy RNG and adds no new grid layer.
func _place_brittle_ice(occupied: Dictionary) -> void:
	if get_biome_index(floor_number) != 3:
		return
	var reachable := _reachable_cells(player_position)
	for point in reachable:
		if grid[point.y][point.x] != TILE_WATER or occupied.has(point) or environment.kind_at(point) != "":
			continue
		if _manhattan(point, player_position) < 3 or _manhattan(point, portal_position) < 3:
			continue
		if _reachable_without_cell(player_position, point) != reachable.size() - 1:
			continue
		environment.cells[point] = {"kind": "ice", "brittle": true, "stress": 0, "broken": false}
		generation_report += "; gelo fragil opcional"
		return


func generate_floor(number: int) -> void:
	sokoban_history.clear()
	sokoban_pushes = 0
	# A previous cinematic cannot leak into a newly generated floor. Entry
	# points explicitly start the floor-five flyover after generation.
	captor_flyover_time = 0.0
	lab_active = false
	_clear_transient_motion_effects()
	environment.reset()
	environment_bonus_available = false
	environment_bonus_claimed = false
	floor_number = maxi(1, number)
	world_size = get_floor_size(floor_number)
	var level_seed := active_seed + number * 7919
	rng.seed = level_seed
	visual_rng.seed = level_seed ^ 0x5a17c3
	floor_start_snapshot = {
		"floor": floor_number, "seed": active_seed, "coins": total_coins,
		"charges": charges, "breach_charges": breach_charges, "powers": _capture_power_state(),
		"hearts": hearts_current, "skills": skills.serialize(),
		"history": floor_history.duplicate(), "facing": facing,
	}
	special_family = special_schedule.family_for(active_seed, floor_number)
	special_hint = ""
	special_spec.clear()
	special_route_cache.clear()
	if special_family in ["sokoban", "mechanism", "circuit"]:
		var candidate: Dictionary = SpecialLevels.make(special_family, active_seed, floor_number)
		var template_key := str([candidate.size, candidate.start, candidate.portal, candidate.walls, candidate.cells, candidate.crates, candidate.plates, candidate.gates])
		var initial_plan: Dictionary
		if special_template_plans.has(template_key):
			initial_plan = special_template_plans[template_key].duplicate(true)
		else:
			initial_plan = SpecialLevels.solve(candidate, candidate.start, candidate.crates)
			if int(initial_plan.length) >= 0:
				special_template_plans[template_key] = initial_plan.duplicate(true)
		if int(initial_plan.length) >= 0:
			_generate_special_room(candidate, initial_plan, level_seed)
			return
		# Never put an unverified or search-truncated room into the campaign.
		push_warning("Special room could not be verified; using WFC floor instead")
		special_family = ""
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
	_reset_player_visual(_cell_center(player_position))
	enemies.clear()
	shields.clear()
	heart_pickups.clear()
	breakers.clear()
	powerups.clear()
	coins.clear()
	switches.clear()
	traps.clear()
	var puzzle_floor := special_family == "sequence"
	var quiet_floor := special_family in ["switches", "quiet"]
	var required_switches := 0
	if puzzle_floor or special_family in ["switches", "hybrid"]:
		required_switches = 3
	elif special_family == "quiet":
		required_switches = 0
	elif number >= 2 and (number % 3 != 1 or number == 4):
		required_switches = mini(1 + number / 2, 4)
	objective_type = "puzzle" if puzzle_floor else "switches" if required_switches > 0 else "escape"
	portal_open = required_switches == 0
	var occupied := {player_position: true, portal_position: true}
	var walkable := _reachable_cells(player_position)
	if puzzle_floor:
		_place_puzzle_switches(walkable, occupied)
	else:
		for i in required_switches:
			var position: Vector2i = _pick_spaced(walkable, occupied, 7)
			if position != Vector2i(-1, -1):
				switches.append({"pos": position, "active": false})
				occupied[position] = true
		for i in (0 if quiet_floor else mini(1 + int(number / 2), 7)):
			var position: Vector2i = _pick_spaced(walkable, occupied, 5)
			if position != Vector2i(-1, -1):
				var role := "hunter"
				if number >= 2 and i % 3 == 1:
					role = "sentry"
				elif number >= 4 and i % 3 == 2:
					role = "wisp"
				if number >= 6 and i % 4 == 3:
					role = "patrol"
				if number >= 7 and i % 5 == 2:
					role = "mirror"
				if number >= 10 and i % 6 == 5:
					role = "rusher"
				enemies.append(_make_enemy(position, role))
				occupied[position] = true
		# The original Guardian keeps its own body and behavior as a mini-boss.
		if number % 5 == 4:
			var warden_position: Vector2i = _pick_spaced(walkable, occupied, 9)
			if warden_position != Vector2i(-1, -1):
				enemies.append(_make_warden(warden_position))
				occupied[warden_position] = true
		if number % 5 == 0:
			var boss_position: Vector2i = _pick_spaced(walkable, occupied, 9)
			if boss_position != Vector2i(-1, -1):
				enemies.append(_make_boss(boss_position))
				occupied[boss_position] = true
	# Reserve the hybrid's obstacle before loot fills a large late-game map.
	# The candidate checks connectivity with both the original and moved box.
	if special_family == "hybrid":
		_place_environment_bonus(walkable, occupied)
		if environment.crates.is_empty():
			_place_hybrid_obstacle(walkable, occupied)
		if environment.crates.is_empty():
			# Never claim a hybrid when it has no interactive obstacle.
			generation_report += "; hibrido omitido: sem celula segura"
			special_family = ""
		else:
			for item in environment.crates:
				occupied[item.pos] = true
			for item in environment.plates:
				occupied[item.pos] = true
			for point in environment.cells:
				occupied[point] = true
	for i in rng.randi_range(2, 4):
		var position: Vector2i = _pick_spaced(walkable, occupied, 2)
		if position != Vector2i(-1, -1):
			shields.append(position)
			occupied[position] = true
	if (number == 1 or number >= 3) and number % 2 == 1:
		var breaker_position: Vector2i = _pick_spaced(walkable, occupied, 6)
		if breaker_position != Vector2i(-1, -1):
			breakers.append(breaker_position)
			occupied[breaker_position] = true
	# Cycle all four abilities across successive floors; the cell is unique and
	# reachable, just like all other pickups.
	var power_position: Vector2i = _pick_spaced(walkable, occupied, 3)
	if power_position != Vector2i(-1, -1):
		powerups.append({"pos": power_position, "kind": POWERUP_TYPES[posmod(number - 1, POWERUP_TYPES.size())]})
		occupied[power_position] = true
	_place_coins(walkable, occupied, 8 + number)
	coins_spawned_this_floor = coins.size()
	# Puzzle floors contain neither enemies nor traps: the sequence itself is
	# the challenge. Other floors introduce visible recurring rhythm hazards.
	if number >= 3 and not puzzle_floor and not quiet_floor:
		for i in mini(1 + number / 4, 3):
			var position: Vector2i = _pick_spaced(walkable, occupied, 4)
			if position != Vector2i(-1, -1):
				if i % 2 == 0:
					traps.append({"pos": position, "type": "rhythm", "phase": rng.randi_range(0, 2), "armed": true, "revealed": true})
				else:
					traps.append({"pos": position, "type": "one_shot", "armed": true, "revealed": false})
				occupied[position] = true
	# Selected non-puzzle floors get an optional, solvability-checked landmark.
	# Existing enemies, switches, routes and the main portal are not replaced.
	if number >= 6 and number % 20 == 6:
		_place_environment_bonus(walkable, occupied)
	if special_family == "hybrid":
		special_hint = "OS PERSEGUIDORES CONTORNAM CAIXAS; ATIVA OS TRES INTERRUPTORES."
	elif special_family == "switches":
		special_hint = "ATIVA OS TRES INTERRUPTORES, EM QUALQUER ORDEM."
	elif special_family == "quiet":
		special_hint = "SETOR TRANQUILO: EXPLORA E ALCANCA O PORTAL."
	_place_heart_pickup(number, occupied)
	for point in heart_pickups:
		occupied[point] = true
	_place_brittle_ice(occupied)
	_build_nav_chevrons()
	moves_this_floor = 0
	turn_number = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	var route_length := _estimate_route_length()
	challenge_par = ceili(float(route_length) * 1.3) + 4 if route_length >= 0 else 0
	var available_challenges := CHALLENGE_KINDS.duplicate()
	if route_length < 0:
		available_challenges.erase("moves")
	challenge_kind = available_challenges[rng.randi_range(0, available_challenges.size() - 1)]
	challenge_complete = false
	last_notice = "%s   /   seed %d" % [get_challenge_text(), level_seed]
	notice_timer = 3.8
	_update_enemy_intents()
	_update_camera(1.0)
	if terrain_renderer != null:
		terrain_renderer.rebuild()
	queue_redraw()


# A special chamber is a designed, validated exception; the normal campaign
# and all reserved boss/warden floors continue to use the WFC generator.
func _generate_special_room(spec: Dictionary, initial_plan: Dictionary, level_seed: int) -> void:
	sokoban_history.clear()
	sokoban_pushes = 0
	special_spec = spec.duplicate(true)
	special_route_cache.clear()
	_cache_special_route(spec.start, spec.crates, initial_plan)
	special_hint = str(spec.hint)
	generation_report = "CAMARA %s; seed %d; rota segura %d" % [str(spec.name), level_seed, int(initial_plan.length)]
	world_size = spec.size
	grid.clear()
	for y in world_size.y:
		var row: Array[int] = []
		for x in world_size.x:
			row.append(TILE_BORDER if x == 0 or y == 0 or x == world_size.x - 1 or y == world_size.y - 1 else TILE_FLOOR)
		grid.append(row)
	for wall in spec.walls:
		grid[wall.y][wall.x] = TILE_WALL
	for point in spec.cells:
		grid[point.y][point.x] = TILE_WATER
	environment.reset(spec)
	player_position = spec.start
	portal_position = spec.portal
	_reset_player_visual(_cell_center(player_position))
	enemies.clear()
	shields.clear()
	heart_pickups.clear()
	breakers.clear()
	powerups.clear()
	coins.clear()
	switches.clear()
	traps.clear()
	rooms.clear()
	room_graph_edges.clear()
	nav_chevrons.clear()
	objective_type = "environment"
	portal_open = false
	_sync_environment_mechanisms()
	var occupied := {player_position: true, portal_position: true}
	for group in [environment.crates, environment.plates, environment.gates]:
		for item in group:
			occupied[item.pos] = true
	for point in environment.cells:
		occupied[point] = true
	var walkable := _reachable_cells(player_position)
	for _i in 2:
		var point: Vector2i = _pick_spaced(walkable, occupied, 2)
		if point != Vector2i(-1, -1):
			shields.append(point)
			occupied[point] = true
	var power_position: Vector2i = _pick_spaced(walkable, occupied, 1)
	if power_position != Vector2i(-1, -1):
		powerups.append({"pos": power_position, "kind": POWERUP_TYPES[posmod(floor_number - 1, POWERUP_TYPES.size())]})
		occupied[power_position] = true
	_place_coins(walkable, occupied, 8 + floor_number)
	coins_spawned_this_floor = coins.size()
	_place_heart_pickup(floor_number, occupied)
	moves_this_floor = 0
	turn_number = 0
	jumps_this_floor = 0
	hits_this_floor = 0
	coins_this_floor = 0
	var route_length := int(initial_plan.length)
	challenge_par = ceili(float(route_length) * 1.3) + 4
	challenge_kind = CHALLENGE_KINDS[rng.randi_range(0, CHALLENGE_KINDS.size() - 1)]
	challenge_complete = false
	last_notice = special_hint + "  /  R REINICIA O ANDAR"
	notice_timer = 5.0
	_update_enemy_intents()
	_update_camera(1.0)
	if terrain_renderer != null:
		terrain_renderer.rebuild()
	queue_redraw()


func _special_state_key(player: Vector2i, boxes: Array) -> String:
	var key := "%d,%d" % [player.x, player.y]
	for box in boxes:
		key += ";%d,%d:%s" % [box.pos.x, box.pos.y, str(box.material)]
	return key


func _cache_special_route(start: Vector2i, boxes: Array, plan: Dictionary) -> void:
	if int(plan.length) < 0:
		return
	var player := start
	var simulated: Array = boxes.duplicate(true)
	var path: Array = plan.path
	for index in range(path.size() + 1):
		var remaining: Array = path.slice(index)
		special_route_cache[_special_state_key(player, simulated)] = {"length": remaining.size(), "step": remaining[0] if not remaining.is_empty() else Vector2i.ZERO, "path": remaining, "truncated": false}
		if index == path.size():
			break
		var direction: Vector2i = path[index]
		var next := player + direction
		for box in simulated:
			if box.pos == next:
				box.pos += direction
				break
		player = next


func _plan_environment_route() -> Dictionary:
	if special_spec.is_empty():
		return {"length": -1, "step": Vector2i.ZERO, "path": [], "truncated": false}
	# Reuse verified states on the route; off-route boards are solved afresh.
	var key := _special_state_key(player_position, environment.crates)
	if special_route_cache.has(key):
		return special_route_cache[key]
	var plan: Dictionary = SpecialLevels.solve(special_spec, player_position, environment.crates)
	_cache_special_route(player_position, environment.crates, plan)
	return plan


func _place_hybrid_obstacle(walkable: Array[Vector2i], occupied: Dictionary) -> void:
	# A crate occupies a non-critical cell: removing that cell must leave every
	# other original floor cell connected, including all switches and the exit.
	for point in walkable:
		if occupied.has(point) or _manhattan(point, player_position) < 3:
			continue
		environment.reset({"crates": [{"pos": point, "material": "wood"}]})
		if _reachable_cells(player_position).size() == walkable.size() - 1:
			occupied[point] = true
			generation_report += "; caixa tatica validada"
			return
	environment.reset()


func get_challenge_text() -> String:
	match challenge_kind:
		"no_jump": return "Atravessa sem saltar"
		"no_hit": return "Chega ao portal sem sofrer dano"
		"moves": return "Escapa em ate %d acoes (%d/%d)" % [challenge_par, moves_this_floor, challenge_par]
		"all_coins": return "Apanha todas as moedas (%d restantes)" % coins.size()
	return ""


func is_challenge_failed() -> bool:
	match challenge_kind:
		"no_jump": return jumps_this_floor > 0
		"no_hit": return hits_this_floor > 0
		"moves": return moves_this_floor > challenge_par
	return false


func is_challenge_met() -> bool:
	match challenge_kind:
		"no_jump": return jumps_this_floor == 0
		"no_hit": return hits_this_floor == 0
		"moves": return moves_this_floor <= challenge_par
		"all_coins": return coins_spawned_this_floor > 0 and coins.is_empty()
	return false


# Pick three ordered runes, rejecting placements whose sequence cannot be
# solved. Merely checking connectivity is insufficient: a future rune can
# block a corridor and reset the sequence when crossed.
func _place_puzzle_switches(walkable: Array[Vector2i], occupied: Dictionary) -> void:
	for attempt in 24:
		for item in switches:
			occupied.erase(item.pos)
		switches.clear()
		for order in 3:
			var position := _pick_spaced(walkable, occupied, 7)
			if position == Vector2i(-1, -1):
				break
			switches.append({"pos": position, "active": false, "order": order})
			occupied[position] = true
		if switches.size() == 3 and int(_plan_puzzle_route().length) >= 0:
			return
	# Deterministic fallback: place runes in order on one simple route from
	# the start, so no later rune can block an earlier one.
	for item in switches:
		occupied.erase(item.pos)
	switches.clear()
	var previous := {player_position: player_position}
	var queue: Array[Vector2i] = [player_position]
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _is_floor(next) and not previous.has(next):
				previous[next] = point
				queue.append(next)
	if queue.size() < 4:
		push_error("O piso puzzle nao tem espaco suficiente para tres runas")
		return
	var path: Array[Vector2i] = []
	var here: Vector2i = queue.back()
	while here != player_position:
		path.append(here)
		here = previous[here]
	path.reverse()
	for point in path:
		if point == portal_position:
			continue
		switches.append({"pos": point, "active": false, "order": switches.size()})
		occupied[point] = true
		if switches.size() == 3:
			return
	push_error("Nao foi possivel colocar as tres runas do puzzle")


# BFS over both position and sequence progress. Entering a future rune resets
# progress; already-lit runes are harmless. Return both exact action count and
# the first step so tests/bots follow the same rules as the player.
func _plan_puzzle_route() -> Dictionary:
	var order_by_pos := {}
	for item in switches:
		order_by_pos[item.pos] = int(item.get("order", 0))
	var start := Vector3i(player_position.x, player_position.y, _active_switches())
	var distance := {start: 0}
	var first_step := {start: Vector2i.ZERO}
	var queue: Array[Vector3i] = [start]
	var head := 0
	while head < queue.size():
		var state: Vector3i = queue[head]
		head += 1
		if Vector2i(state.x, state.y) == portal_position and state.z == switches.size():
			return {"length": int(distance[state]), "step": first_step[state]}
		for direction in FOUR_WAY:
			var point: Vector2i = Vector2i(state.x, state.y) + direction
			if not _is_floor(point):
				continue
			var progress := state.z
			if order_by_pos.has(point):
				var order: int = order_by_pos[point]
				if order == progress:
					progress += 1
				elif order > progress:
					progress = 0
			var next := Vector3i(point.x, point.y, progress)
			if distance.has(next):
				continue
			distance[next] = int(distance[state]) + 1
			first_step[next] = direction if state == start else first_step[state]
			queue.append(next)
	return {"length": -1, "step": Vector2i.ZERO}


# A real reachable route through every switch, followed by the portal. Puzzle
# routes also include the exact ordered-rune/reset rules.
func _estimate_route_length() -> int:
	if objective_type == "environment" and not special_spec.is_empty():
		return int(_plan_environment_route().length)
	if objective_type == "puzzle":
		return int(_plan_puzzle_route().length)
	var total := 0
	var here := player_position
	# Currents can be one-way. Avoid them when estimating an attainable action
	# limit for the existing objective, even if a shorter geometric route exists.
	var avoid_currents := environment.is_active()
	var pending: Array[Vector2i] = []
	for item in switches:
		pending.append(item.pos)
	while not pending.is_empty():
		var distances := _path_distances(here, avoid_currents)
		var best_index := -1
		var best_distance := 2147483647
		for i in pending.size():
			var distance: int = distances.get(pending[i], -1)
			if distance >= 0 and distance < best_distance:
				best_index = i
				best_distance = distance
		if best_index < 0:
			return -1
		total += best_distance
		here = pending[best_index]
		pending.remove_at(best_index)
	var last_leg: int = _path_distances(here, avoid_currents).get(portal_position, -1)
	return total + last_leg if last_leg >= 0 else -1


func _path_distances(start: Vector2i, avoid_currents: bool = false) -> Dictionary:
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _is_floor(next) and (not avoid_currents or environment.kind_at(next) != "current") and not distances.has(next):
				distances[next] = int(distances[point]) + 1
				queue.append(next)
	return distances


func _build_nav_chevrons() -> void:
	nav_chevrons.clear()
	if world_size == Vector2i.ZERO:
		return
	var queue: Array[Vector2i] = [player_position]
	var parent: Dictionary = {}
	parent[player_position] = player_position
	var found := false
	var environmental_nav := environment.is_active()
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == portal_position:
			found = true
			break
		for dir in FOUR_WAY:
			var next_pos: Vector2i = current + dir
			if not _inside(next_pos) or parent.has(next_pos):
				continue
			var tile: int = grid[next_pos.y][next_pos.x]
			if tile == TILE_FLOOR or tile == TILE_WATER:
				# Mark a route that can be walked without accidentally entering a
				# crate, closed gate or one-way current.
				if environmental_nav and (environment.is_blocked(next_pos) or environment.kind_at(next_pos) == "current"):
					continue
				parent[next_pos] = current
				queue.append(next_pos)
	if not found:
		return
	var path: Array[Vector2i] = []
	var curr: Vector2i = portal_position
	while curr != player_position:
		path.append(curr)
		curr = parent[curr]
	path.reverse()
	if path.size() >= 4:
		var step: int = maxi(4, path.size() / 4)
		for i in range(step - 1, path.size() - 1, step):
			var cell: Vector2i = path[i]
			var next_cell: Vector2i = path[i + 1]
			var dir := Vector2(next_cell - cell).normalized()
			if dir.length_squared() > 0.1 and cell != player_position and cell != portal_position:
				nav_chevrons.append({"pos": cell, "dir": dir})


func _init_radial_light_texture() -> void:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var max_r := float(size) * 0.5 - 2.0
	for y in size:
		for x in size:
			var d := (Vector2(x, y) - center).length()
			if d >= max_r:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
			else:
				var t := d / max_r
				var alpha := smoothstep(1.0, 0.0, t) * pow(1.0 - t, 0.85)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	radial_light_texture = ImageTexture.create_from_image(img)


func _init_player_sphere_texture() -> void:
	player_sphere_texture = _make_orb_sphere_texture(Color("380410"), Color("d81636"), Color("ff3b5c"), Color("ff8ca3"))
	lia_sphere_texture = _make_orb_sphere_texture(Color("32103d"), Color("a92eaa"), Color("ee70e4"), Color("ffc3f5"))


func _make_orb_sphere_texture(col_deep: Color, col_mid: Color, col_bright: Color, col_rim: Color) -> ImageTexture:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius := 41.0
	var light_dir := Vector3(-0.55, -0.62, 0.56).normalized()
	var view_dir := Vector3(0.0, 0.0, 1.0)
	var half_vec := (light_dir + view_dir).normalized()
	
	for y in size:
		for x in size:
			var diff_vec := Vector2(x, y) - center
			var dist := diff_vec.length()
			if dist >= radius + 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var nx := diff_vec.x / radius
			var ny := diff_vec.y / radius
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var norm := Vector3(nx, ny, nz)
			
			var n_dot_l := norm.dot(light_dir)
			var half_lambert := clampf(n_dot_l * 0.55 + 0.45, 0.0, 1.0)
			var diff := pow(half_lambert, 1.8)
			
			var n_dot_h := maxf(0.0, norm.dot(half_vec))
			var spec := pow(n_dot_h, 36.0)
			var soft_spec := pow(n_dot_h, 8.0) * 0.35
			
			var fresnel := pow(1.0 - nz, 2.8) * maxf(0.0, ny * 0.6 + nx * 0.3 + 0.4)
			
			var base_col: Color
			if diff < 0.5:
				base_col = col_deep.lerp(col_mid, diff * 2.0)
			else:
				base_col = col_mid.lerp(col_bright, (diff - 0.5) * 2.0)
				
			base_col = base_col.lerp(col_rim, fresnel * 0.5)
			var final_rgb := base_col + Color(1.0, 1.0, 1.0, 0.0) * (spec * 0.95 + soft_spec * 0.3)
			var alpha := 1.0
			if dist > radius - 1.0:
				alpha = clampf((radius + 1.0 - dist) / 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(final_rgb.r, final_rgb.g, final_rgb.b, alpha))
	return ImageTexture.create_from_image(img)


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


# Conservative campaign placement check: no required cell may rely on
# crossing a current in a direction that its forced displacement prevents.
func _reachable_without_cell(start: Vector2i, excluded: Vector2i) -> int:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if next != excluded and _is_floor(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return visited.size()


func _reachable_cells(start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		result.append(point)
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _inside(next) and _is_floor(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return result


# Reuse the ordered list of free cells for all coins. Removing the chosen
# entry preserves the same candidates, random draws and order as _pick_spaced
# at distance 1; running out of cells used to consume no more random values.
func _place_coins(cells: Array[Vector2i], occupied: Dictionary, count: int) -> void:
	var candidates: Array[Vector2i] = []
	for point in cells:
		if not occupied.has(point):
			candidates.append(point)
	for _i in mini(count, candidates.size()):
		var index := rng.randi_range(0, candidates.size() - 1)
		var position := candidates[index]
		coins.append(position)
		occupied[position] = true
		candidates.remove_at(index)


func _pick_spaced(cells: Array[Vector2i], occupied: Dictionary, min_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	# A Manhattan diamond is cheaper than scanning every occupied cell once
	# there are many coins. It tests the same condition without changing order.
	var use_local := min_distance > 1 and occupied.size() > 2 * min_distance * (min_distance - 1)
	var offsets: Array[Vector2i] = []
	if use_local:
		for dx in range(1 - min_distance, min_distance):
			var limit := min_distance - 1 - absi(dx)
			for dy in range(-limit, limit + 1):
				if dx != 0 or dy != 0:
					offsets.append(Vector2i(dx, dy))
	for point in cells:
		if occupied.has(point):
			continue
		var far_enough := true
		if use_local:
			for offset in offsets:
				if occupied.has(point + offset):
					far_enough = false
					break
		elif min_distance > 1:
			for other in occupied:
				if _manhattan(point, other) < min_distance:
					far_enough = false
					break
		if far_enough:
			candidates.append(point)
	if candidates.is_empty():
		for point in cells:
			if not occupied.has(point):
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


func _queue_enemy_visual(enemy: Dictionary, origin: Vector2i, destination: Vector2i) -> void:
	if origin == destination:
		return
	var track = enemy.get("_visual_motion")
	if track == null:
		var current := _enemy_visual_position(enemy)
		track = VisualMotion.new()
		track.reset(current)
		var center := _cell_center(origin)
		if not current.is_equal_approx(center):
			track.enqueue(current, center, "enemy", 0.08)
		enemy["_visual_motion"] = track
	var role := str(enemy.get("role", "hunter"))
	var jumping: bool = role == "chess_boss" and enemy.get("boss_kind", "") == "knight"
	var duration := 0.18 if jumping else 0.12 if role == "rusher" else 0.17 if role in ["sentry", "warden"] else 0.16 if role == "wisp" else 0.14
	# An attack pose is tagged only after this movement has actually resolved
	# into the player's current cell, never from enemy.next or planned paths.
	var committed_contact := destination == player_position
	var motion_kind := "enemy_jump_attack" if jumping and committed_contact else "enemy_jump" if jumping else "enemy_attack" if committed_contact else "enemy"
	track.enqueue(_cell_center(origin), _cell_center(destination), motion_kind, duration)


func _enemy_contact_delay(enemy: Dictionary) -> float:
	var track = enemy.get("_visual_motion")
	if track != null and track.is_active():
		return clampf(track.remaining_time(), 0.0, ImpactPresentation.MAX_PENDING_DELAY)
	return clampf((1.0 - float(enemy.get("t", 1.0))) * 0.14, 0.0, ImpactPresentation.MAX_PENDING_DELAY)


func _record_enemy_defeat(enemy: Dictionary, material: String, delay: float = 0.0) -> void:
	# A non-interactive, role-specific ghost follows the already-resolved actor
	# into contact, then breaks apart. It never collides or awards anything.
	if enemy_defeat_visuals.size() >= 8:
		enemy_defeat_visuals.pop_front()
	var contact_delay := clampf(delay, 0.0, ImpactPresentation.MAX_PENDING_DELAY)
	var snapshot := enemy.duplicate(true)
	snapshot.erase("_visual_motion")
	var face: Vector2i = enemy.get("face", Vector2i(signi(player_position.x - enemy.pos.x), signi(player_position.y - enemy.pos.y)))
	if face == Vector2i.ZERO:
		face = Vector2i.DOWN
	snapshot["face"] = face
	enemy_defeat_visuals.append({
		"role": enemy.get("role", "hunter"), "boss_kind": enemy.get("boss_kind", "pawn"),
		"from": _enemy_visual_position(enemy), "to": _cell_center(enemy.pos),
		"direction": Vector2(facing), "face": Vector2(face), "snapshot": snapshot,
		"material": material, "age": -contact_delay,
		"delay": contact_delay, "duration": 0.58 if _is_elite(enemy) else 0.48,
	})


func _make_enemy(position: Vector2i, role: String) -> Dictionary:
	return {"pos": position, "next": position, "from": _cell_center(position), "to": _cell_center(position),
		"t": 1.0, "role": role, "phase": rng.randi_range(0, 1),
		"patrol_dir": PATROL_DIRECTIONS[rng.randi_range(0, 3)]}


func _make_warden(position: Vector2i) -> Dictionary:
	return {"pos": position, "next": position, "from": _cell_center(position), "to": _cell_center(position),
		"t": 1.0, "role": "warden", "phase": 0, "boss_name": "GUARDIAO", "hp": 3, "max_hp": 3}


func _make_boss(position: Vector2i) -> Dictionary:
	var index := posmod(floori(float(maxi(5, floor_number)) / 5.0) - 1, BOSS_TYPES.size())
	var piece: Dictionary = BOSS_TYPES[index]
	return {"pos": position, "next": position, "from": _cell_center(position), "to": _cell_center(position),
		"t": 1.0, "role": "chess_boss", "phase": 0, "boss_kind": piece.id,
		"boss_name": piece.name, "rule": piece.rule, "hp": piece.hp, "max_hp": piece.hp}


func _is_elite(enemy: Dictionary) -> bool:
	return enemy.get("role", "") in ["warden", "chess_boss"]


func get_active_boss() -> Dictionary:
	for enemy in enemies:
		if enemy.get("role", "") == "chess_boss":
			return enemy
	return {}


# Choose a legal chess-inspired move, limited to three cells for readability.
# Sliding pieces cannot pass through walls, other enemies, reserved landings,
# or blocked diagonal corners. Knights may jump but must land on free floor.
func _boss_intent(enemy: Dictionary, reserved: Array[Vector2i]) -> Dictionary:
	var origin: Vector2i = enemy.pos
	var kind: String = enemy.get("boss_kind", "pawn")
	var candidates: Array[Dictionary] = []
	if kind == "knight":
		for offset in KNIGHT_OFFSETS:
			var landing: Vector2i = origin + offset
			if _is_floor(landing) and not _enemy_at(landing, enemy) and not reserved.has(landing):
				candidates.append({"pos": landing, "path": [landing]})
	else:
		var directions: Array = []
		if kind in ["pawn", "rook", "queen", "king"]:
			directions.append_array(FOUR_WAY)
		if kind in ["bishop", "queen", "king"]:
			directions.append_array(DIAGONALS)
		var reach := 3 if kind in ["rook", "bishop", "queen"] else 1
		for direction in directions:
			var path: Array[Vector2i] = []
			var previous := origin
			for step in range(1, reach + 1):
				var candidate: Vector2i = origin + direction * step
				if not _is_floor(candidate) or _enemy_at(candidate, enemy) or reserved.has(candidate):
					break
				if direction.x != 0 and direction.y != 0:
					if not _is_floor(previous + Vector2i(direction.x, 0)) or not _is_floor(previous + Vector2i(0, direction.y)):
						break
				path.append(candidate)
				candidates.append({"pos": candidate, "path": path.duplicate()})
				previous = candidate
				if candidate == player_position:
					break
	var best := origin
	var best_distance := _manhattan(origin, player_position)
	var best_path: Array[Vector2i] = []
	for candidate in candidates:
		var distance := _manhattan(candidate.pos, player_position)
		if distance < best_distance:
			best = candidate.pos
			best_distance = distance
			best_path.assign(candidate.path)
	if best == origin:
		# Chess diagonals/parity and irregular rooms can otherwise trap a piece
		# indefinitely. A single orthogonal step follows a real path around walls.
		var distances := _path_distances(player_position)
		best_distance = int(distances.get(origin, 2147483647))
		for direction in FOUR_WAY:
			var candidate: Vector2i = origin + direction
			var distance: int = distances.get(candidate, 2147483647)
			if _is_floor(candidate) and not _enemy_at(candidate, enemy) and not reserved.has(candidate) and distance < best_distance:
				best = candidate
				best_distance = distance
				best_path.assign([candidate])
	return {"pos": best, "path": best_path}


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
		enemy["path"] = []
		# Ice delays enemies on even-numbered actions. Plan the stationary
		# result internally; no animation decides or displays the next step.
		if environment.is_slippery_ice(origin) and posmod(turn_number + 1, 2) == 0:
			enemy.next = origin
			continue
		if role == "chess_boss":
			var intent := _boss_intent(enemy, reserved)
			enemy.next = intent.pos
			enemy.path = intent.path
			if enemy.next != origin:
				reserved.append(enemy.next)
			continue
		if role == "mirror":
			# A mirror reacts only once the player's direction is known.
			enemy.next = origin
			continue
		if role == "patrol":
			var direction: Vector2i = enemy.get("patrol_dir", Vector2i.RIGHT)
			if direction not in PATROL_DIRECTIONS:
				direction = Vector2i.RIGHT
			var choice := origin
			for attempt in 4:
				var candidate: Vector2i = origin + direction
				if _is_floor(candidate) and not _enemy_at(candidate, enemy) and not reserved.has(candidate):
					choice = candidate
					break
				direction = Vector2i(-direction.y, direction.x)
			enemy.patrol_dir = direction
			enemy.next = choice
			if choice != origin:
				reserved.append(choice)
			continue
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
				if _inside(middle) and _inside(landing) and _is_floor(middle) and _is_floor(landing) and not _enemy_at(middle, enemy) and not _enemy_at(landing, enemy) and not reserved.has(middle) and not reserved.has(landing):
					enemy.next = landing
					enemy.path = [middle, landing]
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
			if not _inside(candidate) or not _is_floor(candidate):
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


# Unlike planned pursuers, a mirror responds to the direction of the action
# just taken; waiting/demolishing leaves it still. Reserve the other landings.
func _plan_reactive_mirrors(action_direction: Vector2i) -> void:
	var reserved: Array[Vector2i] = []
	for enemy in enemies:
		if enemy.get("role", "") != "mirror" and enemy.next != enemy.pos:
			reserved.append(enemy.next)
	for enemy in enemies:
		if enemy.get("role", "") != "mirror" or int(enemy.get("shield_repel_turn", -1)) == turn_number:
			continue
		var origin: Vector2i = enemy.pos
		if environment.is_slippery_ice(origin) and posmod(turn_number, 2) == 0:
			enemy.next = origin
			enemy["path"] = []
			continue
		var target: Vector2i = origin - action_direction
		enemy.next = origin
		enemy["path"] = []
		if action_direction != Vector2i.ZERO and _is_floor(target) and not _enemy_at(target, enemy) and not reserved.has(target):
			enemy.next = target
			reserved.append(target)


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
		if (x != player_position.x or y != player_position.y) and not _is_floor(Vector2i(x, y)):
			return false
	return true


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)


func _nearest_inactive_switch(origin: Vector2i) -> Vector2i:
	if objective_type == "puzzle":
		for item in switches:
			if int(item.get("order", -1)) == _active_switches() and not item.active:
				return item.pos
		return Vector2i(-1, -1)
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
	if game_state != "playing" or captor_flyover_time > 0.0 or absi(dx) + absi(dy) != 1:
		return
	var undo_before := _snapshot_sokoban()
	facing = Vector2i(dx, dy)
	var next := player_position + facing
	var crate_pushed := false
	var push_contact_delay := _contact_delay(0.035)
	var crate_index: int = environment.crate_index_at(next)
	if crate_index >= 0:
		if not environment.push(crate_index, facing, Callable(self, "_crate_destination_free")):
			blocked_crate_index = crate_index
			blocked_crate_direction = Vector2(facing)
			blocked_crate_pending = player_motion.is_active() or crate_visual_tracks.has(crate_index)
			blocked_crate_time = 0.0 if blocked_crate_pending else 0.16
			last_notice = "CAIXA BLOQUEADA — PRECISA DE UMA CASA LIVRE"
			notice_timer = 1.2
			_queue_contact_feedback("BLOCKED", "block", _cell_center(next) - Vector2(facing) * CELL * 0.5, Vector2(facing), _contact_delay(0.04), str(environment.crates[crate_index].get("material", "wood")))
			queue_redraw()
			return
		crate_pushed = true
		_queue_crate_visual(crate_index, next, environment.crates[crate_index].pos, "push")
	else:
		var can_walk: bool = (_inside(next) and _is_floor(next)) or (dev_noclip and _inside(next) and not environment.is_blocked(next))
		if not can_walk:
			last_notice = "TOC! A passagem esta bloqueada."
			notice_timer = 1.0
			_queue_contact_feedback("BLOCKED", "block", _cell_center(player_position) + Vector2(facing) * CELL * 0.5, Vector2(facing), _contact_delay(0.04), "wall")
			queue_redraw()
			return
	_remember_sokoban(undo_before)
	if crate_pushed and not undo_before.is_empty():
		sokoban_pushes += 1
	_begin_player_move(next, "push" if crate_pushed else "walk")
	moves_this_floor += 1
	_emit_feedback("MOVE", {"material": _current_haptic_material(), "audio_already_played": crate_pushed, "suppress_haptic": crate_pushed})
	if crate_pushed:
		var material := str(environment.crates[crate_index].get("material", "wood"))
		_queue_contact_feedback("CRATE_PUSH_METAL" if material == "metal" else "CRATE_PUSH_WOOD", "push" if material == "metal" else "push_soft", _cell_center(next) - Vector2(facing) * CELL * 0.5, Vector2(facing), push_contact_delay, material)
	_take_turn(facing, crate_pushed)
	if crate_pushed and crate_visual_tracks.has(crate_index):
		var track = crate_visual_tracks[crate_index]
		if player_motion.is_active() and track.is_active() and player_motion.kind == "push" and track.kind == "push" and is_equal_approx(player_motion.progress, track.progress):
			player_motion.duration = track.duration
			_sync_player_motion_fields()


func wait_turn() -> void:
	if game_state != "playing" or captor_flyover_time > 0.0:
		return
	_remember_sokoban(_snapshot_sokoban())
	moves_this_floor += 1
	last_notice = "ESPERASTE UM TURNO — OS INIMIGOS AVANCAM"
	notice_timer = 1.0
	_emit_feedback("WAIT")
	_take_turn()


# Capture every reversible gameplay fact, not just box coordinates. The
# chamber can contain loot and powers and players can jump, blink or demolish;
# undo must not duplicate those resources or leave stale electricity/gates.
func _snapshot_sokoban() -> Dictionary:
	if special_family != "sokoban" or special_spec.is_empty() or lab_active:
		return {}
	return {
		"player": player_position, "facing": facing, "grid": grid.duplicate(true),
		"cells": environment.cells.duplicate(true), "crates": environment.crates.duplicate(true),
		"plates": environment.plates.duplicate(true), "gates": environment.gates.duplicate(true),
		"portal_open": portal_open, "enemies": enemies.duplicate(true),
		"coins": coins.duplicate(), "shields": shields.duplicate(), "hearts_on_floor": heart_pickups.duplicate(),
		"breakers": breakers.duplicate(), "powerups": powerups.duplicate(true),
		"switches": switches.duplicate(true), "traps": traps.duplicate(true),
		"coins_total": total_coins, "best_score": best_score, "best_dirty": best_score_dirty,
		"charges": charges, "breach": breach_charges, "hearts": hearts_current,
		"powers": _capture_power_state(), "turn": turn_number, "moves": moves_this_floor,
		"jumps": jumps_this_floor, "hits": hits_this_floor, "collected": coins_this_floor,
		"pushes": sokoban_pushes, "challenge": challenge_complete,
		"bonus_claimed": environment_bonus_claimed, "rng": rng.state,
		"shield_notice": shield_full_notice_turn,
	}


func _remember_sokoban(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if sokoban_history.size() >= SOKOBAN_HISTORY_LIMIT:
		sokoban_history.pop_front()
	sokoban_history.append(snapshot)


func undo_sokoban_move() -> void:
	if game_state != "playing" or special_family != "sokoban" or special_spec.is_empty() or captor_flyover_time > 0.0:
		return
	if sokoban_history.is_empty():
		last_notice = "AINDA NAO HA MOVIMENTOS PARA DESFAZER"
		notice_timer = 1.4
		_emit_feedback("BLOCKED")
		return
	var saved: Dictionary = sokoban_history.pop_back()
	_clear_transient_motion_effects()
	particles.clear()
	unresolved_contacts.clear()
	grid = saved.grid.duplicate(true)
	environment.reset({"cells": saved.cells, "crates": saved.crates, "plates": saved.plates, "gates": saved.gates})
	player_position = saved.player
	facing = saved.facing
	_reset_player_visual(_cell_center(player_position))
	portal_open = bool(saved.portal_open)
	enemies.assign(saved.enemies.duplicate(true))
	coins.assign(saved.coins)
	shields.assign(saved.shields)
	heart_pickups.assign(saved.hearts_on_floor)
	breakers.assign(saved.breakers)
	powerups.assign(saved.powerups.duplicate(true))
	switches.assign(saved.switches.duplicate(true))
	traps.assign(saved.traps.duplicate(true))
	total_coins = int(saved.coins_total)
	best_score = int(saved.best_score)
	best_score_dirty = bool(saved.best_dirty)
	charges = int(saved.charges)
	breach_charges = int(saved.breach)
	hearts_current = int(saved.hearts)
	_restore_power_state(saved.powers)
	turn_number = int(saved.turn)
	moves_this_floor = int(saved.moves)
	jumps_this_floor = int(saved.jumps)
	hits_this_floor = int(saved.hits)
	coins_this_floor = int(saved.collected)
	sokoban_pushes = int(saved.pushes)
	challenge_complete = bool(saved.challenge)
	environment_bonus_claimed = bool(saved.bonus_claimed)
	rng.state = int(saved.rng)
	shield_full_notice_turn = int(saved.shield_notice)
	damage_this_turn = false
	if terrain_renderer != null:
		terrain_renderer.rebuild()
	_update_enemy_intents()
	_update_camera(1.0)
	last_notice = "ULTIMA ACAO DESFEITA"
	notice_timer = 1.2
	_emit_feedback("UNDO")
	queue_redraw()


func _clear_transient_motion_effects() -> void:
	crate_visual_tracks.clear()
	blocked_crate_index = -1
	blocked_crate_time = 0.0
	blocked_crate_pending = false
	surface_reactions.clear()
	electric_visual_glow.clear()
	if electric_presentation != null:
		electric_presentation.clear()
	enemy_defeat_visuals.clear()
	_flush_pending_impact_cues()
	impact_presentation.clear()
	player_impact_kind = ""
	pickup_feedback_delay = -1.0
	turn_pulse_pending = false
	turn_pulse_time = -1.0
	landing_feedback_time = 0.0
	blocked_feedback_time = 0.0
	blocked_feedback_pending = false
	attack_feedback_time = 0.0
	attack_feedback_delay = 0.0
	impact_feedback_time = 0.0


func _reset_player_visual(position: Vector2) -> void:
	player_motion.reset(position)
	player_from = position
	player_to = position
	player_anim = 1.0
	player_visual_direction = Vector2(facing) if facing != Vector2i.ZERO else Vector2.RIGHT
	player_roll_angle = 0.0
	blocked_feedback_time = 0.0
	blocked_feedback_pending = false
	attack_feedback_time = 0.0
	attack_feedback_delay = 0.0
	impact_feedback_time = 0.0


func _sync_player_motion_fields() -> void:
	# Keep these established fields available to the camera and existing tools.
	player_from = player_motion.from
	player_to = player_motion.to
	player_anim = player_motion.progress


func _player_motion_fields_match() -> bool:
	return player_from.is_equal_approx(player_motion.from) and player_to.is_equal_approx(player_motion.to) and is_equal_approx(player_anim, player_motion.progress)


func _visual_surface_at(point: Vector2i) -> String:
	if not _inside(point) or grid[point.y][point.x] != TILE_WATER:
		return ""
	return _surface_kind(point)


func _begin_player_move(next: Vector2i, motion_kind: String = "walk", visual_wait: float = 0.0) -> void:
	var origin := _cell_center(player_position)
	# Tests/dev tools may reposition the established public fields directly.
	# Never replay a stale route across a reset, room change or teleport.
	if not _player_motion_fields_match() or not player_motion.final_target().is_equal_approx(origin):
		_reset_player_visual(origin)
	player_position = next
	_prune_unresolved_contacts()
	var destination := _cell_center(next)
	if motion_kind == "blink":
		_reset_player_visual(destination)
		return
	var surface := _visual_surface_at(next)
	var duration := JUMP_VISUAL_TIME if motion_kind == "jump" else SLIDE_VISUAL_TIME if motion_kind in ["ice", "current"] else WALK_VISUAL_TIME
	if surface in ["water", "current"] and motion_kind == "walk":
		duration = 0.15
	# An impact recoil may temporarily retain up to contact delay + one step;
	# ordinary inputs still use the shorter queue cap and can supersede it.
	player_motion.enqueue(origin, destination, motion_kind, duration, surface, visual_wait, motion_kind != "heart_recoil")
	_sync_player_motion_fields()
	if player_motion.is_active():
		player_visual_direction = (player_motion.to - player_motion.from).normalized()
	blocked_feedback_time = 0.0
	blocked_feedback_pending = false


func _advance_player_motion(delta: float) -> void:
	if not _player_motion_fields_match():
		# Legacy callers may set the fields to a settled position directly.
		player_motion.reset(_player_visual_position())
		_sync_player_motion_fields()
	if not player_motion.is_active():
		return
	var result: Dictionary = player_motion.advance(delta)
	for step in result.steps:
		var displacement: Vector2 = step.delta
		if displacement.length_squared() > 0.0001:
			player_visual_direction = displacement.normalized()
			# Opposite directions roll with opposite signs; the face stays upright.
			player_roll_angle = fposmod(player_roll_angle + (displacement.x + displacement.y) / 17.0, TAU)
	for arrival in result.arrivals:
		if str(arrival.kind) == "hold":
			continue
		if str(arrival.surface) in ["water", "current"]:
			_add_surface_reaction(arrival.position, "water")
		elif str(arrival.surface) == "ice":
			_add_surface_reaction(arrival.position, "ice")
	_sync_player_motion_fields()
	if not player_motion.is_active() and game_state != "captured":
		landing_feedback_time = 0.12
		if blocked_feedback_pending:
			blocked_feedback_pending = false
			blocked_feedback_time = 0.16


func _add_surface_reaction(position: Vector2, material: String) -> void:
	# Bounded, deterministic and drawn underneath actors; no gameplay RNG.
	if surface_reactions.size() >= 8:
		surface_reactions.pop_front()
	surface_reactions.append({"position": position, "material": material, "age": 0.0, "duration": 0.38 if material == "water" else 0.24})


func _queue_crate_visual(index: int, origin: Vector2i, destination: Vector2i, motion_kind: String) -> void:
	var track = crate_visual_tracks.get(index)
	if track == null:
		track = VisualMotion.new()
		track.reset(_cell_center(origin))
		crate_visual_tracks[index] = track
	if motion_kind == "push":
		# When inputs arrive faster than the picture, keep the crate at contact
		# until the already-committed player path reaches it (and vice versa).
		# These holds are visual only and are compressed by the same queue cap.
		var player_remaining: float = player_motion.remaining_time() if _player_motion_fields_match() else 0.0
		var crate_remaining: float = track.remaining_time()
		if player_remaining > crate_remaining + 0.001:
			track.enqueue(_cell_center(origin), _cell_center(origin), "hold", player_remaining - crate_remaining)
		elif crate_remaining > player_remaining + 0.001:
			var target: Vector2 = player_motion.final_target() if player_motion.is_active() else _cell_center(player_position)
			player_motion.enqueue(target, target, "hold", crate_remaining - player_remaining)
			_sync_player_motion_fields()
	track.enqueue(_cell_center(origin), _cell_center(destination), motion_kind, SLIDE_VISUAL_TIME if motion_kind == "current" else WALK_VISUAL_TIME, _visual_surface_at(destination))


func _crate_visual_position(index: int, crate: Dictionary) -> Vector2:
	var target := _cell_center(crate.pos)
	var track = crate_visual_tracks.get(index)
	if track == null or not track.final_target().is_equal_approx(target):
		return target
	return track.position()


func _advance_crate_visuals(delta: float) -> void:
	for index in crate_visual_tracks.keys():
		var track = crate_visual_tracks[index]
		if index < 0 or index >= environment.crates.size() or not track.final_target().is_equal_approx(_cell_center(environment.crates[index].pos)):
			crate_visual_tracks.erase(index)
			continue
		var result: Dictionary = track.advance(delta)
		for arrival in result.arrivals:
			if str(arrival.kind) == "hold":
				continue
			if str(arrival.surface) in ["water", "current"]:
				_add_surface_reaction(arrival.position, "water")
			elif str(arrival.kind) == "push":
				_add_surface_reaction(arrival.position, str(environment.crates[index].get("material", "wood")))
		if not track.is_active():
			crate_visual_tracks.erase(index)


func _advance_electric_visuals(delta: float) -> void:
	# Danger itself is drawn immediately from environment.powered; this only
	# eases the decorative light when real conductive connections change.
	for point in environment.powered:
		electric_visual_glow[point] = minf(1.0, float(electric_visual_glow.get(point, 0.25)) + maxf(0.0, delta) * 8.0)
	for point in electric_visual_glow.keys():
		if not environment.powered.has(point):
			var faded := maxf(0.0, float(electric_visual_glow[point]) - maxf(0.0, delta) * 4.0)
			if faded <= 0.0:
				electric_visual_glow.erase(point)
			else:
				electric_visual_glow[point] = faded


func _advance_transient_motion_effects(delta: float) -> void:
	for index in range(surface_reactions.size() - 1, -1, -1):
		surface_reactions[index].age += maxf(0.0, delta)
		if surface_reactions[index].age >= surface_reactions[index].duration:
			surface_reactions.remove_at(index)
	for index in range(enemy_defeat_visuals.size() - 1, -1, -1):
		enemy_defeat_visuals[index].age += maxf(0.0, delta)
		if enemy_defeat_visuals[index].age >= enemy_defeat_visuals[index].duration:
			enemy_defeat_visuals.remove_at(index)


func try_jump() -> void:
	if game_state != "playing" or captor_flyover_time > 0.0:
		return
	if charges <= 0:
		last_notice = "Sem escudo para saltar"
		notice_timer = 1.5
		_emit_feedback("BLOCKED")
		queue_redraw()
		return
	var middle := player_position + facing
	var landing := player_position + facing * 2
	var can_jump: bool = _inside(middle) and _inside(landing) and _is_floor(middle) and _is_floor(landing)
	if dev_noclip and _inside(middle) and _inside(landing) and not environment.is_blocked(middle) and not environment.is_blocked(landing):
		can_jump = true
	if not can_jump:
		last_notice = "Precisas de duas casas livres para saltar"
		notice_timer = 1.5
		_emit_feedback("BLOCKED")
		queue_redraw()
		return
	_remember_sokoban(_snapshot_sokoban())
	charges -= 1
	jumps_this_floor += 1
	moves_this_floor += 1
	_begin_player_move(landing, "jump")
	_spawn_burst(_cell_center(player_position), Color("6bf4ff"), 14, 115.0)
	_emit_feedback("JUMP")
	_take_turn(facing)


# Blink ignores intermediate walls, traps, pickups and enemies, but may only
# land on floor and cannot cross the indestructible map boundary.
func try_blink() -> void:
	if game_state != "playing" or captor_flyover_time > 0.0:
		return
	if blink_charges <= 0:
		last_notice = "SEM CARGAS DE BLINK"
		notice_timer = 1.4
		_emit_feedback("BLOCKED")
		return
	var origin := player_position
	var landing := origin
	var reach := 3 + _skill_effect("blink_range")
	for step in range(1, reach + 1):
		var point: Vector2i = origin + facing * step
		if not _inside(point) or grid[point.y][point.x] == TILE_BORDER:
			break
		if _is_floor(point):
			landing = point
	if landing == origin:
		last_notice = "BLINK PRECISA DE UMA CASA LIVRE ATE %d PASSOS" % reach
		notice_timer = 1.6
		_emit_feedback("BLOCKED")
		return
	_remember_sokoban(_snapshot_sokoban())
	blink_charges -= 1
	moves_this_floor += 1
	_spawn_burst(_cell_center(origin), Color("91faff"), 18, 140.0)
	# Blink is an instantaneous teleport, not a slide through intervening tiles.
	_begin_player_move(landing, "blink")
	_spawn_burst(_cell_center(landing), Color("c2b6ff"), 24, 160.0)
	_emit_feedback("BLINK")
	_take_turn(facing)


func try_break_wall() -> void:
	if game_state != "playing" or captor_flyover_time > 0.0:
		return
	var target := player_position + facing
	if not _inside(target):
		return
	var attack_contact_delay := _contact_delay(0.07)

	# Verificar se há um inimigo na célula à frente para demolir
	var enemy_idx := -1
	for i in enemies.size():
		if enemies[i].pos == target:
			enemy_idx = i
			break
	if enemy_idx >= 0:
		if breach_charges <= 0:
			last_notice = "CARGA DE DEMOLICAO EM FALTA PARA DESTRUIR INIMIGO"
			notice_timer = 1.4
			_emit_feedback("BLOCKED")
			queue_redraw()
			return
		_remember_sokoban(_snapshot_sokoban())
		breach_charges -= 1
		var enemy: Dictionary = enemies[enemy_idx]
		var dead_role: String = enemy.get("role", "hunter")
		var defeated := false
		if _is_elite(enemy):
			enemy["hp"] = maxi(0, int(enemy.get("hp", 2)) - 1 - _skill_effect("breach_damage"))
			if enemy.hp > 0:
				enemy["_visual_reaction"] = 0.0
				enemy["_visual_reaction_delay"] = attack_contact_delay
				enemy["_visual_reaction_direction"] = Vector2(facing)
				enemies[enemy_idx] = enemy
				last_notice = "%s ATINGIDO: %d/%d" % [enemy.get("boss_name", "GUARDIAO"), enemy.hp, enemy.get("max_hp", 2)]
			else:
				_record_enemy_defeat(enemy, "impact", attack_contact_delay)
				enemies.remove_at(enemy_idx)
				defeated = true
				last_notice = "%s DERROTADO!" % enemy.get("boss_name", "GUARDIAO")
		else:
			_record_enemy_defeat(enemy, "impact", attack_contact_delay)
			enemies.remove_at(enemy_idx)
			defeated = true
			last_notice = "INIMIGO %s DEMOLIDO!" % dead_role.to_upper()
		if defeated and _skill_effect("breach_salvage") > 0:
			breach_charges += 1
			last_notice += " / CARGA RECUPERADA"
		moves_this_floor += 1
		notice_timer = 2.0
		_queue_contact_feedback("DEMOLITION", "defeat" if defeated else "elite", _cell_center(target), Vector2(facing), attack_contact_delay, dead_role, "enemy_crush", false)
		_take_turn()
		return

	if grid[target.y][target.x] == TILE_BORDER:
		last_notice = "A FRONTEIRA DAS RUINAS NAO CEDE"
		notice_timer = 1.2
		_emit_feedback("BLOCKED")
		queue_redraw()
		return
	if grid[target.y][target.x] != TILE_WALL:
		last_notice = "NAO HA PAREDE PARA DEMOLIR"
		notice_timer = 1.0
		_emit_feedback("BLOCKED")
		queue_redraw()
		return
	if breach_charges <= 0:
		last_notice = "CARGA DE DEMOLICAO EM FALTA"
		notice_timer = 1.4
		_emit_feedback("BLOCKED")
		queue_redraw()
		return
	_remember_sokoban(_snapshot_sokoban())
	breach_charges -= 1
	grid[target.y][target.x] = TILE_FLOOR
	if terrain_renderer != null:
		terrain_renderer.invalidate_cell(target)
	moves_this_floor += 1
	last_notice = "PAREDE ABERTA — OS PERSEGUIDORES AVANCAM"
	notice_timer = 1.7
	var material := _wall_impact_material()
	var sound := "break_glass" if material == "glass" else "break_metal" if material == "metal" else "break_ice" if material == "ice" else "break_wall"
	_queue_contact_feedback("DEMOLITION", "wall", _cell_center(target), Vector2(facing), attack_contact_delay, material, sound, false)
	_take_turn()


func _take_turn(action_direction: Vector2i = Vector2i.ZERO, crate_pushed: bool = false) -> void:
	_prune_unresolved_contacts()
	damage_this_turn = false
	turn_number += 1
	_emit_feedback("TURN_COMMITTED", {"cell": player_position, "turn": turn_number})
	var environmental_turn: bool = environment.is_active()
	var visited_surface: Array[Vector2i] = [player_position]
	var update_navigation := false
	if environmental_turn:
		# A freeze pickup on the entry tile takes effect during this action,
		# before the current moves either the player or any floating wood.
		var entry_freezes := freeze_turns > 0
		for item in powerups:
			if item.pos == player_position and item.kind == "time_freeze":
				entry_freezes = true
				break
		var floated: Array[Dictionary] = []
		if not entry_freezes:
			floated = environment.advance_currents(Callable(self, "_crate_destination_free"))
		for movement in floated:
			_queue_crate_visual(int(movement.index), movement.from, movement.to, "current")
		if not floated.is_empty():
			_emit_feedback("CURRENT_DRIFT")
		_sync_environment_mechanisms()
		update_navigation = not lab_active and (crate_pushed or not floated.is_empty())
	_collect_pickups()
	_trigger_traps(action_direction)
	if game_state == "playing" and environmental_turn and freeze_turns <= 0 and environment.is_electrified(player_position):
		_apply_damage("AGUA ELETRIFICADA!", Color("ffe46a"), -action_direction)
	if game_state != "playing":
		_tick_power_effects()
		queue_redraw()
		return
	_activate_switches()
	if environmental_turn:
		_sync_environment_mechanisms()
	# Initial-cell contact still hurts even when an enemy is frozen; otherwise
	# the player could pass through a stationary enemy without consequence.
	_check_enemy_collision(action_direction)
	if game_state != "playing":
		_tick_power_effects()
		queue_redraw()
		return
	if environmental_turn:
		_resolve_environment_displacement(action_direction)
		visited_surface.append(player_position)
		_stress_brittle_ice(visited_surface)
		if game_state != "playing":
			_tick_power_effects()
			queue_redraw()
			return
	var immobilized := freeze_turns > 0 or (speed_turns > 0 and speed_phase == 0)
	var enemy_advanced_near := false
	if not immobilized:
		_plan_reactive_mirrors(action_direction)
		var positions: Array[Vector2i] = []
		var crossings: Array[int] = []
		for i in enemies.size():
			var enemy: Dictionary = enemies[i]
			var planned: Vector2i = enemy.next
			# A crate/gate may invalidate the internally planned path. Cancel it
			# rather than inventing an alternate move this turn.
			if environmental_turn:
				if not _is_floor(planned):
					planned = enemy.pos
				for path_cell in enemy.get("path", []):
					if not _is_floor(path_cell):
						planned = enemy.pos
						break
			positions.append(planned)
			if (not environmental_turn or planned != enemy.pos) and planned != player_position and enemy.get("path", []).has(player_position):
				crossings.append(i)
		for i in enemies.size():
			var enemy: Dictionary = enemies[i]
			# A shield impact before the enemy phase already committed the recoil.
			# Do not overwrite its interpolation with a stationary movement.
			if int(enemy.get("shield_repel_turn", -1)) == turn_number:
				continue
			var previous_position: Vector2i = enemy.pos
			_queue_enemy_visual(enemy, previous_position, positions[i])
			enemy.from = _cell_center(enemy.pos)
			enemy.pos = positions[i]
			enemy.to = _cell_center(enemy.pos)
			enemy.t = 0.0
			enemies[i] = enemy
			if enemy.pos != previous_position and _manhattan(enemy.pos, player_position) == 1 and _enemy_sees_player(enemy.pos):
				enemy_advanced_near = true
		_check_enemy_collision(Vector2i.ZERO, true)
		if game_state == "playing" and not damage_this_turn:
			for index in crossings:
				var enemy: Dictionary = enemies[index]
				_resolve_enemy_contact(index, _shield_recoil_direction(enemy, Vector2i.ZERO, true))
				break
	if game_state == "playing":
		if environmental_turn:
			_resolve_electrified_enemies()
			_sync_environment_mechanisms()
		if feedback_bus != null and enemy_advanced_near and not damage_this_turn and not dev_god_mode:
			feedback_bus.near_miss({"cell": player_position})
		_update_enemy_intents()
	_tick_power_effects()
	# Tick before saving a completed floor, so its checkpoint contains the
	# duration remaining after the portal action, not one extra turn.
	if game_state == "playing":
		if update_navigation:
			_build_nav_chevrons()
		_check_portal()
	queue_redraw()


func _tick_power_effects() -> void:
	if speed_turns > 0:
		speed_turns -= 1
		speed_phase = 1 - speed_phase if speed_turns > 0 else 0
	if magnet_turns > 0:
		magnet_turns -= 1
	if freeze_turns > 0:
		freeze_turns -= 1


func _collect_coin(point: Vector2i) -> bool:
	if not coins.has(point):
		return false
	coins.erase(point)
	coins_this_floor += 1
	total_coins += 1 + _skill_effect("coin_bonus")
	if total_coins > best_score:
		best_score = total_coins
		best_score_dirty = true
	_spawn_burst(_cell_center(point), Color("ffd15d"), 18, 150.0)
	return true


# Magnetism follows actual floor paths, not Manhattan distance through walls.
func _nearby_floor_cells(start: Vector2i, reach: int) -> Dictionary:
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		if int(distances[point]) >= reach:
			continue
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if _is_floor(next) and not distances.has(next):
				distances[next] = int(distances[point]) + 1
				queue.append(next)
	return distances


func _skill_effect(effect_name: String) -> int:
	# The experimental chambers are an isolated rules laboratory.
	return 0 if lab_active else skills.effect(effect_name)


func shield_capacity() -> int:
	return 3 + _skill_effect("shield_capacity")


func heart_capacity() -> int:
	return _skill_effect("heart_capacity")


func _place_heart_pickup(number: int, occupied: Dictionary) -> void:
	var chance := _skill_effect("heart_spawn")
	if chance <= 0 or heart_capacity() <= 0:
		return
	# Separate RNG: enabling a skill cannot reshuffle maps, enemies or pickups.
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = active_seed ^ (number * 104729) ^ 0x41c64e6d
	if loot_rng.randi_range(1, 100) > chance:
		return
	var candidates: Array[Vector2i] = []
	for point in _reachable_cells(player_position):
		if occupied.has(point) or not _is_floor(point) or environment.kind_at(point) != "":
			continue
		var unsafe := false
		for trap in traps:
			if trap.pos == point:
				unsafe = true
				break
		for plate in environment.plates:
			if plate.pos == point:
				unsafe = true
				break
		if not unsafe:
			candidates.append(point)
	if not candidates.is_empty():
		heart_pickups.append(candidates[loot_rng.randi_range(0, candidates.size() - 1)])


func _collect_pickups() -> void:
	var collected_coins := 1 if _collect_coin(player_position) else 0
	if shields.has(player_position):
		if charges < shield_capacity():
			shields.erase(player_position)
			var gained := mini(1 + _skill_effect("shield_pickup"), shield_capacity() - charges)
			charges += gained
			last_notice = "ESCUDO +%d / SALTAR GASTA 1" % gained
			notice_timer = 2.2
			_spawn_burst(_cell_center(player_position), Color("53edff"), 22, 130.0)
			_emit_feedback("SHIELD_PICKUP")
		elif shield_full_notice_turn != turn_number:
			shield_full_notice_turn = turn_number
			last_notice = "ESCUDOS CHEIOS (%d/%d) — PICKUP FICA NO CHAO" % [charges, shield_capacity()]
			notice_timer = 2.2
	if heart_pickups.has(player_position) and hearts_current < heart_capacity():
		heart_pickups.erase(player_position)
		hearts_current += 1
		last_notice = "CORACAO RECUPERADO (%d/%d)" % [hearts_current, heart_capacity()]
		notice_timer = 2.2
		_spawn_burst(_cell_center(player_position), Color("ff83a1"), 18, 120.0)
		_emit_feedback("HEART_RECOVERED")
	if breakers.has(player_position):
		breakers.erase(player_position)
		var gained := 1 + _skill_effect("breach_pickup")
		breach_charges += gained
		last_notice = "CARGA DE DEMOLICAO +%d — B PARA USAR" % gained
		notice_timer = 2.6
		_spawn_burst(_cell_center(player_position), Color("ffad67"), 26, 155.0)
		_emit_feedback("BREAKER_PICKUP")
	for i in range(powerups.size() - 1, -1, -1):
		var item: Dictionary = powerups[i]
		if item.pos == player_position:
			powerups.remove_at(i)
			_activate_powerup(item.kind)
	if magnet_turns > 0 and not coins.is_empty():
		var nearby := _nearby_floor_cells(player_position, 2 + _skill_effect("magnet_range"))
		for point in coins.duplicate():
			if nearby.has(point) and _collect_coin(point):
				collected_coins += 1
	if collected_coins > 0:
		var value := collected_coins * (1 + _skill_effect("coin_bonus"))
		last_notice = "+%d MOEDA%s%s" % [value, "S" if value != 1 else "", " / IMA" if collected_coins > 1 else ""]
		notice_timer = 1.0
		_audio_coin()


func _activate_powerup(kind: String) -> void:
	match kind:
		"speed":
			speed_turns = SPEED_DURATION + _skill_effect("speed_duration")
			speed_phase = 0
			last_notice = "VELOCIDADE / INIMIGOS AVANCAM EM ACOES ALTERNADAS"
		"magnet":
			magnet_turns = MAGNET_DURATION + _skill_effect("magnet_duration")
			last_notice = "IMA / RECOLHE MOEDAS ATE %d PASSOS" % (2 + _skill_effect("magnet_range"))
		"blink":
			var gained := 1 + _skill_effect("blink_pickup")
			blink_charges += gained
			last_notice = "BLINK +%d / Q TELEPORTA ATE %d CASAS" % [gained, 3 + _skill_effect("blink_range")]
		"time_freeze":
			freeze_turns = FREEZE_DURATION + _skill_effect("freeze_duration")
			last_notice = "TEMPO CONGELADO / ARMADILHAS CONTINUAM ATIVAS"
		_:
			return
	notice_timer = 2.6
	_spawn_burst(_cell_center(player_position), Color(POWERUP_COLORS.get(kind, "ffffff")), 24, 145.0)
	_emit_feedback("POWER_" + kind.to_upper())


func _audio_coin() -> void:
	_emit_feedback("COIN_PICKUP")


func _activate_switches() -> void:
	for i in switches.size():
		var item: Dictionary = switches[i]
		if item.active or item.pos != player_position:
			continue
		if objective_type == "puzzle" and int(item.get("order", -1)) != _active_switches():
			for j in switches.size():
				switches[j].active = false
			last_notice = "ORDEM ERRADA! RECOMECA: CIANO > AMBAR > VIOLETA"
			notice_timer = 2.8
			_spawn_burst(_cell_center(player_position), Color("ff6c82"), 18, 110.0)
			_emit_feedback("PUZZLE_ERROR")
			return
		item.active = true
		switches[i] = item
		if objective_type == "puzzle":
			var order: int = item.order
			last_notice = "RUNA %d / %s — %d/3" % [order + 1, PUZZLE_NAMES[order], _active_switches()]
			_spawn_burst(_cell_center(player_position), Color(PUZZLE_COLORS[order]), 20, 130.0)
		else:
			last_notice = "INTERRUPTOR %d/%d ATIVADO" % [_active_switches(), switches.size()]
			_spawn_burst(_cell_center(player_position), Color("7bf4ff"), 20, 130.0)
		notice_timer = 2.1
		_emit_feedback("SWITCH_ON")
	if objective_type in ["switches", "puzzle"] and not switches.is_empty() and _active_switches() >= switches.size():
		if not portal_open:
			portal_open = true
			last_notice = "SEQUENCIA COMPLETA — PORTAL ABERTO" if objective_type == "puzzle" else "TODOS OS INTERRUPTORES ATIVOS — PORTAL ABERTO"
			notice_timer = 3.0
			_spawn_burst(_cell_center(portal_position), Color("d57aff"), 32, 175.0)
			_emit_feedback("PORTAL_OPEN")


func _active_switches() -> int:
	var count := 0
	for item in switches:
		if item.active:
			count += 1
	return count


# Phase zero is dangerous; the drawing previews the next action's phase.
func _rhythm_is_hot(trap: Dictionary, action_turn: int) -> bool:
	return posmod(action_turn + int(trap.get("phase", 0)), 3) == 0


func _trigger_traps(action_direction: Vector2i = Vector2i.ZERO) -> void:
	for i in traps.size():
		var trap: Dictionary = traps[i]
		if not trap.get("armed", true) or trap.pos != player_position:
			continue
		if trap.get("type", "one_shot") == "rhythm":
			if _rhythm_is_hot(trap, turn_number):
				_apply_damage("ARMADILHA DE RITMO!", Color("ff7456"), -action_direction)
				_emit_feedback("RHYTHM_TRAP")
		else:
			trap.armed = false
			trap.revealed = true
			traps[i] = trap
			_apply_damage("ARMADILHA!", Color("ff7456"), -action_direction)


func _contact_is_guarded(enemy: Dictionary) -> bool:
	for guarded in unresolved_contacts:
		if is_same(guarded, enemy):
			return true
	return false


func _prune_unresolved_contacts() -> void:
	for index in range(unresolved_contacts.size() - 1, -1, -1):
		var guarded: Dictionary = unresolved_contacts[index]
		var present := false
		for enemy in enemies:
			if is_same(guarded, enemy):
				present = true
				break
		if not present or guarded.get("pos", Vector2i(-999, -999)) != player_position:
			unresolved_contacts.remove_at(index)


func _mark_unresolved_overlaps() -> void:
	# Even contacts suppressed by the per-action guard must not become a second
	# hit merely because the same bodies are still overlapped on the next action.
	for enemy in enemies:
		if enemy.pos == player_position and not _contact_is_guarded(enemy):
			unresolved_contacts.append(enemy)


func _check_enemy_collision(action_direction: Vector2i = Vector2i.ZERO, enemy_moved: bool = false) -> void:
	if dev_god_mode:
		return
	_prune_unresolved_contacts()
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if enemy.pos != player_position or _contact_is_guarded(enemy):
			continue
		_resolve_enemy_contact(i, _shield_recoil_direction(enemy, action_direction, enemy_moved))
		if damage_this_turn:
			_mark_unresolved_overlaps()
		return


# In an incoming collision or a dash crossing, rebound toward the attacker's
# starting cell. When the player enters an occupied cell, push forward instead.
func _shield_recoil_direction(enemy: Dictionary, action_direction: Vector2i, enemy_moved: bool) -> Vector2i:
	if enemy_moved:
		var source: Vector2 = enemy.get("from", _cell_center(enemy.pos))
		var source_cell := Vector2i(floori(source.x / CELL), floori(source.y / CELL))
		var delta := source_cell - player_position
		if delta.x != 0 and absi(delta.x) >= absi(delta.y):
			return Vector2i(signi(delta.x), 0)
		if delta.y != 0:
			return Vector2i(0, signi(delta.y))
	if action_direction in FOUR_WAY:
		return action_direction
	return facing if facing in FOUR_WAY else Vector2i.RIGHT


func _resolve_enemy_contact(index: int, recoil_direction: Vector2i) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	if _is_elite(enemy) and charges > 0 and not damage_this_turn and not dev_god_mode:
		_stagger_elite(index)
		return
	var shielded := charges > 0 and not damage_this_turn and not dev_god_mode
	var contact_delay := maxf(_contact_delay(), _enemy_contact_delay(enemy))
	var result := _apply_damage("FOSTE ALCANCADO", Color("6ceeff") if shielded else Color("ff4e70"), -recoil_direction, contact_delay)
	if result == "shield" and not _is_elite(enemy):
		_repel_common_enemy(index, recoil_direction, contact_delay)


func _shield_recoil_cell_free(point: Vector2i, enemy_index: int) -> bool:
	if point == player_position or not _is_floor(point):
		return false
	for i in enemies.size():
		if i == enemy_index:
			continue
		var other: Dictionary = enemies[i]
		if other.pos == point or other.get("next", other.pos) == point or other.get("path", []).has(point):
			return false
	return true


# Move at most two open cells, stopping at walls/occupants/reservations. If the
# primary direction is blocked, try the sides and then the rear deterministically.
# Recoil never damages ordinary enemies and does not consume an extra turn.
func _repel_common_enemy(index: int, direction: Vector2i, contact_delay: float = 0.0) -> void:
	var enemy: Dictionary = enemies[index]
	var primary := direction if direction in FOUR_WAY else Vector2i.RIGHT
	var options: Array[Vector2i] = [primary, Vector2i(-primary.y, primary.x), Vector2i(primary.y, -primary.x), -primary]
	var destination := player_position
	for option in options:
		var candidate := player_position
		for _step in 2:
			var next: Vector2i = candidate + option
			if not _shield_recoil_cell_free(next, index):
				break
			candidate = next
		if candidate != player_position:
			destination = candidate
			break
	if destination != player_position:
		# If the enemy was visibly approaching, finish that already-resolved
		# segment before recoil instead of teleporting it to the contact cell.
		var contact_center := _cell_center(player_position)
		var visible_origin := _enemy_visual_position(enemy)
		# Keep the two drawn bodies readable at the already-resolved shield
		# contact. This is an art-space separation only; neither occupancy nor
		# the actual recoil destination is changed.
		var contact_axis := (visible_origin - contact_center).normalized()
		if contact_axis.length_squared() < 0.01:
			contact_axis = Vector2(destination - player_position).normalized()
		enemy["_visual_contact_axis"] = contact_axis
		enemy["_visual_contact_turn"] = turn_number
		var approach = enemy.get("_visual_motion")
		if approach == null or not approach.is_active() or not approach.final_target().is_equal_approx(contact_center):
			enemy.erase("_visual_motion")
			if not visible_origin.is_equal_approx(contact_center):
				approach = VisualMotion.new()
				approach.reset(visible_origin)
				approach.enqueue(visible_origin, contact_center, "enemy_attack", maxf(0.008, contact_delay))
				enemy["_visual_motion"] = approach
		enemy.from = contact_center
		enemy.pos = destination
		enemy.to = _cell_center(destination)
		enemy.t = 0.0
		enemy["_visual_start_delay"] = contact_delay
		enemy["_visual_reaction_delay"] = contact_delay
		enemy["_visual_reaction_direction"] = Vector2(primary)
		last_notice = "INIMIGO PROJETADO — O ESCUDO ABSORVEU O IMPACTO"
	else:
		# Fully surrounded: retain the existing position rather than inventing
		# an illegal destination or tunnelling through a wall.
		enemy.erase("_visual_contact_turn")
		last_notice = "ESCUDO ABSORVEU O IMPACTO — SEM ESPACO PARA RECUAR"
	notice_timer = 2.0
	enemy.next = enemy.pos
	enemy["path"] = []
	enemy["shield_repel_turn"] = turn_number
	enemy["shield_repel_visual"] = destination != player_position
	enemies[index] = enemy


func _stagger_elite(index: int) -> void:
	if damage_this_turn or charges <= 0 or index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var contact_delay := maxf(_contact_delay(), _enemy_contact_delay(enemy))
	var contact_point := _cell_center(enemy.pos)
	var contact_direction := Vector2(enemy.pos - player_position).normalized()
	if contact_direction.length_squared() < 0.01:
		contact_direction = Vector2(facing)
	charges -= 1
	hits_this_floor += 1
	damage_this_turn = true
	# Shield counter and its explicit tree upgrade damage the elite.
	enemy["hp"] = maxi(0, int(enemy.get("hp", 2)) - 1 - _skill_effect("shield_counter"))
	if enemy.hp <= 0:
		_record_enemy_defeat(enemy, "impact", contact_delay)
		enemies.remove_at(index)
		last_notice = "%s DERROTADO PELO CONTRA-ATAQUE" % enemy.get("boss_name", "GUARDIAO")
		notice_timer = 2.0
		_queue_contact_feedback("ELITE_COUNTER", "shield", contact_point, -contact_direction, contact_delay, "shield", "shield_contact")
		_queue_contact_feedback("", "defeat", contact_point, contact_direction, contact_delay, str(enemy.get("role", "warden")), "", false)
		return
	var best_position: Vector2i = enemy.pos
	var best_distance := _manhattan(enemy.pos, player_position)
	var reserved: Dictionary = {}
	for other in enemies:
		if other != enemy:
			reserved[other.get("next", other.pos)] = true
	for direction in FOUR_WAY:
		var candidate: Vector2i = enemy.pos + direction
		if not _inside(candidate) or not _is_floor(candidate) or _enemy_at(candidate, enemy) or reserved.has(candidate):
			continue
		var distance := _manhattan(candidate, player_position)
		if distance > best_distance:
			best_distance = distance
			best_position = candidate
	var visible_origin := _enemy_visual_position(enemy)
	if best_position != enemy.pos:
		var contact_axis := (visible_origin - contact_point).normalized()
		if contact_axis.length_squared() < 0.01:
			contact_axis = Vector2(best_position - player_position).normalized()
		enemy["_visual_contact_axis"] = contact_axis
		enemy["_visual_contact_turn"] = turn_number
	else:
		enemy.erase("_visual_contact_turn")
	var approach = enemy.get("_visual_motion")
	if approach == null or not approach.is_active() or not approach.final_target().is_equal_approx(contact_point):
		enemy.erase("_visual_motion")
		if not visible_origin.is_equal_approx(contact_point):
			approach = VisualMotion.new()
			approach.reset(visible_origin)
			approach.enqueue(visible_origin, contact_point, "enemy_attack", maxf(0.008, contact_delay))
			enemy["_visual_motion"] = approach
	enemy["_visual_reaction"] = 0.0
	enemy["_visual_reaction_delay"] = contact_delay
	enemy["_visual_start_delay"] = contact_delay
	enemy["_visual_reaction_direction"] = Vector2(best_position - player_position).normalized()
	enemy.from = _cell_center(enemy.pos)
	enemy.pos = best_position
	enemy.to = _cell_center(best_position)
	enemy.next = best_position
	enemy["path"] = []
	enemy.t = 0.0
	enemies[index] = enemy
	last_notice = "%s RECUOU (%d/%d) — O ESCUDO QUEBROU" % [enemy.get("boss_name", "GUARDIAO"), enemy.hp, enemy.get("max_hp", 2)]
	notice_timer = 2.0
	_queue_contact_feedback("ELITE_COUNTER", "shield", contact_point, -contact_direction, contact_delay, "shield", "shield_contact")
	_queue_contact_feedback("", "elite", contact_point, contact_direction, contact_delay, str(enemy.get("role", "warden")), "", false)


func _heart_recoil_cell_free(point: Vector2i) -> bool:
	if not _is_floor(point) or environment.is_electrified(point):
		return false
	for enemy in enemies:
		if enemy.pos == point or enemy.get("next", enemy.pos) == point or enemy.get("path", []).has(point):
			return false
	for trap in traps:
		if trap.pos == point and trap.get("armed", true):
			if trap.get("type", "one_shot") != "rhythm" or _rhythm_is_hot(trap, turn_number):
				return false
	return true


func _heart_knockback(preferred: Vector2i, contact_delay: float = 0.0) -> bool:
	# One cardinal step, no extra turn. Never land in a reserved path or hazard.
	var primary := preferred if preferred in FOUR_WAY else (-facing if facing in FOUR_WAY else Vector2i.LEFT)
	var directions: Array[Vector2i] = [primary, Vector2i(-primary.y, primary.x), Vector2i(primary.y, -primary.x), -primary]
	for direction in directions:
		var destination := player_position + direction
		if not _heart_recoil_cell_free(destination):
			continue
		var wait := maxf(0.0, contact_delay - player_motion.remaining_time())
		_begin_player_move(destination, "heart_recoil", wait)
		_collect_pickups()
		_activate_switches()
		if environment.is_active():
			_sync_environment_mechanisms()
		return true
	return false


# All existing enemy, trap and electrical damage is protectable; no hidden
# bypass. One consequence per committed action, then shield -> heart -> capture.
func _apply_damage(message: String, color: Color, recoil_direction: Vector2i = Vector2i.ZERO, resolved_contact_delay: float = -1.0) -> String:
	if damage_this_turn or dev_god_mode:
		return "ignored"
	damage_this_turn = true
	var contact_point := _cell_center(player_position)
	var contact_delay := maxf(_contact_delay(), resolved_contact_delay)
	var direction := Vector2(recoil_direction if recoil_direction in FOUR_WAY else -facing)
	var electrical := message.contains("ELETRIFIC")
	if charges > 0:
		charges -= 1
		hits_this_floor += 1
		last_notice = message + " — O ESCUDO ABSORVEU O IMPACTO"
		notice_timer = 2.0
		_queue_contact_feedback("SHIELD_IMPACT", "shield", contact_point, direction, contact_delay, "shield", "electric_contact" if electrical else "shield_contact")
		if electrical:
			_queue_contact_feedback("", "electric", contact_point, direction, contact_delay, "electricity", "", false)
		return "shield"
	if not lab_active and hearts_current > 0:
		hearts_current -= 1
		hits_this_floor += 1
		var after_loss := hearts_current
		_queue_contact_feedback("HEART_LOST", "electric" if electrical else "hurt", contact_point, direction, contact_delay, "electricity" if electrical else "heart")
		pickup_feedback_delay = minf(ImpactPresentation.MAX_PENDING_DELAY, contact_delay + WALK_VISUAL_TIME)
		var moved := _heart_knockback(recoil_direction, contact_delay)
		pickup_feedback_delay = -1.0
		last_notice = message + (" — CORACAO PERDIDO; RECUASTE" if moved else " — CORACAO PERDIDO; SEM ESPACO PARA RECUAR")
		if hearts_current > after_loss:
			last_notice += " / CORACAO RECUPERADO"
		notice_timer = 2.4
		return "heart"
	_begin_capture(message, color, contact_delay, direction)
	return "capture"


func _begin_capture(message: String, color: Color, contact_delay: float = -1.0, contact_direction: Vector2 = Vector2.LEFT) -> void:
	game_state = "captured"
	capture_time = 0.0
	capture_darkness = 0.0
	capture_flash = 0.0
	capture_origin = _cell_center(player_position)
	capture_popped = false
	capture_puddle_active = false
	capture_puddle_points.clear()
	capture_splats.clear()
	capture_shockwave_radius = 0.0
	capture_chromatic = 0.0
	capture_noise = 0.0
	# Capture is logically immediate, but the already-resolved path may finish
	# visually at the actual contact cell before the pop. Never replay input.
	if not _player_motion_fields_match() or not player_motion.final_target().is_equal_approx(capture_origin):
		_reset_player_visual(capture_origin)
	turn_pulse_pending = false
	turn_pulse_time = -1.0
	blocked_feedback_time = 0.0
	blocked_feedback_pending = false
	attack_feedback_time = 0.0
	attack_feedback_delay = 0.0
	impact_feedback_time = 0.0
	last_notice = message
	shake_time = 0.18
	shake_strength = 5.0
	flash_time = 0.13
	flash_color = color
	if contact_delay >= 0.0:
		_queue_contact_feedback("CAPTURE_START", "capture", capture_origin, contact_direction, contact_delay, "capture")
	else:
		_emit_feedback("CAPTURE_START")
	_update_capture_overlay()


func _trigger_capture_burst() -> void:
	if capture_popped:
		return
	capture_popped = true
	capture_puddle_active = true
	capture_puddle_points = _make_puddle_outline()
	capture_splats.clear()
	for i in 15:
		var angle := TAU * float(i) / 15.0 + visual_rng.randf_range(-0.2, 0.2)
		var radius := visual_rng.randf_range(CELL * 0.50, CELL * 1.10)
		var offset := Vector2(cos(angle) * radius * 0.98, sin(angle) * radius * 0.84)
		capture_splats.append({"pos": capture_origin + offset, "radius": visual_rng.randf_range(2.5, 8.0)})
	_spawn_blood_burst(capture_origin)
	_emit_feedback("CAPTURE_POP")
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
		var roughness := visual_rng.randf_range(0.965, 1.035)
		outline.append(capture_origin + Vector2(cos(angle) * CELL * 1.28 * roughness, sin(angle) * CELL * 1.16 * roughness))
	return outline


func _spawn_shockwave(origin: Vector2, start_r: float, max_r: float, col: Color, duration: float) -> void:
	particles.append({
		"kind": "shockwave",
		"pos": origin,
		"velocity": Vector2.ZERO,
		"radius": start_r,
		"max_radius": max_r,
		"life": duration,
		"max_life": duration,
		"color": col
	})


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
		var angle := TAU * float(i) / 75.0 + visual_rng.randf_range(-0.18, 0.18)
		var speed := visual_rng.randf_range(90.0, 310.0)
		var color := Color("ff3154") if i % 4 == 0 else Color("8a051e") if i % 3 == 0 else Color("d6123a")
		particles.append({
			"kind": "blood",
			"pos": origin,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": visual_rng.randf_range(0.55, 1.15),
			"max_life": 1.15,
			"color": color,
			"size": visual_rng.randf_range(3.2, 7.5),
			"gravity": visual_rng.randf_range(160.0, 360.0)
		})
	# Gotas pesadas viscosas perto do ponto de impacto
	for i in 25:
		var offset := Vector2(visual_rng.randf_range(-CELL * 0.65, CELL * 0.65), visual_rng.randf_range(-CELL * 0.55, CELL * 0.55))
		particles.append({
			"kind": "blood",
			"pos": origin + offset,
			"velocity": Vector2(visual_rng.randf_range(-55.0, 55.0), visual_rng.randf_range(-65.0, 35.0)),
			"life": visual_rng.randf_range(0.35, 0.8),
			"max_life": 0.8,
			"color": Color("ff637b"),
			"size": visual_rng.randf_range(2.0, 4.5),
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
			last_notice = "FOSTE CAPTURADO — R REINICIA A CAMARA" if lab_active else "FOSTE CAPTURADO — R CONTINUA NO ANDAR %d" % floor_number
			if not lab_active:
				skills.load_state(floor_start_snapshot.get("skills", skills.serialize()))
				hearts_current = clampi(int(floor_start_snapshot.get("hearts", 0)), 0, skills.effect("heart_capacity"))
				_save_resume(floor_number, int(floor_start_snapshot.get("coins", 0)),
					int(floor_start_snapshot.get("charges", 0)), int(floor_start_snapshot.get("breach_charges", 0)),
					floor_start_snapshot.get("history", []), floor_start_snapshot.get("facing", Vector2i.RIGHT),
					floor_start_snapshot.get("powers", {}))
	elif game_state == "game_over":
		capture_darkness = 0.91
		capture_flash = 0.0
		capture_chromatic = 0.0
		capture_noise = 0.20
	_update_capture_overlay()


func _update_capture_overlay() -> void:
	if audio != null and audio.has_method("set_capture_mix"):
		audio.set_capture_mix(capture_darkness)
	if capture_material == null or capture_overlay == null:
		return
	# All four terms contribute to alpha in the shader. Hide only when the
	# result is transparent, or an opaque menu completely covers the world.
	# This avoids a full-screen shader pass during ordinary play.
	var active := _world_is_visible() and (capture_darkness > 0.0 or capture_flash > 0.0 or capture_noise > 0.0 or (capture_shockwave_radius > 0.001 and capture_shockwave_radius < 1.2))
	if capture_overlay.visible != active:
		capture_overlay.visible = active
	if not active:
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
		last_notice = "PORTAL BLOQUEADO — ATIVA AS PLACAS" if objective_type == "environment" else "PORTAL BLOQUEADO — ATIVA OS INTERRUPTORES"
		notice_timer = 2.0
		return
	if lab_active:
		game_state = "floor_clear"
		last_notice = "CAMARA CONCLUIDA — SEM ALTERAR A CAMPANHA"
		notice_timer = 999.0
		_emit_feedback("PORTAL_ENTER")
		return
	if is_challenge_met() and not challenge_complete:
		challenge_complete = true
		last_notice = "DESAFIO CUMPRIDO  +5 MOEDAS"
		_spawn_burst(_cell_center(portal_position), Color("ffd15d"), 26, 170.0)
		_emit_feedback("SWITCH_ON")
	stars_last_floor = _stars_for_floor()
	last_skill_point_awarded = skills.award_floor(floor_number)
	floor_history.append(stars_last_floor)
	floor_reward = stars_last_floor * 2 + (5 if challenge_complete else 0)
	total_coins += floor_reward
	if total_coins > best_score:
		best_score = total_coins
		best_score_dirty = true
	_spawn_burst(_cell_center(portal_position), Color("c476ff"), 42, 240.0)
	_emit_feedback("PORTAL_ENTER")
	var rescue_milestone := floor_number % 5 == 0
	if rescue_milestone:
		game_state = "rescued"
		if floor_number == 5:
			last_notice = "LIA AVISTADA EM ESTASE — LIBERTA-A NO ANDAR 100!"
		elif floor_number == 100:
			if not floor_stars.has("100"):
				rescues_completed += 1
			last_notice = "LIA FOI LIBERTADA! CAMPANHA CONTINUA ATE AO ANDAR 200"
		else:
			last_notice = "CICLO %d CONCLUIDO — SETOR SEGUINTE DESBLOQUEADO" % (floori(float(floor_number - 1) / 5.0) + 1)
	else:
		game_state = "floor_clear"
		last_notice = "ANDAR %d CONCLUIDO — ENTER PARA AVANCAR" % floor_number
	furthest_floor = maxi(furthest_floor, floor_number + 1)
	var star_key := str(floor_number)
	floor_stars[star_key] = maxi(int(floor_stars.get(star_key, 0)), stars_last_floor)
	notice_timer = 999.0
	_save_resume(floor_number + 1, total_coins, charges, breach_charges, floor_history, facing)


func advance_floor() -> void:
	if lab_active and game_state == "floor_clear":
		if lab_index + 1 < EnvironmentChambers.COUNT:
			_load_lab_chamber(lab_index + 1)
		else:
			handle_hud_action("menu")
		return
	if game_state == "floor_clear" or game_state == "rescued":
		generate_floor(floor_number + 1)
		game_state = "playing"
		_begin_captor_flyover_if_needed()


func _stars_for_floor() -> int:
	var fraction := float(coins_this_floor) / maxf(1.0, float(coins.size() + coins_this_floor))
	if fraction >= 1.0: return 5
	if fraction >= 0.75: return 4
	if fraction >= 0.5: return 3
	if fraction >= 0.25: return 2
	return 1


func get_objective_text() -> String:
	if objective_type == "environment":
		return "PLACAS %d/%d  /  %s" % [environment.active_plate_count(), environment.plates.size(), "PORTAL ABERTO" if portal_open else "PORTAL BLOQUEADO"]
	if objective_type == "puzzle":
		return "RUNAS %d/3  /  %s" % [_active_switches(), "PORTAL ABERTO" if portal_open else "SEGUIR A ORDEM"]
	if objective_type == "switches":
		return "INTERRUPTORES %d/%d   /   %s" % [_active_switches(), switches.size(), "PORTAL ABERTO" if portal_open else "PORTAL BLOQUEADO"]
	if game_state == "rescued":
		if floor_number == 5:
			return "LIA FOI AVISTADA! ALCANCA O ANDAR 100 PARA A LIBERTAR."
		elif floor_number == 100:
			return "LIA FOI LIBERTADA! A JORNADA CONTINUA ATE AO ANDAR 200."
		return "SETOR CONCLUIDO. SEGUE EM FRENTE."
	return "OBJETIVO: ALCANCA O PORTAL E ENCONTRA LIA"


func _campaign_payload() -> Dictionary:
	return {
		"best_score": best_score, "rescues": rescues_completed, "furthest_floor": furthest_floor,
		"floor_stars": floor_stars.duplicate(true), "has_resume": has_resume,
		"resume_floor": resume_floor, "resume_coins": resume_coins, "resume_charges": resume_charges,
		"resume_breach_charges": resume_breach_charges, "resume_powers": _normalized_power_state(resume_powers),
		"resume_facing": resume_facing, "resume_seed": resume_seed, "resume_history": Array(resume_history),
		"resume_hearts": resume_hearts, "skills": skills.serialize(), "captor_intro_seen": captor_intro_seen,
	}


func _apply_campaign_payload(data: Dictionary) -> void:
	best_score = int(data.get("best_score", 0))
	rescues_completed = int(data.get("rescues", 0))
	captor_intro_seen = bool(data.get("captor_intro_seen", false))
	captor_flyover_time = 0.0
	furthest_floor = maxi(1, int(data.get("furthest_floor", 1)))
	var stars: Variant = data.get("floor_stars", {})
	floor_stars = stars.duplicate(true) if stars is Dictionary else {}
	has_resume = bool(data.get("has_resume", false))
	resume_floor = maxi(1, int(data.get("resume_floor", 1)))
	resume_coins = maxi(0, int(data.get("resume_coins", 0)))
	resume_charges = maxi(0, int(data.get("resume_charges", 0)))
	resume_breach_charges = maxi(0, int(data.get("resume_breach_charges", 0)))
	resume_powers = _normalized_power_state(data.get("resume_powers", {}))
	var saved_facing: Variant = data.get("resume_facing", Vector2i.RIGHT)
	resume_facing = saved_facing if saved_facing is Vector2i and saved_facing in FOUR_WAY else Vector2i.RIGHT
	resume_seed = int(data.get("resume_seed", 0))
	resume_history.clear()
	var history: Variant = data.get("resume_history", [])
	if history is Array or history is PackedInt32Array or history is PackedInt64Array:
		for value in history:
			resume_history.append(int(value))
	if not skills.load_state(data.get("skills", {})):
		push_warning("Estado de habilidades invalido; campanha nao deve ser substituida")
	resume_hearts = clampi(int(data.get("resume_hearts", 0)), 0, skills.effect("heart_capacity"))
	hearts_current = resume_hearts
	floor_start_snapshot.clear()
	unresolved_contacts.clear()


func _legacy_campaign(profile: ConfigFile) -> Dictionary:
	var saved_history: Variant = profile.get_value("progress", "resume_history", [])
	var history: Array[int] = []
	if saved_history is Array or saved_history is PackedInt32Array or saved_history is PackedInt64Array:
		for value in saved_history:
			history.append(clampi(int(value), 0, 5))
	var raw_stars: Variant = profile.get_value("progress", "floor_stars", {})
	var stars: Dictionary = raw_stars.duplicate(true) if raw_stars is Dictionary else {}
	var old_skills = SkillTree.new()
	old_skills.mark_legacy_floors(stars)
	var saved_facing: Variant = profile.get_value("progress", "resume_facing", Vector2i.RIGHT)
	return {
		"best_score": maxi(0, int(profile.get_value("progress", "best_score", 0))),
		"rescues": maxi(0, int(profile.get_value("progress", "rescues", 0))),
		"furthest_floor": maxi(1, int(profile.get_value("progress", "furthest_floor", 1))),
		"floor_stars": stars,
		"has_resume": bool(profile.get_value("progress", "has_resume", false)),
		"resume_floor": maxi(1, int(profile.get_value("progress", "resume_floor", 1))),
		"resume_coins": maxi(0, int(profile.get_value("progress", "resume_coins", 0))),
		"resume_charges": maxi(0, int(profile.get_value("progress", "resume_charges", 0))),
		"resume_breach_charges": maxi(0, int(profile.get_value("progress", "resume_breach_charges", 0))),
		"resume_powers": _normalized_power_state(profile.get_value("progress", "resume_powers", {})),
		"resume_facing": saved_facing if saved_facing is Vector2i and saved_facing in FOUR_WAY else Vector2i.RIGHT,
		"resume_seed": int(profile.get_value("progress", "resume_seed", 0)), "resume_history": Array(history),
		"resume_hearts": 0, "skills": old_skills.serialize(),
		"captor_intro_seen": bool(profile.get_value("progress", "captor_intro_seen", false)),
	}


func _load_profile() -> void:
	if not persistence_enabled:
		return
	campaign_storage.profile_path = profile_path
	var profile := ConfigFile.new()
	var exists := FileAccess.file_exists(profile_path)
	var error := profile.load(profile_path) if exists else OK
	if error != OK:
		profile_blocked = true
		profile_message = "PERFIL GLOBAL DANIFICADO; ORIGINAL PRESERVADO. RESTAURA O BACKUP NO MENU."
	elif int(profile.get_value("meta", "version", 0)) > 2:
		profile_blocked = true
		profile_message = "PERFIL GLOBAL DE VERSAO MAIS RECENTE; ORIGINAL PRESERVADO."
	else:
		controller_vibration_enabled = bool(profile.get_value("controller", "vibration", true))
		var has_intensity := profile.has_section_key("controller", "vibration_intensity")
		var intensity_version := int(profile.get_value("controller", "vibration_intensity_version", 1))
		var saved_intensity := float(profile.get_value("controller", "vibration_intensity", ControllerScript.MAX_VIBRATION_INTENSITY))
		if not is_finite(saved_intensity):
			saved_intensity = ControllerScript.MAX_VIBRATION_INTENSITY
		elif has_intensity and intensity_version < VIBRATION_PROFILE_VERSION and is_equal_approx(saved_intensity, 1.0):
			saved_intensity = ControllerScript.MAX_VIBRATION_INTENSITY
		controller_vibration_intensity = clampf(saved_intensity, 0.0, ControllerScript.MAX_VIBRATION_INTENSITY)
		var saved_mappings: Variant = profile.get_value("controller", "mappings", {})
		controller_mappings = saved_mappings.duplicate(true) if saved_mappings is Dictionary else {}
		if int(profile.get_value("meta", "version", 0)) >= 2:
			active_slot = clampi(int(profile.get_value("meta", "active_campaign", 0)), 0, 2)
			_load_campaign_slot(active_slot)
		elif profile.has_section("progress"):
			var legacy := _legacy_campaign(profile)
			if int(legacy.rescues) > 0 and int(legacy.furthest_floor) <= 5:
				legacy.furthest_floor = 6
				if not legacy.has_resume:
					legacy.has_resume = true
					legacy.resume_floor = 6
					legacy.resume_seed = int(Time.get_ticks_usec())
			_apply_campaign_payload(legacy)
			legacy_profile_pending = true
			legacy_profile_hash = FileAccess.get_sha256(profile_path)
			var existing := campaign_storage.read_slot(0)
			if existing.status == "ok" and existing.legacy_sha256 == legacy_profile_hash:
				# Interrupted migration: the already-verified campaign belongs to
				# this exact original profile. Keep the newer checkpoint.
				_apply_campaign_payload(existing.data)
			elif existing.status != "empty":
				profile_blocked = true
				profile_message = "MIGRACAO EM CONFLITO: PERFIL ANTIGO E CAMPANHA 1 PRESERVADOS."
		else:
			_load_campaign_slot(0)
	if controller != null:
		controller.set_settings(controller_vibration_enabled, controller_mappings, controller_vibration_intensity)


func _load_campaign_slot(slot: int) -> bool:
	if not persistence_enabled:
		_apply_campaign_payload(transient_campaigns[slot])
		return true
	campaign_storage.profile_path = profile_path
	var result := campaign_storage.read_slot(slot)
	if result.status == "empty":
		_apply_campaign_payload({})
		return true
	if result.status != "ok":
		_apply_campaign_payload({})
		profile_message = "CAMPANHA %d DANIFICADA OU MAIS RECENTE; ORIGINAL PRESERVADO." % (slot + 1)
		return false
	_apply_campaign_payload(result.data)
	return true


func _save_profile() -> bool:
	# Dev experiments must not overwrite real slots, backups, or transient slots.
	if dev_sandbox_active:
		return true
	if not persistence_enabled:
		transient_campaigns[active_slot] = _campaign_payload() if has_resume or furthest_floor > 1 or not floor_stars.is_empty() else {}
		return true
	campaign_storage.profile_path = profile_path
	if profile_blocked:
		push_warning(profile_message)
		return false
	var profile := ConfigFile.new()
	if FileAccess.file_exists(profile_path):
		if profile.load(profile_path) != OK or int(profile.get_value("meta", "version", 0)) > 2:
			profile_blocked = true
			profile_message = "PERFIL GLOBAL INVALIDO OU MAIS RECENTE; ORIGINAL PRESERVADO."
			push_warning(profile_message)
			return false
		if profile.has_section("progress") and int(profile.get_value("meta", "version", 0)) < 2 and not legacy_profile_pending:
			profile_blocked = true
			profile_message = "PERFIL ANTIGO ALTERADO EXTERNAMENTE; ORIGINAL PRESERVADO."
			return false
		# Do not silently migrate a profile which was changed externally.
		if legacy_profile_pending and FileAccess.get_sha256(profile_path) != legacy_profile_hash:
			profile_blocked = true
			profile_message = "O PERFIL ANTIGO FOI ALTERADO; MIGRACAO INTERROMPIDA SEM APAGAR DADOS."
			return false
	var migration_hash := ""
	if legacy_profile_pending:
		var backup := campaign_storage.backup_legacy()
		if not backup.ok:
			profile_message = str(backup.get("error", "BACKUP DO PERFIL ANTIGO FALHOU"))
			push_warning(profile_message)
			return false
		migration_hash = str(backup.sha256)
		var old_slot := campaign_storage.read_slot(0)
		if old_slot.status != "empty" and (old_slot.status != "ok" or old_slot.legacy_sha256 != migration_hash):
			profile_message = "CAMPANHA 1 JA OCUPADA; PERFIL ANTIGO E CAMPANHA PRESERVADOS."
			push_warning(profile_message)
			return false
	var payload := _campaign_payload()
	var needs_slot: bool = has_resume or furthest_floor > 1 or not floor_stars.is_empty() or not skills.unlocked.is_empty() or skills.points > 0 or legacy_profile_pending
	if needs_slot:
		var saved := campaign_storage.save_slot(active_slot, payload, migration_hash)
		if not saved.ok:
			profile_message = str(saved.error)
			push_warning(profile_message)
			return false
	profile.set_value("meta", "version", 2)
	profile.set_value("meta", "active_campaign", active_slot)
	profile.set_value("controller", "vibration", controller_vibration_enabled)
	profile.set_value("controller", "vibration_intensity", controller_vibration_intensity)
	profile.set_value("controller", "vibration_intensity_version", VIBRATION_PROFILE_VERSION)
	profile.set_value("controller", "mappings", controller_mappings)
	# Mirror old progress fields for tools/older readers. The authoritative saves
	# are the three independently backed-up campaign files.
	for key in ["best_score", "rescues", "furthest_floor", "floor_stars", "has_resume", "resume_floor", "resume_coins", "resume_charges", "resume_breach_charges", "resume_powers", "resume_facing", "resume_seed", "resume_history", "captor_intro_seen"]:
		profile.set_value("progress", key, payload[key])
	var saved_global := campaign_storage.save_global(profile)
	if not saved_global.ok:
		profile_message = str(saved_global.error)
		push_warning(profile_message)
		return false
	legacy_profile_pending = false
	legacy_profile_hash = ""
	profile_message = ""
	best_score_dirty = false
	return true


func campaign_status(slot: int) -> Dictionary:
	if not persistence_enabled:
		return {"status": "empty"} if transient_campaigns[slot].is_empty() else {"status": "ok", "data": transient_campaigns[slot].duplicate(true)}
	campaign_storage.profile_path = profile_path
	if slot == active_slot and legacy_profile_pending:
		return {"status": "ok", "data": _campaign_payload(), "backup": false}
	var result := campaign_storage.read_slot(slot)
	result["backup"] = campaign_storage.read_slot(slot, true).status == "ok"
	result["replaced_backup"] = campaign_storage.read_replaced(slot).status == "ok"
	return result


func select_campaign(slot: int) -> bool:
	_leave_dev_sandbox()
	if slot < 0 or slot > 2:
		return false
	var target := campaign_status(slot)
	if target.status not in ["empty", "ok"]:
		slot_message = "CAMPANHA INVALIDA: RESTAURA BACKUP OU ESCOLHE OUTRA."
		return false
	if slot != active_slot:
		if not profile_blocked and not _save_profile():
			slot_message = "NAO FOI POSSIVEL GUARDAR A CAMPANHA ATUAL."
			return false
		active_slot = slot
		if not _load_campaign_slot(slot):
			return false
		if not profile_blocked:
			_save_profile()
	return true


func restore_campaign(slot: int, kind: String = "checkpoint") -> bool:
	_leave_dev_sandbox()
	campaign_storage.profile_path = profile_path
	var result := campaign_storage.restore_slot(slot, kind)
	if not result.ok:
		slot_message = str(result.error)
		return false
	if slot == active_slot:
		_load_campaign_slot(slot)
	slot_message = "BACKUP DA CAMPANHA %d RESTAURADO; VERSAO ANTERIOR ARQUIVADA." % (slot + 1)
	return true


func set_controller_vibration_intensity(value: float) -> void:
	var safe_value := clampf(value, 0.0, ControllerScript.MAX_VIBRATION_INTENSITY) if is_finite(value) else ControllerScript.MAX_VIBRATION_INTENSITY
	var stepped: float = roundf(safe_value * 20.0) / 20.0
	controller.set_vibration_intensity(stepped)
	controller_message = "INTENSIDADE: %d%%" % roundi(stepped * 100.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and controller != null:
		# A release event can be lost while the window is unfocused. Never keep
		# repeating a held direction or vibrating an unattended controller.
		if controller.calibration_device >= 0:
			controller.cancel_calibration()
		controller.reset_held_inputs()
		controller.note_keyboard_or_mouse()
		if hud != null:
			hud.cancel_pointer_drag()


func _exit_tree() -> void:
	# A record earned mid-floor should survive quitting without writing per coin.
	if best_score_dirty and not dev_sandbox_active:
		_save_profile()


func _process(delta: float) -> void:
	if captor_flyover_time > 0.0 and game_state == "playing":
		captor_flyover_time = maxf(0.0, captor_flyover_time - delta)
	# Only the presentation clock is held. Input, turns, game timers, capture,
	# audio/haptic drivers, collision and logical positions still use real time.
	var presentation: Dictionary = impact_presentation.advance(delta, game_state == "paused" or not _world_is_visible())
	var visual_delta: float = presentation.visual_delta
	var player_contact := false
	for contact in presentation.contacts:
		_on_presentation_contact(contact)
		if not bool(contact.get("canceled", false)) and str(contact.kind) in ["shield", "hurt", "electric", "capture"] and bool(contact.context.get("affects_player", true)):
			player_contact = true
	animation_clock += visual_delta
	landing_feedback_time = maxf(0.0, landing_feedback_time - visual_delta)
	blocked_feedback_time = maxf(0.0, blocked_feedback_time - visual_delta)
	blocked_crate_time = maxf(0.0, blocked_crate_time - visual_delta)
	if attack_feedback_delay > 0.0:
		var wait := attack_feedback_delay
		attack_feedback_delay = maxf(0.0, wait - visual_delta)
		if attack_feedback_delay == 0.0:
			attack_feedback_time = maxf(0.0, 0.26 - maxf(0.0, visual_delta - wait))
	else:
		attack_feedback_time = maxf(0.0, attack_feedback_time - visual_delta)
	if not player_contact:
		impact_feedback_time = maxf(0.0, impact_feedback_time - visual_delta)
	near_miss_feedback_time = maxf(0.0, near_miss_feedback_time - visual_delta)
	# Age old effects before adding arrivals in this frame; a long frame must not
	# instantly consume a freshly generated water or ice response.
	_advance_transient_motion_effects(visual_delta)
	_advance_player_motion(visual_delta)
	_advance_crate_visuals(visual_delta)
	_advance_electric_visuals(visual_delta)
	if blocked_crate_pending and not player_motion.is_active() and not crate_visual_tracks.has(blocked_crate_index):
		blocked_crate_pending = false
		blocked_crate_time = 0.16
	if turn_pulse_pending:
		if not player_motion.is_active():
			turn_pulse_pending = false
			turn_pulse_time = 0.0
	elif turn_pulse_time > -1.0:
		turn_pulse_time += visual_delta
		if turn_pulse_time > 0.28:
			turn_pulse_time = -1.0
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		var actor_delta := visual_delta
		var start_delay := float(enemy.get("_visual_start_delay", 0.0))
		if start_delay > 0.0:
			var spent := minf(start_delay, actor_delta)
			actor_delta -= spent
			enemy["_visual_start_delay"] = maxf(0.0, start_delay - spent)
		enemy.t = minf(1.0, enemy.t + actor_delta / 0.14)
		var track = enemy.get("_visual_motion")
		if track != null and track.is_active():
			# A committed approach may continue while the recoil itself waits.
			track.advance(visual_delta)
		if track != null and not track.is_active() and enemy.has("_visual_start_delay"):
			enemy.erase("_visual_motion")
		if enemy.has("_visual_reaction_delay"):
			var delay := float(enemy._visual_reaction_delay)
			if delay <= visual_delta:
				enemy.erase("_visual_reaction_delay")
				enemy["_visual_reaction"] = maxf(0.0, 0.22 - maxf(0.0, visual_delta - delay))
			else:
				enemy["_visual_reaction_delay"] = delay - visual_delta
		elif enemy.has("_visual_reaction"):
			enemy["_visual_reaction"] = maxf(0.0, float(enemy._visual_reaction) - visual_delta)
		enemies[i] = enemy
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.life -= visual_delta
		var vel: Vector2 = particle.get("velocity", Vector2.ZERO)
		particle.pos += vel * visual_delta
		if particle.get("kind", "") == "blood":
			vel += Vector2(0.0, float(particle.get("gravity", 220.0))) * visual_delta
			vel *= pow(0.38, visual_delta)
			particle["velocity"] = vel
		elif particle.get("kind", "") == "shockwave":
			pass
		else:
			vel *= pow(0.08, visual_delta)
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
	if controller != null:
		# Age existing voices before this frame can emit a capture-pop event;
		# a long frame must not instantly skip a freshly requested signature.
		controller.tick(delta)
	_update_capture_sequence(delta)
	visible_threat_distance = _nearest_visible_threat() if game_state == "playing" and not dev_menu_open else -1
	var target_aura := 0.0 if visible_threat_distance < 0 else clampf((5.0 - visible_threat_distance) / 4.0, 0.0, 1.0)
	threat_aura = move_toward(threat_aura, target_aura, delta * 2.5)
	if feedback_bus != null:
		feedback_bus.tick(delta, visible_threat_distance, game_state == "playing" and not dev_menu_open, _current_threat_level())
	_update_camera(delta)
	var view := _visible_world_rect()
	var draw_world := _world_is_visible()
	if electric_presentation != null:
		electric_presentation.update_presentation(view, draw_world, visual_delta)
	_update_background_visibility(view, draw_world)
	if background_rect != null and background_rect.visible and camera != null:
		var background_material := background_rect.material as ShaderMaterial
		background_material.set_shader_parameter("camera_offset", camera.global_position / 2048.0)
	if terrain_renderer != null:
		terrain_renderer.sync_view(view, draw_world)
	queue_redraw()


func _current_threat_level() -> float:
	if game_state != "playing":
		return 0.0
	var intensity := 0.0
	for enemy in enemies:
		var distance := _manhattan(enemy.pos, player_position)
		if distance <= 8:
			intensity = maxf(intensity, 1.0 - float(distance) / 10.0)
		if _is_elite(enemy):
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
	
	# Tremer a câmara inteira uniformemente (chão, paredes, itens, inimigos)
	if shake_time > 0.0:
		camera.offset = Vector2(visual_rng.randf_range(-1.0, 1.0), visual_rng.randf_range(-1.0, 1.0)) * shake_strength * (shake_time / 0.25)
	else:
		camera.offset = Vector2.ZERO
	if near_miss_feedback_time > 0.0:
		# Deterministic and very small; never consume the gameplay RNG.
		camera.offset += Vector2(sin(animation_clock * 58.0), cos(animation_clock * 49.0)) * (near_miss_feedback_time / 0.16) * 1.1


func _input(event: InputEvent) -> void:
	if controller == null:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller.handle_event(event)
		# Our menus are custom-drawn Controls. Consume joypad input before the
		# default ui_accept/ui_cancel bindings can also activate them.
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseMotion and event.relative.length_squared() > 0.0):
		controller.note_keyboard_or_mouse()


func _unhandled_input(event: InputEvent) -> void:
	# Also permits callers/tests that directly deliver an unhandled event.
	# Normal engine events have already been consumed in _input above.
	if controller != null and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		controller.handle_event(event)


func _on_controller_action(action: String) -> void:
	if game_state == "playing" and captor_flyover_time > 0.0:
		if action in ["confirm", "cancel", "pause"]:
			_finish_captor_flyover()
		return
	if game_state in ["captured", "controller_mapping"]:
		return
	var directions := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
	if dev_menu_open and game_state == "playing":
		if action in ["dev", "cancel", "pause"]:
			controller.feedback("menu_confirm")
			dev_toggle_menu()
		elif directions.has(action):
			if hud.move_focus(directions[action]):
				controller.feedback("menu_move")
		elif action == "confirm":
			controller.feedback("menu_confirm")
			hud.activate_focus()
		return
	if game_state == "playing":
		if directions.has(action):
			facing = directions[action]
			try_move(facing.x, facing.y)
		elif action == "confirm":
			try_jump()
		elif action == "break":
			try_break_wall()
		elif action == "wait":
			wait_turn()
		elif action == "blink":
			try_blink()
		elif action == "cancel" and special_family == "sokoban" and controller.button_label("pause") != "--":
			undo_sokoban_move()
		elif action in ["pause", "cancel"]:
			controller.feedback("menu_confirm")
			game_state = "paused"
		elif action == "dev":
			controller.feedback("menu_confirm")
			dev_toggle_menu()
		return
	if directions.has(action):
		if hud.move_focus(directions[action]):
			controller.feedback("menu_move")
	elif action == "confirm":
		controller.feedback("menu_confirm")
		hud.activate_focus()
	elif action in ["cancel", "pause"]:
		controller.feedback("menu_confirm")
		match game_state:
			"paused": handle_hud_action("resume")
			"controller_settings": handle_hud_action("controller_back")
			"level_select", "game_over", "floor_clear", "rescued", "campaign_select": handle_hud_action("menu")
			"campaign_confirm": handle_hud_action("campaign_cancel")
			"skill_tree": handle_hud_action("skill_back")
			"skill_confirm": handle_hud_action("skill_remove_cancel")


func _emit_feedback(event: String, context: Dictionary = {}) -> void:
	if pickup_feedback_delay >= 0.0 and not bool(context.get("defer_presentation", false)) and event in ["COIN_PICKUP", "SHIELD_PICKUP", "HEART_RECOVERED", "BREAKER_PICKUP", "POWER_SPEED", "POWER_MAGNET", "POWER_BLINK", "POWER_TIME_FREEZE", "SWITCH_ON", "PUZZLE_ERROR", "PORTAL_OPEN"]:
		var point := _cell_center(portal_position if event == "PORTAL_OPEN" else player_position)
		_queue_contact_feedback(event, "pickup", point, Vector2(facing), pickup_feedback_delay, event, "", false)
		return
	if feedback_bus != null:
		feedback_bus.emit_event(event, context)


func _contact_delay(extra: float = 0.0) -> float:
	var remaining: float = player_motion.remaining_time() if _player_motion_fields_match() and player_motion.is_active() else 0.0
	return clampf(remaining + extra, 0.0, ImpactPresentation.MAX_PENDING_DELAY)


func _flush_pending_impact_cues() -> void:
	# Transition/restart drops stale art and timing, but each already-emitted
	# semantic fact retains its one audio/haptic cue before the old room goes.
	if feedback_bus == null:
		return
	for pending in impact_presentation.effects:
		if not bool(pending.contacted) and not str(pending.event).is_empty():
			feedback_bus.present_event(str(pending.event), pending.context)


func _queue_contact_feedback(event: String, kind: String, point: Vector2, direction: Vector2, delay: float, material: String = "", sound_override: String = "", affects_player: bool = true) -> void:
	var context := {"defer_presentation": true, "impact_kind": kind, "material": material, "affects_player": affects_player}
	if event == "DEMOLITION":
		context["attack_delay"] = maxf(0.0, delay - 0.07)
	if not sound_override.is_empty():
		context["sound_override"] = sound_override
		if event in ["SHIELD_IMPACT", "ELITE_COUNTER", "DEMOLITION"]:
			context["layer_original_sound"] = true
	var evicted: Dictionary = impact_presentation.add(kind, point, direction, delay, material, event, context)
	# Under pathological input rates keep memory bounded without silently losing
	# an already-emitted cue; its decoration may be dropped, not its feedback.
	if not evicted.is_empty() and not bool(evicted.contacted) and not str(evicted.event).is_empty() and feedback_bus != null:
		feedback_bus.present_event(str(evicted.event), evicted.context)
	# Observers see the fact now, in its original order. The cue alone is played
	# later by present_event(), without re-emitting a semantic event.
	if not event.is_empty():
		_emit_feedback(event, context)


func _wall_impact_material() -> String:
	match get_biome_index(floor_number):
		1: return "glass"
		2: return "metal"
		3: return "ice"
		4: return "energy"
	return "stone"


func _on_presentation_contact(contact: Dictionary) -> void:
	var event := str(contact.event)
	if bool(contact.get("canceled", false)):
		if feedback_bus != null and not event.is_empty():
			feedback_bus.present_event(event, contact.context)
		return
	var kind := str(contact.kind)
	if kind in ["shield", "hurt", "electric", "capture"] and bool(contact.context.get("affects_player", true)):
		player_impact_kind = kind
		player_impact_direction = Vector2(contact.direction)
		impact_feedback_time = 0.20
	# Camera accents are attached to the same visible contact as the cues,
	# rather than deleting the prior camera response or shaking on input.
	# Distant off-screen events cannot shake or flash the whole screen.
	var contact_position: Vector2 = contact.point
	var near_player := contact_position.distance_squared_to(_player_visual_position()) <= pow(CELL * 2.5, 2.0)
	var local_contact := bool(contact.context.get("affects_player", true)) or near_player or _visible_world_rect().has_point(contact_position)
	if local_contact and kind == "block":
		_trigger_shake(0.12, 4.0)
	elif local_contact and kind in ["push", "push_soft"]:
		_trigger_shake(0.09, 3.0 if kind == "push" else 1.8)
	elif local_contact and kind in ["hurt", "electric", "shield"]:
		_trigger_shake(0.12, 4.2 if kind == "hurt" else 3.4)
	elif local_contact and kind in ["elite", "defeat", "wall"]:
		_trigger_shake(0.18, 6.0 if kind == "wall" else 7.5)
		flash_color = Color("ffbb9b") if kind == "wall" else Color("ff7691")
		flash_time = 0.055
	if feedback_bus != null and not event.is_empty():
		feedback_bus.present_event(event, contact.context)


func _on_tactical_feedback(event: String, context: Dictionary) -> void:
	match event:
		"TURN_COMMITTED":
			turn_pulse_position = _cell_center(context.get("cell", player_position))
			# The board is already resolved; only the ring waits for the visual path.
			turn_pulse_pending = player_anim < 1.0
			turn_pulse_time = -0.001 if turn_pulse_pending else 0.0
		"NEAR_MISS":
			near_miss_feedback_time = 0.16
		"BLOCKED":
			blocked_feedback_direction = Vector2(facing)
			blocked_feedback_pending = player_motion.is_active() and _player_motion_fields_match()
			blocked_feedback_time = 0.0 if blocked_feedback_pending else 0.16
		"DEMOLITION":
			attack_feedback_delay = float(context.get("attack_delay", 0.0))
			attack_feedback_time = 0.26 if attack_feedback_delay <= 0.0 else 0.0
		"SHIELD_IMPACT", "ELITE_COUNTER", "HIT", "HEART_LOST":
			if not bool(context.get("defer_presentation", false)):
				impact_feedback_time = 0.20
				player_impact_kind = "shield" if event in ["SHIELD_IMPACT", "ELITE_COUNTER"] else "hurt"
				player_impact_direction = -Vector2(facing)


func _current_haptic_material() -> String:
	match get_biome_index(floor_number):
		1: return "garden"
		2: return "forge"
		3: return "ice"
		4: return "void"
	return "neon"


func _nearest_visible_threat() -> int:
	var closest := -1
	for enemy in enemies:
		var position: Vector2i = enemy.pos
		var distance := _manhattan(position, player_position)
		if distance <= 4 and _enemy_sees_player(position) and (closest < 0 or distance < closest):
			closest = distance
	return closest


func _on_controller_settings_changed() -> void:
	controller_vibration_enabled = controller.vibration_enabled
	controller_vibration_intensity = controller.vibration_intensity
	controller_mappings = controller.custom_mappings.duplicate(true)
	_save_profile()


func _on_controller_calibration_finished(saved: bool) -> void:
	game_state = "controller_settings"
	controller_message = "MAPEAMENTO GUARDADO" if saved else "MAPEAMENTO CANCELADO; ANTERIOR PRESERVADO"


func _on_controller_device_changed(device: int, connected: bool) -> void:
	var message := "COMANDO LIGADO: %s" % controller.device_name(device) if connected else "COMANDO DESLIGADO"
	controller_message = message
	last_notice = message
	notice_timer = 2.5


func _player_visual_position() -> Vector2:
	var motion_kind: String = player_motion.kind if _player_motion_fields_match() else "walk"
	return player_from.lerp(player_to, VisualMotion.eased_progress(player_anim, motion_kind))


func _cell_center(point: Vector2i) -> Vector2:
	return Vector2((point.x + 0.5) * CELL, (point.y + 0.5) * CELL)


func _spawn_burst(position: Vector2, color: Color, count: int, speed: float) -> void:
	# Knockback may collect an item logically before its visual landing. Its
	# bounded contact ring and cue will be drawn there later, not ahead of it.
	if pickup_feedback_delay >= 0.0:
		return
	for i in count:
		var angle := TAU * float(i) / count + visual_rng.randf_range(-0.22, 0.22)
		var velocity := Vector2(cos(angle), sin(angle)) * visual_rng.randf_range(speed * 0.25, speed)
		particles.append({"pos": position, "velocity": velocity, "life": visual_rng.randf_range(0.25, 0.7), "max_life": 0.7, "color": color, "size": visual_rng.randf_range(2.0, 5.0)})


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if game_state == "playing" and captor_flyover_time > 0.0:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_finish_captor_flyover()
		return
	if game_state == "controller_mapping":
		if event.keycode == KEY_ESCAPE:
			controller.cancel_calibration()
		elif event.keycode == KEY_S:
			controller.skip_calibration_step()
		return
	if game_state in ["campaign_select", "campaign_confirm", "skill_tree", "skill_confirm"]:
		match event.keycode:
			KEY_ESCAPE:
				if game_state == "skill_tree": handle_hud_action("skill_back")
				elif game_state == "skill_confirm": handle_hud_action("skill_remove_cancel")
				elif game_state == "campaign_confirm": handle_hud_action("campaign_cancel")
				else: handle_hud_action("menu")
			KEY_UP, KEY_W: hud.move_focus(Vector2i.UP)
			KEY_DOWN, KEY_S: hud.move_focus(Vector2i.DOWN)
			KEY_LEFT, KEY_A: hud.move_focus(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: hud.move_focus(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: hud.activate_focus()
		return
	if game_state == "controller_settings":
		match event.keycode:
			KEY_ESCAPE: handle_hud_action("controller_back")
			KEY_UP, KEY_W: hud.move_focus(Vector2i.UP)
			KEY_DOWN, KEY_S: hud.move_focus(Vector2i.DOWN)
			KEY_LEFT, KEY_A: hud.move_focus(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: hud.move_focus(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: hud.activate_focus()
		return
	if event.keycode == KEY_F1 and game_state == "playing":
		dev_toggle_menu()
		return
	if game_state == "captured":
		return
	if game_state == "title":
		match event.keycode:
			KEY_UP, KEY_W: hud.move_focus(Vector2i.UP)
			KEY_DOWN, KEY_S: hud.move_focus(Vector2i.DOWN)
			KEY_ENTER, KEY_KP_ENTER:
				if hud.focus_visible:
					hud.activate_focus()
				elif has_resume:
					continue_game()
				else:
					handle_hud_action("new_run")
			KEY_N: handle_hud_action("new_run")
			KEY_L: open_level_select()
			KEY_C: start_environment_lab()
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
		match event.keycode:
			KEY_ESCAPE: game_state = "playing"
			KEY_UP, KEY_W: hud.move_focus(Vector2i.UP)
			KEY_DOWN, KEY_S: hud.move_focus(Vector2i.DOWN)
			KEY_LEFT, KEY_A: hud.move_focus(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: hud.move_focus(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if hud.focus_visible: hud.activate_focus()
				else: game_state = "playing"
			KEY_L:
				if not lab_active: open_level_select()
			KEY_R: restart_floor()
			KEY_M: audio.toggle_music()
		return
	if game_state == "game_over":
		if event.keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER]:
			continue_game()
		elif event.keycode == KEY_L and not lab_active:
			open_level_select()
		elif event.keycode == KEY_ESCAPE:
			handle_hud_action("menu")
		return
	if game_state in ["floor_clear", "rescued"]:
		match event.keycode:
			KEY_UP, KEY_W: hud.move_focus(Vector2i.UP)
			KEY_DOWN, KEY_S: hud.move_focus(Vector2i.DOWN)
			KEY_LEFT, KEY_A: hud.move_focus(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: hud.move_focus(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if hud.focus_visible: hud.activate_focus()
				else: advance_floor()
			KEY_N:
				if game_state == "rescued": handle_hud_action("new_run")
			KEY_ESCAPE: handle_hud_action("menu")
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
		KEY_Q: try_blink()
		KEY_X: wait_turn()
		KEY_Z: undo_sokoban_move()
		KEY_R: restart_floor()
		KEY_N:
			if not lab_active:
				slot_message = "VOLTA AO MENU PARA GERIR CAMPANHAS."
				last_notice = slot_message
				notice_timer = 2.0
		KEY_L:
			if not lab_active: open_level_select()
		KEY_M: audio.toggle_music()


# Convert the actual viewport through the CanvasItem transform. This accounts
# for viewport stretching, zoom, camera rotation and shake, unlike subtracting
# half the viewport from the camera position. A little padding protects AA.
func _visible_world_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2(Vector2.ZERO, Vector2(world_size) * CELL)
	var viewport := get_viewport_rect()
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var corners := [
		inverse * viewport.position,
		inverse * Vector2(viewport.end.x, viewport.position.y),
		inverse * viewport.end,
		inverse * Vector2(viewport.position.x, viewport.end.y),
	]
	var low: Vector2 = corners[0]
	var high: Vector2 = corners[0]
	for corner in corners:
		low = low.min(corner)
		high = high.max(corner)
	return Rect2(low, high - low).grow(8.0)


func _world_is_visible() -> bool:
	return game_state not in ["title", "level_select", "controller_settings", "controller_mapping", "campaign_select", "campaign_confirm", "skill_tree", "skill_confirm"]


func _update_background_visibility(view: Rect2, draw_world: bool) -> void:
	if background_rect == null:
		return
	# Every cell has an opaque floor or wall base. When the padded viewport is
	# wholly inside the board, the procedural full-screen background is hidden
	# behind those cells; show it again at world edges and on small maps.
	var board := Rect2(Vector2.ZERO, Vector2(world_size) * CELL)
	var needed := draw_world and (world_size == Vector2i.ZERO or not board.encloses(view))
	if background_rect.visible != needed:
		background_rect.visible = needed


func _enemy_draw_visible(enemy: Dictionary, view: Rect2) -> bool:
	# Include larger boss silhouettes, pose motion and ice rings in the margin.
	# No enemy draws a targeting line to a player outside this region.
	return view.grow(160.0).has_point(_enemy_visual_position(enemy))


func _draw_heart_pickup(cell: Vector2i) -> void:
	var center := _cell_center(cell) + Vector2(0, sin(animation_clock * 3.0) * 2.0)
	draw_circle(center, 22.0, Color("ff6e97", 0.12))
	draw_circle(center + Vector2(-6, -3), 7.0, Color("ff6e97"))
	draw_circle(center + Vector2(6, -3), 7.0, Color("ff6e97"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 0), center + Vector2(13, 0), center + Vector2(0, 15)]), Color("ff6e97"))
	draw_circle(center + Vector2(-6, -5), 2.5, Color("ffe1ea"))


func _draw() -> void:
	if world_size == Vector2i.ZERO or not _world_is_visible():
		return
	var view := _visible_world_rect()
	var item_view := view.grow(48.0)
	# Static ground, shadows and walls are retained by terrain_renderer. The
	# remaining dynamic actors are culled conservatively, never removed from
	# the game state, so objectives and collision still use the full level.
	for gate in environment.gates:
		if item_view.has_point(_cell_center(gate.pos)):
			_draw_environment_gate(gate)
	for index in environment.crates.size():
		var crate: Dictionary = environment.crates[index]
		if item_view.has_point(_crate_visual_position(index, crate)):
			_draw_environment_crate(crate, index)
	for pos in coins:
		if item_view.has_point(_cell_center(pos)):
			_draw_coin(pos)
	for pos in shields:
		if item_view.has_point(_cell_center(pos)):
			_draw_shield(pos)
	for pos in heart_pickups:
		if item_view.has_point(_cell_center(pos)):
			_draw_heart_pickup(pos)
	for pos in breakers:
		if item_view.has_point(_cell_center(pos)):
			_draw_breaker(pos)
	for item in powerups:
		if item_view.has_point(_cell_center(item.pos)):
			_draw_powerup(item)
	if view.grow(64.0).has_point(_cell_center(portal_position)):
		_draw_portal()
	for enemy in enemies:
		if not _enemy_draw_visible(enemy, view):
			continue
		_draw_enemy(enemy)
		# Enemy bodies have their own procedural transform; never leak it into
		# another actor, the ice state, or the rest of the board.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if freeze_turns > 0:
			var ice_center := _enemy_contact_draw_position(enemy)
			var ice_radius := 36.0 if _is_elite(enemy) else 23.0
			draw_arc(ice_center, ice_radius, animation_clock, animation_clock + TAU * 0.8, 28, Color("b4d8ff", 0.85), 1.7, true)
			draw_circle(ice_center + Vector2(ice_radius * 0.75, -ice_radius * 0.65), 2.5, Color("d6faff"))
	for ghost in enemy_defeat_visuals:
		if view.grow(120.0).has_point(ghost.to):
			_draw_enemy_defeat(ghost)
	_draw_player()
	_draw_particles()
	impact_presentation.draw(self, view)
	if floor_number == 5 and captor_flyover_time > 0.0:
		_draw_captor_flyover(view)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_captor_flyover(view: Rect2) -> void:
	var progress := clampf(1.0 - captor_flyover_time / CAPTOR_FLYOVER_SECONDS, 0.0, 1.0)
	var eased_progress := 1.0 - pow(1.0 - progress, 2.0)
	var body_size := clampf(view.size.x * 0.25, 210.0, 330.0)
	var drift_x := lerpf(view.position.x - body_size * 0.8, view.end.x + body_size * 0.8, eased_progress)
	var body_center := Vector2(drift_x, view.position.y + view.size.y * 0.31 + sin(animation_clock * 2.0) * 9.0)
	var body_rect := Rect2(body_center - Vector2.ONE * body_size * 0.5, Vector2.ONE * body_size)
	var glow_pulse := 0.11 + sin(animation_clock * 4.0) * 0.025
	draw_circle(body_center + Vector2(0.0, body_size * 0.35), body_size * 0.32, Color("a444ff", 0.11))
	draw_circle(body_center, body_size * 0.27, Color("ef69ff", glow_pulse))
	draw_texture_rect(DIVINE_CAPTOR_TEXTURE, body_rect, false)
	var cage_size := Vector2(body_size * 0.32, body_size * 0.46)
	var cage_center := body_center + Vector2(body_size * 0.35, body_size * 0.52 + sin(animation_clock * 3.2) * 7.0)
	var cage_top := cage_center + Vector2(0.0, -cage_size.y * 0.45)
	var tether := body_center + Vector2(body_size * 0.32, body_size * 0.14)
	draw_line(tether, cage_top, Color("f054ff", 0.48), 8.0, true)
	draw_line(tether, cage_top, Color("ffe8ff", 0.9), 2.0, true)
	var cage_rotation := sin(animation_clock * 2.7) * 0.075
	draw_set_transform(cage_center, cage_rotation, Vector2.ONE)
	var lia_bob := sin(animation_clock * 3.2 + 0.7) * 1.2
	var lia_center := Vector2.ZERO
	var lia_sphere_center := lia_center + Vector2(0.0, lia_bob)
	draw_circle(lia_sphere_center + Vector2(0.0, 10.0), 11.0, Color("080616", 0.48))
	draw_circle(lia_sphere_center, 22.0, Color("e75ce4", 0.14 + sin(animation_clock * 4.0) * 0.035))
	if lia_sphere_texture != null:
		draw_texture_rect(lia_sphere_texture, Rect2(lia_sphere_center - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), false)
	else:
		draw_circle(lia_sphere_center, 15.5, Color("e75ce4"))
	_draw_orb_face(lia_center, 1.0, Vector2i.LEFT, true, 1.0, 0.0, lia_bob, false, true)
	draw_texture_rect(CAPTIVE_CAGE_TEXTURE, Rect2(-cage_size * 0.5, cage_size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



func _is_wall(pos: Vector2i) -> bool:
	if not _inside(pos):
		return true
	var t: int = grid[pos.y][pos.x]
	return t == TILE_WALL or t == TILE_BORDER


func _is_floor(pos: Vector2i) -> bool:
	if not _inside(pos):
		return false
	var t: int = grid[pos.y][pos.x]
	return (t == TILE_FLOOR or t == TILE_WATER) and ((environment.crates.is_empty() and environment.gates.is_empty()) or not environment.is_blocked(pos))


func _has_wall_front(pos: Vector2i) -> bool:
	if not _is_wall(pos):
		return false
	return _is_floor(pos + Vector2i.DOWN)


func _get_biome_palette(idx: int) -> Dictionary:
	match idx:
		1: # Jardim de Vidro (Bio-Lab)
			return {
				"biome_type": "biolab",
				"floor_base": Color("0b1c20"),
				"floor_alt": Color("0f242a"),
				"floor_seam": Color("050f12"),
				"floor_rivet": Color("47a898", 0.4),
				"wall_roof": Color("1a3238"),
				"wall_face": Color("122428"),
				"wall_bevel": Color("457580"),
				"neon_accent": Color("4effaa"),
				"neon_glow": Color("4effaa", 0.45),
				"has_vines": true,
				"vine_color": Color("2e8a62")
			}
		2: # Fornalha Violeta (Industrial Factory)
			return {
				"biome_type": "factory",
				"floor_base": Color("1a1420"),
				"floor_alt": Color("22182b"),
				"floor_seam": Color("0e0914"),
				"floor_rivet": Color("a85565", 0.4),
				"wall_roof": Color("382337"),
				"wall_face": Color("261726"),
				"wall_bevel": Color("80506e"),
				"neon_accent": Color("ff7e3a"),
				"neon_glow": Color("ff7e3a", 0.45),
				"has_vines": false,
				"vine_color": Color.TRANSPARENT
			}
		3: # Catedral de Gelo (Ruínas Glaciais Antigas)
			return {
				"biome_type": "glacier",
				"floor_base": Color("0e1828"),
				"floor_alt": Color("121f33"),
				"floor_seam": Color("060b14"),
				"floor_rivet": Color("589ec9", 0.4),
				"wall_roof": Color("20334d"),
				"wall_face": Color("152336"),
				"wall_bevel": Color("4d77a8"),
				"neon_accent": Color("6de9ff"),
				"neon_glow": Color("6de9ff", 0.45),
				"has_vines": false,
				"vine_color": Color.TRANSPARENT
			}
		4: # Trono do Guardião (Santuário Místico Arcano)
			return {
				"biome_type": "mystic",
				"floor_base": Color("171126"),
				"floor_alt": Color("1f1633"),
				"floor_seam": Color("0a0614"),
				"floor_rivet": Color("9f78d4", 0.4),
				"wall_roof": Color("36224d"),
				"wall_face": Color("241436"),
				"wall_bevel": Color("7c52a8"),
				"neon_accent": Color("d56bff"),
				"neon_glow": Color("d56bff", 0.45),
				"has_vines": true,
				"vine_color": Color("6a358c")
			}
		_: # 0: Neon Ruins (Urbano) — Roxo/Violeta dominante como nas imagens de referência
			return {
				"biome_type": "neon",
				"floor_base": Color("120c22"),
				"floor_alt": Color("170f30"),
				"floor_seam": Color("0a0615"),
				"floor_rivet": Color("7050b0", 0.5),
				"wall_roof": Color("1c133a"),
				"wall_face": Color("100c24"),
				"wall_bevel": Color("6040a0"),
				"neon_accent": Color("c060ff"),
				"neon_glow": Color("b050ff", 0.5),
				"has_vines": true,
				"vine_color": Color("2a5e42")
			}


func _draw_floor_tile(target: CanvasItem, point: Vector2i, top_left: Vector2, pal: Dictionary) -> void:
	var base_col: Color = pal.floor_base if (point.x + point.y) % 2 == 0 else pal.floor_alt
	var btype: String = pal.get("biome_type", "neon")
	
	# Preenchimento base da placa (quadrado cheio)
	target.draw_rect(Rect2(top_left, Vector2(CELL, CELL)), base_col, true)
	
	# Borda 3D raised: borda superior/esquerda mais clara (luz), inferior/direita escura (sombra)
	var bevel_light := Color(pal.wall_bevel, 0.30)
	var bevel_shadow := Color(0, 0, 0, 0.65)
	target.draw_line(top_left + Vector2(1, 1), top_left + Vector2(CELL - 1, 1), bevel_light, 1.5, true)
	target.draw_line(top_left + Vector2(1, 1), top_left + Vector2(1, CELL - 1), bevel_light, 1.0, true)
	target.draw_line(top_left + Vector2(1, CELL - 1), top_left + Vector2(CELL - 1, CELL - 1), bevel_shadow, 2.0, true)
	target.draw_line(top_left + Vector2(CELL - 1, 1), top_left + Vector2(CELL - 1, CELL - 1), bevel_shadow, 1.5, true)
	
	# Linha néon característica na borda inferior da placa
	target.draw_line(top_left + Vector2(3, CELL - 1), top_left + Vector2(CELL - 3, CELL - 1), Color(pal.neon_accent, 0.40), 1.2, true)
	
	# Parafusos/rebites nos cantos das placas
	var rivet: Color = pal.floor_rivet
	target.draw_circle(top_left + Vector2(4, 4), 1.4, rivet)
	target.draw_circle(top_left + Vector2(CELL - 4, 4), 1.4, rivet)
	target.draw_circle(top_left + Vector2(4, CELL - 4), 1.4, rivet)
	target.draw_circle(top_left + Vector2(CELL - 4, CELL - 4), 1.4, rivet)
	
	var tile_hash := (point.x * 37 + point.y * 79) % 18
	
	# ── ESTRUTURA E ARQUITETURA DIFERENCIADA POR BIOMA ─────────────────────────
	if btype == "biolab":
		# BIO-LAB: Painéis com nós de dados e circuitos biológicos verde-esmeralda
		if tile_hash in [1, 5]:
			# Circuito em cruz / barramento hexagonal no centro da laje
			target.draw_circle(top_left + Vector2(CELL * 0.5, CELL * 0.5), 3.2, Color(pal.neon_accent, 0.65))
			target.draw_circle(top_left + Vector2(CELL * 0.5, CELL * 0.5), 1.5, Color("ffffff", 0.9))
			target.draw_line(top_left + Vector2(CELL * 0.5, 4), top_left + Vector2(CELL * 0.5, CELL - 4), Color(pal.neon_accent, 0.25), 1.0, true)
			target.draw_line(top_left + Vector2(4, CELL * 0.5), top_left + Vector2(CELL - 4, CELL * 0.5), Color(pal.neon_accent, 0.25), 1.0, true)
		elif tile_hash == 2:
			# Pequeno broto de flora bio-mecânica no canto
			target.draw_circle(top_left + Vector2(6, 6), 2.2, Color("34d399", 0.7))
			target.draw_circle(top_left + Vector2(9, 5), 1.6, Color("6ee7b7", 0.6))
			
	elif btype == "factory":
		# INDUSTRIAL: Placas estriadas de aço (diamond plate) e faixas de perigo (hazard stripes)
		if tile_hash in [1, 4]:
			# Faixas diagonais amarelas e pretas de advertência industrial (hazard stripes)
			for s in 3:
				var ox := float(s) * 7.0
				target.draw_line(top_left + Vector2(6 + ox, 6), top_left + Vector2(13 + ox, 13), Color("ffd000", 0.75), 2.2, true)
				target.draw_line(top_left + Vector2(3 + ox, 6), top_left + Vector2(10 + ox, 13), Color("120904", 0.85), 2.0, true)
		elif tile_hash in [2, 6]:
			# Grelha de drenagem de metal perfurado / saída de vapor
			target.draw_rect(Rect2(top_left + Vector2(8, 8), Vector2(CELL - 16, CELL - 16)), Color("0a0710", 0.9), true)
			for i in 3:
				var vy := top_left.y + 11.0 + float(i) * 5.5
				target.draw_line(Vector2(top_left.x + 10, vy), Vector2(top_left.x + CELL - 10, vy), Color("ff8b3d", 0.5), 1.4, true)
				
	elif btype == "glacier":
		# CATEDRAL DE GELO: Cantaria de pedra antiga com fendas glaciais azul-celeste
		if tile_hash in [1, 3]:
			# Veio de gelo cristalino trincando a rocha
			var crack := PackedVector2Array([
				top_left + Vector2(4, CELL * 0.3),
				top_left + Vector2(CELL * 0.45, CELL * 0.48),
				top_left + Vector2(CELL * 0.55, CELL * 0.68),
				top_left + Vector2(CELL - 4, CELL * 0.82)
			])
			target.draw_polyline(crack, Color("6de9ff", 0.65), 1.6, true)
			target.draw_polyline(crack, Color("ffffff", 0.85), 0.8, true)
		elif tile_hash in [2, 7]:
			# Cantaria de blocos antigos lapidados (linha de argamassa de pedra)
			target.draw_line(top_left + Vector2(4, CELL * 0.5), top_left + Vector2(CELL - 4, CELL * 0.5), Color(0, 0, 0, 0.4), 1.2, true)
			target.draw_line(top_left + Vector2(CELL * 0.5, 4), top_left + Vector2(CELL * 0.5, CELL * 0.5), Color(0, 0, 0, 0.35), 1.0, true)
			
	elif btype == "mystic":
		# MÍSTICO: Mármore negro com runas circulares e linhas de canalização arcanas
		if tile_hash in [1, 4]:
			# Glifo rúnico circular entalhado no piso
			var center_pt := top_left + Vector2(CELL * 0.5, CELL * 0.5)
			target.draw_arc(center_pt, 7.0, 0.0, TAU, 18, Color(pal.neon_accent, 0.55), 1.2, true)
			target.draw_circle(center_pt, 2.2, Color("ffffff", 0.8))
			target.draw_circle(center_pt, 1.2, Color(pal.neon_accent))
		elif tile_hash in [2, 5]:
			# Linhas de canalização mágica diagonais
			target.draw_line(top_left + Vector2(4, 4), top_left + Vector2(CELL * 0.5, CELL * 0.5), Color(pal.neon_accent, 0.3), 1.2, true)
			target.draw_line(top_left + Vector2(CELL - 4, CELL - 4), top_left + Vector2(CELL * 0.5, CELL * 0.5), Color(pal.neon_accent, 0.3), 1.2, true)
			
	else:
		# NEON RUINS (Urbano Cyberpunk padrão)
		if tile_hash == 1:
			var vent_rect := Rect2(top_left + Vector2(10, 11), Vector2(CELL - 20, CELL - 22))
			target.draw_rect(vent_rect, Color("040610", 0.95), true)
			target.draw_rect(vent_rect, Color(pal.neon_accent, 0.06), true)
			for i in 4:
				var vy := top_left.y + 15.0 + float(i) * 7.0
				target.draw_line(Vector2(top_left.x + 12, vy), Vector2(top_left.x + CELL - 12, vy), Color(pal.wall_bevel, 0.55), 1.5, true)
		elif tile_hash == 2:
			target.draw_rect(Rect2(top_left + Vector2(10, 10), Vector2(CELL - 20, CELL - 20)), Color(pal.wall_bevel, 0.08), true)
			target.draw_rect(Rect2(top_left + Vector2(10, 10), Vector2(CELL - 20, CELL - 20)), Color(pal.wall_bevel, 0.25), false, 1.0)
		elif tile_hash == 3:
			target.draw_line(top_left + Vector2(7, CELL - 10), top_left + Vector2(CELL - 10, 7), Color(pal.wall_bevel, 0.14), 1.0, true)


func _draw_nav_chevron(target: CanvasItem, point: Vector2i, dir: Vector2, pal: Dictionary) -> void:
	var center := _cell_center(point)
	var angle := dir.angle()
	var pulse := 0.85 + sin(animation_clock * 4.5 + float(point.x + point.y)) * 0.15
	var chevron_col: Color = pal.neon_accent
	
	target.draw_set_transform(center, angle, Vector2.ONE)
	for ci in 2:
		var ox := (float(ci) - 0.5) * 9.0
		var p := PackedVector2Array([
			Vector2(ox - 5.0, -7.0),
			Vector2(ox + 3.0, 0.0),
			Vector2(ox - 5.0, 7.0)
		])
		# Halo emissivo de fundo
		target.draw_polyline(p, Color(chevron_col, 0.25 * pulse), 4.5, true)
		# Linha néon principal intensa
		target.draw_polyline(p, Color(chevron_col, 0.95 * pulse), 1.8, true)
		# Centro branco puro de incandescência
		target.draw_polyline(p, Color("ffffff", 0.75 * pulse), 0.8, true)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_radial_light(target: CanvasItem, pos: Vector2, radius: float, core_color: Color, glow_color: Color, pulse: float = 1.0) -> void:
	if radial_light_texture == null:
		return
	var r := radius * pulse
	# Halo difuso exterior (dispersão ambiental suave)
	var outer_rect := Rect2(pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	target.draw_texture_rect(radial_light_texture, outer_rect, false, glow_color)
	# Manto de iluminação intermediário saturado
	var mr := r * 0.62
	var mid_rect := Rect2(pos - Vector2(mr, mr), Vector2(mr * 2.0, mr * 2.0))
	target.draw_texture_rect(radial_light_texture, mid_rect, false, Color(glow_color.r, glow_color.g, glow_color.b, minf(1.0, glow_color.a * 1.5)))
	# Núcleo quente incandescente
	var cr := r * 0.32
	var core_rect := Rect2(pos - Vector2(cr, cr), Vector2(cr * 2.0, cr * 2.0))
	target.draw_texture_rect(radial_light_texture, core_rect, false, core_color)


func _draw_floor_shadows(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	# Sombra profunda que cai das paredes ao norte sobre o chão
	if _is_wall(point + Vector2i.UP):
		target.draw_rect(Rect2(top_left, Vector2(CELL, 16.0)), Color(0, 0, 0, 0.55), true)
		target.draw_rect(Rect2(top_left, Vector2(CELL, 8.0)), Color(0, 0, 0, 0.28), true)
		# Retained translucent bands soften the contact shadow without a
		# screen-wide pass or invalidating static chunks each frame.
		target.draw_rect(Rect2(top_left + Vector2(0, 16), Vector2(CELL, 6)), Color(0, 0, 0, 0.12), true)
		target.draw_rect(Rect2(top_left + Vector2(0, 22), Vector2(CELL, 5)), Color(0, 0, 0, 0.05), true)
	# Sombra lateral projetada das paredes a oeste
	if _is_wall(point + Vector2i.LEFT):
		target.draw_rect(Rect2(top_left, Vector2(8.0, CELL)), Color(0, 0, 0, 0.38), true)
		target.draw_rect(Rect2(top_left, Vector2(4.0, CELL)), Color(0, 0, 0, 0.20), true)
		target.draw_rect(Rect2(top_left + Vector2(8, 0), Vector2(5, CELL)), Color(0, 0, 0, 0.07), true)


func _enemy_visual_position(enemy: Dictionary) -> Vector2:
	var t: float = clampf(float(enemy.get("t", 1.0)), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var track = enemy.get("_visual_motion")
	var position: Vector2 = track.position() if track != null else enemy.from.lerp(enemy.to, eased)
	if int(enemy.get("shield_repel_turn", -1)) == turn_number and enemy.get("shield_repel_visual", false):
		# A short kick arc is presentation only; the board cell was resolved
		# immediately and no additional turn or collision is generated here.
		position.y -= sin(t * PI) * 8.0
	return position


# Shield collisions resolve on the board immediately, so both logical actors
# can briefly share the contact cell. Prevent the ball from visually hiding a
# repelled creature during that hold, without moving any rule-space position.
func _enemy_contact_draw_position(enemy: Dictionary) -> Vector2:
	var center := _enemy_visual_position(enemy)
	if int(enemy.get("_visual_contact_turn", -1)) != turn_number:
		return center
	var axis: Vector2 = enemy.get("_visual_contact_axis", Vector2.ZERO)
	if axis.length_squared() < 0.01:
		return center
	axis = axis.normalized()
	var relative := center - _player_visual_position()
	var along := relative.dot(axis)
	var side := Vector2(-axis.y, axis.x)
	var lateral := absf(relative.dot(side))
	# Fade away as recoil carries the actor aside, including when the primary
	# retreat is blocked and a legal lateral cell was chosen instead.
	var role := str(enemy.get("role", "hunter"))
	var contact_gap := 40.0 if role == "chess_boss" else 35.0 if role == "warden" else 31.0
	var separation := clampf(contact_gap - along, 0.0, contact_gap) * (1.0 - smoothstep(contact_gap - 7.0, contact_gap + 14.0, lateral))
	return center + axis * separation


func _draw_floor_neon_glow(target: CanvasItem, view: Rect2) -> void:
	var pulse := 1.0 + sin(animation_clock * 3.8) * 0.07
	var light_view := view.grow(116.0)
	var coin_view := view.grow(36.0)
	
	# Held plates provide local grounding light beneath actors, never a
	# screen-wide flash and never a gameplay input.
	for plate in environment.plates:
		var center := _cell_center(plate.pos)
		if plate.get("active", false) and light_view.has_point(center):
			_draw_radial_light(target, center, 35.0, Color("adffe3", 0.35), Color("39cda3", 0.18), 1.0)
	# Halo néon suave da bola vermelha do jogador no chão (sem anel ruidoso)
	var p_pos := _player_visual_position()
	_draw_radial_light(target, p_pos, 52.0, Color("ff6080", 0.90), Color("ff1038", 0.42), pulse)
	
	# Halo dos escudos cibernéticos (ciano radiante)
	for s in shields:
		var sc := _cell_center(s)
		if not light_view.has_point(sc): continue
		_draw_radial_light(target, sc + Vector2(0, 4), 48.0, Color("b0f8ff", 0.95), Color("00bfe6", 0.50), pulse)
		
	# Halo dos baús breaker (âmbar / dourado quente)
	for b in breakers:
		var bc := _cell_center(b)
		if not light_view.has_point(bc): continue
		_draw_radial_light(target, bc + Vector2(0, 4), 52.0, Color("fff1a8", 0.95), Color("ff9900", 0.50), pulse)
		
	# Four power-up colors also match their in-world icon and HUD effects.
	for item in powerups:
		if not light_view.has_point(_cell_center(item.pos)): continue
		var color := Color(POWERUP_COLORS.get(item.kind, "ffffff"))
		_draw_radial_light(target, _cell_center(item.pos) + Vector2(0, 4), 43.0, Color(color, 0.9), Color(color, 0.4), pulse)
	# Halo das moedas (dourado compacto)
	for c in coins:
		var cc := _cell_center(c)
		if not coin_view.has_point(cc): continue
		_draw_radial_light(target, cc + Vector2(0, 4), 28.0, Color("fff6bd", 0.85), Color("e69900", 0.40), 1.0)
		
	# Halo dos interruptores (azul/ciano inativo, verde esmeralda ativado)
	for sw in switches:
		var sc := _cell_center(sw.pos)
		if not light_view.has_point(sc): continue
		var sw_on: bool = sw.get("active", false)
		var sw_core := Color("a0ffcf", 0.92) if sw_on else Color("6de9ff", 0.82)
		var sw_glow := Color("15b565", 0.48) if sw_on else Color("1468b8", 0.38)
		if sw.has("order"):
			var rune_color := Color(PUZZLE_COLORS[clampi(int(sw.order), 0, 2)])
			sw_core = Color(rune_color, 0.95 if sw_on else 0.7)
			sw_glow = Color(rune_color, 0.45 if sw_on else 0.27)
		_draw_radial_light(target, sc + Vector2(0, 2), 38.0, sw_core, sw_glow, pulse)
		
	# Halo dos inimigos no chão (luz volumétrica viva e colorida por tipo de mob)
	for enemy in enemies:
		var ec := _enemy_visual_position(enemy)
		if not light_view.has_point(ec): continue
		var role: String = enemy.get("role", "hunter")
		var alert: bool = enemy.get("alert", false)
		var e_radius := 44.0
		var e_core := Color("ff4865", 0.90)
		var e_glow := Color("b50824", 0.45)
		match role:
			"hunter":
				e_radius = 42.0
				e_core = Color("ff4865", 0.90) if alert else Color("e62a4a", 0.75)
				e_glow = Color("b50824", 0.45)
			"sentry":
				e_radius = 45.0
				e_core = Color("ffd043", 0.92) if alert else Color("e6a520", 0.75)
				e_glow = Color("a65c00", 0.42)
			"wisp":
				e_radius = 48.0
				e_core = Color("da8aff", 0.92)
				e_glow = Color("8520cb", 0.46)
			"rusher":
				e_radius = 46.0
				e_core = Color("ff8b3d", 0.95) if alert else Color("e66a1a", 0.80)
				e_glow = Color("b33500", 0.46)
			"patrol":
				e_radius = 42.0
				e_core = Color("72f7ac", 0.9)
				e_glow = Color("1da866", 0.43)
			"mirror":
				e_radius = 43.0
				e_core = Color("bce8ff", 0.9)
				e_glow = Color("3189d5", 0.44)
			"warden":
				e_radius = 62.0
				e_core = Color("c95eff", 0.95)
				e_glow = Color("680ca8", 0.52)
			"chess_boss":
				var piece_color := Color(BOSS_COLORS.get(enemy.get("boss_kind", "pawn"), "c95eff"))
				e_radius = 72.0
				e_core = Color(piece_color, 0.95)
				e_glow = Color(piece_color, 0.48)
		_draw_radial_light(target, ec + Vector2(0, 4), e_radius, e_core, e_glow, pulse)
		
	# Halo do portal dimensional (vórtice violeta/ciano expansivo)
	var pc := _cell_center(portal_position)
	if light_view.has_point(pc):
		var portal_pulse := 1.0 + sin(animation_clock * 2.5) * 0.12
		var portal_core := Color("f1b8ff", 0.95) if portal_open else Color("ffa6b8", 0.85)
		var portal_glow := Color("a028ff", 0.55) if portal_open else Color("d61848", 0.45)
		_draw_radial_light(target, pc, 96.0, portal_core, portal_glow, portal_pulse)


func _draw_wall_tile(target: CanvasItem, point: Vector2i, top_left: Vector2, pal: Dictionary, border: bool) -> void:
	var has_front: bool = _has_wall_front(point) and not border
	
	if has_front:
		# PAREDE 2.5D com Topo + Frente Vertical Neon (como no mockup das referências)
		var front_h := 20.0
		var roof_h := CELL - front_h
		
		# TOPO DA PAREDE (Roof — superfície plana superior, levemente texturizada)
		var roof_rect := Rect2(top_left, Vector2(CELL, roof_h))
		target.draw_rect(roof_rect, pal.wall_roof, true)
		# Painel interno texturizado (inner surface com recuo)
		target.draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL - 4, roof_h - 3)), pal.wall_roof.lightened(0.05), true)
		# Linha de topo iluminada (aresta superior da parede)
		target.draw_line(top_left + Vector2(0, 0), top_left + Vector2(CELL, 0), Color(pal.wall_bevel, 0.5), 1.5, true)
		# Cornija — borda inferior do topo
		target.draw_line(top_left + Vector2(0, roof_h), top_left + Vector2(CELL, roof_h), Color(0, 0, 0, 0.9), 2.0, true)
		
		# FRENTE DA PAREDE (Face vertical iluminada)
		var face_top := top_left.y + roof_h
		var face_rect := Rect2(Vector2(top_left.x, face_top), Vector2(CELL, front_h))
		target.draw_rect(face_rect, pal.wall_face, true)
		# Linha central de divisória
		target.draw_line(Vector2(top_left.x + CELL * 0.5, face_top), Vector2(top_left.x + CELL * 0.5, face_top + front_h), Color(0, 0, 0, 0.55), 1.0, true)
		
		# BORDA SUPERIOR ILUMINADA DA FACE FRONTAL (cornija neon)
		target.draw_rect(Rect2(Vector2(top_left.x, face_top), Vector2(CELL, 2.0)), Color(pal.wall_bevel, 0.6), true)
		
		# CONDUTA NÉON HORIZONTAL CONTÍNUA (na metade da frente)
		var tube_y := face_top + float(front_h) * 0.55
		var left_conn := _has_wall_front(point + Vector2i.LEFT)
		var right_conn := _has_wall_front(point + Vector2i.RIGHT)
		var x_start := top_left.x if left_conn else top_left.x + 6.0
		var x_end := top_left.x + CELL if right_conn else top_left.x + CELL - 6.0
		
		# Glow néon amplo externo
		target.draw_line(Vector2(x_start, tube_y), Vector2(x_end, tube_y), Color(pal.neon_accent, 0.30), 6.0, true)
		# Tubo néon emissivo colorido
		target.draw_line(Vector2(x_start, tube_y), Vector2(x_end, tube_y), pal.neon_accent, 2.2, true)
		# Núcleo branco brilhante
		target.draw_line(Vector2(x_start + 2, tube_y), Vector2(x_end - 2, tube_y), Color("ffffff", 0.95), 0.8, true)
		
		# Terminações/Suportes nos extremos do tubo (se não continua)
		if not left_conn:
			target.draw_rect(Rect2(top_left.x + 3.0, tube_y - 4.0, 5.0, 8.0), Color(pal.wall_bevel, 0.8), true)
			target.draw_rect(Rect2(top_left.x + 3.0, tube_y - 4.0, 5.0, 8.0), Color(0, 0, 0, 0.4), false, 1.0)
		if not right_conn:
			target.draw_rect(Rect2(top_left.x + CELL - 8.0, tube_y - 4.0, 5.0, 8.0), Color(pal.wall_bevel, 0.8), true)
			target.draw_rect(Rect2(top_left.x + CELL - 8.0, tube_y - 4.0, 5.0, 8.0), Color(0, 0, 0, 0.4), false, 1.0)
		
		# Rodapé escuro de contacto com o chão
		target.draw_rect(Rect2(Vector2(top_left.x, top_left.y + CELL - 2.0), Vector2(CELL, 2.0)), Color("02030a", 0.9), true)
		
		# Trepadeiras/Vegetação cibernética pendente (nas paredes com bioma verde)
		if pal.has_vines and ((point.x * 29 + point.y * 61) % 5 == 0):
			_draw_wall_vines(target, Vector2(top_left.x, face_top), pal.vine_color, pal.neon_accent)
	else:
		# PAREDE SÓLIDA (não tem face frontal — parede interna ou borda)
		var roof_col: Color = pal.wall_roof.darkened(0.05) if not border else pal.wall_roof.darkened(0.30)
		var bevel_col: Color = pal.wall_bevel if not border else pal.wall_bevel.darkened(0.5)
		target.draw_rect(Rect2(top_left, Vector2(CELL, CELL)), roof_col, true)
		# Interior mais claro (raised effect)
		target.draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), roof_col.lightened(0.06), true)
		# Bordas 3D raised: topo e esquerda iluminados
		target.draw_line(top_left + Vector2(1, 1), top_left + Vector2(CELL - 1, 1), Color(bevel_col, 0.45), 1.5, true)
		target.draw_line(top_left + Vector2(1, 1), top_left + Vector2(1, CELL - 1), Color(bevel_col, 0.25), 1.0, true)
		# Fundo e direita em sombra
		target.draw_line(top_left + Vector2(0, CELL - 1), top_left + Vector2(CELL, CELL - 1), Color(0, 0, 0, 0.65), 1.5, true)
		target.draw_line(top_left + Vector2(CELL - 1, 0), top_left + Vector2(CELL - 1, CELL), Color(0, 0, 0, 0.4), 1.0, true)
		# Decoração interna (variar por tipo)
		var wall_var := (point.x * 23 + point.y * 41) % 5
		if wall_var == 0 and not border:
			# Faixas horizontais de painel
			target.draw_line(top_left + Vector2(4, CELL * 0.5), top_left + Vector2(CELL - 4, CELL * 0.5), Color(bevel_col, 0.20), 1.0, true)
		elif wall_var == 1 and not border:
			# Grelha de ventilação
			for gi in 3:
				target.draw_line(top_left + Vector2(9, 13 + gi * 9), top_left + Vector2(CELL - 9, 13 + gi * 9), Color(bevel_col, 0.30), 1.2, true)


func _draw_wall_vines(target: CanvasItem, pos: Vector2, vine_col: Color, bio_glow: Color) -> void:
	# Pequenas folhas e gavinhas que descem da borda da parede
	var offsets := [Vector2(12, 0), Vector2(16, 6), Vector2(14, 13)]
	for i in range(offsets.size() - 1):
		target.draw_line(pos + offsets[i], pos + offsets[i+1], vine_col, 1.6, true)
	target.draw_circle(pos + Vector2(13, 8), 2.2, vine_col)
	target.draw_circle(pos + Vector2(17, 12), 1.8, vine_col)
	target.draw_circle(pos + Vector2(14, 14), 1.2, bio_glow)
	
	var offsets2 := [Vector2(CELL - 16, 0), Vector2(CELL - 13, 5), Vector2(CELL - 15, 10)]
	for i in range(offsets2.size() - 1):
		target.draw_line(pos + offsets2[i], pos + offsets2[i+1], vine_col, 1.4, true)
	target.draw_circle(pos + Vector2(CELL - 14, 6), 2.0, vine_col)
	target.draw_circle(pos + Vector2(CELL - 15, 11), 1.2, bio_glow)


func _draw_water_base(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	var is_garden := get_biome_index(floor_number) == 1
	var deep := Color("082029") if is_garden else Color("0d2538")
	var water := Color("134c56") if is_garden else Color("21536b")
	# Fill adjoining cells edge-to-edge. Contact shading belongs only to the
	# outer shoreline, so retained chunks do not draw a dark grid across a lake.
	target.draw_rect(Rect2(top_left, Vector2(CELL, CELL)), water, true)
	var above := point + Vector2i.UP
	var below := point + Vector2i.DOWN
	if not _inside(above) or grid[above.y][above.x] != TILE_WATER or _surface_kind(above) == "ice":
		target.draw_rect(Rect2(top_left, Vector2(CELL, 3)), deep, true)
		target.draw_rect(Rect2(top_left + Vector2(0, 3), Vector2(CELL, 5)), Color("78c6c8", 0.07), true)
	if not _inside(below) or grid[below.y][below.x] != TILE_WATER or _surface_kind(below) == "ice":
		target.draw_rect(Rect2(top_left + Vector2(0, CELL - 2), Vector2(CELL, 2)), deep, true)
		target.draw_rect(Rect2(top_left + Vector2(0, CELL - 9), Vector2(CELL, 7)), Color("020c19", 0.17), true)


func _draw_water_tile(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	var is_garden := get_biome_index(floor_number) == 1
	var caustic := Color("7bf6e4", 0.32) if is_garden else Color("8de4ff", 0.34)
	var shore := Color("8bfad0", 0.65) if is_garden else Color("9fe9ff", 0.68)
	# Shared endpoints in world-cell coordinates carry each animated wave across
	# adjacent tiles/chunk boundaries rather than restarting it in every cell.
	var phase := animation_clock * 1.35 + float(point.y) * 0.57
	for wave in 2:
		var base_y := 14.0 + float(wave) * 22.0
		var start_y := base_y + sin(phase + float(point.x) * 0.7 + float(wave)) * 3.2
		var end_y := base_y + sin(phase + float(point.x + 1) * 0.7 + float(wave)) * 3.2
		target.draw_line(top_left + Vector2(0, start_y), top_left + Vector2(CELL, end_y), caustic, 1.5, true)
	# Bolhas de luz cintilantes
	if environment.kind_at(point) != "current":
		var bubble_y := fposmod(CELL - 6.0 - (animation_clock * 16.0 + (point.x + point.y) * 12.0), CELL - 8.0)
		target.draw_circle(top_left + Vector2(15.0 + sin(animation_clock * 3.0) * 3.0, bubble_y), 1.6, Color(caustic, 0.7))
	# Contornos de margem e espuma neon
	for direction in FOUR_WAY:
		var neighbor: Vector2i = point + direction
		if _inside(neighbor) and grid[neighbor.y][neighbor.x] == TILE_WATER and _surface_kind(neighbor) != "ice":
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
		target.draw_line(start, finish, shore, 2.2, true)


func _draw_ice_base(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	var ice_deep := Color("0b1e33")
	var ice_surface := Color("1a3d5e")
	var crack_color := Color("c6f3ff", 0.65)
	target.draw_rect(Rect2(top_left, Vector2(CELL - 1.0, CELL - 1.0)), ice_deep, true)
	target.draw_rect(Rect2(top_left + Vector2(2, 2), Vector2(CELL - 5, CELL - 5)), ice_surface, true)
	# Rachas cristalinas procedurais deterministas, retidas com o chão.
	var seed_val := (point.x * 47 + point.y * 89)
	var r1 := float(seed_val % 10) / 10.0
	var r2 := float((seed_val / 10) % 10) / 10.0
	target.draw_line(top_left + Vector2(6, 8 + r1 * 10), top_left + Vector2(24, 22), crack_color, 1.4, true)
	target.draw_line(top_left + Vector2(24, 22), top_left + Vector2(CELL - 8, 16 + r2 * 14), crack_color, 1.2, true)
	target.draw_line(top_left + Vector2(24, 22), top_left + Vector2(18 + r1 * 8, CELL - 8), Color(crack_color, 0.45), 1.0, true)


func _draw_ice_tile(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	var glow := Color("6ee3ff", 0.40)
	# Brilho especular dinâmico que desliza sobre o gelo
	var sweep := fposmod(animation_clock * 0.45 + point.x * 0.12 - point.y * 0.08, 1.8)
	if sweep < 1.0:
		var glint_x := top_left.x + sweep * (CELL + 16.0) - 8.0
		target.draw_line(Vector2(glint_x, top_left.y + 4), Vector2(glint_x - 14.0, top_left.y + CELL - 4), Color("ffffff", 0.28), 2.5, true)
	# Contorno de geada e cristalização nas margens
	for direction in FOUR_WAY:
		var neighbor: Vector2i = point + direction
		if _inside(neighbor) and grid[neighbor.y][neighbor.x] == TILE_WATER and _surface_kind(neighbor) == "ice":
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
		target.draw_line(start, finish, glow, 2.0, true)


func _draw_surface_reactions(target: CanvasItem, view: Rect2) -> void:
	for reaction in surface_reactions:
		var center: Vector2 = reaction.position
		if not view.grow(32.0).has_point(center):
			continue
		var t := clampf(float(reaction.age) / float(reaction.duration), 0.0, 1.0)
		if reaction.material in ["wood", "metal"]:
			var tint := Color("eac48a") if reaction.material == "wood" else Color("b8eaff")
			for spark in 5:
				var angle := float(spark) * TAU / 5.0 + 0.2
				var point := center + Vector2.from_angle(angle) * (10.0 + t * 13.0) + Vector2(0, 10.0 - t * 5.0)
				target.draw_circle(point, (1.8 if reaction.material == "wood" else 1.1) * (1.0 - t), Color(tint, 0.5 * (1.0 - t)))
			continue
		var color := Color("a4f3ef", 0.48 * (1.0 - t)) if reaction.material == "water" else Color("c7f4ff", 0.30 * (1.0 - t))
		var radius := lerpf(8.0, 23.0 if reaction.material == "water" else 16.0, t)
		target.draw_set_transform(center + Vector2(0, 7), 0.0, Vector2(1.0, 0.48))
		target.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 1.4, true)
		target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Real electrical state comes from the rules, not from decorative effects.
# The orange triangle marks a source; bright borders mark dangerous water.
func _draw_environment_surface(target: CanvasItem, point: Vector2i, top_left: Vector2) -> void:
	var kind: String = environment.kind_at(point)
	var center := top_left + Vector2(CELL * 0.5, CELL * 0.5)
	if kind == "ice":
		var frost := Color("a8efff", 0.95)
		target.draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), frost, false, 2.2)
		var crystal := top_left + Vector2(11, 11)
		for axis in [Vector2(5, 0), Vector2(2.5, 4.3), Vector2(-2.5, 4.3)]:
			target.draw_line(crystal - axis, crystal + axis, frost, 1.5, true)
		var ice: Dictionary = environment.cells.get(point, {})
		if bool(ice.get("brittle", false)):
			var stress := int(ice.get("stress", 0))
			var crack := PackedVector2Array([center + Vector2(-13, -13), center + Vector2(-4, -5), center + Vector2(-8, 3), center + Vector2(5, 8), center + Vector2(13, 15)])
			target.draw_polyline(crack, Color("21566c", 0.95), 3.2, true)
			target.draw_polyline(crack, Color("e6ffff", 0.95), 1.4, true)
			if stress > 0:
				target.draw_line(center + Vector2(-4, -5), center + Vector2(11, -12), frost, 1.5, true)
			if stress > 1:
				target.draw_line(center + Vector2(5, 8), center + Vector2(-14, 14), frost, 1.5, true)
	elif kind == "current":
		var direction: Vector2i = environment.cells[point].get("flow", Vector2i.ZERO)
		if direction in FOUR_WAY:
			# Moving streaks and droplets, never arrowheads. Their travel follows
			# the exact direction used by forced_direction and floating wood.
			for mote in EnvironmentVFX.current_particles(center, direction, CELL, 0.0 if freeze_turns > 0 else animation_clock, point.x * 37 + point.y * 79):
				target.draw_line(mote.tail, mote.position, Color("b5fff5", float(mote.alpha)), 1.6, true)
				target.draw_circle(mote.position, 1.3, Color("defefa", float(mote.alpha)))
	var live: bool = environment.is_electrified(point)
	var glow := float(electric_visual_glow.get(point, 0.25 if live else 0.0))
	if glow > 0.0:
		# An extinguished cell cools blue: never leave a false yellow hazard.
		var tint := Color("ffc848", 0.11 * glow) if live else Color("74c5df", 0.07 * glow)
		target.draw_circle(center, 21.0, tint)
	if bool(environment.cells.get(point, {}).get("source", false)):
		# Preserve the source warning but draw the live discharge over it; an
		# opaque icon must not hide the arc that drives the local light/audio.
		var triangle := PackedVector2Array([center + Vector2(0, -18), center + Vector2(17, 13), center + Vector2(-17, 13)])
		target.draw_colored_polygon(triangle, Color("ff982e", 0.96))
		var outline := triangle.duplicate()
		outline.append(triangle[0])
		target.draw_polyline(outline, Color("3b200d"), 2.2, true)
		target.draw_line(center + Vector2(0, -8), center + Vector2(0, 2), Color("351b0d"), 2.8, true)
		target.draw_circle(center + Vector2(0, 7), 1.7, Color("351b0d"))
	if live:
		var pulse := 0.76 + 0.18 * sin(animation_clock * 7.0 + float(point.x + point.y))
		target.draw_rect(Rect2(top_left + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color("ffde62", pulse), false, 2.0)
		var key := point.x * 37 + point.y * 79
		EnvironmentVFX.draw_arc(target, center + Vector2(-12, -8), center + Vector2(11, 8), key, animation_clock)
		# Only join nodes that are actually connected by the rules. Water and
		# metal conduct, while a wooden crate never invents a connection.
		for direction in FOUR_WAY:
			var next: Vector2i = point + direction
			if environment.powered.has(next):
				var crate_index := environment.crate_index_at(next)
				# Water-to-water is drawn once; a metal node has no water draw
				# callback, so water must draw that link in every direction.
				if crate_index < 0 and direction in [Vector2i.LEFT, Vector2i.UP]:
					continue
				var endpoint := _cell_center(next)
				if crate_index >= 0:
					endpoint = _crate_visual_position(crate_index, environment.crates[crate_index])
				EnvironmentVFX.draw_arc(target, center, endpoint, key + direction.x * 101 + direction.y * 193, animation_clock)


func _draw_environment_plate(target: CanvasItem, plate: Dictionary) -> void:
	var center := _cell_center(plate.pos)
	var active: bool = plate.get("active", false)
	var edge := Color("8effc9") if active else Color("e5bd72")
	var top := Rect2(center - Vector2(20, 13), Vector2(40, 29))
	target.draw_rect(top.grow(3), Color("020b16", 0.8))
	target.draw_rect(top, Color("174439") if active else Color("3f3024"))
	target.draw_rect(top, edge, false, 2.0)
	var label := "L" if plate.get("required", "") == "wood" else "M" if plate.get("required", "") == "metal" else "E" if plate.get("required", "") == "powered" else "+"
	target.draw_string(font, center + Vector2(-5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, 15, 15, Color("effff7") if active else Color("ffdfa3"))


func _draw_environment_gate(gate: Dictionary) -> void:
	var center := _cell_center(gate.pos)
	var opened: bool = gate.get("open", false)
	var dark := Color("0b1522")
	var edge := Color("65eebc") if opened else Color("ffb96d")
	# Open posts remain legible but do not cover the player or path.
	draw_rect(Rect2(center + Vector2(-24, -25), Vector2(6, 50)), dark)
	draw_rect(Rect2(center + Vector2(18, -25), Vector2(6, 50)), dark)
	draw_line(center + Vector2(-21, -22), center + Vector2(-21, 23), edge, 2.0, true)
	draw_line(center + Vector2(21, -22), center + Vector2(21, 23), edge, 2.0, true)
	if not opened:
		draw_rect(Rect2(center + Vector2(-18, -22), Vector2(36, 45)), Color("27313e"))
		for x in [-10.0, 0.0, 10.0]:
			draw_line(center + Vector2(x, -18), center + Vector2(x, 19), edge, 2.5, true)
		draw_line(center + Vector2(-16, 0), center + Vector2(16, 0), Color("ffe4af"), 2.0, true)


func _draw_environment_crate(crate: Dictionary, index: int) -> void:
	var center := _crate_visual_position(index, crate)
	var track = crate_visual_tracks.get(index)
	var push_pose := sin(clampf(float(track.progress), 0.0, 1.0) * PI) if track != null and track.kind == "push" and track.is_active() else 0.0
	var push_dir: Vector2 = (track.to - track.from).normalized() if track != null and track.kind == "push" else Vector2.ZERO
	var blocked_pose := sin((1.0 - clampf(blocked_crate_time / 0.16, 0.0, 1.0)) * PI) if index == blocked_crate_index and blocked_crate_time > 0.0 else 0.0
	if blocked_pose > 0.0:
		push_dir = blocked_crate_direction
		center += push_dir * blocked_pose * 2.0
	var metal: bool = crate.get("material", "") == "metal"
	var visible_cell := Vector2i(floori(center.x / CELL), floori(center.y / CELL))
	if not metal and environment.is_water(visible_cell):
		# Wood floats visually; logical occupancy remains at its resolved cell.
		center.y += sin(animation_clock * 3.6 + float(index)) * 1.1
	var top := Color("8db1bd") if metal else Color("bd864e")
	var face := Color("34525f") if metal else Color("694322")
	var side := Color("263c49") if metal else Color("4c2d18")
	var trim := Color("d9f6ff") if metal else Color("f5c58a")
	# Contact shadow, front and bevel give a small 2.5D silhouette while the
	# logical position remains an integer cell resolved before drawing.
	draw_set_transform(center + Vector2(0, 19), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Short resistance/compression and recovery, never a collision transform.
	var squash := push_pose * 0.035 + blocked_pose * 0.055
	var pose_scale := Vector2(1.0 - squash, 1.0 + squash * 0.5) if absf(push_dir.x) >= absf(push_dir.y) else Vector2(1.0 + squash * 0.5, 1.0 - squash)
	draw_set_transform_matrix(Transform2D(0.0, pose_scale, 0.0, center - center * pose_scale))
	var upper := center + Vector2(0, -5)
	var face_points := PackedVector2Array([upper + Vector2(-18, 4), upper + Vector2(18, 4), upper + Vector2(18, 18), upper + Vector2(-18, 18)])
	draw_colored_polygon(face_points, face)
	var top_points := PackedVector2Array([upper + Vector2(-18, 4), upper + Vector2(-14, -15), upper + Vector2(15, -15), upper + Vector2(18, 4)])
	draw_colored_polygon(top_points, top)
	draw_colored_polygon(PackedVector2Array([upper + Vector2(18, 4), upper + Vector2(15, -15), upper + Vector2(21, -10), upper + Vector2(21, 13), upper + Vector2(18, 18)]), side)
	draw_polyline(PackedVector2Array([upper + Vector2(-18, 4), upper + Vector2(-14, -15), upper + Vector2(15, -15), upper + Vector2(18, 4), upper + Vector2(-18, 4)]), trim, 1.5, true)
	if metal:
		draw_line(upper + Vector2(-10, -10), upper + Vector2(10, -10), Color("34525f"), 2.0, true)
		draw_line(upper + Vector2(-10, -4), upper + Vector2(10, -4), Color("34525f"), 2.0, true)
		for x in [-12.0, 12.0]:
			draw_circle(upper + Vector2(x, 11), 1.8, trim)
	else:
		draw_line(upper + Vector2(-10, -11), upper + Vector2(10, 1), Color("694322"), 2.2, true)
		draw_line(upper + Vector2(10, -11), upper + Vector2(-10, 1), Color("694322"), 2.2, true)
		draw_line(upper + Vector2(-14, 10), upper + Vector2(14, 10), Color("eab579", 0.65), 1.5, true)
	if metal and environment.powered.has(crate.pos):
		EnvironmentVFX.draw_arc(self, center + Vector2(-13, -8), center + Vector2(13, 4), int(crate.pos.x * 79 + crate.pos.y * 37), animation_clock)
		draw_string(font, center + Vector2(-4, 13), "!", HORIZONTAL_ALIGNMENT_LEFT, 12, 14, Color("ffe57a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if metal and environment.powered.has(crate.pos):
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = crate.pos + direction
			var neighbor := environment.crate_index_at(next)
			if neighbor >= 0 and environment.powered.has(next) and environment.crates[neighbor].get("material", "") == "metal":
				EnvironmentVFX.draw_arc(self, center, _crate_visual_position(neighbor, environment.crates[neighbor]), int(crate.pos.x * 97 + crate.pos.y * 53), animation_clock)


func _draw_powerup(item: Dictionary) -> void:
	var kind: String = item.get("kind", "speed")
	var tint := Color(POWERUP_COLORS.get(kind, "ffffff"))
	var center := _cell_center(item.pos) + Vector2(0, -5 + sin(animation_clock * 3.0 + item.pos.x) * 2.0)
	draw_circle(center + Vector2(0, 6), 17.0, Color(tint, 0.12))
	var frame := PackedVector2Array([center + Vector2(0, -17), center + Vector2(15, -3), center + Vector2(10, 13), center + Vector2(0, 17), center + Vector2(-10, 13), center + Vector2(-15, -3)])
	draw_colored_polygon(frame, Color("0a1427"))
	var outline := frame.duplicate()
	outline.append(frame[0])
	draw_polyline(outline, Color(tint, 0.95), 2.2, true)
	var facet := PackedVector2Array([center + Vector2(0, -13), center + Vector2(11, -3), center + Vector2(7, 9), center + Vector2(0, 13), center + Vector2(-7, 9), center + Vector2(-11, -3)])
	draw_colored_polygon(facet, Color(tint, 0.26))
	var bright := Color("f4ffff")
	match kind:
		"speed":
			draw_colored_polygon(PackedVector2Array([center + Vector2(1, -10), center + Vector2(-6, 1), center + Vector2(-1, 1), center + Vector2(-3, 9), center + Vector2(7, -3), center + Vector2(2, -3)]), bright)
		"magnet":
			draw_arc(center + Vector2(0, 1), 6.0, 0.0, PI, 16, bright, 2.8, true)
			draw_line(center + Vector2(-6, 1), center + Vector2(-6, -6), bright, 2.8, true)
			draw_line(center + Vector2(6, 1), center + Vector2(6, -6), bright, 2.8, true)
			draw_line(center + Vector2(-8, -6), center + Vector2(-4, -6), tint, 2.5, true)
			draw_line(center + Vector2(4, -6), center + Vector2(8, -6), tint, 2.5, true)
		"blink":
			draw_arc(center + Vector2(-4, 0), 5.5, -PI * 0.55, PI * 0.55, 14, bright, 2.0, true)
			draw_arc(center + Vector2(4, 0), 5.5, PI * 0.45, PI * 1.55, 14, bright, 2.0, true)
			draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), bright, 1.8, true)
		"time_freeze":
			for i in 3:
				var axis := Vector2.from_angle(float(i) * PI / 3.0) * 8.0
				draw_line(center - axis, center + axis, bright, 1.7, true)
			draw_circle(center, 2.2, tint)


func _draw_coin(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 4.2 + float(point.x)) * 2.0
	var spin := 0.30 + absf(sin(animation_clock * 5.0 + float(point.y))) * 0.70
	
	# Sombra projetada no chão
	draw_set_transform(center + Vector2(0, 8.0), 0.0, Vector2(spin, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color("04060c", 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Moeda Dourada 3D em perspectiva
	draw_set_transform(Vector2(center.x, center.y + bob), 0.0, Vector2(spin, 1.0))
	draw_circle(Vector2.ZERO, 9.5, Color("c9871e"))
	draw_circle(Vector2.ZERO, 8.0, Color("ffcb3d"))
	draw_circle(Vector2.ZERO, 5.5, Color("ffe17d"))
	# Gravação do símbolo cibernético central
	draw_rect(Rect2(-2, -2, 4, 4), Color("c9871e"), true)
	# Brilho especular no canto superior esquerdo
	draw_circle(Vector2(-2.5, -2.5), 1.8, Color("ffffff", 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shield(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 3.4 + float(point.x)) * 3.0
	var cy := center.y - 3.0 + bob
	var cx := center.x
	
	# Pedestal de contenção cibernético na base
	var ped_poly := PackedVector2Array([
		Vector2(cx - 10.0, center.y + 10.0), Vector2(cx + 10.0, center.y + 10.0),
		Vector2(cx + 7.0, center.y + 15.0), Vector2(cx - 7.0, center.y + 15.0)
	])
	draw_colored_polygon(ped_poly, Color("111a29"))
	draw_polyline(ped_poly, Color("355b80"), 1.2, true)
	
	# Coluna vertical de contenção holográfica
	draw_rect(Rect2(cx - 5.0, cy - 18.0, 10.0, 36.0), Color("3ae6ff", 0.07), true)
	
	# Sombra projetada do escudo no chão
	draw_circle(Vector2(cx, center.y + 11.0), 9.0, Color("020610", 0.45))
	
	# ── CORPO PRINCIPAL DO ESCUDO DE COMBATE (Heraldic Cyber-Shield) ──
	var shield_outer := PackedVector2Array([
		Vector2(cx - 11.0, cy - 12.0),
		Vector2(cx, cy - 9.5),
		Vector2(cx + 11.0, cy - 12.0),
		Vector2(cx + 12.5, cy - 2.0),
		Vector2(cx + 9.0, cy + 7.0),
		Vector2(cx, cy + 15.0),
		Vector2(cx - 9.0, cy + 7.0),
		Vector2(cx - 12.5, cy - 2.0)
	])
	draw_colored_polygon(shield_outer, Color("141c2c"))
	
	var shield_inner := PackedVector2Array([
		Vector2(cx - 8.5, cy - 9.5),
		Vector2(cx, cy - 7.5),
		Vector2(cx + 8.5, cy - 9.5),
		Vector2(cx + 9.5, cy - 1.5),
		Vector2(cx + 6.8, cy + 5.5),
		Vector2(cx, cy + 12.0),
		Vector2(cx - 6.8, cy + 5.5),
		Vector2(cx - 9.5, cy - 1.5)
	])
	draw_colored_polygon(shield_inner, Color("1e2a3f"))
	
	# Bordas metálicas de reforço com rebites dourados nos cantos
	draw_polyline(shield_outer, Color("5b83ad"), 1.5, true)
	draw_circle(Vector2(cx - 9.5, cy - 9.5), 1.2, Color("ffe07a"))
	draw_circle(Vector2(cx + 9.5, cy - 9.5), 1.2, Color("ffe07a"))
	draw_circle(Vector2(cx, cy + 12.5), 1.2, Color("ffe07a"))
	
	# ── GEMA PRECIOSA CENTRAL INCRUSTADA (Radiant Cyan Power Gem) ──
	var gem_top := Vector2(cx, cy - 7.0)
	var gem_left := Vector2(cx - 5.5, cy - 1.0)
	var gem_right := Vector2(cx + 5.5, cy - 1.0)
	var gem_bottom := Vector2(cx, cy + 6.0)
	var gem_center := Vector2(cx, cy - 1.5)
	
	draw_colored_polygon(PackedVector2Array([gem_top, gem_left, gem_center]), Color("a6f8ff"))
	draw_colored_polygon(PackedVector2Array([gem_top, gem_center, gem_right]), Color("5ce4ff"))
	draw_colored_polygon(PackedVector2Array([gem_center, gem_left, gem_bottom]), Color("21a8cc"))
	draw_colored_polygon(PackedVector2Array([gem_center, gem_right, gem_bottom]), Color("106a85"))
	
	var gem_poly := PackedVector2Array([gem_top, gem_left, gem_bottom, gem_right, gem_top])
	draw_polyline(gem_poly, Color("e5ffff"), 1.2, true)
	draw_circle(Vector2(cx - 1.5, cy - 4.0), 1.2, Color("ffffff"))
	
	# Gemas menores incrustadas nos flancos
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 8.0, cy - 1.0), Vector2(cx - 6.5, cy - 3.5),
		Vector2(cx - 5.0, cy - 1.0), Vector2(cx - 6.5, cy + 1.5)
	]), Color("5ae1ff"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 8.0, cy - 1.0), Vector2(cx + 6.5, cy - 3.5),
		Vector2(cx + 5.0, cy - 1.0), Vector2(cx + 6.5, cy + 1.5)
	]), Color("5ae1ff"))
	
	# Campo de força pulsante sutil
	var shield_pulse := 1.0 + sin(animation_clock * 5.0) * 0.08
	draw_arc(Vector2(cx, cy), 16.0 * shield_pulse, 0.0, TAU, 32, Color("5ef4ff", 0.35), 1.2, true)


func _draw_breaker(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 4.0 + float(point.x + point.y)) * 2.5
	var cy := center.y + bob
	var pulse := 1.0 + sin(animation_clock * 6.0) * 0.12
	
	# Sombra da ferramenta no chão
	draw_circle(center + Vector2(0, 11), 10.0, Color("02050f", 0.40))
	
	# Halo de energia âmbar/dourado ao redor da ferramenta (mesma cor do ícone do HUD)
	draw_circle(Vector2(center.x, cy), 18.0 * pulse, Color("ff9900", 0.16))
	
	# Ferramenta de Demolição em ângulo de 45 graus (Marreta/Picareta de Impacto do HUD)
	var base_pos := Vector2(center.x, cy)
	# Cabo metálico reforçado (cinzento titânio)
	var handle_start := base_pos + Vector2(-9, 10)
	var handle_end := base_pos + Vector2(8, -7)
	draw_line(handle_start, handle_end, Color("151a28"), 5.0, true)
	draw_line(handle_start, handle_end, Color("4a5670"), 2.8, true)
	# Pomo da base do cabo em ouro
	draw_circle(handle_start, 3.2, Color("ffaa1a"))
	
	# Cabeça de impacto / marreta-picareta dupla
	var head_center := handle_end
	var head_p1 := head_center + Vector2(-11, -8) # ponta afiada esquerda
	var head_p2 := head_center + Vector2(10, 9)   # bloco de marreta direita
	
	# Bloco estrutural da cabeça
	draw_line(head_p1, head_p2, Color("2a1a08"), 7.0, true)
	draw_line(head_p1, head_p2, Color("ff9d1a"), 4.0, true)
	draw_line(head_p1, head_p2, Color("fff2a8"), 1.8, true)
	
	# Ponta perfurante esquerda (triângulo de plasma âmbar)
	var spike_pts := PackedVector2Array([
		head_p1 + Vector2(-3, -2),
		head_p1 + Vector2(2, -4),
		head_p1 + Vector2(-2, 3)
	])
	draw_colored_polygon(spike_pts, Color("ffee77"))
	
	# Núcleo de sobrecarga cintilante
	draw_circle(head_center, 3.5 * pulse, Color("ffffff"))
	draw_circle(head_center, 2.0, Color("ff9900"))


func _draw_treasure_chest(point: Vector2i) -> void:
	var center := _cell_center(point)
	var bob := sin(animation_clock * 3.6 + float(point.y)) * 2.2
	var cy := center.y + bob
	
	# Baú do tesouro tecnológico Sci-Fi em cobre/ouro (para recompensas secretas/chefes)
	var w := 26.0
	var h := 18.0
	var body_rect := Rect2(center.x - w * 0.5, cy - 2.0, w, h)
	
	# Corpo do baú (aço escuro/bronze)
	draw_rect(body_rect, Color("261811"), true)
	
	# Borda e reforços dourados nos cantos
	draw_rect(Rect2(center.x - w * 0.5, cy - 2.0, 4.0, h), Color("e6a832"), true)
	draw_rect(Rect2(center.x + w * 0.5 - 4.0, cy - 2.0, 4.0, h), Color("e6a832"), true)
	draw_rect(Rect2(center.x - w * 0.5, cy + h - 5.0, w, 3.0), Color("c78820"), true)
	
	# Tampa curva/chanfrada superior do baú
	var lid_points := PackedVector2Array([
		Vector2(center.x - w * 0.5 - 1.0, cy - 2.0),
		Vector2(center.x - w * 0.5 + 2.0, cy - 9.0),
		Vector2(center.x + w * 0.5 - 2.0, cy - 9.0),
		Vector2(center.x + w * 0.5 + 1.0, cy - 2.0)
	])
	draw_colored_polygon(lid_points, Color("ffd45e"))
	draw_polyline(lid_points, Color("fff1a8"), 1.2, true)
	
	# Fechadura cibernética dourada com luz âmbar a vazar
	var lock_rect := Rect2(center.x - 4.0, cy + 1.0, 8.0, 8.0)
	draw_rect(lock_rect, Color("ffd866"), true)
	draw_rect(Rect2(center.x - 1.5, cy + 3.5, 3.0, 4.0), Color("120904"), true)
	draw_circle(Vector2(center.x, cy + 4.5), 2.2, Color("fff4ba"))
	
	# Halo/Raio sutil de luz do fecho
	draw_circle(Vector2(center.x, cy + 5.0), 6.0, Color("ffb84d", 0.35))


func _draw_portal() -> void:
	var center := _cell_center(portal_position)
	var pulse := sin(animation_clock * 2.8) * 3.0
	var main_color := Color("c37aff") if portal_open else Color("c05e79")
	var sec_color := Color("4eeeff") if portal_open else Color("ff7990")
	var cx := center.x
	var cy := center.y
	
	# Pilares emissores laterais (Stargate Pylons)
	var pylon_w := 6.0
	var pylon_h := 28.0
	# Pilar esquerdo
	draw_rect(Rect2(cx - 24.0, cy - pylon_h * 0.5, pylon_w, pylon_h), Color("120f26"), true)
	draw_rect(Rect2(cx - 24.0, cy - pylon_h * 0.5, pylon_w, pylon_h), Color("3f2d6b"), false, 1.2)
	draw_rect(Rect2(cx - 23.0, cy - 8.0, 4.0, 16.0), Color(sec_color, 0.75), true)
	# Pilar direito
	draw_rect(Rect2(cx + 18.0, cy - pylon_h * 0.5, pylon_w, pylon_h), Color("120f26"), true)
	draw_rect(Rect2(cx + 18.0, cy - pylon_h * 0.5, pylon_w, pylon_h), Color("3f2d6b"), false, 1.2)
	draw_rect(Rect2(cx + 19.0, cy - 8.0, 4.0, 16.0), Color(sec_color, 0.75), true)
	
	# Arco estrutural superior
	var arch_pts := PackedVector2Array([
		Vector2(cx - 21.0, cy - pylon_h * 0.5),
		Vector2(cx, cy - 22.0),
		Vector2(cx + 21.0, cy - pylon_h * 0.5)
	])
	draw_polyline(arch_pts, Color("4a357d"), 2.4, true)
	draw_circle(Vector2(cx, cy - 22.0), 2.5, Color(main_color, 0.9))
	
	# Plataforma de ancoragem no chão
	draw_circle(center, 28.0 + pulse, Color(main_color, 0.10))
	
	# Anéis de energia em rotação contrária
	draw_arc(center, 21.0 + pulse, animation_clock * 1.1, animation_clock * 1.1 + TAU * 0.75, 48, Color(main_color, 0.9), 2.8, true)
	draw_arc(center, 15.0 - pulse * 0.3, -animation_clock * 1.4, -animation_clock * 1.4 + TAU * 0.75, 40, Color(sec_color, 0.85), 2.0, true)
	
	# Horizonte de eventos (vórtice gravitacional profundo)
	draw_circle(center, 12.0, Color("050210", 0.98))
	draw_circle(center, 7.0 + sin(animation_clock * 5.0) * 1.2, Color(main_color, 0.7))
	draw_circle(center, 3.5 + sin(animation_clock * 7.0) * 0.8, Color("ffffff", 0.95))
	
	# Setas holográficas verticais ascendentes
	var arrow_y := fposmod(-animation_clock * 20.0, 16.0) - 8.0
	var arrow_pts := PackedVector2Array([
		center + Vector2(-5, arrow_y + 3), center + Vector2(0, arrow_y - 2), center + Vector2(5, arrow_y + 3)
	])
	draw_polyline(arrow_pts, Color("ffffff", 0.75), 1.5, true)
	
	# Glifos / Runas orbitais holográficas
	for i in 4:
		var angle := animation_clock * 0.75 + float(i) * TAU / 4.0
		var orbit := Vector2(cos(angle), sin(angle) * 0.7) * (25.0 + pulse)
		draw_circle(center + orbit, 2.0, Color(sec_color, 0.85))
		draw_circle(center + orbit, 0.8, Color("ffffff"))
		
	if not portal_open:
		draw_circle(center, 8.0, Color("200918", 0.92))
		draw_arc(center, 18.0, 0.0, TAU, 40, Color("ff7990"), 2.2, true)


func _draw_switch(target: CanvasItem, item: Dictionary) -> void:
	var center := _cell_center(item.pos)
	var is_active: bool = item.active
	var state_col := Color("5ef59f") if is_active else Color("52e3ff")
	if item.has("order"):
		state_col = Color(PUZZLE_COLORS[clampi(int(item.order), 0, 2)])
	var pulse := 1.0 + sin(animation_clock * 4.2 + center.x * 0.05) * 0.08
	
	# Sombra da consola projetada no chão
	target.draw_circle(center + Vector2(0, 5), 14.0, Color("02050f", 0.45))
	
	# Placa base octogonal industrial chanfrada
	var base_poly := _chamfered_square_points(center, 13.5, 4.0)
	target.draw_colored_polygon(base_poly, Color("151a2d"))
	var base_border := base_poly.duplicate()
	base_border.append(base_poly[0])
	target.draw_polyline(base_border, Color("35426b"), 1.2, true)
	
	# Parafusos / rebites nos 4 cantos
	var bolt_offsets := [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9)]
	for bo in bolt_offsets:
		target.draw_circle(center + bo, 1.4, Color("4a5987"))
		target.draw_circle(center + bo + Vector2(-0.4, -0.4), 0.5, Color("9ab0e6"))
	
	# Ranhuras de conduta nos 4 lados ligando ao chão
	target.draw_line(center + Vector2(0, -13), center + Vector2(0, -8), Color(state_col, 0.7), 1.6, true)
	target.draw_line(center + Vector2(0, 8), center + Vector2(0, 13), Color(state_col, 0.7), 1.6, true)
	target.draw_line(center + Vector2(-13, 0), center + Vector2(-8, 0), Color(state_col, 0.7), 1.6, true)
	target.draw_line(center + Vector2(8, 0), center + Vector2(13, 0), Color(state_col, 0.7), 1.6, true)
	
	# Anel metálico interno elevado (cilindro 2.5D)
	target.draw_circle(center + Vector2(0, 1), 8.2, Color("0c101e"))
	target.draw_circle(center, 8.0, Color("202842"))
	target.draw_circle(center, 7.0, Color("10162a"))
	
	# Cristal / Pilar holográfico central pulsante
	var crystal_radius := 4.6 * (pulse if is_active else 1.0)
	target.draw_circle(center, crystal_radius * 1.5, Color(state_col, 0.22))
	target.draw_circle(center, crystal_radius, state_col)
	# Núcleo branco brilhante de alta energia
	target.draw_circle(center + Vector2(-0.8, -0.8), crystal_radius * 0.45, Color("ffffff", 0.95))
	
	# Anel de status circular giratório
	if is_active:
		var rot := animation_clock * 2.4
		target.draw_arc(center, 10.5, rot, rot + TAU * 0.75, 20, Color("8affbb", 0.85), 1.4, true)
	else:
		target.draw_arc(center, 10.5, 0.0, TAU, 24, Color(state_col, 0.5), 1.0, true)
	# One, two or three white dots distinguish the ordered runes without color.
	if item.has("order"):
		var count := clampi(int(item.order) + 1, 1, 3)
		target.draw_rect(Rect2(center + Vector2(-10, 14), Vector2(20, 7)), Color("07101d", 0.9))
		for dot in count:
			target.draw_circle(center + Vector2((float(dot) - float(count - 1) * 0.5) * 5.5, 17.5), 1.8, Color("f3ffff"))


func _draw_trap(target: CanvasItem, trap: Dictionary) -> void:
	var center := _cell_center(trap.pos)
	if trap.get("type", "one_shot") == "rhythm":
		# Three LEDs: the outlined one is the phase of the NEXT action. The
		# first (red/spiked) phase is dangerous, the other two are safe.
		var next_phase := posmod(turn_number + 1 + int(trap.get("phase", 0)), 3)
		var hot := _rhythm_is_hot(trap, turn_number + 1)
		var color := Color("ff6957") if hot else Color("70dfd8")
		target.draw_circle(center, 18.0, Color(color, 0.14))
		target.draw_arc(center, 13.0, 0.0, TAU, 28, Color(color, 0.9), 2.2, true)
		var spikes := PackedVector2Array([center + Vector2(0, -9), center + Vector2(7, 7), center + Vector2(-7, 7)])
		target.draw_colored_polygon(spikes, Color(color, 0.8 if hot else 0.28))
		target.draw_rect(Rect2(center + Vector2(-14, 15), Vector2(28, 8)), Color("07101d", 0.92))
		for i in 3:
			var led := center + Vector2((float(i) - 1.0) * 8.0, 19.0)
			target.draw_circle(led, 2.0, Color("ff7761") if i == 0 else Color("83eee5"))
			if i == next_phase:
				target.draw_arc(led, 3.4, 0.0, TAU, 12, Color("ffffff"), 1.0, true)
		return
	if not trap.get("armed", true) and not trap.get("revealed", false):
		return
	var armed: bool = trap.get("armed", true)
	var alpha := (0.64 + sin(animation_clock * 5.0 + center.x) * 0.16) if armed else 0.2
	target.draw_circle(center, 18.0, Color("ff684c", alpha * 0.12))
	target.draw_arc(center, 13.0, animation_clock * 0.25, animation_clock * 0.25 + TAU, 28, Color("ff775c", alpha), 2.0, true)
	for i in 4:
		var angle := i * TAU / 4.0
		target.draw_circle(center + Vector2(cos(angle), sin(angle)) * 7.0, 2.0, Color("ffbd73", alpha))


func _draw_enemy_defeat(ghost: Dictionary) -> void:
	var age := float(ghost.age)
	var delay := float(ghost.get("delay", 0.0))
	var center: Vector2 = ghost.to
	if age < -0.000001 and delay > 0.0:
		# The actor is logically gone, but retains its original appearance until
		# the committed visual contact, rather than becoming a ghost prematurely.
		var before: Dictionary = ghost.snapshot
		before.from = ghost.from
		before.to = ghost.to
		before.t = clampf((age + delay) / delay, 0.0, 1.0)
		_draw_enemy(before)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var t := clampf(maxf(0.0, age) / float(ghost.duration), 0.0, 1.0)
	var body_alpha := 0.82 * (1.0 - smoothstep(0.06, 0.68, t))
	var role := str(ghost.role)
	var color := Color("ff6985")
	match role:
		"sentry": color = Color("ffcb62")
		"wisp", "warden": color = Color("d297ff")
		"rusher": color = Color("ff9b42")
		"mirror": color = Color("a8e7ff")
		"patrol": color = Color("75f7b6")
	if ghost.material == "electricity":
		color = color.lerp(Color("ffe88b"), 0.35)
	var direction: Vector2 = Vector2(ghost.get("direction", Vector2.RIGHT)).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.RIGHT
	var side := Vector2(-direction.y, direction.x)
	var squash := 1.0 - minf(0.18, t * 0.26)
	if role == "chess_boss":
		var texture: Texture2D = BOSS_TEXTURES.get(str(ghost.boss_kind), BOSS_TEXTURES["pawn"])
		var size := 100.0 * squash
		draw_texture_rect(texture, Rect2(center + Vector2(-size * 0.5, -size * 0.78), Vector2(size, size)), false, Color(1, 1, 1, body_alpha))
	elif role == "wisp":
		var r := 14.0 * squash
		draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.55, 3), center + Vector2(r * 0.55, 3), center + Vector2(0, r * 1.65)]), Color(color, body_alpha * 0.34))
		draw_circle(center, r, Color(color, body_alpha * 0.62))
		draw_circle(center + Vector2(-3, -4), r * 0.45, Color("f6dfff", body_alpha * 0.75))
	elif role == "sentry":
		draw_circle(center, 15.0 * squash, Color("6c4613", body_alpha))
		draw_circle(center, 12.5 * squash, Color(color, body_alpha * 0.9))
		draw_circle(center, 6.0 * squash, Color("241a13", body_alpha))
		draw_circle(center, 2.8 * squash, Color("fff3c9", body_alpha))
	elif role == "rusher":
		var face: Vector2 = Vector2(ghost.get("face", direction)).normalized()
		var face_side := Vector2(-face.y, face.x)
		var nose := center + face * 20.0 * squash
		var wing_a := center - face * 10.0 + face_side * 15.0 * squash
		var wing_b := center - face * 10.0 - face_side * 15.0 * squash
		draw_colored_polygon(PackedVector2Array([nose, wing_a, center - face * 5.0, wing_b]), Color(color, body_alpha * 0.75))
		draw_circle(center, 3.0, Color("fff5d3", body_alpha))
	else:
		var size := (20.0 if role == "warden" else 15.0) * squash
		var shape := _chamfered_square_points(center, size, size * (0.55 if role == "mirror" else 0.30))
		draw_colored_polygon(shape, Color(color, body_alpha * 0.46))
		shape.append(shape[0])
		draw_polyline(shape, Color(color, body_alpha), 1.8, true)
		if role == "patrol":
			draw_line(center - side * size, center + side * size, Color("ddffe9", body_alpha), 2.0, true)
		elif role == "mirror":
			draw_line(center - Vector2(0, size * 0.8), center + Vector2(0, size * 0.8), Color("efffff", body_alpha), 1.4, true)
		else:
			draw_circle(center, 3.5 * squash, Color("ffffff", body_alpha))
	if age <= 0.0:
		return
	# The pieces inherit the silhouette's material; wisps shed light instead
	# of solid plates. No pieces can block a cell or use gameplay randomness.
	var fade := pow(1.0 - t, 1.2)
	for i in 7:
		var a := float(i) * TAU / 7.0 + 0.28
		var outward := Vector2(cos(a), sin(a))
		var tangent := Vector2(-outward.y, outward.x)
		var flight := maxf(0.0, t - float(i % 3) * 0.025)
		var p := center + outward * (8.0 + flight * (22.0 + float(i % 4) * 5.0)) + direction * flight * 10.0
		p.y += flight * flight * (3.0 if role == "wisp" else 12.0)
		if role == "wisp":
			draw_circle(p, 2.8 - t * 1.4, Color(color, fade * 0.60))
			draw_circle(p - outward * 3.0, 1.0, Color("fff4ff", fade * 0.65))
		elif role in ["rusher", "mirror"]:
			# Triangular propulsion fins and mirrored shards break differently
			# from the round sentry and squared patrol/hunter plates.
			var shard_size := 4.8 if role == "rusher" else 3.6
			draw_colored_polygon(PackedVector2Array([p + outward * shard_size, p - outward * 2.0 + tangent * 2.4, p - outward * 2.0 - tangent * 2.4]), Color(color, fade * 0.70))
		elif role == "sentry":
			draw_arc(p, 2.8 + float(i % 2), a - 0.9, a + 1.4, 8, Color(color, fade * 0.78), 1.5, true)
		else:
			var size := 2.5 + float(i % 2)
			var plate := PackedVector2Array([p - outward * size - tangent * size, p + outward * size - tangent * size * 0.8, p + outward * size + tangent * size, p - outward * size + tangent * size * 0.7])
			draw_colored_polygon(plate, Color(color, fade * 0.65))
		if ghost.material == "electricity" and i % 2 == 0:
			draw_line(p, p + tangent * 3.0 + outward * 4.0, Color("fff0a1", fade * 0.7), 1.0, true)


func _enemy_pose_transform(enemy: Dictionary, center: Vector2, motion_arc: float, reaction: float) -> Transform2D:
	# Shape the body from the segment already being presented, never the next
	# logical step or path. Heavier silhouettes yield less than agile ones.
	var role: String = enemy.get("role", "hunter")
	var strength := 0.075
	var lean_strength := 0.08
	match role:
		"rusher":
			strength = 0.12
			lean_strength = 0.13
		"wisp":
			strength = 0.11
			lean_strength = 0.06
		"sentry", "warden", "chess_boss":
			strength = 0.035
			lean_strength = 0.04
		"patrol", "mirror":
			strength = 0.055
	var track = enemy.get("_visual_motion")
	if track != null and track.is_active() and str(track.kind) in ["enemy_attack", "enemy_jump_attack"]:
		strength *= 1.35
		lean_strength *= 1.30
	var direction := Vector2.ZERO
	if track != null and track.is_active():
		direction = (Vector2(track.to) - Vector2(track.from)).normalized()
	elif motion_arc > 0.0:
		direction = (Vector2(enemy.get("to", center)) - Vector2(enemy.get("from", center))).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2(enemy.get("face", Vector2i.DOWN)).normalized()
	var axis := absf(direction.x) - absf(direction.y)
	var breath := sin(animation_clock * 2.7 + center.x * 0.013) * 0.012
	# Contact begins compressed, then resolves back to the actual silhouette;
	# heavy actors yield less than wisps/rushers, without changing their cell.
	var impact := pow(reaction, 0.8) if reaction > 0.0 else 0.0
	var stretch := motion_arc * strength
	var reaction_dir: Vector2 = enemy.get("_visual_reaction_direction", Vector2.ZERO)
	var reaction_axis := absf(reaction_dir.x) - absf(reaction_dir.y)
	var yield_amount := 0.035 if role in ["sentry", "warden", "chess_boss"] else 0.09
	var scale := Vector2(1.0 + stretch * axis + breath - impact * yield_amount * reaction_axis, 1.0 - stretch * axis - breath + impact * yield_amount * reaction_axis)
	var tilt := direction.x * motion_arc * lean_strength + reaction_dir.x * impact * 0.08
	var pose := Transform2D(tilt, scale, 0.0, Vector2.ZERO)
	pose.origin = center - pose * center
	return pose


func _draw_enemy(enemy: Dictionary) -> void:
	var center := _enemy_contact_draw_position(enemy)
	var role: String = enemy.get("role", "hunter")
	var track = enemy.get("_visual_motion")
	var moving: bool = track.is_active() if track != null else float(enemy.get("t", 1.0)) < 1.0 and not Vector2(enemy.from).is_equal_approx(enemy.to)
	var progress: float = track.progress if track != null else float(enemy.get("t", 1.0))
	var motion_arc := sin(clampf(progress, 0.0, 1.0) * PI) if moving else 0.0
	var leap_height := 7.0 if role == "chess_boss" and enemy.get("boss_kind", "") == "knight" else 3.5 if role == "wisp" else 2.0
	center.y -= motion_arc * leap_height
	if moving and track != null and str(track.kind) in ["enemy_attack", "enemy_jump_attack"]:
		var lunge_direction: Vector2 = (Vector2(track.to) - Vector2(track.from)).normalized()
		var lunge := 2.0 if role in ["sentry", "warden", "chess_boss"] else 4.0
		center += lunge_direction * motion_arc * lunge
	var reaction: float = clampf(float(enemy.get("_visual_reaction", 0.0)) / 0.22, 0.0, 1.0)
	if reaction > 0.0:
		var direction: Vector2 = enemy.get("_visual_reaction_direction", Vector2.UP)
		var recoil_size := 2.2 if role in ["sentry", "warden", "chess_boss"] else 4.0
		center += direction * reaction * recoil_size
	if role == "chess_boss":
		var kind: String = enemy.get("boss_kind", "pawn")
		var texture: Texture2D = BOSS_TEXTURES.get(kind, BOSS_TEXTURES["pawn"])
		var size := 110.0 if kind in ["queen", "king"] else 100.0
		center.y += sin(animation_clock * 2.5 + center.x * 0.01) * 1.5
		var size_v := Vector2(size * (1.0 + motion_arc * 0.025), size * (1.0 - motion_arc * 0.025))
		draw_set_transform_matrix(_enemy_pose_transform(enemy, center, motion_arc, reaction))
		draw_texture_rect(texture, Rect2(center + Vector2(-size_v.x * 0.5, -size_v.y * 0.78), size_v), false)
		return
	var alert: bool = enemy.get("alert", _enemy_sees_player(enemy.pos))
	var size_scale := 1.35 if role == "warden" else 0.88 if role == "wisp" else 0.95 if role == "rusher" else 1.08 if role == "sentry" else 1.02
	var bob := sin(animation_clock * (5.5 if alert else 3.2) + center.x * 0.015) * (3.0 if role == "wisp" else 1.4)
	center.y += bob
	var face: Vector2i = enemy.get("face", Vector2i(signi(player_position.x - enemy.pos.x), signi(player_position.y - enemy.pos.y)))
	if face == Vector2i.ZERO:
		face = Vector2i.DOWN
	var face_offset := Vector2(face) * (2.2 if alert else 1.2)
	var half_size := 15.5 * size_scale
	
	# Sombra de chão dinâmica e suave
	draw_set_transform(center + Vector2(0, 12 * size_scale), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, half_size * 1.15, Color("020612", 0.48))
	draw_set_transform_matrix(_enemy_pose_transform(enemy, center, motion_arc, reaction))

	if role == "patrol":
		# Low, tracked scout; the chevron points along its patrol direction.
		var direction: Vector2i = enemy.get("patrol_dir", Vector2i.RIGHT)
		var heading := Vector2(direction)
		if heading.length_squared() < 0.1:
			heading = Vector2.RIGHT
		var side := Vector2(-heading.y, heading.x)
		draw_line(center + side * 14.0 - heading * 11.0, center + side * 14.0 + heading * 11.0, Color("081e18"), 7.0, true)
		draw_line(center - side * 14.0 - heading * 11.0, center - side * 14.0 + heading * 11.0, Color("081e18"), 7.0, true)
		var shell := _chamfered_square_points(center, 15.0, 5.0)
		draw_colored_polygon(shell, Color("174b3f"))
		var rim := shell.duplicate()
		rim.append(shell[0])
		draw_polyline(rim, Color("75f7b6"), 1.8, true)
		draw_circle(center, 8.0, Color("0b2523"))
		draw_line(center - heading * 5.0 + side * 4.0, center + heading * 6.0, Color("ddffe9"), 2.2, true)
		draw_line(center - heading * 5.0 - side * 4.0, center + heading * 6.0, Color("ddffe9"), 2.2, true)
		return

	if role == "mirror":
		# Split reflective diamond, visibly unlike the drones or chess pieces.
		var shell := PackedVector2Array([center + Vector2(0, -19), center + Vector2(16, 0), center + Vector2(0, 19), center + Vector2(-16, 0)])
		draw_colored_polygon(shell, Color("132742"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(13, 0), center + Vector2(0, 16)]), Color("4b9bce"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(-13, 0), center + Vector2(0, 16)]), Color("89d7ed"))
		var rim := shell.duplicate()
		rim.append(shell[0])
		draw_polyline(rim, Color("c8f6ff"), 1.7, true)
		draw_line(center + Vector2(0, -14), center + Vector2(0, 14), Color("efffff", 0.8), 1.3, true)
		draw_line(center + Vector2(-9, -2), center + Vector2(-3, -2), Color("122f47"), 2.2, true)
		draw_line(center + Vector2(3, 2), center + Vector2(9, 2), Color("e3ffff"), 2.2, true)
		draw_circle(center + Vector2(-6, -7), 1.8, Color("ffffff"))
		return

	if role == "hunter":
		# HUNTER: Drone de Assalto Tático (Armadura Titânio Carmesim, Antenas Chifres, Visor Angular)
		# 1. Base / Chassi inferior
		var base_hull := _chamfered_square_points(center + Vector2(0, 1), half_size, half_size * 0.35)
		draw_colored_polygon(base_hull, Color("14161f"))
		
		# 2. Carapaça carmesim 3D chanfrada com luz superior
		var armor := _chamfered_square_points(center, half_size * 0.92, half_size * 0.32)
		draw_colored_polygon(armor, Color("c41a37"))
		var armor_rim := armor.duplicate()
		armor_rim.append(armor[0])
		draw_polyline(armor_rim, Color("ff4865"), 1.2, true)
		
		# 3. Destaque especular na calota superior
		var highlight_poly := PackedVector2Array([
			center + Vector2(-half_size * 0.6, -half_size * 0.85),
			center + Vector2(half_size * 0.6, -half_size * 0.85),
			center + Vector2(half_size * 0.45, -half_size * 0.45),
			center + Vector2(-half_size * 0.45, -half_size * 0.45)
		])
		draw_colored_polygon(highlight_poly, Color("ff7a92", 0.65))
		
		# 4. Antenas / Chifres mecânicos laterais superiores com pontas neon
		var horn_l := [center + Vector2(-half_size * 0.65, -half_size * 0.5), center + Vector2(-half_size * 1.1, -half_size * 1.3)]
		var horn_r := [center + Vector2(half_size * 0.65, -half_size * 0.5), center + Vector2(half_size * 1.1, -half_size * 1.3)]
		draw_line(horn_l[0], horn_l[1], Color("1f2333"), 3.0, true)
		draw_line(horn_r[0], horn_r[1], Color("1f2333"), 3.0, true)
		draw_line(horn_l[0], horn_l[1], Color("ff2e4e"), 1.5, true)
		draw_line(horn_r[0], horn_r[1], Color("ff2e4e"), 1.5, true)
		draw_circle(horn_l[1], 2.2, Color("ffffff") if alert else Color("ff4865"))
		draw_circle(horn_r[1], 2.2, Color("ffffff") if alert else Color("ff4865"))
		
		# 5. Painel do visor frontal escurecido (recessed socket)
		var visor_box := Rect2(center + Vector2(-half_size * 0.55, -2.5) + face_offset, Vector2(half_size * 1.1, 8.0))
		draw_rect(visor_box, Color("08080e"), true)
		
		# 6. Olhos táticos angulares luminosos
		var eye_y := center.y + 1.5 + face_offset.y
		var le := Vector2(center.x - 4.5 + face_offset.x, eye_y)
		var re := Vector2(center.x + 4.5 + face_offset.x, eye_y)
		if alert:
			# ALERTA: olhos VERMELHOS intensos a olhar DIRECTAMENTE para o jogador
			var p_pos := _player_visual_position()
			var to_player_l := (p_pos - le).normalized() * 1.6
			var to_player_r := (p_pos - re).normalized() * 1.6
			var eye_col_alert := Color("ff0820")
			# Halo externo vermelho pulsante
			draw_circle(le, 3.8, Color("ff0820", 0.45))
			draw_circle(re, 3.8, Color("ff0820", 0.45))
			draw_line(le + Vector2(-3.5, -2.0), le + Vector2(2.5, 1.0), eye_col_alert, 2.4, true)
			draw_line(re + Vector2(-2.5, 1.0), re + Vector2(3.5, -2.0), eye_col_alert, 2.4, true)
			draw_circle(le + to_player_l, 1.6, Color("ff4060"))
			draw_circle(re + to_player_r, 1.6, Color("ff4060"))
			draw_circle(le + to_player_l, 0.7, Color("ffffff"))
			draw_circle(re + to_player_r, 0.7, Color("ffffff"))
		else:
			var eye_col := Color("ff2040")
			draw_line(le + Vector2(-3.5, -2.0), le + Vector2(2.5, 1.0), eye_col, 2.4, true)
			draw_line(re + Vector2(-2.5, 1.0), re + Vector2(3.5, -2.0), eye_col, 2.4, true)
			draw_circle(le, 1.4, Color("ff4060", 0.9))
			draw_circle(re, 1.4, Color("ff4060", 0.9))
		return

	if role == "sentry":
		# SENTRY: Tanque Mecânico Sentinela (Cúpula Dourada 3D, Ombros Blindados, Grande Scanner Cíclope)
		# 1. Blindagem de ombro pesada (pauldrons esquerdo e direito)
		draw_rect(Rect2(center + Vector2(-half_size * 1.35, -5), Vector2(6, 12)), Color("1c1912"), true)
		draw_rect(Rect2(center + Vector2(-half_size * 1.35 + 1, -4), Vector2(4, 10)), Color("d6961a"), true)
		draw_rect(Rect2(center + Vector2(half_size * 1.35 - 6, -5), Vector2(6, 12)), Color("1c1912"), true)
		draw_rect(Rect2(center + Vector2(half_size * 1.35 - 5, -4), Vector2(4, 10)), Color("d6961a"), true)
		
		# 2. Cúpula esférica principal em bronze/ouro metálico
		draw_circle(center + Vector2(0, 1.5), half_size * 0.95, Color("14120e"))
		draw_circle(center, half_size * 0.92, Color("332408"))
		draw_circle(center + Vector2(0, -1), half_size * 0.85, Color("df9b15"))
		# Highlight curvado superior
		draw_circle(center + Vector2(-half_size * 0.25, -half_size * 0.35), half_size * 0.45, Color("ffe775", 0.75))
		
		# 3. Cavidade do visor central em preto profundo
		draw_circle(center + face_offset * 0.7, half_size * 0.52, Color("08080b"))
		draw_arc(center + face_offset * 0.7, half_size * 0.52, 0.0, TAU, 24, Color("ffbd38"), 1.2, true)
		
		# 4. Olho óptico de scanner 3D
		var p_pos_s := _player_visual_position()
		if alert:
			# ALERTA: scanner TRAVA no jogador, fica VERMELHO sangue
			var eye_center_alert := center + face_offset * 0.8
			# Offset direction toward player from sentry center
			var to_pl := (p_pos_s - center).normalized() * (half_size * 0.28)
			eye_center_alert = center + to_pl
			# Halo exterior vermelho pulsante
			draw_circle(eye_center_alert, 7.0, Color("ff0000", 0.30))
			draw_circle(eye_center_alert, 4.8, Color("cc0000", 0.75))
			draw_circle(eye_center_alert, 3.2, Color("ff2020"))
			draw_circle(eye_center_alert, 1.8, Color("fff0f0"))
			draw_circle(eye_center_alert + Vector2(-0.8, -0.8), 0.9, Color("ffffff"))
			# Attention stays on the entity itself, not a projected line.
		else:
			# CALMO: scanner oscila lentamente em dourado
			var sweep := sin(animation_clock * 4.0) * (half_size * 0.22)
			var eye_center := center + face_offset * 0.8 + Vector2(sweep, 0)
			draw_circle(eye_center, 4.2, Color("ffaa00", 0.35))
			draw_circle(eye_center, 3.2, Color("ffbc24"))
			draw_circle(eye_center, 1.8, Color("fff8d1"))
			draw_circle(eye_center + Vector2(-0.8, -0.8), 0.9, Color("ffffff"))
		return

	if role == "wisp":
		# WISP: Esfera de Plasma Etérea (Camadas Translúcidas, Rastro de Cauda Fluido, Satélites Flutuantes)
		var wisp_r := half_size * 0.95
		var flame_w := sin(animation_clock * 9.0 + center.x * 0.03) * 3.5
		
		# 1. Cauda de plasma fluida ondulante
		var tail_pts := PackedVector2Array([
			center + Vector2(-wisp_r * 0.55, 3),
			center + Vector2(wisp_r * 0.55, 3),
			center + Vector2(flame_w * 0.5, wisp_r * 1.5),
			center + Vector2(flame_w, wisp_r * 2.2 + 2)
		])
		draw_colored_polygon(tail_pts, Color("8020d0", 0.65))
		var inner_tail := PackedVector2Array([
			center + Vector2(-wisp_r * 0.3, 3),
			center + Vector2(wisp_r * 0.3, 3),
			center + Vector2(flame_w * 0.4, wisp_r * 1.4)
		])
		draw_colored_polygon(inner_tail, Color("da8aff", 0.85))
		
		# 2. Orbe de plasma volumétrico multicamada
		draw_circle(center, wisp_r * 1.2, Color("9b36eb", 0.20))
		draw_circle(center, wisp_r, Color("9230e0", 0.85))
		draw_circle(center + Vector2(0, -1.5), wisp_r * 0.78, Color("c26aff", 0.92))
		draw_circle(center + Vector2(-2, -3.5), wisp_r * 0.45, Color("f3d5ff", 0.88))
		
		# 3. Motes / Chamas satélites orbitando o Wisp
		for s in 3:
			var s_ang := animation_clock * 3.0 + float(s) * TAU / 3.0
			var s_pos := center + Vector2(cos(s_ang) * (wisp_r * 1.35), sin(s_ang) * (wisp_r * 0.75))
			draw_circle(s_pos, 2.2, Color("e3a4ff", 0.85))
			draw_circle(s_pos, 1.0, Color("ffffff"))
			
		# 4. Rosto digital com visor expressivo
		var eye_y := center.y - 1.0 + face_offset.y
		var le := center + Vector2(-4.2, eye_y - center.y) + face_offset * 0.5
		var re := center + Vector2(4.2, eye_y - center.y) + face_offset * 0.5
		if alert:
			# ALERTA: olhos VERMELHOS agressivos a mirar o jogador
			var p_pos_w := _player_visual_position()
			var to_pl_l := (p_pos_w - le).normalized() * 1.4
			var to_pl_r := (p_pos_w - re).normalized() * 1.4
			# Halo vermelho ao redor dos olhos
			draw_circle(le, 3.2, Color("ff1010", 0.50))
			draw_circle(re, 3.2, Color("ff1010", 0.50))
			# Olhos semicerrados agressivos vermelhos
			draw_line(le + Vector2(-2.5, 1), le + Vector2(2.5, -1), Color("ff1020"), 2.2, true)
			draw_line(re + Vector2(-2.5, -1), re + Vector2(2.5, 1), Color("ff1020"), 2.2, true)
			draw_circle(le + to_pl_l, 1.2, Color("ff3040"))
			draw_circle(re + to_pl_r, 1.2, Color("ff3040"))
		else:
			# CALMO: olhinhos digitais felizes ( ^  ^ )
			draw_arc(le, 2.4, PI + 0.3, TAU - 0.3, 12, Color("ffffff"), 1.8, true)
			draw_arc(re, 2.4, PI + 0.3, TAU - 0.3, 12, Color("ffffff"), 1.8, true)
		return

	if role == "rusher":
		# RUSHER: Predador Supersónico / Fera Magmática (Asas Delta de Fogo, Afterburner, Lança Agressiva)
		var f_dir := Vector2(face)
		if f_dir.length_squared() < 0.1:
			f_dir = Vector2.RIGHT
		var perp := Vector2(-f_dir.y, f_dir.x)
		
		# 1. Chamas do Afterburner traseiro pulsantes
		var flame_len := (half_size * 0.85 + sin(animation_clock * 25.0) * 5.0)
		var thruster_pts := PackedVector2Array([
			center - f_dir * (half_size * 0.3) + perp * 4,
			center - f_dir * (half_size * 0.3) - perp * 4,
			center - f_dir * (half_size * 0.3 + flame_len)
		])
		draw_colored_polygon(thruster_pts, Color("ff4800", 0.90))
		draw_colored_polygon(PackedVector2Array([
			center - f_dir * (half_size * 0.3) + perp * 2,
			center - f_dir * (half_size * 0.3) - perp * 2,
			center - f_dir * (half_size * 0.3 + flame_len * 0.6)
		]), Color("ffee55", 0.95))
		
		# 2. Carapaça de ataque em asa delta obsidian + magma
		var nose := center + f_dir * (half_size * 1.3)
		var wing_l := center - f_dir * (half_size * 0.55) + perp * (half_size * 1.1)
		var wing_r := center - f_dir * (half_size * 0.55) - perp * (half_size * 1.1)
		var tail_notch := center - f_dir * (half_size * 0.3)
		
		# Casco exterior escuro
		var hull_poly := PackedVector2Array([nose, wing_l, tail_notch, wing_r])
		draw_colored_polygon(hull_poly, Color("201006"))
		
		# Blindagem interna magmática laranja-dourada
		var inner_poly := PackedVector2Array([
			nose - f_dir * 3.0,
			wing_l + f_dir * 3.0 - perp * 2.5,
			tail_notch + f_dir * 2.0,
			wing_r + f_dir * 3.0 + perp * 2.5
		])
		draw_colored_polygon(inner_poly, Color("ff771a"))
		var inner_outline := inner_poly.duplicate()
		inner_outline.append(inner_poly[0])
		draw_polyline(inner_outline, Color("ffd043"), 1.2, true)
		
		# 3. Núcleo afiado central + sensor de mira
		if alert:
			# Alert stays in the core and thruster; no projected speed lines.
			draw_circle(center + f_dir * 3, 4.0, Color("ff0020", 0.60))
			draw_circle(center + f_dir * 3, 3.2, Color("ffffff"))
			draw_circle(center + f_dir * 3, 2.0, Color("ff2020"))
			# Ponto de mira do sensor
			var p_pos_r := _player_visual_position()
			var to_p := (p_pos_r - center).normalized()
			draw_circle(center + to_p * 6.0, 2.5, Color("ff1010", 0.85))
			draw_circle(center + to_p * 6.0, 1.0, Color("ffffff"))
		else:
			draw_circle(center + f_dir * 3, 3.2, Color("ffffff"))
			draw_circle(center + f_dir * 3, 2.0, Color("ff3300"))
		return

	if role == "warden":
		# WARDEN: mini-chefe original (Gólem Mecha Violeta, Fagulhas Orbitais, Reator de Fusão Central)
		# 1. Ombros / Punhos flutuantes pesados à esquerda e direita
		var hand_bob := sin(animation_clock * 4.0) * 2.5
		var hand_l := center + Vector2(-half_size * 1.35, hand_bob)
		var hand_r := center + Vector2(half_size * 1.35, -hand_bob)
		draw_circle(hand_l, 6.5, Color("1f0d36"))
		draw_circle(hand_l, 5.0, Color("8024c7"))
		draw_circle(hand_r, 6.5, Color("1f0d36"))
		draw_circle(hand_r, 5.0, Color("8024c7"))
		
		# 2. Chassi do peitoral maciço chanfrado em titânio púrpura
		var body_outer := _chamfered_square_points(center, half_size * 1.05, half_size * 0.35)
		draw_colored_polygon(body_outer, Color("140824"))
		var body_plate := _chamfered_square_points(center, half_size * 0.90, half_size * 0.30)
		draw_colored_polygon(body_plate, Color("7b1ec7"))
		var body_rim := body_plate.duplicate()
		body_rim.append(body_plate[0])
		draw_polyline(body_rim, Color("c96eff"), 1.5, true)
		
		# 3. Drones orbitais espiculados com conexão de raio
		var drone_speed := 3.8 if alert else 1.6
		var drone_col := Color("ff5050") if alert else Color("f49aff")
		var drone_line_col := Color("ff2020", 0.50) if alert else Color("c25eff", 0.35)
		for s in 4:
			var s_ang := animation_clock * drone_speed + float(s) * TAU / 4.0
			var s_pos := center + Vector2(cos(s_ang), sin(s_ang)) * (half_size * 1.45)
			draw_circle(s_pos, 3.5, drone_col)
			draw_circle(s_pos, 1.5, Color("ffffff"))
			draw_line(center, s_pos, drone_line_col, 1.0, true)
			
		# 4. Anel de contenção gravitacional
		draw_arc(center, half_size * 1.25, animation_clock * 3.5, animation_clock * 3.5 + TAU * 0.7, 24, Color("f1b5ff", 0.7), 2.0, true)
		
		# 5. Núcleo do Reator de Fusão central (olho estelar)
		var core_p := 1.0 + sin(animation_clock * 9.0) * 0.22
		if alert:
			# Alert is readable on the Warden's own reactor and orbiting drones.
			draw_circle(center, 7.5 * core_p, Color("ff0020", 0.55))
			draw_circle(center, 5.0 * core_p, Color("ffffff"))
			draw_circle(center, 3.0 * core_p, Color("ff1530"))

		else:
			draw_circle(center, 7.5 * core_p, Color("c25eff", 0.45))
			draw_circle(center, 5.0 * core_p, Color("ffffff"))
			draw_circle(center, 3.0 * core_p, Color("ef75ff"))
		return

	# Fallback para outros mobs
	var fallback_shell := _chamfered_square_points(center, half_size, half_size * 0.22)
	draw_colored_polygon(fallback_shell, Color("1a1424"))
	var fallback_inner := _chamfered_square_points(center, half_size * 0.85, half_size * 0.20)
	draw_colored_polygon(fallback_inner, Color("ff3355"))
	draw_circle(center + face_offset, 3.0, Color("ffffff"))
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
	var moving: bool = player_anim < 1.0 and (not _player_motion_fields_match() or player_motion.kind != "hold")
	var movement := sin(clampf(player_anim, 0.0, 1.0) * PI) if moving else 0.0
	var roll := player_roll_angle
	var hop_height := 8.0 if player_motion.kind == "jump" else 1.2 if player_motion.kind in ["ice", "current"] else 3.2
	var hop := movement * hop_height
	if game_state == "captured":
		var inflation := clampf(capture_time / CAPTURE_POP_TIME, 0.0, 1.0)
		size_scale = 1.0 + 0.78 * smoothstep(0.0, 1.0, inflation)
		stretch = Vector2(1.0 + inflation * 0.04, 1.0 - inflation * 0.025)
		if inflation > 0.3 and int(capture_time * 26.0) % 2 == 0:
			visibility = 0.3
	else:
		var block := sin((1.0 - clampf(blocked_feedback_time / 0.16, 0.0, 1.0)) * PI) if blocked_feedback_time > 0.0 else 0.0
		var attack_phase := 1.0 - clampf(attack_feedback_time / 0.26, 0.0, 1.0)
		var windup := 0.0
		var attack := 0.0
		if attack_feedback_time > 0.0:
			windup = sin(clampf(attack_phase / 0.17, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.17, 0.28, attack_phase))
			attack = smoothstep(0.12, 0.27, attack_phase) * (1.0 - smoothstep(0.34, 0.90, attack_phase))
		var impact := clampf(impact_feedback_time / 0.20, 0.0, 1.0)
		var shield_reaction := player_impact_kind == "shield"
		center += blocked_feedback_direction * (block * 2.8)
		center += Vector2(facing) * (attack * 6.0 - windup * 2.5)
		center += player_impact_direction * impact * (2.2 if shield_reaction else 5.0)
		var push := movement if moving and player_motion.kind == "push" else 0.0
		# The cell centers remain exactly aligned with the crate track, while
		# the visible body leans in to bridge the sprites' empty margins.
		center += player_visual_direction * push * 9.0
		# Anticipate, compress at contact, then recover. Damage and shield have
		# different weight; none of these offsets alter the player's grid cell.
		var along := 1.0 + movement * 0.10 - push * 0.15 - block * 0.10 + attack * 0.08 - windup * 0.07 - impact * (0.07 if shield_reaction else 0.15)
		var across := 1.0 - movement * 0.065 + push * 0.10 + block * 0.065 - attack * 0.05 + windup * 0.04 + impact * (0.04 if shield_reaction else 0.10)
		var pose_direction := player_impact_direction if impact > 0.0 else blocked_feedback_direction if block > 0.0 else Vector2(facing) if attack > 0.0 or windup > 0.0 else player_visual_direction
		stretch = Vector2(along, across) if absf(pose_direction.x) >= absf(pose_direction.y) else Vector2(across, along)
		var landing := clampf(landing_feedback_time / 0.12, 0.0, 1.0)
		stretch *= Vector2(1.0 + landing * 0.06, 1.0 - landing * 0.05)
		hop += sin(animation_clock * 7.0) * 0.5
	if moving and player_motion.kind == "ice" and game_state != "captured":
		var behind := center - player_visual_direction * 15.0
		draw_line(behind, behind - player_visual_direction * (7.0 + movement * 5.0), Color("c6f3ff", 0.25 * movement), 1.3, true)
	if threat_aura > 0.01 and game_state == "playing":
		var pulse := 1.0 + 0.05 * sin(animation_clock * 5.0)
		draw_arc(center, 21.0 * pulse, 0.0, TAU, 32, Color("ff6a71", threat_aura * 0.22), 1.4, true)
	var shadow_color := Color("00040d", (0.36 + threat_aura * 0.10) * visibility)
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
	# Esfera 3D Volumétrica da Bola Vermelha
	var bob := sin(animation_clock * 8.5) * 0.6
	var sphere_pos := center + Vector2(0, bob - hop)
	# Keep the baked light fixed in world/screen space; rotating the entire
	# lit texture made the highlight orbit the ball on every step. Deformation
	# still follows the real movement and contact axes.
	var body_transform := Transform2D(0.0, stretch * size_scale, 0.0, sphere_pos)
	draw_set_transform_matrix(body_transform)
	if player_sphere_texture != null:
		var diameter := 32.0
		var tex_rect := Rect2(-diameter * 0.5, -diameter * 0.5, diameter, diameter)
		draw_texture_rect(player_sphere_texture, tex_rect, false, Color(1, 1, 1, visibility))
	else:
		draw_circle(Vector2.ZERO, 15.5, Color("e01b3c", visibility))
	if moving and game_state != "captured":
		# A faint projected surface seam can roll without moving the light. Its
		# axis follows the travelled direction; it is not an arrow or a preview.
		var axis := Vector2.RIGHT if absf(player_visual_direction.x) >= absf(player_visual_direction.y) else Vector2.DOWN
		var side := Vector2(-axis.y, axis.x)
		var offset := sin(roll) * 10.5
		var half_width := 10.2 * sqrt(maxf(0.0, 1.0 - offset * offset / 196.0))
		var seam := PackedVector2Array()
		for index in 9:
			var across := float(index) / 4.0 - 1.0
			seam.append(axis * (offset + cos(roll) * (1.0 - across * across) * 1.7) + side * (across * half_width))
		draw_polyline(seam, Color("63142d", 0.18 * movement * visibility), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	_draw_orb_face(center, size_scale, facing, frightened, visibility, hop, bob, moving)


func _draw_orb_face(center: Vector2, size_scale: float, face_direction: Vector2i, frightened: bool, visibility: float, hop: float, bob: float, moving: bool = false, lia_palette: bool = false) -> void:
	# Olhos cibernéticos expressivos
	var eye_offset := Vector2(face_direction) * (2.0 * size_scale)
	var eye_y := -2.6 - hop + bob
	var eye_radius := 4.0 if frightened else 3.3
	var eye_left := center + Vector2(-5.1, eye_y) * size_scale + eye_offset
	var eye_right := center + Vector2(5.1, eye_y) * size_scale + eye_offset
	var face_visibility := visibility
	var sclera := Color("fff5e6", face_visibility)
	var pupil := Color("2a0814", face_visibility)
	
	var gaze := Vector2(face_direction) * (1.05 if frightened else 0.72) * size_scale
	if frightened:
		# Tremor de pânico nos olhos
		var panic_jitter := Vector2(sin(animation_clock * 32.0), cos(animation_clock * 28.0)) * (0.6 * size_scale)
		# Esclera branca bem nítida e ampla
		draw_circle(eye_left + panic_jitter, 4.3 * size_scale, Color("ffffff", face_visibility))
		draw_circle(eye_right + panic_jitter, 4.3 * size_scale, Color("ffffff", face_visibility))
		# Pupilas contraídas de medo que tremem
		draw_circle(eye_left + gaze * 0.4 + panic_jitter, 1.4 * size_scale, Color("140208", face_visibility))
		draw_circle(eye_right + gaze * 0.4 + panic_jitter, 1.4 * size_scale, Color("140208", face_visibility))
		# Ponto de reflexo especular na pupila
		draw_circle(eye_left + panic_jitter + Vector2(-0.8, -0.8), 0.7 * size_scale, Color("ffffff", face_visibility))
		draw_circle(eye_right + panic_jitter + Vector2(-0.8, -0.8), 0.7 * size_scale, Color("ffffff", face_visibility))
		
		# Sobrancelhas levantadas em ângulo de aflição ( \   / )
		draw_line(eye_left + Vector2(-3.2, -6.2) * size_scale, eye_left + Vector2(2.5, -4.5) * size_scale, Color("381541" if lia_palette else "521426", visibility), 1.8 * size_scale, true)
		draw_line(eye_right + Vector2(-2.5, -4.5) * size_scale, eye_right + Vector2(3.2, -6.2) * size_scale, Color("381541" if lia_palette else "521426", visibility), 1.8 * size_scale, true)
		
		# Boca aberta de espanto (elipse vertical com fundo escuro e dentes/grito)
		var mouth_pos := center + Vector2(0.0, 6.2 - hop + bob) * size_scale
		draw_circle(mouth_pos, (2.6 + sin(animation_clock * 14.0) * 0.4) * size_scale, Color("3b174b" if lia_palette else "4a0f1d", visibility))
		draw_circle(mouth_pos + Vector2(0, 0.8), 1.2 * size_scale, Color("ffb0f4" if lia_palette else "ff8aa5", visibility * 0.8))
		
		# Gota de suor ciano de pânico no lado da cabeça
		var sweat_pos := center + Vector2(10.5 * size_scale, (-5.5 - hop + bob + sin(animation_clock * 10.0) * 1.0) * size_scale)
		var sweat_pts := PackedVector2Array([
			sweat_pos + Vector2(0, -3.2 * size_scale),
			sweat_pos + Vector2(2.2 * size_scale, 1.8 * size_scale),
			sweat_pos + Vector2(-2.2 * size_scale, 1.8 * size_scale)
		])
		draw_colored_polygon(sweat_pts, Color("ff9cf0" if lia_palette else "7ae7ff", visibility * 0.95))
		draw_circle(sweat_pos + Vector2(0, 1.6 * size_scale), 2.2 * size_scale, Color("ff9cf0" if lia_palette else "7ae7ff", visibility * 0.95))
		draw_circle(sweat_pos + Vector2(-0.7, 0.8) * size_scale, 0.8 * size_scale, Color("ffffff", visibility))
	else:
		# A brief deterministic idle blink adds life without consuming game RNG.
		var blink_phase := fposmod(animation_clock, 4.8)
		var blinking := not moving and blink_phase > 4.61 and blink_phase < 4.72
		if blinking:
			draw_line(eye_left + Vector2(-2.7, 0) * size_scale, eye_left + Vector2(2.7, 0) * size_scale, sclera, 1.5 * size_scale, true)
			draw_line(eye_right + Vector2(-2.7, 0) * size_scale, eye_right + Vector2(2.7, 0) * size_scale, sclera, 1.5 * size_scale, true)
		else:
			draw_circle(eye_left, eye_radius * size_scale, sclera)
			draw_circle(eye_right, eye_radius * size_scale, sclera)
			draw_circle(eye_left + gaze, 1.45 * size_scale, pupil)
			draw_circle(eye_right + gaze, 1.45 * size_scale, pupil)
			# Ponto especular na pupila
			draw_circle(eye_left + gaze + Vector2(-0.5, -0.5), 0.6 * size_scale, Color("ffffff", face_visibility))
			draw_circle(eye_right + gaze + Vector2(-0.5, -0.5), 0.6 * size_scale, Color("ffffff", face_visibility))
		draw_arc(center + Vector2(0, 4.5 - hop + bob) * size_scale, 3.0 * size_scale, 0.15, PI - 0.15, 16, Color("61296d" if lia_palette else "78243e", visibility), 1.3 * size_scale, true)


func _draw_blood_puddle(target: CanvasItem) -> void:
	if not capture_puddle_active or capture_puddle_points.size() < 3:
		return
	# Sombra profunda sob a poça
	var shadow_outline := PackedVector2Array()
	for point in capture_puddle_points:
		shadow_outline.append(point + Vector2(0, 3.5))
	target.draw_colored_polygon(shadow_outline, Color("000000", 0.45))
	
	# Camada viscosa base
	target.draw_colored_polygon(capture_puddle_points, Color("590519", 0.98))
	
	# Camada interna arterial
	var inset := PackedVector2Array()
	for point in capture_puddle_points:
		inset.append(capture_origin + (point - capture_origin) * 0.74)
	target.draw_colored_polygon(inset, Color("a10b2a", 0.95))
	
	# Centro líquido reflexivo
	var center_inset := PackedVector2Array()
	for point in capture_puddle_points:
		center_inset.append(capture_origin + (point - capture_origin) * 0.48)
	target.draw_colored_polygon(center_inset, Color("c91638", 0.90))
	
	# Reflexos especulares de líquido fresco
	var spec1 := capture_origin + Vector2(-CELL * 0.35, -CELL * 0.28)
	target.draw_circle(spec1, 4.2, Color("ffffff", 0.65))
	target.draw_circle(spec1 + Vector2(7, 2), 2.2, Color("ffffff", 0.45))
	
	# Contorno neon arterial pulsante
	var outline := capture_puddle_points.duplicate()
	outline.append(capture_puddle_points[0])
	target.draw_polyline(outline, Color("ff365c", 0.88), 2.4, true)
	
	# Gotículas e respingos periféricos com mini-brilho
	for splat in capture_splats:
		target.draw_circle(splat.pos + Vector2(0, 1.5), splat.radius, Color("000000", 0.35))
		target.draw_circle(splat.pos, splat.radius, Color("ab0c2e", 0.96))
		target.draw_circle(splat.pos + Vector2(-splat.radius * 0.25, -splat.radius * 0.25), maxf(1.0, splat.radius * 0.35), Color("ff6379", 0.85))


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
