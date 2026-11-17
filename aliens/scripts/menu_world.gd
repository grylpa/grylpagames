extends "res://scripts/menu_poster.gd"

# ALIENS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): an alien night with a
# ringed planet and two moons; a flying saucer hangs high, its lights chasing round its rim, and lets its
# passengers down a beam of light -- the game's own aliens (alien.gd), each different (eyes, color, build,
# antennae, spots), drifting gently down, turning a little -- to the glowing boarding pad of a spaceport
# gate. The spaceport's work, as a picture. Made up, never the board.

const ALIEN = preload("res://aliens/scripts/alien.gd")
const RIDERS: int = 5
const FALL: float = 9.0          # seconds for one alien to come down the beam

var _layer: Node2D = null
var _riders: Array = []
var _front: Array = []

func _setup() -> void:
	_layer = Node2D.new()
	add_child(_layer)
	for k in RIDERS:
		var a: Node2D = ALIEN.new()
		_layer.add_child(a)
		a.call("setup", 30.0, 1 + k % 3, k % 5, k % 2 == 0, (k + 1) % 3, k % 2 == 1)
		_riders.append(a)
	# two waiting on the pad, larger, in front
	for k in 2:
		var a: Node2D = ALIEN.new()
		_layer.add_child(a)
		a.call("setup", 46.0, 2 + k, (k * 2 + 1) % 5, k == 0, 2 - k, k == 0)
		_front.append(a)

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var ship: Vector2 = Vector2(full.x * 0.5, (300.0 if mobile else 190.0))
	var pad: Vector2 = Vector2(full.x * 0.5, bottom - (70.0 if mobile else 40.0))
	return {"full": full, "bottom": bottom, "ship": ship, "pad": pad}

func _tick(_delta: float) -> void:
	var g: Dictionary = _geom()
	var ship: Vector2 = g["ship"]
	var pad: Vector2 = g["pad"]
	for k in _riders.size():
		var a: Node2D = _riders[k]
		var u: float = fmod(t / FALL + float(k) / float(_riders.size()), 1.0)
		var y: float = lerpf(ship.y + 40.0, pad.y - 30.0, u)
		var x: float = ship.x + sin(t * 0.8 + float(k) * 1.9) * 26.0 * (0.3 + u)
		a.position = Vector2(x, y)
		a.rotation = sin(t * 0.6 + float(k)) * 0.25
		var s: float = 0.65 + 0.55 * u
		a.scale = Vector2(s, s)
		a.modulate = Color(1, 1, 1, clampf(u / 0.08, 0.0, 1.0) * clampf((1.0 - u) / 0.08, 0.0, 1.0))
	for k in _front.size():
		var a: Node2D = _front[k]
		var side: float = -1.0 if k == 0 else 1.0
		a.position = pad + Vector2(side * g["full"].x * 0.30, -10.0 + 4.0 * sin(t * 1.4 + float(k) * 2.0))
		a.call("set_bob", sin(t * 2.0 + float(k)) * 2.0)

func _paint(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var ship: Vector2 = g["ship"]
	var pad: Vector2 = g["pad"]
	# THE SKY: violet to teal, stars, a ringed planet and two moons
	vgrad(Rect2(Vector2.ZERO, full), Color(0.05, 0.03, 0.12), Color(0.06, 0.16, 0.20))
	for k in 140:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * full.y * 0.85)
		var tw: float = 0.5 + 0.5 * sin(t * (0.2 + 0.4 * h01(k + 9)) + float(k))
		cv.draw_circle(sp, 0.7 + 1.4 * h01(k * 5 + 3), Color(0.9, 0.95, 1.0, 0.25 + 0.5 * tw * h01(k * 5 + 4)))
	var planet: Vector2 = Vector2(full.x * 0.18, ship.y + 40.0)
	var pr: float = full.x * 0.17
	glow_at(planet, pr * 1.6, Color(0.95, 0.55, 0.85, 0.20))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), true)
	_sphere(planet, pr, Color(0.30, 0.10, 0.28), Color(0.95, 0.62, 0.82))
	for b in 3:
		ellipse(planet + Vector2(-pr * 0.08, pr * (-0.32 + 0.3 * float(b))), pr * (0.86 - 0.12 * float(b)), pr * 0.07, Color(1.0, 0.80, 0.90, 0.14))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), false)
	_sphere(Vector2(full.x * 0.86, ship.y - 120.0), 20.0, Color(0.25, 0.30, 0.38), Color(0.92, 0.96, 1.0))
	_sphere(Vector2(full.x * 0.74, ship.y - 60.0), 10.0, Color(0.15, 0.32, 0.26), Color(0.75, 1.0, 0.85))
	# THE GROUND: a dark deck to the horizon, and the gate's pad glowing
	var horizon: float = pad.y - 70.0
	vgrad(Rect2(0.0, horizon, full.x, full.y - horizon), Color(0.07, 0.09, 0.14), Color(0.03, 0.04, 0.07))
	for k in 6:
		var lx: float = fmod(float(k) * 130.0 + 40.0, full.x)
		cv.draw_circle(Vector2(lx, horizon + 10.0), 3.0, Color(0.6, 0.9, 1.0, 0.5 + 0.5 * sin(t * 2.0 + float(k))))
	glow_at(pad, 170.0, Color(0.70, 0.95, 1.0, 0.28), 8)
	ellipse(pad, 130.0, 30.0, Color(0.55, 0.62, 0.70))
	ellipse(pad, 116.0, 24.0, Color(0.85, 0.97, 1.0, 0.85))
	# THE BEAM, from the saucer to the pad
	var bw0: float = 40.0
	var bw1: float = 130.0
	var beam: PackedVector2Array = PackedVector2Array([ship + Vector2(-bw0, 20.0), ship + Vector2(bw0, 20.0), pad + Vector2(bw1, 0.0), pad + Vector2(-bw1, 0.0)])
	cv.draw_polygon(beam, PackedColorArray([Color(0.75, 1.0, 0.95, 0.30), Color(0.75, 1.0, 0.95, 0.30), Color(0.75, 1.0, 0.95, 0.10), Color(0.75, 1.0, 0.95, 0.10)]))
	for k in 6:
		var u: float = fmod(t * 0.25 + float(k) / 6.0, 1.0)
		var y: float = lerpf(ship.y + 20.0, pad.y, u)
		var hw: float = lerpf(bw0, bw1, u)
		ellipse(Vector2(ship.x, y), hw, 6.0 + 10.0 * u, Color(0.85, 1.0, 0.95, 0.10 * sin(u * PI)))

func _paint_top(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var ship: Vector2 = g["ship"]
	# THE SAUCER, over the beam's top
	var hover: Vector2 = ship + Vector2(0.0, 5.0 * sin(t * 1.1))
	ellipse(hover + Vector2(0.0, 6.0), 120.0, 30.0, Color(0.30, 0.34, 0.42))
	ellipse(hover, 120.0, 26.0, Color(0.62, 0.68, 0.78))
	ellipse(hover + Vector2(0.0, -6.0), 104.0, 16.0, Color(0.78, 0.84, 0.92))
	ellipse(hover + Vector2(0.0, -24.0), 50.0, 30.0, Color(0.60, 0.95, 1.0, 0.75))
	ellipse(hover + Vector2(-14.0, -34.0), 18.0, 9.0, Color(1, 1, 1, 0.5))
	for k in 10:
		var a: float = TAU * float(k) / 10.0 + t * 1.5
		var p: Vector2 = hover + Vector2(cos(a) * 108.0, sin(a) * 20.0 + 6.0)
		if sin(a) > -0.2:
			var on: float = 0.5 + 0.5 * sin(t * 4.0 - float(k) * 0.8)
			cv.draw_circle(p, 5.0, Color(1.0, 0.85, 0.35, 0.5 + 0.5 * on))
	title("Aliens", "Work the spaceport gates", Color(0.70, 1.0, 0.85), Color(0.04, 0.10, 0.10), Color(0.4, 1.0, 0.8, 0.30))

# A LIT SPHERE (the user: the saucer is drawn in 3-D, the planet was flat circles): many thin discs
# drifting toward the light at the top left, each a little lighter, so the shading is a smooth slope;
# a soft shadow on the far side; a thin bright rim of atmosphere
func _sphere(c: Vector2, r: float, dark: Color, light: Color) -> void:
	glow_at(c, r * 1.35, Color(light, 0.18), 6)
	cv.draw_circle(c, r, dark)
	for k in 24:
		var f: float = float(k + 1) / 24.0
		cv.draw_circle(c + Vector2(-r, -r) * 0.32 * f, r * (1.0 - 0.62 * f), dark.lerp(light, f))
	cv.draw_arc(c, r - 1.0, deg_to_rad(150.0), deg_to_rad(300.0), 32, Color(light.lightened(0.3), 0.55), maxf(1.5, r * 0.04), true)

# a planet's ring: the back half under the planet, the front half over it
func _ring(c: Vector2, rx: float, ry: float, col: Color, back: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 33:
		var a: float = (PI if back else 0.0) + PI * float(k) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.25))
	cv.draw_polyline(pts, col, 7.0, true)
