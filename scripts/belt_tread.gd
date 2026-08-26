extends Control
class_name BeltTread

# The surface a belt actually is: an inset trough with a slatted tread running down it, a roller at
# each end, and rails along the sides.
#
# The belts were a flat rectangle of one color. Nothing about them said "machine", and nothing on
# screen moved — so even with the objects restyled, the games read as a list of labels rather than
# something running. The tread scrolls continuously, which is what a conveyor does whether or not
# anything is on it.

const TROUGH: Color = Color(0.055, 0.067, 0.098, 1.0)
const SLAT: Color = Color(0.153, 0.180, 0.243, 1.0)
const SLAT_LIP: Color = Color(0.235, 0.278, 0.361, 1.0)
const RAIL: Color = Color(0.322, 0.376, 0.475, 1.0)
const ROLLER: Color = Color(0.290, 0.337, 0.427, 1.0)

const SLAT_H: float = 26.0
const RAIL_W: float = 5.0

# Pixels per second the tread travels. Slow on purpose: this is background motion, and anything
# quicker competes with the objects the player is supposed to be reading.
@export var speed: float = 34.0

var _offset: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_offset = fmod(_offset + speed * delta, SLAT_H)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < 4.0:
		return
	draw_rect(Rect2(0.0, 0.0, w, h), TROUGH)

	# Slats, scrolling downward. Drawn one past each end so they enter and leave off-screen rather
	# than popping into existence at the edge.
	var y: float = -SLAT_H + _offset
	while y < h + SLAT_H:
		var top: float = maxf(y, 0.0)
		var bot: float = minf(y + SLAT_H - 4.0, h)
		if bot > top:
			draw_rect(Rect2(RAIL_W, top, w - RAIL_W * 2.0, bot - top), SLAT)
			# a lit lip on the leading edge of each slat, which is what makes the motion readable
			if y >= 0.0 and y <= h:
				draw_line(Vector2(RAIL_W, y), Vector2(w - RAIL_W, y), SLAT_LIP, 2.0)
		y += SLAT_H

	# Side rails, and a roller at each end.
	draw_rect(Rect2(0.0, 0.0, RAIL_W, h), RAIL)
	draw_rect(Rect2(w - RAIL_W, 0.0, RAIL_W, h), RAIL)
	var r: float = 7.0
	draw_rect(Rect2(0.0, 0.0, w, r), ROLLER)
	draw_rect(Rect2(0.0, h - r, w, r), ROLLER)
	draw_line(Vector2(0.0, r), Vector2(w, r), Color(0.0, 0.0, 0.0, 0.35), 2.0)
	draw_line(Vector2(0.0, h - r), Vector2(w, h - r), Color(0.0, 0.0, 0.0, 0.35), 2.0)
