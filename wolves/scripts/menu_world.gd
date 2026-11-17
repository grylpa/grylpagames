extends "res://scripts/menu_poster.gd"

# WOLVES' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own clearing
# seen from above (forest.gdshader's woods closing in round a lawn) with its own animals (beast_art.gd):
# a flock grazing in the middle, drifting a little; the border collie circling it, tail wagging; and two
# wolves creeping out of the trees toward it -- until the dog swings round at them and they slink back
# into the shade, and come again. Made up, never the board: the menu also opens mid-game.

const BEAST: Script = preload("res://wolves/scripts/beast_art.gd")
const SHEEP_N: int = 9
const CYCLE: float = 9.0
const ZOOM: float = 2.2         # the animals are drawn in board units (a cell is 40); this many px each

var _woods: Control = null
var _glade_c: Vector2 = Vector2.ZERO     # the glade, in screen px
var _glade_r: Vector2 = Vector2.ZERO
var _field: Node2D = null
var _sheep: Array = []
var _dog: Node2D = null
var _wolves: Array = []
var _center: Vector2 = Vector2.ZERO
var _laid_for: Vector2 = Vector2.ZERO
var _shadows: Control = null
var _dust: Array = []          # [screen position, when] behind a fleeing wolf
var _bark: float = 0.0

func _setup() -> void:
	# the lawn and the woods never move: still layers, baked (menu_poster.gd `add_still`)
	add_still(func(d: Control) -> void: _draw_lawn(d))
	# THE WOODS, drawn once: tree crowns seen from above round an irregular glade (the user's rule: a poster
	# is a picture -- the square clearing in the game's forest shader read like a board)
	_woods = add_still(func(d: Control) -> void: _draw_woods(d))
	# the sheep's contact shadows, under them: they stand ON the grass (without, they floated like clouds)
	_shadows = Control.new()
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadows.draw.connect(func() -> void:
		for sh in _sheep:
			var sp: Vector2 = (sh as Node2D).position * ZOOM
			_ell_on(_shadows, sp + Vector2(4.0, 6.0), 30.0, 22.0, Color(0.05, 0.12, 0.03, 0.40))
			_ell_on(_shadows, sp + Vector2(2.0, 3.0), 24.0, 17.0, Color(0.05, 0.12, 0.03, 0.30)))
	add_child(_shadows)
	_field = Node2D.new()
	_field.scale = Vector2(ZOOM, ZOOM)
	add_child(_field)
	for k in SHEEP_N:
		_sheep.append(_animal("sheep"))
	_dog = _animal("dog")
	for k in 2:
		_wolves.append(_animal("wolf"))

# the animals' pictures are rendered into atlases a moment in (drawn as shapes until then): the glade shows
# at once and the animals fade in when their pictures are ready
var _animals_a: float = 0.0

func _atlases_ready() -> bool:
	return BEAST._atlases.has("sheep") and BEAST._atlases.has("dog") and BEAST._atlases.has("wolf")

func _animal(kind: String) -> Node2D:
	var head: Node2D = Node2D.new()
	_field.add_child(head)
	var art: Node2D = BEAST.new()
	art.set("kind", kind)
	head.add_child(art)
	# NATURAL PROPORTIONS for the dog and the wolves (the user): the game draws them stockier across the
	# body (BEAST_GIRTH) so they read on a phone's small board; here they are large, so the girth is taken
	# off again -- the picture holds it and its own draw divides it back out, so a uniform scale is natural
	if kind != "sheep":
		var k: float = float(BEAST.SIZE) * float(BEAST.BEAST_SIZE)
		art.scale = Vector2(k, k)
	return head

func _lay(full: Vector2, bottom: float) -> void:
	var key: Vector2 = Vector2(full.x, bottom)
	if key == _laid_for:
		return
	_laid_for = key
	# the glade: the middle of the scene, under the name and above the panel
	var top: float = 230.0 if mobile else 150.0
	_glade_c = Vector2(full.x * 0.5, (top + 20.0 + bottom - 40.0) * 0.5)
	_glade_r = Vector2(full.x * 0.40, maxf(80.0, (bottom - top - 60.0) * 0.46))
	_center = _glade_c / ZOOM
	_woods.queue_redraw()

# THE ANIMALS STEER, they are not slid along a path (the user: when they turned "they move more than they
# turn" -- their bodies turned slowly while their places followed the path, so they crabbed sideways). Each
# has a point it wants to reach; it turns toward it (at most TURN_RATE) and walks FORWARD along its own
# heading, slowing almost to a stop while it faces away -- so it turns, then goes, as an animal does.
const TURN_RATE: float = 3.2

func _steer(n: Node2D, target: Vector2, max_speed: float, delta: float) -> void:
	if not n.has_meta("init"):
		n.set_meta("init", true)
		n.position = target
		n.rotation = h01(n.get_instance_id() % 997) * TAU
		return
	var to: Vector2 = target - n.position
	var dist: float = to.length()
	if dist < 0.6:
		return
	var err: float = angle_difference(n.rotation, to.angle())
	n.rotation += clampf(err, -TURN_RATE * delta, TURN_RATE * delta)
	var facing: float = maxf(0.0, cos(angle_difference(n.rotation, to.angle())))
	var speed: float = minf(max_speed, dist * 2.5) * facing * facing
	n.position += Vector2.from_angle(n.rotation) * speed * delta

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_lay(full, bottom)
	var spread: float = minf(full.x, bottom) / ZOOM * 0.16
	# the flock, grazing: each sheep ambles a little round its place
	for k in _sheep.size():
		var a0: float = TAU * float(k) / float(_sheep.size()) + h01(k) * 0.8
		var rad: float = spread * (0.45 + 0.80 * h01(k + 20))      # apart enough not to overlap
		var home: Vector2 = _center + Vector2(cos(a0), sin(a0)) * rad
		# GRAZING IN STEPS (the user: drifting smoothly they floated "like clouds"): a sheep stands with its
		# head down, then takes a few quick steps forward along its heading, which turns a little with every
		# walk -- so it moves only the way it faces, and slowly traces a small loop round its place
		var period: float = 2.6 + 1.4 * h01(k + 70)
		var tau: float = t / period + h01(k + 80)
		var walked: float = floor(tau) + smoothstep(0.62, 1.0, tau - floor(tau))
		var turn_per_walk: float = 0.35 * (1.0 if k % 2 == 0 else -1.0)
		var face: float = h01(k + 60) * TAU + walked * turn_per_walk
		var loop_r: float = 4.0 / absf(turn_per_walk)
		var center0: float = h01(k + 60) * TAU
		_sheep[k].position = home + Vector2(sin(face) - sin(center0), -cos(face) + cos(center0)) * loop_r * signf(turn_per_walk)
		_sheep[k].rotation = face
	_shadows.queue_redraw()
	_animals_a = fade_in(_atlases_ready(), _animals_a, delta)
	_field.modulate.a = _animals_a
	_shadows.modulate.a = _animals_a
	# the wolves: out of the woods toward the flock, then back when the dog turns on them
	var u: float = fmod(t, CYCLE) / CYCLE
	var creep: float = smoothstep(0.0, 0.55, u) * (1.0 - smoothstep(0.62, 0.80, u))
	var sides: Array = [Vector2(-1.0, -0.35), Vector2(1.0, 0.45)]
	for k in 2:
		var from: Vector2 = _center + sides[k] * Vector2(full.x / ZOOM * 0.44, spread * 2.2)
		var to: Vector2 = _center + sides[k] * Vector2(spread * 1.9, spread * 0.8)
		var fleeing: bool = u > 0.60 and u < 0.86
		var goal: Vector2 = from.lerp(to, creep)
		if fleeing:
			goal = from + (from - _center).normalized() * 30.0     # back into the trees, and beyond
		_steer(_wolves[k], goal, 95.0 if fleeing else 30.0, delta)
		if fleeing and fmod(t, 0.09) < delta:
			_dust.append([_wolves[k].position * ZOOM, t])
	# the dog circles the flock, and in the middle of the cycle dashes at the nearer wolf
	var ring: float = spread * 2.0
	var ang: float = t * 0.9
	var circling: Vector2 = _center + Vector2(cos(ang), sin(ang)) * ring
	var dash: float = smoothstep(0.50, 0.62, u) * (1.0 - smoothstep(0.70, 0.86, u))
	var target: Vector2 = _wolves[0].position.lerp(_center, 0.15)
	var goal: Vector2 = circling.lerp(target, dash)
	# never through the flock: a goal inside it is pushed out to its edge, and a dog inside it heads out
	var keep: float = spread * 1.75
	if goal.distance_to(_center) < keep:
		goal = _center + (goal - _center).normalized() * keep
	if _dog.position.distance_to(_center) < keep:
		goal = _center + (_dog.position - _center).normalized() * (keep + 10.0)
	_steer(_dog, goal, 90.0, delta)
	# THE BARK: as the dog reaches the wolves it stops short and barks -- its head jerks forward with each
	# bark, rings of sound go out ahead of it -- and the wolves bolt
	_bark = 1.0 if (u > 0.56 and u < 0.74) else 0.0
	var pulse: float = maxf(0.0, sin(t * 14.0)) if _bark > 0.0 else 0.0
	_dog.scale = Vector2.ONE * (1.0 + 0.10 * pulse)
	while not _dust.is_empty() and t - float(_dust[0][1]) > 0.9:
		_dust.pop_front()

# THE LAWN, drawn ONCE on its own layer under the woods (the user: "improve the grass under the sheep"):
# the pasture's yellow-green, lit from the top left, broad soft patches of lighter and darker grass, and
# thousands of fine blades in three greens, with clover and a few small flowers -- static, so the many
# strokes cost nothing after the first frame.
func _draw_lawn(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.38, 0.54, 0.24))
	# light from the top left across the field
	for k in 10:
		var c: Vector2 = Vector2(full.x * 0.30, full.y * 0.30)
		_ell_on(d, c, full.x * (1.1 - 0.09 * float(k)), full.y * (0.7 - 0.055 * float(k)), Color(0.80, 0.85, 0.45, 0.022))
	for k in 90:
		var c: Vector2 = Vector2(h01(k * 3) * full.x, h01(k * 3 + 1) * full.y)
		var lighter: bool = h01(k * 3 + 2) > 0.45
		_ell_on(d, c, 30.0 + 70.0 * h01(k + 300), 18.0 + 36.0 * h01(k + 400),
			Color(0.55, 0.68, 0.30, 0.13) if lighter else Color(0.22, 0.36, 0.14, 0.15))
	var greens: Array = [Color(0.24, 0.40, 0.15, 0.70), Color(0.47, 0.62, 0.27, 0.65), Color(0.62, 0.74, 0.36, 0.55)]
	for k in 4200:
		var p: Vector2 = Vector2(h01(k * 7 + 5) * full.x, h01(k * 7 + 6) * full.y)
		var lean: float = (h01(k * 7 + 2) - 0.5) * 5.0
		var hgt: float = 4.0 + 5.0 * h01(k * 7 + 3)
		d.draw_line(p, p + Vector2(lean, -hgt), greens[k % 3], 1.2)
	for k in 60:
		var p: Vector2 = Vector2(h01(k * 11 + 1) * full.x, h01(k * 11 + 2) * full.y)
		for j in 3:
			d.draw_circle(p + Vector2(cos(float(j) * 2.1), sin(float(j) * 2.1)) * 3.0, 2.6, Color(0.28, 0.48, 0.18, 0.8))
	for k in 45:
		var p: Vector2 = Vector2(h01(k * 13 + 4) * full.x, h01(k * 13 + 5) * full.y)
		var fc: Color = [Color(0.98, 0.97, 0.90), Color(0.98, 0.86, 0.30), Color(0.85, 0.70, 0.95)][k % 3]
		d.draw_circle(p, 2.2, fc)
		d.draw_circle(p, 0.9, Color(0.95, 0.75, 0.25))

const LIGHT: Vector2 = Vector2(-0.6, -0.8)

func _broadleaf(d: Control, c: Vector2, r: float, seed_i: int) -> void:
	var base: Color = [Color(0.12, 0.26, 0.10), Color(0.15, 0.30, 0.11), Color(0.10, 0.22, 0.12)][seed_i % 3]
	d.draw_circle(c, r * 0.86, base.darkened(0.35))
	for j in 22:
		var a: float = h01(seed_i * 29 + j) * TAU
		var rr: float = sqrt(h01(seed_i * 31 + j)) * r * 0.78
		var off: Vector2 = Vector2.from_angle(a) * rr
		var lit: float = clampf(0.5 + 0.5 * off.normalized().dot(LIGHT) * (rr / r), 0.0, 1.0)
		var cr: float = r * (0.24 + 0.12 * h01(seed_i * 37 + j))
		d.draw_circle(c + off, cr, base.darkened(0.25).lerp(base.lightened(0.28), lit))
		d.draw_circle(c + off + Vector2(-cr * 0.25, -cr * 0.30), cr * 0.45, base.lightened(0.18 + 0.2 * lit))
	for j in 6:
		var a2: float = h01(seed_i * 41 + j) * TAU
		d.draw_circle(c + Vector2.from_angle(a2) * r * 0.5 * h01(seed_i * 43 + j) + LIGHT * r * 0.25, 2.0, base.lightened(0.45))

func _conifer(d: Control, c: Vector2, r: float, seed_i: int) -> void:
	var base: Color = Color(0.07, 0.18, 0.12)
	for tier in 3:
		var tier_r: float = r * (1.0 - 0.28 * float(tier))
		var n: int = 11 - tier * 2
		var rot: float = h01(seed_i * 3 + tier) * TAU
		var pts: PackedVector2Array = PackedVector2Array()
		for k in n * 2:
			var a: float = rot + TAU * float(k) / float(n * 2)
			var rad: float = tier_r if k % 2 == 0 else tier_r * 0.55
			pts.append(c + Vector2.from_angle(a) * rad + LIGHT * float(tier) * 2.0)
		d.draw_colored_polygon(pts, base.lightened(0.10 * float(tier)))
		# the lit side of each tier
		var lit_pts: PackedVector2Array = PackedVector2Array([c])
		for k in range(n * 2 / 2 + 1):
			var a3: float = LIGHT.angle() - PI * 0.5 + PI * float(k) / float(n)
			lit_pts.append(c + Vector2.from_angle(a3) * tier_r * (0.9 if k % 2 == 0 else 0.5))
		d.draw_colored_polygon(lit_pts, Color(0.35, 0.55, 0.30, 0.18))
	d.draw_circle(c + LIGHT * 2.0, r * 0.08, base.lightened(0.3))

# the glade's edge, a little irregular: how far out from its center the trees begin, by angle
func _glade_edge(a: float) -> float:
	return 1.0 + 0.10 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 7.0 + 2.1) + 0.04 * sin(a * 11.0)

func _in_glade(p: Vector2, margin: float) -> bool:
	var q: Vector2 = (p - _glade_c) / _glade_r
	return q.length() < _glade_edge(q.angle()) - margin

# THE WOODS from above: crowns (each three or four overlapping discs, lit on the side toward the evening
# sun at the top left, a soft shadow cast to the bottom right) everywhere outside the glade; an old dry-stone
# wall along part of the glade's edge; the evening light warm across everything
func _draw_woods(d: Control) -> void:
	if _glade_r.x <= 0.0:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var crowns: Array = []
	var step: float = 44.0
	var y: float = -20.0
	var row: int = 0
	while y < full.y + 20.0:
		var x: float = -20.0 + (step * 0.5 if row % 2 == 1 else 0.0)
		var col_i: int = 0
		while x < full.x + 20.0:
			var p: Vector2 = Vector2(x, y) + Vector2(h01(row * 97 + col_i) - 0.5, h01(row * 131 + col_i + 7) - 0.5) * step * 0.7
			if not _in_glade(p, -0.12):
				crowns.append([p, 26.0 + 14.0 * h01(row * 53 + col_i * 3), row * 1000 + col_i])
			x += step
			col_i += 1
		y += step * 0.85
		row += 1
	# shadows first, all of them, then the crowns: a crown's shadow never lies over a nearer crown
	for c in crowns:
		_ell_on(d, c[0] + Vector2(14.0, 18.0), float(c[1]) * 1.1, float(c[1]) * 0.9, Color(0.02, 0.06, 0.02, 0.35))
	# THE CROWNS (the user: smooth discs were "green balls" that did not read as trees): a broadleaf crown is
	# many small LEAF CLUMPS, each lit by where it sits in the crown (brighter toward the sun at the top
	# left), so the edge is ragged and the crown has depth; every fourth tree is a CONIFER seen from above,
	# a spiky star in three tiers
	for c in crowns:
		var p2: Vector2 = c[0]
		var r: float = c[1]
		var seed_i: int = c[2]
		if seed_i % 4 == 0:
			_conifer(d, p2, r * 0.9, seed_i)
		else:
			_broadleaf(d, p2, r, seed_i)
	# the dry-stone wall along the glade's lower left edge
	for k in 26:
		var a: float = lerpf(PI * 0.55, PI * 1.05, float(k) / 25.0)
		var e: float = _glade_edge(a) - 0.06
		var p3: Vector2 = _glade_c + Vector2(cos(a) * _glade_r.x, sin(a) * _glade_r.y) * e
		for j in 2:
			var sp: Vector2 = p3 + Vector2(cos(a), sin(a)) * float(j) * 9.0
			_ell_on(d, sp + Vector2(2, 3), 8.0, 6.0, Color(0, 0, 0, 0.30))
			_ell_on(d, sp, 8.0, 6.0, Color(0.56, 0.55, 0.50).darkened(0.25 * h01(k * 3 + j)))
			d.draw_circle(sp + Vector2(-2, -2), 3.0, Color(0.72, 0.71, 0.66))
	# the evening light: warm from the top left, cooling to the bottom right
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(full.x, 0), Vector2(full.x, full.y), Vector2(0, full.y)]),
		PackedColorArray([Color(1.0, 0.80, 0.45, 0.16), Color(1.0, 0.85, 0.55, 0.06), Color(0.10, 0.12, 0.30, 0.22), Color(1.0, 0.85, 0.55, 0.04)]))

func _ell_on(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# dust kicked up by the fleeing wolves
	for d in _dust:
		var age: float = t - float(d[1])
		var a: float = 1.0 - age / 0.9
		for gg in 3:
			cv.draw_circle(d[0], (8.0 + 30.0 * age) * (1.0 - 0.25 * float(gg)), Color(0.78, 0.70, 0.52, 0.10 * a))
	# the bark: arcs of sound going out ahead of the dog, three at a time
	if _bark > 0.0 and _dog != null:
		var head: Vector2 = _dog.position * ZOOM + Vector2.from_angle(_dog.rotation) * 34.0
		for k in 3:
			var ring: float = fmod(t * 2.6 + float(k) / 3.0, 1.0)
			var r: float = 18.0 + ring * 95.0
			var col: Color = Color(1.0, 0.97, 0.85, 0.95 * (1.0 - ring))
			cv.draw_arc(head, r, _dog.rotation - 0.7, _dog.rotation + 0.7, 18, Color(0.1, 0.08, 0.04, 0.35 * (1.0 - ring)), 9.0 - 4.0 * ring, true)
			cv.draw_arc(head, r, _dog.rotation - 0.7, _dog.rotation + 0.7, 18, col, 6.0 - 3.0 * ring, true)
	title("Wolves", "Guard your flock from the wolves", Color(0.96, 0.93, 0.84), Color(0.05, 0.08, 0.04),
		Color(0.0, 0.0, 0.0, 0.45))
