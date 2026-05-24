extends PopupPanel
class_name PopupText

signal closed

@export var margin_px := 12
@export var clamp_margin_px := 8

@onready var _label: Label = %Text

var _blocker: Control = null
var _emitted := false

var _hidden_temporarily := false

func popup_text(text: String, vcenter:bool, top_px := 80.0) -> void:
	_hidden_temporarily = true
	hide()
	_label.text = text
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


func _gui_input(event: InputEvent) -> void:
	# Close when tapping/clicking on the popup itself.
	if event is InputEventMouseButton and event.pressed:
		hide()
	elif event is InputEventScreenTouch and event.pressed:
		hide()


func _ensure_blocker() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		return

	_blocker = Control.new()
	_blocker.name = "TextPopupBlocker"
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.offset_left = 0
	_blocker.offset_top = 0
	_blocker.offset_right = 0
	_blocker.offset_bottom = 0

	# Crucial: STOP means this Control consumes input so it won't reach gameplay _input.
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP

	_blocker.gui_input.connect(_on_blocker_gui_input)

	# Add blocker to the same window canvas as the popup, then place popup above it.
	var win := get_window()
	win.add_child(_blocker)

	# Ensure blocker is behind popup.
	_blocker.move_to_front() # move blocker to top...
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

	emit_signal("closed")

	# If you prefer to reuse the same instance, remove this line.
	queue_free()
