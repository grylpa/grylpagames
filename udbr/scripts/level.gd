extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

var game: GenericGameUtil

var _duration_ms: float = 300000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

# Phase state machine — drives stats (inhale/exhale/hold durations)
enum Phase { NONE, INHALING, EXHALING, HOLDING_TOP, HOLDING_BOTTOM }

var _inhale_durations_ms: Array = []
var _exhale_durations_ms: Array = []
var _hold_top_durations_ms: Array = []
var _hold_bottom_durations_ms: Array = []

# Reversal timestamps — used only for consistency score
var _reversal_times_ms: Array = []

# Large-movement counters — displayed live on screen
# A stroke counts when it travels more than large_move_threshold_frac of the swipe area height.
var _inhale_count: int = 0
var _exhale_count: int = 0

var guided_mode: bool = false
var _is_mobile: bool = false
var _guided_phase: Phase = Phase.INHALING
var _guided_phase_elapsed_ms: float = 0.0
var _guided_ball_y_norm: float = 1.0

const _MIN_PHASE_MS: float = 200.0

var _trace_segments: Array = []
var _current_segment: Array = []

# Keyboard input state for active mode
var _kbd_y_norm: float = 0.5
var _kbd_vel: float = 0.0
var _kbd_used: bool = false
var _kbd_trace_last_ms: float = 0.0
const _KBD_TRACE_INTERVAL_MS: float = 100.0

var _key_poll: Array = []
const _KEY_POLL_INTERVAL_MS: float = 50.0
var _kbd_prev_up: bool = false
var _kbd_prev_dn: bool = false
var _last_kbd_phases: Array = []

# Stats computed at session end
var _intervals_ms: Array = []
var _mean_ms: float = 0.0
var _stddev_ms: float = 0.0
var _bpm: float = 0.0
var _missed_cycles: int = 0
var _outlier_threshold_ms: float = 0.0

@onready var _swipe_area: Control = $SwipeArea
@onready var _inhale_label: Label = $SessionOverlay/InhaleLabel
@onready var _exhale_label: Label = $SessionOverlay/ExhaleLabel
@onready var _hint_label: Label = $SessionOverlay/HintLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _metrics_label: Label = $ResultsPanel/Margin/VBox/MetricsLabel
@onready var _graph: Control = $ResultsPanel/Margin/VBox/Graph
@onready var _done_button: Button = $ResultsPanel/Margin/VBox/DoneButton
var _phase_grid: GridContainer
var _again_button: Button
var _guided_done_button: Button
var _guided_done_panel: Control
var _guided_header_label: Label
var _guided_stats_grid: GridContainer
var _guided_stats_fs: int = 20

func _ready() -> void:
	game = UdbrG.game
	_is_mobile = MainGlobals.is_mobile()
	_results_panel.hide()
	var _f: Font = MainGlobals.get_system_sans_font()
	var _t: Theme = Theme.new()
	_t.set_font("font", "Label", _f)
	_t.set_font("font", "Button", _f)
	$SessionOverlay.theme = _t
	_results_panel.theme = _t
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.38, 0.65, 1.0)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	var btn_pressed_style: StyleBoxFlat = btn_style.duplicate()
	btn_pressed_style.bg_color = Color(0.12, 0.26, 0.48, 1.0)
	_done_button.add_theme_stylebox_override("normal", btn_style)
	_done_button.add_theme_stylebox_override("hover", btn_style)
	_done_button.add_theme_stylebox_override("pressed", btn_pressed_style)

	# Guided done screen — centered Again / Done buttons over the results panel
	_guided_done_panel = Control.new()
	_guided_done_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guided_done_panel.hide()
	_results_panel.add_child(_guided_done_panel)
	var _center: CenterContainer = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guided_done_panel.add_child(_center)
	var _bvbox: VBoxContainer = VBoxContainer.new()
	_bvbox.add_theme_constant_override("separation", 24)
	_center.add_child(_bvbox)
	var mobile: bool = MainGlobals.is_mobile()
	_guided_stats_fs = 32 if mobile else 20
	var header_margin_bottom: int = 60 if mobile else 36
	var _header_vbox: VBoxContainer = VBoxContainer.new()
	_header_vbox.add_theme_constant_override("separation", 16 if mobile else 10)
	_guided_header_label = Label.new()
	_guided_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guided_header_label.add_theme_font_size_override("font_size", _guided_stats_fs)
	_header_vbox.add_child(_guided_header_label)
	_guided_stats_grid = GridContainer.new()
	_guided_stats_grid.columns = 2
	_guided_stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_guided_stats_grid.add_theme_constant_override("h_separation", 24 if mobile else 16)
	_guided_stats_grid.add_theme_constant_override("v_separation", 6 if mobile else 4)
	_header_vbox.add_child(_guided_stats_grid)
	var _header_margin: MarginContainer = MarginContainer.new()
	_header_margin.add_theme_constant_override("margin_bottom", header_margin_bottom)
	_header_margin.add_child(_header_vbox)
	_bvbox.add_child(_header_margin)
	var btn_min: Vector2 = Vector2(280, 72) if mobile else Vector2(220, 60)
	var guided_fs: int = 48 if mobile else 28
	_again_button = Button.new()
	_again_button.text = "Again"
	_again_button.custom_minimum_size = btn_min
	_again_button.add_theme_stylebox_override("normal", btn_style)
	_again_button.add_theme_stylebox_override("hover", btn_style)
	_again_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	_again_button.add_theme_font_size_override("font_size", guided_fs)
	_again_button.pressed.connect(_on_again_pressed)
	_bvbox.add_child(_again_button)
	_guided_done_button = Button.new()
	_guided_done_button.text = "Done"
	_guided_done_button.custom_minimum_size = btn_min
	_guided_done_button.add_theme_stylebox_override("normal", btn_style)
	_guided_done_button.add_theme_stylebox_override("hover", btn_style)
	_guided_done_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	_guided_done_button.add_theme_font_size_override("font_size", guided_fs)
	_guided_done_button.pressed.connect(_on_done_pressed)
	_bvbox.add_child(_guided_done_button)

	# Active-mode Again button — reparent Done into an HBox with Again on the left
	var again_btn_a: Button = Button.new()
	again_btn_a.text = "Again"
	again_btn_a.custom_minimum_size = Vector2(160, 52)
	again_btn_a.add_theme_stylebox_override("normal", btn_style)
	again_btn_a.add_theme_stylebox_override("hover", btn_style)
	again_btn_a.add_theme_stylebox_override("pressed", btn_pressed_style)
	again_btn_a.add_theme_font_size_override("font_size", 36 if mobile else 26)
	again_btn_a.pressed.connect(_on_again_pressed)
	var btn_hbox_a: HBoxContainer = HBoxContainer.new()
	btn_hbox_a.add_theme_constant_override("separation", 16)
	btn_hbox_a.alignment = BoxContainer.ALIGNMENT_CENTER
	var vbox_a: Node = $ResultsPanel/Margin/VBox
	vbox_a.add_child(btn_hbox_a)
	_done_button.reparent(btn_hbox_a)
	btn_hbox_a.add_child(again_btn_a)
	btn_hbox_a.move_child(again_btn_a, 0)

	_phase_grid = GridContainer.new()
	_phase_grid.columns = 2
	_phase_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_grid.add_theme_constant_override("h_separation", 24)
	_phase_grid.add_theme_constant_override("v_separation", 4)
	var _grid_hbox_u: HBoxContainer = HBoxContainer.new()
	_grid_hbox_u.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_hbox_u.add_child(_phase_grid)
	vbox_a.add_child(_grid_hbox_u)
	vbox_a.move_child(_grid_hbox_u, 1)

	if mobile:
		_inhale_label.add_theme_font_size_override("font_size", 38)
		_exhale_label.add_theme_font_size_override("font_size", 38)
		_hint_label.add_theme_font_size_override("font_size", 28)
		_hint_label.offset_top -= 80.0
		_hint_label.offset_bottom -= 80.0
		_metrics_label.add_theme_font_size_override("font_size", 28)
		_done_button.add_theme_font_size_override("font_size", 36)
		pass
	_graph.set_script(load("res://mother/scripts/key_graph.gd"))
	_graph.set("bg_color", Color(0.04, 0.07, 0.14, 1.0))
	var graph_spacer_u: Control = Control.new()
	graph_spacer_u.custom_minimum_size = Vector2(0, 24)
	var vbox_u: Node = $ResultsPanel/Margin/VBox
	vbox_u.add_child(graph_spacer_u)
	vbox_u.move_child(graph_spacer_u, _graph.get_index() + 1)

	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.offset_top = 0.0
	_results_panel.offset_bottom = 0.0
	_results_panel.offset_left = 0.0
	_results_panel.offset_right = 0.0
	var margin_ctrl_u: Control = $ResultsPanel/Margin as Control
	margin_ctrl_u.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + (48 if MainGlobals.is_mobile() else 16))
	margin_ctrl_u.add_theme_constant_override("margin_top", 8)
	($ResultsPanel/Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 6)

func new_game(_from_scratch: bool = true) -> void:
	_duration_ms = UdbrG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_reversal_times_ms.clear()
	_trace_segments.clear()
	_current_segment.clear()
	_inhale_durations_ms.clear()
	_exhale_durations_ms.clear()
	_hold_top_durations_ms.clear()
	_hold_bottom_durations_ms.clear()
	_inhale_count = 0
	_exhale_count = 0
	_kbd_y_norm = UdbrG.LANE_BOT_FRAC
	_kbd_vel = 0.0
	_kbd_used = false
	_kbd_trace_last_ms = 0.0
	_key_poll = []
	_kbd_prev_up = false
	_kbd_prev_dn = false
	_last_kbd_phases = []
	game.level_is_ready = true
	game.playing = true
	if guided_mode:
		_guided_phase = Phase.INHALING
		_guided_phase_elapsed_ms = 0.0
		_guided_ball_y_norm = UdbrG.LANE_BOT_FRAC
		game.add_score_and_time(0, 0, true)
		_hint_label.text = ""
		_exhale_label.hide()
		_update_guided_label()
		if _is_mobile:
			_inhale_label.offset_bottom = 213.0
			_inhale_label.offset_top = 169.0
	else:
		_hint_label.text = ""
		_inhale_label.show()
		_exhale_label.show()
		if _is_mobile:
			_inhale_label.offset_bottom = 161.0
			_inhale_label.offset_top = 117.0
			_exhale_label.offset_bottom = 213.0
			_exhale_label.offset_top = 169.0
	$SessionOverlay.show()
	_results_panel.hide()
	_update_counts_label()

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused():
		return
	if _session_complete:
		return
	_elapsed_ms += delta * 1000.0
	if guided_mode:
		_update_guided_animation(delta * 1000.0)
	else:
		_process_kbd(delta)
	_swipe_area.queue_redraw()
	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

func _update_guided_animation(delta_ms: float) -> void:
	_guided_phase_elapsed_ms += delta_ms
	var durations: Array = UdbrG.get_guided_durations()
	var inhale_ms: float = durations[0]
	var hold_top_ms: float = durations[1]
	var exhale_ms: float = durations[2]
	var hold_bot_ms: float = durations[3]
	match _guided_phase:
		Phase.INHALING:
			var t: float = clampf(_guided_phase_elapsed_ms / inhale_ms, 0.0, 1.0)
			_guided_ball_y_norm = lerp(UdbrG.LANE_BOT_FRAC, UdbrG.LANE_TOP_FRAC, smoothstep(0.0, 1.0, t))
			if _guided_phase_elapsed_ms >= inhale_ms:
				_guided_phase_elapsed_ms -= inhale_ms
				_guided_phase = Phase.HOLDING_TOP if hold_top_ms >= _MIN_PHASE_MS else Phase.EXHALING
				_update_guided_label()
		Phase.HOLDING_TOP:
			_guided_ball_y_norm = UdbrG.LANE_TOP_FRAC
			if _guided_phase_elapsed_ms >= hold_top_ms:
				_guided_phase_elapsed_ms -= hold_top_ms
				_guided_phase = Phase.EXHALING
				_update_guided_label()
		Phase.EXHALING:
			var t: float = clampf(_guided_phase_elapsed_ms / exhale_ms, 0.0, 1.0)
			_guided_ball_y_norm = lerp(UdbrG.LANE_TOP_FRAC, UdbrG.LANE_BOT_FRAC, smoothstep(0.0, 1.0, t))
			if _guided_phase_elapsed_ms >= exhale_ms:
				_guided_phase_elapsed_ms -= exhale_ms
				_guided_phase = Phase.HOLDING_BOTTOM if hold_bot_ms >= _MIN_PHASE_MS else Phase.INHALING
				_update_guided_label()
		Phase.HOLDING_BOTTOM:
			_guided_ball_y_norm = UdbrG.LANE_BOT_FRAC
			if _guided_phase_elapsed_ms >= hold_bot_ms:
				_guided_phase_elapsed_ms -= hold_bot_ms
				_guided_phase = Phase.INHALING
				_update_guided_label()

func _update_counts_label() -> void:
	if guided_mode:
		return
	_inhale_label.text = "Inhales: %d" % _inhale_count
	_exhale_label.text = "Exhales: %d" % _exhale_count

func _update_guided_label() -> void:
	match _guided_phase:
		Phase.INHALING:
			_inhale_label.text = "Inhale"
		Phase.HOLDING_TOP:
			_inhale_label.text = "Hold"
		Phase.EXHALING:
			_inhale_label.text = "Exhale"
		Phase.HOLDING_BOTTOM:
			_inhale_label.text = "Hold"

func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	if guided_mode:
		_show_guided_done()
		return
	if _kbd_used and _current_segment.size() > 1:
		_trace_segments.append(_current_segment.duplicate())
		_current_segment.clear()
	var analysis: Dictionary = {}
	if _kbd_used:
		var phases: Array = _compute_phase_durations(_key_poll)
		analysis["kbd_phases"] = phases
		game.score = _accuracy_score(phases)
		if phases[0] + phases[2] > 100.0:
			_last_kbd_phases = phases
	else:
		_compute_stats()
		game.score = _consistency_score()
		analysis = _analyze_trace(_trace_segments)
	_show_results(analysis)
	sig_session_done.emit()

func _show_guided_done() -> void:
	$SessionOverlay.hide()
	$ResultsPanel/Margin.hide()
	var d: Array = UdbrG.get_guided_durations()
	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60
	_guided_header_label.text = "Session done  (%d:%02d min)" % [dur_min, dur_sec]
	for child in _guided_stats_grid.get_children():
		child.queue_free()
	var rows: Array = [
		["Inhale", _fmt_guided_s(d[0])],
	]
	if d[1] >= _MIN_PHASE_MS:
		rows.append(["Hold", _fmt_guided_s(d[1])])
	rows.append(["Exhale", _fmt_guided_s(d[2])])
	if d[3] >= _MIN_PHASE_MS:
		rows.append(["Hold", _fmt_guided_s(d[3])])
	for row in rows:
		for col_idx in range(2):
			var lbl: Label = Label.new()
			lbl.text = row[col_idx]
			lbl.add_theme_font_size_override("font_size", _guided_stats_fs)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_guided_stats_grid.add_child(lbl)
	_guided_done_panel.show()
	_results_panel.show()

func _consistency_score() -> int:
	if _mean_ms <= 0.0:
		return 0
	var cv_pct: float = (_stddev_ms / _mean_ms) * 100.0
	return clampi(100 - roundi(cv_pct), 0, 100)

func _arr_mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s: float = 0.0
	for v in arr:
		s += v
	return s / float(arr.size())

func _compute_stats() -> void:
	_intervals_ms.clear()
	_mean_ms = 0.0
	_stddev_ms = 0.0
	_bpm = 0.0
	_missed_cycles = 0

	if _reversal_times_ms.size() < 2:
		return

	for i: int in range(1, _reversal_times_ms.size()):
		_intervals_ms.append(_reversal_times_ms[i] - _reversal_times_ms[i - 1])

	# Pair consecutive half-cycles into full breath cycles (inhale+exhale)
	var full_cycles: Array = []
	for i: int in range(0, _intervals_ms.size() - 1, 2):
		full_cycles.append(_intervals_ms[i] + _intervals_ms[i + 1])

	var stats_source: Array = full_cycles if full_cycles.size() >= 2 else _intervals_ms

	var sorted: Array = stats_source.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	var median_ms: float = float(sorted[mid]) if sorted.size() % 2 != 0 else (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5
	_outlier_threshold_ms = median_ms * 1.75

	var clean: Array = []
	for iv in stats_source:
		if iv <= _outlier_threshold_ms:
			clean.append(iv)

	var final_source: Array = clean if clean.size() >= 2 else stats_source

	var s: float = 0.0
	for iv in final_source:
		s += iv
	_mean_ms = s / float(final_source.size())

	var variance: float = 0.0
	for iv in final_source:
		var d: float = iv - _mean_ms
		variance += d * d
	variance /= float(final_source.size())
	_stddev_ms = sqrt(variance)

	_bpm = 60000.0 / _mean_ms if _mean_ms > 0.0 else 0.0

	# Count full cycles that are outliers (paused/missed breaths)
	_missed_cycles = 0
	for iv in stats_source:
		if iv > _outlier_threshold_ms:
			_missed_cycles += 1

func _fmt_sec(ms: float) -> String:
	return "%.1f s" % [ms / 1000.0]

func _fmt_guided_s(ms: float) -> String:
	var s: float = ms / 1000.0
	if s == float(int(s)):
		return "%d s" % int(s)
	return "%.1f s" % s

func _process_kbd(delta: float) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	var up: bool = Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up
	var dn: bool = Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn
	print("kbd up=", up, " dn=", dn, " swipe_up=", MainGlobals.is_in_digitized_swipe_up, " kbd_used=", _kbd_used, " paused=", game.paused())
	if not _kbd_used and not up and not dn:
		return
	if not _kbd_used and (up or dn):
		_kbd_used = true
		_current_segment.clear()
		_kbd_trace_last_ms = _elapsed_ms
		game.add_score_and_time(0, 0, true)
	var expected_slots: int = int(_elapsed_ms / _KEY_POLL_INTERVAL_MS)
	while _key_poll.size() < expected_slots:
		if up:
			_key_poll.append(1)
		elif dn:
			_key_poll.append(2)
		else:
			_key_poll.append(0)
	var speed_up: float = 0.3
	var speed_dn: float = 0.3
	var target_vel: float = 0.0
	if up:
		target_vel = -speed_up
	elif dn:
		target_vel = speed_dn
	_kbd_vel = target_vel
	_kbd_y_norm = clampf(_kbd_y_norm + _kbd_vel * delta, UdbrG.LANE_TOP_FRAC, UdbrG.LANE_BOT_FRAC)
	if _elapsed_ms - _kbd_trace_last_ms >= _KBD_TRACE_INTERVAL_MS:
		_current_segment.append(Vector2(_elapsed_ms, _kbd_y_norm))
		_kbd_trace_last_ms = _elapsed_ms
	if up and not _kbd_prev_up:
		_inhale_count += 1
		_update_counts_label()
	if dn and not _kbd_prev_dn:
		_exhale_count += 1
		_update_counts_label()
	_kbd_prev_up = up
	_kbd_prev_dn = dn

func _show_results(analysis: Dictionary) -> void:
	$SessionOverlay.hide()
	_guided_done_panel.hide()
	$ResultsPanel/Margin.show()
	_results_panel.show()
	if _kbd_used and _key_poll.size() > 0:
		_graph.show()
		var graph_duration_ms_u: float = _key_poll.size() * _KEY_POLL_INTERVAL_MS
		_graph.call("set_data", _key_poll, [], graph_duration_ms_u)
		_graph.queue_redraw()
	else:
		_graph.hide()

	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60
	var text: String = "Session: %d:%02d min\n" % [dur_min, dur_sec]

	if _kbd_used:
		var phases: Array = analysis.get("kbd_phases", [0.0, 0.0, 0.0, 0.0])
		var has_data: bool = phases[0] + phases[2] > 100.0
		if has_data:
			text += "Pattern saved for next guided session"
			_populate_phase_grid_u(phases)
		else:
			text += "No breathing data detected"
			_populate_phase_grid_u([])
	else:
		if _reversal_times_ms.size() < 2:
			_metrics_label.text = "Too few direction changes to analyse.\nSwipe up while inhaling and down while exhaling."
			_populate_phase_grid_u([])
			return
		text += "Consistency: %d / 100   (%.1f bpm)\n" % [_consistency_score(), _bpm]
		text += "Missed breaths: %d" % [_missed_cycles]
		var p: Array = []
		if analysis.get("valid", false):
			p = [analysis.inhale_ms, analysis.hold_top_ms, analysis.exhale_ms, analysis.hold_bot_ms]
		else:
			p = [_arr_mean(_inhale_durations_ms), _arr_mean(_hold_top_durations_ms),
				_arr_mean(_exhale_durations_ms), _arr_mean(_hold_bottom_durations_ms)]
		_populate_phase_grid_u(p)
	_metrics_label.text = text.strip_edges()

func _analyze_trace(segments: Array) -> Dictionary:
	var pts: Array = []
	for seg in segments:
		for pt in seg:
			pts.append(pt)
	if pts.size() < 30:
		return {"valid": false}
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	# 200ms grid — finer than 500ms so period interpolation is accurate
	const DT_MS: float = 200.0
	var t_start: float = pts[0].x
	var t_end: float = pts[pts.size() - 1].x
	var n: int = int((t_end - t_start) / DT_MS) + 1
	if n < 20:
		return {"valid": false}
	var y: PackedFloat32Array = PackedFloat32Array()
	y.resize(n)
	var ji: int = 0
	for i in range(n):
		var t: float = t_start + float(i) * DT_MS
		while ji < pts.size() - 2 and pts[ji + 1].x < t:
			ji += 1
		var pa: Vector2 = pts[ji]
		var pb: Vector2 = pts[ji + 1] if ji + 1 < pts.size() else pa
		var frac: float = clampf((t - pa.x) / maxf(pb.x - pa.x, 0.001), 0.0, 1.0)
		y[i] = lerpf(pa.y, pb.y, frac)

	var ymean: float = 0.0
	for v in y:
		ymean += v
	ymean /= float(n)
	var yz: PackedFloat32Array = PackedFloat32Array()
	yz.resize(n)
	for i in range(n):
		yz[i] = y[i] - ymean

	var min_lag: int = maxi(1, int(3000.0 / DT_MS))
	var max_lag: int = mini(int(60000.0 / DT_MS), n / 2)
	if max_lag <= min_lag:
		return {"valid": false}
	var ac0: float = 0.0
	for v in yz:
		ac0 += v * v
	ac0 = maxf(ac0 / float(n), 1e-9)
	var best_lag: int = min_lag
	var best_ac: float = -1.0
	for lag in range(min_lag, max_lag + 1):
		var ac: float = 0.0
		var cnt: int = n - lag
		for i in range(cnt):
			ac += yz[i] * yz[i + lag]
		ac = (ac / float(cnt)) / ac0
		if ac > best_ac:
			best_ac = ac
			best_lag = lag
	if best_ac < 0.15:
		return {"valid": false}

	# Quadratic interpolation for sub-sample period accuracy
	var period_ms: float = float(best_lag) * DT_MS
	if best_lag > min_lag and best_lag < max_lag:
		var cnt_m: int = n - (best_lag - 1)
		var cnt_p: int = n - (best_lag + 1)
		var ac_m: float = 0.0
		var ac_p: float = 0.0
		for i in range(cnt_m):
			ac_m += yz[i] * yz[i + best_lag - 1]
		ac_m = (ac_m / float(cnt_m)) / ac0
		for i in range(cnt_p):
			ac_p += yz[i] * yz[i + best_lag + 1]
		ac_p = (ac_p / float(cnt_p)) / ac0
		var denom: float = ac_m - 2.0 * best_ac + ac_p
		if absf(denom) > 1e-6:
			var delta: float = clampf(0.5 * (ac_m - ac_p) / denom, -0.5, 0.5)
			period_ms = (float(best_lag) + delta) * DT_MS

	const N_BINS: int = 60
	var bins: PackedFloat32Array = PackedFloat32Array()
	bins.resize(N_BINS)
	var bcnt: PackedInt32Array = PackedInt32Array()
	bcnt.resize(N_BINS)
	for i in range(n):
		var t_rel: float = fmod(float(i) * DT_MS, period_ms)
		var bi: int = int(t_rel / period_ms * float(N_BINS)) % N_BINS
		bins[bi] += y[i]
		bcnt[bi] += 1
	for i in range(N_BINS):
		if bcnt[i] > 0:
			bins[i] /= float(bcnt[i])
		else:
			bins[i] = bins[(i - 1 + N_BINS) % N_BINS]

	var sb: PackedFloat32Array = PackedFloat32Array()
	sb.resize(N_BINS)
	for i in range(N_BINS):
		sb[i] = (bins[(i - 1 + N_BINS) % N_BINS] + bins[i] + bins[(i + 1) % N_BINS]) / 3.0

	var wmin: float = sb[0]
	var wmax: float = sb[0]
	for v in sb:
		if v < wmin: wmin = v
		if v > wmax: wmax = v
	var wrange: float = wmax - wmin
	if wrange < 0.05:
		return {"valid": false, "period_ms": period_ms}

	# Derivative-based classification: flat (|dv| ≤ wrange/N_BINS) = hold, sloped = movement.
	# This avoids the large bias of value-threshold approaches (which eat into the movement phases).
	var bin_ms: float = period_ms / float(N_BINS)
	var n_top: int = 0
	var n_bot: int = 0
	var n_up: int = 0
	var n_dn: int = 0
	var flat_thr: float = wrange / float(N_BINS)
	var wmid: float = (wmin + wmax) * 0.5
	for i in range(N_BINS):
		var dv: float = sb[(i + 1) % N_BINS] - sb[(i - 1 + N_BINS) % N_BINS]
		if absf(dv) <= flat_thr:
			if sb[i] < wmid:
				n_top += 1
			else:
				n_bot += 1
		elif dv < 0.0:
			n_up += 1
		else:
			n_dn += 1

	var hold_top_ms: float = float(n_top) * bin_ms
	var hold_bot_ms: float = float(n_bot) * bin_ms
	var total_move: int = n_up + n_dn
	var movement_ms: float = float(total_move) * bin_ms
	var inhale_ms: float = movement_ms * float(n_up) / float(total_move) if total_move > 0 else movement_ms * 0.5
	var exhale_ms: float = movement_ms - inhale_ms

	return {
		"valid": true,
		"period_ms": period_ms,
		"inhale_ms": inhale_ms,
		"hold_top_ms": hold_top_ms,
		"exhale_ms": exhale_ms,
		"hold_bot_ms": hold_bot_ms,
	}

func _accuracy_score(phases: Array) -> int:
	var d: Array = UdbrG.get_guided_durations()
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

func get_session_score(didwin: bool, wasaborted: bool) -> Array:
	return [didwin, wasaborted,
		int(_duration_ms / 60000.0),
		int(_mean_ms),
		_bpm,
		_reversal_times_ms.size(),
		_missed_cycles]

func get_swipe_draw_state() -> Dictionary:
	var active: bool = not _session_complete and game.level_is_ready
	var progress: float = clampf(_elapsed_ms / _duration_ms, 0.0, 1.0) if _duration_ms > 0.0 else 0.0
	if guided_mode:
		return {
			"session_active": active,
			"session_progress": progress,
			"touch_active": active,
			"touch_y_norm": _guided_ball_y_norm,
			"direction": 0,
			"in_hold": _guided_phase == Phase.HOLDING_TOP or _guided_phase == Phase.HOLDING_BOTTOM,
			"phase": _guided_phase,
			"pattern_text": _fmt_pattern(),
		}
	return {
		"session_active": active,
		"session_progress": progress,
		"touch_active": active,
		"touch_y_norm": _kbd_y_norm,
		"direction": 0,
		"in_hold": false,
		"phase": Phase.NONE,
	}

func get_kbd_phases() -> Array:
	return _last_kbd_phases

func get_mean_phase_durations() -> Dictionary:
	var inhale: float = _arr_mean(_inhale_durations_ms)
	var exhale: float = _arr_mean(_exhale_durations_ms)
	if inhale <= 0.0 or exhale <= 0.0:
		return {"valid": false}
	return {
		"valid": true,
		"inhale_ms": inhale,
		"exhale_ms": exhale,
		"hold_top_ms": _arr_mean(_hold_top_durations_ms),
		"hold_bottom_ms": _arr_mean(_hold_bottom_durations_ms),
	}

func _fmt_pattern() -> String:
	var d: Array = UdbrG.get_guided_durations()
	var fv: Callable = func(ms: float) -> String:
		var r: float = round(ms / 500.0) / 2.0
		if r == float(int(r)):
			return str(int(r))
		var whole: int = int(r)
		return ("" if whole == 0 else str(whole)) + "½"
	return "%s-%s-%s-%s s" % [fv.call(d[0]), fv.call(d[1]), fv.call(d[2]), fv.call(d[3])]

func _populate_phase_grid_u(phases: Array) -> void:
	for child in _phase_grid.get_children():
		child.queue_free()
	if phases.size() < 4:
		return
	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 28 if _is_mobile else 20
	_phase_grid.columns = 2
	var rows: Array = [["Inhale", phases[0]]]
	if phases[1] > 200.0:
		rows.append(["Hold air", phases[1]])
	rows.append(["Exhale", phases[2]])
	if phases[3] > 200.0:
		rows.append(["Hold empty", phases[3]])
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

func _on_again_pressed() -> void:
	_results_panel.hide()
	game.reset(true)
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
