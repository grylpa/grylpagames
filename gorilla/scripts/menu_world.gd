extends "res://scripts/menu_poster.gd"

# GORILLA'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): deep in the rainforest at
# dawn, seen from the side -- layers of foliage fading into green haze, shafts of light falling slantwise
# through the canopy, vines hanging and swaying, great leaves framing the edges; the game's own silverback
# (peripheral_gorilla.gd) knuckle-walking slowly along the forest floor, and its baby (baby_gorilla.gd)
# sitting on a mossy log beside a bunch of bananas; butterflies and drifting motes in the light.
# The game is about the gorillas you notice out of the corner of your eye. Made up, never the board.

const ADULT: Script = preload("res://gorilla/scripts/peripheral_gorilla.gd")
const BABY: Script = preload("res://gorilla/scripts/baby_gorilla.gd")
const BANANAS: Script = preload("res://gorilla/scripts/banana_art.gd")
# THE WALK, DRIVEN HERE (the user: too slow, "gliding on the ground and not walking on it"): the figure's
# own cadence is tuned for its small size in the game, so drawn large and walked slowly its feet slid. Its
# clock is stopped and its walk cycle advanced here at STEP_RATE, and it moves one STRIDE (in body heights)
# per cycle -- so its feet keep pace with the ground.
const STEP_RATE: float = 4.2          # radians of the walk cycle a second
# the figure's side-view knuckles and feet swing +-0.2 body heights, so a planted hand travels 0.4 back per
# half cycle: 0.8 body heights per full cycle is the pace at which they do not slide (1.15 still glided)
const STRIDE: float = 0.8            # body heights per full cycle (2 pi)

var _back: Control = null       # the forest's still layers, drawn once
var _figures: Node2D = null
var _adult: Node2D = null
var _baby: Node2D = null
var _bananas: Node2D = null
var _laid_for: Vector2 = Vector2.ZERO

func _setup() -> void:
	# the forest floor never moves: a still layer, baked (menu_poster.gd `add_still`)
	_back = add_still(func(d: Control) -> void: _draw_back(d))
	_figures = Node2D.new()
	add_child(_figures)
	_adult = ADULT.new()
	_adult.set("velocity", Vector2(1.0, 0.0))     # facing right (its _ready picks the side view from this)
	_adult.set("screen_rect", Rect2(-100000.0, -100000.0, 200000.0, 200000.0))   # it never "leaves": it is walked round
	_figures.add_child(_adult)
	_adult.set_process(false)
	_bananas = BANANAS.new()
	_figures.add_child(_bananas)
	_baby = BABY.new()
	_figures.add_child(_baby)

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var floor_y: float = bottom - (60.0 if mobile else 30.0)
	return {"full": full, "bottom": bottom, "floor": floor_y, "top": (230.0 if mobile else 150.0)}

func _tick(delta: float) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var floor_y: float = g["floor"]
	var key: Vector2 = Vector2(full.x, floor_y)
	if key != _laid_for:
		_laid_for = key
		_back.queue_redraw()
		var room: float = floor_y - float(g["top"])
		_adult.set("body_height", room * 0.40)
		_adult.position = Vector2(full.x * 0.50, floor_y - room * 0.40 * 0.48)     # in view from the start
		_baby.set("body_height", room * 0.20)
		_bananas.set("size", room * 0.11)
	var room2: float = floor_y - float(g["top"])
	# the silverback walks across and, out of sight past the right edge, round again from the left
	var ah: float = float(_adult.get("body_height"))
	_adult.set("_phase", float(_adult.get("_phase")) + STEP_RATE * delta)
	_adult.position.x += STRIDE * ah * STEP_RATE / TAU * delta
	_adult.queue_redraw()
	if _adult.position.x > full.x + ah:
		_adult.position.x = -ah
	# on the rolling ground under it, the weight rising and settling with each step, the body rocking
	var ph: float = float(_adult.get("_phase"))
	_adult.position.y = _ground_at(_adult.position.x, floor_y) - ah * 0.48 + room2 * 0.05 - absf(sin(ph)) * ah * 0.025
	_adult.rotation = sin(ph) * 0.025 + (_ground_at(_adult.position.x + 20.0, floor_y) - _ground_at(_adult.position.x - 20.0, floor_y)) / 40.0 * 0.6
	# the baby on its log at the left, the bananas beside it
	var log_top: float = floor_y - room2 * 0.10
	_baby.position = Vector2(full.x * 0.24, log_top - float(_baby.get("body_height")) * 0.46)
	_bananas.position = Vector2(full.x * 0.40, log_top - room2 * 0.035)
	_bananas.set("now_ms", 5000.0)        # long since arrived: fully shown (at age 0 it is transparent)
	_bananas.set("born_ms", 0.0)
	_bananas.set("life_ms", 1.0e12)
	_bananas.queue_redraw()

# --- the forest, back to front (once) -------------------------------------------------------------------

func _draw_back(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var floor_y: float = g["floor"]
	# the light behind everything: pale green-gold high up, deep green below
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(full.x, 0), Vector2(full.x, full.y), Vector2(0, full.y)]),
		PackedColorArray([Color(0.62, 0.74, 0.46), Color(0.78, 0.82, 0.52), Color(0.08, 0.16, 0.08), Color(0.06, 0.12, 0.06)]))
	# three layers of foliage, each nearer one darker and less hazed: trunks, then a mass of leaves
	var layers: Array = [[Color(0.40, 0.56, 0.38), 0.30, 7], [Color(0.24, 0.40, 0.24), 0.45, 5], [Color(0.13, 0.26, 0.13), 0.60, 4]]
	for li in layers.size():
		var col: Color = layers[li][0]
		var base_y: float = lerpf(float(g["top"]), floor_y, float(layers[li][1]))
		var n: int = int(layers[li][2])
		for k in n:
			var x: float = full.x * (float(k) + 0.2 + 0.6 * h01(k * 7 + li * 31)) / float(n)
			var w: float = 10.0 + 10.0 * float(li) + 8.0 * h01(k + li * 11)
			d.draw_rect(Rect2(x - w * 0.5, 0.0, w, floor_y), col.darkened(0.15))
		# THE LEAVES: clusters of pointed leaves (circles read as blobs), lit on top, darker below
		for k in 26:
			var c: Vector2 = Vector2(h01(k * 3 + li * 101) * full.x, base_y * (0.08 + 0.9 * h01(k * 3 + 1 + li * 101)))
			_cluster(d, c, 34.0 + 30.0 * h01(k + li * 57), col, k + li * 1000)
		# the floor of this layer: undergrowth, a band of upright leaves
		for k in 34:
			var c2: Vector2 = Vector2(full.x * float(k) / 33.0, base_y + 30.0 * (0.5 + float(li)) + 10.0 * h01(k + li * 9))
			_cluster(d, c2, 26.0, col.darkened(0.1), k + li * 2000 + 500)
	# a soft shade high up, so the name reads over the canopy
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(full.x, 0), Vector2(full.x, float(g["top"])), Vector2(0, float(g["top"]))]),
		PackedColorArray([Color(0.02, 0.05, 0.02, 0.65), Color(0.02, 0.05, 0.02, 0.65), Color(0.02, 0.05, 0.02, 0.0), Color(0.02, 0.05, 0.02, 0.0)]))
	# the forest floor: dark soil and moss, roots
	# THE GROUND ROLLS (the user: "too flat"): a rise and a dip along the floor, the gorilla following it;
	# soil darkening below, a mossy lit lip along the top, roots and stones and leaf litter on it
	var ground: PackedVector2Array = PackedVector2Array()
	var gcols: PackedColorArray = PackedColorArray()
	for k in 41:
		var x: float = full.x * float(k) / 40.0
		ground.append(Vector2(x, _ground_at(x, floor_y)))
		gcols.append(Color(0.20, 0.17, 0.08))
	ground.append(Vector2(full.x, full.y))
	gcols.append(Color(0.04, 0.03, 0.02))
	ground.append(Vector2(0.0, full.y))
	gcols.append(Color(0.04, 0.03, 0.02))
	d.draw_polygon(ground, gcols)
	var lip: PackedVector2Array = ground.slice(0, 41)
	d.draw_polyline(lip, Color(0.30, 0.42, 0.14), 6.0, true)
	d.draw_polyline(lip, Color(0.45, 0.56, 0.20), 2.0, true)
	for k in 70:
		var x2: float = h01(k * 5 + 900) * full.x
		var p: Vector2 = Vector2(x2, _ground_at(x2, floor_y) + 4.0 + h01(k * 5 + 901) * 46.0)
		_ell(d, p, 6.0 + 12.0 * h01(k + 950), 2.5 + 3.0 * h01(k + 960),
			[Color(0.30, 0.38, 0.14, 0.7), Color(0.42, 0.30, 0.14, 0.7), Color(0.20, 0.16, 0.08, 0.8)][k % 3])
	# roots snaking along the ground, and stones
	for k in 4:
		var x0: float = full.x * (0.12 + 0.25 * float(k))
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 9:
			var x3: float = x0 + float(j) * 14.0
			pts.append(Vector2(x3, _ground_at(x3, floor_y) + 6.0 + sin(float(j) * 1.3 + float(k)) * 5.0 + float(j) * 1.5))
		d.draw_polyline(pts, Color(0.30, 0.20, 0.10), 6.0 - float(k % 2) * 2.0, true)
		d.draw_polyline(pts, Color(0.42, 0.30, 0.16), 1.5, true)
	for k in 6:
		var x4: float = h01(k * 7 + 300) * full.x
		var sp: Vector2 = Vector2(x4, _ground_at(x4, floor_y) + 14.0 + 20.0 * h01(k + 310))
		_ell(d, sp, 12.0 + 8.0 * h01(k + 320), 7.0 + 4.0 * h01(k + 330), Color(0.32, 0.32, 0.30))
		_ell(d, sp + Vector2(-3, -3), 6.0, 3.0, Color(0.48, 0.48, 0.44))
	# the mossy log at the left, the baby's seat
	var room: float = floor_y - float(g["top"])
	var log_y: float = floor_y - room * 0.06
	var log_r: Rect2 = Rect2(full.x * 0.04, log_y - room * 0.05, full.x * 0.48, room * 0.10)
	d.draw_rect(log_r, Color(0.28, 0.18, 0.10))
	d.draw_rect(Rect2(log_r.position, Vector2(log_r.size.x, log_r.size.y * 0.35)), Color(0.36, 0.48, 0.16))
	for k in 8:
		var bx: float = log_r.position.x + log_r.size.x * (0.05 + 0.12 * float(k))
		d.draw_line(Vector2(bx, log_r.position.y + log_r.size.y * 0.45), Vector2(bx + 30.0, log_r.position.y + log_r.size.y * 0.55), Color(0.18, 0.11, 0.06), 2.0)
	_ell(d, Vector2(log_r.end.x, log_r.get_center().y), log_r.size.y * 0.30, log_r.size.y * 0.50, Color(0.55, 0.40, 0.24))
	_ell(d, Vector2(log_r.end.x, log_r.get_center().y), log_r.size.y * 0.18, log_r.size.y * 0.32, Color(0.42, 0.28, 0.15))

# a cluster of leaves: pointed blades fanning out from a center, each with a lit and a shaded half
func _cluster(d: CanvasItem, c: Vector2, radius: float, col: Color, seed_i: int) -> void:
	var n: int = 9
	for k in n:
		var ang: float = TAU * float(k) / float(n) + h01(seed_i * 13 + k) * 0.6
		var length: float = radius * (0.7 + 0.5 * h01(seed_i * 17 + k))
		var dir: Vector2 = Vector2.from_angle(ang)
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var w: float = length * 0.26
		var base: Vector2 = c + dir * radius * 0.15
		var tip: Vector2 = base + dir * length
		var mid: Vector2 = base + dir * length * 0.45
		var lit: Color = col.lightened(0.10 + 0.12 * maxf(0.0, -dir.y))
		d.draw_colored_polygon(PackedVector2Array([base, mid + nrm * w, tip]), lit)
		d.draw_colored_polygon(PackedVector2Array([base, tip, mid - nrm * w]), col.darkened(0.12))

# the forest floor's height at x: a gentle rise and dip
func _ground_at(x: float, floor_y: float) -> float:
	return floor_y - 10.0 + 16.0 * sin(x * 0.010 + 0.6) + 7.0 * sin(x * 0.027 + 2.0)

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- over the gorillas: the light, the vines, the framing leaves, the life in the air ---------------------

func _paint_top(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var floor_y: float = g["floor"]
	# shafts of light, slanting from the top right, breathing slowly
	for k in 4:
		var x0: float = full.x * (0.30 + 0.20 * float(k))
		var a: float = 0.09 + 0.04 * sin(t * 0.3 + float(k) * 1.3)
		cv.draw_polygon(PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + 50.0, 0.0), Vector2(x0 - 160.0, floor_y), Vector2(x0 - 260.0, floor_y)]),
			PackedColorArray([Color(1.0, 0.96, 0.72, a), Color(1.0, 0.96, 0.72, a), Color(1.0, 0.96, 0.72, 0.0), Color(1.0, 0.96, 0.72, 0.0)]))
	# motes drifting in the light
	for k in 24:
		var u: float = fmod(t * (0.02 + 0.02 * h01(k)) + h01(k + 3), 1.0)
		var p: Vector2 = Vector2(full.x * h01(k + 40) + sin(t * 0.5 + float(k)) * 20.0, floor_y * (1.0 - u))
		cv.draw_circle(p, 1.4, Color(1.0, 0.95, 0.70, 0.5 * sin(u * PI)))
	# butterflies: two, fluttering along a slow loop
	for k in 2:
		var c: Vector2 = Vector2(full.x * (0.55 + 0.25 * sin(t * 0.21 + float(k) * 2.0)), floor_y * (0.45 + 0.15 * sin(t * 0.33 + float(k))))
		var flap: float = absf(sin(t * 11.0 + float(k))) * 1.7
		var wc: Color = [Color(0.25, 0.55, 0.95), Color(0.98, 0.62, 0.18)][k]
		for side in [-1.0, 1.0]:
			_ell(cv, c + Vector2(side * 7.0 * flap, -3.0), 7.0 * flap + 1.5, 10.0, wc)
			_ell(cv, c + Vector2(side * 5.0 * flap, 7.0), 5.0 * flap + 1.5, 7.0, wc.darkened(0.2))
		cv.draw_line(c + Vector2(0, -5), c + Vector2(0, 6), Color(0.1, 0.08, 0.06), 2.0)
	# vines hanging from the canopy, swaying
	for k in 5:
		var x: float = full.x * (0.08 + 0.21 * float(k))
		var length: float = floor_y * (0.30 + 0.30 * h01(k + 70))
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 12:
			var u: float = float(j) / 11.0
			pts.append(Vector2(x + sin(t * 0.6 + float(k)) * 14.0 * u * u + sin(u * 6.0 + float(k)) * 4.0, u * length))
		cv.draw_polyline(pts, Color(0.10, 0.18, 0.08), 3.0, true)
		for j in 5:
			var lp: Vector2 = pts[2 + j * 2]
			_ell(cv, lp + Vector2(6.0 if j % 2 == 0 else -6.0, 0.0), 7.0, 3.5, Color(0.16, 0.32, 0.12))
	# the great leaves framing the corners, dark, nodding in a breeze
	var fronds: Array = [[Vector2(-10.0, floor_y * 0.20), 0.3], [Vector2(full.x + 10.0, floor_y * 0.12), PI - 0.3],
		[Vector2(-10.0, floor_y + 10.0), -0.5], [Vector2(full.x + 10.0, floor_y), PI + 0.5]]
	for k in fronds.size():
		var base: Vector2 = fronds[k][0]
		var ang: float = float(fronds[k][1]) + 0.05 * sin(t * 0.8 + float(k))
		_frond(base, ang, full.x * 0.36, Color(0.05, 0.12, 0.05))
	title("Gorilla", "Eat apples and rescue the lost baby gorillas", Color(0.98, 0.86, 0.42), Color(0.08, 0.12, 0.04),
		Color(0.9, 0.9, 0.4, 0.22))

# a palm frond: a curving rib with leaflets along both sides
func _frond(base: Vector2, ang: float, length: float, col: Color) -> void:
	var dir: Vector2 = Vector2.from_angle(ang)
	var nrm: Vector2 = Vector2(-dir.y, dir.x)
	var prev: Vector2 = base
	for j in 14:
		var u: float = float(j + 1) / 14.0
		var p: Vector2 = base + dir * length * u + nrm * length * 0.18 * u * u
		cv.draw_line(prev, p, col, 4.0 * (1.0 - u) + 1.5)
		var lf: float = length * 0.28 * sin(u * PI)
		for side in [-1.0, 1.0]:
			var tip: Vector2 = p + (nrm * side * 0.9 + dir * 0.45).normalized() * lf
			cv.draw_colored_polygon(PackedVector2Array([p, p + dir * 8.0, tip]), col)
		prev = p
