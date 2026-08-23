extends PopupPanel
class_name PopupText

signal closed

@export var margin_px := 12
@export var clamp_margin_px := 8

@onready var _label: Label = %Text
@onready var _title: Label = %Title
@onready var _tap: Label = %TapText

var _blocker: Control = null
var _blocker_layer: CanvasLayer = null
var _emitted := false

var _hidden_temporarily := false

func popup_text(text_title: String, text: String, vcenter:bool, top_px := 80.0) -> void:
	_hidden_temporarily = true
	# The scene starts HIDDEN (scenes/popup_text.tscn). It used to start visible, so add_child()
	# put a visible Window into the tree — Godot hooked it up to its transient parent there and
	# then — and the hide()/popup() below re-did that hookup from a different state, which is what
	# logged "disconnect a nonexistent connection ... focus_entered" followed by "already
	# connected" every time any game opened this popup.
	if visible:
		hide()
	# The scene's 36px font makes the popup too big on desktop; shrink it there (mobile is
	# fine as-is). The popup sizes to the content, so this shrinks the whole panel.
	var fs: int = 36 if MainGlobals.is_mobile() else 26
	_label.text = text
	_label.add_theme_font_size_override("font_size", fs)
	# "Tap anywhere to start" — a bit larger on mobile
	_tap.add_theme_font_size_override("font_size", 24 if MainGlobals.is_mobile() else 16)
	# Title: same font/color as the text but +2 in size. If empty, hide it so it takes no
	# vertical space (a hidden child is skipped by the VBox, along with its separation).
	if text_title.is_empty():
		_title.text = ""
		_title.visible = false
	else:
		_title.text = text_title
		_title.visible = true
		_title.add_theme_font_size_override("font_size", fs + 8)
	# The panel used to be sized purely from its content, so ANY text wider than the window made
	# it overflow the screen — on every platform, not just narrow ones. Shrink the font until the
	# widest line fits the available width, fall back to wrapping if even the floor is too wide,
	# and hard-clamp the final size below. Callers never have to think about line lengths.
	var winsize: Vector2 = MainGlobals.screen_size
	# A Window's size is floored by its contents' minimum, so clamping `size` alone cannot shrink
	# an oversized popup — the CONTENT has to fit. Account for the panel's own stylebox padding
	# too, which is on top of margin_px.
	var pad: Vector2 = Vector2.ZERO
	var sb: StyleBox = get_theme_stylebox("panel")
	if sb != null:
		pad = Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT),
			sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
	var overhead: Vector2 = pad + 2.0 * Vector2(margin_px, margin_px)
	var limit: Vector2 = winsize - 2.0 * Vector2(clamp_margin_px, clamp_margin_px)
	var avail: Vector2 = limit - overhead

	fs = _fit_font_to_width(fs, avail.x)
	_apply_font(fs)
	if _widest_line(fs) > avail.x:
		# even at the smallest readable size a line is too long — let it wrap instead
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = avail.x
		_title.custom_minimum_size.x = avail.x

	_ensure_blocker()
	await get_tree().process_frame
	await get_tree().process_frame

	# Measure what the laid-out content actually needs and shrink until it fits BOTH dimensions.
	# Measuring beats predicting: wrapping, theme margins and font metrics all feed into this.
	var desired: Vector2 = Vector2.ZERO
	for _try in 10:
		desired = ($VBoxContainer as Control).get_combined_minimum_size() + overhead
		if (desired.x <= limit.x and desired.y <= limit.y) or fs <= MIN_POPUP_FONT:
			break
		fs -= 2
		_apply_font(fs)
		if _label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			_label.custom_minimum_size.x = avail.x
			_title.custom_minimum_size.x = avail.x
		await get_tree().process_frame

	size = Vector2i(mini(ceili(desired.x), int(limit.x)), mini(ceili(desired.y), int(limit.y)))
	var x := (winsize.x - float(size.x)) * 0.5
	var y := float(top_px)
	if vcenter:
		y = (winsize.y - float(size.y)) * 0.5

	x = clamp(x, float(clamp_margin_px), winsize.x - float(size.x) - float(clamp_margin_px))
	y = clamp(y, float(clamp_margin_px), winsize.y - float(size.y) - float(clamp_margin_px))

	popup(Rect2i(Vector2i(int(x), int(y)), size))

	MainGlobals.bring_to_front()
	_hidden_temporarily = false


const MIN_POPUP_FONT: int = 14

func _apply_font(fs: int) -> void:
	_label.add_theme_font_size_override("font_size", fs)
	if _title.visible:
		_title.add_theme_font_size_override("font_size", fs + 8)

# Widest single line across title, body and the tap prompt, at body font size `fs`. Measured from
# the font directly rather than from a laid-out Control, so it is deterministic and needs no frame.
func _widest_line(fs: int) -> float:
	var w: float = 0.0
	var body_font: Font = _label.get_theme_font("font")
	if body_font == null:
		body_font = MainGlobals.get_system_sans_font()
	for line in _label.text.split("\n"):
		w = maxf(w, body_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	if _title.visible:
		var title_font: Font = _title.get_theme_font("font")
		if title_font == null:
			title_font = body_font
		for line in _title.text.split("\n"):
			w = maxf(w, title_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 8).x)
	var tap_font: Font = _tap.get_theme_font("font")
	if tap_font == null:
		tap_font = body_font
	var tap_fs: int = _tap.get_theme_font_size("font_size")
	w = maxf(w, tap_font.get_string_size(_tap.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tap_fs).x)
	return w

# Largest font size (up to `fs`) whose widest line still fits `avail_w`.
func _fit_font_to_width(fs: int, avail_w: float) -> int:
	var out: int = fs
	while out > MIN_POPUP_FONT and _widest_line(out) > avail_w:
		out -= 1
	return out

func _ready() -> void:
	# Fires for any reason the popup hides (ESC, outside click, hide(), etc).
	popup_hide.connect(_on_popup_hide)
	_add_inside_catcher()


func _add_inside_catcher() -> void:
	# A tap ON the popup must close it too (matches "Tap anywhere to start"). _gui_input
	# does NOT fire on a PopupPanel (it's a Window, not a Control), so we put a transparent
	# full-rect Control on top of the content that closes on a press. Taps OUTSIDE the
	# popup are handled by the root dim blocker.
	var catcher: Control = Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_catcher_gui_input)
	add_child(catcher)
	catcher.move_to_front()


func _on_catcher_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		# Both halves of one tap arrive (touch, and the mouse button synthesized from it), so the
		# second one would hide a popup that is already hidden.
		if visible:
			hide()


func _ensure_blocker() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		return

	# Host the blocker on a HIGH CanvasLayer so it covers game content that lives on its own
	# CanvasLayers. A plain window-level blocker sits on the base canvas (layer 0), BELOW
	# those layers, so buttons behind the popup stay clickable (not modal). The popup itself
	# is a subwindow and still renders above this layer.
	_blocker_layer = CanvasLayer.new()
	_blocker_layer.layer = 128

	# A visible dark translucent full-screen ColorRect: dims everything behind the popup AND
	# (mouse_filter STOP) consumes ALL input under it — clicks, drags and hover — so buttons
	# below can't be clicked or even flash on hover. Sized way oversized because a
	# CanvasLayer-hosted Control's full-rect anchors don't always resolve to the viewport
	# (leaving it zero-sized, which is why a transparent Control let hover through).
	var dim: ColorRect = ColorRect.new()
	dim.name = "TextPopupBlocker"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.position = Vector2(-2000, -2000)
	dim.size = Vector2(8000, 8000)
	dim.gui_input.connect(_on_blocker_gui_input)
	_blocker = dim
	_blocker_layer.add_child(_blocker)

	# Add to the MAIN window (root viewport), NOT get_window(): this node is itself a
	# Window (PopupPanel), so get_window() returns the popup — adding there would dim the
	# popup and leave the screen behind it untouched. On the root the popup subwindow
	# renders above this layer, so the popup stays bright while everything else is dimmed
	# and input-blocked.
	get_tree().root.add_child(_blocker_layer)

	MainGlobals.bring_to_front()

func _on_blocker_gui_input(event: InputEvent) -> void:
	# Any press outside closes the popup.
	if event is InputEventMouseButton and event.pressed:
		hide()
	elif event is InputEventScreenTouch and event.pressed:
		hide()
	# Swallow drags/motion so swipe systems never see them.
	elif event is InputEventMouseMotion:
		pass
	elif event is InputEventScreenDrag:
		pass


func _on_popup_hide() -> void:
	if _hidden_temporarily:
		return
	_cleanup_and_emit()


func _cleanup_and_emit() -> void:
	if _emitted:
		return
	_emitted = true

	if _blocker != null and is_instance_valid(_blocker):
		_blocker.queue_free()
	_blocker = null
	if _blocker_layer != null and is_instance_valid(_blocker_layer):
		_blocker_layer.queue_free()
	_blocker_layer = null

	emit_signal("closed")

	# If you prefer to reuse the same instance, remove this line.
	queue_free()
