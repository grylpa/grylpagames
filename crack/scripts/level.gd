extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

const LONG_SPEED: float = 45.0   # deg/s long arm on keyboard
const SHORT_SPEED: float = 45.0  # deg/s short arm on keyboard

var game: GenericGameUtil
var _duration_ms: float = 180000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

# Arms — free rotation, no clamping
var _long_angle: float = 0.0
var _short_angle: float = 0.0

# Gesture state
var _gesture: int = 0         # 1=swipe_up, -1=swipe_down, 0=holding
var _last_swipe_dir: int = 0  # 1 or -1 (direction of most recent swipe)
var _gesture_timer_ms: float = 0.0

# Sequence state machine: track last 4 actions
# States: -1=waiting for swipe_up, 0=waiting for hold_after_up,
#          1=waiting for swipe_down, 2=waiting for hold_after_down
var _seq_state: int = -1
var _seq_durations: Array = []  # durations (ms) of completed actions this sequence

# Display: up to 4 most recent completed action durations (seconds), for feedback
var _display_durations: Array = []

var _safe_open: bool = false
var _score: int = 0

# Phase duration tracking for stats
var _swipe_up_ms: Array = []
var _hold_top_ms: Array = []
var _swipe_down_ms: Array = []
var _hold_bot_ms: Array = []
var _unlock_times_ms: Array = []

# Stats / graph
var _graph: Control = null
var _phase_grid: GridContainer
var _trace_segments: Array = []
var _current_trace: Array = []
var _trace_last_ms: float = 0.0
const TRACE_INTERVAL_MS_C: float = 200.0

var _key_poll: Array = []
const KEY_POLL_INTERVAL_MS_C: float = 50.0

var active_mode: bool = false
var _computed_phases: Array = [0.0, 0.0, 0.0, 0.0]

var _screen_w: float = 680.0
var _screen_h: float = 788.0

@onready var _canvas: Control = $CrackCanvas
@onready var _timer_label: Label = $SessionOverlay/TimerLabel
@onready var _phase_label: Label = $SessionOverlay/PhaseLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _result_label: Label = $ResultsPanel/Margin/VBox/ResultLabel

func _ready() -> void:
	game = CrackG.game
	_screen_w = float(MainGlobals.screen_size.x)
	_screen_h = float(MainGlobals.screen_size.y)

	var _f: Font = MainGlobals.get_system_sans_font()
	var _t: Theme = Theme.new()
	_t.set_font("font", "Label", _f)
	_t.set_font("font", "Button", _f)
	$SessionOverlay.theme = _t
	_results_panel.theme = _t
	if OS.get_name() == "Web":
		_phase_label.custom_minimum_size.x = _screen_w * 0.75
		_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
	var door_h_r: float = _screen_h * 0.80
	var door_y_r: float = (_screen_h - door_h_r) * 0.5 + _screen_h * 0.02
	var mobile_r: bool = MainGlobals.is_mobile()
	var fs_phase: int = 42 if mobile_r else 22
	_phase_label.offset_bottom = door_y_r - 8.0
	_phase_label.offset_top = _phase_label.offset_bottom - float(fs_phase) - 8.0
	if mobile_r:
		_timer_label.add_theme_font_size_override("font_size", 46)
		_timer_label.offset_bottom = 62.0
		_phase_label.add_theme_font_size_override("font_size", 42)
		$ResultsPanel/Margin/VBox/TitleLabel.add_theme_font_size_override("font_size", 34)
		_result_label.add_theme_font_size_override("font_size", 28)
		$ResultsPanel/Margin/VBox/DoneButton.add_theme_font_size_override("font_size", 36)

	_graph = Control.new()
	_graph.set_script(load("res://mother/scripts/key_graph.gd"))
	_graph.set("bg_color", Color(0.04, 0.07, 0.14, 1.0))
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(0, 100)
	_graph.visible = false
	var vbox_c: Node = $ResultsPanel/Margin/VBox
	vbox_c.add_child(_graph)
	vbox_c.move_child(_graph, vbox_c.get_child_count() - 2)
	var graph_spacer_c: Control = Control.new()
	graph_spacer_c.custom_minimum_size = Vector2(0, 24)
	vbox_c.add_child(graph_spacer_c)
	vbox_c.move_child(graph_spacer_c, vbox_c.get_child_count() - 2)

	var mobile_c: bool = MainGlobals.is_mobile()
	var again_btn_c: Button = Button.new()
	again_btn_c.text = "Again"
	again_btn_c.custom_minimum_size = Vector2(160, 52)
	again_btn_c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_c.add_theme_stylebox_override("normal", btn_style)
	again_btn_c.add_theme_stylebox_override("hover", btn_style)
	again_btn_c.add_theme_stylebox_override("pressed", btn_pressed)
	again_btn_c.add_theme_font_size_override("font_size", 36 if mobile_c else 26)
	again_btn_c.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	again_btn_c.pressed.connect(_on_again_pressed)
	var btn_hbox_c: HBoxContainer = HBoxContainer.new()
	btn_hbox_c.add_theme_constant_override("separation", 16)
	btn_hbox_c.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_c.add_child(btn_hbox_c)
	$ResultsPanel/Margin/VBox/DoneButton.reparent(btn_hbox_c)
	btn_hbox_c.add_child(again_btn_c)
	btn_hbox_c.move_child(again_btn_c, 0)

	_phase_grid = GridContainer.new()
	_phase_grid.columns = 3
	_phase_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_grid.add_theme_constant_override("h_separation", 24)
	_phase_grid.add_theme_constant_override("v_separation", 1 if MainGlobals.is_mobile() else 4)
	var _grid_hbox_c: HBoxContainer = HBoxContainer.new()
	_grid_hbox_c.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_hbox_c.add_child(_phase_grid)
	vbox_c.add_child(_grid_hbox_c)
	vbox_c.move_child(_grid_hbox_c, 2)

	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.offset_top = 0.0
	_results_panel.offset_bottom = 0.0
	_results_panel.offset_left = 0.0
	_results_panel.offset_right = 0.0
	var margin_ctrl_c: Control = $ResultsPanel/Margin as Control
	margin_ctrl_c.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + (48 if MainGlobals.is_mobile() else 16))
	margin_ctrl_c.add_theme_constant_override("margin_top", 8)
	($ResultsPanel/Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 6)
	_results_panel.hide()

func new_game() -> void:
	_duration_ms = CrackG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_long_angle = 0.0
	_short_angle = 0.0
	_gesture = 0
	_last_swipe_dir = 0
	_gesture_timer_ms = 0.0
	_seq_state = -1
	_seq_durations = []
	_display_durations = []
	_safe_open = false
	_score = 0
	_swipe_up_ms = []
	_hold_top_ms = []
	_swipe_down_ms = []
	_hold_bot_ms = []
	_unlock_times_ms = []
	_trace_segments = []
	_current_trace = []
	_trace_last_ms = 0.0
	_key_poll = []
	_computed_phases = [0.0, 0.0, 0.0, 0.0]
	game.level_is_ready = true
	game.playing = true
	$SessionOverlay.show()
	_phase_label.visible = CrackG.show_instructions
	_results_panel.hide()
	_canvas.queue_redraw()

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	_elapsed_ms += delta * 1000.0
	_gesture_timer_ms += delta * 1000.0

	# Trace sampling
	if _elapsed_ms - _trace_last_ms >= TRACE_INTERVAL_MS_C:
		var y_norm: float = 0.5
		if _gesture == 1: y_norm = 0.05
		elif _gesture == -1: y_norm = 0.95
		elif _last_swipe_dir == 1: y_norm = 0.25
		elif _last_swipe_dir == -1: y_norm = 0.75
		_current_trace.append(Vector2(_elapsed_ms, y_norm))
		_trace_last_ms = _elapsed_ms

	# Key poll for phase measurement
	var expected_slots_c: int = int(_elapsed_ms / KEY_POLL_INTERVAL_MS_C)
	while _key_poll.size() < expected_slots_c:
		if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
			_key_poll.append(1)
		elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
			_key_poll.append(2)
		else:
			_key_poll.append(0)

	# Keyboard gesture polling
	if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
		if _gesture != 1:
			_on_gesture_changed(1)
	elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
		if _gesture != -1:
			_on_gesture_changed(-1)
	else:
		if _gesture != 0:
			_on_gesture_changed(0)

	# Arms move only from user action — no pattern knowledge
	if _gesture == 1:
		_long_angle += LONG_SPEED * delta
	elif _gesture == -1:
		_long_angle -= LONG_SPEED * delta

	if _gesture == 0 and _last_swipe_dir == 1:
		_short_angle += SHORT_SPEED * delta
	elif _gesture == 0 and _last_swipe_dir == -1:
		_short_angle -= SHORT_SPEED * delta

	var rem_s: int = int(maxf(0.0, _duration_ms - _elapsed_ms) / 1000.0)
	_timer_label.text = "%d:%02d" % [rem_s / 60, rem_s % 60]
	_phase_label.text = _current_phase_label()

	_canvas.queue_redraw()

	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

func _on_gesture_changed(new_gesture: int) -> void:
	var prev: int = _gesture
	if prev == new_gesture:
		return
	var duration_ms: float = _gesture_timer_ms
	_gesture_timer_ms = 0.0
	_gesture = new_gesture
	# Record the completed action before updating direction
	_on_action_completed(prev, _last_swipe_dir, duration_ms)
	# Update direction for new swipe
	if new_gesture != 0:
		_last_swipe_dir = new_gesture

func _on_action_completed(action_type: int, prev_swipe_dir: int, duration_ms: float) -> void:
	# Ignore the initial "0-holding-from-nothing" at game start
	if action_type == 0 and prev_swipe_dir == 0:
		return
	# Ignore very short accidental flickers
	if duration_ms < 80.0:
		return

	# Record phase durations for stats
	if action_type == 1:
		_swipe_up_ms.append(duration_ms)
	elif action_type == -1:
		_swipe_down_ms.append(duration_ms)
	elif action_type == 0 and prev_swipe_dir == 1:
		_hold_top_ms.append(duration_ms)
	elif action_type == 0 and prev_swipe_dir == -1:
		_hold_bot_ms.append(duration_ms)

	var dur_s: float = duration_ms / 1000.0
	_display_durations.append(dur_s)
	if _display_durations.size() > 4:
		_display_durations.remove_at(0)

	# Advance the 4-step sequence state machine
	match _seq_state:
		-1:
			if action_type == 1:  # completed swipe_up
				_seq_state = 0
				_seq_durations = [duration_ms]
		0:
			if action_type == 0 and prev_swipe_dir == 1:  # hold after swipe_up
				_seq_state = 1
				_seq_durations.append(duration_ms)
			else:
				_reset_seq()
				if action_type == 1:
					_seq_state = 0
					_seq_durations = [duration_ms]
		1:
			if action_type == -1:  # completed swipe_down
				_seq_state = 2
				_seq_durations.append(duration_ms)
			else:
				_reset_seq()
		2:
			if action_type == 0 and prev_swipe_dir == -1:  # hold after swipe_down
				_seq_durations.append(duration_ms)
				_try_score()
				_reset_seq()
			else:
				_reset_seq()
				if action_type == 1:
					_seq_state = 0
					_seq_durations = [duration_ms]

func _reset_seq() -> void:
	_seq_state = -1
	_seq_durations = []

func _try_score() -> void:
	if active_mode:
		return
	var d: Array = CrackG.get_guided_durations()
	var thr: float = CrackG.TIMING_THRESHOLD_MS
	if (_seq_durations.size() == 4 and
		absf(_seq_durations[0] - d[0]) < thr and
		absf(_seq_durations[1] - d[1]) < thr and
		absf(_seq_durations[2] - d[2]) < thr and
		absf(_seq_durations[3] - d[3]) < thr):
		_score += 1
		game.add_score_and_time(1, 0)
		_safe_open = not _safe_open
		_unlock_times_ms.append(_elapsed_ms)

func _current_phase_label() -> String:
	if active_mode:
		return ""
	var d: Array = CrackG.get_guided_durations()
	var t: float = fmod(_elapsed_ms, d[0] + d[1] + d[2] + d[3])
	if t < d[0]:
		return "Inhale  ↑"
	t -= d[0]
	if t < d[1]:
		return "Hold  —"
	t -= d[1]
	if t < d[2]:
		return "Exhale  ↓"
	return "Hold  —"

func _do_draw(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y
	var cx: float = w * 0.5
	var cy: float = h * 0.5

	canvas.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.05, 0.09, 1.0))

	var door_w: float = w * 0.88
	var door_h: float = h * 0.80
	var door_x: float = (w - door_w) * 0.5
	var door_y: float = (h - door_h) * 0.5 + h * 0.02
	var dial_r: float = minf(door_w, door_h) * 0.26
	var score_font: Font = MainGlobals.get_system_sans_font()
	var text_x: float = door_x
	var text_w: float = door_w

	# Dial color palette — blue when locked, muted green when open
	var op: bool = _safe_open
	var disc_a: Color    = Color(0.18, 0.36, 0.24) if op else Color(0.34, 0.38, 0.54)
	var disc_b: Color    = Color(0.22, 0.40, 0.28) if op else Color(0.38, 0.42, 0.58)
	var disc_ring: Color = Color(0.12, 0.26, 0.18) if op else Color(0.26, 0.30, 0.46)
	var bz_bg: Color     = Color(0.12, 0.24, 0.16) if op else Color(0.16, 0.18, 0.28)
	var bz_rim: Color    = Color(0.36, 0.64, 0.46) if op else Color(0.54, 0.58, 0.76)
	var bz_in: Color     = Color(0.14, 0.26, 0.18) if op else Color(0.22, 0.26, 0.38)
	var bz_in_rim: Color = Color(0.40, 0.68, 0.50) if op else Color(0.58, 0.62, 0.80)
	var tk_maj: Color    = Color(0.68, 0.88, 0.74) if op else Color(0.86, 0.90, 0.98)
	var tk_min: Color    = Color(0.32, 0.56, 0.42) if op else Color(0.52, 0.58, 0.74)
	var num_c: Color     = Color(0.76, 0.94, 0.82) if op else Color(0.92, 0.94, 1.00)
	var knb_c: Color     = Color(0.18, 0.36, 0.24) if op else Color(0.32, 0.36, 0.52)
	var knb_rim: Color   = Color(0.38, 0.66, 0.48) if op else Color(0.54, 0.62, 0.82)
	var knb_in: Color    = Color(0.14, 0.28, 0.20) if op else Color(0.24, 0.28, 0.44)
	var knb_inr: Color   = Color(0.36, 0.62, 0.46) if op else Color(0.50, 0.58, 0.78)
	var knb_dot: Color   = Color(0.48, 0.74, 0.58) if op else Color(0.64, 0.72, 0.90)
	var score_c: Color   = Color(0.68, 0.92, 0.76) if op else Color(0.86, 0.92, 1.00)
	var hdl_c: Color     = Color(0.16, 0.30, 0.20) if op else Color(0.26, 0.30, 0.44)
	var hdl_rim: Color   = Color(0.34, 0.58, 0.42) if op else Color(0.46, 0.52, 0.70)

	# ---- Door structure (always the same) ----
	canvas.draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(0.14, 0.16, 0.24, 1.0))
	var frame_inset: float = 14.0
	canvas.draw_rect(Rect2(door_x + frame_inset, door_y + frame_inset,
		door_w - frame_inset * 2.0, door_h - frame_inset * 2.0),
		Color(0.17, 0.20, 0.30, 1.0))
	canvas.draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(0.24, 0.30, 0.50, 1.0), false, 4.0)

	# Bolts — warm bronze
	var bolt_r: float = 10.0
	var bolt_margin: float = 24.0
	for bp in [
		Vector2(door_x + bolt_margin, door_y + bolt_margin),
		Vector2(door_x + door_w - bolt_margin, door_y + bolt_margin),
		Vector2(door_x + bolt_margin, door_y + door_h - bolt_margin),
		Vector2(door_x + door_w - bolt_margin, door_y + door_h - bolt_margin),
	]:
		canvas.draw_circle(bp, bolt_r, Color(0.26, 0.22, 0.18, 1.0), true, -1.0, true)
		canvas.draw_circle(bp, bolt_r, Color(0.54, 0.48, 0.36, 1.0), false, 2.0, true)
		canvas.draw_circle(bp, bolt_r * 0.35, Color(0.72, 0.66, 0.50, 1.0), true, -1.0, true)

	# Handle bar
	var handle_x: float = door_x + door_w - 32.0
	canvas.draw_rect(Rect2(handle_x - 9.0, cy - 40.0, 18.0, 80.0), hdl_c)
	canvas.draw_rect(Rect2(handle_x - 9.0, cy - 40.0, 18.0, 80.0), hdl_rim, false, 2.0)

	# ---- Combination lock dial ----
	var dcx: float = cx
	var dcy: float = cy
	var bezel_r: float = dial_r + 18.0

	canvas.draw_circle(Vector2(dcx, dcy), bezel_r + 8.0, bz_bg, true, -1.0, true)
	canvas.draw_circle(Vector2(dcx, dcy), bezel_r + 8.0, bz_rim, false, 3.5, true)
	canvas.draw_circle(Vector2(dcx, dcy), bezel_r, bz_in, true, -1.0, true)
	canvas.draw_circle(Vector2(dcx, dcy), bezel_r, bz_in_rim, false, 2.0, true)

	# Gold indicator triangle (fixed)
	var ind_pts: PackedVector2Array = PackedVector2Array([
		Vector2(dcx - 7.0, dcy - bezel_r - 6.0),
		Vector2(dcx + 7.0, dcy - bezel_r - 6.0),
		Vector2(dcx, dcy - bezel_r + 10.0),
	])
	canvas.draw_colored_polygon(ind_pts, Color(0.95, 0.78, 0.08, 1.0))

	# Rotating disc
	var dial_rot: float = deg_to_rad(_long_angle)
	canvas.draw_set_transform(Vector2(dcx, dcy), dial_rot, Vector2.ONE)

	canvas.draw_circle(Vector2.ZERO, dial_r, disc_a, true, -1.0, true)
	canvas.draw_circle(Vector2.ZERO, dial_r * 0.88, disc_b, true, -1.0, true)
	canvas.draw_circle(Vector2.ZERO, dial_r * 0.88, disc_ring, false, 2.0, true)

	for i in range(100):
		var a: float = deg_to_rad(float(i) * 3.6)
		var is_major: bool = i % 10 == 0
		var is_half: bool = i % 5 == 0
		var tlen: float = 15.0 if is_major else (8.0 if is_half else 4.0)
		var tw: float = 2.5 if is_major else 1.0
		canvas.draw_line(
			Vector2(cos(a) * (dial_r - tlen), sin(a) * (dial_r - tlen)),
			Vector2(cos(a) * (dial_r - 1.0), sin(a) * (dial_r - 1.0)),
			tk_maj if is_major else tk_min, tw, true)

	# Numbers — each rotated perpendicular to its tick
	var num_fs: int = 22 if MainGlobals.is_mobile() else 15
	var num_clip: float = 34.0 if MainGlobals.is_mobile() else 24.0
	var num_r: float = dial_r - 26.0
	for i in range(10):
		var a: float = deg_to_rad(float(i) * 36.0 - 90.0)
		var phi: float = a + dial_rot
		var num_screen: Vector2 = Vector2(dcx + cos(phi) * num_r, dcy + sin(phi) * num_r)
		canvas.draw_set_transform(num_screen, phi + PI * 0.5, Vector2.ONE)
		canvas.draw_string(score_font, Vector2(-num_clip * 0.5, -num_fs * 0.5), str(i * 10),
			HORIZONTAL_ALIGNMENT_CENTER, num_clip, num_fs, num_c)

	# Back to dial-local for the knob
	canvas.draw_set_transform(Vector2(dcx, dcy), dial_rot, Vector2.ONE)

	# Knob — very gentle bumps (low radius ratio)
	var knob_r: float = dial_r * 0.275
	var knob_inner_r: float = dial_r * 0.258
	var n_teeth: int = 35
	var knob_pts: PackedVector2Array = PackedVector2Array()
	for i in range(n_teeth * 2):
		var a_k: float = deg_to_rad(float(i) * 360.0 / float(n_teeth * 2))
		var r_k: float = knob_r if i % 2 == 0 else knob_inner_r
		knob_pts.append(Vector2(cos(a_k) * r_k, sin(a_k) * r_k))
	canvas.draw_colored_polygon(knob_pts, knb_c)
	var knob_close: PackedVector2Array = PackedVector2Array(knob_pts)
	knob_close.append(knob_pts[0])
	canvas.draw_polyline(knob_close, knb_rim, 1.5, true)
	canvas.draw_circle(Vector2.ZERO, knob_inner_r * 0.74, knb_in, true, -1.0, true)
	canvas.draw_circle(Vector2.ZERO, knob_inner_r * 0.74, knb_inr, false, 1.5, true)
	canvas.draw_circle(Vector2.ZERO, 5.0, knb_dot, true, -1.0, true)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Score
	canvas.draw_string(score_font, Vector2(door_x, door_y + door_h - 50.0),
		str(_score), HORIZONTAL_ALIGNMENT_CENTER, door_w, 52, score_c)

	# ---- HUD timing text — anchored just above the dial, working upward ----
	var mobile_d: bool = MainGlobals.is_mobile()
	var fs_dur: int = 44 if mobile_d else 30
	var fs_now: int = 32 if mobile_d else 20
	var fs_goal: int = 32 if mobile_d else 17
	var dial_top_y: float = cy - dial_r - 26.0
	var dial_gap: float = 24.0 if mobile_d else 16.0
	var line_gap: float = 4.0 if mobile_d else 5.0
	var y_goal: float = dial_top_y - dial_gap
	var y_now: float = y_goal - fs_goal - line_gap
	var y_dur: float = y_now - fs_now - line_gap
	if _display_durations.size() > 0:
		var dur_str: String = ""
		for i in range(_display_durations.size()):
			if i > 0:
				dur_str += " – "
			dur_str += "%.1f" % _display_durations[i]
		canvas.draw_string(score_font, Vector2(text_x, y_dur),
			dur_str, HORIZONTAL_ALIGNMENT_CENTER, text_w, fs_dur,
			Color(0.96, 0.88, 0.62, 0.95))
	var live_s: float = _gesture_timer_ms / 1000.0
	var gesture_name: String = "hold" if _gesture == 0 else ("↑" if _gesture == 1 else "↓")
	canvas.draw_string(score_font, Vector2(text_x, y_now),
		"Now: %.1fs %s" % [live_s, gesture_name], HORIZONTAL_ALIGNMENT_CENTER, text_w, fs_now,
		Color(0.62, 0.82, 1.00, 0.90))
	if not active_mode:
		var d: Array = CrackG.get_guided_durations()
		canvas.draw_string(score_font, Vector2(text_x, y_goal),
			"Goal:  %s – %s – %s – %s" % [_fv_ms(d[0]), _fv_ms(d[1]), _fv_ms(d[2]), _fv_ms(d[3])],
			HORIZONTAL_ALIGNMENT_CENTER, text_w, fs_goal, Color(0.62, 0.72, 0.95, 0.88))

func _avg_ms(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())

func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	$SessionOverlay.hide()

	if _current_trace.size() > 1:
		_trace_segments.append(_current_trace)

	var dur_s_total: int = int(_duration_ms / 1000.0)
	var dur_min: int = dur_s_total / 60
	var dur_sec: int = dur_s_total % 60

	var phases: Array = _compute_phase_durations(_key_poll)
	_computed_phases = phases
	var has_data: bool = phases[0] + phases[2] > 100.0
	if active_mode:
		if has_data:
			_result_label.text = "Session: %d:%02d min\nPattern saved for next guided session" % [dur_min, dur_sec]
			_populate_phase_grid(phases, [])
		else:
			_result_label.text = "Session: %d:%02d min\nNo breathing data detected" % [dur_min, dur_sec]
			_populate_phase_grid([], [])
	else:
		var d: Array = CrackG.get_guided_durations()
		var accuracy: int = _accuracy_score_c(phases)
		if has_data:
			game.add_score_and_time(accuracy, 0, true)
		_result_label.text = "Session: %d:%02d   Unlocks: %d   Score: %d/100" % [dur_min, dur_sec, _score, accuracy]
		_populate_phase_grid(phases, d)

	if _key_poll.size() > 0:
		_graph.visible = true
		var graph_duration_ms_c: float = _key_poll.size() * KEY_POLL_INTERVAL_MS_C
		_graph.call("set_data", _key_poll, [], graph_duration_ms_c)
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
	var rows: Array = [["Inhale", phases[0], durations[0] if has_target else 0.0],
		["Hold top", phases[1], durations[1] if has_target else 0.0],
		["Exhale", phases[2], durations[2] if has_target else 0.0],
		["Hold bot", phases[3], durations[3] if has_target else 0.0]]
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

func _accuracy_score_c(phases: Array) -> int:
	var d: Array = CrackG.get_guided_durations()
	if phases[0] + phases[2] < 100.0:
		return 0
	var err: float = (absf(phases[0] - d[0]) / maxf(d[0], 1.0)
		+ absf(phases[1] - d[1]) / maxf(d[1], 1.0)
		+ absf(phases[2] - d[2]) / maxf(d[2], 1.0)
		+ absf(phases[3] - d[3]) / maxf(d[3], 1.0)) / 4.0
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

func get_computed_phases() -> Array:
	return _computed_phases

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
