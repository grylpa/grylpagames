extends CanvasLayer

class TimerArc extends Node2D:
	var progress: float = 1.0
	var radius: float = 20.0
	var width: float = 2.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.1, 0.1, 0.1, 0.4), width)
		if progress <= 0.0:
			return
		var arc_end: float = -PI * 0.5 + progress * TAU
		var col: Color = Color(0.3, 0.85, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.2, 1.0), 1.0 - progress)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, 64, col, width)

var game: GenericGameUtil = null

# 8 directions: up, down, left, right, TL, TR, BL, BR
const DIR_POSITIONS: Array = [
	Vector2i(3, 0),  # 0: up
	Vector2i(3, 6),  # 1: down
	Vector2i(0, 3),  # 2: left
	Vector2i(6, 3),  # 3: right
	Vector2i(0, 0),  # 4: TL
	Vector2i(6, 0),  # 5: TR
	Vector2i(0, 6),  # 6: BL
	Vector2i(6, 6),  # 7: BR
]

var level: int = 1
var _center_ms: int = 700
var _periph_ms: int = 200
var _num_same: int = 2
var _num_options: int = 2
var _two_colors: bool = false
var _same_color_alts: bool = false
var _num_corrects_for_next_level: int = 5
var _time_to_consider_fail_ms: int = 5000

var num_corrects_in_level_so_far: int = 0
var _times_to_answer: Array = []

# Model and periph flash state
var _model_agent: Area2D = null
var _periph_agent: Area2D = null
var _model_done: bool = false
var _periph_done: bool = false
var _need_to_show_model: bool = false
var _time_to_show_model_ms: float = 0.0
var _need_to_show_periph: bool = false
var _time_to_show_periph_ms: float = 0.0
var _pending_answer_at_ms: float = -1.0

# Answer stage state
var _answer_active: bool = false
var _answer_agents: Array = []
var _answer_start_game_time: float = 0.0
var _answer_start_real_time: float = 0.0

# Current round's model shape/color (periph uses same)
var _round_model_texture_idx: int = 0
var _round_model_color: Array = []
var _periph_dir_idx: int = -1

# Circular timeout indicator
var _timer_arc: TimerArc = null

# Camera
var _agent_cam: Camera2D = null

signal started_playing
signal sig_level_is_done(didwin: bool)

@export var agent_scene: PackedScene = load("res://didi/scenes/agent.tscn")

var dispatch_audio: AudioStream = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio: AudioStream = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio: AudioStream = preload("res://art/sounds/swoosh.mp3")

var ambient_audios: Array = [
	preload("res://art/sounds/ocean-waves-2.mp3"),
	preload("res://art/sounds/ocean-waves-3.mp3"),
	preload("res://art/sounds/ocean-waves-4.mp3"),
]

func _ready() -> void:
	game = DidiG.game
	game.sig_time_over.connect(on_time_over)
	level = DidiG.starting_level
	_load_cfg(false)
	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	_timer_arc = TimerArc.new()
	_timer_arc.z_index = 10
	_timer_arc.hide()
	add_child(_timer_arc)
	_create_camera()

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		game.level_is_ready = true
		started_playing.emit()
		_schedule_next_round(500.0)

func new_game(from_scratch: bool = true) -> void:
	_clear_round_state()
	game.level_is_ready = false
	game.level_is_done = false
	num_corrects_in_level_so_far = 0
	if from_scratch:
		level = DidiG.starting_level
		_times_to_answer.clear()
	_load_cfg(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")
	var lvl: Dictionary = DidiLevelConfig.get_level(level)
	game.show_game_popup(self, "Level %d" % level,
		"Center: %d ms\nPeriph flash: %d ms\nTimeout: %.1f s\nRounds: %d" % [
			lvl["center_ms"], lvl["periph_ms"],
			float(lvl["time_to_consider_fail"]) / 1000.0, lvl["rounds"]])

func _load_cfg(increase: bool = false) -> void:
	if increase:
		level = min(level + 1, DidiLevelConfig.MAX_LEVEL)
	level = clamp(level, 1, DidiLevelConfig.MAX_LEVEL)
	var s: int = 7
	game.max_board_size = Vector2i(s, s)
	game.forced_board_size = Vector2i(s, s)
	game.init_sizes()
	var lvl: Dictionary = DidiLevelConfig.get_level(level)
	_center_ms = lvl["center_ms"]
	_periph_ms = lvl["periph_ms"]
	_num_same = lvl["num_same"]
	_two_colors = lvl["two_colors"]
	_same_color_alts = lvl["same_color_alts"]
	_num_options = lvl["num_options"]
	_num_corrects_for_next_level = lvl["rounds"]
	_time_to_consider_fail_ms = lvl["time_to_consider_fail"]

func _clear_round_state() -> void:
	_answer_active = false
	if _timer_arc != null:
		_timer_arc.hide()
	_clear_answer_agents()
	if _model_agent != null and is_instance_valid(_model_agent):
		_model_agent.queue_free()
	_model_agent = null
	if _periph_agent != null and is_instance_valid(_periph_agent):
		_periph_agent.queue_free()
	_periph_agent = null
	_model_done = false
	_periph_done = false
	_pending_answer_at_ms = -1.0
	_need_to_show_model = false
	_need_to_show_periph = false

func _schedule_next_round(delay_ms: float) -> void:
	_model_done = false
	_periph_done = false
	_pending_answer_at_ms = -1.0
	_time_to_show_model_ms = game.game_time + delay_ms
	_need_to_show_model = true

func _process(_delta: float) -> void:
	if game.level_is_done:
		return
	# Update circular arc timer continuously (real time for smooth animation)
	if _answer_active and _timer_arc != null and _timer_arc.visible:
		var elapsed_sec: float = Time.get_unix_time_from_system() - _answer_start_real_time
		var timeout_sec: float = float(_time_to_consider_fail_ms) / 1000.0
		_timer_arc.progress = 1.0 - clamp(elapsed_sec / timeout_sec, 0.0, 1.0)
		_timer_arc.queue_redraw()
	if game.paused() or not game.level_is_ready:
		return
	if _need_to_show_model and game.game_time >= _time_to_show_model_ms:
		_need_to_show_model = false
		_spawn_model()
	if _need_to_show_periph and game.game_time >= _time_to_show_periph_ms:
		_need_to_show_periph = false
		_spawn_periph_flash()
	if _pending_answer_at_ms >= 0.0 and game.game_time >= _pending_answer_at_ms:
		_pending_answer_at_ms = -1.0
		_dispatch_answer_stage()
	if _answer_active and game.game_time >= _answer_start_game_time + float(_time_to_consider_fail_ms):
		_on_answer_timeout()

func _spawn_model() -> void:
	if _model_agent != null and is_instance_valid(_model_agent):
		_model_agent.queue_free()
	var center: Vector2i = Vector2i(3, 3)
	_model_done = false
	var agent: Area2D = agent_scene.instantiate()
	agent.time_to_hide_ms = float(_center_ms)
	agent.is_model = true
	agent.is_correct = false
	agent.board_pos = center
	add_child(agent)
	var use_two_colors: bool = _two_colors and game.rng.randi() % 2 == 0
	if use_two_colors:
		_round_model_color = [game.next_color(), game.next_color()]
	else:
		var c: Color = game.next_color()
		_round_model_color = [c, c]
	_round_model_texture_idx = agent.set_rand_texture()
	agent.set_pos(game.board_to_px(center), 0)
	agent.set_colors(_round_model_color)
	agent.need_to_remove_agent.connect(_on_model_removed)
	_model_agent = agent
	game.play_sound("dispatch")
	# Schedule periph flash shortly after model appears
	_need_to_show_periph = true
	_time_to_show_periph_ms = game.game_time + 150.0

func _on_model_removed(_agent) -> void:
	if is_instance_valid(_agent):
		_agent.queue_free()
	_model_agent = null
	_model_done = true
	_maybe_start_answer()

func _spawn_periph_flash() -> void:
	_periph_dir_idx = game.rng.randi() % 8
	var center_px: Vector2 = game.board_to_px(Vector2i(3, 3))
	var edge_px: Vector2 = game.board_to_px(DIR_POSITIONS[_periph_dir_idx])
	var t: float = game.rng.randf_range(0.8, 1.0)
	var flash_px: Vector2 = center_px.lerp(edge_px, t)
	var agent: Area2D = agent_scene.instantiate()
	agent.time_to_hide_ms = float(_periph_ms)
	agent.is_model = false
	agent.is_correct = false
	agent.board_pos = DIR_POSITIONS[_periph_dir_idx]
	add_child(agent)
	agent.set_pos(flash_px, 0)
	# Periph uses a random shape/color (like DDOOO) so the center flash is needed
	# to know the shape, and the periph flash is only used for position memory
	agent.set_rand_texture()
	var c: Color = game.next_color()
	agent.set_colors([c, c])
	agent.scale *= 0.55
	agent.need_to_remove_agent.connect(func(_a):
		if is_instance_valid(_a):
			_a.queue_free()
		_periph_agent = null
		_periph_done = true
		_maybe_start_answer()
	)
	_periph_agent = agent

func _maybe_start_answer() -> void:
	if _model_done and _periph_done and _pending_answer_at_ms < 0.0 and not _answer_active:
		_pending_answer_at_ms = game.game_time + 300.0

func _dispatch_answer_stage() -> void:
	if game.paused() or game.level_is_done or _answer_active:
		return
	_answer_active = true
	_answer_start_game_time = game.game_time
	_answer_start_real_time = Time.get_unix_time_from_system()
	_clear_answer_agents()

	# Decide which direction clusters get the correct shape.
	# periph_dir_idx always gets one; fill remaining from random others.
	var correct_shape_dirs: Array = [_periph_dir_idx]
	var other_dirs: Array = []
	for i in 8:
		if i != _periph_dir_idx:
			other_dirs.append(i)
	other_dirs.shuffle()
	var extra: int = min(_num_same - 1, other_dirs.size())
	for i in range(extra):
		correct_shape_dirs.append(other_dirs[i])

	for dir_idx in 8:
		var has_correct_shape: bool = dir_idx in correct_shape_dirs
		_spawn_answer_cluster(dir_idx, has_correct_shape)

	_timer_arc.position = game.board_to_px(Vector2i(3, 3))
	_timer_arc.radius = game.tile_size * 0.25
	_timer_arc.progress = 1.0
	_timer_arc.show()
	_timer_arc.queue_redraw()

# Returns world-space positions for each sub-agent in the cluster at dir_idx.
# num_opts=2: pair perpendicular to inward axis; cardinals spread wider to align
#             their option centers with adjacent corner option centers.
# num_opts=3: triangle — one outer (away from center) + two inner flanking it.
# num_opts=4: corners → diamond (outer/inner/left/right);
#             cardinals → 2×2 grid (outer-L, outer-R, inner-L, inner-R).
func _get_cluster_positions(dir_idx: int, num_opts: int) -> Array:
	var is_corner: bool = dir_idx >= 4
	var center_px: Vector2 = game.board_to_px(Vector2i(3, 3))
	var edge_px: Vector2 = game.board_to_px(DIR_POSITIONS[dir_idx])
	var option_rad_s = 0.65 if is_corner else 0.8
	if num_opts == 2:
		option_rad_s = 0.68 if is_corner else 0.88
	var base_px: Vector2 = center_px.lerp(edge_px, option_rad_s)
	var inward: Vector2 = (center_px - edge_px).normalized()
	var perp: Vector2 = Vector2(-inward.y, inward.x)
	var t: float = float(game.tile_size)
	# s_corner is the baseline spacing for corner clusters and drives
	# the cardinal alignment formula.
	var s_corner: float = t * 0.56
	match num_opts:
		2:
			var s: float = 0.75		# how close the cluster elements are to each other
			return [base_px - perp * s_corner * s, base_px + perp * s_corner * s]
		3:
			# var s: float = t * (0.62 if is_corner else 0.62)
			var s: float = t * 0.62
			return [
				base_px - inward * (s * 0.55),
				base_px + inward * (s * 0.4) - perp * (s * 0.6),
				base_px + inward * (s * 0.4) + perp * (s * 0.6),
			]
		4:
			var s: float = t * 0.5
			if is_corner:
				# Screen-space diamond (N/S/E/W), same radius as the cardinal grid
				return [
					base_px + Vector2(0.0, -s),
					base_px + Vector2(0.0,  s),
					base_px + Vector2(-s, 0.0),
					base_px + Vector2( s, 0.0),
				]
			else:
				# 2×2 grid matching corner spacing: each point s/√2 away in each axis
				var d: float = s / sqrt(2.0)
				return [
					base_px - inward * d - perp * d,
					base_px - inward * d + perp * d,
					base_px + inward * d - perp * d,
					base_px + inward * d + perp * d,
				]
	return [base_px]

func _cluster_agent_scale(dir_idx: int, num_opts: int) -> float:
	var is_corner: bool = dir_idx >= 4
	match num_opts:
		2: return 0.22 if is_corner else 0.22
		3: return 0.18 if is_corner else 0.18
		4: return 0.18 if is_corner else 0.18
		_: return 0.18

func _spawn_answer_cluster(dir_idx: int, has_correct_shape: bool) -> void:
	var positions: Array = _get_cluster_positions(dir_idx, _num_options)
	var cluster_scale: float = _cluster_agent_scale(dir_idx, _num_options)
	# Randomly pick which sub-slot within this cluster gets the correct shape
	var correct_sub: int = game.rng.randi() % positions.size()
	for sub_idx in positions.size():
		var px: Vector2 = positions[sub_idx]
		var this_correct_shape: bool = has_correct_shape and sub_idx == correct_sub
		var this_true_correct: bool = this_correct_shape and dir_idx == _periph_dir_idx
		var agent: Area2D = agent_scene.instantiate()
		agent.time_to_hide_ms = 999999.0
		agent.is_model = false
		agent.is_correct = this_true_correct
		agent.is_correct_shape = this_correct_shape
		agent.is_correct_direction = (dir_idx == _periph_dir_idx)
		agent.board_pos = DIR_POSITIONS[dir_idx]
		add_child(agent)
		agent.scale = Vector2(cluster_scale, cluster_scale)
		agent.set_pos(px, 0)
		if this_correct_shape:
			agent.set_texture(_round_model_texture_idx)
			agent.set_colors(_round_model_color.duplicate(true))
		else:
			agent.set_rand_texture(_round_model_texture_idx)
			if _same_color_alts:
				agent.set_colors(_round_model_color.duplicate(true))
			else:
				var c: Color = game.next_color()
				agent.set_colors([c, c])
		agent.agent_pressed.connect(func(_a): _on_answer_agent_pressed(_a))
		_answer_agents.append(agent)

func _on_answer_agent_pressed(agent) -> void:
	if not _answer_active or game.paused() or game.level_is_done:
		return
	var elapsed_ms: float = game.game_time - _answer_start_game_time
	var board_pos: Vector2i = agent.board_pos

	if agent.is_correct:
		var score_to_add: int = max(1, int(10 - elapsed_ms / 300.0))
		_add_time_to_answer_ms(int(elapsed_ms))
		game.add_score_and_time(score_to_add, 15)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("delivery")
		_flash_at(board_pos, true)
		_show_score_popup(board_pos, "+" + str(score_to_add), true)
		num_corrects_in_level_so_far += 1
	elif agent.is_correct_direction:
		# Correct direction, wrong shape — partial credit
		game.add_score_and_time(1, 5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_flash_at(board_pos, false)
		_show_score_popup(board_pos, "+1", false)
	elif agent.is_correct_shape:
		# Correct shape, wrong direction — partial credit
		game.add_score_and_time(1, 5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_flash_at(board_pos, false)
		_show_score_popup(board_pos, "+1", false)
	else:
		# Decoy
		game.add_score_and_time(-1, -5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_flash_at(board_pos, false)
		_show_score_popup(board_pos, "-1", false)

	_end_answer_stage()

	if agent.is_correct and num_corrects_in_level_so_far >= _num_corrects_for_next_level:
		_level_done(true)
		return
	_schedule_next_round(500.0)

func _on_answer_timeout() -> void:
	if not _answer_active:
		return
	game.add_score_and_time(-1, -5)
	game.add_correct_or_mistake(0, 1)
	game.play_sound("swoosh")
	_end_answer_stage()
	_schedule_next_round(500.0)

func _end_answer_stage() -> void:
	_answer_active = false
	if _timer_arc != null:
		_timer_arc.hide()
	_clear_answer_agents()

func _clear_answer_agents() -> void:
	for a in _answer_agents:
		if is_instance_valid(a):
			a.queue_free()
	_answer_agents.clear()

func on_time_over() -> void:
	game.stop_sound("ambient")

func tick() -> void:
	pass

func _level_done(didwin: bool) -> void:
	game.level_is_done = true
	game.sig_level_is_done.emit(didwin)
	game.stop_sound("ambient")
	if didwin:
		MainGlobals.global_level_is_done(true)
		if level >= DidiLevelConfig.MAX_LEVEL:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = true
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd: String = "\n\nAverage time: %d ms" % mean_time_to_answer_ms()
			game.show_level_done_popup(self, "", "", level, textadd)
	else:
		sig_level_is_done.emit(didwin)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

const FEEDBACK_OK_TEXT_COLOR: Color = Color(0.3, 1.0, 0.3)
const FEEDBACK_BAD_TEXT_COLOR: Color = Color(1.0, 0.4, 0.4)

func _flash_at(board_pos: Vector2i, is_correct: bool) -> void:
	var rect: ColorRect = ColorRect.new()
	var col: Color = Color(0.0, 0.9, 0.0, 0.55) if is_correct else Color(0.9, 0.0, 0.0, 0.55)
	rect.color = col
	var sz: float = float(game.tile_size) * 1.1
	rect.size = Vector2(sz, sz)
	rect.position = game.board_to_px(board_pos) - Vector2(sz * 0.5, sz * 0.5)
	rect.z_index = 5
	add_child(rect)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.35)
	tween.tween_callback(rect.queue_free)

func _show_score_popup(board_pos: Vector2i, text: String, is_correct: bool) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color",
		FEEDBACK_OK_TEXT_COLOR if is_correct else FEEDBACK_BAD_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(game.tile_size * 3, 0)
	var px: Vector2 = game.board_to_px(board_pos)
	label.position = px - Vector2(game.tile_size * 1.5, game.tile_size * 0.5)
	label.z_index = 10
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", px.y - game.tile_size * 2.5, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(label.queue_free)

func mean_time_to_answer_ms() -> int:
	var N: int = _times_to_answer.size()
	if N == 0:
		return _time_to_consider_fail_ms
	var s: int = 0
	for t in _times_to_answer:
		s += t
	return roundi(float(s) / float(N))

func _add_time_to_answer_ms(t_ms: int) -> void:
	if t_ms <= 0:
		return
	_times_to_answer.append(t_ms)
	while _times_to_answer.size() > 10:
		_times_to_answer.remove_at(0)

func _create_camera() -> void:
	follow_viewport_enabled = true
	if _agent_cam == null:
		_agent_cam = Camera2D.new()
		add_child(_agent_cam)
	_agent_cam.make_current()
	_agent_cam.zoom = Vector2(
		min(6.0, 1.0 / game.get_board_part_of_width()),
		min(6.0, 1.0 / game.get_board_part_of_width()))
	_agent_cam.enabled = true
	_agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	_agent_cam.set_offset(game.board_to_px(Vector2i(3, 3)))
