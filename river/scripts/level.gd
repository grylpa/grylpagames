extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

const CHAR_X_FRAC: float = 0.25
const CHANNEL_HALF: float = 90.0  # half-width of each bank from its own extreme
const WAVE_BIAS: float = 0.0      # 0=symmetric, bank moves exactly during inhale/exhale phases
const HEAD_SCALE: float = 0.22
const VAR_AMP: float = 55.0
const VAR_PERIOD_TOP_MS: float = 17000.0
const VAR_PERIOD_BOT_MS: float = 23000.0

var game: GenericGameUtil
var _duration_ms: float = 300000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

var _char_y: float = 0.0
var _char_x: float = 0.0
var _char_vel_y: float = 0.0
var _cycles_completed: int = 0
var _prev_phase_idx: int = 0
var _in_channel_ms: float = 0.0
var _walking: bool = false

# Stats / graph
var _graph: Control = null
var _trace_segments: Array = []
var _current_trace: Array = []
var _trace_last_ms: float = 0.0
const TRACE_INTERVAL_MS_R: float = 200.0

var _key_poll: Array = []
const KEY_POLL_INTERVAL_MS_R: float = 50.0

var _phase_grid: GridContainer
var _anim_time: float = 0.0
var _head_frame: int = 0
var _screen_h: float = 788.0
var _screen_w: float = 680.0
var _top_y: float = 65.0
var _bot_y: float = 723.0
var _scroll_px_per_ms: float = 0.04

var _head_textures: Array = []
var _sprite_head: Sprite2D

var _ripple_seeds: Array = []
var _tuft_seeds: Array = []
var _tree_seeds: Array = []
var _rock_seeds: Array = []
var _boat_seeds: Array = []

@onready var _canvas: Control = $RiverCanvas
@onready var _timer_label: Label = $SessionOverlay/TimerLabel
@onready var _goal_label: Label = $SessionOverlay/GoalLabel
@onready var _phase_label: Label = $SessionOverlay/PhaseLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _result_label: Label = $ResultsPanel/Margin/VBox/ResultLabel

func _ready() -> void:
	game = RiverG.game
	_screen_h = float(MainGlobals.screen_size.y)
	_screen_w = float(MainGlobals.screen_size.x)
	_char_x = _screen_w * CHAR_X_FRAC
	_top_y = float(MainGlobals.header_height) + 40.0
	_bot_y = _screen_h - 40.0

	_head_textures = [
		load("res://art/head1-4x.png"),
		load("res://art/head2-4x.png"),
		load("res://art/head3-4x.png"),
		load("res://art/head2-4x.png"),
	]

	_sprite_head = Sprite2D.new()
	_sprite_head.texture = _head_textures[0]
	_sprite_head.scale = Vector2(HEAD_SCALE, HEAD_SCALE)
	_sprite_head.z_index = 2
	_sprite_head.visible = false
	add_child(_sprite_head)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7331

	for i in range(55):
		_ripple_seeds.append({
			"wx": i * 20.0 + rng.randf_range(0.0, 12.0),
			"y_frac": rng.randf_range(0.12, 0.88),
			"len": rng.randf_range(14.0, 38.0),
		})
	for i in range(40):
		_tuft_seeds.append({
			"wx": i * 19.0 + rng.randf_range(0.0, 10.0),
			"side": i % 2,
			"r": rng.randf_range(5.0, 10.0),
			"offset": rng.randf_range(-5.0, 5.0),
		})
	# Bank-edge trees — wx uniformly covers [0,900] so no empty gaps on wrap
	for i in range(18):
		_tree_seeds.append({
			"wx": float(i) * 50.0 + rng.randf_range(0.0, 25.0),
			"side": i % 2,
			"trunk_h": rng.randf_range(22.0, 46.0),
			"canopy_r": rng.randf_range(14.0, 26.0),
			"depth": 0.0,
		})
	# Meadow trees — interleaved offset so mixed coverage with bank trees
	for i in range(18):
		_tree_seeds.append({
			"wx": float(i) * 50.0 + rng.randf_range(25.0, 50.0),
			"side": i % 2,
			"trunk_h": rng.randf_range(16.0, 36.0),
			"canopy_r": rng.randf_range(10.0, 20.0),
			"depth": rng.randf_range(45.0, 115.0),
		})
	# Meadow bushes
	for i in range(20):
		_rock_seeds.append({
			"wx": i * 50.0 + rng.randf_range(0.0, 32.0),
			"side": i % 2,
			"r": rng.randf_range(8.0, 18.0),
			"depth": rng.randf_range(30.0, 200.0),
		})
	for i in range(10):
		_boat_seeds.append({
			"wx": i * 115.0 + rng.randf_range(15.0, 70.0),
			"side": i % 2,
			"color_idx": rng.randi() % 3,
			"has_mast": rng.randf() > 0.35,
			"blen": rng.randf_range(28.0, 44.0),
		})

	var _f: Font = MainGlobals.get_system_sans_font()
	var _t: Theme = Theme.new()
	_t.set_font("font", "Label", _f)
	_t.set_font("font", "Button", _f)
	$SessionOverlay.theme = _t
	_results_panel.theme = _t

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.30, 0.50, 1.0)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.20, 0.36, 1.0)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("normal", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("hover", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("pressed", btn_pressed)

	_timer_label.offset_right = -16.0
	if MainGlobals.is_mobile():
		_timer_label.add_theme_font_size_override("font_size", 46)
		_timer_label.offset_bottom = 62.0
		_goal_label.add_theme_font_size_override("font_size", 36)
		_goal_label.offset_top = 66.0
		_goal_label.offset_bottom = 106.0
		_phase_label.add_theme_font_size_override("font_size", 42)
		_phase_label.offset_top = -74.0
		_phase_label.offset_bottom = -16.0
		$ResultsPanel/Margin/VBox/TitleLabel.add_theme_font_size_override("font_size", 34)
		_result_label.add_theme_font_size_override("font_size", 28)
		$ResultsPanel/Margin/VBox/DoneButton.add_theme_font_size_override("font_size", 36)

	_graph = Control.new()
	_graph.set_script(load("res://mother/scripts/key_graph.gd"))
	_graph.set("bg_color", Color(0.04, 0.07, 0.14, 1.0))
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(0, 100)
	_graph.visible = false
	var vbox_r: Node = $ResultsPanel/Margin/VBox
	vbox_r.add_child(_graph)
	vbox_r.move_child(_graph, vbox_r.get_child_count() - 2)
	var graph_spacer_r: Control = Control.new()
	graph_spacer_r.custom_minimum_size = Vector2(0, 24)
	vbox_r.add_child(graph_spacer_r)
	vbox_r.move_child(graph_spacer_r, vbox_r.get_child_count() - 2)

	var mobile_r: bool = MainGlobals.is_mobile()
	var again_btn_r: Button = Button.new()
	again_btn_r.text = "Again"
	again_btn_r.custom_minimum_size = Vector2(160, 52)
	again_btn_r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_r.add_theme_stylebox_override("normal", btn_style)
	again_btn_r.add_theme_stylebox_override("hover", btn_style)
	again_btn_r.add_theme_stylebox_override("pressed", btn_pressed)
	again_btn_r.add_theme_font_size_override("font_size", 36 if mobile_r else 26)
	again_btn_r.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	again_btn_r.pressed.connect(_on_again_pressed)
	var btn_hbox_r: HBoxContainer = HBoxContainer.new()
	btn_hbox_r.add_theme_constant_override("separation", 16)
	btn_hbox_r.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_r.add_child(btn_hbox_r)
	$ResultsPanel/Margin/VBox/DoneButton.reparent(btn_hbox_r)
	btn_hbox_r.add_child(again_btn_r)
	btn_hbox_r.move_child(again_btn_r, 0)

	_phase_grid = GridContainer.new()
	_phase_grid.columns = 3
	_phase_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_grid.add_theme_constant_override("h_separation", 24)
	_phase_grid.add_theme_constant_override("v_separation", 4)
	var _grid_hbox_r: HBoxContainer = HBoxContainer.new()
	_grid_hbox_r.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_hbox_r.add_child(_phase_grid)
	vbox_r.add_child(_grid_hbox_r)
	vbox_r.move_child(_grid_hbox_r, 2)

	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.offset_top = 0.0
	_results_panel.offset_bottom = 0.0
	_results_panel.offset_left = 0.0
	_results_panel.offset_right = 0.0
	var margin_ctrl_r: Control = $ResultsPanel/Margin as Control
	margin_ctrl_r.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + (48 if MainGlobals.is_mobile() else 16))
	margin_ctrl_r.add_theme_constant_override("margin_top", 8)
	($ResultsPanel/Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 6)
	_results_panel.hide()

func new_game() -> void:
	_duration_ms = RiverG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_walking = false
	_anim_time = 0.0
	_head_frame = 0
	_char_vel_y = 0.0
	_cycles_completed = 0
	_prev_phase_idx = 0
	_in_channel_ms = 0.0
	_trace_segments = []
	_current_trace = []
	_trace_last_ms = 0.0
	_key_poll = []
	_scroll_px_per_ms = _compute_scroll_speed()
	_char_y = _bot_y
	_sprite_head.visible = true
	game.level_is_ready = true
	game.playing = true
	var d_g: Array = RiverG.get_guided_durations()
	_goal_label.text = "Goal: %s – %s – %s – %s" % [_fv_ms(d_g[0]), _fv_ms(d_g[1]), _fv_ms(d_g[2]), _fv_ms(d_g[3])]
	$SessionOverlay.show()
	_results_panel.hide()
	_canvas.queue_redraw()

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	_elapsed_ms += delta * 1000.0
	_anim_time += delta

	# Cycle counter: count each completed inhale→hold→exhale→hold cycle
	var _dc: Array = RiverG.get_guided_durations()
	var _cycle_ms_c: float = _dc[0] + _dc[1] + _dc[2] + _dc[3]
	var _phase_t_c: float = fmod(_elapsed_ms, _cycle_ms_c)
	var cur_phase_idx: int = 0
	if _phase_t_c >= _dc[0] + _dc[1] + _dc[2]:
		cur_phase_idx = 3
	elif _phase_t_c >= _dc[0] + _dc[1]:
		cur_phase_idx = 2
	elif _phase_t_c >= _dc[0]:
		cur_phase_idx = 1
	if cur_phase_idx == 0 and _prev_phase_idx == 3:
		_cycles_completed += 1
	_prev_phase_idx = cur_phase_idx

	# Key poll for phase measurement
	var expected_slots_r: int = int(_elapsed_ms / KEY_POLL_INTERVAL_MS_R)
	while _key_poll.size() < expected_slots_r:
		if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
			_key_poll.append(1)
		elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
			_key_poll.append(2)
		else:
			_key_poll.append(0)

	var prev_char_y: float = _char_y
	var up: bool = Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up
	var down: bool = Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn
	if up or down:
		var d: Array = RiverG.get_guided_durations()
		var inhale_ms: float = d[0]
		var hold_top_ms: float = d[1]
		var exhale_ms: float = d[2]
		var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + d[3]
		var phase_t: float = fmod(_elapsed_ms, cycle_ms)
		if phase_t < 0.0:
			phase_t += cycle_ms
		var spd: float = 0.0
		var c_now: float = (_upper_y_at(_elapsed_ms) + _lower_y_at(_elapsed_ms)) * 0.5
		var tau: float = 0.05
		if phase_t < inhale_ms:
			if up:
				spd = clampf((c_now - _char_y) / tau, -800.0, 800.0)
			else:
				spd = 280.0
		elif phase_t < inhale_ms + hold_top_ms:
			spd = -220.0 if up else 220.0
		elif phase_t < inhale_ms + hold_top_ms + exhale_ms:
			if down:
				spd = clampf((c_now - _char_y) / tau, -800.0, 800.0)
			else:
				spd = -280.0
		else:
			spd = -220.0 if up else 220.0
		_char_y += spd * delta
	_char_y = clampf(_char_y, _var_top_y(_elapsed_ms) - CHANNEL_HALF + 10.0, _var_bot_y(_elapsed_ms) + CHANNEL_HALF - 10.0)

	var uy: float = _upper_y_at(_elapsed_ms)
	var ly: float = _lower_y_at(_elapsed_ms)
	_walking = _char_y < uy or _char_y > ly
	if not _walking:
		_in_channel_ms += delta * 1000.0

	if _elapsed_ms - _trace_last_ms >= TRACE_INTERVAL_MS_R:
		var y_norm: float = clampf((_char_y - _top_y) / (_bot_y - _top_y), 0.0, 1.0)
		_current_trace.append(Vector2(_elapsed_ms, y_norm))
		_trace_last_ms = _elapsed_ms

	var raw_vel: float = (_char_y - prev_char_y) / maxf(delta, 0.001)
	_char_vel_y = lerpf(_char_vel_y, raw_vel, delta * 8.0)

	_head_frame = int(_anim_time * 3.5) % 4
	_sprite_head.texture = _head_textures[_head_frame]
	_sprite_head.rotation = atan2(_char_vel_y, _scroll_px_per_ms * 1000.0)
	_sprite_head.position = Vector2(_char_x, _char_y)

	var rem_s_hud: int = int(maxf(0.0, _duration_ms - _elapsed_ms) / 1000.0)
	_timer_label.text = "%d:%02d" % [rem_s_hud / 60, rem_s_hud % 60]
	_phase_label.text = _current_phase_name()

	_canvas.queue_redraw()

	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

func _cycle_top_offset(n: int) -> float:
	return VAR_AMP * sin(float(n) * 0.8)

func _cycle_bot_offset(n: int) -> float:
	return VAR_AMP * sin(float(n) * 0.7 + 1.7)

func _var_top_y(t_ms: float) -> float:
	var d: Array = RiverG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	return _top_y + _cycle_top_offset(int(floor(t_ms / cycle_ms)))

func _var_bot_y(t_ms: float) -> float:
	var d: Array = RiverG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	return _bot_y + _cycle_bot_offset(int(floor(t_ms / cycle_ms)))

func _compute_scroll_speed() -> float:
	var d: Array = RiverG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	var future_px: float = _screen_w - _char_x
	return future_px / (1.2 * cycle_ms)

func _upper_y_at(t_ms: float) -> float:
	var d: Array = RiverG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var hold_bot_ms: float = d[3]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + hold_bot_ms
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	var cycle_n: int = int(floor(t_ms / cycle_ms))
	var top_pos: float = _top_y - CHANNEL_HALF + _cycle_top_offset(cycle_n)
	var bot_pos: float = _bot_y - CHANNEL_HALF + _cycle_bot_offset(cycle_n)
	var prev_bot_pos: float = _bot_y - CHANNEL_HALF + _cycle_bot_offset(cycle_n - 1)
	if t < inhale_ms:
		return lerpf(prev_bot_pos, top_pos, smoothstep(0.0, 1.0, t / inhale_ms))
	t -= inhale_ms
	if t < hold_top_ms:
		return top_pos
	t -= hold_top_ms
	if t < exhale_ms:
		return lerpf(top_pos, bot_pos, smoothstep(0.0, 1.0, t / exhale_ms))
	return bot_pos

func _lower_y_at(t_ms: float) -> float:
	var d: Array = RiverG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var hold_bot_ms: float = d[3]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + hold_bot_ms
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	var cycle_n: int = int(floor(t_ms / cycle_ms))
	var top_pos: float = _top_y + CHANNEL_HALF + _cycle_top_offset(cycle_n)
	var bot_pos: float = _bot_y + CHANNEL_HALF + _cycle_bot_offset(cycle_n)
	var prev_bot_pos: float = _bot_y + CHANNEL_HALF + _cycle_bot_offset(cycle_n - 1)
	if t < inhale_ms:
		return lerpf(prev_bot_pos, top_pos, smoothstep(0.0, 1.0, t / inhale_ms))
	t -= inhale_ms
	if t < hold_top_ms:
		return top_pos
	t -= hold_top_ms
	if t < exhale_ms:
		return lerpf(top_pos, bot_pos, smoothstep(0.0, 1.0, t / exhale_ms))
	return bot_pos

func _current_phase_name() -> String:
	var d: Array = RiverG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var t: float = fmod(_elapsed_ms, d[0] + d[1] + d[2] + d[3])
	if t < inhale_ms:
		return "Inhale  ▲"
	t -= inhale_ms
	if t < hold_top_ms:
		return "Hold  ■"
	t -= hold_top_ms
	if t < exhale_ms:
		return "Exhale  ▼"
	return "Hold  ■"

func _do_draw(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = float(MainGlobals.screen_size.y)       # content area (excludes footer)
	var h_full: float = (canvas as Control).size.y        # full canvas including footer gap

	canvas.draw_rect(Rect2(0.0, 0.0, w, h_full * 0.45), Color(0.52, 0.74, 0.92, 1.0))
	canvas.draw_rect(Rect2(0.0, h_full * 0.45, w, h_full * 0.55), Color(0.06, 0.18, 0.34, 1.0))
	canvas.draw_rect(Rect2(0.0, 0.0, w, h_full), Color(0.06, 0.18, 0.34, 1.0))

	var step: float = 4.0
	var n: int = int(ceil(w / step)) + 1
	var upper_pts: PackedVector2Array = PackedVector2Array()
	var lower_pts: PackedVector2Array = PackedVector2Array()
	upper_pts.resize(n)
	lower_pts.resize(n)
	for i in range(n):
		var x: float = minf(i * step, w)
		var t_ms: float = _elapsed_ms + (x - _char_x) / _scroll_px_per_ms
		upper_pts[i] = Vector2(x, clampf(_upper_y_at(t_ms), 30.0, h))
		lower_pts[i] = Vector2(x, clampf(_lower_y_at(t_ms), 0.0, h - 30.0))

	var land_color: Color = Color(0.17, 0.44, 0.21, 1.0)
	var land_dark: Color = Color(0.10, 0.28, 0.13, 1.0)
	var land_mid: Color = Color(0.13, 0.36, 0.17, 1.0)
	var edge_color: Color = Color(0.07, 0.20, 0.10, 1.0)

	var up_poly: PackedVector2Array = PackedVector2Array()
	up_poly.append(Vector2(0.0, 0.0))
	up_poly.append_array(upper_pts)
	up_poly.append(Vector2(w, 0.0))
	canvas.draw_polygon(up_poly, PackedColorArray([land_color]))

	var up_dark: PackedVector2Array = PackedVector2Array()
	up_dark.append(Vector2(0.0, 0.0))
	for i in range(n):
		up_dark.append(Vector2(upper_pts[i].x, upper_pts[i].y - 22.0))
	up_dark.append(Vector2(w, 0.0))
	canvas.draw_polygon(up_dark, PackedColorArray([land_dark]))

	var up_mid: PackedVector2Array = PackedVector2Array()
	up_mid.append(Vector2(0.0, 0.0))
	for i in range(n):
		up_mid.append(Vector2(upper_pts[i].x, upper_pts[i].y - 7.0))
	up_mid.append(Vector2(w, 0.0))
	canvas.draw_polygon(up_mid, PackedColorArray([land_mid]))

	var lo_poly: PackedVector2Array = PackedVector2Array()
	lo_poly.append(Vector2(0.0, h_full))
	lo_poly.append_array(lower_pts)
	lo_poly.append(Vector2(w, h_full))
	canvas.draw_polygon(lo_poly, PackedColorArray([land_color]))

	var lo_dark: PackedVector2Array = PackedVector2Array()
	lo_dark.append(Vector2(0.0, h_full))
	for i in range(n):
		lo_dark.append(Vector2(lower_pts[i].x, lower_pts[i].y + 22.0))
	lo_dark.append(Vector2(w, h_full))
	canvas.draw_polygon(lo_dark, PackedColorArray([land_dark]))

	var lo_mid: PackedVector2Array = PackedVector2Array()
	lo_mid.append(Vector2(0.0, h_full))
	for i in range(n):
		lo_mid.append(Vector2(lower_pts[i].x, lower_pts[i].y + 7.0))
	lo_mid.append(Vector2(w, h_full))
	canvas.draw_polygon(lo_mid, PackedColorArray([land_mid]))

	canvas.draw_polyline(upper_pts, edge_color, 3.0, true)
	canvas.draw_polyline(lower_pts, edge_color, 3.0, true)

	var scroll_offset: float = _elapsed_ms * _scroll_px_per_ms


	# --- Meadow bushes ---
	var bush_span: float = float(_rock_seeds.size()) * 50.0
	for rk in _rock_seeds:
		var tx_raw: float = fmod(rk.wx - scroll_offset, bush_span)
		if tx_raw < 0.0:
			tx_raw += bush_span
		for _ti in range(2):
			var tx: float = tx_raw if _ti == 0 else tx_raw - bush_span
			var br: float = rk.r
			if tx + br < -5.0 or tx - br > w + 5.0:
				continue
			var t_ms: float = _elapsed_ms + (tx - _char_x) / _scroll_px_per_ms
			var by_center: float
			if rk.side == 0:
				by_center = _upper_y_at(t_ms) - rk.depth
			else:
				by_center = _lower_y_at(t_ms) + rk.depth
			var hash_v: float = rk.wx * 0.17 + float(rk.side) * 2.3
			var n_sp: int = 7
			for ki in range(n_sp):
				var a: float = float(ki) / float(n_sp) * TAU + hash_v
				var r_f: float = 0.9
				var sp_col: Color = Color(0.06, 0.16, 0.07, 0.92)
				canvas.draw_line(Vector2(tx, by_center), Vector2(tx + cos(a) * br * r_f, by_center + sin(a) * br * r_f), sp_col, 1.8, true)
			canvas.draw_circle(Vector2(tx, by_center), br * 0.22, Color(0.07, 0.20, 0.09, 0.95), true, -1.0, true)

	# --- Trees: bank-edge and meadow depth ---
	var tree_span: float = 900.0
	for tree in _tree_seeds:
		var tx_raw: float = fmod(tree.wx - scroll_offset, tree_span)
		if tx_raw < 0.0:
			tx_raw += tree_span
		for _ti in range(2):
			var tx: float = tx_raw if _ti == 0 else tx_raw - tree_span
			var cr: float = tree.canopy_r
			if tx + cr * 2.0 < -5.0 or tx - cr > w + 5.0:
				continue
			var t_ms: float = _elapsed_ms + (tx - _char_x) / _scroll_px_per_ms
			var trunk_h: float = tree.trunk_h
			var depth: float = tree.depth
			if tree.side == 0:
				var base_y: float = _upper_y_at(t_ms) - depth
				canvas.draw_line(Vector2(tx, base_y), Vector2(tx, base_y - trunk_h),
					Color(0.22, 0.14, 0.08, 0.9), 3.0, true)
				canvas.draw_circle(Vector2(tx, base_y - trunk_h - cr * 0.7),
					cr, Color(0.09, 0.26, 0.11, 0.85), true, -1.0, true)
				canvas.draw_circle(Vector2(tx - cr * 0.5, base_y - trunk_h - cr * 0.35),
					cr * 0.75, Color(0.12, 0.32, 0.14, 0.80), true, -1.0, true)
			else:
				var base_y: float = _lower_y_at(t_ms) + depth
				canvas.draw_line(Vector2(tx, base_y), Vector2(tx, base_y - trunk_h),
					Color(0.22, 0.14, 0.08, 0.9), 3.0, true)
				canvas.draw_circle(Vector2(tx, base_y - trunk_h - cr * 0.7),
					cr, Color(0.09, 0.26, 0.11, 0.85), true, -1.0, true)
				canvas.draw_circle(Vector2(tx + cr * 0.5, base_y - trunk_h - cr * 0.35),
					cr * 0.75, Color(0.12, 0.32, 0.14, 0.80), true, -1.0, true)

	# --- Boats moored at bank edges ---
	var boat_hull_colors: Array = [Color(0.45, 0.25, 0.15, 1.0), Color(0.22, 0.34, 0.50, 1.0),
		Color(0.72, 0.68, 0.60, 1.0)]
	var boat_span: float = float(_boat_seeds.size()) * 115.0
	for bt in _boat_seeds:
		var tx_raw: float = fmod(bt.wx - scroll_offset, boat_span)
		if tx_raw < 0.0:
			tx_raw += boat_span
		for _ti in range(2):
			var tx: float = tx_raw if _ti == 0 else tx_raw - boat_span
			var blen: float = bt.blen
			if tx + blen / 2.0 < -5.0 or tx - blen / 2.0 > w + 5.0:
				continue
			var t_ms: float = _elapsed_ms + (tx - _char_x) / _scroll_px_per_ms
			var hull_col: Color = boat_hull_colors[bt.color_idx]
			var bh: float = 9.0
			var hull: PackedVector2Array = PackedVector2Array()
			if bt.side == 0:
				var base_y: float = _upper_y_at(t_ms)
				var cy: float = base_y + 6.0
				hull.append(Vector2(tx - blen / 2.0, cy + bh * 0.5))
				hull.append(Vector2(tx - blen / 2.0 + 6.0, cy))
				hull.append(Vector2(tx + blen / 2.0 - 6.0, cy))
				hull.append(Vector2(tx + blen / 2.0, cy + bh * 0.5))
				hull.append(Vector2(tx + blen / 2.0 - 6.0, cy + bh))
				hull.append(Vector2(tx - blen / 2.0 + 6.0, cy + bh))
				canvas.draw_colored_polygon(hull, hull_col)
				canvas.draw_polyline(hull, Color(0.15, 0.10, 0.05, 0.8), 1.5, true)
				if bt.has_mast:
					canvas.draw_line(Vector2(tx + 4.0, cy), Vector2(tx + 4.0, cy - 28.0),
						Color(0.30, 0.20, 0.10, 0.9), 2.0, true)
					var sail: PackedVector2Array = PackedVector2Array()
					sail.append(Vector2(tx + 4.0, cy - 28.0))
					sail.append(Vector2(tx + 4.0, cy - 8.0))
					sail.append(Vector2(tx + 4.0 + blen * 0.35, cy - 18.0))
					canvas.draw_colored_polygon(sail, Color(0.94, 0.92, 0.86, 0.85))
			else:
				var base_y: float = _lower_y_at(t_ms)
				var cy: float = base_y - 6.0
				hull.append(Vector2(tx - blen / 2.0, cy + bh * 0.5))
				hull.append(Vector2(tx - blen / 2.0 + 6.0, cy))
				hull.append(Vector2(tx + blen / 2.0 - 6.0, cy))
				hull.append(Vector2(tx + blen / 2.0, cy + bh * 0.5))
				hull.append(Vector2(tx + blen / 2.0 - 6.0, cy + bh))
				hull.append(Vector2(tx - blen / 2.0 + 6.0, cy + bh))
				canvas.draw_colored_polygon(hull, hull_col)
				canvas.draw_polyline(hull, Color(0.15, 0.10, 0.05, 0.8), 1.5, true)
				if bt.has_mast:
					canvas.draw_line(Vector2(tx + 4.0, cy), Vector2(tx + 4.0, cy - 28.0),
						Color(0.30, 0.20, 0.10, 0.9), 2.0, true)
					var sail: PackedVector2Array = PackedVector2Array()
					sail.append(Vector2(tx + 4.0, cy - 28.0))
					sail.append(Vector2(tx + 4.0, cy - 8.0))
					sail.append(Vector2(tx + 4.0 + blen * 0.35, cy - 18.0))
					canvas.draw_colored_polygon(sail, Color(0.94, 0.92, 0.86, 0.85))

	# --- River ripples ---
	var ripple_span: float = float(_ripple_seeds.size()) * 20.0
	var ripple_color: Color = Color(0.55, 0.75, 0.92, 0.18)
	for rpl in _ripple_seeds:
		var rx: float = fmod(rpl.wx - scroll_offset, ripple_span)
		if rx < 0.0:
			rx += ripple_span
		if rx + rpl.len < 0.0 or rx > w:
			continue
		var t_ms_r: float = _elapsed_ms + (rx - _char_x) / _scroll_px_per_ms
		var t_ms_end_r: float = _elapsed_ms + (rx + rpl.len - _char_x) / _scroll_px_per_ms
		var uy_r: float = _upper_y_at(t_ms_r)
		var ly_r: float = _lower_y_at(t_ms_r)
		var uy2_r: float = _upper_y_at(t_ms_end_r)
		var ly2_r: float = _lower_y_at(t_ms_end_r)
		# Horizontal ripple — skip if outside river at either endpoint
		var uy_max: float = maxf(uy_r, uy2_r)
		var ly_min: float = minf(ly_r, ly2_r)
		var ry: float = uy_r + (ly_r - uy_r) * rpl.y_frac
		if ry < uy_max + 8.0 or ry > ly_min - 8.0:
			continue
		canvas.draw_line(Vector2(rx, ry), Vector2(rx + rpl.len, ry), ripple_color, 1.5, true)


func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	_sprite_head.visible = false
	$SessionOverlay.hide()

	if _current_trace.size() > 1:
		_trace_segments.append(_current_trace)
	_current_trace = []

	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60

	var phases: Array = _compute_phase_durations(_key_poll)
	var has_data: bool = phases[0] + phases[2] > 100.0
	var in_pct: int = clampi(roundi(_in_channel_ms / maxf(_duration_ms, 1.0) * 100.0), 0, 100)
	var d: Array = RiverG.get_guided_durations()
	var accuracy: int = _accuracy_score_r(phases)
	if has_data:
		game.add_score_and_time(accuracy, 0, true)
	_result_label.text = "Session: %d:%02d min   Score: %d/100\nCycles: %d   In channel: %d%%" % [
		dur_min, dur_sec, accuracy, _cycles_completed, in_pct]
	_populate_phase_grid(phases, d)

	if _graph != null:
		_graph.visible = true
		var graph_duration_ms_r: float = _key_poll.size() * KEY_POLL_INTERVAL_MS_R
		_graph.call("set_data", _key_poll, [], graph_duration_ms_r)
		_graph.queue_redraw()

	_results_panel.show()
	sig_session_done.emit()

func _accuracy_score_r(phases: Array) -> int:
	var d: Array = RiverG.get_guided_durations()
	if phases[0] + phases[2] < 100.0:
		return 0
	var err: float = 0.0
	var n: int = 2
	err += absf(phases[0] - d[0]) / maxf(d[0], 1.0)
	err += absf(phases[2] - d[2]) / maxf(d[2], 1.0)
	if d[1] > 200.0:
		err += absf(phases[1] - d[1]) / maxf(d[1], 1.0)
		n += 1
	if d[3] > 200.0:
		err += absf(phases[3] - d[3]) / maxf(d[3], 1.0)
		n += 1
	err /= float(n)
	return clampi(roundi((1.0 - minf(err, 1.0)) * 100.0), 0, 100)

func _compute_phase_durations(keys: Array) -> Array:
	var res: Array = [0.0, 0.0, 0.0, 0.0]
	var maxgap: int = 2
	for i in range(maxgap + 1, keys.size()):
		if keys[i] != 0 and keys[i - 1] == 0 and keys[i - maxgap - 1] == keys[i]:
			for j in range(i - maxgap, i):
				keys[j] = keys[i]
	var i_started: int = 0
	var phase: int = -1
	var sums: Array = [0, 0, 0, 0]
	var nums: Array = [0, 0, 0, 0]
	for i in keys.size():
		if keys[i] == 1:
			if phase != 0:
				if phase == 3:
					nums[3] += 1
					sums[3] += i - i_started + 1
				i_started = i
				phase = 0
		elif keys[i] == 2:
			if phase != 2:
				if phase == 1:
					nums[1] += 1
					sums[1] += i - i_started + 1
				i_started = i
				phase = 2
		else:
			if phase == 0:
				nums[0] += 1
				sums[0] += i - i_started + 1
				i_started = i
				phase = 1
			elif phase == 2:
				nums[2] += 1
				sums[2] += i - i_started + 1
				i_started = i
				phase = 3
	for i in 4:
		res[i] = float(sums[i]) / (float(nums[i]) + 1e-6) * 50.0
	return res

func _populate_phase_grid(phases: Array, durations: Array) -> void:
	for child in _phase_grid.get_children():
		child.queue_free()
	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 28 if MainGlobals.is_mobile() else 20
	var rows: Array = [["Inhale", phases[0], durations[0]]]
	if durations[1] > 200.0:
		rows.append(["Hold air", phases[1], durations[1]])
	rows.append(["Exhale", phases[2], durations[2]])
	if durations[3] > 200.0:
		rows.append(["Hold empty", phases[3], durations[3]])
	for row in rows:
		var lbl_n: Label = Label.new()
		lbl_n.text = str(row[0]) + ":"
		lbl_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_n.add_theme_font_override("font", font)
		lbl_n.add_theme_font_size_override("font_size", fs)
		lbl_n.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.80))
		_phase_grid.add_child(lbl_n)
		var lbl_v: Label = Label.new()
		lbl_v.text = "%.1f s" % [float(row[1]) / 1000.0]
		lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_v.add_theme_font_override("font", font)
		lbl_v.add_theme_font_size_override("font_size", fs)
		lbl_v.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
		_phase_grid.add_child(lbl_v)
		var lbl_t: Label = Label.new()
		lbl_t.text = "(target %.1f s)" % [float(row[2]) / 1000.0]
		lbl_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_t.add_theme_font_override("font", font)
		lbl_t.add_theme_font_size_override("font_size", fs)
		lbl_t.add_theme_color_override("font_color", Color(0.70, 0.88, 0.72, 0.72))
		_phase_grid.add_child(lbl_t)

func _fv_ms(ms: float) -> String:
	var r: float = round(ms / 500.0) / 2.0
	if r == float(int(r)):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _on_again_pressed() -> void:
	_results_panel.hide()
	game.reset(true)
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
