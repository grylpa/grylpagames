extends Control
class_name BeltTread

# The surface a belt actually is: a trough of turning rollers between two rails (the housings over
# the ends are scripts/belt_hood.gd).
#
# The belts were a flat rectangle of one color. Nothing about them said "machine", and nothing on
# screen moved — so even with the objects restyled, the games read as a list of labels rather than
# something running. The rollers turn continuously, which is what a conveyor does whether or not
# anything is on it.

# A ROLLER CONVEYOR since the parcels (2026-11-02): a row of steel rollers across the belt, which is how
# a parcel line looks. It was a rubber belt of scrolling slats before, which is right for loose items
# and wrong under boxes.
#
# THE TURN IS A GLINT (2026-11-15): a thin line of light across each roller's whole width, rolling over
# it as it turns, seen only on the front of the turn; each roller GLINT_STEP behind the one above, so the
# glints make a ripple that runs down the belt at the parcels' pace (see GLINT_STEP). It replaced a short dark dash at one
# spot on each roller, which read as a black artifact on the belt; and it turns at `speed`, which a game
# keeps equal to its parcels' pace (Sorting Robots sets it every frame, its belts speeding up as the
# player improves) -- the dash turned at a fixed speed unrelated to the parcels.
const TROUGH: Color = Color(0.045, 0.036, 0.030, 1.0)
const ROLL_DARK: Color = Color(0.120, 0.110, 0.100)
const ROLL_LIT: Color = Color(0.600, 0.570, 0.520)
const RAIL: Color = Color(0.624, 0.471, 0.259, 1.0)
const RAIL_DARK: Color = Color(0.300, 0.220, 0.120, 1.0)

const PITCH: float = 17.0
const ROLL_H: float = 12.0
const RAIL_W: float = 5.0
const GLINT: Color = Color(0.95, 0.92, 0.85)
const GLINT_ALPHA: float = 0.34          # 0.16 was "too subtle"
const GLINT_W: float = 1.6
# Each roller's glint is this far (radians) behind the one above. SMALL on purpose: a physically true
# turn put each roller nearly half a turn behind the next, and at half a turn the eye cannot tell which
# way a ripple runs (the wagon-wheel effect). So the turn is slower than a real roller's, and the
# ripple -- what the eye reads -- runs at the parcels' pace.
const GLINT_STEP: float = 0.55

# The rollers' SURFACE speed, units a second -- set it to the parcels' own pace.
var speed: float = 34.0
var _turn: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	# The glints' phase runs so that the RIPPLE (each roller GLINT_STEP behind the one above) travels
	# down the belt at exactly `speed`: the ripple moves one roller pitch while the phase moves one step.
	_turn = fmod(_turn + speed * delta * GLINT_STEP / PITCH, TAU)
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
	var roller: int = 0
	while y < h:
		var top: float = y
		var mid: float = y + ROLL_H * 0.38
		var bot: float = y + ROLL_H
		# a steel cylinder: dark at its top and bottom edge, lit along a line just above its middle
		draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, mid), Vector2(x0, mid)]),
			PackedColorArray([ROLL_DARK, ROLL_DARK, ROLL_LIT, ROLL_LIT]))
		draw_polygon(PackedVector2Array([Vector2(x0, mid), Vector2(x1, mid), Vector2(x1, bot), Vector2(x0, bot)]),
			PackedColorArray([ROLL_LIT, ROLL_LIT, ROLL_DARK.darkened(0.3), ROLL_DARK.darkened(0.3)]))
		# the glint rolling over the front of the turn, across the whole roller, faint
		# Each roller a turn BEHIND the one above by exactly PITCH of surface: the glints then form a ripple
		# that travels down the belt at `speed` -- the parcels' pace -- instead of every roller glinting
		# in step, which pulsed in place and "did not match the turn speed".
		var a: float = _turn - float(roller) * GLINT_STEP
		if cos(a) > 0.0:
			var gy: float = y + ROLL_H * 0.5 + sin(a) * ROLL_H * 0.42
			draw_line(Vector2(x0, gy), Vector2(x1, gy), Color(GLINT.r, GLINT.g, GLINT.b, GLINT_ALPHA * cos(a)), GLINT_W)
		# its axle ends in the rails
		draw_circle(Vector2(RAIL_W * 0.5, y + ROLL_H * 0.5), 2.0, RAIL_DARK)
		draw_circle(Vector2(w - RAIL_W * 0.5, y + ROLL_H * 0.5), 2.0, RAIL_DARK)
		y += PITCH
		roller += 1
	# side rails
	draw_rect(Rect2(0.0, 0.0, RAIL_W, h), RAIL)
	draw_rect(Rect2(w - RAIL_W, 0.0, RAIL_W, h), RAIL)
	draw_line(Vector2(RAIL_W, 0.0), Vector2(RAIL_W, h), RAIL_DARK, 1.5)
	draw_line(Vector2(w - RAIL_W, 0.0), Vector2(w - RAIL_W, h), RAIL_DARK, 1.5)
	for k in int(h / 40.0) + 1:
		var by: float = 20.0 + float(k) * 40.0
		draw_circle(Vector2(RAIL_W * 0.5, by), 1.6, RAIL_DARK)
		draw_circle(Vector2(w - RAIL_W * 0.5, by), 1.6, RAIL_DARK)
