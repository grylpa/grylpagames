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

	var mobile_r: bool = MainGlobals.is_mobile()
	if mobile_r:
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

	var again_btn_c: Button = Button.new()
	again_btn_c.text = "Again"
	again_btn_c.custom_minimum_size = Vector2(160, 52)
	again_btn_c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_c.add_theme_stylebox_override("normal", btn_style)
	again_btn_c.add_theme_stylebox_override("hover", btn_style)
	again_btn_c.add_theme_stylebox_override("pressed", btn_pressed)
	MainGlobals.set_font_size(again_btn_c, 26)
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
	# A finger that turns straight around -- up to down with no neutral frame between -- performed
	# a hold of zero length, and the pattern has four beats whether or not one of them took any
	# time. Without this the hold simply never happens: _process polls up, then down, then neutral,
	# so a reversal inside one frame never passes through 0 and no hold action is ever generated.
	# The sequence then stalls waiting for a beat that cannot arrive, which is why the presets with
	# a 0 in them (5-0-5-0, 4-0-8-0, 4-4-8-0, 4-2-4-0) could never open the safe.
	if prev != 0 and new_gesture != 0 and prev != new_gesture:
		_on_action_completed(0, _last_swipe_dir, 0.0)
	# Update direction for new swipe
	if new_gesture != 0:
		_last_swipe_dir = new_gesture

func _on_action_completed(action_type: int, prev_swipe_dir: int, duration_ms: float) -> void:
	# Ignore the initial "0-holding-from-nothing" at game start
	if action_type == 0 and prev_swipe_dir == 0:
		return
	# Ignore very short accidental flickers -- but only on the SLIDES. The guard exists because the
	# digitized-swipe flag can drop for a frame mid-gesture; applied to holds as well, it threw away
	# every genuinely brief pause, so a fast turnaround was indistinguishable from no turnaround and
	# a 0-length hold could never be timed. A hold is not a flicker: it is a beat of the pattern,
	# and if it was short the timing check is what should say so.
	if action_type != 0 and duration_ms < 80.0:
		return

	# The coach listens here because this is where the game itself decides an action happened --
	# past the flicker guard, so a twitch the game ignored never advances a tutorial step.
	# no-ops outside tutorial mode.
	if action_type == 1:
		game.tutorial_notify("inhaled")
	elif action_type == -1:
		game.tutorial_notify("exhaled")
	elif prev_swipe_dir == 1:
		game.tutorial_notify("held_top")
	elif prev_swipe_dir == -1:
		game.tutorial_notify("held_bottom")

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
		game.tutorial_notify("unlocked")
	else:
		game.tutorial_notify("sequence_missed")

func _do_draw(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y
	var cx: float = w * 0.5
	var cy: float = h * 0.5

	canvas.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.05, 0.09, 1.0))

	# Session progress along the top edge, the same bar udbr and breathe use. It replaced a digital
	# countdown: a number counting down is something to read and do arithmetic on, which is the
	# opposite of what a breathing game wants the player doing.
	_draw_session_bar(canvas, w)

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
	var gesture_name: String = "■" if _gesture == 0 else ("▲" if _gesture == 1 else "▼")
	canvas.draw_string(score_font, Vector2(text_x, y_now),
		"Now: %.1f s %s" % [live_s, gesture_name], HORIZONTAL_ALIGNMENT_CENTER, text_w, fs_now,
		Color(0.62, 0.82, 1.00, 0.90))
	if not active_mode:
		var d: Array = CrackG.get_guided_durations()
		canvas.draw_string(score_font, Vector2(text_x, y_goal),
			"Goal:  %s – %s – %s – %s" % [_fv_ms(d[0]), _fv_ms(d[1]), _fv_ms(d[2]), _fv_ms(d[3])],
			HORIZONTAL_ALIGNMENT_CENTER, text_w, fs_goal, Color(0.62, 0.72, 0.95, 0.88))

# --- what the coach needs to point at -------------------------------------------------------
#
# The safe is drawn procedurally in _do_draw, so there are no nodes to hand the overlay. These
# recompute the same geometry from the same canvas size. Kept next to nothing else on purpose: if
# _do_draw's layout constants move, these move with them.

func _dial_center_and_radius() -> Array:
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	var door_w: float = w * 0.88
	var door_h: float = h * 0.80
	return [Vector2(w * 0.5, h * 0.5), minf(door_w, door_h) * 0.26]

func _to_screen(r: Rect2) -> Rect2:
	var tl: Vector2 = _canvas.get_global_transform() * r.position
	return Rect2(tl, r.size)

# Just the goal line -- the combination itself. The three-line block below is mostly empty before
# the demo has run, so framing all of it to say "here is the combination" points at two blank rows
# and one small line of text.
func tutorial_goal_rect() -> Rect2:
	var d: Array = _dial_center_and_radius()
	var mobile_d: bool = MainGlobals.is_mobile()
	var fs_goal: int = 32 if mobile_d else 17
	var base: float = float(d[0].y) - float(d[1]) - 26.0 - (24.0 if mobile_d else 16.0)
	var w: float = _canvas.size.x * 0.7
	var x: float = (_canvas.size.x - w) * 0.5
	return _to_screen(Rect2(Vector2(x, base - float(fs_goal) - 8.0), Vector2(w, float(fs_goal) + 16.0)))

# Ends the tutorial the way a real session ends: on the summary screen, with a session behind it.
#
# The demo showed four beats a few times over; what it cannot show is what twenty minutes of them
# adds up to, which is the thing the player is actually signing up for. Rather than describe that
# screen, the tutorial produces one. The run beneath it is invented -- there was no session -- but
# it is invented the way a real one behaves: the preset, breathed with a human amount of drift, for
# a believable length of time, with a handful of sequences missed.
#
# It writes nothing. `game.tutorial_mode` guards every save in generic_game_util.gd, and the
# `learned_*` write in main.gd is behind `not guided_mode`, which the tutorial has forced off.
const _SUMMARY_MINUTES: float = 3.0

func tutorial_show_summary() -> void:
	var d: Array = CrackG.get_guided_durations()
	var base: Array = [float(d[0]) / 1000.0, float(d[1]) / 1000.0,
		float(d[2]) / 1000.0, float(d[3]) / 1000.0]
	var cycle: float = base[0] + base[1] + base[2] + base[3]
	_duration_ms = _SUMMARY_MINUTES * 60000.0

	# _key_poll is the whole record the summary is computed and drawn from: one sample every
	# KEY_POLL_INTERVAL_MS_C, 1 = sliding up, 2 = sliding down, 0 = holding.
	_key_poll = []
	_swipe_up_ms = []
	_hold_top_ms = []
	_swipe_down_ms = []
	_hold_bot_ms = []
	_unlock_times_ms = []
	_score = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260825            # same picture every time it is shown
	var t_ms: float = 0.0
	var thr: float = CrackG.TIMING_THRESHOLD_MS
	while t_ms < _duration_ms - cycle * 1000.0:
		var beat: Array = []
		var hit: bool = true
		for i in range(4):
			# Human drift: mostly close, occasionally enough to miss.
			var off: float = rng.randfn(0.0, 0.34)
			if rng.randf() < 0.12:
				off += (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.9, 1.5)
			var v: float = maxf(0.35, base[i] + off)
			beat.append(v)
			if absf(v * 1000.0 - float(d[i])) >= thr:
				hit = false
		_swipe_up_ms.append(beat[0] * 1000.0)
		_hold_top_ms.append(beat[1] * 1000.0)
		_swipe_down_ms.append(beat[2] * 1000.0)
		_hold_bot_ms.append(beat[3] * 1000.0)
		for i in range(4):
			var code: int = [1, 0, 2, 0][i]
			var n: int = int(round(beat[i] * 1000.0 / KEY_POLL_INTERVAL_MS_C))
			for _j in range(n):
				_key_poll.append(code)
			t_ms += beat[i] * 1000.0
		if hit:
			_score += 1
			_safe_open = not _safe_open
			_unlock_times_ms.append(t_ms)
	_elapsed_ms = _duration_ms
	_current_trace = []
	_trace_segments = []
	_on_session_complete()

# The results panel, once it is up, so the coach can leave it undimmed. Null while it is hidden --
# a never_dim entry returning a rect for a hidden panel would punch a bright hole in every earlier
# step.
func tutorial_results_rect():
	if _results_panel == null or not _results_panel.visible:
		return null
	return _results_panel.get_global_rect()

# --- the acted-out pattern ------------------------------------------------------------------
#
# The coach plays the WHOLE combination as one continuous animation before asking the player to do
# any of it, and repeats it three times. Not one beat per tap: a breathing pattern is a rhythm, and
# a rhythm chopped into five tap-gated stills is not a rhythm any more -- the timing, which is the
# only thing being taught, is exactly what gets lost.
#
# The caption changes in step with the animation instead (a live Callable `text`), so what is on
# screen and what is being said stay together without the player having to do anything.
#
# Durations come from the live preset, so what is demonstrated is exactly what will be judged.
const _DEMO_CYCLES: int = 3
const _DEMO_FINAL_SEC: float = 2.0     # the last inhale, which opens it and ends the demo
# No tail. It was 2.6 s, added so the animation's own closing caption could be read -- but the step
# that follows now carries that message, so holding a motionless picture first is just dead air
# between the animation ending and the next words appearing.
const _DEMO_TAIL_SEC: float = 0.0
const _DEMO_BADGE_SEC: float = 1.8     # how long "safe opened/closed" stays up after a toggle

# Phase of the demo, for the caption. -1 = not running, 5 = finished.
var _demo_phase: int = -1
var _demo_cycle: int = 0
var _demo_done: bool = false

func _demo_line() -> Array:
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	# The caption is a narrow column on the right, so the gesture gets the full height it deserves
	# -- a finger that only crosses a third of the height does not look like a four-second breath.
	var x: float = w * 0.38
	return [_canvas.get_global_transform() * Vector2(x, h * 0.76),
		_canvas.get_global_transform() * Vector2(x, h * 0.16)]

# The region the animation occupies, for the caption to keep clear of.
func tutorial_demo_rect() -> Rect2:
	var line: Array = _demo_line()
	var top: float = minf(line[0].y, line[1].y) - 40.0
	var bot: float = maxf(line[0].y, line[1].y) + 70.0
	var x: float = line[0].x
	return Rect2(Vector2(x - 24.0, top), Vector2(140.0, bot - top))

# How quickly the finger comes off the glass and settles back onto it.
const _DEMO_LIFT_SEC: float = 0.18

# The demo does NOT breathe the preset exactly. A row of perfect 4.0 - 1.0 - 4.0 - 1.0 teaches that
# the numbers must be hit dead on, which is not the rule -- everything within TIMING_THRESHOLD_MS
# counts. Being visibly a little off, and opening anyway, is the clearest way to say so.
const _DEMO_OFFSETS: Array = [0.1, 0.2, -0.1, -0.1]

func _demo_durations() -> Array:
	var d: Array = CrackG.get_guided_durations()
	var out: Array = []
	for i in range(4):
		out.append(maxf(0.3, float(d[i]) / 1000.0 + float(_DEMO_OFFSETS[i])))
	return out

# elapsed -> where the finger is, how far off the glass, and which beat we are on.
#
# The finger NEVER jumps. Every beat begins where the last one ended, because that is what the
# gesture actually is: up, off, down, off, up again.
#
# This also drives the SAFE ITSELF -- the dial arms, the live "Now:" readout, the row of completed
# durations, and the lock opening. The level is frozen while the coach talks, so none of that moves
# on its own, and a demonstration of a gesture on a board that does not react to it teaches the
# gesture as decoration. Everything below is computed from `elapsed` alone, never accumulated, so
# it lands on the same state no matter which frames it is called on.
func tutorial_demo_sequence(elapsed: float) -> Dictionary:
	var line: Array = _demo_line()
	var low: Vector2 = line[0]
	var high: Vector2 = line[1]
	var dd: Array = _demo_durations()
	var t_in: float = dd[0]
	var t_ht: float = dd[1]
	var t_out: float = dd[2]
	var t_hb: float = dd[3]
	var cycle: float = t_in + t_ht + t_out + t_hb
	# A tail after the last beat, holding the finished picture -- the safe open, the row of what it
	# did -- long enough to be read. Without it `advance_when` fired on the same frame the
	# animation ended and the closing caption was never seen at all.
	var total: float = cycle * float(_DEMO_CYCLES) + _DEMO_FINAL_SEC + _DEMO_TAIL_SEC

	var el: float = clampf(elapsed, 0.0, total)
	_demo_done = elapsed >= total
	var pos: Vector2 = low
	var lift: float = 0.0
	var phase: int = 0
	# How many complete four-beat sequences have been performed by now. The lock TOGGLES on each
	# one, exactly as _try_score does, so three sequences read open, closed, open.
	var seqs: int = 0
	# Time spent so far in each of the four gestures, for the dial arms and the "Now:" line.
	var up_s: float = 0.0
	var dn_s: float = 0.0
	var ht_s: float = 0.0
	var hb_s: float = 0.0
	var live: float = 0.0
	var gest: int = 0
	# Time since the lock last changed state, or -1 when it has not just changed. A toggle only
	# happens as an INHALE begins, so this is not the same as time-into-the-current-beat -- keying
	# it to that popped the badge up again at the start of every beat.
	var since_toggle: float = -1.0

	if el >= cycle * float(_DEMO_CYCLES):
		var ff: float = clampf((el - cycle * float(_DEMO_CYCLES)) / _DEMO_FINAL_SEC, 0.0, 1.0)
		_demo_cycle = _DEMO_CYCLES
		seqs = _DEMO_CYCLES
		pos = low.lerp(high, ff * 0.5)
		phase = 5 if ff >= 1.0 else 4
		live = ff * _DEMO_FINAL_SEC
		gest = 1
		up_s = live
		since_toggle = el - cycle * float(_DEMO_CYCLES)
	else:
		var c: int = int(el / cycle)
		var t: float = el - float(c) * cycle
		_demo_cycle = mini(c + 1, _DEMO_CYCLES)
		seqs = c
		if t < t_in:
			pos = low.lerp(high, t / maxf(t_in, 0.01))
			# The whole inhale, not the first two seconds of it. A caption that changes partway
			# through a beat is on screen too briefly to read, and this is the one sentence in the
			# demo that explains what just happened to the lock.
			phase = 4 if c >= 1 else 0
			live = t
			gest = 1
			up_s = t
			if c >= 1:
				since_toggle = t
		elif t < t_in + t_ht:
			var th: float = t - t_in
			pos = high
			phase = 1
			live = th
			gest = 0
			up_s = t_in
			ht_s = th
			lift = minf(th / _DEMO_LIFT_SEC, (t_ht - th) / _DEMO_LIFT_SEC)
			lift = clampf(lift, 0.0, 1.0)
		elif t < t_in + t_ht + t_out:
			var td: float = t - t_in - t_ht
			pos = high.lerp(low, td / maxf(t_out, 0.01))
			phase = 2
			live = td
			gest = -1
			up_s = t_in
			ht_s = t_ht
			dn_s = td
		else:
			var tb: float = t - t_in - t_ht - t_out
			pos = low
			phase = 3
			live = tb
			gest = 0
			up_s = t_in
			ht_s = t_ht
			dn_s = t_out
			hb_s = tb
			lift = minf(tb / _DEMO_LIFT_SEC, (t_hb - tb) / _DEMO_LIFT_SEC)
			lift = clampf(lift, 0.0, 1.0)

	# The dial arms, exactly as _process turns them: the long arm follows the slides, the short arm
	# follows the holds. Whole cycles cancel out (in == out, hold == hold in every preset), so only
	# the current cycle's partial gestures move them.
	_long_angle = LONG_SPEED * (up_s - dn_s)
	_short_angle = SHORT_SPEED * (ht_s - hb_s)
	_gesture = gest
	_gesture_timer_ms = live * 1000.0

	# The row of completed durations, as the player will see their own. Rebuilt from scratch each
	# call rather than appended, so it cannot drift.
	var beats: Array = [t_in, t_ht, t_out, t_hb]
	var done_beats: Array = []
	for i in range(seqs * 4):
		done_beats.append(beats[i % 4])
	if phase == 1 or phase == 2 or phase == 3 or (phase == 0 and _demo_cycle > 0):
		var within: int = 0
		if phase == 1:
			within = 1
		elif phase == 2:
			within = 2
		elif phase == 3:
			within = 3
		for i in range(within):
			done_beats.append(beats[i])
	_display_durations = []
	for i in range(maxi(0, done_beats.size() - 4), done_beats.size()):
		_display_durations.append(done_beats[i])

	var want_open: bool = (seqs % 2) == 1
	if phase == 5 or (phase == 4 and _demo_cycle == _DEMO_CYCLES and el >= cycle * float(_DEMO_CYCLES)):
		want_open = (_DEMO_CYCLES % 2) == 1
	_demo_phase = phase
	if _safe_open != want_open:
		_safe_open = want_open
	_canvas.queue_redraw()

	# The lock changing state is the payoff of the four beats just performed, and it happens on the
	# board -- which is under the dim while the coach talks, so it is easy to miss. Announce it,
	# briefly, opposite the caption. `since` is the time since the toggle, which is the time since
	# the current beat began, because a toggle only ever happens on a beat boundary.
	var badge: String = ""
	var badge_alpha: float = 0.0
	if seqs >= 1 and since_toggle >= 0.0 and since_toggle < _DEMO_BADGE_SEC:
		badge = "Safe opened!" if want_open else "Safe closed!"
		badge_alpha = clampf((_DEMO_BADGE_SEC - since_toggle) / 0.45, 0.0, 1.0)
	return {"pos": pos, "lift": lift, "path": line,
		"badge": badge, "badge_alpha": badge_alpha, "badge_good": want_open}

# What the animation is doing right now, in words. Read by the step's live caption.
func tutorial_demo_caption() -> String:
	var d: Array = CrackG.get_guided_durations()
	var s_in: String = "%.0f" % (float(d[0]) / 1000.0)
	var s_ht: String = "%.0f" % (float(d[1]) / 1000.0)
	var s_out: String = "%.0f" % (float(d[2]) / 1000.0)
	var reps: String = "%d of %d" % [_demo_cycle, _DEMO_CYCLES]
	match _demo_phase:
		0:
			return "Breathe IN.\n\nThe finger slides up, and keeps sliding for all %s seconds.\n\nNot a flick.\n\n(%s)" % [s_in, reps]
		1:
			return "Finger OFF.\n\nThat pause is the hold — %s second.\n\n(%s)" % [s_ht, reps]
		2:
			return "Breathe OUT.\n\nSliding back down, %s seconds, all the way.\n\n(%s)" % [s_out, reps]
		3:
			return "Finger OFF again at the bottom.\n\n(%s)" % reps
		4:
			return "The next breath in — and THAT is when the lock reads all four.\n\nOpen.\n\n(%s)" % reps
		5:
			return "In, hold, out, hold.\n\nThen the next breath in opens it."
	return ""

# True once the animation has played all _DEMO_CYCLES times, so the step can end itself.
# True only once the tail has run too, so the closing caption gets its time on screen.
func tutorial_demo_finished() -> bool:
	return _demo_done

# Ends the animation and shuts the lock, but deliberately LEAVES the row of durations and the dial
# where the demo put them: the next two captions point at that row and call it "what the demo just
# did", so clearing it here would blank the very thing they describe.
func tutorial_demo_end() -> void:
	_demo_phase = -1
	_demo_done = false
	if _safe_open:
		_safe_open = false
	_canvas.queue_redraw()

# Wipes what the demo left behind, for the player's own turn to fill in.
func tutorial_demo_clear() -> void:
	_demo_phase = -1
	_demo_done = false
	_gesture = 0
	_gesture_timer_ms = 0.0
	_display_durations = []
	_long_angle = 0.0
	_short_angle = 0.0
	_safe_open = false
	_canvas.queue_redraw()

# Session progress along the top edge -- shared with udbr, breathe and mother.
func _draw_session_bar(canvas: CanvasItem, w: float) -> void:
	if _session_complete or _duration_ms <= 0.0:
		return
	SessionBar.draw_cool(canvas, w, _elapsed_ms / _duration_ms)

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
		lbl_v.text = "%.1f s" % [float(row[1]) / 1000.0]
		lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_v.add_theme_font_override("font", font)
		lbl_v.add_theme_font_size_override("font_size", fs)
		lbl_v.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
		_phase_grid.add_child(lbl_v)
		if has_target:
			var lbl_t: Label = Label.new()
			lbl_t.text = "(target %.1f s)" % [float(row[2]) / 1000.0]
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
