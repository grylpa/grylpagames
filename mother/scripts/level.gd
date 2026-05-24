extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

# Both heads at same x; mother on top half, child on bottom half
const HEAD_X_FRAC: float = 0.82
const M_TOP_FRAC: float = 0.30   # mother y range top (center of range ~0.43, just above screen center)
const M_BOT_FRAC: float = 0.56   # mother y range bottom; child starts at 0.5 (just below mid-range)
# Visuals
var MOTHER_W: float = 18.0
var CHILD_W: float = 12.0
var HEAD_SCALE: float = 0.34

# Child body history ring buffer — interpolated to eliminate jitter
const HISTORY_INTERVAL_MS: float = 16.0
const HISTORY_SLOTS: int = 3000

var game: GenericGameUtil
var _duration_ms: float = 60000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

var _screen_w: float = 680.0
var _screen_h: float = 788.0
var _head_x: float = 0.0
var _m_top_y: float = 0.0
var _m_bot_y: float = 0.0
var _scroll_px_per_ms: float = 0.04

var _child_y: float = 0.0

var _child_history: PackedFloat32Array
var _history_head: int = 0
var _history_count: int = 0
var _history_last_ms: float = -1000.0

var _child_angle: float = 0.0
var _child_vel_y: float = 0.0   # smooth keyboard velocity (px/s, positive = down)
var _session_ps: int = 0

var _head_textures: Array = []
var _sprite_child: Sprite2D
var _sprite_mother: Sprite2D
var _anim_time: float = 0.0
var _head_frame: int = 0
var _bg_seeds: Array = []

# Stats / graph
var _graph: Control = null
var _phase_grid: GridContainer
var _reaction_label: Label
var _trace_segments: Array = []
var _current_trace: Array = []
var _trace_last_ms: float = 0.0
const TRACE_INTERVAL_MS: float = 200.0
const KEY_POLL_INTERVAL_MS: float = 50.0

var _key_poll: Array = []
var _rt_ms: int = 0

var active_mode: bool = false
var _computed_phases: Array = [0.0, 0.0, 0.0, 0.0]

@onready var _canvas: Control = $MotherCanvas
@onready var _timer_label: Label = $SessionOverlay/TimerLabel
@onready var _goal_label: Label = $SessionOverlay/GoalLabel
@onready var _phase_label: Label = $SessionOverlay/PhaseLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _result_label: Label = $ResultsPanel/Margin/VBox/ResultLabel

func _ready() -> void:
	game = MotherG.game
	_screen_w = float(MainGlobals.screen_size.x)
	_screen_h = float(MainGlobals.screen_size.y)
	_head_x = _screen_w * HEAD_X_FRAC
	_m_top_y = _screen_h * M_TOP_FRAC
	_m_bot_y = _screen_h * M_BOT_FRAC
	if MainGlobals.is_mobile():
		MOTHER_W *= 2.0
		CHILD_W *= 2.0
		HEAD_SCALE *= 2.0

	_head_textures = [
		load("res://art/head1-4x.png"),
		load("res://art/head2-4x.png"),
		load("res://art/head3-4x.png"),
		load("res://art/head2-4x.png"),
	]

	_sprite_mother = Sprite2D.new()
	_sprite_mother.texture = _head_textures[0]
	_sprite_mother.scale = Vector2(HEAD_SCALE * 0.675, HEAD_SCALE * 0.475)
	_sprite_mother.modulate = Color(0.35, 1.0, 0.40, 1.0)
	_sprite_mother.z_index = 3
	_sprite_mother.visible = false
	add_child(_sprite_mother)

	_sprite_child = Sprite2D.new()
	_sprite_child.texture = _head_textures[0]
	_sprite_child.scale = _sprite_mother.scale * 0.8
	_sprite_child.z_index = 4
	_sprite_child.visible = false
	add_child(_sprite_child)

	var sys_font: Font = MainGlobals.get_system_sans_font()
	var theme: Theme = Theme.new()
	theme.set_font("font", "Label", sys_font)
	theme.set_font("font", "Button", sys_font)
	$SessionOverlay.theme = theme
	_results_panel.theme = theme

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.10, 0.28, 0.12, 1.0)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.06, 0.18, 0.08, 1.0)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("normal", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("hover", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("pressed", btn_pressed)

	_timer_label.offset_right = -16.0
	if MainGlobals.is_mobile():
		_timer_label.add_theme_font_size_override("font_size", 46)
		_timer_label.offset_bottom = 62.0
		_goal_label.add_theme_font_size_override("font_size", 42)
		_goal_label.offset_top = 66.0
		_goal_label.offset_bottom = 114.0
		_phase_label.add_theme_font_size_override("font_size", 42)
		_phase_label.offset_top = -74.0
		_phase_label.offset_bottom = -16.0
		$ResultsPanel/Margin/VBox/TitleLabel.add_theme_font_size_override("font_size", 34)
		_result_label.add_theme_font_size_override("font_size", 28)
		$ResultsPanel/Margin/VBox/DoneButton.add_theme_font_size_override("font_size", 36)

	_child_history = PackedFloat32Array()
	_child_history.resize(HISTORY_SLOTS)

	_graph = Control.new()
	_graph.set_script(load("res://mother/scripts/key_graph.gd"))
	_graph.set("bg_color", Color(0.04, 0.07, 0.04, 1.0))
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(0, 100)
	_graph.visible = false
	var vbox_m: Node = $ResultsPanel/Margin/VBox
	vbox_m.add_child(_graph)
	vbox_m.move_child(_graph, vbox_m.get_child_count() - 2)
	var graph_spacer_m: Control = Control.new()
	graph_spacer_m.custom_minimum_size = Vector2(0, 24)
	vbox_m.add_child(graph_spacer_m)
	vbox_m.move_child(graph_spacer_m, vbox_m.get_child_count() - 2)

	var mobile_m: bool = MainGlobals.is_mobile()
	var again_btn_m: Button = Button.new()
	again_btn_m.text = "Again"
	again_btn_m.custom_minimum_size = Vector2(160, 52)
	again_btn_m.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_m.add_theme_stylebox_override("normal", btn_style)
	again_btn_m.add_theme_stylebox_override("hover", btn_style)
	again_btn_m.add_theme_stylebox_override("pressed", btn_pressed)
	again_btn_m.add_theme_font_size_override("font_size", 36 if mobile_m else 26)
	again_btn_m.add_theme_color_override("font_color", Color(0.82, 0.96, 0.85, 1.0))
	again_btn_m.pressed.connect(_on_again_pressed)
	var btn_hbox_m: HBoxContainer = HBoxContainer.new()
	btn_hbox_m.add_theme_constant_override("separation", 16)
	btn_hbox_m.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_m.add_child(btn_hbox_m)
	$ResultsPanel/Margin/VBox/DoneButton.reparent(btn_hbox_m)
	btn_hbox_m.add_child(again_btn_m)
	btn_hbox_m.move_child(again_btn_m, 0)

	_phase_grid = GridContainer.new()
	_phase_grid.columns = 3
	_phase_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_grid.add_theme_constant_override("h_separation", 24)
	_phase_grid.add_theme_constant_override("v_separation", 1)
	var _grid_hbox_m: HBoxContainer = HBoxContainer.new()
	_grid_hbox_m.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_hbox_m.add_child(_phase_grid)
	vbox_m.add_child(_grid_hbox_m)
	vbox_m.move_child(_grid_hbox_m, 2)

	_reaction_label = Label.new()
	_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reaction_label.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	_reaction_label.add_theme_font_size_override("font_size", 20 if not MainGlobals.is_mobile() else 28)
	_reaction_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.75, 0.85))
	_reaction_label.visible = false
	vbox_m.add_child(_reaction_label)
	vbox_m.move_child(_reaction_label, 3)

	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.offset_top = 0.0
	_results_panel.offset_bottom = 0.0
	_results_panel.offset_left = 0.0
	_results_panel.offset_right = 0.0
	var margin_ctrl: Control = $ResultsPanel/Margin as Control
	var mobile_r: bool = MainGlobals.is_mobile()
	margin_ctrl.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + (48 if mobile_r else 16))
	margin_ctrl.add_theme_constant_override("margin_top", 8)
	($ResultsPanel/Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 3 if mobile_r else 6)
	_results_panel.hide()

	var bg_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	bg_rng.seed = 4219
	# Sand ripple lines (alternating dark/light)
	for i in range(22):
		_bg_seeds.append({
			"type": 0,
			"y_frac": (float(i) + bg_rng.randf_range(0.1, 0.9)) / 22.0,
			"amp": bg_rng.randf_range(1.5, 5.0),
			"period": bg_rng.randf_range(110.0, 280.0),
			"phase": bg_rng.randf_range(0.0, TAU),
			"alpha": bg_rng.randf_range(0.18, 0.38),
			"light": bg_rng.randf() > 0.5,
		})
	# Small pebbles
	for i in range(22):
		_bg_seeds.append({
			"type": 1,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(0.0, 1.0),
			"r": bg_rng.randf_range(1.5, 4.0),
			"speed_f": bg_rng.randf_range(0.55, 1.0),
		})
	# Dry bushes (tumbling with wind)
	for i in range(11):
		var spikes: Array = []
		for _k in range(12):
			spikes.append({"a": bg_rng.randf_range(0.0, TAU), "r": bg_rng.randf_range(0.45, 1.0)})
		# First 8 go in the top half, last 3 spread bottom half
		var y_min: float = 0.05 if i < 8 else 0.52
		var y_max: float = 0.50 if i < 8 else 0.92
		_bg_seeds.append({
			"type": 2,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(y_min, y_max),
			"r": bg_rng.randf_range(10.0, 20.0),
			"spikes": spikes,
			"speed_f": bg_rng.randf_range(1.1, 1.5),
			"phase": bg_rng.randf_range(0.0, TAU),
		})
	# Beetles
	for i in range(4):
		_bg_seeds.append({
			"type": 3,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(0.1, 0.9),
			"speed_f": bg_rng.randf_range(0.7, 1.1),
			"phase": bg_rng.randf_range(0.0, TAU),
		})

func new_game() -> void:
	_duration_ms = MotherG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_anim_time = 0.0
	_head_frame = 0
	_scroll_px_per_ms = _compute_scroll_speed()
	_child_y = _m_bot_y + 60.0
	_child_angle = 0.0
	_child_vel_y = 0.0
	_session_ps = 0
	_rt_ms = 0
	_history_head = 0
	_history_count = 0
	_history_last_ms = -1000.0
	_child_history.fill(_child_y)
	_trace_segments = []
	_current_trace = []
	_trace_last_ms = 0.0
	_key_poll = []
	_computed_phases = [0.0, 0.0, 0.0, 0.0]
	_sprite_child.visible = not active_mode
	_sprite_mother.visible = true
	if active_mode:
		_goal_label.text = ""
	else:
		var d_g: Array = MotherG.get_guided_durations()
		_goal_label.text = "Goal: %s – %s – %s – %s" % [_fv_ms(d_g[0]), _fv_ms(d_g[1]), _fv_ms(d_g[2]), _fv_ms(d_g[3])]
	game.level_is_ready = true
	game.playing = true
	$SessionOverlay.show()
	_results_panel.hide()
	_canvas.queue_redraw()

func _compute_scroll_speed() -> float:
	var d: Array = MotherG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	return _screen_w / (1.5 * cycle_ms)

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	_elapsed_ms += delta * 1000.0
	_anim_time += delta

	# Keyboard: speed calibrated so full inhale/exhale traverses the mother's range
	var d: Array = MotherG.get_guided_durations()
	var m_range: float = _m_bot_y - _m_top_y
	var speed_up: float = m_range / d[0] * 1000.0
	var speed_down: float = m_range / d[2] * 1000.0
	var target_vel: float = 0.0
	if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
		target_vel = -speed_up
	elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
		target_vel = speed_down
	_child_vel_y = lerpf(_child_vel_y, target_vel, delta * 8.0)
	var _new_child_y: float = clampf(_child_y + _child_vel_y * delta, 0.0, _screen_h)
	if _new_child_y == 0.0 or _new_child_y == _screen_h:
		_child_vel_y = 0.0
	_child_y = _new_child_y

	# History ring buffer
	if _elapsed_ms - _history_last_ms >= HISTORY_INTERVAL_MS:
		_child_history[_history_head] = _child_y
		_history_head = (_history_head + 1) % HISTORY_SLOTS
		_history_count = mini(_history_count + 1, HISTORY_SLOTS)
		_history_last_ms = _elapsed_ms

	# Keyboard polling — fill every 50ms slot up to current time; no drift
	var expected_slots: int = int(_elapsed_ms / KEY_POLL_INTERVAL_MS)
	while _key_poll.size() < expected_slots:
		if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
			_key_poll.append(1)
		elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
			_key_poll.append(2)
		else:
			_key_poll.append(0)

	# Trace sampling
	if _elapsed_ms - _trace_last_ms >= TRACE_INTERVAL_MS:
		var y_norm: float = _child_y / _screen_h
		_current_trace.append(Vector2(_elapsed_ms, clampf(y_norm, 0.0, 1.0)))
		_trace_last_ms = _elapsed_ms

	# Head animation
	_head_frame = int(_anim_time * 3.5) % 4
	_sprite_child.texture = _head_textures[_head_frame]
	_sprite_mother.texture = _head_textures[_head_frame]

	var scroll_px_s: float = _scroll_px_per_ms * 1000.0
	var y_old: float = _child_y_at_time(_elapsed_ms - 50.0)
	var child_vel_px_s: float = (_child_y - y_old) / 0.05

	if active_mode:
		_sprite_mother.position = Vector2(_head_x, _child_y)
		_sprite_mother.rotation = atan2(child_vel_px_s, scroll_px_s)
	else:
		var mother_y: float = _phase_y_at(_elapsed_ms, _m_top_y, _m_bot_y)
		var mother_vel_px_s: float = _phase_vel_norm_at(_elapsed_ms) * (_m_bot_y - _m_top_y) * 1000.0
		_sprite_mother.rotation = atan2(mother_vel_px_s, scroll_px_s)
		_sprite_mother.position = Vector2(_head_x, mother_y)
		_child_angle = lerpf(_child_angle, atan2(child_vel_px_s, scroll_px_s), delta * 20.0)
		_sprite_child.rotation = _child_angle
		_sprite_child.position = Vector2(_head_x, _child_y)

	var rem_s: int = int(maxf(0.0, _duration_ms - _elapsed_ms) / 1000.0)
	_timer_label.text = "%d:%02d" % [rem_s / 60, rem_s % 60]
	_phase_label.text = _current_phase_label()

	_canvas.queue_redraw()

	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

# Breathing phase y position; top_y = inhale extreme, bot_y = exhale extreme
func _phase_y_at(t_ms: float, top_y: float, bot_y: float) -> float:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + d[3]
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < inhale_ms:
		return lerpf(bot_y, top_y, t / inhale_ms)
	t -= inhale_ms
	if t < hold_top_ms:
		return top_y
	t -= hold_top_ms
	if t < exhale_ms:
		return lerpf(top_y, bot_y, t / exhale_ms)
	return bot_y

# Normalized velocity in range-fractions per ms (negative=going to top)
func _phase_vel_norm_at(t_ms: float) -> float:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + d[3]
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < inhale_ms:
		return -1.0 / inhale_ms
	t -= inhale_ms
	if t < hold_top_ms:
		return 0.0
	t -= hold_top_ms
	if t < exhale_ms:
		return 1.0 / exhale_ms
	return 0.0

# Interpolated history lookup — smooth from current position through stored history
func _child_y_at_time(t_ms: float) -> float:
	if _history_count == 0:
		return _child_y
	var time_back_ms: float = _elapsed_ms - t_ms
	if time_back_ms <= 0.0:
		return _child_y
	var last_idx: int = (_history_head - 1 + HISTORY_SLOTS) % HISTORY_SLOTS
	var time_since_last: float = _elapsed_ms - _history_last_ms
	# Sub-interval: interpolate between current position and last stored sample
	if time_back_ms <= time_since_last:
		var t: float = time_back_ms / maxf(time_since_last, 0.5)
		return lerpf(_child_y, _child_history[last_idx], t)
	# Into stored history, offset by the partial interval already consumed
	var adjusted_back: float = time_back_ms - time_since_last
	var slots_back_f: float = adjusted_back / HISTORY_INTERVAL_MS
	var slots_back: int = int(slots_back_f)
	var frac: float = slots_back_f - float(slots_back)
	if slots_back >= _history_count - 1:
		var oldest_idx: int = (_history_head - _history_count + HISTORY_SLOTS) % HISTORY_SLOTS
		return _child_history[oldest_idx]
	var idx0: int = (_history_head - 1 - slots_back + HISTORY_SLOTS) % HISTORY_SLOTS
	var idx1: int = (_history_head - 2 - slots_back + HISTORY_SLOTS) % HISTORY_SLOTS
	return lerpf(_child_history[idx0], _child_history[idx1], frac)

func _current_phase_label() -> String:
	if active_mode:
		return ""
	var d: Array = MotherG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	var t: float = fmod(_elapsed_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < d[0]:
		return "Inhale  ↑"
	t -= d[0]
	if t < d[1]:
		return "Hold"
	t -= d[1]
	if t < d[2]:
		return "Exhale  ↓"
	return "Hold"

func _do_draw(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y

	canvas.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.82, 0.70, 0.46, 1.0))

	var scroll_off: float = _elapsed_ms * _scroll_px_per_ms
	var bg_span: float = 2000.0

	# Ground texture (behind snake paths): sand ripple lines and pebbles
	for bg_item in _bg_seeds:
		if bg_item.type == 0:  # sand ripple line
			var y_base: float = bg_item.y_frac * h
			var rpts: PackedVector2Array = PackedVector2Array()
			var rx_step: float = 8.0
			var rn: int = int(w / rx_step) + 2
			rpts.resize(rn)
			for j in range(rn):
				var rx: float = float(j) * rx_step
				rpts[j] = Vector2(rx, y_base + bg_item.amp * sin((rx + scroll_off) * TAU / bg_item.period + bg_item.phase))
			var rc: Color = Color(0.96, 0.88, 0.68, bg_item.alpha) if bg_item.light else Color(0.38, 0.28, 0.14, bg_item.alpha)
			canvas.draw_polyline(rpts, rc, 1.0, true)
		elif bg_item.type == 1:  # pebble
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			var sy: float = bg_item.y_frac * h
			for _si in range(2):
				var sx: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx < -6.0 or sx > w + 6.0:
					continue
				canvas.draw_circle(Vector2(sx, sy), bg_item.r, Color(0.28, 0.22, 0.13, 0.65), true, -1.0, true)

	var step: float = 2.0

	# Exact phase transition x positions for jitter-free corners
	var _d: Array = MotherG.get_guided_durations()
	var _cycle_ms: float = _d[0] + _d[1] + _d[2] + _d[3]
	var _t_left: float = _elapsed_ms - (_head_x + MOTHER_W) / _scroll_px_per_ms
	var _trans_in_cycle: Array = [0.0, _d[0], _d[0] + _d[1], _d[0] + _d[1] + _d[2]]
	var _extra_xs: Array = []
	var _ct: float = floor(_t_left / _cycle_ms) * _cycle_ms
	while _ct <= _elapsed_ms + _cycle_ms:
		for _off in _trans_in_cycle:
			var _tt: float = _ct + _off
			if _tt >= _t_left and _tt <= _elapsed_ms:
				_extra_xs.append(_head_x - (_elapsed_ms - _tt) * _scroll_px_per_ms)
		_ct += _cycle_ms
	_extra_xs.sort()

	# --- Mother body ---
	if active_mode:
		# In active mode the mother follows the player — draw using child history
		if _history_count > 4:
			var reliable_px_a: float = minf(float(_history_count - 4) * HISTORY_INTERVAL_MS * _scroll_px_per_ms, _head_x + MOTHER_W)
			var n_ma: int = int(reliable_px_a / step) + 2
			if n_ma >= 2:
				var mother_pts_a: PackedVector2Array = PackedVector2Array()
				for i in range(n_ma):
					var x: float = _head_x - float(i) * step
					if x < -MOTHER_W:
						break
					var t_at_x: float = _elapsed_ms - (_head_x - x) / _scroll_px_per_ms
					mother_pts_a.append(Vector2(x, _child_y_at_time(t_at_x)))
				if mother_pts_a.size() >= 2:
					canvas.draw_polyline(mother_pts_a, Color(0.18, 0.82, 0.22, 0.92), MOTHER_W, true)
					canvas.draw_polyline(mother_pts_a, Color(0.55, 1.0, 0.60, 0.28), MOTHER_W * 0.38, true)
	else:
		# Guided mode: mother path from preset, starts before left edge so endpoint cap is hidden
		var mother_pts: PackedVector2Array = PackedVector2Array()
		var _mx: float = -MOTHER_W
		var _ex_idx: int = 0
		while _mx <= _head_x + step:
			while _ex_idx < _extra_xs.size() and _extra_xs[_ex_idx] < _mx:
				var _ex: float = _extra_xs[_ex_idx]
				if _ex >= -MOTHER_W and _ex <= _head_x:
					mother_pts.append(Vector2(_ex, _phase_y_at(_elapsed_ms - (_head_x - _ex) / _scroll_px_per_ms, _m_top_y, _m_bot_y)))
				_ex_idx += 1
			if _mx <= _head_x:
				mother_pts.append(Vector2(_mx, _phase_y_at(_elapsed_ms - (_head_x - _mx) / _scroll_px_per_ms, _m_top_y, _m_bot_y)))
			_mx += step
		canvas.draw_polyline(mother_pts, Color(0.18, 0.82, 0.22, 0.92), MOTHER_W, true)
		canvas.draw_polyline(mother_pts, Color(0.55, 1.0, 0.60, 0.28), MOTHER_W * 0.38, true)

		# --- Child body — break at left edge to avoid tail jitter ---
		if _history_count > 4:
			var reliable_px: float = minf(float(_history_count - 4) * HISTORY_INTERVAL_MS * _scroll_px_per_ms, _head_x)
			var n_child: int = int(reliable_px / step) + 2
			if n_child >= 2:
				var child_pts: PackedVector2Array = PackedVector2Array()
				for i in range(n_child):
					var x: float = _head_x - float(i) * step
					if x < -CHILD_W:
						break
					var t_at_x: float = _elapsed_ms - (_head_x - x) / _scroll_px_per_ms
					child_pts.append(Vector2(x, _child_y_at_time(t_at_x)))
				if child_pts.size() >= 2:
					canvas.draw_polyline(child_pts, Color(0.30, 0.25, 0.90, 0.92), CHILD_W, true)
					canvas.draw_polyline(child_pts, Color(0.7, 0.85, 1.0, 0.20), CHILD_W * 0.35, true)

	# Ground objects (drawn over snake — same ground level): bushes and beetles
	for bg_item in _bg_seeds:
		if bg_item.type == 2:  # dry bush with wind rotation and gentle bob
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			for _si in range(2):
				var sx: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx + bg_item.r * 2.0 < -5.0 or sx - bg_item.r * 2.0 > w + 5.0:
					continue
				var rot_angle: float = sin(_elapsed_ms * 0.0015 + bg_item.phase) * 0.4
				var bob_y: float = sin(_elapsed_ms * 0.0022 + bg_item.phase * 0.7) * 4.0
				var sy: float = bg_item.y_frac * h + bob_y
				var bc: Color = Color(0.42, 0.30, 0.14, 0.75)
				for sp in bg_item.spikes:
					var total_a: float = sp.a + rot_angle
					var ex: float = sx + cos(total_a) * bg_item.r * sp.r
					var ey: float = sy + sin(total_a) * bg_item.r * sp.r
					canvas.draw_line(Vector2(sx, sy), Vector2(ex, ey), bc, 1.4, true)
				canvas.draw_circle(Vector2(sx, sy), bg_item.r * 0.18, bc, true, -1.0, true)
		elif bg_item.type == 3:  # beetle with body jitter and walking legs
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			var base_sy: float = bg_item.y_frac * h
			for _si in range(2):
				var sx_base: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx_base < -20.0 or sx_base > w + 20.0:
					continue
				var sx: float = sx_base + sin(_elapsed_ms * 0.0031 + bg_item.phase) * 0.5
				var sy: float = base_sy + sin(_elapsed_ms * 0.0047 + bg_item.phase * 1.4) * 0.35
				var col: Color = Color(0.06, 0.06, 0.04, 0.90)
				var bw_b: float = 7.0
				var bh_b: float = 4.5
				var bpts: PackedVector2Array = PackedVector2Array()
				for k in range(10):
					var a: float = float(k) / 10.0 * TAU
					bpts.append(Vector2(sx + cos(a) * bw_b, sy + sin(a) * bh_b))
				canvas.draw_colored_polygon(bpts, col)
				# 3 pairs of walking legs, radiating outward from ellipse surface
				var walk_t: float = _elapsed_ms * 0.006 + bg_item.phase
				var leg_len_b: float = 3.2
				var leg_dxs: Array = [-3.8, 0.0, 3.8]
				var walk_phases: Array = [0.0, PI, 0.0]
				for li in range(3):
					var dx: float = leg_dxs[li]
					var fy: float = sqrt(maxf(0.0, 1.0 - (dx / bw_b) * (dx / bw_b)))
					var y_top: float = sy - bh_b * fy
					var y_bot: float = sy + bh_b * fy
					var lx: float = sx + dx
					var walk_ang: float = 0.28 * sin(walk_t + walk_phases[li])
					# Front legs (li=0) tilt forward; rear (li=2) tilt backward
					var fwd: float = (float(li) - 1.0) * 0.4
					var ang_top: float = -PI / 2.0 + fwd + walk_ang
					var ang_bot: float = PI / 2.0 - fwd + walk_ang
					canvas.draw_line(
						Vector2(lx, y_top),
						Vector2(lx + cos(ang_top) * leg_len_b, y_top + sin(ang_top) * leg_len_b),
						col, 1.0, true)
					canvas.draw_line(
						Vector2(lx, y_bot),
						Vector2(lx + cos(ang_bot) * leg_len_b, y_bot + sin(ang_bot) * leg_len_b),
						col, 1.0, true)


func get_session_score(didwin: bool, wasaborted: bool) -> Array:
	return [didwin, wasaborted, int(_duration_ms / 60000.0), _session_ps, _rt_ms]

func get_computed_phases() -> Array:
	return _computed_phases

func _fv_ms(ms: float) -> String:
	var r: float = round(ms / 500.0) / 2.0
	if r == float(int(r)):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	_sprite_child.visible = false
	_sprite_mother.visible = false
	$SessionOverlay.hide()

	if _current_trace.size() > 1:
		_trace_segments.append(_current_trace)
	_current_trace = []

	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60

	var phases: Array = _compute_phase_durations(_key_poll)
	_computed_phases = phases
	var minhale: float = phases[0]
	var mhold_top: float = phases[1]
	var mexhale: float = phases[2]
	var mhold_bot: float = phases[3]
	var has_data: bool = minhale + mexhale > 100.0

	var d: Array = MotherG.get_guided_durations() if not active_mode else []
	if active_mode:
		if has_data:
			_result_label.text = "Session: %d:%02d min\nPattern saved for next guided session" % [dur_min, dur_sec]
			_populate_phase_grid([minhale, mhold_top, mexhale, mhold_bot], [])
		else:
			_result_label.text = "Session: %d:%02d min\nNo breathing data detected" % [dur_min, dur_sec]
			_populate_phase_grid([], [])
	else:
		_session_ps = 0
		if has_data:
			var err: float = 0.0
			err += absf(minhale - d[0]) / maxf(d[0], 1.0)
			err += absf(mhold_top - d[1]) / maxf(d[1], 1.0)
			err += absf(mexhale - d[2]) / maxf(d[2], 1.0)
			err += absf(mhold_bot - d[3]) / maxf(d[3], 1.0)
			err /= 4.0
			_session_ps = clampi(roundi((1.0 - minf(err, 1.0)) * 100.0), 0, 100)
			game.add_score_and_time(_session_ps, 0, true)
		_result_label.text = "Session: %d:%02d min    Score: %d/100" % [dur_min, dur_sec, _session_ps]
		if has_data:
			_populate_phase_grid([minhale, mhold_top, mexhale, mhold_bot], d)
		else:
			_result_label.text += "\nNo breathing data detected"
			_populate_phase_grid([], [])

	if not active_mode and has_data:
		var mother_cmds: Array = _get_mother_commands()
		_rt_ms = calc_reaction_time(mother_cmds, _key_poll)
		_reaction_label.text = "Avg reaction time: %d ms" % _rt_ms
		_reaction_label.visible = true
	else:
		_rt_ms = 0
		_reaction_label.visible = false

	if _graph != null:
		_graph.visible = true
		var graph_mother: Array = _get_mother_commands() if not active_mode else []
		var graph_duration_ms: float = _key_poll.size() * KEY_POLL_INTERVAL_MS
		_graph.call("set_data", _key_poll, graph_mother, graph_duration_ms)
		_graph.queue_redraw()

	_results_panel.show()
	sig_session_done.emit()

func _populate_phase_grid(phases: Array, durations: Array) -> void:
	for child in _phase_grid.get_children():
		child.queue_free()
	if phases.size() < 4:
		return
	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 28 if MainGlobals.is_mobile() else 20
	var has_target: bool = durations.size() >= 4
	_phase_grid.columns = 3 if has_target else 2
	var rows: Array = [["Inhale", phases[0], durations[0] if has_target else 0.0]]
	if (has_target and durations[1] > 200.0) or (not has_target and phases[1] > 200.0):
		rows.append(["Hold air", phases[1], durations[1] if has_target else 0.0])
	rows.append(["Exhale", phases[2], durations[2] if has_target else 0.0])
	if (has_target and durations[3] > 200.0) or (not has_target and phases[3] > 200.0):
		rows.append(["Hold empty", phases[3], durations[3] if has_target else 0.0])
	for row in rows:
		var lbl_n: Label = Label.new()
		lbl_n.text = str(row[0]) + ":"
		lbl_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_n.add_theme_font_override("font", font)
		lbl_n.add_theme_font_size_override("font_size", fs)
		lbl_n.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.80))
		_phase_grid.add_child(lbl_n)
		var lbl_v: Label = Label.new()
		lbl_v.text = "%.1fs" % [float(row[1]) / 1000.0]
		lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_v.add_theme_font_override("font", font)
		lbl_v.add_theme_font_size_override("font_size", fs)
		lbl_v.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
		_phase_grid.add_child(lbl_v)
		if has_target:
			var lbl_t: Label = Label.new()
			lbl_t.text = "(target %.1fs)" % [float(row[2]) / 1000.0]
			lbl_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl_t.add_theme_font_override("font", font)
			lbl_t.add_theme_font_size_override("font_size", fs)
			lbl_t.add_theme_color_override("font_color", Color(0.70, 0.88, 0.72, 0.72))
			_phase_grid.add_child(lbl_t)

# keys: Array of int polled every 50ms — 1=up pressed, 2=down pressed, 0=neither
# Returns [inhale_ms, hold_top_ms, exhale_ms, hold_bot_ms] as average durations in ms
func _compute_phase_durations(keys: Array) -> Array:
	var res:Array[float] = [0.0, 0.0, 0.0, 0.0]

	# print("got %d keys" % [keys.size()])

	# var num_vals = [0,0,0]
	# for i in keys.size():
	# 	num_vals[keys[i]] += 1

	# print("num keys: ", num_vals)

	#first, fill outlier gaps
	var maxgap:int = 2
	# var ngaps_filled = 0
	for i in range(maxgap + 1,keys.size()):
		if keys[i] != 0 and keys[i-1] == 0 and keys[i-maxgap-1] == keys[i]:
			for j in range(i-maxgap,i):
				keys[j] = keys[i]
			# ngaps_filled += 1
	# print("filled %d gaps" % ngaps_filled)	

	#second, find consecutive phases
	var i_started = 0
	var phase = -1
	var sums:Array[int] = [0,0,0,0]
	var nums:Array[int] = [0,0,0,0]
	for i in keys.size():
		if keys[i] == 1:
			if phase != 0:
				if phase == 3:
					nums[3] += 1
					sums[3] += i - i_started + 1
				i_started = i
				phase = 0
				# print("set phase 0")
		elif keys[i] == 2:
			if phase != 2:
				if phase == 1:
					nums[1] += 1
					sums[1] += i - i_started + 1
				i_started = i
				phase = 2
				# print("set phase 2")
		else:			
			if phase == 0:
				nums[0] += 1
				sums[0] += i - i_started + 1
				i_started = i
				phase = 1
				# print("set phase 1")
			elif phase == 2:
				nums[2] += 1
				sums[2] += i - i_started + 1
				i_started = i
				phase = 3
				# print("set phase 3")

	for i in 4:
		res[i] = float(sums[i]) / (float(nums[i]) + 1e-6) * 50.0
		# print("for phase i got sum %d num %d res %.1f" % [sums[i],nums[i],res[i]])

	return res


func _get_mother_commands() -> Array:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var hold_bot_ms: float = d[3]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + hold_bot_ms
	if cycle_ms < 1.0:
		return []
	var result: Array = []
	for i: int in _key_poll.size():
		var t: float = fmod(float(i) * KEY_POLL_INTERVAL_MS, cycle_ms)
		if t < inhale_ms:
			result.append(1)
		elif t < inhale_ms + hold_top_ms:
			result.append(0)
		elif t < inhale_ms + hold_top_ms + exhale_ms:
			result.append(2)
		else:
			result.append(0)
	return result

func calc_reaction_time(mother_commands: Array, child_actions: Array) -> int:
	# Returns mean reaction time in ms (center 80th percentile, slots * 50ms).
	# Each sample: slots until child makes the same phase transition as mother (0 = reacted early).
	# old: return int(dt * float(sum) / (num + 1e-6) + 0.5)  # plain mean of all samples
	var dt: float = 50.0
	var look_back: int = int(200.0 / dt + 0.5)    # 4 slots — child reacted early window
	var look_ahead: int = int(2000.0 / dt + 0.5)  # 40 slots — max latency to measure
	var actual_commands: Array = []

	for i in range(1, mother_commands.size()):
		if mother_commands[i] != mother_commands[i - 1]:
			var found_back: int = -1
			var found_ahead: int = -1
			for j in range(i - 1, max(1, i - look_back) - 1, -1):
				if child_actions[j] == mother_commands[i] and child_actions[j - 1] == mother_commands[i - 1]:
					found_back = j
					break
			for j in range(i, min(child_actions.size(), i + look_ahead + 1)):
				if child_actions[j] == mother_commands[i] and child_actions[j - 1] == mother_commands[i - 1]:
					found_ahead = j
					break
			if found_back >= 0 and (found_ahead < 0 or i - found_back < found_ahead - i):
				actual_commands.append(0)  # child reacted early
			elif found_ahead >= 0:
				actual_commands.append(found_ahead - i)
			# else: neither found — skip (missing reaction, not counted)

	if actual_commands.is_empty():
		return 0

	actual_commands.sort()
	var cut: int = maxi(0, int(actual_commands.size() * 0.10))
	var trimmed: Array = actual_commands.slice(cut, actual_commands.size() - cut)
	if trimmed.is_empty():
		trimmed = actual_commands
		# return int(dt * float(actual_commands[actual_commands.size() / 2]) + 0.5)
	var s: float = 0.0
	for v in trimmed:
		s += float(v)
	return int(dt * s / float(trimmed.size()) + 0.5)

func _on_again_pressed() -> void:
	_results_panel.hide()
	game.reset(true)
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
