extends CanvasLayer

signal sig_level_is_done(level_id: int, avg_time_ms: int, pct_correct: int)
signal update_score(delta: int)

const _FEEDBACK_OK_COLOR: Color = Color(0.25, 1.0, 0.35, 1.0)
const _FEEDBACK_BAD_COLOR: Color = Color(1.0, 0.38, 0.38, 1.0)

# Characters available — uppercase letters and digits
const CHARSET: Array = [
	"A","B","C","D","E","F","G","H","I","J","K","L","M",
	"N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9",
]

# Groups of characters that look too similar to each other; avoid mixing them in options
const CONFUSABLE_GROUPS: Array = [
	["O", "0", "Q"],
	["I", "1"],
	["S", "5"],
	["Z", "2"],
	["B", "8"],
	["G", "6"],
]

var _level: int = 1
var _cfg: Dictionary = {}
var _panels_bk_color: Color = Color.ORANGE
var _dots_color: Color = Color.BLACK
var _letters_color: Color = Color.BLACK
var _timeout_bar: ProgressBar = null
var _timeout_fill_style: StyleBoxFlat = null
var _timeout_duration: float = 0.0

var _correct_char: String = ""
var _option_chars: Array = []
var _option_buttons: Array = []
var _options_hidden: bool = false
var _round_start_time: float = 0.0
var _help_open_time: float = 0.0
var _rounds_done: int = 0
var _rounds_correct: int = 0
var _total_response_time_ms: float = 0.0
var _can_click: bool = false
var _round_id: int = 0
var _first_round: bool = true
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null
var _style_pressed: StyleBoxFlat = null

func _ready() -> void:
	$CharViewport.size = Vector2i(256, 256)
	$CharViewport.transparent_bg = true
	$CharViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%CharLabel.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	var root_ctrl: Control = $"Root"
	root_ctrl.offset_left = 10.0
	root_ctrl.offset_top = 100.0
	root_ctrl.offset_right = -10.0
	root_ctrl.offset_bottom = -55.0
	if MainGlobals.is_mobile():
		root_ctrl.offset_top = 120.0
		root_ctrl.offset_bottom = -105.0
	# Hide until the first round is fully ready to avoid a flash of unstyled panels
	$"Root/GameArea".hide()
	_setup_timeout_bar()

func _setup_timeout_bar() -> void:
	var style_bg: StyleBoxFlat = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	_timeout_fill_style = StyleBoxFlat.new()
	_timeout_fill_style.bg_color = Color(0.3, 0.85, 0.3, 1.0)
	_timeout_bar = ProgressBar.new()
	_timeout_bar.max_value = 1.0
	_timeout_bar.value = 1.0
	_timeout_bar.show_percentage = false
	_timeout_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timeout_bar.offset_top = -4.0
	_timeout_bar.offset_bottom = 0.0
	_timeout_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeout_bar.z_index = 10
	_timeout_bar.add_theme_stylebox_override("background", style_bg)
	_timeout_bar.add_theme_stylebox_override("fill", _timeout_fill_style)
	$"Root".add_child(_timeout_bar)
	_timeout_bar.hide()

func _process(_delta: float) -> void:
	if not _can_click or _timeout_duration <= 0.0 or _timeout_bar == null:
		return
	var elapsed: float = Time.get_unix_time_from_system() - _round_start_time
	var progress: float = 1.0 - clamp(elapsed / _timeout_duration, 0.0, 1.0)
	_timeout_bar.value = progress
	_timeout_fill_style.bg_color = Color(0.3, 0.85, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.2, 1.0), 1.0 - progress)

func new_game(_from_scratch: bool = true, _keep_stats: bool = false) -> void:
	if not _keep_stats:
		_rounds_done = 0
		_rounds_correct = 0
		_total_response_time_ms = 0.0
	_first_round = true
	if _from_scratch:
		_level = PolkadotsG.starting_level
	_load_cfg()
	_apply_layout()
	_start_round()

func advance_level() -> void:
	_level = min(_level + 1, PolkadotsLevelConfig.LEVELS.size())

func get_level() -> int:
	return _level

func _apply_layout() -> void:
	# Build and apply the box style early so it's ready before GameArea is shown
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = _panels_bk_color
	_style_normal.border_width_left = 2
	_style_normal.border_width_top = 2
	_style_normal.border_width_right = 2
	_style_normal.border_width_bottom = 2
	_style_normal.border_color = Color(0.35, 0.35, 0.55, 1.0)
	_style_normal.corner_radius_top_left = 8
	_style_normal.corner_radius_top_right = 8
	_style_normal.corner_radius_bottom_left = 8
	_style_normal.corner_radius_bottom_right = 8
	_style_normal.content_margin_left = 0.0
	_style_normal.content_margin_right = 0.0
	_style_normal.content_margin_top = 0.0
	_style_normal.content_margin_bottom = 0.0
	_style_hover = _style_normal.duplicate() as StyleBoxFlat
	_style_hover.bg_color = _panels_bk_color.darkened(0.1)#  Color(0.95, 0.75, 0.25, 1.0)
	_style_pressed = _style_normal.duplicate() as StyleBoxFlat
	_style_pressed.bg_color = _panels_bk_color.darkened(0.2)
	%DotsInnerPanel.add_theme_stylebox_override("panel", _style_normal)

	var dots_panel: Control = $"Root/GameArea/HBox/DotsPanel"
	var opts_panel: Control = $"Root/GameArea/HBox/OptionsPanel"
	var dots_margin: MarginContainer = $"Root/GameArea/HBox/DotsPanel/DotsMargin"

	# Zero out minimum sizes so large fonts don't push the layout beyond the viewport
	dots_panel.custom_minimum_size = Vector2(0, 0)
	dots_panel.clip_contents = true
	opts_panel.custom_minimum_size = Vector2(0, 0)
	opts_panel.clip_contents = true
	%OptionsVBox.custom_minimum_size = Vector2(0, 0)

	dots_panel.size_flags_stretch_ratio = 2.0
	for prop: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		dots_margin.add_theme_constant_override(prop, 10)

func _load_cfg() -> void:
	var diff: int = clamp(_level - 1, 0, PolkadotsLevelConfig.LEVELS.size() - 1)
	_cfg = PolkadotsLevelConfig.LEVELS[diff]	
	_panels_bk_color = _cfg.get("bk_color", PolkadotsLevelConfig.default_bk_color)
	_letters_color = _cfg.get("letter_color", PolkadotsLevelConfig.default_letters_color)
	_dots_color = _cfg.get("dot_color", PolkadotsLevelConfig.default_dots_color)

func _start_round() -> void:
	_round_id += 1
	var rid: int = _round_id
	_can_click = false
	_options_hidden = false
	# Clear reveal alpha before changing CharLabel — the texture is live,
	# so any change to the SubViewport would show through if alpha > 0
	%DotsDisplay.clear_reveal()

	_correct_char = CHARSET[randi() % CHARSET.size()]
	_option_chars = _build_options(_correct_char, int(_cfg["num_options"]))

	# Render character at placeholder size; viewport will be resized after layout
	%CharLabel.text = _correct_char
	%CharLabel.add_theme_font_size_override("font_size", 200)
	# Ensure the right number of persistent buttons exist; reset their appearance
	%DotsInnerPanel.add_theme_stylebox_override("panel", _style_normal)
	_ensure_option_buttons_count(int(_cfg["num_options"]))
	for btn in _option_buttons:
		btn.text = ""
		btn.modulate = Color.WHITE
		btn.add_theme_color_override("font_color", _letters_color)
		btn.add_theme_color_override("font_hover_color", _letters_color)
		btn.add_theme_color_override("font_pressed_color", _letters_color)
		btn.add_theme_color_override("font_focus_color", _letters_color)
	# Show GameArea before awaiting so Godot computes layout (DotsDisplay.size)
	$"Root/GameArea".show()

	await get_tree().process_frame
	await get_tree().process_frame

	if _round_id != rid or not is_inside_tree():
		return

	# Between rounds: empty styled boxes are already visible; just clear dots and pause
	if not _first_round:
		%DotsDisplay.clear_dots()
		await get_tree().create_timer(0.5).timeout
		if _round_id != rid or not is_inside_tree():
			return

	_first_round = false

	# Resize CharViewport for the letter render
	$CharViewport.size = Vector2i(256, 256)
	%CharLabel.add_theme_font_size_override("font_size", 200)
	# Wait TWO frames: one for layout, one for the SubViewport to re-render at the new size
	await get_tree().process_frame
	await get_tree().process_frame
	if _round_id != rid or not is_inside_tree():
		return

	await _generate_and_show_dots(rid)
	if _round_id != rid or not is_inside_tree():
		return
	_configure_option_buttons()

	_round_start_time = Time.get_unix_time_from_system()
	_can_click = true
	_timeout_duration = float(_cfg["timeout_sec"])
	_timeout_fill_style.bg_color = Color(0.3, 0.85, 0.3, 1.0)
	_timeout_bar.value = 1.0
	_timeout_bar.show()

	var opt_sec: float = float(_cfg["option_display_sec"])
	if opt_sec > 0.0:
		$HideOptionsTimer.wait_time = opt_sec
		$HideOptionsTimer.start()
	else:
		$HideOptionsTimer.stop()

	$TimeoutTimer.wait_time = float(_cfg["timeout_sec"])
	$TimeoutTimer.start()

# ── Character selection ────────────────────────────────────────────────────────

func _build_options(correct: String, count: int) -> Array:
	# Find the confusable group that contains the correct char
	var avoid: Array = [correct]
	for group in CONFUSABLE_GROUPS:
		if correct in group:
			avoid = avoid + group
			break

	var pool: Array = CHARSET.filter(func(c: String) -> bool: return not (c in avoid))
	pool.shuffle()

	var result: Array = [correct]
	for c in pool:
		if result.size() >= count:
			break
		result.append(c)

	result.shuffle()
	return result

# ── Dot generation ────────────────────────────────────────────────────────────

func _generate_and_show_dots(rid: int) -> void:
	var img: Image = $CharViewport.get_texture().get_image()
	if img == null or img.is_empty():
		return

	img.convert(Image.FORMAT_RGBA8)
	var iw: int = img.get_width()
	var ih: int = img.get_height()

	var display_size: Vector2 = %DotsDisplay.size
	if display_size.x < 10.0 or display_size.y < 10.0:
		display_size = Vector2(260.0, 480.0)

	# Erode in image space: dot_radius screen-px → image-px
	var dot_radius_cfg: float = float(_cfg["dot_radius"])
	var erode_px: int = max(1, int(ceil(dot_radius_cfg * float(iw) / display_size.x)))

	# Collect pixels strictly inside the letter via erosion.
	# If the full erosion radius leaves nothing (e.g. thin strokes at small font sizes),
	# halve the erosion and retry until at least some pixels are found.
	var letter_pixels: Array = []
	var try_erode: int = erode_px
	while letter_pixels.is_empty():
		for y in range(ih):
			for x in range(iw):
				if img.get_pixel(x, y).a > 0.7:
					var ok: bool = true
					for dy in range(-try_erode, try_erode + 1):
						for dx in range(-try_erode, try_erode + 1):
							if dx * dx + dy * dy > try_erode * try_erode:
								continue
							var nx: int = x + dx
							var ny: int = y + dy
							if nx < 0 or ny < 0 or nx >= iw or ny >= ih or img.get_pixel(nx, ny).a <= 0.7:
								ok = false
								break
						if not ok:
							break
					if ok:
						letter_pixels.append(Vector2(float(x) / iw, float(y) / ih))
		if not letter_pixels.is_empty() or try_erode == 0:
			break
		try_erode = max(0, try_erode / 2)

	if letter_pixels.is_empty():
		return

	var dot_radius: float = float(_cfg["dot_radius"])
	var jitter: float = dot_radius * 0.5
	var inset: Vector2 = Vector2(dot_radius, dot_radius)
	var dot_origin: Vector2 = Vector2.ZERO
	var inner_origin: Vector2 = dot_origin + inset
	var inner_size: Vector2 = display_size - 2.0 * inset

	# Stratified 6×6 grid: one dot per cell until 70% of cells are covered,
	# then fill remaining count from leftover pixels.
	const GRID: int = 6
	var cells: Array = []
	cells.resize(GRID * GRID)
	for i in range(cells.size()):
		cells[i] = []
	for np in letter_pixels:
		var gx: int = clamp(int(np.x * float(GRID)), 0, GRID - 1)
		var gy: int = clamp(int(np.y * float(GRID)), 0, GRID - 1)
		cells[gy * GRID + gx].append(np)

	var non_empty: Array = []
	for cell in cells:
		if cell.size() > 0:
			cell.shuffle()
			non_empty.append(cell)
	non_empty.shuffle()

	var density: float = float(_cfg["dot_density"]) / 100.0
	var total_count: int = max(3, int(letter_pixels.size() * density))
	var coverage_target: int = int(ceil(float(non_empty.size()) * 0.7))

	var positions: Array = []
	for i in range(min(coverage_target, non_empty.size())):
		var np: Vector2 = non_empty[i].pop_back()
		var pp: Vector2 = inner_origin + np * inner_size
		pp.x += randf_range(-jitter, jitter)
		pp.y += randf_range(-jitter, jitter)
		positions.append(pp.clamp(inner_origin, inner_origin + inner_size))

	var leftovers: Array = []
	for cell in non_empty:
		leftovers.append_array(cell)
	leftovers.shuffle()
	var li: int = 0
	while positions.size() < total_count and li < leftovers.size():
		var np: Vector2 = leftovers[li]
		var pp: Vector2 = inner_origin + np * inner_size
		# pp.x += randf_range(-jitter, jitter)
		# pp.y += randf_range(-jitter, jitter)
		positions.append(pp.clamp(inner_origin, inner_origin + inner_size))
		li += 1

	var non_overlaps = []
	for i in range(positions.size()):
		var p = positions[i]
		var ok_to_use: bool = true
		for q in non_overlaps:
			var d:Vector2 = q - p
			if d.length() < 2.2 * dot_radius:
				ok_to_use = false
				break
		if ok_to_use:
			non_overlaps.append(p)
	positions = non_overlaps

	# ── Uniqueness check ──────────────────────────────────────────────────────
	# Render each wrong option and measure what fraction of dots fall inside it.
	# If > 30% overlap, replace that option. Iterate up to 3 passes so
	# replacement options are also checked.
	if positions.size() >= 3:
		for _pass in range(3):
			var bad_indices: Array = []
			for opt_i in range(_option_chars.size()):
				if _option_chars[opt_i] == _correct_char:
					continue
				%CharLabel.text = _option_chars[opt_i]
				await get_tree().process_frame
				if _round_id != rid or not is_inside_tree():
					%CharLabel.text = _correct_char
					return
				var test_img: Image = $CharViewport.get_texture().get_image()
				test_img.convert(Image.FORMAT_RGBA8)
				var tw: int = test_img.get_width()
				var th: int = test_img.get_height()
				var inside: int = 0
				for pos in positions:
					var px: int = int(pos.x / display_size.x * float(tw))
					var py: int = int(pos.y / display_size.y * float(th))
					if px >= 0 and px < tw and py >= 0 and py < th:
						if test_img.get_pixel(px, py).a > 0.5:
							inside += 1
				if float(inside) / float(positions.size()) > 0.3:
					bad_indices.append(opt_i)

			if bad_indices.is_empty():
				break

			var replace_pool: Array = CHARSET.filter(func(c: String) -> bool: return not (c in _option_chars))
			replace_pool.shuffle()
			var ri: int = 0
			for bi in bad_indices:
				if ri < replace_pool.size():
					_option_chars[bi] = replace_pool[ri]
					ri += 1

		# Restore correct char and let viewport re-render before set_dots
		%CharLabel.text = _correct_char
		await get_tree().process_frame
		if _round_id != rid or not is_inside_tree():
			return

	var texture: Texture2D = $CharViewport.get_texture()
	%DotsDisplay.set_dots(positions, dot_radius, texture, Rect2(Vector2.ZERO, display_size), _dots_color)

# ── Option buttons ─────────────────────────────────────────────────────────────

# Ensures exactly n persistent buttons exist. Creates new ones if needed; removes extras.
# Does NOT set text or connect signals.
func _ensure_option_buttons_count(n: int) -> void:
	while _option_buttons.size() > n:
		_option_buttons.pop_back().queue_free()
	# Refresh styles on existing buttons in case _apply_layout was called
	for btn in _option_buttons:
		btn.add_theme_stylebox_override("normal", _style_normal)
		btn.add_theme_stylebox_override("hover", _style_hover)
		btn.add_theme_stylebox_override("pressed", _style_pressed)
	while _option_buttons.size() < n:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 0)
		btn.clip_contents = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", MainGlobals.get_system_sans_font())
		btn.add_theme_color_override("font_color", _letters_color)
		btn.add_theme_color_override("font_hover_color", _letters_color)
		btn.add_theme_color_override("font_pressed_color", _letters_color)
		btn.add_theme_color_override("font_focus_color", _letters_color)
		btn.add_theme_stylebox_override("normal", _style_normal)
		btn.add_theme_stylebox_override("hover", _style_hover)
		btn.add_theme_stylebox_override("pressed", _style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		%OptionsVBox.add_child(btn)
		_option_buttons.append(btn)

# Sets text, font size, and pressed signal on existing buttons for the current round.
func _configure_option_buttons() -> void:
	var n: int = _option_buttons.size()
	var sep: float = 8.0
	var vbox_h: float = %OptionsVBox.size.y
	if vbox_h < 50.0:
		vbox_h = 550.0
	var max_btn_h: float = (vbox_h - float(n - 1) * sep) / float(n)
	var letter_size: int = min(int(_cfg["letter_size"]), int(max_btn_h / 1.4))
	for i in range(n):
		var btn: Button = _option_buttons[i]
		btn.text = _option_chars[i]
		btn.add_theme_font_size_override("font_size", letter_size)
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		var idx: int = i
		btn.pressed.connect(func(): _on_option_pressed(idx))

# ── Input handling ────────────────────────────────────────────────────────────

func _on_option_pressed(idx: int) -> void:
	if not _can_click:
		return
	_can_click = false
	_timeout_bar.hide()
	$TimeoutTimer.stop()
	$HideOptionsTimer.stop()

	var response_ms: float = (Time.get_unix_time_from_system() - _round_start_time) * 1000.0
	var correct: bool = (_option_chars[idx] == _correct_char)

	_rounds_done += 1
	_total_response_time_ms += response_ms

	var btn: Button = _option_buttons[idx]
	var btn_center: Vector2 = btn.global_position + btn.size * 0.5

	%DotsDisplay.reveal_letter()

	if correct:
		_rounds_correct += 1
		update_score.emit(10)
		PolkadotsG.game.play_sound("correct")
		_show_feedback_popup(btn_center, "+10", true)
	else:
		update_score.emit(0)
		PolkadotsG.game.play_sound("wrong")
		_show_feedback_popup(btn_center, "→ " + _correct_char, false)

	var rid: int = _round_id
	await %DotsDisplay.reveal_finished
	if _round_id != rid or not is_inside_tree():
		return
	_next_or_finish()

func _on_timeout_timer_timeout() -> void:
	if not _can_click:
		return
	_can_click = false
	_timeout_bar.hide()
	$HideOptionsTimer.stop()

	_rounds_done += 1
	_total_response_time_ms += float(_cfg["timeout_sec"]) * 1000.0

	update_score.emit(0)
	PolkadotsG.game.play_sound("wrong")
	%DotsDisplay.reveal_letter()

	var opts_center: Vector2 = %OptionsVBox.global_position + %OptionsVBox.size * 0.5
	_show_feedback_popup(opts_center, "→ " + _correct_char, false)

	var rid: int = _round_id
	await %DotsDisplay.reveal_finished
	if _round_id != rid or not is_inside_tree():
		return
	_next_or_finish()

func _on_hide_options_timer_timeout() -> void:
	_options_hidden = true
	for btn in _option_buttons:
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))

func _show_feedback_popup(screen_pos: Vector2, text: String, is_correct: bool) -> void:
	var font_size: int = 44 if is_correct else 60
	var travel: float = 100.0 if is_correct else 130.0
	var duration: float = 0.8 if is_correct else 1.1
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	label.add_theme_color_override("font_color", _FEEDBACK_OK_COLOR if is_correct else _FEEDBACK_BAD_COLOR)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200, 0)
	label.pivot_offset = Vector2(100, 0)
	label.position = screen_pos - Vector2(100, font_size)
	label.z_index = 20
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(label, "position:y", screen_pos.y - travel, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free)

func _flash_correct_button() -> void:
	var correct_idx: int = _option_chars.find(_correct_char)
	if correct_idx < 0 or correct_idx >= _option_buttons.size():
		return
	var btn: Button = _option_buttons[correct_idx]
	btn.modulate = Color(0.3, 1.0, 0.4, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", Color.WHITE, 0.7)

func pause_round(paused: bool) -> void:
	$TimeoutTimer.paused = paused
	$HideOptionsTimer.paused = paused
	if paused:
		_help_open_time = Time.get_unix_time_from_system()
	else:
		_round_start_time += Time.get_unix_time_from_system() - _help_open_time

func _next_or_finish() -> void:
	if _rounds_correct >= int(_cfg["rounds_per_level"]):
		var avg_time_ms: int = int(_total_response_time_ms / max(1, _rounds_done))
		var pct_correct: int = int(100.0 * _rounds_correct / max(1, _rounds_done))
		sig_level_is_done.emit(int(_cfg["level"]), avg_time_ms, pct_correct)
	else:
		_start_round()
