extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

# ---- Keyboard layout constants (also in globals.gd) ----
const ROW0: String = "QWERTYUIOP"
const ROW1: String = "ASDFGHJKL"
const ROW2: String = "ZXCVBNM"
const KEY_GAP: float = 4.0

const OUTLIER_IQR_FACTOR: float = 3.0
const MIN_INTER_KEY_MS: float = 40.0
const BIAS_THRESHOLD: float = 0.22

# ---- Session state ----
var game: GenericGameUtil
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

# Target text
var _passage_order: Array = []
var _passage_idx: int = 0
var _target: String = ""
var _target_pos: int = 0

# Per-position tracking (parallel arrays, resized on backspace)
var _char_correctness: Array = []   # bool: was this position correct?
var _char_pressed: Array = []       # String: what key was actually pressed

# Measurements
var _inter_key_times: Array = []
var _last_press_elapsed_ms: float = -1.0

# Per expected-key hit data
var _key_hits: Dictionary = {}       # char -> Array[Vector2] (spine-error dx,dy; for stats)
var _key_hit_dists: Dictionary = {}  # char -> Array[float] (capsule distance; for colour)
var _key_taps: Dictionary = {}       # char -> Array[Vector2] (actual offset from center; for dot position)

# Counts
var _correct_chars: int = 0
var _mistakes: int = 0
var _backspaces: int = 0

# Keyboard state
var _keys_alpha: Array = []
var _keys_num: Array = []
var _show_num_layer: bool = false
var _key_w: float = 62.0
var _key_h: float = 58.0

# Case handling
var _case_sensitive: bool = false   # if true, Shift is shown and input must match casing
var _shift_on: bool = false         # one-shot Shift state (next letter capitalised)

# Visual feedback
var _wrong_key_label: String = ""
var _error_flash_ms: float = 0.0
var _last_pressed_key_label: String = ""
var _key_press_anim_ms: float = 0.0
const ERROR_FLASH_DUR: float = 130.0
const KEY_ANIM_DUR: float = 80.0

var _sw: float = 680.0
var _sh: float = 748.0
var _font: Font = null
var _mono_font: Font = null   # monospace, for the reference/typed text so they align

# Debounce: emulate_touch_from_mouse fires both touch+mouse for one tap
var _last_tap_wall_ms: int = -100

@onready var _canvas: Control = $TypeCanvas
@onready var _timer_label: Label = $SessionOverlay/TimerLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _results_vbox: VBoxContainer = $ResultsPanel/Margin/VBox

# ---- Ready ----

func _ready() -> void:
	game = TypitG.game
	_sw = float(MainGlobals.screen_size.x)
	_sh = float(MainGlobals.screen_size.y)
	_font = MainGlobals.get_system_sans_font()
	var mf: SystemFont = SystemFont.new()
	mf.font_names = PackedStringArray(["Liberation Mono", "DejaVu Sans Mono", "Noto Sans Mono", "Courier New", "monospace"])
	_mono_font = mf

	var f: Font = _font
	var t: Theme = Theme.new()
	t.set_font("font", "Label", f)
	t.set_font("font", "Button", f)
	$SessionOverlay.theme = t
	_results_panel.theme = t

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.13, 1.0)
	_results_panel.add_theme_stylebox_override("panel", panel_style)
	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = $ResultsPanel/Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + 12)

	_results_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_vbox.add_theme_constant_override("separation", 3)

	if MainGlobals.is_mobile():
		_timer_label.add_theme_font_size_override("font_size", 40)
	else:
		_timer_label.add_theme_font_size_override("font_size", 24)

	_results_panel.hide()

# ---- Public API ----

func new_game() -> void:
	_elapsed_ms = 0.0
	_session_complete = false
	_inter_key_times = []
	_last_press_elapsed_ms = -1.0
	_key_hits = {}
	_key_hit_dists = {}
	_key_taps = {}
	_char_correctness = []
	_char_pressed = []
	_correct_chars = 0
	_mistakes = 0
	_backspaces = 0
	_error_flash_ms = 0.0
	_wrong_key_label = ""
	_last_pressed_key_label = ""
	_key_press_anim_ms = 0.0
	_show_num_layer = false
	_last_tap_wall_ms = -100
	_case_sensitive = TypitG.case_sensitive(TypitG.selected_level)
	_shift_on = false

	var lvl_idx: int = TypitG.level_index(TypitG.selected_level)
	_key_w = TypitG.LEVEL_KEY_W[lvl_idx]
	_key_h = TypitG.LEVEL_KEY_H[lvl_idx]
	_keys_alpha = _build_alpha_keyboard()
	_keys_num = _build_num_keyboard()

	_passage_order = []
	for i in range(TypitLevelConfig.PASSAGES.size()):
		_passage_order.append(i)
	_passage_order.shuffle()
	_passage_idx = 0
	_load_passage()

	game.score = 0
	game.score_was_changed = false
	game.level_is_ready = true
	game.playing = true
	$SessionOverlay.show()
	_results_panel.hide()
	_canvas.queue_redraw()

# ---- Process ----

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	_elapsed_ms += delta * 1000.0

	if _error_flash_ms > 0.0:
		_error_flash_ms -= delta * 1000.0
	if _key_press_anim_ms > 0.0:
		_key_press_anim_ms -= delta * 1000.0

	# Show elapsed time (no time limit)
	var elapsed_s: int = int(_elapsed_ms / 1000.0)
	_timer_label.text = "%d:%02d" % [elapsed_s / 60, elapsed_s % 60]
	_canvas.queue_redraw()

# ---- Input ----

func _input(event: InputEvent) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	var touch_pos: Vector2 = Vector2.ZERO
	var got_touch: bool = false

	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = event as InputEventScreenTouch
		if e.pressed:
			touch_pos = e.position
			got_touch = true
	elif event is InputEventMouseButton:
		var e: InputEventMouseButton = event as InputEventMouseButton
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			touch_pos = e.position
			got_touch = true

	if not got_touch:
		return

	# Debounce: both emulated events arrive within <5ms; 30ms clears them safely
	var now: int = Time.get_ticks_msec()
	if now - _last_tap_wall_ms < 30:
		get_viewport().set_input_as_handled()
		return
	_last_tap_wall_ms = now
	get_viewport().set_input_as_handled()

	var active_keys: Array = _keys_num if _show_num_layer else _keys_alpha
	var hit_key: Dictionary = _find_key(touch_pos, active_keys)
	if hit_key.is_empty():
		return

	_handle_keypress(hit_key, touch_pos)

func _find_key(pos: Vector2, keys: Array) -> Dictionary:
	for k in keys:
		var hw: float = k.hit_w * 0.5
		var hh: float = k.hit_h * 0.5
		if pos.x >= k.cx - hw and pos.x <= k.cx + hw and pos.y >= k.cy - hh and pos.y <= k.cy + hh:
			return k
	return {}

func _handle_keypress(key: Dictionary, touch_pos: Vector2) -> void:
	var key_type: String = key.key_type
	_last_pressed_key_label = key.label
	_key_press_anim_ms = KEY_ANIM_DUR

	if key_type == "backspace":
		if _target_pos > 0:
			_target_pos -= 1
			if _char_correctness.size() > _target_pos:
				_char_correctness.resize(_target_pos)
			if _char_pressed.size() > _target_pos:
				_char_pressed.resize(_target_pos)
			_backspaces += 1
		_canvas.queue_redraw()
		return

	if key_type == "done":
		_finish_session()
		return

	if key_type == "num_toggle":
		_show_num_layer = true
		_canvas.queue_redraw()
		return

	if key_type == "alpha_toggle":
		_show_num_layer = false
		_canvas.queue_redraw()
		return

	if key_type == "shift":
		# Only meaningful on case-sensitive levels (where the key is shown)
		if _case_sensitive:
			_shift_on = not _shift_on
			_canvas.queue_redraw()
		return

	if key_type not in ["char", "space"]:
		return

	if _target_pos >= _target.length():
		return

	var pressed_char: String = key.action
	# Apply one-shot Shift (case-sensitive levels only) → capitalise this letter
	if _case_sensitive and _shift_on:
		pressed_char = pressed_char.to_upper()
	_shift_on = false
	var expected_char: String = _target[_target_pos]

	if _last_press_elapsed_ms >= 0.0:
		var ikt: float = _elapsed_ms - _last_press_elapsed_ms
		if ikt >= MIN_INTER_KEY_MS:
			_inter_key_times.append(ikt)
	_last_press_elapsed_ms = _elapsed_ms

	# Case-sensitive levels require exact case; otherwise compare case-insensitively
	var is_correct: bool
	if _case_sensitive:
		is_correct = pressed_char == expected_char
	else:
		is_correct = pressed_char.to_lower() == expected_char.to_lower()

	# Record position data for every tap, measured against the EXPECTED key's spine
	# (capsule model — tapping anywhere along the central band = ~0 error).
	var expected_lower: String = expected_char.to_lower()
	var exp_key: Dictionary = _find_key_by_char(expected_lower, _keys_alpha)
	if not exp_key.is_empty():
		var spine: Vector2 = _spine_nearest(touch_pos, exp_key)
		var dx: float = touch_pos.x - spine.x
		var dy: float = touch_pos.y - spine.y
		var raw_mag: float = sqrt(dx * dx + dy * dy)
		# For the spine-error components (colour/bias) cap the magnitude at 150% of the
		# capsule radius so a far wrong key stays bounded. The distance metric instead
		# stores the RAW magnitude and rejects anything over 150% (see _compute_stats).
		var cap: float = 1.5 * (exp_key.h * 0.5)
		if raw_mag > cap and raw_mag > 0.0:
			var s: float = cap / raw_mag
			dx *= s
			dy *= s
		# Key by lowercase so upper/title-case targets don't split a key's data
		if not _key_hits.has(expected_lower):
			_key_hits[expected_lower] = []
			_key_hit_dists[expected_lower] = []
			_key_taps[expected_lower] = []
		_key_hits[expected_lower].append(Vector2(dx, dy))
		_key_hit_dists[expected_lower].append(raw_mag)
		# Actual offset from the key center — for showing WHERE the tap landed
		_key_taps[expected_lower].append(Vector2(touch_pos.x - exp_key.cx, touch_pos.y - exp_key.cy))

	_char_correctness.append(is_correct)
	_char_pressed.append(pressed_char)
	_target_pos += 1

	if is_correct:
		_correct_chars += 1
	else:
		_mistakes += 1
		_wrong_key_label = key.label
		_error_flash_ms = ERROR_FLASH_DUR

	_canvas.queue_redraw()

func _find_key_by_char(ch: String, keys: Array) -> Dictionary:
	for k in keys:
		if k.action == ch:
			return k
	return {}

func _load_passage() -> void:
	if _passage_order.is_empty():
		return
	var idx: int = _passage_order[_passage_idx % _passage_order.size()]
	_target = TypitLevelConfig.PASSAGES[idx].to_lower().strip_edges()
	_target = _truncate_to_words(_target, TypitG.max_len(TypitG.selected_level))
	_target = _apply_case(_target, TypitG.text_case(TypitG.selected_level))
	_target_pos = 0
	_char_correctness = []
	_char_pressed = []
	_passage_idx += 1

# Cut a passage to at most max_len characters, only at a whitespace boundary
# (never mid-word) and never ending on a space. max_len <= 0 means no limit.
func _truncate_to_words(s: String, max_len: int) -> String:
	if max_len <= 0 or s.length() <= max_len:
		return s.strip_edges()
	# Last space at or before the limit → cut there (drops the space, no mid-word cut)
	var cut: int = s.rfind(" ", max_len)
	if cut > 0:
		return s.substr(0, cut).strip_edges()
	# First word is longer than the limit — unavoidable hard cut
	return s.substr(0, max_len).strip_edges()

func _apply_case(s: String, mode: String) -> String:
	match mode:
		"upper":
			return s.to_upper()
		"title":
			var words: Array = s.split(" ")
			var out: Array = []
			for wd in words:
				if (wd as String).length() > 0:
					out.append((wd as String).substr(0, 1).to_upper() + (wd as String).substr(1))
				else:
					out.append(wd)
			return " ".join(out)
		"sentence":
			if s.length() > 0:
				return s.substr(0, 1).to_upper() + s.substr(1)
			return s
		_:
			return s

# ---- Distance metric ----
# Nearest point on the key's horizontal capsule spine.
# Spine runs from (cx - w/2 + r, cy) to (cx + w/2 - r, cy), where r = h/2.
# Tapping anywhere along this central band gives distance 0 — the correct
# model for wide rectangular keys (e.g. the space bar).
func _spine_nearest(touch: Vector2, key: Dictionary) -> Vector2:
	var cx: float = key.cx
	var cy: float = key.cy
	var half_w: float = key.w * 0.5
	var r: float = key.h * 0.5
	var lx0: float = cx - half_w + r
	var lx1: float = cx + half_w - r
	if lx0 >= lx1:
		return Vector2(cx, cy)
	return Vector2(clampf(touch.x, lx0, lx1), cy)

func _capsule_dist(touch: Vector2, key: Dictionary) -> float:
	return touch.distance_to(_spine_nearest(touch, key))

# ---- Session end ----

func _finish_session() -> void:
	if _session_complete:
		return
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	game.score_was_changed = _correct_chars > 0
	$SessionOverlay.hide()

	var stats: Dictionary = _compute_stats()
	# Score = speed in cpm so the "Score" chart tab shows typing speed over time
	game.score = int(stats.speed_cpm)
	_build_results_panel(stats)
	_results_panel.show()

	if _correct_chars > 0:
		# [4]=level [5]=correct [6]=total [7]=mistakes [8]=speed_cpm [9]=dist_pct [10]=mistake_rate%
		var total: int = _correct_chars + _mistakes
		var mistake_rate: int = int(float(_mistakes) / float(max(1, total)) * 100.0)
		var extra: Array = [
			TypitG.selected_level,
			_correct_chars,
			total,
			_mistakes,
			int(stats.speed_cpm),
			int(stats.dist_pct),
			mistake_rate,
		]
		game.save_score(extra)
	_save_key_data()
	sig_session_done.emit()

# ---- Per-key data persistence ----
# Saves per-session per-key aggregate to a user-specific file. Per-key array:
# [n, sum_dx, sum_dy, sum_dx2, sum_dy2, key_w, key_h, sum_ax, sum_ay, sum_ax2, sum_ay2]
#   d* = spine-error components (for the dx/dy accuracy numbers)
#   a* = actual offset from key center (for the graphic's position/spread)

func _save_key_data() -> void:
	if _key_hits.is_empty():
		return
	var data: Dictionary = _load_key_data_raw()
	var sessions: Array = data.get("sessions", [])

	var key_data: Dictionary = {}
	for ch in _key_hits.keys():
		var hits: Array = _key_hits[ch]
		var taps: Array = _key_taps.get(ch, [])
		var n: int = hits.size()
		var sum_dx: float = 0.0
		var sum_dy: float = 0.0
		var sum_dx2: float = 0.0
		var sum_dy2: float = 0.0
		for v in hits:
			sum_dx += v.x
			sum_dy += v.y
			sum_dx2 += v.x * v.x
			sum_dy2 += v.y * v.y
		var sum_ax: float = 0.0
		var sum_ay: float = 0.0
		var sum_ax2: float = 0.0
		var sum_ay2: float = 0.0
		for v in taps:
			sum_ax += v.x
			sum_ay += v.y
			sum_ax2 += v.x * v.x
			sum_ay2 += v.y * v.y
		# Store the key's actual width/height so the stats screen can normalise correctly
		var kd: Dictionary = _find_key_by_char(ch, _keys_alpha)
		var kwid: float = kd.get("w", _key_w)
		var khgt: float = kd.get("h", _key_h)
		key_data[ch] = [n, sum_dx, sum_dy, sum_dx2, sum_dy2, kwid, khgt,
			sum_ax, sum_ay, sum_ax2, sum_ay2]

	sessions.append({
		"ts": int(Time.get_unix_time_from_system()),
		"level": TypitG.selected_level,
		"keys": key_data,
	})

	var max_n: int = TypitG.KEY_STATS_SESSIONS
	if max_n > 0 and sessions.size() > max_n:
		sessions = sessions.slice(sessions.size() - max_n)

	data["sessions"] = sessions
	var path: String = TypitG.get_key_data_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func _load_key_data_raw() -> Dictionary:
	var path: String = TypitG.get_key_data_path()
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	file.close()
	if data is Dictionary:
		return data as Dictionary
	return {}

# ---- Statistics ----

func _compute_stats() -> Dictionary:
	var filtered_times: Array = _filter_outliers(_inter_key_times)
	var effective_ms: float = 0.0
	for t in filtered_times:
		effective_ms += float(t)
	var speed_cpm: float = 0.0
	if effective_ms > 100.0:
		speed_cpm = float(_correct_chars + _mistakes) / (effective_ms / 60000.0)

	# Reject any tap whose error exceeds 150% of the capsule radius (a wrong/far key),
	# then RMS the rest. A simple fixed threshold is more suitable than IQR for the
	# few samples in a short sentence. All keys share the same height, so one threshold.
	var dist_reject: float = _key_h * 0.5 * 1.5
	var kept_dists: Array = []
	for ch in _key_hit_dists.keys():
		for d in _key_hit_dists[ch]:
			if float(d) <= dist_reject:
				kept_dists.append(d)
	var rms: float = _compute_rms(kept_dists)

	# Final text state. _char_correctness reflects corrections (backspace pops entries).
	var typed_len: int = _char_correctness.size()
	var uncorrected_typed: int = 0
	for ok in _char_correctness:
		if not ok:
			uncorrected_typed += 1
	# Letters never typed (Done pressed early) count as errors too.
	var untyped: int = maxi(0, _target.length() - typed_len)
	var final_correct: int = typed_len - uncorrected_typed
	var total: int = _target.length()
	var wrong_total: int = uncorrected_typed + untyped
	# Fixed = wrong keypresses that are no longer wrong in the final text
	var fixed: int = maxi(0, _mistakes - uncorrected_typed)
	# Accuracy = final correct / total positions in the full passage
	var acc: float = 100.0
	if total > 0:
		acc = float(final_correct) / float(total) * 100.0

	var dist_pct: float = 0.0
	if _key_h > 0.0:
		dist_pct = rms / (_key_h * 0.5) * 100.0

	return {
		"speed_cpm": speed_cpm,
		"rms": rms,
		"dist_pct": dist_pct,
		"accuracy": acc,
		"correct": final_correct,
		"wrong": wrong_total,
		"fixed": fixed,
		"backspaces": _backspaces,
	}

func _compute_rms(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum_sq: float = 0.0
	for v in arr:
		sum_sq += float(v) * float(v)
	return sqrt(sum_sq / float(arr.size()))

func _filter_outliers(arr: Array) -> Array:
	if arr.size() < 4:
		return arr.duplicate()
	var sorted: Array = arr.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var q1: float = float(sorted[n / 4])
	var q3: float = float(sorted[3 * n / 4])
	var upper: float = q3 + OUTLIER_IQR_FACTOR * (q3 - q1)
	var out: Array = []
	for v in arr:
		if float(v) <= upper:
			out.append(v)
	return out

# Bias analysis (data kept for typit_scores.gd; not shown in summary)
func _compute_key_bias() -> Array:
	var biases: Array = []
	for ch in _key_hits.keys():
		var hits: Array = _key_hits[ch]
		if hits.size() < 3:
			continue
		var sum_dx: float = 0.0
		var sum_dy: float = 0.0
		for v in hits:
			sum_dx += v.x
			sum_dy += v.y
		var mean_dx: float = sum_dx / float(hits.size())
		var mean_dy: float = sum_dy / float(hits.size())
		var thr_x: float = _key_w * BIAS_THRESHOLD
		var thr_y: float = _key_h * BIAS_THRESHOLD
		var dirs: Array = []
		if mean_dx < -thr_x:
			dirs.append("left")
		elif mean_dx > thr_x:
			dirs.append("right")
		if mean_dy < -thr_y:
			dirs.append("up")
		elif mean_dy > thr_y:
			dirs.append("down")
		if dirs.size() > 0:
			biases.append({"key": ch, "mean_dx": mean_dx, "mean_dy": mean_dy,
				"dirs": dirs, "n": hits.size()})
	return biases

# ---- Results panel ----

func _build_results_panel(stats: Dictionary) -> void:
	for ch in _results_vbox.get_children():
		ch.queue_free()

	_results_vbox.add_theme_constant_override("separation", 3)

	var mobile: bool = MainGlobals.is_mobile()
	var fs_title: int = 28 if mobile else 20
	var fs_stat: int = 22 if mobile else 16
	var fs_small: int = 18 if mobile else 13

	_add_label(_results_vbox, "Done!", fs_title, Color(0.92, 0.96, 1.0, 1.0))

	var elapsed_s: int = int(_elapsed_ms / 1000.0)
	_add_label(_results_vbox, "%d:%02d  ·  Level %d  ·  Backspaces: %d" % [
		elapsed_s / 60, elapsed_s % 60, TypitG.selected_level, stats.backspaces],
		fs_small, Color(0.65, 0.72, 0.90, 0.75))

	_add_label(_results_vbox, "Correct: %d  ·  Wrong: %d  ·  Fixed: %d" % [
		stats.correct, stats.wrong, stats.fixed],
		fs_stat, Color(0.80, 0.95, 0.75, 1.0))

	_add_label(_results_vbox, "Accuracy: %.0f%%" % stats.accuracy,
		fs_stat, Color(0.80, 0.95, 0.75, 1.0))

	_add_label(_results_vbox, "Speed: %.1f cpm  ·  Distance: %.0f%%" % [
		stats.speed_cpm, stats.dist_pct],
		fs_stat, Color(0.95, 0.88, 0.65, 1.0))

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 4.0)
	_results_vbox.add_child(gap)

	_add_label(_results_vbox, "tap accuracy  (green = center  ·  red = outside key)", fs_small,
		Color(0.55, 0.65, 0.80, 0.55))

	var heatmap: Control = Control.new()
	heatmap.custom_minimum_size = Vector2(0.0, 120.0)
	heatmap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heatmap.draw.connect(_draw_heatmap.bind(heatmap))
	_results_vbox.add_child(heatmap)
	heatmap.queue_redraw()

	# If errors remain, show the correct vs typed sentences (wrong letters in red)
	if stats.wrong > 0:
		_add_comparison_sentences(fs_small)

	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0.0, 8.0)
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_vbox.add_child(gap2)

	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	_results_vbox.add_child(btn_hbox)

	var btn_again: Button = _make_button("Again", fs_stat)
	btn_again.pressed.connect(_on_again_pressed)
	btn_hbox.add_child(btn_again)

	var btn_done: Button = _make_button("Done", fs_stat)
	btn_done.pressed.connect(_on_done_pressed)
	btn_hbox.add_child(btn_done)

func _add_label(parent: Node, text: String, font_size: int, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)

# Show the expected and typed sentences (wrong letters red), char-aligned & centered.
func _add_comparison_sentences(_fs_small: int) -> void:
	var base_cfs: int = 16 if MainGlobals.is_mobile() else 12
	var ctrl: Control = Control.new()
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.custom_minimum_size = Vector2(0.0, float(base_cfs + 6) * 2.0 + 10.0)
	ctrl.draw.connect(_draw_comparison.bind(ctrl, base_cfs))
	_results_vbox.add_child(ctrl)
	ctrl.queue_redraw()

func _draw_comparison(canvas: Control, base_cfs: int) -> void:
	if _mono_font == null:
		return
	var w: float = canvas.size.x
	var n: int = _target.length()
	if n == 0:
		return

	# Shrink font until the whole sentence fits the width on one line.
	var cfs: int = base_cfs
	var adv: float = _mono_font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	var max_w: float = w - 8.0
	while float(n) * adv > max_w and cfs > 8:
		cfs -= 1
		adv = _mono_font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x

	var block_w: float = adv * float(n)
	var start_x: float = maxf(2.0, (w - block_w) * 0.5)
	var line_h: float = float(cfs) + 6.0
	var want_y: float = float(cfs)
	var got_y: float = want_y + line_h + 4.0
	var light: Color = Color(0.88, 0.92, 1.0, 1.0)
	var red: Color = Color(1.0, 0.33, 0.27, 1.0)

	# Expected sentence
	for i in range(n):
		canvas.draw_string(_mono_font, Vector2(start_x + float(i) * adv, want_y),
			_target[i], HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, light)

	# Typed sentence (case-matched; wrong letters red, wrong/untyped → red middle dot).
	# Loop over the FULL passage so letters never typed (Done pressed early) show as errors.
	for i in range(n):
		var dispc: String
		var wrong: bool
		if i < _char_pressed.size():
			dispc = _char_pressed[i]
			if not _case_sensitive and _target[i] != _target[i].to_lower():
				dispc = dispc.to_upper()
			wrong = i < _char_correctness.size() and not _char_correctness[i]
		else:
			# Never typed → error
			dispc = "·"
			wrong = true
		if wrong and dispc == " ":
			dispc = "·"
		canvas.draw_string(_mono_font, Vector2(start_x + float(i) * adv, got_y),
			dispc, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, red if wrong else light)

func _make_button(text: String, font_size: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130.0, 50.0)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 1.0))
	var sty: StyleBoxFlat = StyleBoxFlat.new()
	sty.bg_color = Color(0.14, 0.28, 0.48, 1.0)
	sty.corner_radius_top_left = 10
	sty.corner_radius_top_right = 10
	sty.corner_radius_bottom_left = 10
	sty.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", sty)
	var sty_p: StyleBoxFlat = sty.duplicate()
	sty_p.bg_color = Color(0.08, 0.18, 0.34, 1.0)
	btn.add_theme_stylebox_override("pressed", sty_p)
	btn.add_theme_stylebox_override("hover", sty)
	return btn

# ---- Drawing: heat map ----

func _draw_heatmap(canvas: Control) -> void:
	var cw: float = canvas.size.x
	var ch: float = canvas.size.y
	if cw <= 0.0 or ch <= 0.0:
		return

	# Fit the whole keyboard inside this control (width AND height), centered,
	# so it never overflows onto the elements below it.
	var kb_top: float = _kb_top_y()
	var kb_h_screen: float = 4.0 * _key_h + 3.0 * KEY_GAP
	var draw_scale: float = minf(cw / _sw, ch / kb_h_screen)
	var off_x: float = (cw - _sw * draw_scale) * 0.5
	var off_y: float = (ch - kb_h_screen * draw_scale) * 0.5

	for k in _keys_alpha:
		if k.key_type not in ["char", "space"]:
			continue
		var ch_str: String = k.action
		var taps: Array = _key_taps.get(ch_str, [])
		var dists: Array = _key_hit_dists.get(ch_str, [])

		var kw: float = k.w * draw_scale
		var kh: float = k.h * draw_scale
		var cx: float = k.cx * draw_scale + off_x
		var cy_local: float = (k.cy - kb_top) * draw_scale + off_y
		var r: float = k.h * 0.5   # capsule radius (unscaled), for colour normalisation

		# Neutral key background so the dots stand out
		var rect: Rect2 = Rect2(cx - kw * 0.5, cy_local - kh * 0.5, kw, kh)
		canvas.draw_rect(rect, Color(0.13, 0.16, 0.24, 1.0))
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.40), false, 1.0)

		if _font != null and kw >= 10.0:
			var lbl: String = k.label.to_upper()
			var fs: int = clampi(int(kh * 0.50), 7, 22)
			canvas.draw_string(_font, Vector2(cx - kw * 0.5 + 1.0, cy_local + float(fs) * 0.42),
				lbl, HORIZONTAL_ALIGNMENT_CENTER, kw - 2.0, fs,
				Color(1.0, 1.0, 1.0, 0.70 if not taps.is_empty() else 0.25))

		# One dot per tap, drawn at the ACTUAL tap position (offset from center, scaled),
		# coloured green→red by that tap's spine distance. Position is clamped to the key
		# so a stray far tap pins to the edge instead of flying off.
		var dot_r: float = maxf(1.5, kh * 0.10)
		var lim_x: float = maxf(0.0, kw * 0.5 - dot_r)
		var lim_y: float = maxf(0.0, kh * 0.5 - dot_r)
		for i in range(taps.size()):
			var a: Vector2 = taps[i]
			var ddx: float = clampf(a.x * draw_scale, -lim_x, lim_x)
			var ddy: float = clampf(a.y * draw_scale, -lim_y, lim_y)
			var dist: float = float(dists[i]) if i < dists.size() else 0.0
			var t: float = clampf(dist / r, 0.0, 1.0)
			var col: Color = Color.from_hsv(0.33 * (1.0 - t), 0.85, 0.95, 1.0)
			canvas.draw_circle(Vector2(cx + ddx, cy_local + ddy), dot_r, col, true, -1.0, true)

# ---- Main game drawing ----

func _do_draw(canvas: CanvasItem) -> void:
	if _session_complete:
		return
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y

	canvas.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.10, 0.12, 0.16, 1.0))
	_draw_text_area(canvas, w)
	_draw_keyboard(canvas, _keys_num if _show_num_layer else _keys_alpha)

func _draw_text_area(canvas: CanvasItem, w: float) -> void:
	if _mono_font == null or _target.is_empty():
		return

	var mobile: bool = MainGlobals.is_mobile()
	var fs: int = 38 if mobile else 28
	var pad: float = 16.0
	var header_h: float = float(MainGlobals.header_height)
	var kb_top: float = _kb_top_y()
	var avail_h: float = kb_top - header_h - 8.0
	var white: Color = Color(1.0, 1.0, 1.0, 1.0)

	# Monospace → fixed advance, so the typed line aligns under the reference line.
	var adv: float = _mono_font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var n: int = _target.length()
	var cols: int = maxi(1, int((w - pad * 2.0) / adv))   # chars that fit per line

	# Word-wrap into char-index ranges [start, end). Break after the last space that
	# fits; only hard-break if a single word is longer than a line.
	var lines: Array = []
	var i: int = 0
	while i < n:
		var line_end: int = mini(i + cols, n)
		if line_end < n:
			var brk: int = _target.rfind(" ", line_end - 1)
			if brk >= i:
				line_end = brk + 1
		lines.append(Vector2i(i, line_end))
		i = line_end
	if lines.is_empty():
		return

	var gap_ref_typed: float = 12.0   # ref line → its typed line (clears the caret)
	var gap_rows: float = float(fs) + 18.0   # between wrapped rows (clear of typed letters)
	var row_h: float = float(fs) * 2.0 + gap_ref_typed
	var block_h: float = float(lines.size()) * row_h + float(lines.size() - 1) * gap_rows
	var block_top: float = maxf(header_h + 4.0, header_h + (avail_h - block_h) * 0.5)

	for li in range(lines.size()):
		var rng: Vector2i = lines[li]
		var lstart: int = rng.x
		var count: int = rng.y - lstart
		var row_top: float = block_top + float(li) * (row_h + gap_rows)
		var ref_y: float = row_top + float(fs)
		var typed_y: float = ref_y + gap_ref_typed + float(fs)
		# Single line is centered; wrapped lines are left-aligned for readability.
		var start_x: float = pad
		if lines.size() == 1:
			start_x = maxf(pad, (w - adv * float(count)) * 0.5)

		for c in range(count):
			var gi: int = lstart + c
			var cx_i: float = start_x + float(c) * adv
			canvas.draw_string(_mono_font, Vector2(cx_i, ref_y), _target[gi],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
			if gi == _target_pos:
				canvas.draw_rect(Rect2(cx_i, ref_y + 4.0, adv, 3.0), Color(1.0, 0.85, 0.20, 0.95))
			if gi < _char_pressed.size():
				var disp: String = _char_pressed[gi]
				# Case-insensitive: show in target case so it reads right. Case-sensitive:
				# show exactly what was produced (so wrong casing is visible).
				if not _case_sensitive and _target[gi] != _target[gi].to_lower():
					disp = disp.to_upper()
				canvas.draw_string(_mono_font, Vector2(cx_i, typed_y), disp,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)

	# Passage-complete prompt
	if _target_pos >= n:
		var prompt_y: float = minf(block_top + block_h + float(fs), kb_top - 6.0)
		canvas.draw_string(_font, Vector2(0.0, prompt_y),
			"✓  Press Done",
			HORIZONTAL_ALIGNMENT_CENTER, w, fs - 10,
			Color(0.55, 0.88, 0.65, 0.80))

func _kb_top_y() -> float:
	# Read live screen_size (already has footer subtracted) and add extra pad
	var sh: float = float(MainGlobals.screen_size.y)
	var kb_h: float = 4.0 * _key_h + 3.0 * KEY_GAP
	return sh - kb_h - 14.0

# ---- Keyboard drawing ----

func _draw_keyboard(canvas: CanvasItem, keys: Array) -> void:
	for k in keys:
		var is_pressed: bool = _key_press_anim_ms > 0.0 and k.label == _last_pressed_key_label
		_draw_key(canvas, k, is_pressed)

func _draw_key(canvas: CanvasItem, k: Dictionary, is_pressed: bool) -> void:
	var cx: float = k.cx
	var cy: float = k.cy
	var kw: float = k.w
	var kh: float = k.h
	var bg: Color = k.color
	# Active one-shot Shift is highlighted
	var shift_active: bool = k.key_type == "shift" and _shift_on
	if is_pressed or shift_active:
		bg = Color(minf(bg.r * 1.6, 1.0), minf(bg.g * 1.6, 1.0), minf(bg.b * 1.9, 1.0), bg.a)
	var rect: Rect2 = Rect2(cx - kw * 0.5, cy - kh * 0.5, kw, kh)
	canvas.draw_rect(rect, bg, true, -1.0)
	if shift_active:
		canvas.draw_rect(rect, Color(0.55, 0.80, 1.0, 0.9), false, 2.0)
	if _error_flash_ms > 0.0 and k.label == _wrong_key_label:
		canvas.draw_rect(rect, Color(1.0, 0.12, 0.08, (_error_flash_ms / ERROR_FLASH_DUR) * 0.60))
	canvas.draw_rect(rect, Color(0.28, 0.36, 0.52, 0.55), false, 1.0)
	if _font == null:
		return
	# On case-sensitive levels, letter keys show the case that will actually be typed.
	var label_text: String = k.label
	if k.key_type == "char" and _case_sensitive:
		label_text = k.label.to_upper() if _shift_on else k.label.to_lower()
	canvas.draw_string(_font, Vector2(cx - kw * 0.5 + 2.0, cy + float(k.font_size) * 0.42),
		label_text, HORIZONTAL_ALIGNMENT_CENTER, kw - 4.0, k.font_size, k.label_color)

# ---- Keyboard layout builders ----

func _build_alpha_keyboard() -> Array:
	var keys: Array = []
	var kw: float = _key_w
	var kh: float = _key_h
	var gap: float = KEY_GAP
	var unit: float = kw + gap
	var kb_top: float = _kb_top_y()
	var row_ys: Array = [
		kb_top + kh * 0.5,
		kb_top + (kh + gap) + kh * 0.5,
		kb_top + (kh + gap) * 2.0 + kh * 0.5,
		kb_top + (kh + gap) * 3.0 + kh * 0.5,
	]
	# All rows share the same total width as row 0 and are centered → scales with level
	var total_w: float = 10.0 * kw + 9.0 * gap
	var left: float = (_sw - total_w) * 0.5

	for i in range(10):
		var ch: String = ROW0[i]
		keys.append(_make_char_key(ch.to_lower(), ch.to_upper(),
			left + float(i) * unit + kw * 0.5, row_ys[0], kw, kh, gap))
	var r1_left: float = left + 0.5 * unit
	for i in range(9):
		var ch: String = ROW1[i]
		keys.append(_make_char_key(ch.to_lower(), ch.to_upper(),
			r1_left + float(i) * unit + kw * 0.5, row_ys[1], kw, kh, gap))

	# Row 2: [shift] + 7 letters (key-width) + backspace, the whole row centered.
	# Shift only shown on case-sensitive levels.
	var bs_w: float = kw * 1.5
	var shift_w: float = kw * 1.5
	# Total row width depends on whether shift is present (7 letters + 7 gaps + bs [+ shift+gap])
	var row2_w: float = 7.0 * kw + 7.0 * gap + bs_w
	if _case_sensitive:
		row2_w += shift_w + gap
	var r2x: float = (_sw - row2_w) * 0.5
	if _case_sensitive:
		keys.append(_make_special_key("⬆", "shift", "shift",
			r2x + shift_w * 0.5, row_ys[2], shift_w, kh, Color(0.18, 0.22, 0.32, 1.0)))
		r2x += shift_w + gap
	for i in range(7):
		var ch: String = ROW2[i]
		keys.append(_make_char_key(ch.to_lower(), ch.to_upper(),
			r2x + kw * 0.5, row_ys[2], kw, kh, gap))
		r2x += kw + gap
	keys.append(_make_special_key("⌫", "backspace", "backspace",
		r2x + bs_w * 0.5, row_ys[2], bs_w, kh, Color(0.22, 0.26, 0.36, 1.0)))

	# Row 3: 123 + space + done, within total_w
	var num_w: float = kw * 1.6
	var done_w: float = kw * 2.0
	var space_w: float = total_w - num_w - done_w - 2.0 * gap
	var r3x: float = left
	keys.append(_make_special_key("123", "num", "num_toggle",
		r3x + num_w * 0.5, row_ys[3], num_w, kh, Color(0.22, 0.26, 0.36, 1.0)))
	r3x += num_w + gap
	keys.append(_make_special_key(" ", " ", "space",
		r3x + space_w * 0.5, row_ys[3], space_w, kh, Color(0.24, 0.28, 0.40, 1.0)))
	r3x += space_w + gap
	keys.append(_make_special_key("Done", "done", "done",
		r3x + done_w * 0.5, row_ys[3], done_w, kh, Color(0.18, 0.36, 0.60, 1.0)))
	return keys

func _build_num_keyboard() -> Array:
	var keys: Array = []
	var kw: float = _key_w
	var kh: float = _key_h
	var gap: float = KEY_GAP
	var unit: float = kw + gap
	var kb_top: float = _kb_top_y()
	var row_ys: Array = [
		kb_top + kh * 0.5,
		kb_top + (kh + gap) + kh * 0.5,
		kb_top + (kh + gap) * 2.0 + kh * 0.5,
		kb_top + (kh + gap) * 3.0 + kh * 0.5,
	]
	var total_w: float = 10.0 * kw + 9.0 * gap
	var left: float = (_sw - total_w) * 0.5

	var nums0: String = "1234567890"
	for i in range(10):
		keys.append(_make_char_key(nums0[i], nums0[i],
			left + float(i) * unit + kw * 0.5, row_ys[0], kw, kh, gap))
	var row1_chars: Array = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
	for i in range(row1_chars.size()):
		keys.append(_make_char_key(row1_chars[i], row1_chars[i],
			left + float(i) * unit + kw * 0.5, row_ys[1], kw, kh, gap))

	# Row 2: symbol keys (key-width) + backspace, centered. No dead "#+=" toggle.
	var bs_w: float = kw * 1.5
	var row2_chars: Array = [".", ",", "?", "!", "'", "+", "=", "%", "*"]
	var row2_w: float = float(row2_chars.size()) * kw + float(row2_chars.size()) * gap + bs_w
	var r2x: float = (_sw - row2_w) * 0.5
	for i in range(row2_chars.size()):
		keys.append(_make_char_key(row2_chars[i], row2_chars[i],
			r2x + kw * 0.5, row_ys[2], kw, kh, gap))
		r2x += kw + gap
	keys.append(_make_special_key("⌫", "backspace", "backspace",
		r2x + bs_w * 0.5, row_ys[2], bs_w, kh, Color(0.22, 0.26, 0.36, 1.0)))

	# Row 3: ABC + space + done, within total_w
	var abc_w: float = kw * 1.6
	var done_w: float = kw * 2.0
	var space_w: float = total_w - abc_w - done_w - 2.0 * gap
	var r3x: float = left
	keys.append(_make_special_key("ABC", "alpha", "alpha_toggle",
		r3x + abc_w * 0.5, row_ys[3], abc_w, kh, Color(0.22, 0.26, 0.36, 1.0)))
	r3x += abc_w + gap
	keys.append(_make_special_key(" ", " ", "space",
		r3x + space_w * 0.5, row_ys[3], space_w, kh, Color(0.24, 0.28, 0.40, 1.0)))
	r3x += space_w + gap
	keys.append(_make_special_key("Done", "done", "done",
		r3x + done_w * 0.5, row_ys[3], done_w, kh, Color(0.18, 0.36, 0.60, 1.0)))
	return keys

func _make_char_key(action: String, display: String, cx: float, cy: float,
		kw: float, kh: float, extra_hit: float) -> Dictionary:
	var fs: int = clampi(int(kh * 0.55), 10, 32)
	return {"label": display, "action": action, "key_type": "char",
		"cx": cx, "cy": cy, "w": kw, "h": kh,
		"hit_w": kw + extra_hit, "hit_h": kh + KEY_GAP,
		"color": Color(0.20, 0.24, 0.34, 1.0),
		"label_color": Color(0.92, 0.96, 1.0, 1.0), "font_size": fs}

func _make_special_key(display: String, action: String, key_type: String,
		cx: float, cy: float, kw: float, kh: float, bg: Color) -> Dictionary:
	var fs: int = clampi(int(kh * 0.46), 9, 26)
	return {"label": display, "action": action, "key_type": key_type,
		"cx": cx, "cy": cy, "w": kw, "h": kh,
		"hit_w": kw, "hit_h": kh + KEY_GAP,
		"color": bg, "label_color": Color(0.88, 0.92, 1.0, 1.0), "font_size": fs}

# ---- Button callbacks ----

func _on_again_pressed() -> void:
	_results_panel.hide()
	game.reset(true)
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
