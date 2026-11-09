extends Control
class_name MenuSwitch

# AN ON/OFF SWITCH for a main-menu row (main_menu.gd add_switch_entry), drawn in the menu's own
# colors: a pill track that is the dropdowns' dark when off and the menu's gold when on, with a knob
# that slides across. A yes/no setting used to be a dropdown with "Off"/"On" in it, or a two-step
# slider -- neither of which reads as a switch.

signal toggled(is_on: bool)

const SLIDE_TIME: float = 0.14
const TRACK_OFF: Color = Color(0.10, 0.105, 0.125)
const TRACK_EDGE: Color = Color(1.0, 1.0, 1.0, 0.10)
const KNOB_OFF: Color = Color(0.80, 0.80, 0.84)
const TRACK_ON: Color = Color(0.976, 0.792, 0.353)   # main_menu.gd ACCENT
const KNOB_ON: Color = Color(0.153, 0.118, 0.043)    # main_menu.gd INK

var on: bool = false
var _k: float = 0.0          # 0 = off .. 1 = on, animated
var _tw: Tween = null

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h: float = 44.0 if not MainGlobals.is_mobile() else 56.0
	custom_minimum_size = Vector2(h * 1.9, h)
	size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

# Set without a signal (the menu showing a saved value).
func set_on(v: bool) -> void:
	on = v
	_k = 1.0 if v else 0.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		on = not on
		if _tw != null and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_method(_set_k, _k, 1.0 if on else 0.0, SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		accept_event()
		toggled.emit(on)

func _set_k(v: float) -> void:
	_k = v
	queue_redraw()

func _draw() -> void:
	var h: float = size.y
	var r: float = h * 0.5
	var w: float = size.x
	var track: Color = TRACK_OFF.lerp(TRACK_ON, _k)
	draw_circle(Vector2(r, r), r, track)
	draw_circle(Vector2(w - r, r), r, track)
	draw_rect(Rect2(r, 0.0, w - 2.0 * r, h), track)
	# a hairline round the track, so the dark "off" pill still has an edge on the dark card
	draw_arc(Vector2(r, r), r - 1.0, PI * 0.5, PI * 1.5, 24, TRACK_EDGE.lerp(Color(0, 0, 0, 0), _k), 2.0, true)
	draw_arc(Vector2(w - r, r), r - 1.0, -PI * 0.5, PI * 0.5, 24, TRACK_EDGE.lerp(Color(0, 0, 0, 0), _k), 2.0, true)
	draw_line(Vector2(r, 1.0), Vector2(w - r, 1.0), TRACK_EDGE.lerp(Color(0, 0, 0, 0), _k), 2.0)
	draw_line(Vector2(r, h - 1.0), Vector2(w - r, h - 1.0), TRACK_EDGE.lerp(Color(0, 0, 0, 0), _k), 2.0)
	var kr: float = r - 5.0
	var kx: float = lerpf(r, w - r, _k)
	draw_circle(Vector2(kx, r + 2.0), kr, Color(0, 0, 0, 0.25))      # its shadow
	draw_circle(Vector2(kx, r), kr, KNOB_OFF.lerp(KNOB_ON, _k))
