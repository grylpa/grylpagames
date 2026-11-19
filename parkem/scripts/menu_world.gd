extends "res://scripts/menu_poster.gd"

# DETOUR'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): A DUNGEON CORRIDOR, ALL IN
# 3-D (one camera, `_proj`, at a walker's eye height): flagstones and block walls running away under a barrel
# vault into the dark, torches in iron sconces down both walls, their flames alive and their light warm on
# the stone. On the right a doorway into a TREASURE ROOM, gold spilling out of it; its heavy iron-bound door
# hangs on a hinge at the doorway's far side. The game's creatures (MonsterArt's armored bugs: a dark shell,
# swept-back horns, amber slit eyes, fangs, scuttling legs) come one by one out of the dark toward the gold --
# and each time, just before one gets there, the door SWINGS SHUT in its face (turning about its hinge, with
# its thickness); the creature hesitates, turns its head to the shut door, and scuttles on toward us and off
# into a dark side passage on the left; then the door swings open again. The game in one picture: you never
# stop them, you turn them aside. Everything follows one clock (`t`); nothing pops. Made up, never the board.

const W: float = 100.0               # the corridor's half width
const H: float = 170.0               # its walls' height (the vault rises above)
const VAULT: float = 70.0
const FAR: float = -1700.0
const DOOR_Z0: float = -370.0        # the treasure doorway, near us on the right wall, from DOOR_Z0 to DOOR_Z1
const DOOR_Z1: float = -180.0
const DOOR_H: float = 150.0
const SIDE_Z0: float = -300.0        # the side passage on the left, across from it, where the creatures go
const SIDE_Z1: float = -180.0
const INNER_TORCH: Vector3 = Vector3(-W - 150.0, 100.0, SIDE_Z0 + 5.0)    # a torch deep in the side passage
const PERIOD: float = 7.0            # a creature every PERIOD seconds
const SPEED: float = 240.0
const TORCHES: Array = [[-1.0, -110.0], [1.0, -110.0], [-1.0, -440.0], [1.0, -660.0], [-1.0, -900.0], [1.0, -1020.0], [-1.0, -1400.0], [1.0, -1450.0]]
const MORTAR: Color = Color(0.36, 0.31, 0.25)      # the grout between the stones
const SHELL: Color = Color(0.20, 0.14, 0.22)
const EYE: Color = Color(1.0, 0.78, 0.18)

var _room: Control = null
var _life: Control = null
var _cam: Dictionary = {}
var _for_bottom: float = -2.0
# a creature's way, in (x, z) on the floor: out of the dark, veering to the gold's doorway, stopping before
# it, then on toward us and round into the side passage on the left
const WAY: Array = [Vector2(-10, -1660), Vector2(-10, -1100), Vector2(4, -760), Vector2(30, -460), Vector2(56, -262),
	Vector2(24, -226), Vector2(-40, -240), Vector2(-230, -240)]
const STOP_AT: int = 4               # WAY's point where it stops before the doorway
const HOLD: float = 1.2              # seconds it stands facing the shut door
var _way: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _s_stop: float = 0.0
var _s_close: float = 0.0            # the door must be shut before it gets here (clear of the swing)
var _s_open: float = 0.0             # and opens once it is past here

func _setup() -> void:
	_build_way()
	# the corridor never moves: a still layer, baked (menu_poster.gd `add_still`)
	_room = add_still(func(d: Control) -> void: _draw_room(d))
	_life = _mk(func(d: Control) -> void: _draw_life(d))

func _mk(fn: Callable) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

# --- the camera --------------------------------------------------------------------------------------------

func _camera() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 230.0 if mobile else 150.0
	# a little toward the left wall and turned to the right one, so the treasure's alcove can be seen into
	var eye: Vector3 = Vector3(-62.0, 92.0, 250.0)
	var target: Vector3 = Vector3(50.0, 68.0, -700.0)
	var f: Vector3 = (target - eye).normalized()
	var r: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = r.cross(f)
	return {"eye": eye, "f": f, "r": r, "u": u, "focal": full.x * 0.95, "full": full, "bottom": bottom,
		"center": Vector2(full.x * 0.5, top + (bottom - top) * 0.46)}

# the camera's parts as plain fields, for _proj (called thousands of times a frame: reading them from the dictionary
# each time cost a phone several ms a frame)
var _c_eye: Vector3 = Vector3.ZERO
var _c_f: Vector3 = Vector3.FORWARD
var _c_r: Vector3 = Vector3.RIGHT
var _c_u: Vector3 = Vector3.UP
var _c_center: Vector2 = Vector2.ZERO
var _c_focal: float = 1.0

func _set_cam(c: Dictionary) -> void:
	_cam = c
	_c_eye = c["eye"]
	_c_f = c["f"]
	_c_r = c["r"]
	_c_u = c["u"]
	_c_center = c["center"]
	_c_focal = c["focal"]

func _proj(p: Vector3) -> Vector2:
	var v: Vector3 = p - _c_eye
	var z: float = maxf(v.dot(_c_f), 1.0)
	return _c_center + Vector2(v.dot(_c_r), -v.dot(_c_u)) * _c_focal / z

func _px(p: Vector3) -> float:
	return _c_focal / maxf((p - _c_eye).dot(_c_f), 1.0)

func _depth(p: Vector3) -> float:
	return (p - _c_eye).dot(_c_f)

# THE GOLD GLOW OUT OF THE DOORWAY on the GPU: it was 16 discs, each 2.5% (less as the door shuts), the largest a
# good part of the screen -- here one square computing the same stack, 1 - (1 - a)^n for the n discs over a pixel
const GOLD_GLOW: String = """shader_type canvas_item;
uniform float a = 0.025;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float n = clamp(ceil(16.0 * (1.0 - d)), 0.0, 16.0);
	COLOR = vec4(1.0, 0.76, 0.30, 1.0 - pow(1.0 - a, n));
}
"""
var _gold: ColorRect = null

func _tick(_delta: float) -> void:
	_set_cam(_camera())
	if _gold == null:
		_gold = ColorRect.new()
		_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm: ShaderMaterial = ShaderMaterial.new()
		var gsh: Shader = Shader.new()
		gsh.code = GOLD_GLOW
		gm.shader = gsh
		_gold.material = gm
		add_child(_gold)
		move_child(_gold, _life.get_index())
	var gold_c: Vector2 = _proj(Vector3(W - 20.0, 30.0, (DOOR_Z0 + DOOR_Z1) * 0.5))
	var gr: float = 170.0 * _px(Vector3(W, 0, DOOR_Z1))
	_gold.position = gold_c - Vector2(gr, gr)
	_gold.size = Vector2(gr, gr) * 2.0
	(_gold.material as ShaderMaterial).set_shader_parameter("a", 0.025 * (1.0 - _door_shut() * 0.7))
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		_room.queue_redraw()
	_life.queue_redraw()

# --- light -------------------------------------------------------------------------------------------------

func _torch_pos(tr_: Array) -> Vector3:
	return Vector3(float(tr_[0]) * (W - 16.0), 118.0, float(tr_[1]))

# the steady light at a point: warm from the torches near it, gold from the treasure room, a cold dark beyond
func _light(p: Vector3) -> Color:
	var col: Color = Color(0.05, 0.05, 0.08)
	for tr_ in TORCHES:
		var tp: Vector3 = _torch_pos(tr_)
		var dd: float = p.distance_to(tp)
		var k: float = 1.0 / (1.0 + pow(dd / 150.0, 2.0))
		col += Color(1.0, 0.62, 0.30) * k * 0.95
	col += Color(1.0, 0.60, 0.28) * (0.8 / (1.0 + pow(p.distance_to(INNER_TORCH) / 110.0, 2.0)))
	var gold: Vector3 = Vector3(W + 60.0, 40.0, (DOOR_Z0 + DOOR_Z1) * 0.5)
	var gd: float = p.distance_to(gold)
	col += Color(1.0, 0.78, 0.30) * (0.55 / (1.0 + pow(gd / 140.0, 2.0)))
	# the far end falls into darkness
	var fade: float = clampf((-p.z - 900.0) / 900.0, 0.0, 1.0)
	col = col.lerp(Color(0.02, 0.02, 0.04), fade * 0.8)
	return Color(minf(col.r, 1.2), minf(col.g, 1.1), minf(col.b, 1.0))

func _lit(base: Color, p: Vector3) -> Color:
	var l: Color = _light(p)
	return Color(base.r * l.r, base.g * l.g, base.b * l.b)

# a quad in the world, each corner lit by the light there
func _quad(d: CanvasItem, pts: Array, base: Color) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	for p in pts:
		q.append(_proj(p))
		cols.append(_lit(base, p))
	if Geometry2D.triangulate_polygon(q).size() > 0:
		d.draw_polygon(q, cols)

# --- the corridor, drawn once -------------------------------------------------------------------------------

func _draw_room(d: Control) -> void:
	if _cam.is_empty():
		_set_cam(_camera())
	var full: Vector2 = _cam["full"]
	d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.02, 0.02, 0.04))
	# the far end: a dark opening going on
	_quad(d, [Vector3(-W, 0, FAR), Vector3(W, 0, FAR), Vector3(W, H, FAR), Vector3(-W, H, FAR)], Color(0.10, 0.09, 0.10))
	# THE FLOOR: flagstones in rows, each a little irregular, each its own tone, mortar between
	var z: float = 230.0
	var row: int = 0
	while z > FAR:
		var depth_row: float = 44.0 + 10.0 * h01(row + 3)
		var x: float = -W - 20.0 * h01(row + 9)
		var k: int = 0
		while x < W:
			var wdt: float = 46.0 + 30.0 * h01(row * 13 + k)
			var x1: float = minf(x + wdt, W)
			var tone: float = 0.75 + 0.35 * h01(row * 7 + k * 3)
			var base: Color = Color(0.52 * tone, 0.48 * tone, 0.44 * tone)
			var g: float = 2.5
			_quad(d, [Vector3(maxf(x, -W), 0, z), Vector3(x1, 0, z), Vector3(x1, 0, z - depth_row), Vector3(maxf(x, -W), 0, z - depth_row)], MORTAR)
			_grit(d, Vector3(maxf(x, -W), 0.1, z - 1.2), Vector3(x1, 0.1, z - 1.2), row * 53 + k)
			_quad(d, [Vector3(maxf(x, -W) + g, 0, z - g), Vector3(x1 - g, 0, z - g), Vector3(x1 - g, 0, z - depth_row + g), Vector3(maxf(x, -W) + g, 0, z - depth_row + g)], base)
			_stone_tex(d, Vector3(maxf(x, -W) + g, 0.2, z - g), Vector3(x1 - g, 0.2, z - g), Vector3(x1 - g, 0.2, z - depth_row + g), Vector3(maxf(x, -W) + g, 0.2, z - depth_row + g), row * 41 + k)
			x = x1
			k += 1
		z -= depth_row
		row += 1
	# THE TREASURE ROOM through the doorway: its back wall golden, a heap of coins and a chest catching the light
	# a SHALLOW alcove (a deep room could not be seen into from the corridor: the wall hid it)
	var rx: float = W + 75.0
	_quad(d, [Vector3(W, 0, DOOR_Z0), Vector3(rx, 0, DOOR_Z0), Vector3(rx, 0, DOOR_Z1), Vector3(W, 0, DOOR_Z1)], Color(0.70, 0.55, 0.30))
	# its walls in the same blocks and mortar as the corridor's (they were flat orange)
	_block_wall(d, Vector3(rx, 0, DOOR_Z0 - 60.0), Vector3(rx, 0, DOOR_Z1 + 60.0), DOOR_H + 30.0, 901)
	_block_wall(d, Vector3(W, 0, DOOR_Z0), Vector3(rx, 0, DOOR_Z0), DOOR_H + 30.0, 902)
	# THE WALLS: blocks in courses, both sides, with the doorway and the side passage left open
	for side in [-1.0, 1.0]:
		var wx: float = side * W
		var course: int = 0
		var y: float = 0.0
		while y < H:
			var ch: float = 30.0
			var zz: float = 230.0 - 40.0 * float(course % 2)
			var b: int = 0
			while zz > FAR:
				var bl: float = 70.0 + 30.0 * h01(course * 17 + b + int(side * 5.0))
				var z0: float = zz
				var z1: float = zz - bl
				zz = z1
				b += 1
				# leave the openings
				if side > 0.0 and z1 < DOOR_Z1 and z0 > DOOR_Z0 and y < DOOR_H:
					continue
				if side < 0.0 and z1 < SIDE_Z1 and z0 > SIDE_Z0 and y < DOOR_H - 30.0:
					continue
				var tone: float = 0.70 + 0.35 * h01(course * 29 + b * 5 + int(side * 3.0))
				var base: Color = Color(0.50 * tone, 0.45 * tone, 0.42 * tone)
				# THE MORTAR BED behind the block: sandy grout, lit like the stone (the gaps were open, and the
				# treasure alcove's wall showed through them as flat light brown)
				_quad(d, [Vector3(wx, y, z0), Vector3(wx, y, z1), Vector3(wx, y + ch, z1), Vector3(wx, y + ch, z0)], MORTAR)
				_grit(d, Vector3(wx, y + 1.0, z0), Vector3(wx, y + 1.0, z1), course * 71 + b)
				_quad(d, [Vector3(wx, y + 2.0, z0 - 2.0), Vector3(wx, y + 2.0, z1 + 2.0), Vector3(wx, y + ch - 2.0, z1 + 2.0), Vector3(wx, y + ch - 2.0, z0 - 2.0)], base)
				var wi: Vector3 = Vector3(-side * 0.3, 0, 0)
				_stone_tex(d, Vector3(wx, y + ch - 2.0, z0 - 2.0) + wi, Vector3(wx, y + ch - 2.0, z1 + 2.0) + wi, Vector3(wx, y + 2.0, z1 + 2.0) + wi, Vector3(wx, y + 2.0, z0 - 2.0) + wi, course * 53 + b * 7 + int(side * 3.0))
			y += 30.0
			course += 1
	# THE VAULT: a barrel ceiling in strips, ribs across it every so often
	var strips: int = 10
	for k in strips:
		var a0: float = PI * float(k) / float(strips)
		var a1: float = PI * float(k + 1) / float(strips)
		var p0: Vector3 = Vector3(cos(a0) * W, H + sin(a0) * VAULT, 0)
		var p1: Vector3 = Vector3(cos(a1) * W, H + sin(a1) * VAULT, 0)
		# the dark mortar behind, then the vault's stones in courses along it, staggered, each textured
		_quad(d, [p0 + Vector3(0, 0, 230), p1 + Vector3(0, 0, 230), p1 + Vector3(0, 0, FAR), p0 + Vector3(0, 0, FAR)], Color(0.10, 0.09, 0.09))
		var zs: float = 230.0 - 30.0 * float(k % 2)
		var bi: int = 0
		while zs > FAR:
			var bl: float = 60.0 + 26.0 * h01(k * 37 + bi)
			var tone: float = 0.75 + 0.35 * h01(k * 11 + bi * 3)
			var inset: Vector3 = (p1 - p0) * 0.04
			var q00: Vector3 = p0 + inset + Vector3(0, 0, zs - 2.0)
			var q10: Vector3 = p1 - inset + Vector3(0, 0, zs - 2.0)
			var q11: Vector3 = p1 - inset + Vector3(0, 0, zs - bl + 2.0)
			var q01: Vector3 = p0 + inset + Vector3(0, 0, zs - bl + 2.0)
			_quad(d, [q00, q10, q11, q01], Color(0.40 * tone, 0.36 * tone, 0.33 * tone))
			_stone_tex(d, q00, q10, q11, q01, k * 131 + bi)
			zs -= bl
			bi += 1
	var rz: float = 100.0
	while rz > FAR:
		for k in strips:
			var a2: float = PI * float(k) / float(strips)
			var a3: float = PI * float(k + 1) / float(strips)
			var q0: Vector3 = Vector3(cos(a2) * W, H + sin(a2) * VAULT, rz)
			var q1: Vector3 = Vector3(cos(a3) * W, H + sin(a3) * VAULT, rz)
			_quad(d, [q0, q1, q1 + Vector3(0, -8, -18), q0 + Vector3(0, -8, -18)], Color(0.46, 0.40, 0.36))
			# a voussoir joint at each stone of the rib
			if _depth(q0) > 30.0:
				d.draw_line(_proj(q0), _proj(q0 + Vector3(0, -8, -18)), Color(0.08, 0.06, 0.05, 0.8), maxf(1.0, 1.2 * _px(q0)), true)
		rz -= 300.0
	# THE SIDE PASSAGE on the left: an arched opening into darkness, the wall's thickness showing in its near
	# reveal, darker deeper in
	var arch_c: float = (SIDE_Z0 + SIDE_Z1) * 0.5
	var half: float = (SIDE_Z1 - SIDE_Z0) * 0.5
	var spring: float = DOOR_H - half
	var hole: Array = [Vector3(-W, 0, SIDE_Z1)]
	for k in 13:
		var a: float = PI * float(k) / 12.0
		hole.append(Vector3(-W, spring + sin(a) * half, arch_c + cos(a) * half))
	hole.append(Vector3(-W, 0, SIDE_Z0))
	var hp: PackedVector2Array = PackedVector2Array()
	for hpt in hole:
		hp.append(_proj(hpt))
	if Geometry2D.triangulate_polygon(hp).size() > 0:
		d.draw_colored_polygon(hp, Color(0.03, 0.03, 0.04))
	# THE PASSAGE'S INSIDE, seen only through the arch (each piece clipped to the opening): its floor running
	# in, its far side wall in courses (that wall's first stretch is the arch's visible reveal), the vault over
	# it, a torch deep inside -- lost in the dark at its end (it was flat black)
	var hole_poly: PackedVector2Array = hp
	var deep: float = -W - 300.0
	_clip_quad(d, [Vector3(-W, 0, SIDE_Z0), Vector3(-W, 0, SIDE_Z1), Vector3(deep, 0, SIDE_Z1), Vector3(deep, 0, SIDE_Z0)], Color(0.46, 0.42, 0.38), hole_poly)
	for k in 6:
		var fx0: float = -W - float(k) * 50.0
		_clip_quad(d, [Vector3(fx0 - 1.0, 0.2, SIDE_Z0), Vector3(fx0 - 1.0, 0.2, SIDE_Z1), Vector3(fx0 - 3.0, 0.2, SIDE_Z1), Vector3(fx0 - 3.0, 0.2, SIDE_Z0)], Color(0.10, 0.09, 0.08), hole_poly)
	var course_i: int = 0
	var cy: float = 0.0
	while cy < DOOR_H:
		var cx: float = -W - 24.0 * float(course_i % 2)
		var bi2: int = 0
		while cx > deep:
			var bl2: float = 46.0 + 20.0 * h01(course_i * 13 + bi2)
			var tone2: float = 0.7 + 0.3 * h01(course_i * 7 + bi2 * 3)
			_clip_quad(d, [Vector3(minf(cx, -W), cy + 1.5, SIDE_Z0), Vector3(cx - bl2 + 1.5, cy + 1.5, SIDE_Z0), Vector3(cx - bl2 + 1.5, cy + 22.5, SIDE_Z0), Vector3(minf(cx, -W), cy + 22.5, SIDE_Z0)], Color(0.40 * tone2, 0.37 * tone2, 0.34 * tone2), hole_poly)
			cx -= bl2
			bi2 += 1
		cy += 24.0
		course_i += 1
	# the end of it in darkness: a veil deepening toward the far end
	for k in 8:
		var vx: float = lerpf(-W - 60.0, deep, float(k) / 8.0)
		_clip_quad(d, [Vector3(vx, 0, SIDE_Z0), Vector3(vx, 0, SIDE_Z1), Vector3(vx, DOOR_H + 20.0, SIDE_Z1), Vector3(vx, DOOR_H + 20.0, SIDE_Z0)], Color(0.0, 0.0, 0.0, 0.10), hole_poly, false)
	# the wall above and round the arch, lit from the corridor
	for k in 12:
		var a0: float = PI * float(k) / 12.0
		var a1: float = PI * float(k + 1) / 12.0
		var p0: Vector3 = Vector3(-W, spring + sin(a0) * half, arch_c + cos(a0) * half)
		var p1: Vector3 = Vector3(-W, spring + sin(a1) * half, arch_c + cos(a1) * half)
		_quad(d, [p0, p1, Vector3(-W, H, p1.z), Vector3(-W, H, p0.z)], Color(0.48, 0.43, 0.40))
	# arch stones round the opening
	for k in 9:
		var a2: float = PI * float(k) / 9.0
		var a3: float = PI * float(k + 1) / 9.0
		var q0: Vector3 = Vector3(-W + 1.0, spring + sin(a2) * half, arch_c + cos(a2) * half)
		var q1: Vector3 = Vector3(-W + 1.0, spring + sin(a3) * half, arch_c + cos(a3) * half)
		var o0: Vector3 = Vector3(-W + 1.0, spring + sin(a2) * (half + 16.0), arch_c + cos(a2) * (half + 16.0))
		var o1: Vector3 = Vector3(-W + 1.0, spring + sin(a3) * (half + 16.0), arch_c + cos(a3) * (half + 16.0))
		_quad(d, [q0, q1, o1, o0], Color(0.58, 0.52, 0.46).darkened(0.15 * h01(k + 70)))
	# the doorway's jambs and lintel, the gold light spilling out over the corridor floor
	# THE DOORWAY'S FRAME on the wall's face: big dressed stones up both sides and a lintel of three with a
	# keystone, lighter than the wall -- an opening into a room, plainly
	for side_z in [DOOR_Z0 - 16.0, DOOR_Z1]:
		for k in 5:
			var fy0: float = DOOR_H * float(k) / 5.0
			var fy1: float = DOOR_H * float(k + 1) / 5.0
			var wdt: float = 16.0 + (6.0 if k % 2 == 0 else 0.0)
			var zz0: float = side_z + (16.0 if side_z < DOOR_Z0 else 0.0)
			var zz1: float = zz0 - wdt if side_z < DOOR_Z0 else zz0 + wdt
			_quad(d, [Vector3(W - 0.4, fy0 + 1.5, zz0), Vector3(W - 0.4, fy0 + 1.5, zz1), Vector3(W - 0.4, fy1 - 1.5, zz1), Vector3(W - 0.4, fy1 - 1.5, zz0)], Color(0.62, 0.56, 0.48))
			_stone_tex(d, Vector3(W - 0.6, fy1 - 1.5, zz0), Vector3(W - 0.6, fy1 - 1.5, zz1), Vector3(W - 0.6, fy0 + 1.5, zz1), Vector3(W - 0.6, fy0 + 1.5, zz0), 660 + k + int(side_z))
	for k in 3:
		var lz0: float = lerpf(DOOR_Z0 - 20.0, DOOR_Z1 + 20.0, float(k) / 3.0)
		var lz1: float = lerpf(DOOR_Z0 - 20.0, DOOR_Z1 + 20.0, float(k + 1) / 3.0)
		var top_y: float = DOOR_H + (24.0 if k == 1 else 18.0)
		_quad(d, [Vector3(W - 0.4, DOOR_H + 1.0, lz0 + 1.5), Vector3(W - 0.4, DOOR_H + 1.0, lz1 - 1.5), Vector3(W - 0.4, top_y, lz1 - 1.5), Vector3(W - 0.4, top_y, lz0 + 1.5)], Color(0.66, 0.60, 0.52) if k == 1 else Color(0.60, 0.54, 0.47))
	# the FAR jamb (the wall's thickness, facing us; the near one faces away and is never seen -- drawn, it was a
	# flat slab), in dressed blocks, each textured
	for k in 5:
		var y0: float = DOOR_H * float(k) / 5.0
		var y1: float = DOOR_H * float(k + 1) / 5.0
		var tone: float = 0.8 + 0.3 * h01(k + 610)
		_quad(d, [Vector3(W, y0 + 1.5, DOOR_Z0), Vector3(W + 30.0, y0 + 1.5, DOOR_Z0), Vector3(W + 30.0, y1 - 1.5, DOOR_Z0), Vector3(W, y1 - 1.5, DOOR_Z0)], Color(0.46 * tone, 0.41 * tone, 0.37 * tone))
		_stone_tex(d, Vector3(W, y1 - 1.5, DOOR_Z0 + 0.3), Vector3(W + 30.0, y1 - 1.5, DOOR_Z0 + 0.3), Vector3(W + 30.0, y0 + 1.5, DOOR_Z0 + 0.3), Vector3(W, y0 + 1.5, DOOR_Z0 + 0.3), 620 + k)
	_quad(d, [Vector3(W, DOOR_H, DOOR_Z0), Vector3(W, DOOR_H, DOOR_Z1), Vector3(W, H, DOOR_Z1), Vector3(W, H, DOOR_Z0)], Color(0.50, 0.45, 0.40))
	_stone_tex(d, Vector3(W - 0.3, H, DOOR_Z0), Vector3(W - 0.3, H, DOOR_Z1), Vector3(W - 0.3, DOOR_H, DOOR_Z1), Vector3(W - 0.3, DOOR_H, DOOR_Z0), 640)
	# (the torches, holder and flame, are in the live layer: the door must be able to hide them)

# an open chest of gold: a wooden box bound in brass, its lid tipped back, the gold heaped over its rim
func _chest(d: CanvasItem, c: Vector3, clip: PackedVector2Array) -> void:
	# seen only through the doorway, like the heap
	var hw: float = 36.0
	var hd: float = 20.0
	var hh: float = 30.0
	# its body: the faces toward us (front toward -x, the near end toward +z), planked, brass at the corners
	_clip_quad(d, [c + Vector3(-hd, 0, -hw), c + Vector3(-hd, 0, hw), c + Vector3(-hd, hh, hw), c + Vector3(-hd, hh, -hw)], Color(0.42, 0.24, 0.12), clip)
	_clip_quad(d, [c + Vector3(-hd, 0, hw), c + Vector3(hd, 0, hw), c + Vector3(hd, hh, hw), c + Vector3(-hd, hh, hw)], Color(0.34, 0.19, 0.09), clip)
	for k in 3:
		var by: float = hh * (0.2 + 0.3 * float(k))
		_clip_quad(d, [c + Vector3(-hd - 0.3, by - 0.6, -hw), c + Vector3(-hd - 0.3, by - 0.6, hw), c + Vector3(-hd - 0.3, by + 0.6, hw), c + Vector3(-hd - 0.3, by + 0.6, -hw)], Color(0.12, 0.06, 0.02), clip)
	for zz in [-hw, 0.0, hw]:
		_clip_quad(d, [c + Vector3(-hd - 0.5, 0, zz - 3.0), c + Vector3(-hd - 0.5, 0, zz + 3.0), c + Vector3(-hd - 0.5, hh, zz + 3.0), c + Vector3(-hd - 0.5, hh, zz - 3.0)], Color(0.85, 0.66, 0.28), clip)
	# the gold heaped in it, its top glowing
	var top: PackedVector2Array = PackedVector2Array()
	for k in 18:
		var a: float = TAU * float(k) / 18.0
		top.append(_proj(c + Vector3(cos(a) * hd * 0.95, hh + 6.0 + 8.0 * maxf(0.0, sin(a + 0.4)) * 0.0, sin(a) * hw * 0.95) + Vector3(0, 4.0 * (1.0 - absf(cos(a))), 0)))
	for piece in Geometry2D.intersect_polygons(top, clip):
		if Geometry2D.triangulate_polygon(piece).size() > 0:
			d.draw_colored_polygon(piece, _lit(Color(0.95, 0.70, 0.20), c + Vector3(0, hh, 0)))
	for k in 30:
		var cp: Vector3 = c + Vector3((h01(k + 900) - 0.5) * hd * 1.6, hh + 4.0 + 6.0 * h01(k + 901), (h01(k + 902) - 0.5) * hw * 1.7)
		if Geometry2D.is_point_in_polygon(_proj(cp), clip):
			_ell(d, _proj(cp), 3.5 * _px(cp), 1.8 * _px(cp), _lit(Color(1.0, 0.85, 0.40), cp))
	# the lid, tipped back against the wall
	_clip_quad(d, [c + Vector3(hd, hh, -hw), c + Vector3(hd, hh, hw), c + Vector3(hd + 8.0, hh + 30.0, hw), c + Vector3(hd + 8.0, hh + 30.0, -hw)], Color(0.38, 0.21, 0.10), clip)

# the heap of gold in the treasure room
func _coins(d: CanvasItem) -> void:
	# THE HEAP OF GOLD: every coin lies ON the heap's surface (a low cone) or flat on the floor round it -- placed
	# at random heights they floated in the air, the user -- drawn far to near
	# the chest at the alcove's back, open, heaped with gold, the lid standing up behind it
	var hc: Vector3 = Vector3(W + 26.0, 0.0, (DOOR_Z0 + DOOR_Z1) * 0.5 + 10.0)
	var heap_r: float = 40.0
	var heap_h: float = 22.0
	# seen only THROUGH THE DOORWAY: the heap lies in the room, and the corridor's wall hides the rest of it
	var door_poly: PackedVector2Array = PackedVector2Array([_proj(Vector3(W, 0, DOOR_Z0)), _proj(Vector3(W, 0, DOOR_Z1)), _proj(Vector3(W, DOOR_H, DOOR_Z1)), _proj(Vector3(W, DOOR_H, DOOR_Z0))])
	_chest(d, Vector3(W + 50.0, 0.0, (DOOR_Z0 + DOOR_Z1) * 0.5 - 20.0), door_poly)
	var coins: Array = []
	for k in 120:
		var a: float = TAU * h01(k * 3 + 500)
		var rr: float = heap_r * sqrt(h01(k * 3 + 501)) * (1.25 if k >= 100 else 1.0)
		var cp: Vector3 = hc + Vector3(cos(a) * rr, 0.0, sin(a) * rr * 0.9)
		cp.y = maxf(0.0, heap_h * (1.0 - rr / heap_r))
		coins.append(cp)
	coins.sort_custom(func(x, y): return _depth(x) > _depth(y))
	# the heap's body under the coins
	var body: PackedVector2Array = PackedVector2Array()
	for k in 24:
		var a2: float = PI + PI * float(k) / 23.0
		body.append(_proj(hc + Vector3(cos(a2) * heap_r, 0.0, sin(a2) * heap_r * 0.9)))
	body.append(_proj(hc + Vector3(0, heap_h, 0)))
	var hull: PackedVector2Array = Geometry2D.convex_hull(body)
	if hull.size() >= 4:
		hull.remove_at(hull.size() - 1)
		for piece in Geometry2D.intersect_polygons(hull, door_poly):
			if Geometry2D.triangulate_polygon(piece).size() > 0:
				d.draw_colored_polygon(piece, _lit(Color(0.70, 0.48, 0.12), hc + Vector3(0, heap_h * 0.5, 0)))
	for cp2 in coins:
		var sp: Vector2 = _proj(cp2)
		if not Geometry2D.is_point_in_polygon(sp, door_poly):
			continue
		var pr: float = 4.0 * _px(cp2)
		var lc: Color = _lit(Color(0.95, 0.72, 0.22), cp2)
		_ell(d, sp + Vector2(0, pr * 0.15), pr, pr * 0.42, lc.darkened(0.35))
		_ell(d, sp, pr, pr * 0.40, lc)
		_ell(d, sp + Vector2(-pr * 0.25, -pr * 0.08), pr * 0.45, pr * 0.16, lc.lightened(0.45))

# TEXTURE ON A STONE FACE (the user: "the walls and floor and archs should have some texture"): pits and
# flecks scattered over it, a crack across some, and its upper (or near) edge caught by the light -- all placed
# in the face's own plane, so they lie on it in perspective. p00-p10 is the edge that catches the light.
func _stone_tex(d: CanvasItem, p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, seed_i: int) -> void:
	if not (_depth(p00) > 30.0 and _depth(p11) > 30.0):
		return
	var px: float = _px((p00 + p11) * 0.5)
	if px < 0.25:
		return
	for k in 4:
		var u: float = 0.1 + 0.8 * h01(seed_i * 17 + k * 2)
		var v: float = 0.1 + 0.8 * h01(seed_i * 17 + k * 2 + 1)
		var q: Vector3 = p00.lerp(p10, u).lerp(p01.lerp(p11, u), v)
		var dark: bool = h01(seed_i * 5 + k) > 0.2
		var r: float = (0.7 + 1.3 * h01(seed_i * 3 + k)) * px
		d.draw_circle(_proj(q), maxf(0.5, r), Color(0.0, 0.0, 0.0, 0.22) if dark else Color(_lit(Color(0.85, 0.80, 0.72), q), 0.18))
	if h01(seed_i * 7 + 3) > 0.7:
		var c0: Vector3 = p00.lerp(p10, 0.2 + 0.3 * h01(seed_i + 9)).lerp(p01.lerp(p11, 0.3), 0.15)
		var c1: Vector3 = c0.lerp(p01.lerp(p11, 0.7), 0.5) + (p10 - p00) * 0.12
		var c2: Vector3 = c1.lerp(p01.lerp(p11, 0.55), 0.6)
		d.draw_polyline(PackedVector2Array([_proj(c0), _proj(c1), _proj(c2)]), Color(0.0, 0.0, 0.0, 0.40), maxf(1.0, 0.8 * px), true)
	d.draw_line(_proj(p00), _proj(p10), Color(_lit(Color(0.95, 0.85, 0.70), p00), 0.30), maxf(1.0, 1.0 * px), true)

# a quad drawn only where it shows through `clip` (a screen polygon): the pieces of their intersection, in the
# light at the quad's middle (or, with lit false, in its own color)
# the side passage's arched opening, on the screen
func _side_hole() -> PackedVector2Array:
	var arch_c: float = (SIDE_Z0 + SIDE_Z1) * 0.5
	var half: float = (SIDE_Z1 - SIDE_Z0) * 0.5
	var spring: float = DOOR_H - half
	var hp: PackedVector2Array = PackedVector2Array([_proj(Vector3(-W, 0, SIDE_Z1))])
	for k in 13:
		var a: float = PI * float(k) / 12.0
		hp.append(_proj(Vector3(-W, spring + sin(a) * half, arch_c + cos(a) * half)))
	hp.append(_proj(Vector3(-W, 0, SIDE_Z0)))
	return hp

func _clip_quad(d: CanvasItem, pts: Array, col: Color, clip: PackedVector2Array, lit: bool = true) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	var mid: Vector3 = Vector3.ZERO
	for p in pts:
		q.append(_proj(p))
		mid += Vector3(p) / float(pts.size())
	var c: Color = _lit(col, mid) if lit else col
	if lit:
		c.a = col.a
	for piece in Geometry2D.intersect_polygons(q, clip):
		if Geometry2D.triangulate_polygon(piece).size() > 0:
			d.draw_colored_polygon(piece, c)

# a wall of blocks in courses on mortar, from a to b along the floor, h high
func _block_wall(d: CanvasItem, a: Vector3, b: Vector3, h: float, seed_i: int) -> void:
	var ln: float = a.distance_to(b)
	var dir: Vector3 = (b - a).normalized()
	var y: float = 0.0
	var course: int = 0
	while y < h:
		var sv: float = -30.0 * float(course % 2)
		var k: int = 0
		while sv < ln:
			var bl: float = 60.0 + 26.0 * h01(seed_i * 7 + course * 13 + k)
			var sa: float = maxf(sv, 0.0)
			var sb: float = minf(sv + bl, ln)
			var tone: float = 0.72 + 0.35 * h01(seed_i * 5 + course * 29 + k * 3)
			_quad(d, [a + dir * sa + Vector3(0, y, 0), a + dir * sb + Vector3(0, y, 0), a + dir * sb + Vector3(0, y + 30.0, 0), a + dir * sa + Vector3(0, y + 30.0, 0)], MORTAR)
			if sb - sa > 4.0:
				_quad(d, [a + dir * (sa + 2.0) + Vector3(0, y + 2.0, 0), a + dir * (sb - 2.0) + Vector3(0, y + 2.0, 0), a + dir * (sb - 2.0) + Vector3(0, y + 28.0, 0), a + dir * (sa + 2.0) + Vector3(0, y + 28.0, 0)], Color(0.52 * tone, 0.45 * tone, 0.38 * tone))
			sv += bl
			k += 1
		y += 30.0
		course += 1

# grit along a joint: tiny grains, darker and lighter, scattered along the line a..b
func _grit(d: CanvasItem, a: Vector3, b: Vector3, seed_i: int) -> void:
	var px: float = _px((a + b) * 0.5)
	if px < 0.35:
		return
	for k in 5:
		var q: Vector3 = a.lerp(b, h01(seed_i * 11 + k))
		var c: Color = Color(0.0, 0.0, 0.0, 0.30) if k % 2 == 0 else Color(_lit(Color(0.75, 0.68, 0.56), q), 0.35)
		d.draw_circle(_proj(q), maxf(0.5, 0.7 * px), c)

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- what moves: the flames and their breath of light, the door, the creatures --------------------------------

# when each creature reaches the doorway, and how shut the door is now (0 open into the room .. 1 shut)
func _build_way() -> void:
	_way.clear()
	var stop_idx: int = 0
	for i in WAY.size() - 1:
		var p0: Vector2 = WAY[maxi(i - 1, 0)]
		var p1: Vector2 = WAY[i]
		var p2: Vector2 = WAY[i + 1]
		var p3: Vector2 = WAY[mini(i + 2, WAY.size() - 1)]
		if i == STOP_AT:
			stop_idx = _way.size()
		for k in 16:
			var u: float = float(k) / 16.0
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
			_way.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = WAY[WAY.size() - 1]
	_way.append(Vector3(last.x, 0.0, last.y))
	_cum.clear()
	_cum.append(0.0)
	for i in range(1, _way.size()):
		_cum.append(_cum[i - 1] + _way[i].distance_to(_way[i - 1]))
	_s_stop = _cum[stop_idx]
	_s_close = _s_stop
	_s_open = _s_stop
	# the door must be shut before a creature comes within its sweep (it swings through the corridor from beyond
	# the doorway, 140 round its hinge), and opens once the creature has crossed away toward the side passage
	for i in _way.size():
		if _way[i].z < -620.0:
			_s_close = _cum[i]
	for i in range(stop_idx, _way.size()):
		if _way[i].x < -60.0:
			_s_open = _cum[i]
			break

func _way_at(sv: float) -> Array:
	sv = clampf(sv, 0.0, _cum[_cum.size() - 1])
	var lo: int = 0
	var hi: int = _cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _cum[mid] <= sv:
			lo = mid
		else:
			hi = mid
	var seg: float = maxf(_cum[hi] - _cum[lo], 0.001)
	return [_way[lo].lerp(_way[hi], (sv - _cum[lo]) / seg), (_way[hi] - _way[lo]).normalized()]

# how far a creature has come, `tau` seconds after it set out: walking, easing to a stop before the doorway,
# standing, easing off again -- its speed never jumps
func _dist(tau: float) -> float:
	var t1: float = (_s_stop - 60.0) / SPEED
	if tau < t1:
		return SPEED * tau
	if tau < t1 + 0.5:
		var u: float = (tau - t1) / 0.5
		return _s_stop - 60.0 + 60.0 * (1.0 - (1.0 - u) * (1.0 - u))
	if tau < t1 + 0.5 + HOLD:
		return _s_stop
	if tau < t1 + 1.0 + HOLD:
		var u2: float = (tau - t1 - 0.5 - HOLD) / 0.5
		return _s_stop + 60.0 * u2 * u2
	return _s_stop + 60.0 + SPEED * (tau - t1 - 1.0 - HOLD)

func _tau_at(sv: float) -> float:
	# the time it reaches distance sv (on the walking stretches)
	var t1: float = (_s_stop - 60.0) / SPEED
	if sv <= _s_stop - 60.0:
		return sv / SPEED
	return t1 + 1.0 + HOLD + maxf(0.0, sv - _s_stop - 60.0) / SPEED

# THE DOOR follows the creatures: it swings shut (out of the corridor, round into the doorway) while the next
# one is still well up the corridor, clear of its sweep, and opens again only once that one has gone on past
func _door_shut() -> float:
	var best: float = 0.0
	var n0: int = int(floor(t / PERIOD))
	for i in range(n0 - 2, n0 + 2):
		var tau: float = t - float(i) * PERIOD
		var tc: float = _tau_at(_s_close)
		var to: float = _tau_at(_s_open)
		best = maxf(best, smoothstep(tc - 1.1, tc, tau) * (1.0 - smoothstep(to, to + 1.1, tau)))
	return best

func _draw_life(d: Control) -> void:
	if _cam.is_empty():
		return
	var full: Vector2 = _cam["full"]
	# the gold glow out of the doorway, as open as the door is: _gold, under this layer
	var shut: float = _door_shut()
	# collect what has depth -- the door, the creatures, the flames -- and draw far to near
	var items: Array = []
	# the gold lies behind the door always. A creature is drawn before the door when it is on the door's FAR
	# side (beyond its plane, as seen from here) and after it when on our side -- the door turns across the
	# corridor, and a creature far down it was drawn over the door, "passing through" it
	_coins(d)
	var plane: Array = _door_plane(shut)
	var behind: Array = []
	var n0: int = int(floor(t / PERIOD)) - 2
	for i in range(n0, n0 + 4):
		var st: Dictionary = _creature_state(i)
		if st.is_empty():
			continue
		var cp: Vector3 = st["p"]
		if (cp - Vector3(plane[0])).dot(plane[1]) < 0.0:
			behind.append([_depth(cp), st])
		else:
			items.append([_depth(cp), 1, st])
	behind.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for bh in behind:
		_creature(d, bh[1])
	# the torches too: one beyond the door's plane is hidden by it (the door swung through them, the user)
	var torches_behind: Array = []
	for k in TORCHES.size():
		var tq: Vector3 = _torch_pos(TORCHES[k])
		if (tq - Vector3(plane[0])).dot(plane[1]) < -6.0:
			torches_behind.append(k)
		else:
			items.append([_depth(tq), 2, k])
	for k2 in torches_behind:
		_torch(d, k2)
	_door(d, shut)
	items.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for it in items:
		match int(it[1]):
			1:
				_creature(d, it[2])
			2:
				_torch(d, int(it[2]))
	# the torch deep in the side passage, seen only through the arch (drawn anywhere, it hung on the solid wall)
	if Geometry2D.is_point_in_polygon(_proj(INNER_TORCH + Vector3(0, 10, 0)), _side_hole()):
		_flame_at(d, INNER_TORCH, 9)
	# dust drifting in the torchlight, and the edges of the view falling into dark
	for k in 20:
		var mp: Vector3 = Vector3(lerpf(-W, W, h01(k + 800)) + 10.0 * sin(t * 0.2 + float(k)), 30.0 + 120.0 * h01(k + 801) + 6.0 * sin(t * 0.15 + float(k) * 2.0), lerpf(0.0, -900.0, h01(k + 802)))
		d.draw_circle(_proj(mp), maxf(0.8, 0.8 * _px(mp)), Color(1.0, 0.85, 0.6, 0.30))
	for side in [0.0, 1.0]:
		var x0: float = side * full.x
		var x1: float = x0 + (full.x * 0.2 if side == 0.0 else -full.x * 0.2)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, full.y), Vector2(x0, full.y)]),
			PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5)]))

# A TORCH'S FLAME: nested tongues that waver in height, width and lean, quick and slow, its glow breathing
# A TORCH IN ITS HOLDER, in 3-D: an iron plate riveted to the wall, an arm out from it, a cup the torch stands
# in (seen from below, as the eye is), the wooden torch, and its flame on top
func _torch(d: CanvasItem, k: int) -> void:
	var tp: Vector3 = _torch_pos(TORCHES[k])
	var sd: float = float(TORCHES[k][0])
	var wx: float = sd * W - sd * 0.6
	var iron: Color = Color(0.20, 0.19, 0.20)
	# the plate on the wall, its rivets
	_quad(d, [Vector3(wx, tp.y - 40.0, tp.z - 6.0), Vector3(wx, tp.y - 40.0, tp.z + 6.0), Vector3(wx, tp.y - 14.0, tp.z + 6.0), Vector3(wx, tp.y - 14.0, tp.z - 6.0)], iron)
	for ry in [-36.0, -18.0]:
		var rp: Vector3 = Vector3(wx - sd * 0.5, tp.y + ry, tp.z)
		d.draw_circle(_proj(rp), maxf(1.0, 1.4 * _px(rp)), _lit(Color(0.6, 0.6, 0.62), rp))
	# the arm: a round iron bar from the plate out and up to the cup, dark with a lit upper edge
	var a0: Vector3 = Vector3(sd * W, tp.y - 30.0, tp.z)
	var a1: Vector3 = tp + Vector3(0, -14.0, 0)
	var w: float = maxf(1.5, 2.6 * _px(tp))
	d.draw_line(_proj(a0), _proj(a1), _lit(iron, a1), w, true)
	d.draw_line(_proj(a0) + Vector2(0, -w * 0.3), _proj(a1) + Vector2(0, -w * 0.3), _lit(Color(0.7, 0.62, 0.52), a1), maxf(1.0, w * 0.35), true)
	# the torch: a wooden handle down through the cup
	var h0: Vector3 = tp + Vector3(0, -26.0, 0)
	d.draw_line(_proj(h0), _proj(tp + Vector3(0, -2.0, 0)), _lit(Color(0.42, 0.26, 0.12), tp), maxf(1.5, 3.2 * _px(tp)), true)
	# the cup: an iron cone, wider at its rim, its underside showing (we look up at it), a lit rim
	var cup: PackedVector2Array = PackedVector2Array()
	var rim: PackedVector2Array = PackedVector2Array()
	for j in 16:
		var a: float = TAU * float(j) / 16.0
		cup.append(_proj(tp + Vector3(cos(a) * 6.5, -4.0, sin(a) * 6.5)))
		cup.append(_proj(tp + Vector3(cos(a) * 3.0, -16.0, sin(a) * 3.0)))
		rim.append(_proj(tp + Vector3(cos(a) * 6.5, -4.0, sin(a) * 6.5)))
	var hull: PackedVector2Array = Geometry2D.convex_hull(cup)
	if hull.size() >= 4:
		hull.remove_at(hull.size() - 1)
		d.draw_colored_polygon(hull, _lit(iron, tp))
	d.draw_polyline(rim + PackedVector2Array([rim[0]]), _lit(Color(0.75, 0.62, 0.45), tp), maxf(1.0, 1.0 * _px(tp)), true)
	_flame(d, k)

func _flame(d: CanvasItem, k: int) -> void:
	_flame_at(d, _torch_pos(TORCHES[k]), k)

func _flame_at(d: CanvasItem, tp: Vector3, k: int) -> void:
	var px: float = _px(tp)
	var base: Vector2 = _proj(tp)
	var tt: float = t + float(k) * 2.3
	var flick: float = 0.5 * sin(tt * 11.0) + 0.3 * sin(tt * 17.3 + 1.0) + 0.2 * sin(tt * 4.1)
	for g in 14:
		d.draw_circle(base + Vector2(0, -8.0 * px), 90.0 * px * (1.0 - float(g) / 14.0), Color(1.0, 0.62, 0.26, 0.022 * (0.9 + 0.1 * flick)))
	var sway: float = (2.6 * sin(tt * 3.1) + 1.4 * sin(tt * 9.7)) * px
	var hgt: float = (24.0 + 5.0 * flick + 2.0 * sin(tt * 23.0)) * px
	for layer_i in 3:
		var kk: float = 1.0 - 0.28 * float(layer_i)
		var col: Color = [Color(1.0, 0.45, 0.10, 0.85), Color(1.0, 0.78, 0.30), Color(1.0, 0.97, 0.86)][layer_i]
		var w: float = 7.0 * kk * px
		var tip: Vector2 = base + Vector2(sway * kk, -hgt * kk)
		var pts: PackedVector2Array = PackedVector2Array()
		for s2 in 9:
			var a: float = PI * float(s2) / 8.0
			pts.append(base + Vector2(-cos(a) * w, sin(a) * w * 0.6))
		for s3 in 7:
			var f: float = float(s3) / 6.0
			pts.append(base.lerp(tip, f) + Vector2(w * (1.0 - f) * (1.0 - f) + sin(f * PI) * sway * 0.5 * kk, 0.0))
			pts.append(base.lerp(tip, f) + Vector2(-w * (1.0 - f) * (1.0 - f) + sin(f * PI) * sway * 0.5 * kk, 0.0))
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		if hull.size() >= 4:
			hull.remove_at(hull.size() - 1)
			d.draw_colored_polygon(hull, col)

# THE DOOR: a slab of planks bound in iron, hung on a hinge at the doorway's far side; open it stands into
# the room square to the wall, shut it lies across the doorway -- turning about the hinge in 3-D, its face,
# its edge and its iron all following
# the door's plane now: a point on it and its normal turned toward the eye
func _door_plane(shut: float) -> Array:
	var hinge: Vector3 = Vector3(W - 4.5 - 1.0, 0.0, DOOR_Z0)
	var ang: float = PI * (1.0 - shut)
	var along: Vector3 = Vector3(-sin(ang), 0.0, cos(ang))
	var n: Vector3 = along.cross(Vector3.UP).normalized()
	if n.dot(Vector3(_cam["eye"]) - hinge) < 0.0:
		n = -n
	return [hinge, n]

func _door(d: CanvasItem, shut: float) -> void:
	# hinged at the doorway's FAR side: open it lies back along the corridor wall beyond the doorway, out of the
	# way; as a creature comes it swings FORWARD through the corridor and shuts the doorway in front of the gold
	var thick: float = 9.0
	var hinge: Vector3 = Vector3(W - thick * 0.5 - 1.0, 0.0, DOOR_Z0)
	var ang: float = PI * (1.0 - shut)                           # 0: shut (pointing +z, over the doorway); PI: open (along the wall beyond)
	var along: Vector3 = Vector3(-sin(ang), 0.0, cos(ang))
	var width: float = DOOR_Z1 - DOOR_Z0
	var out_n: Vector3 = along.cross(Vector3.UP).normalized()     # the face toward the corridor side
	if out_n.x > 0.0:
		out_n = -out_n
	var up: Vector3 = Vector3.UP * (DOOR_H - 4.0)
	var a: Vector3 = hinge + Vector3(0.0, 2.0, 0.0)
	var b: Vector3 = a + along * (width - 4.0)
	var eye: Vector3 = _cam["eye"]
	# the face we see: the one turned toward the camera
	var face_n: Vector3 = out_n if out_n.dot(eye - (a + b) * 0.5) > 0.0 else -out_n
	var fo: Vector3 = face_n * thick * 0.5
	# its edge (the free end), when it shows
	var edge_n: Vector3 = along
	if edge_n.dot(eye - b) > 0.0:
		_quad(d, [b + fo, b - fo, b - fo + up, b + fo + up], Color(0.30, 0.18, 0.09))
	# the top edge
	_quad(d, [a + fo + up, b + fo + up, b - fo + up, a - fo + up], Color(0.34, 0.21, 0.10))
	# the face: planks, each its own tone, a dark seam between
	var planks: int = 5
	for k in planks:
		var u0: float = float(k) / float(planks)
		var u1: float = float(k + 1) / float(planks)
		var tone: float = 0.85 + 0.25 * h01(k + 40)
		var p0: Vector3 = a.lerp(b, u0) + fo
		var p1: Vector3 = a.lerp(b, u1) + fo
		_quad(d, [p0, p1, p1 + up, p0 + up], Color(0.50 * tone, 0.30 * tone, 0.15 * tone))
		d.draw_line(_proj(p0), _proj(p0 + up), Color(0.06, 0.03, 0.01, 0.9), maxf(1.5, 2.2 * _px(p0)))
		# the grain along the plank
		for g in 3:
			var gu: float = lerpf(u0, u1, 0.25 + 0.25 * float(g))
			var g0: Vector3 = a.lerp(b, gu) + fo + Vector3.UP * DOOR_H * 0.05
			d.draw_line(_proj(g0), _proj(g0 + up * 0.9 + along * 3.0 * sin(float(g + k))), Color(0.18, 0.09, 0.03, 0.35), 1.0, true)
	# iron bands across it, with studs
	for by in [0.18, 0.5, 0.82]:
		var y0: float = DOOR_H * float(by)
		var b0: Vector3 = a + fo + face_n * 0.5 + Vector3.UP * y0
		var b1: Vector3 = b + fo + face_n * 0.5 + Vector3.UP * y0
		_quad(d, [b0 - Vector3.UP * 6.0, b1 - Vector3.UP * 6.0, b1 + Vector3.UP * 6.0, b0 + Vector3.UP * 6.0], Color(0.16, 0.16, 0.18))
		d.draw_line(_proj(b0 + Vector3.UP * 6.0), _proj(b1 + Vector3.UP * 6.0), _lit(Color(0.7, 0.7, 0.72), b0), 1.0, true)
		for s in 5:
			var sp: Vector3 = b0.lerp(b1, (float(s) + 0.5) / 5.0)
			var pr: float = 2.6 * _px(sp)
			d.draw_circle(_proj(sp), pr, _lit(Color(0.30, 0.30, 0.32), sp))
			d.draw_circle(_proj(sp) + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.4, _lit(Color(0.9, 0.9, 0.9), sp))
	# THE HINGES: iron knuckles on the jamb at the door's near edge, a strap from each across the door's face
	for hy in [24.0, 76.0, 128.0]:
		# the knuckle sits on the hinge's axis, the door's edge, and turns with nothing: it is the axis
		var hk: Vector3 = hinge + Vector3(0.0, hy, 0.0) + fo
		var kp0: Vector2 = _proj(hk + Vector3(0, -10, 0))
		var kp1: Vector2 = _proj(hk + Vector3(0, 10, 0))
		var kw: float = maxf(2.0, 4.5 * _px(hk))
		d.draw_line(kp0, kp1, _lit(Color(0.20, 0.20, 0.22), hk), kw)
		d.draw_line(kp0 + Vector2(-kw * 0.25, 0), kp1 + Vector2(-kw * 0.25, 0), _lit(Color(0.75, 0.75, 0.78), hk), maxf(1.0, kw * 0.3))
		var s0: Vector3 = a + fo + face_n * 0.6 + Vector3.UP * hy
		_quad(d, [s0 - Vector3.UP * 5.0, s0 + along * width * 0.45 - Vector3.UP * 4.0, s0 + along * width * 0.45 + Vector3.UP * 4.0, s0 + Vector3.UP * 5.0], Color(0.14, 0.14, 0.16))
	# a ring handle near the free end
	var hp: Vector3 = a.lerp(b, 0.85) + fo + face_n * 2.0 + Vector3.UP * DOOR_H * 0.45
	d.draw_arc(_proj(hp), 6.0 * _px(hp), 0.0, TAU, 20, _lit(Color(0.5, 0.5, 0.52), hp), maxf(1.0, 1.6 * _px(hp)), true)

# where a creature is at time t, its heading and its stride: out of the dark at the far end, down the
# corridor, slowing at the shut doorway with its head turned to the door, on toward us, round into the side
# passage on the left
func _creature_state(i: int) -> Dictionary:
	var tau: float = t - float(i) * PERIOD
	if tau < 0.0:
		return {}
	var dist: float = _dist(tau)
	var at: Array = _way_at(dist)
	var p: Vector3 = at[0]
	var heading: Vector3 = at[1]
	# standing at the shut door it turns to face it, then turns away to go on -- eased both ways
	var t1: float = (_s_stop - 60.0) / SPEED
	var face: float = smoothstep(t1 + 0.4, t1 + 0.9, tau) * (1.0 - smoothstep(t1 + 0.5 + HOLD - 0.3, t1 + 0.9 + HOLD, tau))
	# by ANGLE: from its approach to facing the door, then round (through facing us) to the way out
	var a_path: float = atan2(heading.z, heading.x)
	var a_door: float = atan2(-0.10, 1.0)
	var ang: float = lerp_angle(a_path, a_door, face)
	heading = Vector3(cos(ang), 0.0, sin(ang))
	var alpha: float = clampf(dist / 120.0, 0.0, 1.0)
	# into the side passage it goes into the dark, and is gone before any of it would be where the wall beyond
	# the arch hides it (it was drawn whole there: "they pass through the wall")
	if p.x < -W + 20.0:
		alpha *= clampf(1.0 - (-p.x - W + 20.0) / 34.0, 0.0, 1.0)
	if alpha <= 0.0 or dist >= _cum[_cum.size() - 1]:
		return {}
	return {"p": p, "h": heading, "dist": dist, "a": alpha, "look": 0.0, "i": i}

# ONE CREATURE, a 3-D model: an armored shell (an ellipsoid), a head with horns sweeping back, amber slit eyes
# glowing, two fangs, four legs a side scuttling with their feet planted while they push
func _creature(d: CanvasItem, st: Dictionary) -> void:
	var p: Vector3 = st["p"]
	var f: Vector3 = st["h"]
	var s: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = Vector3.UP
	var alpha: float = st["a"]
	var dist: float = st["dist"]
	var idx: int = st["i"]
	var L: float = 46.0
	var body_c: Vector3 = p + u * L * 0.28
	var head_dir: Vector3 = f.rotated(Vector3.UP, -0.9 * float(st["look"]))   # toward the door, on the right
	var head_c: Vector3 = body_c + f * L * 0.42 + u * L * 0.02
	# its shadow
	var sh: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		sh.append(_proj(p + f * cos(a) * L * 0.55 + s * sin(a) * L * 0.42))
	if Geometry2D.triangulate_polygon(sh).size() > 0:
		d.draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * alpha))
	# legs: four a side, alternating, feet planted while they push
	var stride: float = 22.0
	for sd in [-1.0, 1.0]:
		for li in 4:
			var ph: float = 0.0 if (li % 2 == 0) == (sd > 0.0) else 0.5
			var cyc: float = fposmod(dist / stride + ph + float(idx) * 0.17, 1.0)
			var rel: float = 0.0
			var lift: float = 0.0
			var amp: float = stride * 0.6
			if cyc < 0.6:
				rel = amp * (0.5 - cyc / 0.6)
			else:
				var w: float = (cyc - 0.6) / 0.4
				rel = amp * (-0.5 + smoothstep(0.0, 1.0, w))
				lift = sin(w * PI) * 8.0
			var along: float = lerpf(0.30, -0.30, float(li) / 3.0) * L
			var hip: Vector3 = body_c + f * along + s * sd * L * 0.26
			var foot: Vector3 = p + f * (along * 1.3 + rel) + s * sd * L * 0.66 + Vector3.UP * lift
			var knee: Vector3 = hip.lerp(foot, 0.4) + Vector3.UP * L * 0.30 + s * sd * L * 0.06
			var leg_col: Color = Color(_lit(SHELL, knee), alpha)
			d.draw_line(_proj(hip), _proj(knee), leg_col, maxf(1.0, 3.0 * _px(knee)), true)
			d.draw_line(_proj(knee), _proj(foot), leg_col, maxf(1.0, 2.2 * _px(knee)), true)
	# the shell
	_ellipsoid(d, body_c - f * L * 0.05, f, s, u, L * 0.40, L * 0.30, L * 0.22, SHELL, alpha)
	# its plates: two dark bands and a ridge along its back
	for bd in [-0.10, 0.12]:
		var bp: PackedVector2Array = PackedVector2Array()
		for k in 9:
			var a2: float = PI * float(k) / 8.0
			bp.append(_proj(body_c + f * L * float(bd) + s * cos(a2) * L * 0.29 + u * sin(a2) * L * 0.21))
		d.draw_polyline(bp, Color(0.05, 0.03, 0.06, 0.8 * alpha), maxf(1.0, 2.0 * _px(body_c)), true)
	# the head
	var hs: Vector3 = head_dir.cross(Vector3.UP).normalized()
	_ellipsoid(d, head_c, head_dir, hs, u, L * 0.18, L * 0.20, L * 0.15, SHELL.lightened(0.05), alpha)
	# horns sweeping back from the crown
	for sd2 in [-1.0, 1.0]:
		var root: Vector3 = head_c + u * L * 0.10 + hs * sd2 * L * 0.10
		var mid: Vector3 = root + u * L * 0.22 + hs * sd2 * L * 0.12 - head_dir * L * 0.08
		var tip: Vector3 = mid + u * L * 0.10 + hs * sd2 * L * 0.04 - head_dir * L * 0.26
		var hc: Color = Color(_lit(Color(0.70, 0.62, 0.50), mid), alpha)
		d.draw_line(_proj(root), _proj(mid), hc, maxf(1.0, 3.0 * _px(root)), true)
		d.draw_line(_proj(mid), _proj(tip), hc, maxf(1.0, 1.8 * _px(root)), true)
	# the eyes: amber slits slanting into a scowl, glowing (only from the front -- they face along head_dir)
	var eye_pos: Vector3 = _cam["eye"]
	if head_dir.dot(eye_pos - head_c) > 0.0:
		for sd3 in [-1.0, 1.0]:
			var ep: Vector3 = head_c + head_dir * L * 0.16 + hs * sd3 * L * 0.08 + u * L * 0.04
			var sp: Vector2 = _proj(ep)
			var pr: float = L * 0.05 * _px(ep)
			for g in 6:
				d.draw_circle(sp, pr * (3.0 - 0.35 * float(g)), Color(EYE, 0.05 * alpha))
			var slant: float = -0.45 * sd3 * (1.0 if hs.x < 0.0 else -1.0)
			d.draw_set_transform(sp, slant, Vector2(1.0, 0.45))
			d.draw_circle(Vector2.ZERO, pr * 1.3, Color(EYE, alpha))
			d.draw_circle(Vector2.ZERO, pr * 0.5, Color(0.25, 0.08, 0.02, alpha))
			d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# fangs, curving down
		for sd4 in [-1.0, 1.0]:
			var fr: Vector3 = head_c + head_dir * L * 0.17 + hs * sd4 * L * 0.05 - u * L * 0.08
			var ft: Vector3 = fr - u * L * 0.10 + head_dir * L * 0.03 - hs * sd4 * L * 0.02
			d.draw_line(_proj(fr), _proj(ft), Color(0.92, 0.88, 0.78, alpha), maxf(1.0, 2.0 * _px(fr)), true)

# an ellipsoid: silhouette as the hull of its principal sections, lit by the torchlight there, a gloss of
# light along its upper side
func _ellipsoid(d: CanvasItem, c: Vector3, f: Vector3, s: Vector3, u: Vector3, rf: float, rs: float, ru: float, col: Color, alpha: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		pts.append(_proj(c + f * cos(a) * rf + s * sin(a) * rs))
		pts.append(_proj(c + f * cos(a) * rf + u * sin(a) * ru))
		pts.append(_proj(c + s * cos(a) * rs + u * sin(a) * ru))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() < 4:
		return
	hull.remove_at(hull.size() - 1)
	if Geometry2D.triangulate_polygon(hull).size() == 0:
		return
	var lit_c: Color = _lit(col, c + u * ru)
	d.draw_colored_polygon(hull, Color(lit_c.darkened(0.35), alpha))
	# graded toward the top: inner layers, lighter, nudged up
	var px: float = _px(c)
	var sp: Vector2 = _proj(c)
	for k in 6:
		var fk: float = float(k + 1) / 7.0
		var inner: PackedVector2Array = PackedVector2Array()
		for p2 in hull:
			inner.append(sp + (p2 - sp) * (1.0 - 0.55 * fk) + Vector2(0.0, -ru * px * 0.35 * fk))
		d.draw_colored_polygon(inner, Color(lit_c.lerp(lit_c.lightened(0.5), fk), alpha * 0.45))
	d.draw_circle(sp + Vector2(-rs * px * 0.2, -ru * px * 0.6), maxf(1.0, rs * px * 0.15), Color(1.0, 0.85, 0.6, 0.45 * alpha))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Detour", "Don't allow the monsters to reach their goals", Color(1.0, 0.82, 0.48), Color(0.10, 0.04, 0.02),
		Color(1.0, 0.6, 0.2, 0.25))
