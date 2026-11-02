extends Control
class_name BeltTread

# The surface a belt actually is: a trough of turning rollers between two rails (the housings over
# the ends are scripts/belt_hood.gd).
#
# The belts were a flat rectangle of one color. Nothing about them said "machine", and nothing on
# screen moved — so even with the objects restyled, the games read as a list of labels rather than
# something running. The rollers turn continuously, which is what a conveyor does whether or not
# anything is on it.

# A ROLLER CONVEYOR since the parcels (2026-11-02): a row of steel rollers across the belt, standing
# still while they turn (a mark on each rolls round), which is how a parcel line looks. It was a
# rubber belt of scrolling slats before, which is right for loose items and wrong under boxes.
const TROUGH: Color = Color(0.045, 0.036, 0.030, 1.0)
const ROLL_DARK: Color = Color(0.120, 0.110, 0.100)
const ROLL_LIT: Color = Color(0.600, 0.570, 0.520)
const RAIL: Color = Color(0.624, 0.471, 0.259, 1.0)
const RAIL_DARK: Color = Color(0.300, 0.220, 0.120, 1.0)

const PITCH: float = 17.0
const ROLL_H: float = 12.0
const RAIL_W: float = 5.0

# How fast the rollers turn, as surface speed (units a second) -- the parcels' own pace.
@export var speed: float = 34.0

var _turn: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_turn = fmod(_turn + speed * delta, ROLL_H * PI)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < 4.0:
		return
	draw_rect(Rect2(0.0, 0.0, w, h), TROUGH)
	var x0: float = RAIL_W + 1.0
	var x1: float = w - RAIL_W - 1.0
	var y: float = 4.0
	var mark_t: float = _turn / (ROLL_H * PI)          # 0..1 round the roller
	while y < h:
		var top: float = y
		var mid: float = y + ROLL_H * 0.38
		var bot: float = y + ROLL_H
		# a steel cylinder: dark at its top and bottom edge, lit along a line just above its middle
		draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, mid), Vector2(x0, mid)]),
			PackedColorArray([ROLL_DARK, ROLL_DARK, ROLL_LIT, ROLL_LIT]))
		draw_polygon(PackedVector2Array([Vector2(x0, mid), Vector2(x1, mid), Vector2(x1, bot), Vector2(x0, bot)]),
			PackedColorArray([ROLL_LIT, ROLL_LIT, ROLL_DARK.darkened(0.3), ROLL_DARK.darkened(0.3)]))
		# the mark that shows it turning: seen only on the front half of the turn
		var a: float = mark_t * TAU
		if cos(a) > 0.0:
			var my: float = y + ROLL_H * 0.5 + sin(a) * ROLL_H * 0.5
			var mx: float = lerpf(x0, x1, 0.22)
			draw_line(Vector2(mx, my), Vector2(mx + 7.0, my), Color(0, 0, 0, 0.35 * cos(a)), 2.0)
		# its axle ends in the rails
		draw_circle(Vector2(RAIL_W * 0.5, y + ROLL_H * 0.5), 2.0, RAIL_DARK)
		draw_circle(Vector2(w - RAIL_W * 0.5, y + ROLL_H * 0.5), 2.0, RAIL_DARK)
		y += PITCH
	# side rails
	draw_rect(Rect2(0.0, 0.0, RAIL_W, h), RAIL)
	draw_rect(Rect2(w - RAIL_W, 0.0, RAIL_W, h), RAIL)
	draw_line(Vector2(RAIL_W, 0.0), Vector2(RAIL_W, h), RAIL_DARK, 1.5)
	draw_line(Vector2(w - RAIL_W, 0.0), Vector2(w - RAIL_W, h), RAIL_DARK, 1.5)
	for k in int(h / 40.0) + 1:
		var by: float = 20.0 + float(k) * 40.0
		draw_circle(Vector2(RAIL_W * 0.5, by), 1.6, RAIL_DARK)
		draw_circle(Vector2(w - RAIL_W * 0.5, by), 1.6, RAIL_DARK)
