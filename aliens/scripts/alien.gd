extends Node2D

# A drawn alien (no images), positioned at its CENTER. The level moves it by setting `position`
# and reads its `radius`; this node only draws itself and holds its traits + simulation state.
#
# EVERY alien has the SAME collision `radius` regardless of tall/short/round/slim. That is the
# load-bearing simplification: slot spacing, pairwise separation, ring-band width and keep-out
# distances all become one constant. A slim alien just has a little air around it. Do NOT make
# the radius shape-dependent — it would break the guarantee that parked aliens never overlap.

# --- traits (drawn independently of one another; that IS the confusion mechanism) ---
var radius: float = 33.0
var eyes: int = 2            # 1 | 2 | 3
var color_id: int = 0        # index into ALIEN_COLORS
var is_tall: bool = false
var is_fat: bool = false
var antennae: int = 0        # 0 | 1 | 2
var has_spots: bool = false

# --- simulation state, owned and mutated ONLY by level.gd (one array of nodes is the world) ---
# `sim_pos` is authoritative: separation runs several relaxation passes per frame and we do not
# want to dirty the node transform on each one, so it is copied to `position` exactly once.
var state: int = 0                       # level.gd's AState enum
var sim_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var retarget_ms: float = 0.0
var waypoints: Array = []                # remaining path points (gate, then slot)
var area_idx: int = -1                   # which area it is seeking / parked at
var slot_idx: int = -1                   # INNER-ring slot it owns (-1 = none)
var park_angle: float = NAN              # reserved angle on the OUTER ring lane (NAN = none)
var park_ms: float = 0.0                 # when it parked (starts the response-time clock)
var bob_phase: float = 0.0
var drag_from_state: int = 0
var drag_origin: Vector2 = Vector2.ZERO  # where a drag started, for snap-back
var snap_from: Vector2 = Vector2.ZERO
var snap_to: Vector2 = Vector2.ZERO
var snap_t0: float = 0.0
var snap_end_state: int = 0
var fade_t0: float = 0.0
var fade_in_t0: float = 0.0      # >0 while fading in after a respawn
var hint_until_ms: float = 0.0   # 0 = no timed hint
var seek_start_ms: float = 0.0   # when it committed to walking in (stall watchdog)
var respawn_need: Array = []     # [rule_key, want_match] to satisfy on the next recycle
var entry_block_ms: float = 0.0  # cannot try to enter an area again until this time
var grab_delay_ms: float = -1.0  # park -> grab time, banked at the START of a drag (-1 = n/a)

# --- drawing-only state ---
var _bob: float = 0.0                     # walk bob in px
var _look: Vector2 = Vector2(0.0, 1.0)    # unit gaze direction for the pupils
var _hint: int = 0                        # 0 none, 1 legal target, 2 illegal, 3 grabbed

const ALIEN_COLORS: Array = [
	Color(0.28, 0.56, 0.95),  # 0 blue
	Color(0.93, 0.34, 0.30),  # 1 red
	Color(0.36, 0.78, 0.42),  # 2 green
	Color(0.97, 0.80, 0.25),  # 3 yellow
	Color(0.70, 0.46, 0.90),  # 4 purple
]

const BODY_STEPS: int = 30

# Unit eye layouts in a [-1,1] box; index = eye count - 1. Three distinct SHAPES, not three
# counts: recognizing a shape is instant, counting pips at phone size is not. The triangle also
# fits a narrow body, where a row of three would have to shrink to nothing.
const EYE_UNITS: Array = [
	[Vector2(0.0, 0.0)],
	[Vector2(-1.0, 0.0), Vector2(1.0, 0.0)],
	[Vector2(-1.0, -0.75), Vector2(1.0, -0.75), Vector2(0.0, 0.95)],
]
const EYE_SPREAD: float = 1.18   # center spacing in eye radii
const EYE_MAX: float = 0.34      # eye radius never exceeds this fraction of `radius`
const EYE_MIN: float = 0.15      # legibility floor; eyes may overhang a slim body outline

const SPOT_UNITS: Array = [
	Vector2(-0.46, 0.34), Vector2(0.42, 0.24), Vector2(-0.12, 0.62), Vector2(0.28, 0.64),
]

func setup(r: float, n_eyes: int, cid: int, tall: bool, fat: bool, ant: int, spots: bool) -> void:
	radius = r
	eyes = clampi(n_eyes, 1, 3)
	color_id = clampi(cid, 0, ALIEN_COLORS.size() - 1)
	is_tall = tall
	is_fat = fat
	antennae = clampi(ant, 0, 2)
	has_spots = spots
	queue_redraw()

func set_bob(v: float) -> void:
	if absf(_bob - v) > 0.15:
		_bob = v
		queue_redraw()

func set_look(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	var nd: Vector2 = dir.normalized()
	if nd.distance_to(_look) > 0.08:
		_look = nd
		queue_redraw()

func set_hint(h: int) -> void:
	if _hint != h:
		_hint = h
		queue_redraw()

func body_color() -> Color:
	return ALIEN_COLORS[color_id]

# Half-extents of the body ellipse.
#
# TALL is defined so BOTH readings agree: a tall alien is always TALLER THAN IT IS WIDE, and a
# short one is always WIDER THAN IT IS TALL — whatever its girth. Previously "tall" meant only
# "greater absolute height", so a tall+wide alien came out at (0.92 w, 0.86 h): visibly wider than
# tall while labelled TALL. You had to compare it against other aliens to judge the rule at all.
#
#            WIDE            NARROW
#   TALL   (0.86, 0.98)   (0.56, 1.00)     ry > rx in every case
#   SHORT  (0.98, 0.52)   (0.66, 0.54)     rx > ry in every case
#
# Girth stays an independent dimension: it sets rx, height sets ry. Nothing exceeds `radius`, so
# the drawn body always stays inside the collision circle.
func body_extents() -> Vector2:
	if is_tall:
		return Vector2(radius * (0.86 if is_fat else 0.56), radius * (0.98 if is_fat else 1.00))
	return Vector2(radius * (0.98 if is_fat else 0.66), radius * (0.52 if is_fat else 0.54))

func _ellipse(rx: float, ry: float, center_y: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in BODY_STEPS:
		var t: float = TAU * float(i) / float(BODY_STEPS)
		pts.append(Vector2(cos(t) * rx, center_y + sin(t) * ry))
	return pts

# Eye centers + eye radius, solved so the layout fits the face without shrinking below EYE_MIN.
func _eye_geometry(rx: float, ry: float) -> Array:
	var units: Array = EYE_UNITS[clampi(eyes, 1, 3) - 1]
	var ext_x: float = 0.0
	var ext_y: float = 0.0
	for u in units:
		ext_x = maxf(ext_x, absf(u.x))
		ext_y = maxf(ext_y, absf(u.y))
	# centers sit at u * er * EYE_SPREAD, so the half-extent is er * (ext * SPREAD + 1)
	var er_w: float = (rx * 1.34) * 0.5 / (ext_x * EYE_SPREAD + 1.0)
	var er_h: float = (ry * 1.04) * 0.5 / (ext_y * EYE_SPREAD + 1.0)
	var er: float = clampf(minf(er_w, er_h), radius * EYE_MIN, radius * EYE_MAX)
	var face_y: float = -ry * 0.22
	var centers: Array = []
	for u in units:
		centers.append(Vector2(u.x * er * EYE_SPREAD, face_y + u.y * er * EYE_SPREAD))
	return [centers, er]

func _draw() -> void:
	var ext: Vector2 = body_extents()
	var rx: float = ext.x
	var ry: float = ext.y
	var col: Color = body_color()

	# 1) ground shadow — drawn UNBOBBED so the alien visibly rises off it while walking
	draw_colored_polygon(_ellipse(rx * 0.82, radius * 0.11, ry * 0.98), Color(0, 0, 0, 0.22))

	# a pure TRANSLATION is safe here; scaling the transform would squash the eyes into ovals
	draw_set_transform(Vector2(0.0, -_bob), 0.0, Vector2.ONE)

	# 2) antennae, before the body so the stalk roots tuck under it
	if antennae > 0:
		var xs: Array = [0.0] if antennae == 1 else [-rx * 0.42, rx * 0.42]
		for bx in xs:
			var base: Vector2 = Vector2(bx, -ry * 0.72)
			var sgn: float = 1.0 if bx >= 0.0 else -1.0
			var tip: Vector2 = base + Vector2(sgn * radius * 0.15, -radius * 0.30)
			draw_line(base, tip, col.darkened(0.35), radius * 0.075, true)
			draw_circle(tip, radius * 0.11, col.lightened(0.35))

	# 3) body + outline
	var body_pts: PackedVector2Array = _ellipse(rx, ry, 0.0)
	draw_colored_polygon(body_pts, col)
	var outline: PackedVector2Array = body_pts.duplicate()
	outline.append(body_pts[0])
	draw_polyline(outline, col.darkened(0.34), radius * 0.055, true)

	# 4) belly highlight
	draw_colored_polygon(_ellipse(rx * 0.56, ry * 0.44, ry * 0.28), col.lightened(0.16))

	# 5) spots — lower body only, so they never read as extra eyes
	if has_spots:
		for u in SPOT_UNITS:
			draw_circle(Vector2(u.x * rx, u.y * ry), radius * 0.105, col.darkened(0.32))

	# 6) eyes
	var geo: Array = _eye_geometry(rx, ry)
	var centers: Array = geo[0]
	var er: float = float(geo[1])
	for c in centers:
		draw_circle(c, er, Color(0.98, 0.98, 1.0))
		draw_arc(c, er, 0.0, TAU, 20, col.darkened(0.40), maxf(1.0, er * 0.13), true)
		draw_circle(c + _look * er * 0.32, er * 0.46, Color(0.09, 0.08, 0.12))
		draw_circle(c + Vector2(-er * 0.26, -er * 0.28), er * 0.17, Color(1, 1, 1, 0.85))

	# 7) mouth — the same smile on every alien: cuteness, zero information
	draw_arc(Vector2(0.0, ry * 0.36), radius * 0.16, 0.22 * PI, 0.78 * PI, 12,
		col.darkened(0.45), radius * 0.05, true)

	# 8) hint ring while dragging
	if _hint != 0:
		var hc: Color = Color(0.35, 1.0, 0.55, 0.85)
		if _hint == 2:
			hc = Color(1.0, 0.42, 0.30, 0.85)
		elif _hint == 3:
			hc = Color(1.0, 0.95, 0.55, 0.80)
		draw_arc(Vector2.ZERO, radius * 1.13, 0.0, TAU, 40, hc, radius * 0.09, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
