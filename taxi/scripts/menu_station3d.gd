extends RefCounted

# TAXI'S CAB STATION IN REAL 3-D, for the menu poster's baked background only (devtools/make_menu_bake.gd renders
# it once with the poster's own camera and the result is shipped as taxi/art/menu_city.webp; the game never builds
# it at run time). The user: the hand-drawn pumps were "still bad ... make them super perfect, including the
# entire gas station". Everything is in the poster's world units, under a root the caller scales to 1:100 (the
# engine's lights fall off by metres); light ranges are given in metres.
#
# The forecourt of concrete slabs with joints and stains; the station building in painted brick -- a garage whose
# open door shows its lit inside (a cab, tires, a work lamp), a shop with a lit window, shelves and a door, a
# parapet, a roof unit, wall lamps, the company's name lit on the roof; the canopy -- a thick slab, the checker
# round its fascia, CITY CABS on its road side, recessed lights in its underside -- on steel columns; the pump
# island with yellow bollards, two pumps (rounded bodies, glossy paint, a lit display with its sale, grade
# buttons, the brand disc, nozzles in holsters on both sides, rubber hoses); a tall price sign; a bin.

const ROAD: float = 110.0
const WALK: float = 46.0
const ST_Z0: float = 160.0
const ST_Z1: float = -520.0
const ST_BACK: float = ROAD + WALK + 230.0
const ISLAND_X: float = ROAD + WALK + 120.0
const PUMP_Z: float = -230.0
const YELLOW: Color = Color(0.99, 0.80, 0.16)
# the driveways across the sidewalk (z from, z to): where the station's cab turns in, and where it pulls out
const DRIVE_IN: Vector2 = Vector2(-40.0, 110.0)
const DRIVE_OUT: Vector2 = Vector2(-545.0, -360.0)

# a concrete apron across the sidewalk: its top sloping from the road (x0, height 0) up to the forecourt (x1, h), its
# two ends closed; the texture laid by the world's x and z, as on the slabs beside it
static func ramp_mesh(x0: float, x1: float, z0: float, z1: float, h: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_top: Vector3 = Vector3(-h, x1 - x0, 0.0).normalized()
	var top: Array = [Vector3(x0, 0.0, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, 0.0, z1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		var v: Vector3 = top[idx]
		st.set_normal(n_top)
		st.set_uv(Vector2(v.x, v.z) / 256.0)
		st.add_vertex(v)
	for zz in [z0, z1]:
		var side_n: Vector3 = Vector3(0.0, 0.0, -1.0 if zz == z0 else 1.0)
		for v2 in [Vector3(x0, 0.0, zz), Vector3(x1, 0.0, zz), Vector3(x1, h, zz)]:
			st.set_normal(side_n)
			st.set_uv(Vector2(v2.x, v2.y) / 256.0)
			st.add_vertex(v2)
	return st.commit()

static func h01(i: int) -> float:
	var x: int = (i * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0

static func build(root: Node3D, font: Font) -> void:
	_lights(root)
	_forecourt(root)
	_building(root, font)
	_canopy(root, font)
	_island(root)
	_price_sign(root, font)
	_props(root)

# --- helpers ---------------------------------------------------------------------------------------------------

static func mat(col: Color, rough: float = 0.8, metal: float = 0.0, tex: Texture2D = null, uv: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col if tex == null else Color(1, 1, 1)
	m.roughness = rough
	m.metallic = metal
	# both faces: the rounded boxes and tubes are wound the other way round from the engine's front face, and with
	# back faces culled their outsides vanished (the pump island did not show; the pumps stood on a black slab)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func glow(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func put(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot
	return mi

static func box(parent: Node3D, sz: Vector3, m: Material, center: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	return put(parent, bm, m, center, rot)

# a box given by two corners
static func block(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> MeshInstance3D:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return box(parent, hi - lo, m, (lo + hi) * 0.5)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, m: Material, center: Vector3, segs: int = 32, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	return put(parent, cm, m, center, rot)

static func light(parent: Node3D, pos: Vector3, col: Color, energy: float, range_m: float, shadow: bool = false) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = shadow
	parent.add_child(l)
	l.position = pos

static func label(parent: Node3D, txt: String, font: Font, px_size: float, col: Color, pos: Vector3, rot: Vector3) -> void:
	var lb: Label3D = Label3D.new()
	lb.text = txt
	lb.font = font
	lb.font_size = 128
	lb.pixel_size = px_size
	lb.modulate = col
	lb.shaded = false
	lb.outline_size = 0
	lb.double_sided = false
	parent.add_child(lb)
	lb.position = pos
	lb.rotation_degrees = rot

# a picture made in code: base color with specks, and optional lines (joints, mortar) every `step` texels
static func tex(n: int, base: Color, speck: float, seed_i: int, joints: int = 0, joint_col: Color = Color.BLACK, brick: bool = false) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(base)
	if brick:
		var bh: int = n / 8
		var bw: int = n / 4
		for row in 8:
			var off: int = (bw / 2) * (row % 2)
			for col in 5:
				var x0: int = col * bw - off
				var tone: float = 0.9 + 0.2 * h01(seed_i * 31 + row * 7 + col)
				img.fill_rect(Rect2i(maxi(x0 + 1, 0), row * bh + 1, mini(bw - 2, n - maxi(x0 + 1, 0)), bh - 2), Color(base.r * tone, base.g * tone, base.b * tone))
		img.fill_rect(Rect2i(0, 0, n, 1), joint_col)
	for k in n * n / 5:
		var v: float = (h01(seed_i * 100003 + k * 3) - 0.5) * speck
		var x: int = int(h01(seed_i * 100003 + k * 3 + 1) * float(n - 1))
		var y: int = int(h01(seed_i * 100003 + k * 3 + 2) * float(n - 1))
		var c: Color = img.get_pixel(x, y)
		img.set_pixel(x, y, Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1)))
	if joints > 0:
		var step: int = n / joints
		for k2 in joints:
			img.fill_rect(Rect2i(k2 * step, 0, 1, n), joint_col)
			img.fill_rect(Rect2i(0, k2 * step, n, 1), joint_col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a ROUNDED BOX standing on its foot: a rounded-rectangle section (half sizes hx, hz, corner radius r) swept up h,
# the top edge bevelled, smooth normals all round
static func rbox_mesh(hx: float, hz: float, h: float, r: float, bev: float) -> ArrayMesh:
	var ring: Array = []
	var corners: Array = [Vector2(hx - r, hz - r), Vector2(-(hx - r), hz - r), Vector2(-(hx - r), -(hz - r)), Vector2(hx - r, -(hz - r))]
	for ci in 4:
		for k in 7:
			var a: float = PI * 0.5 * float(ci) + PI * 0.5 * float(k) / 6.0
			var nrm: Vector2 = Vector2(cos(a), sin(a))
			ring.append([Vector2(corners[ci]) + nrm * r, nrm])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = ring.size()
	var top_y: float = h - bev
	for i in n:
		var j: int = (i + 1) % n
		var pa: Vector2 = ring[i][0]
		var pb: Vector2 = ring[j][0]
		var na: Vector3 = Vector3(Vector2(ring[i][1]).x, 0.0, Vector2(ring[i][1]).y)
		var nb: Vector3 = Vector3(Vector2(ring[j][1]).x, 0.0, Vector2(ring[j][1]).y)
		var a0: Vector3 = Vector3(pa.x, 0.0, pa.y)
		var b0: Vector3 = Vector3(pb.x, 0.0, pb.y)
		var a1: Vector3 = Vector3(pa.x, top_y, pa.y)
		var b1: Vector3 = Vector3(pb.x, top_y, pb.y)
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		_v(st, a0, na, Vector2(u0, 1.0))
		_v(st, a1, na, Vector2(u0, 0.0))
		_v(st, b1, nb, Vector2(u1, 0.0))
		_v(st, a0, na, Vector2(u0, 1.0))
		_v(st, b1, nb, Vector2(u1, 0.0))
		_v(st, b0, nb, Vector2(u1, 1.0))
		var ia: Vector3 = Vector3(pa.x - na.x * bev, h, pa.y - na.z * bev)
		var ib: Vector3 = Vector3(pb.x - nb.x * bev, h, pb.y - nb.z * bev)
		_v(st, a1, na, Vector2.ZERO)
		_v(st, ia, (na + Vector3.UP).normalized(), Vector2.ZERO)
		_v(st, ib, (nb + Vector3.UP).normalized(), Vector2.ZERO)
		_v(st, a1, na, Vector2.ZERO)
		_v(st, ib, (nb + Vector3.UP).normalized(), Vector2.ZERO)
		_v(st, b1, nb, Vector2.ZERO)
		_v(st, Vector3(0.0, h, 0.0), Vector3.UP, Vector2(0.5, 0.5))
		_v(st, ib, Vector3.UP, Vector2.ZERO)
		_v(st, ia, Vector3.UP, Vector2.ZERO)
	return st.commit()

static func _v(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)

# a smooth tube of radius r along a path
static func tube_mesh(path: PackedVector3Array, r: float, sides: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in path.size():
		var tg: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tg.cross(Vector3.UP)
		if side.length() < 0.1:
			side = tg.cross(Vector3.RIGHT)
		side = side.normalized()
		var up2: Vector3 = side.cross(tg).normalized()
		var ring: Array = []
		for k in sides:
			var a: float = TAU * float(k) / float(sides)
			var nrm: Vector3 = side * cos(a) + up2 * sin(a)
			ring.append([path[i] + nrm * r, nrm])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var k2: int = (k + 1) % sides
			for v in [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k], rings[i + 1][k2], rings[i][k2]]:
				_v(st, v[0], v[1], Vector2.ZERO)
	return st.commit()

# --- the scene ---------------------------------------------------------------------------------------------------

static func _lights(root: Node3D) -> void:
	# the canopy's recessed lights (cool), the garage's work lights and the shop (warm), the street lamp near by
	for lx in [ROAD + WALK + 70.0, ST_BACK - 90.0]:
		for lz in [PUMP_Z + 120.0, PUMP_Z, PUMP_Z - 140.0]:
			light(root, Vector3(lx, 100.0, lz), Color(0.86, 0.92, 1.0), 0.55, 2.0)
	light(root, Vector3(ST_BACK + 50.0, 80.0, -215.0), Color(1.0, 0.80, 0.52), 0.9, 2.6, true)
	light(root, Vector3(ST_BACK + 30.0, 60.0, -440.0), Color(1.0, 0.88, 0.66), 0.6, 2.0)
	light(root, Vector3(90.0, 148.0, -260.0), Color(1.0, 0.74, 0.44), 0.8, 2.8)
	light(root, Vector3(ST_BACK - 10.0, 104.0, -100.0), Color(1.0, 0.80, 0.50), 0.25, 1.2)

static func _forecourt(root: Node3D) -> void:
	var t: ImageTexture = tex(256, Color(0.52, 0.51, 0.49), 0.10, 11, 4, Color(0.30, 0.29, 0.28))
	var conc: StandardMaterial3D = mat(Color.WHITE, 0.75, 0.0, t, Vector3(4.0, 10.0, 1.0))
	block(root, Vector3(ROAD + WALK, 0.0, ST_Z1), Vector3(ST_BACK + 260.0, 4.1, ST_Z0), conc)
	# THE SIDEWALK IN FRONT OF IT: raised, a curb stone at the road's edge -- and at the two DRIVEWAYS, where the cab
	# turns in and pulls out, a dropped curb and a concrete apron sloping up from the road to the forecourt (it was a
	# 4-unit step all along: the cab "fell" onto the road, the user, 2026-11-20)
	var curb: StandardMaterial3D = mat(Color(0.62, 0.61, 0.58), 0.7)
	var z_edges: Array = [ST_Z1, DRIVE_OUT.x, DRIVE_OUT.y, DRIVE_IN.x, DRIVE_IN.y, ST_Z0]
	for i in z_edges.size() - 1:
		var za: float = z_edges[i]
		var zb: float = z_edges[i + 1]
		if i % 2 == 0:
			block(root, Vector3(ROAD + 6.0, 0.0, za), Vector3(ROAD + WALK, 4.1, zb), conc)
			block(root, Vector3(ROAD, 0.0, za), Vector3(ROAD + 6.0, 4.5, zb), curb)
		else:
			put(root, ramp_mesh(ROAD, ROAD + WALK, za, zb, 4.1), conc, Vector3.ZERO)
	# oil stains where the cabs stand
	var stain: StandardMaterial3D = mat(Color(0.12, 0.11, 0.11, 0.35), 0.4)
	stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 4:
		var sc: CylinderMesh = CylinderMesh.new()
		sc.top_radius = 7.0 + 6.0 * h01(k + 3)
		sc.bottom_radius = sc.top_radius
		sc.height = 0.2
		put(root, sc, stain, Vector3(ISLAND_X - 34.0 + 6.0 * h01(k), 4.2, PUMP_Z + 50.0 - 40.0 * float(k)))

# THE BUILDING: painted brick, its face to the forecourt (-x) with the garage and the shop cut into it
static func _building(root: Node3D, font: Font) -> void:
	var bh: float = 120.0
	var brick: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex(256, Color(0.62, 0.56, 0.50), 0.08, 21, 0, Color(0.42, 0.38, 0.34), true), Vector3(6.0, 3.0, 1.0))
	var trim: StandardMaterial3D = mat(Color(0.82, 0.80, 0.76), 0.6)
	var x0: float = ST_BACK
	var gz0: float = -110.0
	var gz1: float = -320.0
	var sz0: float = -380.0
	var sz1: float = -500.0
	# the face in pieces round the openings, each a slab 12 thick
	block(root, Vector3(x0, 0, ST_Z0), Vector3(x0 + 12.0, bh, gz0), brick)
	block(root, Vector3(x0, 92.0, gz0), Vector3(x0 + 12.0, bh, gz1), brick)
	block(root, Vector3(x0, 0, gz1), Vector3(x0 + 12.0, bh, sz0), brick)
	block(root, Vector3(x0, 0, sz0), Vector3(x0 + 12.0, 20.0, sz1), brick)
	block(root, Vector3(x0, 80.0, sz0), Vector3(x0 + 12.0, bh, sz1), brick)
	block(root, Vector3(x0, 0, sz1), Vector3(x0 + 12.0, bh, ST_Z1), brick)
	# the body behind the garage and the shop (starting at their back walls: begun right behind the face, it filled
	# both, and the garage showed a grey wall), its near end toward us; the roof over all
	block(root, Vector3(x0 + 125.0, 0, ST_Z0), Vector3(x0 + 260.0, bh, ST_Z1), brick)
	block(root, Vector3(x0 + 12.0, 0, ST_Z0), Vector3(x0 + 125.0, bh, ST_Z0 - 20.0), brick)
	block(root, Vector3(x0 - 2.0, bh, ST_Z0), Vector3(x0 + 260.0, bh + 8.0, ST_Z1), trim)
	block(root, Vector3(x0 + 40.0, bh + 8.0, -200.0), Vector3(x0 + 90.0, bh + 30.0, -260.0), mat(Color(0.60, 0.62, 0.64), 0.5, 0.3))
	# THE GARAGE: lit inside -- floor, back wall, sides, a ceiling light, tires, a cab -- and the rolled-up door
	var inside_floor: StandardMaterial3D = mat(Color(0.42, 0.40, 0.38), 0.6)
	var inside_wall: StandardMaterial3D = mat(Color(0.78, 0.74, 0.66), 0.8)
	block(root, Vector3(x0, 0.0, gz1), Vector3(x0 + 120.0, 4.1, gz0), inside_floor)
	block(root, Vector3(x0 + 120.0, 0.0, gz1), Vector3(x0 + 124.0, 92.0, gz0), inside_wall)
	block(root, Vector3(x0, 0.0, gz1 - 4.0), Vector3(x0 + 120.0, 92.0, gz1), inside_wall)
	block(root, Vector3(x0, 92.0, gz1), Vector3(x0 + 120.0, 96.0, gz0), inside_wall)
	box(root, Vector3(60.0, 1.0, 6.0), glow(Color(1.0, 0.96, 0.86)), Vector3(x0 + 70.0, 91.0, (gz0 + gz1) * 0.5))
	var rubber: StandardMaterial3D = mat(Color(0.05, 0.05, 0.05), 0.7)
	for k in 4:
		var tz: float = gz1 + 22.0 + float(k % 2) * 26.0
		var ty: float = 4.1 + 6.0 + float(k / 2) * 12.0
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 5.0
		tm.outer_radius = 11.0
		put(root, tm, rubber, Vector3(x0 + 104.0, ty, tz), Vector3(0, 0, 0)).scale = Vector3(1.0, 0.55, 1.0)
	_cab(root, Vector3(x0 + 60.0, 4.1, (gz0 + gz1) * 0.5 + 10.0), Vector3(0.0, 90.0, 0.0))
	var door_drum: StandardMaterial3D = mat(Color(0.55, 0.57, 0.60), 0.45, 0.4)
	cyl(root, 6.0, 6.0, gz0 - gz1, door_drum, Vector3(x0 + 6.0, 98.0, (gz0 + gz1) * 0.5), 24, Vector3(90.0, 0.0, 0.0))
	# THE SHOP: a lit room behind its window -- shelves of goods -- the glass, the frame, a door
	block(root, Vector3(x0 + 4.0, 0.0, sz1), Vector3(x0 + 90.0, 4.1, sz0), inside_floor)
	block(root, Vector3(x0 + 90.0, 0.0, sz1), Vector3(x0 + 94.0, 100.0, sz0), mat(Color(0.95, 0.92, 0.84), 0.8))
	for k in 3:
		var shelf_y: float = 28.0 + float(k) * 16.0
		block(root, Vector3(x0 + 70.0, shelf_y, sz1 + 10.0), Vector3(x0 + 88.0, shelf_y + 2.0, sz0 - 10.0), mat(Color(0.55, 0.40, 0.28), 0.7))
		for g in 9:
			var gc: Color = [Color(0.85, 0.20, 0.15), Color(0.20, 0.45, 0.85), Color(0.95, 0.80, 0.20), Color(0.25, 0.65, 0.30)][(k + g) % 4]
			box(root, Vector3(8.0, 8.0 + 3.0 * h01(k * 9 + g), 9.0), mat(gc, 0.6), Vector3(x0 + 80.0, shelf_y + 6.0, sz1 + 16.0 + float(g) * 11.0))
	light(root, Vector3(x0 + 50.0, 70.0, (sz0 + sz1) * 0.5), Color(1.0, 0.92, 0.75), 0.5, 1.4)
	var glass: StandardMaterial3D = mat(Color(0.75, 0.86, 1.0, 0.14), 0.05, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box(root, Vector3(0.6, 60.0, sz0 - sz1), glass, Vector3(x0 + 6.0, 50.0, (sz0 + sz1) * 0.5))
	for fz in [sz0, (sz0 + sz1) * 0.5, sz1]:
		box(root, Vector3(3.0, 60.0, 3.0), trim, Vector3(x0 + 1.0, 50.0, fz))
	# wall lamps over the garage, and GARAGE lit on the face
	for wz in [gz0 - 30.0, gz1 + 30.0]:
		cyl(root, 1.0, 1.0, 10.0, mat(Color(0.1, 0.1, 0.1), 0.4, 0.5), Vector3(x0 - 4.0, 104.0, wz), 12, Vector3(0, 0, 90.0))
		box(root, Vector3(8.0, 3.0, 8.0), glow(Color(1.0, 0.92, 0.75)), Vector3(x0 - 9.0, 101.0, wz))
	label(root, "GARAGE", font, 0.09, Color(1.0, 0.86, 0.45), Vector3(x0 - 0.6, 108.0, (gz0 + gz1) * 0.5), Vector3(0, -90.0, 0))
	# the company's name on the roof, lit
	label(root, "CITY CABS", font, 0.22, YELLOW, Vector3(x0 + 20.0, bh + 34.0, -250.0), Vector3(0, -90.0, 0))
	block(root, Vector3(x0 + 22.0, bh + 8.0, -170.0), Vector3(x0 + 24.0, bh + 30.0, -330.0), mat(Color(0.12, 0.12, 0.13), 0.5, 0.5))

# a cab parked in the garage: a body, a cabin with glass, wheels, the roof sign, the checker band
static func _cab(root: Node3D, pos: Vector3, rot: Vector3) -> void:
	var car: Node3D = Node3D.new()
	root.add_child(car)
	car.position = pos
	car.rotation_degrees = rot
	var paint: StandardMaterial3D = mat(YELLOW, 0.3, 0.1)
	put(car, rbox_mesh(23.0, 10.5, 11.0, 3.0, 2.0), paint, Vector3(0, 3.0, 0))
	put(car, rbox_mesh(12.0, 9.0, 8.0, 2.5, 2.0), mat(Color(0.08, 0.09, 0.12), 0.1, 0.3), Vector3(-1.0, 13.0, 0))
	put(car, rbox_mesh(12.2, 9.2, 2.0, 2.6, 1.0), paint, Vector3(-1.0, 20.0, 0))
	box(car, Vector3(5.0, 3.0, 9.0), glow(Color(1.0, 0.88, 0.50)), Vector3(-1.0, 23.5, 0))
	var tire: StandardMaterial3D = mat(Color(0.04, 0.04, 0.04), 0.8)
	for wx in [-14.0, 14.0]:
		for wz in [-9.5, 9.5]:
			cyl(car, 4.6, 4.6, 3.6, tire, Vector3(wx, 4.6, wz), 20, Vector3(90.0, 0, 0))
	for k in 10:
		box(car, Vector3(4.0, 1.4, 0.4), mat(Color(0.05, 0.05, 0.05), 0.5), Vector3(-20.0 + float(k) * 4.0 + 2.0, 9.6 + 1.4 * float(k % 2), 10.7))

# THE CANOPY: steel columns on plinths, a thick slab, the checker round its fascia, CITY CABS on the road side,
# recessed light panels in its underside
static func _canopy(root: Node3D, font: Font) -> void:
	var c_h: float = 110.0
	var cx0: float = ROAD + WALK + 30.0
	var cx1: float = ST_BACK - 50.0
	var cz0: float = PUMP_Z + 170.0
	var cz1: float = PUMP_Z - 190.0
	var steel: StandardMaterial3D = mat(Color(0.80, 0.82, 0.86), 0.3, 0.3)
	for cz in [PUMP_Z + 62.0, PUMP_Z - 62.0]:
		cyl(root, 4.0, 4.0, c_h - 10.0, steel, Vector3(ISLAND_X, 10.0 + (c_h - 10.0) * 0.5, cz), 32)
		cyl(root, 7.0, 7.5, 3.0, steel, Vector3(ISLAND_X, 11.5, cz), 32)
	var white: StandardMaterial3D = mat(Color(0.90, 0.91, 0.93), 0.5)
	block(root, Vector3(cx0, c_h, cz1), Vector3(cx1, c_h + 20.0, cz0), white)
	# the underside's recessed light panels
	for lx in [cx0 + 30.0, (cx0 + cx1) * 0.5, cx1 - 30.0]:
		for lz in [cz0 - 50.0, PUMP_Z, cz1 + 50.0]:
			box(root, Vector3(20.0, 0.6, 20.0), glow(Color(1.0, 1.0, 0.96)), Vector3(lx, c_h - 0.2, lz))
	# the checker round the fascia (road side -x and near end +z), two rows, under a white band
	var dark: StandardMaterial3D = mat(Color(0.06, 0.06, 0.06), 0.5)
	var yel: StandardMaterial3D = mat(YELLOW, 0.4)
	var nq: int = int((cz0 - cz1) / 8.0)
	for q in nq:
		for r in 2:
			box(root, Vector3(0.6, 4.0, 8.0), dark if (q + r) % 2 == 0 else yel, Vector3(cx0 - 0.3, c_h + 3.5 + float(r) * 4.0, cz0 - 4.0 - float(q) * 8.0))
	var nf: int = int((cx1 - cx0) / 8.0)
	for q2 in nf:
		for r2 in 2:
			box(root, Vector3(8.0, 4.0, 0.6), dark if (q2 + r2) % 2 == 0 else yel, Vector3(cx0 + 4.0 + float(q2) * 8.0, c_h + 3.5 + float(r2) * 4.0, cz0 + 0.3))
	label(root, "CITY CABS", font, 0.07, YELLOW, Vector3(cx0 - 0.8, c_h + 15.0, PUMP_Z), Vector3(0, -90.0, 0))

# THE PUMP ISLAND: a raised concrete island with yellow kerbs, bollards at its ends, two pumps
static func _island(root: Node3D) -> void:
	var conc: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex(64, Color(0.66, 0.64, 0.61), 0.12, 5))
	put(root, rbox_mesh(14.0, 72.0, 6.0, 6.0, 1.5), conc, Vector3(ISLAND_X, 4.1, PUMP_Z))
	put(root, rbox_mesh(14.4, 72.4, 1.5, 6.2, 0.5), mat(YELLOW, 0.5), Vector3(ISLAND_X, 4.1, PUMP_Z))
	var bol: StandardMaterial3D = mat(YELLOW, 0.35)
	var band: StandardMaterial3D = mat(Color(0.05, 0.05, 0.05), 0.5)
	for bz in [PUMP_Z + 78.0, PUMP_Z - 78.0]:
		cyl(root, 3.0, 3.0, 24.0, bol, Vector3(ISLAND_X, 4.1 + 12.0, bz), 24)
		cyl(root, 3.05, 3.05, 3.0, band, Vector3(ISLAND_X, 4.1 + 18.0, bz), 24)
		var cap: SphereMesh = SphereMesh.new()
		cap.radius = 3.0
		cap.height = 3.0
		cap.is_hemisphere = true
		put(root, cap, bol, Vector3(ISLAND_X, 4.1 + 24.0, bz))
	for pz in [PUMP_Z + 34.0, PUMP_Z - 34.0]:
		_pump(root, Vector3(ISLAND_X, 10.1, pz))

# ONE PUMP: a dark plinth, a rounded body in glossy white with a yellow band, a red head with a lit strip and the
# brand disc, the display in its bezel (the sale and the litres lit), grade buttons, a holster each side with its
# nozzle, a rubber hose looping down to each
static func _pump(root: Node3D, b: Vector3) -> void:
	var white: StandardMaterial3D = mat(Color(0.92, 0.92, 0.94), 0.18, 0.05)
	var red: StandardMaterial3D = mat(Color(0.80, 0.10, 0.08), 0.2, 0.05)
	var dark: StandardMaterial3D = mat(Color(0.05, 0.05, 0.06), 0.15, 0.2)
	var steel: StandardMaterial3D = mat(Color(0.80, 0.82, 0.86), 0.25, 0.4)
	var rubber: StandardMaterial3D = mat(Color(0.03, 0.03, 0.035), 0.55)
	put(root, rbox_mesh(10.0, 12.0, 4.0, 2.0, 1.0), dark, b)
	put(root, rbox_mesh(8.0, 10.0, 44.0, 3.0, 1.6), white, b + Vector3(0, 4.0, 0))
	put(root, rbox_mesh(8.1, 10.1, 4.0, 3.0, 0.5), mat(YELLOW, 0.3), b + Vector3(0, 16.0, 0))
	put(root, rbox_mesh(8.8, 10.8, 13.0, 3.5, 2.2), red, b + Vector3(0, 48.0, 0))
	box(root, Vector3(13.0, 1.6, 0.4), glow(Color(1.0, 0.97, 0.88)), b + Vector3(0, 56.0, 10.9))
	# the brand disc on the head, facing us and the road
	cyl(root, 3.2, 3.2, 0.6, mat(YELLOW, 0.3), b + Vector3(0, 52.0, 10.95), 24, Vector3(90.0, 0, 0))
	cyl(root, 3.2, 3.2, 0.6, mat(YELLOW, 0.3), b + Vector3(-8.95, 52.0, 0.0), 24, Vector3(0, 0, 90.0))
	# the display: bezel, lit screen with two lines of figures, its glass
	box(root, Vector3(12.0, 15.0, 1.0), dark, b + Vector3(0, 37.0, 9.9))
	box(root, Vector3(9.6, 4.0, 0.3), glow(Color(0.45, 0.95, 0.60)), b + Vector3(0, 40.0, 10.45))
	box(root, Vector3(9.6, 4.0, 0.3), glow(Color(0.45, 0.95, 0.60)), b + Vector3(0, 34.5, 10.45))
	box(root, Vector3(7.0, 1.0, 0.32), glow(Color(0.08, 0.30, 0.14)), b + Vector3(0.6, 40.0, 10.62))
	box(root, Vector3(7.0, 1.0, 0.32), glow(Color(0.08, 0.30, 0.14)), b + Vector3(0.6, 34.5, 10.62))
	# grade buttons under it
	for g in 3:
		var gc: Color = [Color(0.25, 0.70, 0.30), Color(0.95, 0.75, 0.15), Color(0.85, 0.20, 0.15)][g]
		box(root, Vector3(2.4, 2.4, 0.8), mat(gc, 0.3), b + Vector3(-3.4 + float(g) * 3.4, 27.0, 10.3))
	# holsters each side, the nozzles in them, the hoses
	for side in [-1.0, 1.0]:
		var hx: float = side * 8.9
		put(root, rbox_mesh(1.4, 2.4, 9.0, 0.8, 0.4), dark, b + Vector3(hx + side * 0.6, 20.0, 3.0))
		var noz: MeshInstance3D = put(root, rbox_mesh(1.0, 1.1, 10.0, 0.5, 0.3), steel, b + Vector3(hx + side * 1.6, 22.0, 3.0))
		noz.rotation_degrees = Vector3(0, 0, side * -16.0)
		var path: PackedVector3Array = PackedVector3Array()
		for k in 25:
			var u: float = float(k) / 24.0
			path.append(b + Vector3(hx + side * (0.4 + sin(u * PI) * 5.0), 44.0 - sin(u * PI) * 30.0 - u * 12.0, lerpf(-5.0, 3.0, u)))
		put(root, tube_mesh(path, 0.9, 10), rubber, Vector3.ZERO)

# THE PRICE SIGN at the forecourt's corner: twin steel legs, a box with the brand and the lit prices
static func _price_sign(root: Node3D, font: Font) -> void:
	var ps: Vector3 = Vector3(ROAD + WALK + 14.0, 4.1, ST_Z0 - 40.0)
	var steel: StandardMaterial3D = mat(Color(0.55, 0.57, 0.60), 0.35, 0.4)
	for lz in [12.0, -12.0]:
		cyl(root, 2.2, 2.2, 150.0, steel, ps + Vector3(0, 75.0, lz), 20)
	block(root, ps + Vector3(-5.0, 150.0, 24.0), ps + Vector3(5.0, 222.0, -24.0), mat(Color(0.10, 0.10, 0.11), 0.4))
	# the brand panel, lit, with the checker
	box(root, Vector3(0.4, 20.0, 42.0), glow(YELLOW), ps + Vector3(-5.2, 209.0, 0))
	label(root, "CITY CABS", font, 0.032, Color(0.06, 0.06, 0.06), ps + Vector3(-5.6, 209.0, 0), Vector3(0, -90.0, 0))
	for k in 2:
		var py: float = 166.0 + float(k) * 18.0
		box(root, Vector3(0.4, 14.0, 42.0), glow(Color(0.04, 0.04, 0.05)), ps + Vector3(-5.2, py, 0))
		label(root, ["1.89", "2.04"][k], font, 0.07, Color(1.0, 0.45, 0.22), ps + Vector3(-5.6, py, 4.0), Vector3(0, -90.0, 0))
		label(root, ["REG", "PREM"][k], font, 0.025, Color(0.9, 0.9, 0.9), ps + Vector3(-5.6, py, -13.0), Vector3(0, -90.0, 0))

# small things: a bin and an air stand beside the island
static func _props(root: Node3D) -> void:
	cyl(root, 5.0, 4.5, 16.0, mat(Color(0.12, 0.28, 0.18), 0.5, 0.2), Vector3(ISLAND_X, 10.1 + 8.0, PUMP_Z + 92.0), 24)
	put(root, rbox_mesh(4.0, 4.0, 30.0, 1.2, 0.6), mat(Color(0.20, 0.35, 0.65), 0.3), Vector3(ST_BACK - 20.0, 4.1, -60.0))
