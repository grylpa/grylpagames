extends "res://scripts/menu_poster.gd"

# POCKETS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a billiard room at night,
# seen low over the table -- the green felt running away under a hanging lamp's cone of light, beer bottles
# (scripts/bottle_art.gd) standing on the far rail in the dimness, a cue resting across the corner -- and
# the game's own pair of balls (scripts/ball_art.gd) rolling slowly up the felt toward the big leather
# pocket in the near rail, and dropping in; then the next pair. Made up, never the board.

const PAIRS: Array = [
	[{"text": "7", "color": Color(0.95, 0.75, 0.20)}, {"shape": "★", "color": Color(0.35, 0.60, 0.95)}],
	[{"shape": "●", "color": Color(0.90, 0.30, 0.30)}, {"text": "3", "color": Color(0.40, 0.80, 0.45)}],
	[{"text": "A", "color": Color(0.80, 0.45, 0.90)}, {"shape": "▲", "color": Color(0.95, 0.55, 0.20)}],
]
const ROLL: float = 3.2          # seconds up the felt
const DROP: float = 1.0          # then into the pocket

var _balls: BallArt = null
var _pair: int = -1
var _bsize: Vector2 = Vector2.ZERO
var _bottles: Array = [null, null, null, null]

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var far_y: float = (360.0 if mobile else 230.0)
	var near_y: float = bottom - (60.0 if mobile else 30.0)
	return {"full": full, "far": far_y, "near": near_y, "pocket": Vector2(full.x * 0.5, near_y + 6.0)}

func _tick(_delta: float) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var cycle: float = ROLL + DROP
	var n: int = int(t / cycle)
	var u: float = fmod(t, cycle)
	if n != _pair or _balls == null:
		_pair = n
		if _balls != null:
			_balls.queue_free()
		var pr: Array = PAIRS[n % PAIRS.size()]
		_bsize = Vector2(full.x * 0.36, full.x * 0.36 * 0.48)
		_balls = BallArt.make(self, _bsize, pr[0], pr[1], 50 + n)
		add_child(_balls)
		if _top != null:
			move_child(_top, get_child_count() - 1)
	# up the felt toward us: from far (small) to near (full size), then into the pocket
	# THE ROLL, IN PERSPECTIVE AND IN PHYSICS (the user: the balls glided, they did not roll): struck at the
	# far end, the pair travels the table's length losing speed (s = 1 - (1-p)^2, constant friction), its
	# depth z giving both its size (near / z) and its place on the felt (a ground plane: the horizon at the
	# far rail), so it starts as a SPECK; and its labels turn by the distance rolled over the radius
	# (ball_art.gd roll_angle), as a ball rolls without slipping
	var p: float = clampf(u / ROLL, 0.0, 1.0)
	var dist: float = 1.0 - (1.0 - p) * (1.0 - p)
	var z_near: float = 1.0
	var z_far: float = 30.0
	var z: float = lerpf(z_far, z_near, dist)
	var sc: float = z_near / z
	var pocket: Vector2 = g["pocket"]
	var near_c: Vector2 = Vector2(full.x * 0.5, pocket.y - _bsize.y * 0.75)
	var far_y: float = float(g["far"]) + 4.0
	var drift: float = sin(dist * 2.4) * 60.0        # a little sideways in the world, smaller far away
	var ctr: Vector2 = Vector2(near_c.x + drift * sc, far_y + (near_c.y - far_y) * sc)
	var lengths_per_radius: float = 26.0                # the table's length, in ball radii
	_balls.roll_angle = dist * lengths_per_radius
	_balls.scale = Vector2(sc, sc)
	_balls.position = ctr - _bsize * 0.5 * sc
	if u >= ROLL and not _balls.has_meta("sinking"):
		_balls.set_meta("sinking", true)
		_balls.sink_into((pocket - _balls.position) / sc, 46.0 / sc)
	for k in 4:
		if _bottles[k] == null:
			_bottles[k] = BottleArt.texture(self, k, 256)

func _is_ready() -> bool:
	for b in _bottles:
		if b == null:
			return false
	return true

func _paint(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var far_y: float = g["far"]
	var near_y: float = g["near"]
	var pocket: Vector2 = g["pocket"]
	# the room: dark wood paneling, warm in the lamp's light
	vgrad(Rect2(Vector2.ZERO, full), Color(0.08, 0.05, 0.04), Color(0.13, 0.08, 0.05))
	var x: float = 20.0
	while x < full.x:
		cv.draw_rect(Rect2(x, 0.0, 2.0, far_y), Color(0, 0, 0, 0.3))
		x += 90.0
	# THE TABLE in perspective: the far rail narrow, the near rail across the screen
	var fw: float = full.x * 0.30
	var felt: PackedVector2Array = PackedVector2Array([Vector2(full.x * 0.5 - fw, far_y), Vector2(full.x * 0.5 + fw, far_y),
		Vector2(full.x + 40.0, near_y), Vector2(-40.0, near_y)])
	var rail: PackedVector2Array = PackedVector2Array([Vector2(full.x * 0.5 - fw - 18.0, far_y - 14.0), Vector2(full.x * 0.5 + fw + 18.0, far_y - 14.0),
		Vector2(full.x + 80.0, near_y + 30.0), Vector2(-80.0, near_y + 30.0)])
	cv.draw_colored_polygon(rail, Color(0.30, 0.15, 0.07))
	cv.draw_polygon(felt, PackedColorArray([Color(0.06, 0.26, 0.15), Color(0.06, 0.26, 0.15), Color(0.10, 0.40, 0.24), Color(0.10, 0.40, 0.24)]))
	# the lamp's pool on the felt
	for k in 9:
		ellipse(Vector2(full.x * 0.5, lerpf(far_y, near_y, 0.55)), full.x * (0.62 - 0.05 * float(k)), (near_y - far_y) * (0.42 - 0.035 * float(k)), Color(1.0, 0.95, 0.70, 0.035))
	# bottles on the far rail, dim
	var bh: float = 110.0 if mobile else 80.0
	for k in 4:
		var tex: Texture2D = _bottles[k]
		if tex == null:
			continue
		var bx: float = full.x * 0.5 + fw * (-0.9 + 0.55 * float(k)) + (30.0 if k >= 2 else 0.0)
		var w: float = bh * BottleArt.ASPECT
		cv.draw_texture_rect(tex, Rect2(bx - w * 0.5, far_y - 14.0 - bh * 0.92, w, bh), false, Color(0.62, 0.58, 0.55))
	# the near rail and its pocket: dark leather, its lip catching the light
	cv.draw_rect(Rect2(0.0, near_y + 14.0, full.x, full.y - near_y), Color(0.24, 0.12, 0.06))
	cv.draw_line(Vector2(0.0, near_y + 14.0), Vector2(full.x, near_y + 14.0), Color(0.55, 0.32, 0.16), 3.0)
	ellipse(pocket + Vector2(0.0, 6.0), 62.0, 30.0, Color(0.30, 0.18, 0.08))
	ellipse(pocket, 54.0, 24.0, Color(0.02, 0.02, 0.02))
	# the lamp: a green shade over the table, its cone
	var lamp: Vector2 = Vector2(full.x * 0.5, far_y - 120.0)
	cv.draw_polygon(PackedVector2Array([lamp + Vector2(-60, 20), lamp + Vector2(60, 20), Vector2(full.x * 0.5 + fw * 1.4, near_y), Vector2(full.x * 0.5 - fw * 1.4, near_y)]),
		PackedColorArray([Color(1.0, 0.95, 0.70, 0.12), Color(1.0, 0.95, 0.70, 0.12), Color(1.0, 0.95, 0.70, 0.0), Color(1.0, 0.95, 0.70, 0.0)]))
	cv.draw_line(Vector2(lamp.x, 0.0), lamp, Color(0.15, 0.12, 0.10), 3.0)
	cv.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-64, 22), lamp + Vector2(64, 22), lamp + Vector2(36, -6), lamp + Vector2(-36, -6)]), Color(0.10, 0.35, 0.20))
	cv.draw_line(lamp + Vector2(-64, 22), lamp + Vector2(64, 22), Color(0.95, 0.80, 0.40), 3.0)
	glow_at(lamp + Vector2(0, 24), 40.0, Color(1.0, 0.95, 0.75, 0.6))

func _paint_top(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	# the cue, resting across the near corner, rocking a hair
	var tip: Vector2 = Vector2(full.x * 0.30, float(g["near"]) - 30.0)
	var butt: Vector2 = Vector2(-60.0, float(g["near"]) + 70.0 + 3.0 * sin(t * 0.8))
	cv.draw_line(butt, tip, Color(0.62, 0.42, 0.22), 12.0, true)
	cv.draw_line(butt.lerp(tip, 0.55), tip, Color(0.92, 0.82, 0.62), 9.0, true)
	cv.draw_line(tip, tip + (tip - butt).normalized() * 10.0, Color(0.35, 0.55, 0.85), 8.0, true)
	title("Pockets", "Send rolling balls into the right pocket", Color(0.98, 0.88, 0.60), Color(0.12, 0.06, 0.02), Color(1.0, 0.8, 0.4, 0.22))
