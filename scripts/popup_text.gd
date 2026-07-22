extends PopupPanel
class_name PopupText

signal closed

@export var margin_px := 12
@export var clamp_margin_px := 8

@onready var _label: Label = %Text

var _blocker: Control = null
var _blocker_layer: CanvasLayer = null
var _emitted := false

var _hidden_temporarily := false

func popup_text(text: String, vcenter:bool, top_px := 80.0) -> void:
	_hidden_temporarily = true
	hide()
	_label.text = text
	# The scene's 36px font makes the popup too big on desktop; shrink it there (mobile is
	# fine as-is). The popup sizes to the label, so this shrinks the whole panel.
	_label.add_theme_font_size_override("font_size", 36 if MainGlobals.is_mobile() else 26)
	_ensure_blocker()
	await get_tree().process_frame
	await get_tree().process_frame

	var content_size := _label.get_combined_minimum_size()
	var desired := content_size + 2 * Vector2(margin_px, margin_px)
	size = Vector2i(ceili(desired.x), ceili(desired.y))

	# var win := get_tree().root.get_window()
	# var win: Rect2 = get_viewport().get_visible_rect()
	var winsize:Vector2 = MainGlobals.screen_size
	var x := (winsize.x - float(size.x)) * 0.5
	var y := float(top_px)
	if vcenter:
		y = (winsize.y - float(size.y)) * 0.5

	x = clamp(x, float(clamp_margin_px), winsize.x - float(size.x) - float(clamp_margin_px))
	y = clamp(y, float(clamp_margin_px), winsize.y - float(size.y) - float(clamp_margin_px))

	popup(Rect2i(Vector2i(int(x), int(y)), size))

	MainGlobals.bring_to_front()
	_hidden_temporarily = false


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
