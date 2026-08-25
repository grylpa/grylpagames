extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

var game: GenericGameUtil

var _duration_ms: float = 300000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false
var _tap_times_ms: Array = []

# Computed after session ends
var _intervals_ms: Array = []
var _mean_ms: float = 0.0
var _stddev_ms: float = 0.0
var _bpm: float = 0.0
var _missed_breaths: int = 0
var _outlier_threshold_ms: float = 0.0

# Ring animation state (read by tap_area.gd)
var _ring_pos: Vector2 = Vector2.ZERO
var _ring_age: float = 0.0
var _ring_active: bool = false
var _last_tap_ms: float = -9999.0  # debounce: ignore duplicate events from same physical tap
var _rhythm_interval_ms: float = 0.0   # median-trimmed estimate from all taps
var _display_rhythm_ms: float = 9000.0 # smoothly lerped period used for animation
var _breath_phase: float = 0.0         # normalized [0,1); 0 = tap moment
# The big circle used to start breathing along with the player once four taps had established a
# rhythm. Turned OFF: people followed the animation instead of their own breath, which is the one
# thing this game must not do. Everything else is untouched — the circle is still drawn (static),
# each tap still throws its expanding ring, and the rhythm is still measured and scored exactly as
# before. Set this back to true to bring the animation back.
const BREATH_ANIMATION: bool = false

var _anim_active: bool = false         # stays false until first tap
var _amplitude_factor: float = 0.0         # target: ramps from 1/3 at tap 4 to 1.0 at tap 8
var _display_amp_factor: float = 0.0      # smoothly lerped toward _amplitude_factor

@onready var _tap_area: Control = $TapArea
@onready var _breath_label: Label = $SessionOverlay/BreathCountLabel
@onready var _breaths_word_label: Label = $SessionOverlay/BreathsWordLabel
@onready var _hint_label: Label = $SessionOverlay/HintLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _metrics_label: Label = $ResultsPanel/Margin/VBox/MetricsLabel
@onready var _graph: Control = $ResultsPanel/Margin/VBox/Graph
@onready var _done_button: Button = $ResultsPanel/Margin/VBox/DoneButton

func _ready() -> void:
	game = BreatheG.game
	_tap_area.gui_input.connect(_on_tap_area_input)
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
	var mobile_b: bool = MainGlobals.is_mobile()
	if mobile_b:
		_breath_label.add_theme_color_override("font_color", Color(0.6, 0.92, 1.0, 1.0))
		_breaths_word_label.add_theme_color_override("font_color", Color(0.6, 0.92, 1.0, 0.95))
		_hint_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 0.95))
		_breaths_word_label.add_theme_font_size_override("font_size", 26)
		_hint_label.add_theme_font_size_override("font_size", 28)
		_hint_label.offset_top -= 80.0
		_hint_label.offset_bottom -= 80.0
		_metrics_label.add_theme_font_size_override("font_size", 28)
		_done_button.add_theme_font_size_override("font_size", 36)
		_results_panel.offset_bottom = -110.0
	else:
		_results_panel.offset_bottom = -80.0

	var again_btn_b: Button = Button.new()
	again_btn_b.text = "Again"
	again_btn_b.custom_minimum_size = Vector2(160, 52)
	again_btn_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_b.add_theme_stylebox_override("normal", btn_style)
	again_btn_b.add_theme_stylebox_override("hover", btn_style)
	again_btn_b.add_theme_stylebox_override("pressed", btn_pressed_style)
	again_btn_b.add_theme_font_size_override("font_size", 36 if mobile_b else 26)
	again_btn_b.pressed.connect(_on_again_pressed)
	var btn_hbox_b: HBoxContainer = HBoxContainer.new()
	btn_hbox_b.add_theme_constant_override("separation", 16)
	btn_hbox_b.alignment = BoxContainer.ALIGNMENT_CENTER
	var vbox_b: Node = $ResultsPanel/Margin/VBox
	vbox_b.add_child(btn_hbox_b)
	_done_button.reparent(btn_hbox_b)
	btn_hbox_b.add_child(again_btn_b)
	btn_hbox_b.move_child(again_btn_b, 0)

func new_game(_from_scratch: bool = true) -> void:
	_duration_ms = BreatheG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_tap_times_ms.clear()
	_ring_active = false
	_last_tap_ms = -9999.0
	_rhythm_interval_ms = 0.0
	_display_rhythm_ms = 9000.0
	_breath_phase = 0.0
	_anim_active = false
	_amplitude_factor = 0.0
	_display_amp_factor = 0.0
	game.level_is_ready = true
	game.playing = true
	$SessionOverlay.show()
	_results_panel.hide()
	_update_breath_label()

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused():
		return
	if _session_complete:
		return
	_elapsed_ms += delta * 1000.0
	if _rhythm_interval_ms > 0.0:
		_display_rhythm_ms = lerpf(_display_rhythm_ms, _rhythm_interval_ms, delta * 0.5)
	_display_amp_factor = lerpf(_display_amp_factor, _amplitude_factor, delta * 1.5)
	if _anim_active:
		_breath_phase += delta / (_display_rhythm_ms / 1000.0)
		if _breath_phase >= 1.0:
			_breath_phase -= 1.0
	if _ring_active:
		_ring_age += delta * 1.8
		if _ring_age >= 1.0:
			_ring_active = false
	_tap_area.queue_redraw()  # always redraw: drives the pulse animation on the tap circle
	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

func _on_tap_area_input(event: InputEvent) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return
	var is_tap: bool = false
	var tap_pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			tap_pos = mbe.position
			is_tap = true
	elif event is InputEventScreenTouch:
		var ste: InputEventScreenTouch = event as InputEventScreenTouch
		if ste.pressed:
			tap_pos = ste.position
			is_tap = true
	if not is_tap:
		return
	_register_tap(tap_pos)

func _input(event: InputEvent) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				_register_tap(_tap_area.size / 2.0)

func _register_tap(tap_pos: Vector2) -> void:
	# Debounce: Godot fires both InputEventMouseButton and InputEventScreenTouch
	# for one physical tap when touch emulation is on — ignore events within 200ms.
	if _elapsed_ms - _last_tap_ms < 200.0:
		return
	_last_tap_ms = _elapsed_ms
	_tap_times_ms.append(_elapsed_ms)
	if _tap_times_ms.size() == 1:
		game.add_score_and_time(0, 0, true)
	_update_rhythm()
	var n: int = _tap_times_ms.size()
	if n == 4 and BREATH_ANIMATION:
		_anim_active = true
		_breath_phase = 0.0
		_display_rhythm_ms = _rhythm_interval_ms
	if n >= 4:
		_amplitude_factor = minf(1.0, (1.0 / 3.0) + (2.0 / 3.0) * float(n - 4) / 4.0)
	_ring_pos = tap_pos
	_ring_age = 0.0
	_ring_active = true
	_tap_area.queue_redraw()
	_update_breath_label()
	# After the debounce, so the coach only ever counts taps the game itself accepted.
	game.tutorial_notify("tapped")          # no-op outside tutorial mode
	if n >= 2:
		game.tutorial_notify("rhythm_started")

func _update_rhythm() -> void:
	var n: int = _tap_times_ms.size()
	if n < 4:
		return
	var intervals: Array = []
	for i: int in range(1, n):
		intervals.append(_tap_times_ms[i] - _tap_times_ms[i - 1])
	intervals.sort()
	var count: int = intervals.size()
	var keep: int = mini(maxi(3, roundi(float(count) * 0.6)), count)
	var skip: int = (count - keep) / 2
	var sum: float = 0.0
	for i: int in range(skip, skip + keep):
		sum += float(intervals[i])
	_rhythm_interval_ms = sum / float(keep)

func _compute_breath_value() -> float:
	if not _anim_active:
		return 0.0
	var p: float = _breath_phase
	# Cycle: tap at phase 0 (circle at 0)
	#   [0,   p1]: hold at min (500ms)
	#   [p1,  p2]: inhale 0→1
	#   [p2,  p3]: hold at max (500ms)
	#   [p3, 1.0]: exhale 1→0, ends at next tap
	var hold_frac: float = clampf(500.0 / _display_rhythm_ms, 0.04, 0.16)
	var half_frac: float = (1.0 - hold_frac * 2.0) * 0.5
	var p1: float = hold_frac
	var p2: float = p1 + half_frac
	var p3: float = p2 + hold_frac
	if p < p1:
		return 0.0
	elif p < p2:
		return smoothstep(p1, p2, p)
	elif p < p3:
		return 1.0
	else:
		return 1.0 - smoothstep(p3, 1.0, p)

func _update_breath_label() -> void:
	_breath_label.text = str(_tap_times_ms.size())

func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	_compute_stats()
	game.score = _consistency_score()
	_show_results()
	sig_session_done.emit()

func _consistency_score() -> int:
	return maxi(0, 100 - roundi(_stddev_ms / 10.0))

func _compute_stats() -> void:
	_intervals_ms.clear()
	_mean_ms = 0.0
	_stddev_ms = 0.0
	_bpm = 0.0
	_missed_breaths = 0

	if _tap_times_ms.size() < 2:
		return

	for i in range(1, _tap_times_ms.size()):
		_intervals_ms.append(_tap_times_ms[i] - _tap_times_ms[i - 1])

	# Use median for outlier threshold — raw_mean is inflated when there are missed taps,
	# making a raw_mean-based threshold too loose to catch them.
	var sorted: Array = _intervals_ms.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	var median_ms: float = float(sorted[mid]) if sorted.size() % 2 != 0 else (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5
	_outlier_threshold_ms = median_ms * 1.75

	var clean: Array = []
	for iv in _intervals_ms:
		if iv <= _outlier_threshold_ms:
			clean.append(iv)

	var stats_source: Array = clean if clean.size() >= 2 else _intervals_ms

	var s: float = 0.0
	for iv in stats_source:
		s += iv
	_mean_ms = s / float(stats_source.size())

	var variance: float = 0.0
	for iv in stats_source:
		var d: float = iv - _mean_ms
		variance += d * d
	variance /= float(stats_source.size())
	_stddev_ms = sqrt(variance)

	_bpm = 60000.0 / _mean_ms if _mean_ms > 0.0 else 0.0

	var expected: float = _duration_ms / _mean_ms if _mean_ms > 0.0 else 0.0
	_missed_breaths = maxi(0, roundi(expected) - _tap_times_ms.size())

func _show_results() -> void:
	$SessionOverlay.hide()
	_results_panel.show()

	if _tap_times_ms.size() < 2:
		_metrics_label.text = "Too few taps to analyze.\nStart a new session and tap each breath."
		return

	var mean_sec: float = _mean_ms / 1000.0
	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60

	var text: String = ""
	text += "Session: %d:%02d min\n" % [dur_min, dur_sec]
	text += "Breaths tapped: %d\n" % [_tap_times_ms.size()]
	text += "Mean interval: %.2f s  (%.1f bpm)\n" % [mean_sec, _bpm]
	text += "Consistency: %d / 100\n" % [_consistency_score()]
	# text += "Deviation from mean: %.0f ms\n" % [_stddev_ms]
	text += "Estimated missed taps: %d\n" % [_missed_breaths]
	_metrics_label.text = text.strip_edges()

	_graph.set_data(_tap_times_ms, _duration_ms)
	_graph.queue_redraw()

func get_session_score(didwin: bool, wasaborted: bool) -> Array:
	return [didwin, wasaborted,
		int(_duration_ms / 60000.0),
		int(_mean_ms),
		_bpm,
		_tap_times_ms.size(),
		_missed_breaths]

# --- what the coach needs to point at -------------------------------------------------------

# The breathing circle, in screen space. tap_area draws it centered on itself at a fixed radius.
func tutorial_circle_rect() -> Rect2:
	var r: float = 220.0 if MainGlobals.is_mobile() else 150.0
	var c: Vector2 = _tap_area.get_global_transform() * (_tap_area.size / 2.0)
	return Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))

func tutorial_tap_count() -> int:
	return _tap_times_ms.size()

# The gap between the last two taps, in seconds; 0 until there are two.
func tutorial_last_interval_sec() -> float:
	var n: int = _tap_times_ms.size()
	if n < 2:
		return 0.0
	return float(_tap_times_ms[n - 1] - _tap_times_ms[n - 2]) / 1000.0

func get_tap_draw_state() -> Dictionary:
	return {
		"ring_active": _ring_active,
		"ring_pos": _ring_pos,
		"ring_age": _ring_age,
		"session_active": not _session_complete and game.level_is_ready,
		"session_progress": clampf(_elapsed_ms / _duration_ms, 0.0, 1.0) if _duration_ms > 0.0 else 0.0,
		"breath_value": _compute_breath_value(),
		"anim_active": _anim_active,
		"amplitude_factor": _display_amp_factor,
	}

func _on_again_pressed() -> void:
	_results_panel.hide()
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
