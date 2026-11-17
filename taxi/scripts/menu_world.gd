extends "res://scripts/menu_poster.gd"

# TAXI'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): THE TAXI STATION ON A CITY
# AVENUE AT NIGHT, ALL IN 3-D (one camera, `_proj`, standing on the sidewalk): the avenue running away
# between office blocks whose windows are lit here and dark there, street lamps down both sides with their
# pools of light, the asphalt wet so every light lies on it in a long streak, the city's glow at the far end.
# In the near right is YOUR STATION: its garage open and lit, a neon TAXI sign over the forecourt breathing
# softly, a fuel pump on its island. Yellow cabs -- real boxes in 3-D: a body, a cabin with glass, a lit roof
# sign, wheels, headlights in front and red lights behind -- drive both ways down the avenue; and one at a
# time comes up from behind us, turns into the station, waits at the pump with its roof sign lit, then pulls
# out and is away into the city. Everything follows one clock (`t`): no jumps, no pops. Made up, never the board.

const ROAD: float = 110.0            # the roadway's half width
const WALK: float = 46.0             # a sidewalk's width
const FAR: float = -3200.0
const YELLOW: Color = Color(0.99, 0.80, 0.16)
const LANE_GAP: float = 2.6          # seconds between cabs in a lane
const LANE_SPEED: float = 300.0
const STATION_PERIOD: float = 13.0   # the station's own cab: in, waits, out
const LAMPS: Array = [-200.0, -650.0, -1100.0, -1550.0, -2000.0, -2450.0]

var _lights: Array = []             # [position, color, radius] of every light in the scene
var _city: Control = null
var _life: Control = null
var _cam: Dictionary = {}
var _for_bottom: float = -2.0

# NEVER HOLD THE MENU UP (it took "a lot of time to enter the main on first run"): the sky, the road, the
# station and the lamps are drawn at once; the blocks -- most of the work -- each have a layer of their own,
# stacked far to near, rendered a few a frame INSIDE ONE INVISIBLE GROUP, and when all are done the whole city
# fades in together (block by block, each fading in, was "a bit disturbing")
var _blocks: Array = []              # [side, z0, z1, height, seed] far to near on each side
var _block_layers: Array = []
var _revealed: int = 0
# THE CITY IS A PICTURE SHIPPED WITH THE GAME (the user: "can the buildings just be stored in a small jpg?"): the
# blocks never change and the layouts only slide them up or down (the camera's center), so they are rendered once
# by devtools/make_menu_bake.gd into BAKED_CITY, drawn centered on BAKE_CY, and here drawn at once, slid into place
const BAKED_CITY: String = "res://taxi/art/menu_city.webp"
const BAKE_W: int = 680
const BAKE_H: int = 1500
const BAKE_CY: float = 750.0
var _city_tex: Texture2D = null
var _city_img_layer: Control = null
# THE WHOLE STILL SCENE IS THE PICTURE: sky, road, blocks, lamp posts -- and the cab station, built in real 3-D
# (taxi/scripts/menu_station3d.gd: the user wanted the pumps, "including the entire gas station", made "super
# perfect" and saved with the rest) and rendered at twice the size for clean edges. At run time only what moves is
# drawn: the cabs, the lamps' glow, the neon's breath.
const STATION3D: String = "res://taxi/scripts/menu_station3d.gd"
var _station_vp: SubViewport = null
var _blocks_root: Control = null
var _city_alpha: float = 0.0
var _front: Control = null

func _setup() -> void:
	_build_lights()
	if not bake_mode and ResourceLoader.exists(BAKED_CITY):
		_city_tex = load(BAKED_CITY)
		_city_img_layer = _mk(func(d: Control) -> void:
			if _city_tex != null and not _cam.is_empty():
				d.draw_texture(_city_tex, Vector2(0.0, Vector2(_cam["center"]).y - BAKE_CY)))
		_life = _mk(func(d: Control) -> void: _draw_life(d))
		return
	if bake_mode:
		_cam = _camera()
	_city = _mk(func(d: Control) -> void: _draw_city(d))
	for side in [-1.0, 1.0]:
		var zz: float = 300.0 if side < 0.0 else -560.0
		var k2: int = 0
		var one_side: Array = []
		while zz > FAR + 300.0:
			var depth_b: float = 180.0 + 160.0 * h01(k2 * 7 + int(side * 3.0) + 10)
			var hgt: float = 260.0 + 520.0 * h01(k2 * 5 + int(side * 3.0) + 11)
			one_side.append([side, zz, zz - depth_b, hgt, k2 * 31 + int(side * 7.0)])
			zz -= depth_b + 18.0
			k2 += 1
		# FAR TO NEAR: a nearer block covers the end of the one behind it
		one_side.reverse()
		_blocks.append_array(one_side)
	_blocks_root = Control.new()
	_blocks_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocks_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocks_root.modulate = Color(1, 1, 1, 0)
	add_child(_blocks_root)
	for bk in _blocks:
		var blk: Control = Control.new()
		blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blk.set_anchors_preset(Control.PRESET_FULL_RECT)
		blk.draw.connect(func() -> void: _block(blk, bk[0], bk[1], bk[2], bk[3], bk[4]))
		blk.visible = false
		_blocks_root.add_child(blk)
		_block_layers.append(blk)
	if bake_mode:
		# the baking tool: every block at once; over them the 3-D station (rendered at twice the size), then the
		# lamp posts
		_blocks_root.modulate = Color(1, 1, 1, 1)
		for bl2 in _block_layers:
			(bl2 as Control).visible = true
		_station_vp = _station_3d()
		_mk(func(d: Control) -> void:
			if _station_vp != null:
				d.draw_texture_rect(_station_vp.get_texture(), Rect2(0, 0, BAKE_W, BAKE_H), false))
		_mk(func(d: Control) -> void: _draw_poles(d))
		return
	_front = _mk(func(d: Control) -> void: _draw_front(d))
	_life = _mk(func(d: Control) -> void: _draw_life(d))

func _mk(fn: Callable) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

# --- the camera ------------------------------------------------------------------------------------------

func _camera() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 230.0 if mobile else 150.0
	# turned toward the station on the right: it is the poster's subject
	var eye: Vector3 = Vector3(-40.0, 78.0, 340.0)
	var target: Vector3 = Vector3(130.0, 44.0, -700.0)
	var f: Vector3 = (target - eye).normalized()
	var r: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = r.cross(f)
	var center: Vector2 = Vector2(full.x * 0.5, top + (bottom - top) * 0.50)
	if bake_mode:
		full = Vector2(BAKE_W, BAKE_H)
		center = Vector2(float(BAKE_W) * 0.5, BAKE_CY)
	return {"eye": eye, "f": f, "r": r, "u": u, "focal": float(BAKE_W) * 0.95, "full": full, "bottom": bottom,
		"center": center}

func _proj(p: Vector3) -> Vector2:
	var v: Vector3 = p - _cam["eye"]
	var z: float = maxf(v.dot(_cam["f"]), 1.0)
	return Vector2(_cam["center"]) + Vector2(v.dot(_cam["r"]), -v.dot(_cam["u"])) * float(_cam["focal"]) / z

func _px(p: Vector3) -> float:
	return float(_cam["focal"]) / maxf((p - _cam["eye"]).dot(_cam["f"]), 1.0)

func _depth(p: Vector3) -> float:
	return (p - _cam["eye"]).dot(_cam["f"])

func _visible(p: Vector3) -> bool:
	return _depth(p) > 30.0

func _tick(delta: float) -> void:
	_cam = _camera()
	if bake_mode:
		return
	if _city_tex != null:
		if absf(scene_bottom - _for_bottom) > 0.5:
			_for_bottom = scene_bottom
			_city_img_layer.queue_redraw()
		_life.queue_redraw()
		return
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		_city.queue_redraw()
		_front.queue_redraw()
		for bl in _block_layers:
			if (bl as Control).visible:
				(bl as Control).queue_redraw()
	# a few more blocks a frame, out of sight in their group; once every one has been drawn, the city fades in
	for _n in 3:
		if _revealed < _block_layers.size():
			(_block_layers[_revealed] as Control).visible = true
			_revealed += 1
	if _revealed >= _block_layers.size() and _city_alpha < 1.0:
		_city_alpha = fade_in(true, _city_alpha, delta)
		_blocks_root.modulate = Color(1, 1, 1, _city_alpha)
	_life.queue_redraw()

# THE LIGHT AT A POINT (the user: "all is still flat"): the night's ambient, darker away from the city's glow,
# plus every light in the scene by its distance -- the street lamps, the canopy's lights, the garage, the shop
# window, the neon. Every opaque surface is lit by it at each corner, so it shades across itself.
func _build_lights() -> void:
	_lights.clear()
	for lz in LAMPS:
		for side in [-1.0, 1.0]:
			_lights.append([Vector3(side * (ROAD + 10.0) - side * 30.0, 148.0, float(lz) - (60.0 if side > 0.0 else 0.0)), Color(1.0, 0.72, 0.42), 95.0])
	for lx in [ROAD + WALK + 60.0, (ROAD + WALK + 30.0 + ST_BACK - 50.0) * 0.5, ST_BACK - 80.0]:
		for lz in [PUMP_Z + 120.0, PUMP_Z, PUMP_Z - 140.0]:
			_lights.append([Vector3(lx, 104.0, lz), Color(0.80, 0.88, 1.0), 70.0])
	_lights.append([Vector3(ST_BACK + 40.0, 50.0, -215.0), Color(1.0, 0.80, 0.50), 110.0])
	_lights.append([Vector3(ST_BACK + 30.0, 50.0, -440.0), Color(1.0, 0.88, 0.66), 80.0])
	_lights.append([Vector3(ROAD + WALK + 26.0, 129.0, -230.0), Color(1.0, 0.82, 0.30), 70.0])

func _light(p: Vector3) -> Color:
	var col: Color = Color(0.10, 0.10, 0.17)
	col += Color(0.20, 0.09, 0.09) * clampf((-p.z - 600.0) / 2400.0, 0.0, 1.0)
	for lt in _lights:
		var dd: float = p.distance_to(lt[0])
		if dd > float(lt[2]) * 6.0:
			continue
		# a tight falloff: a pool round each light, not a wash over the whole street
		col += Color(lt[1]) * (1.0 / pow(1.0 + pow(dd / float(lt[2]), 2.0), 1.5))
	return Color(minf(col.r, 1.4), minf(col.g, 1.3), minf(col.b, 1.3))

const GAIN: float = 1.25

func _lit(base: Color, p: Vector3) -> Color:
	var l: Color = _light(p)
	return Color(minf(base.r * l.r * GAIN, 1.0), minf(base.g * l.g * GAIN, 1.0), minf(base.b * l.b * GAIN, 1.0), base.a)

# a surface: lit per corner (a see-through overlay -- a glow, a shadow, a sheen -- is drawn as given)
func _quad(d: CanvasItem, pts: Array, col: Color) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	var cc: PackedColorArray = PackedColorArray()
	for p in pts:
		if not _visible(p):
			return
		q.append(_proj(p))
		cc.append(col if col.a < 1.0 else _lit(col, p))
	if Geometry2D.triangulate_polygon(q).size() > 0:
		d.draw_polygon(q, cc)

# something that gives light (a lit window, a lens, a sign): drawn in its own color
func _equad(d: CanvasItem, pts: Array, col: Color) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	for p in pts:
		if not _visible(p):
			return
		q.append(_proj(p))
	if Geometry2D.triangulate_polygon(q).size() > 0:
		d.draw_colored_polygon(q, col)

func _quad_c(d: CanvasItem, pts: Array, cols: Array) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	var cc: PackedColorArray = PackedColorArray()
	for k in pts.size():
		if not _visible(pts[k]):
			return
		q.append(_proj(pts[k]))
		cc.append(cols[k])
	if Geometry2D.triangulate_polygon(q).size() > 0:
		d.draw_polygon(q, cc)

# --- the city, drawn once ---------------------------------------------------------------------------------

func _draw_city(d: Control) -> void:
	if _cam.is_empty():
		_cam = _camera()
	var full: Vector2 = _cam["full"]
	# the night sky, the city's glow low down at the far end
	var hz: float = _proj(Vector3(0, 0, FAR)).y
	d.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(full.x, 0), Vector2(full.x, hz), Vector2(0, hz)]),
		PackedColorArray([Color(0.03, 0.04, 0.10), Color(0.03, 0.04, 0.10), Color(0.30, 0.18, 0.22), Color(0.30, 0.18, 0.22)]))
	var vp: Vector2 = _proj(Vector3(0, 60, FAR))
	for k in 18:
		d.draw_circle(vp, full.x * 0.6 * (1.0 - float(k) / 18.0), Color(1.0, 0.55, 0.35, 0.02))
	# far skyline across the end of the avenue
	for k in 16:
		var bx: float = lerpf(-900.0, 900.0, float(k) / 15.0)
		var bh: float = 300.0 + 500.0 * h01(k + 200)
		_quad(d, [Vector3(bx - 60.0, 0, FAR - 200.0), Vector3(bx + 60.0, 0, FAR - 200.0), Vector3(bx + 60.0, bh, FAR - 200.0), Vector3(bx - 60.0, bh, FAR - 200.0)], Color(0.07, 0.07, 0.13))
	# THE ROAD: wet asphalt, darker near, a sheen toward the glow; sidewalks with curbs
	# the road in strips, so the lamps' light falls on it in pools
	var rz: float = 400.0
	while rz > FAR:
		var rz1: float = rz - (40.0 if rz > -800.0 else 160.0)
		for rxk in 4:
			var rx0: float = lerpf(-ROAD, ROAD, float(rxk) / 4.0)
			var rx1: float = lerpf(-ROAD, ROAD, float(rxk + 1) / 4.0)
			_quad(d, [Vector3(rx0, 0, rz), Vector3(rx1, 0, rz), Vector3(rx1, 0, rz1), Vector3(rx0, 0, rz1)], Color(0.20, 0.19, 0.22))
		rz = rz1
	for side in [-1.0, 1.0]:
		var x0: float = side * ROAD
		var x1: float = side * (ROAD + WALK)
		_quad(d, [Vector3(x0, 0, 400), Vector3(x0, 4, 400), Vector3(x0, 4, FAR), Vector3(x0, 0, FAR)], Color(0.30, 0.30, 0.34))
		var wz: float = 400.0
		while wz > FAR:
			var wz1: float = wz - (40.0 if wz > -800.0 else 160.0)
			_quad(d, [Vector3(x0, 4, wz), Vector3(x1, 4, wz), Vector3(x1, 4, wz1 + 1.5), Vector3(x0, 4, wz1 + 1.5)], Color(0.40, 0.38, 0.40))
			wz = wz1
	# lane marks: a dashed center line
	var z: float = 380.0
	while z > FAR:
		_quad(d, [Vector3(-2.5, 0.3, z), Vector3(2.5, 0.3, z), Vector3(2.5, 0.3, z - 40.0), Vector3(-2.5, 0.3, z - 40.0)], Color(0.80, 0.78, 0.70, 0.55))
		z -= 90.0
	# (the blocks have their own layers, over this one; the station and the lamps are over them)

func _draw_front(d: Control) -> void:
	if _cam.is_empty():
		_cam = _camera()
	_station(d)
	_draw_poles(d)

func _draw_poles(d: Control) -> void:
	# the street lamps' poles and arms (their light is in the live layer)
	for lz in LAMPS:
		for side in [-1.0, 1.0]:
			var base: Vector3 = Vector3(side * (ROAD + 10.0), 4.0, float(lz) - (60.0 if side > 0.0 else 0.0))
			var top_p: Vector3 = base + Vector3(0, 150, 0)
			if not _visible(base):
				continue
			# the pole: a round post, shaded across (lit on the road's side by the lamps' glow), tapering up
			_pole(d, base, top_p, 3.2, 2.2, Color(0.20, 0.20, 0.24))
			# the arm out over the road, and the lamp head on it: a shallow housing, a lens under it
			var head: Vector3 = top_p + Vector3(-side * 30.0, 6, 0)
			_pole(d, top_p + Vector3(0, -2, 0), head, 1.8, 1.6, Color(0.20, 0.20, 0.24))
			_lamp_head(d, head)

# ONE BLOCK, BUILT IN DEPTH (the user: flat buildings): its face to the avenue in brick-toned courses, every
# window a RECESS -- the glass set back, the reveal on its far side showing, the lintel's underside showing above
# the eye and the sill's top below it, a sill standing out under it; string courses standing out between floors;
# a parapet on the roof; at street level shopfronts recessed behind their glass with the lit interior's back
# wall, a sloping awning standing out over each and a lit sign box
# A WINDOW'S GLASS from a to b (its bottom edge), h high. LIT: a room behind it -- brighter up toward its ceiling
# light, a window bar across, now and then a blind half down or a curtain, and its glow spilling onto the wall
# round it. DARK: the glass reflecting the night sky, lighter low down from the street
func _pane(d: CanvasItem, a: Vector3, b: Vector3, h: float, col: Color, lit: bool, seed_i: int, _out_n: Vector3) -> void:
	if not (_visible(a) and _visible(b)):
		return
	var up: Vector3 = Vector3(0, h, 0)
	var q: PackedVector2Array = PackedVector2Array([_proj(a), _proj(b), _proj(b + up), _proj(a + up)])
	if Geometry2D.triangulate_polygon(q).size() == 0:
		return
	if lit:
		var top_c: Color = col.lightened(0.25)
		var bot_c: Color = col.darkened(0.35)
		d.draw_polygon(q, PackedColorArray([bot_c, bot_c, top_c, top_c]))
		var kind: float = h01(seed_i + 3)
		if kind < 0.3:
			# a blind part way down
			var bl: float = 0.3 + 0.4 * h01(seed_i + 5)
			_equad(d, [a + up * (1.0 - bl), b + up * (1.0 - bl), b + up, a + up], col.darkened(0.45))
			for k in 4:
				var ly: float = 1.0 - bl * float(k) / 4.0
				d.draw_line(_proj(a + up * ly), _proj(b + up * ly), Color(0, 0, 0, 0.25), 1.0)
		elif kind < 0.5:
			# a curtain drawn to one side
			_equad(d, [a, a.lerp(b, 0.3), a.lerp(b, 0.22) + up, a + up], col.darkened(0.5))
	else:
		d.draw_polygon(q, PackedColorArray([Color(0.14, 0.13, 0.18), Color(0.14, 0.13, 0.18), Color(0.04, 0.05, 0.10), Color(0.04, 0.05, 0.10)]))
	# the window bar and the frame's edge
	d.draw_line(_proj(a.lerp(b, 0.5)), _proj(a.lerp(b, 0.5) + up), Color(0.05, 0.04, 0.04, 0.8), maxf(1.0, 0.8 * _px(a)))
	d.draw_line(_proj(a + up * 0.55), _proj(b + up * 0.55), Color(0.05, 0.04, 0.04, 0.6), maxf(1.0, 0.6 * _px(a)))

func _block(d: CanvasItem, side: float, z0: float, z1: float, hgt: float, seed_i: int) -> void:
	var x: float = side * (ROAD + WALK)
	var inward: float = side                 # into the building is away from the avenue
	var tone: float = 0.8 + 0.4 * h01(seed_i)
	var face: Color = [Color(0.30, 0.20, 0.17), Color(0.26, 0.25, 0.28), Color(0.32, 0.28, 0.22)][seed_i % 3]
	face = Color(face.r * tone, face.g * tone, face.b * tone)
	var eye: Vector3 = _cam["eye"]
	# the face, lighter low down where the street lights reach it
	# the face in panels, each lit at its corners, so the lamps' light lies on it and the top goes into the night
	var py0: float = 0.0
	while py0 < hgt:
		var py1: float = minf(py0 + 60.0, hgt)
		var pz: float = z0
		while pz > z1:
			var pz1: float = maxf(pz - 80.0, z1)
			_quad(d, [Vector3(x, py0, pz), Vector3(x, py0, pz1), Vector3(x, py1, pz1), Vector3(x, py1, pz)], face)
			pz = pz1
		py0 = py1
	# its near end, facing us, darker
	var ey0: float = 0.0
	while ey0 < hgt:
		var ey1: float = minf(ey0 + 60.0, hgt)
		for ek in 4:
			var ex_a: float = x + side * 75.0 * float(ek)
			_quad(d, [Vector3(ex_a, ey0, z0), Vector3(ex_a + side * 75.0, ey0, z0), Vector3(ex_a + side * 75.0, ey1, z0), Vector3(ex_a, ey1, z0)], face.darkened(0.25))
		ey0 = ey1
	# the near end's windows too (a taller block rises behind a shorter one, and its end stood bare): recessed
	# into the end face, the soffit showing above the eye and the sill below
	var end_bays: int = 8
	var floors_e: int = int((hgt - 50.0) / 34.0)
	for fl in floors_e:
		var ey: float = 52.0 + float(fl) * 34.0
		for b in end_bays:
			var ex0: float = x + side * (14.0 + float(b) * 34.0)
			var ex1: float = ex0 + side * 18.0
			var hv: float = h01(seed_i * 577 + fl * 13 + b)
			var gl: Color = Color(0.05, 0.06, 0.09)
			if hv > 0.35:
				var dm: float = 0.5 + 0.4 * h01(seed_i * 7 + fl * 3 + b)
				gl = (Color(1.0, 0.80, 0.50) if hv > 0.6 else Color(0.66, 0.80, 1.0)) * dm
				gl.a = 1.0
			_pane(d, Vector3(ex0, ey, z0 - 4.0), Vector3(ex1, ey, z0 - 4.0), 20.0, gl, hv > 0.35, seed_i * 31 + fl * 7 + b, Vector3(0, 0, 1))
			if ey + 20.0 > eye.y:
				_quad(d, [Vector3(ex0, ey + 20.0, z0), Vector3(ex1, ey + 20.0, z0), Vector3(ex1, ey + 20.0, z0 - 4.0), Vector3(ex0, ey + 20.0, z0 - 4.0)], face.darkened(0.7))
			else:
				_quad(d, [Vector3(ex0, ey, z0), Vector3(ex1, ey, z0), Vector3(ex1, ey, z0 - 4.0), Vector3(ex0, ey, z0 - 4.0)], face.darkened(0.2))
	# windows
	var floors: int = int((hgt - 50.0) / 34.0)
	var bays: int = int(absf(z0 - z1) / 32.0)
	for fl in floors:
		var wy: float = 52.0 + float(fl) * 34.0
		for b in bays:
			var wz0: float = z0 - 9.0 - float(b) * 32.0
			var wz1: float = wz0 - 17.0
			var hv: float = h01(seed_i * 977 + fl * 31 + b)
			var glass: Color = Color(0.06, 0.07, 0.10)
			if hv > 0.32:
				var dim: float = 0.55 + 0.45 * h01(seed_i * 13 + fl * 7 + b * 3)
				var lit: Color = Color(1.0, 0.80, 0.50) if hv > 0.6 else Color(0.66, 0.80, 1.0)
				glass = Color(lit.r * dim, lit.g * dim, lit.b * dim)
			var dep: float = 4.0
			var gx: float = x + inward * dep
			_pane(d, Vector3(gx, wy, wz0), Vector3(gx, wy, wz1), 20.0, glass, hv > 0.32, seed_i * 53 + fl * 11 + b, Vector3(-side, 0, 0))
			# the reveal on its far side (the side turned toward us)
			_quad(d, [Vector3(x, wy, wz1), Vector3(gx, wy, wz1), Vector3(gx, wy + 20.0, wz1), Vector3(x, wy + 20.0, wz1)], face.darkened(0.25))
			if wy + 20.0 > eye.y:
				_quad(d, [Vector3(x, wy + 20.0, wz0), Vector3(x, wy + 20.0, wz1), Vector3(gx, wy + 20.0, wz1), Vector3(gx, wy + 20.0, wz0)], face.darkened(0.5))
			else:
				_quad(d, [Vector3(x, wy, wz0), Vector3(x, wy, wz1), Vector3(gx, wy, wz1), Vector3(gx, wy, wz0)], face.lightened(0.1))
			# the sill standing out
			_box(d, Vector3(x - inward * 2.5, wy - 2.5, wz0 + 1.5), Vector3(x, wy, wz1 - 1.5), face.lightened(0.25))
		if fl % 3 == 2:
			_box(d, Vector3(x - inward * 3.0, wy + 26.0, z0), Vector3(x, wy + 29.0, z1), face.lightened(0.2))
	# the parapet on the roof, and a water tank on some
	_box(d, Vector3(x - inward * 3.0, hgt, z0), Vector3(x + inward * 6.0, hgt + 10.0, z1), face.lightened(0.1))
	if h01(seed_i + 5) > 0.5:
		var tz: float = lerpf(z0, z1, 0.4)
		_box(d, Vector3(x + inward * 30.0, hgt, tz), Vector3(x + inward * 54.0, hgt + 34.0, tz - 24.0), Color(0.24, 0.18, 0.14))
	# THE SHOPFRONTS at street level
	var shops: int = int(absf(z0 - z1) / 75.0)
	for sk in shops:
		var sz0: float = z0 - 12.0 - float(sk) * 75.0
		var sz1: float = sz0 - 56.0
		var hue: Color = [Color(1.0, 0.75, 0.45), Color(0.60, 0.85, 1.0), Color(1.0, 0.62, 0.70), Color(0.75, 1.0, 0.72)][(seed_i + sk) % 4]
		var dep2: float = 10.0
		var bx: float = x + inward * dep2
		# the interior's back wall glowing, seen through the glass; the floor inside; the reveal
		_quad_c(d, [Vector3(bx + inward * 30.0, 4, sz0), Vector3(bx + inward * 30.0, 4, sz1), Vector3(bx + inward * 30.0, 34, sz1), Vector3(bx + inward * 30.0, 34, sz0)],
			[hue.darkened(0.2), hue.darkened(0.2), hue.darkened(0.5), hue.darkened(0.5)])
		for sh_i in 3:
			var shy: float = 10.0 + float(sh_i) * 8.0
			_equad(d, [Vector3(bx + inward * 29.0, shy, sz0 - 6.0), Vector3(bx + inward * 29.0, shy, sz1 + 6.0), Vector3(bx + inward * 29.0, shy + 1.5, sz1 + 6.0), Vector3(bx + inward * 29.0, shy + 1.5, sz0 - 6.0)], hue.darkened(0.7))
		_quad(d, [Vector3(x, 4, sz1), Vector3(bx + inward * 30.0, 4, sz1), Vector3(bx + inward * 30.0, 34, sz1), Vector3(x, 34, sz1)], face.darkened(0.3))
		# the glass itself: a faint sheen with the street's reflection streak
		_quad(d, [Vector3(bx, 4, sz0), Vector3(bx, 4, sz1), Vector3(bx, 34, sz1), Vector3(bx, 34, sz0)], Color(0.7, 0.85, 1.0, 0.10))
		_quad(d, [Vector3(bx, 6, sz0 - 10.0), Vector3(bx, 6, sz0 - 16.0), Vector3(bx, 32, sz0 - 24.0), Vector3(bx, 32, sz0 - 18.0)], Color(1, 1, 1, 0.12))
		# its light spilling on the sidewalk
		_quad_c(d, [Vector3(x, 4.2, sz0), Vector3(x, 4.2, sz1), Vector3(x - inward * 30.0, 4.2, sz1 + 6.0), Vector3(x - inward * 30.0, 4.2, sz0 - 6.0)],
			[Color(hue, 0.22), Color(hue, 0.22), Color(hue, 0.0), Color(hue, 0.0)])
		# the awning: a sloping canvas standing out from the wall, its front valance, its underside lit
		var a_top: float = 42.0
		var a_bot: float = 34.0
		var out: float = 14.0
		_quad(d, [Vector3(x, a_bot, sz0 + 2.0), Vector3(x, a_bot, sz1 - 2.0), Vector3(x - inward * out, a_bot - 2.0, sz1 - 2.0), Vector3(x - inward * out, a_bot - 2.0, sz0 + 2.0)], hue.darkened(0.15))
		_quad(d, [Vector3(x, a_top, sz0 + 2.0), Vector3(x, a_top, sz1 - 2.0), Vector3(x - inward * out, a_bot, sz1 - 2.0), Vector3(x - inward * out, a_bot, sz0 + 2.0)], hue.darkened(0.55))
		_quad(d, [Vector3(x - inward * out, a_bot, sz0 + 2.0), Vector3(x - inward * out, a_bot, sz1 - 2.0), Vector3(x - inward * out, a_bot - 5.0, sz1 - 2.0), Vector3(x - inward * out, a_bot - 5.0, sz0 + 2.0)], hue.darkened(0.35))
		# the sign box over it, its face lit
		_box(d, Vector3(x - inward * 3.0, 46.0, sz0 - 6.0), Vector3(x, 54.0, sz1 + 6.0), Color(0.1, 0.1, 0.12))
		_equad(d, [Vector3(x - inward * 3.2, 47.0, sz0 - 7.0), Vector3(x - inward * 3.2, 47.0, sz1 + 7.0), Vector3(x - inward * 3.2, 53.0, sz1 + 7.0), Vector3(x - inward * 3.2, 53.0, sz0 - 7.0)], hue.lightened(0.2))

# THE STATION in the near right, BUILT IN DEPTH: a forecourt of concrete slabs; at its back the station
# building -- a garage whose opening shows its lit inside (floor, walls, a cab), an office with a lit shop
# window, a parapet; over the forecourt a thick canopy on round columns, lights set in its underside; a pump
# island with two pumps (lit displays, hoses on holsters); a tall price sign at the corner
const ST_Z0: float = 160.0
const ST_Z1: float = -520.0
const ST_BACK: float = ROAD + WALK + 230.0
const ISLAND_X: float = ROAD + WALK + 120.0
const PUMP_Z: float = -230.0

func _station(d: CanvasItem) -> void:
	# the forecourt: concrete slabs with joints, an oil stain or two
	var fz: float = ST_Z0
	while fz > ST_Z1:
		for fxk in 4:
			var fx0: float = lerpf(ROAD + WALK, ST_BACK, float(fxk) / 4.0)
			var fx1: float = lerpf(ROAD + WALK, ST_BACK, float(fxk + 1) / 4.0)
			_quad(d, [Vector3(fx0, 4.1, fz), Vector3(fx1, 4.1, fz), Vector3(fx1, 4.1, fz - 35.0), Vector3(fx0, 4.1, fz - 35.0)], Color(0.50, 0.49, 0.48))
		fz -= 35.0
	for k in 3:
		_ground_glow(d, Vector3(ISLAND_X - 40.0 + 30.0 * h01(k + 20), 4.2, PUMP_Z + 60.0 - 70.0 * float(k)), 14.0, Color(0.02, 0.02, 0.03, 0.18))
	# THE BUILDING: the garage's inside first (its back wall, floor, side walls, a cab), then the face round it
	var bh: float = 120.0
	var gz0: float = -110.0
	var gz1: float = -320.0
	var gin: float = ST_BACK + 90.0
	_quad_c(d, [Vector3(gin, 4, gz0), Vector3(gin, 4, gz1), Vector3(gin, 92, gz1), Vector3(gin, 92, gz0)], [Color(0.80, 0.66, 0.44), Color(0.80, 0.66, 0.44), Color(0.50, 0.40, 0.28), Color(0.50, 0.40, 0.28)])
	_quad(d, [Vector3(ST_BACK, 4.2, gz0), Vector3(gin, 4.2, gz0), Vector3(gin, 4.2, gz1), Vector3(ST_BACK, 4.2, gz1)], Color(0.46, 0.40, 0.32))
	_quad(d, [Vector3(ST_BACK, 4, gz1), Vector3(gin, 4, gz1), Vector3(gin, 92, gz1), Vector3(ST_BACK, 92, gz1)], Color(0.62, 0.52, 0.36))
	for k in 3:
		var tz: float = gz1 + 30.0 + float(k) * 26.0
		_box(d, Vector3(gin - 14.0, 4.0, tz), Vector3(gin - 2.0, 30.0, tz + 18.0), Color(0.12, 0.12, 0.13))
	_car(d, Vector3(ST_BACK + 46.0, 4.0, (gz0 + gz1) * 0.5), Vector3(0, 0, -1), true, 1.0)
	# the face, in pieces round the garage opening and the shop window
	var face: Color = Color(0.56, 0.52, 0.48)
	_quad(d, [Vector3(ST_BACK, 0, ST_Z0), Vector3(ST_BACK, 0, gz0), Vector3(ST_BACK, bh, gz0), Vector3(ST_BACK, bh, ST_Z0)], face)
	_quad(d, [Vector3(ST_BACK, 92, gz0), Vector3(ST_BACK, 92, gz1), Vector3(ST_BACK, bh, gz1), Vector3(ST_BACK, bh, gz0)], face)
	var sz0: float = -380.0
	var sz1: float = -500.0
	_quad(d, [Vector3(ST_BACK, 0, gz1), Vector3(ST_BACK, 0, sz0), Vector3(ST_BACK, bh, sz0), Vector3(ST_BACK, bh, gz1)], face)
	_quad(d, [Vector3(ST_BACK, 0, sz0), Vector3(ST_BACK, 0, sz1), Vector3(ST_BACK, 20, sz1), Vector3(ST_BACK, 20, sz0)], face)
	_quad(d, [Vector3(ST_BACK, 80, sz0), Vector3(ST_BACK, 80, sz1), Vector3(ST_BACK, bh, sz1), Vector3(ST_BACK, bh, sz0)], face)
	_quad(d, [Vector3(ST_BACK, 0, sz1), Vector3(ST_BACK, 0, ST_Z1), Vector3(ST_BACK, bh, ST_Z1), Vector3(ST_BACK, bh, sz1)], face)
	# the shop window: the lit room behind (back wall with shelves), the reveal, the glass's sheen
	var sw: float = ST_BACK + 40.0
	_quad_c(d, [Vector3(sw, 20, sz0), Vector3(sw, 20, sz1), Vector3(sw, 80, sz1), Vector3(sw, 80, sz0)], [Color(0.98, 0.92, 0.78), Color(0.98, 0.92, 0.78), Color(0.80, 0.74, 0.62), Color(0.80, 0.74, 0.62)])
	for k in 4:
		_equad(d, [Vector3(sw - 1.0, 30.0 + float(k) * 12.0, sz0 - 10.0), Vector3(sw - 1.0, 30.0 + float(k) * 12.0, sz1 + 10.0), Vector3(sw - 1.0, 32.0 + float(k) * 12.0, sz1 + 10.0), Vector3(sw - 1.0, 32.0 + float(k) * 12.0, sz0 - 10.0)], Color(0.45, 0.30, 0.20))
	_quad(d, [Vector3(ST_BACK, 20, sz1), Vector3(sw, 20, sz1), Vector3(sw, 80, sz1), Vector3(ST_BACK, 80, sz1)], face.darkened(0.3))
	_quad(d, [Vector3(ST_BACK, 20, sz0), Vector3(ST_BACK, 20, sz1), Vector3(ST_BACK, 80, sz1), Vector3(ST_BACK, 80, sz0)], Color(0.7, 0.85, 1.0, 0.10))
	# the garage's lintel soffit and side reveal (the wall's thickness), the rolled-up door's drum
	_quad(d, [Vector3(ST_BACK, 92, gz0), Vector3(ST_BACK, 92, gz1), Vector3(ST_BACK + 12.0, 92, gz1), Vector3(ST_BACK + 12.0, 92, gz0)], face.darkened(0.5))
	_box(d, Vector3(ST_BACK + 2.0, 84.0, gz0 - 2.0), Vector3(ST_BACK + 12.0, 92.0, gz1 + 2.0), Color(0.42, 0.42, 0.46))
	# its light on the forecourt
	_quad_c(d, [Vector3(ST_BACK, 4.2, gz0), Vector3(ST_BACK, 4.2, gz1), Vector3(ST_BACK - 150.0, 4.2, gz1 - 40.0), Vector3(ST_BACK - 150.0, 4.2, gz0 + 40.0)],
		[Color(1.0, 0.82, 0.55, 0.28), Color(1.0, 0.82, 0.55, 0.28), Color(1.0, 0.82, 0.55, 0.0), Color(1.0, 0.82, 0.55, 0.0)])
	# the building's near end and its parapet
	_quad(d, [Vector3(ST_BACK, 0, ST_Z0), Vector3(ST_BACK + 260.0, 0, ST_Z0), Vector3(ST_BACK + 260.0, bh, ST_Z0), Vector3(ST_BACK, bh, ST_Z0)], face.darkened(0.4))
	_box(d, Vector3(ST_BACK - 3.0, bh, ST_Z0), Vector3(ST_BACK + 8.0, bh + 9.0, ST_Z1), face.lightened(0.1))
	# (the pump island, its pumps and the canopy's columns are in the baked picture, in 3-D)
	# THE CANOPY: a thick slab over the island, its underside's lights
	var c_h: float = 110.0
	var cx0: float = ROAD + WALK + 30.0
	var cx1: float = ST_BACK - 50.0
	var cz0: float = PUMP_Z + 170.0
	var cz1: float = PUMP_Z - 190.0
	_quad(d, [Vector3(cx0, c_h, cz0), Vector3(cx1, c_h, cz0), Vector3(cx1, c_h, cz1), Vector3(cx0, c_h, cz1)], Color(0.82, 0.84, 0.88))
	for lx in [cx0 + 30.0, (cx0 + cx1) * 0.5, cx1 - 30.0]:
		for lz in [cz0 - 50.0, PUMP_Z, cz1 + 50.0]:
			var lp: Vector3 = Vector3(lx, c_h - 0.3, lz)
			_equad(d, [lp + Vector3(-9, 0, -9), lp + Vector3(9, 0, -9), lp + Vector3(9, 0, 9), lp + Vector3(-9, 0, 9)], Color(1.0, 1.0, 0.96))
			_ground_glow(d, Vector3(lx, 4.3, lz), 60.0, Color(0.92, 0.95, 1.0, 0.06))
	_box(d, Vector3(cx0, c_h, cz0), Vector3(cx1, c_h + 20.0, cz1), Color(0.86, 0.86, 0.90))
	# the cab company's checker along the fascia, two rows, under its name
	var nq: int = int(absf(cz1 - cz0) / 8.0)
	for q in nq:
		for r in 2:
			var qz0: float = cz0 - float(q) * 8.0
			var qy: float = c_h + 1.5 + float(r) * 4.0
			var dark: bool = (q + r) % 2 == 0
			_quad(d, [Vector3(cx0 - 0.4, qy, qz0), Vector3(cx0 - 0.4, qy, qz0 - 8.0), Vector3(cx0 - 0.4, qy + 4.0, qz0 - 8.0), Vector3(cx0 - 0.4, qy + 4.0, qz0)], Color(0.08, 0.08, 0.08) if dark else YELLOW)
	var nf: int = int(absf(cx1 - cx0) / 8.0)
	for q2 in nf:
		for r2 in 2:
			var qx0: float = cx0 + float(q2) * 8.0
			var qy2: float = c_h + 1.5 + float(r2) * 4.0
			_quad(d, [Vector3(qx0, qy2, cz0 + 0.4), Vector3(qx0 + 8.0, qy2, cz0 + 0.4), Vector3(qx0 + 8.0, qy2 + 4.0, cz0 + 0.4), Vector3(qx0, qy2 + 4.0, cz0 + 0.4)], Color(0.08, 0.08, 0.08) if (q2 + r2) % 2 == 0 else YELLOW)
	# THE PRICE SIGN at the forecourt's corner: two legs, a box with lit panels
	var ps: Vector3 = Vector3(ROAD + WALK + 14.0, 4.0, ST_Z0 - 40.0)
	_pole(d, ps + Vector3(0, 0, 10), ps + Vector3(0, 150, 10), 2.2, 2.2, Color(0.4, 0.4, 0.44))
	_pole(d, ps + Vector3(0, 0, -10), ps + Vector3(0, 150, -10), 2.2, 2.2, Color(0.4, 0.4, 0.44))
	_box(d, ps + Vector3(-5, 150, 22), ps + Vector3(5, 215, -22), Color(0.12, 0.12, 0.14))
	_equad(d, [ps + Vector3(-5.3, 196, 19), ps + Vector3(-5.3, 196, -19), ps + Vector3(-5.3, 212, -19), ps + Vector3(-5.3, 212, 19)], Color(0.95, 0.80, 0.20))
	for k in 2:
		var py: float = 158.0 + float(k) * 18.0
		_equad(d, [ps + Vector3(-5.3, py, 19), ps + Vector3(-5.3, py, -19), ps + Vector3(-5.3, py + 14.0, -19), ps + Vector3(-5.3, py + 14.0, 19)], Color(0.05, 0.05, 0.06))
		_neon_text(d, ps + Vector3(-5.6, py + 7.0, 0), ["1.89", "2.04"][k], 12.0, Color(1.0, 0.45, 0.25, 1.0))

# a fuel pump: a plinth, a body with rounded shoulders, a lit display set in its face, a hose to its holster
# THE CAB STATION IN REAL 3-D (only when baking): a viewport twice the picture's size, the poster's own camera
# (same eye, aim and lens), the scene at 1:100 so the engine's lights reach (they fall off by metres), the station
# built by menu_station3d.gd
func _station_3d() -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(BAKE_W * 2, BAKE_H * 2)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var top_world: Node3D = Node3D.new()
	vp.add_child(top_world)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.72)
	env.ambient_light_energy = 0.28
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	top_world.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.60, 0.66, 0.90)
	moon.light_energy = 0.18
	top_world.add_child(moon)
	moon.rotation_degrees = Vector3(-55.0, -140.0, 0.0)
	var cam: Camera3D = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = rad_to_deg(2.0 * atan(0.5 / 0.95))
	cam.near = 0.05
	cam.far = 40.0
	top_world.add_child(cam)
	cam.look_at_from_position(Vector3(-40.0, 78.0, 340.0) * 0.01, Vector3(130.0, 44.0, -700.0) * 0.01, Vector3.UP)
	cam.current = true
	var world: Node3D = Node3D.new()
	top_world.add_child(world)
	world.scale = Vector3.ONE * 0.01
	load(STATION3D).call("build", world, MainGlobals.get_text_font())
	return vp

# a round post from a to b, its radius tapering ra -> rb: across its width it is shaded as a cylinder, in
# strips at even angles, the colors blended -- no flat stick
func _pole(d: CanvasItem, a: Vector3, b: Vector3, ra: float, rb: float, col: Color) -> void:
	if not (_visible(a) and _visible(b)):
		return
	var pa: Vector2 = _proj(a)
	var pb: Vector2 = _proj(b)
	var n: Vector2 = (pb - pa).normalized().orthogonal()
	var wa: float = ra * _px(a)
	var wb: float = rb * _px(b)
	var steps: int = 8
	for k in steps:
		var th0: float = -PI * 0.5 + PI * float(k) / float(steps)
		var th1: float = -PI * 0.5 + PI * float(k + 1) / float(steps)
		var c0: Color = col.lerp(Color(0.62, 0.55, 0.50), 0.45 * maxf(0.0, cos(th0 - 0.6))).darkened(0.4 * maxf(0.0, -sin(th0)))
		var c1: Color = col.lerp(Color(0.62, 0.55, 0.50), 0.45 * maxf(0.0, cos(th1 - 0.6))).darkened(0.4 * maxf(0.0, -sin(th1)))
		d.draw_polygon(PackedVector2Array([pa + n * wa * sin(th0), pb + n * wb * sin(th0), pb + n * wb * sin(th1), pa + n * wa * sin(th1)]),
			PackedColorArray([c0, c0, c1, c1]))

# a street lamp's head: a shallow housing over the road, seen from below, its lens glowing underneath
func _lamp_head(d: CanvasItem, c: Vector3) -> void:
	_box(d, c + Vector3(-12.0, -1.0, -6.0), c + Vector3(12.0, 5.0, 6.0), Color(0.22, 0.22, 0.26))
	_equad(d, [c + Vector3(-9.0, -1.2, -4.0), c + Vector3(9.0, -1.2, -4.0), c + Vector3(9.0, -1.2, 4.0), c + Vector3(-9.0, -1.2, 4.0)], Color(1.0, 0.94, 0.78))

func _ground_glow(d: CanvasItem, c: Vector3, r: float, col: Color) -> void:
	for k in 6:
		var rr: float = r * (1.0 - float(k) / 6.0)
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 20:
			var a: float = TAU * float(j) / 20.0
			var p: Vector3 = c + Vector3(cos(a) * rr, 0.0, sin(a) * rr)
			if not _visible(p):
				return
			pts.append(_proj(p))
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			d.draw_colored_polygon(pts, col)

# an axis-aligned box from corner a to corner b: the faces turned toward the eye, each shaded by its side
func _box(d: CanvasItem, a: Vector3, b: Vector3, col: Color) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var eye: Vector3 = _cam["eye"]
	if eye.y > hi.y:
		_quad(d, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], col.lightened(0.15))
	elif eye.y < lo.y:
		_quad(d, [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)], col.darkened(0.45))
	if eye.x < lo.x:
		_quad(d, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z)], col.darkened(0.15))
	elif eye.x > hi.x:
		_quad(d, [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)], col.darkened(0.25))
	if eye.z > hi.z:
		_quad(d, [Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], col)

# --- the live layer: lamps' light, reflections, the neon, the cabs --------------------------------------------

func _draw_life(d: Control) -> void:
	if _cam.is_empty():
		return
	# the street lamps' heads, their pools on the road and the wet streaks under them
	for lz in LAMPS:
		for side in [-1.0, 1.0]:
			var head: Vector3 = Vector3(side * (ROAD + 10.0) - side * 30.0, 152.0, float(lz) - (60.0 if side > 0.0 else 0.0))
			if not _visible(head):
				continue
			_ground_glow(d, Vector3(head.x, 0.2, head.z), 90.0, Color(1.0, 0.76, 0.42, 0.05))
			_streak(d, head, Color(1.0, 0.76, 0.42), 0.35)
			var hp: Vector2 = _proj(head)
			var pr: float = _px(head)
			for g in 8:
				d.draw_circle(hp, 40.0 * pr * (1.0 - float(g) / 8.0), Color(1.0, 0.78, 0.45, 0.05))
	# THE NEON on the canopy's fascia: TAXI in yellow, breathing slowly
	var sign_c: Vector3 = Vector3(ROAD + WALK + 30.0 - 0.5, 129.0, -230.0)
	var breathe: float = 0.85 + 0.15 * sin(t * 1.6)
	var sp: Vector2 = _proj(sign_c)
	var spx: float = _px(sign_c)
	for g in 10:
		d.draw_circle(sp, 120.0 * spx * (1.0 - float(g) / 10.0), Color(1.0, 0.80, 0.20, 0.03 * breathe))
	_streak(d, sign_c, Color(1.0, 0.80, 0.25), 0.5 * breathe)
	# THE CABS, far to near: the lanes' traffic and the station's own cab
	var cars: Array = []
	for lane in 2:
		var dir_z: float = -1.0 if lane == 0 else 1.0
		var lx: float = 55.0 if lane == 0 else -55.0
		var n0: int = int(floor(t / LANE_GAP)) - 14
		for i in range(n0, n0 + 16):
			if h01(i * 7 + lane * 101) < 0.35:
				continue                       # gaps in the traffic, not a parade
			var along: float = (t - float(i) * LANE_GAP) * LANE_SPEED
			var zc: float = (300.0 - along) if lane == 0 else (FAR + 200.0 + along)
			if zc < FAR + 100.0 or zc > 420.0:
				continue
			# leave the station's cab its lane where it turns in and out
			var p: Vector3 = Vector3(lx, 0.0, zc)
			cars.append([_depth(p), p, Vector3(0, 0, dir_z), true])
	var st: Array = _station_cab()
	if not st.is_empty():
		cars.append([_depth(st[0]), st[0], st[1], st[2]])
	cars.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for c in cars:
		_car(d, c[1], c[2], bool(c[3]), 1.0)

# THE STATION'S CAB: up from behind us in the near lane, round into the forecourt and straight up to the pump
# (it never turns where it stands), a wait with its roof sign lit, then on ahead past the pump and back out into
# the lane and away -- along smooth paths, eased in and out of the stop
func _cab_path(pts: Array) -> Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for k in 12:
			var u: float = float(k) / 12.0
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
			out.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = pts[pts.size() - 1]
	out.append(Vector3(last.x, 0.0, last.y))
	var cum: PackedFloat32Array = PackedFloat32Array([0.0])
	for i in range(1, out.size()):
		cum.append(cum[i - 1] + out[i].distance_to(out[i - 1]))
	return [out, cum]

func _cab_at(pa: Array, u: float) -> Array:
	var pts: PackedVector3Array = pa[0]
	var cum: PackedFloat32Array = pa[1]
	var sv: float = clampf(u, 0.0, 1.0) * cum[cum.size() - 1]
	for i in range(1, pts.size()):
		if cum[i] >= sv or i == pts.size() - 1:
			var seg: float = maxf(cum[i] - cum[i - 1], 0.001)
			return [pts[i - 1].lerp(pts[i], (sv - cum[i - 1]) / seg), (pts[i] - pts[i - 1]).normalized()]
	return [pts[pts.size() - 1], Vector3(0, 0, -1)]

func _station_cab() -> Array:
	var u: float = fposmod(t + 3.0, STATION_PERIOD)
	var stop_x: float = ISLAND_X - 34.0
	var stop_z: float = PUMP_Z + 10.0
	var p_in: Array = _cab_path([Vector2(55, 460), Vector2(55, 200), Vector2(90, 60), Vector2(stop_x, -40.0), Vector2(stop_x, stop_z)])
	var p_out: Array = _cab_path([Vector2(stop_x, stop_z), Vector2(stop_x, -360.0), Vector2(110, -470.0), Vector2(55, -620.0), Vector2(55, -2400.0)])
	var at: Array = []
	if u < 3.6:
		at = _cab_at(p_in, smoothstep(0.0, 1.0, u / 3.6) * 0.6 + (u / 3.6) * 0.4)
	elif u < 8.0:
		at = _cab_at(p_in, 1.0)
	else:
		var k: float = (u - 8.0) / (STATION_PERIOD - 8.0)
		at = _cab_at(p_out, k * k)
	var p: Vector3 = at[0]
	if p.x > ROAD:
		p.y = 4.0
	return [p, at[1], u > 3.0 and u < 8.5]

# ONE CAB
func _car(d: CanvasItem, p: Vector3, dir: Vector3, busy: bool, alpha: float) -> void:
	_car_body(d, p, dir, YELLOW, alpha, true, busy, false)

# THE CAR'S SHAPE: its side profile (length along the car, height), front to back is +x to -x -- bumper,
# bonnet, windshield, roof, rear window, boot, bumper -- swept across its width, narrowing toward the roof
const PROFILE: Array = [Vector2(-23.0, 3.0), Vector2(-23.6, 9.0), Vector2(-21.5, 12.6), Vector2(-13.5, 13.6), Vector2(-8.0, 21.0),
	Vector2(6.0, 21.4), Vector2(12.5, 13.9), Vector2(22.0, 12.3), Vector2(23.6, 8.2), Vector2(23.0, 3.0)]
const GLASS_STRIPS: Array = [3, 5]          # rear window, windshield
const BUMPER_STRIPS: Array = [0, 8]
const SIDE_WINDOW: Array = [Vector2(-12.6, 14.3), Vector2(-7.7, 20.2), Vector2(5.4, 20.6), Vector2(11.4, 14.4)]

func _half_w(h: float) -> float:
	return 10.5 - maxf(0.0, h - 13.5) * 0.28

# a body panel's color in the scene's light, with a gloss where it turns toward the light above and the eye
func _car_paint(albedo: Color, n: Vector3, at: Vector3, gloss: float) -> Color:
	var c: Color = _lit(albedo, at)
	var lam: float = 0.55 + 0.45 * clampf(n.dot(Vector3(0.0, 1.0, 0.0)), -1.0, 1.0)
	c = Color(c.r * lam, c.g * lam, c.b * lam, albedo.a)
	var view: Vector3 = (Vector3(_cam["eye"]) - at).normalized()
	var half_v: Vector3 = (Vector3.UP + view).normalized()
	var spec: float = pow(clampf(n.dot(half_v), 0.0, 1.0), 18.0) * gloss
	return c.lerp(Color(1.0, 0.95, 0.85, albedo.a), clampf(spec, 0.0, 0.8))

# ONE CAR at p heading dir: its shadow, the body as panels (each lit, glossy, the glass dark and reflecting),
# the near side with its windows and wheel arches, the wheels with their tires' depth, lenses for lights
func _car_body(d: CanvasItem, p: Vector3, dir: Vector3, col: Color, alpha: float, taxi: bool, busy: bool, reversing: bool) -> void:
	var f: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var s: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = Vector3.UP
	var eye: Vector3 = _cam["eye"]
	if not (_visible(p + f * 24.0) and _visible(p - f * 24.0)):
		return
	var sh: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		sh.append(_proj(p + f * cos(a) * 27.0 + s * sin(a) * 13.0 + u * 0.3))
	if Geometry2D.triangulate_polygon(sh).size() > 0:
		d.draw_colored_polygon(sh, Color(0, 0, 0, 0.5 * alpha))
	var near_s: float = 1.0 if s.dot(eye - p) > 0.0 else -1.0
	var n: int = PROFILE.size()
	# the panels swept from the profile, far ones first
	var faces: Array = []
	for i in n - 1:
		var a2: Vector2 = PROFILE[i]
		var b2: Vector2 = PROFILE[i + 1]
		var pa_l: Vector3 = p + f * a2.x + u * a2.y - s * _half_w(a2.y)
		var pa_r: Vector3 = p + f * a2.x + u * a2.y + s * _half_w(a2.y)
		var pb_l: Vector3 = p + f * b2.x + u * b2.y - s * _half_w(b2.y)
		var pb_r: Vector3 = p + f * b2.x + u * b2.y + s * _half_w(b2.y)
		var mid: Vector3 = (pa_l + pa_r + pb_l + pb_r) * 0.25
		var nrm: Vector3 = (pb_l - pa_l).cross(pa_r - pa_l).normalized()
		if nrm.dot(mid - (p + u * 11.0)) < 0.0:
			nrm = -nrm
		if nrm.dot(eye - mid) <= 0.0:
			continue
		faces.append([_depth(mid), [pa_l, pb_l, pb_r, pa_r], nrm, mid, i])
	faces.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for fc in faces:
		var idx: int = fc[4]
		var albedo: Color = col
		var gloss: float = 0.6
		if GLASS_STRIPS.has(idx):
			albedo = Color(0.10, 0.12, 0.16)
			gloss = 1.0
		elif BUMPER_STRIPS.has(idx):
			albedo = Color(0.20, 0.20, 0.22)
			gloss = 0.3
		var q: PackedVector2Array = PackedVector2Array()
		for v in fc[1]:
			q.append(_proj(v))
		if Geometry2D.triangulate_polygon(q).size() > 0:
			d.draw_colored_polygon(q, _car_paint(Color(albedo, alpha), fc[2], fc[3], gloss))
	# the near side: the far wheels are hidden by the body; the near ones' arches, then the side, then the wheels
	var side_n: Vector3 = s * near_s
	var side_pts: PackedVector2Array = PackedVector2Array()
	for pr in PROFILE:
		var v2: Vector2 = pr
		side_pts.append(_proj(p + f * v2.x + u * v2.y + s * near_s * _half_w(v2.y)))
	if Geometry2D.triangulate_polygon(side_pts).size() > 0:
		d.draw_colored_polygon(side_pts, _car_paint(Color(col, alpha), side_n, p + side_n * 10.0 + u * 8.0, 0.35))
	# a crease along the side catching the light
	d.draw_line(_proj(p + f * 21.0 + u * 11.5 + side_n * 10.6), _proj(p - f * 21.0 + u * 12.0 + side_n * 10.6), Color(1, 1, 1, 0.20 * alpha), maxf(1.0, 0.7 * _px(p)), true)
	# the side windows, dark glass reflecting, a pillar between
	var win: PackedVector2Array = PackedVector2Array()
	for wv in SIDE_WINDOW:
		var w2: Vector2 = wv
		win.append(_proj(p + f * w2.x + u * w2.y + s * near_s * (_half_w(w2.y) + 0.15)))
	if Geometry2D.triangulate_polygon(win).size() > 0:
		d.draw_polygon(win, PackedColorArray([Color(0.08, 0.09, 0.13, alpha), Color(0.30, 0.32, 0.40, alpha), Color(0.30, 0.32, 0.40, alpha), Color(0.08, 0.09, 0.13, alpha)]))
	d.draw_line(_proj(p - f * 1.0 + u * 14.3 + side_n * (_half_w(14.3) + 0.2)), _proj(p - f * 1.2 + u * 20.4 + side_n * (_half_w(20.4) + 0.2)), _car_paint(Color(col, alpha), side_n, p + side_n * 10.0 + u * 17.0, 0.2), maxf(1.0, 1.4 * _px(p)))
	if taxi:
		# the checker band along the side
		for k in 10:
			var x0: float = -20.0 + float(k) * 4.0
			var y0: float = 9.6 if k % 2 == 0 else 11.0
			_equad(d, [p + f * x0 + u * y0 + side_n * 10.62, p + f * (x0 + 4.0) + u * y0 + side_n * 10.62, p + f * (x0 + 4.0) + u * (y0 + 1.4) + side_n * 10.62, p + f * x0 + u * (y0 + 1.4) + side_n * 10.62], Color(0.04, 0.04, 0.04, alpha))
	for wf in [-14.5, 14.0]:
		var wc: Vector3 = p + f * float(wf) + u * 4.6
		var arch: PackedVector2Array = PackedVector2Array()
		for k in 11:
			var a3: float = PI * float(k) / 10.0
			arch.append(_proj(wc + f * cos(a3) * 6.2 + u * sin(a3) * 6.2 + side_n * 10.55))
		if Geometry2D.triangulate_polygon(arch).size() > 0:
			d.draw_colored_polygon(arch, Color(0.02, 0.02, 0.03, alpha))
		var outer: Vector3 = wc + side_n * 10.2
		var inner: Vector3 = wc + side_n * 6.5
		var rim_o: PackedVector2Array = PackedVector2Array()
		var tread: PackedVector2Array = PackedVector2Array()
		for k in 18:
			var a4: float = TAU * float(k) / 18.0
			var off: Vector3 = f * cos(a4) * 4.6 + u * sin(a4) * 4.6
			rim_o.append(_proj(outer + off))
			tread.append(_proj(outer + off))
			tread.append(_proj(inner + off))
		var th: PackedVector2Array = Geometry2D.convex_hull(tread)
		if th.size() >= 4:
			th.remove_at(th.size() - 1)
			d.draw_colored_polygon(th, Color(0.03, 0.03, 0.04, alpha))
		if Geometry2D.triangulate_polygon(rim_o).size() > 0:
			d.draw_colored_polygon(rim_o, Color(0.10, 0.10, 0.12, alpha))
		var hub: PackedVector2Array = PackedVector2Array()
		for k in 12:
			var a5: float = TAU * float(k) / 12.0
			hub.append(_proj(outer + side_n * 0.2 + f * cos(a5) * 2.4 + u * sin(a5) * 2.4))
		if Geometry2D.triangulate_polygon(hub).size() > 0:
			d.draw_colored_polygon(hub, _lit(Color(0.70, 0.70, 0.74, alpha), wc))
	# the roof sign (a taxi): a little box, lit amber when the cab is free
	if taxi:
		var rs: Vector3 = p - f * 1.0 + u * 21.4
		var sc: Color = Color(1.0, 0.86, 0.45, alpha) if not busy else Color(0.40, 0.35, 0.25, alpha)
		_equad(d, [rs - f * 3.0 - s * 4.0, rs + f * 3.0 - s * 4.0, rs + f * 3.0 - s * 4.0 + u * 3.5, rs - f * 3.0 - s * 4.0 + u * 3.5], sc)
		_equad(d, [rs - f * 3.0 + s * 4.0, rs + f * 3.0 + s * 4.0, rs + f * 3.0 + s * 4.0 + u * 3.5, rs - f * 3.0 + s * 4.0 + u * 3.5], sc)
		_equad(d, [rs - f * 3.0 - s * 4.0 + u * 3.5, rs + f * 3.0 - s * 4.0 + u * 3.5, rs + f * 3.0 + s * 4.0 + u * 3.5, rs - f * 3.0 + s * 4.0 + u * 3.5], sc.lightened(0.1))
		if not busy:
			var rp: Vector2 = _proj(rs + u * 2.0)
			for g in 5:
				d.draw_circle(rp, 14.0 * _px(rs) * (1.0 - float(g) / 5.0), Color(1.0, 0.85, 0.40, 0.06 * alpha))
	# lamps: lenses set in the front and the back, glowing
	for sd2 in [-1.0, 1.0]:
		var front: Vector3 = p + f * 23.5 + s * sd2 * 7.2 + u * 9.6
		var back: Vector3 = p - f * 23.6 + s * sd2 * 7.4 + u * 10.2
		if f.dot(eye - front) > 0.0:
			var fp: Vector2 = _proj(front)
			for g in 6:
				d.draw_circle(fp, 18.0 * _px(front) * (1.0 - float(g) / 6.0), Color(1.0, 0.95, 0.80, 0.08 * alpha))
			_equad(d, [front - s * 2.6 - u * 1.2, front + s * 2.6 - u * 1.2, front + s * 2.6 + u * 1.2, front - s * 2.6 + u * 1.2], Color(1.0, 1.0, 0.94, alpha))
			_streak(d, front, Color(1.0, 0.95, 0.80), 0.4 * alpha)
		if (-f).dot(eye - back) > 0.0:
			var lc: Color = Color(1.0, 0.22, 0.16) if not reversing else Color(1.0, 1.0, 0.95)
			var bp: Vector2 = _proj(back)
			for g in 5:
				d.draw_circle(bp, 12.0 * _px(back) * (1.0 - float(g) / 5.0), Color(lc, 0.08 * alpha))
			_equad(d, [back - s * 2.4 - u * 1.3, back + s * 2.4 - u * 1.3, back + s * 2.4 + u * 1.3, back - s * 2.4 + u * 1.3], Color(lc, alpha))
			_streak(d, back, lc, 0.35 * alpha)

# a light's reflection on the wet road: a long vertical streak below it, fading downward
func _streak(d: CanvasItem, src: Vector3, col: Color, strength: float) -> void:
	var g: Vector3 = Vector3(src.x, 0.0, src.z)
	if not _visible(g):
		return
	var top_p: Vector2 = _proj(g)
	var px: float = _px(g)
	var w: float = maxf(1.5, 6.0 * px)
	var ln: float = 60.0 * px + 20.0
	d.draw_polygon(PackedVector2Array([top_p + Vector2(-w, 0), top_p + Vector2(w, 0), top_p + Vector2(w * 0.4, ln), top_p + Vector2(-w * 0.4, ln)]),
		PackedColorArray([Color(col, 0.30 * strength), Color(col, 0.30 * strength), Color(col, 0.0), Color(col, 0.0)]))

# neon letters on a plane facing the avenue (along z), drawn as glowing strokes through the projection
func _neon_text(d: CanvasItem, c: Vector3, txt: String, hgt: float, col: Color) -> void:
	var font: Font = MainGlobals.get_text_font()
	var fs: int = 64
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sc: float = hgt / float(fs)
	# the plane: x fixed, letters running toward +z -- toward us, as the fascia faces the avenue from our right
	var origin: Vector3 = c + Vector3(0, -hgt * 0.35, -tw * sc * 0.5)
	var a: Vector2 = _proj(origin)
	var bx: Vector2 = _proj(origin + Vector3(0, 0, 1.0)) - a
	var by: Vector2 = _proj(origin + Vector3(0, 1.0, 0)) - a
	var xf: Transform2D = Transform2D(bx * sc, -by * sc, a)
	d.draw_set_transform_matrix(xf)
	for g in 3:
		d.draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14 - g * 4, Color(col.r, col.g * 0.8, col.b * 0.4, 0.18 * col.a))
	d.draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.97, 0.80, col.a))
	d.draw_set_transform_matrix(Transform2D.IDENTITY)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Taxi", "Be a station manager and owner", Color(1.0, 0.86, 0.30), Color(0.10, 0.06, 0.0),
		Color(1.0, 0.8, 0.3, 0.25))
