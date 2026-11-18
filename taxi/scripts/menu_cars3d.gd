extends RefCounted

# TAXI POSTER'S CARS IN REAL 3-D (2026-11-18; the user: "can you improve the cars? they are childish and cartoonish"
# -- they were hand-projected 2-D panels). A see-through SubViewport over the baked city, its camera the poster's own
# (taxi/scripts/menu_world.gd `_camera`: the same eye, aim and focal length), the scene at 1:100 like the station's
# (menu_station3d.gd), lit by the street's own lights -- the lamps, the canopy, the garage -- and a dim moon. Each
# car is a LOFTED BODY: cross-sections along its length (a rounded lower body, a shoulder at the belt line, the
# glasshouse leaning in to the roof) joined into one smooth shell, with the glass a separate dark, glossy surface;
# chrome-rimmed wheels, bumpers, lenses lit front and back, mirrors, and for a cab its checker band and roof sign
# (lit when it is free). Depth FOG in the city's haze color: a car far down the avenue comes out of the haze, never
# popping in. A soft shadow lies under each.

const POOL: int = 28
const YELLOW: Color = Color(0.99, 0.78, 0.14)
const SEDANS: Array = [Color(0.10, 0.14, 0.24), Color(0.30, 0.06, 0.07), Color(0.42, 0.44, 0.48), Color(0.06, 0.06, 0.07)]

var holder: SubViewportContainer = null
var vp: SubViewport = null
var cam: Camera3D = null
var root: Node3D = null
var cars: Array = []          # per slot: [Node3D, paint material, sign material, sign node, checker nodes]

func build(host: Control, lights: Array, eye: Vector3, target: Vector3, focal_frac: float) -> void:
	holder = SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(holder)
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var top: Node3D = Node3D.new()
	vp.add_child(top)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.52, 0.68)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.16, 0.10, 0.13)
	env.fog_density = 1.0
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 34.0
	env.fog_sky_affect = 0.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	top.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.68, 0.92)
	moon.light_energy = 0.35
	top.add_child(moon)
	moon.rotation_degrees = Vector3(-55.0, -140.0, 0.0)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = rad_to_deg(2.0 * atan(0.5 / focal_frac))
	cam.near = 0.05
	cam.far = 60.0
	top.add_child(cam)
	cam.look_at_from_position(eye * 0.01, target * 0.01, Vector3.UP)
	cam.current = true
	root = Node3D.new()
	top.add_child(root)
	root.scale = Vector3.ONE * 0.01
	for lt in lights:
		var ol: OmniLight3D = OmniLight3D.new()
		ol.light_color = lt[1]
		ol.light_energy = 1.6
		ol.omni_range = float(lt[2]) * 4.0 * 0.01
		ol.omni_attenuation = 1.4
		root.add_child(ol)
		ol.position = lt[0]
	var shared: Dictionary = _materials()
	var body: ArrayMesh = _body_mesh(shared)
	for _k in POOL:
		cars.append(_make_car(body, shared))

# the viewport laid over the screen so that its center is the camera's center (the poster's `center`)
func place(center: Vector2, full: Vector2) -> void:
	var half_h: float = maxf(center.y, full.y - center.y)
	holder.position = Vector2(0.0, center.y - half_h)
	holder.size = Vector2(full.x, half_h * 2.0)

func set_shown(shown: bool) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED

# list: [position, heading, taxi?, busy?, paint index]
func set_cars(list: Array) -> void:
	for k in cars.size():
		var c: Array = cars[k]
		var node: Node3D = c[0]
		if k >= list.size():
			node.visible = false
			continue
		var it: Array = list[k]
		var p: Vector3 = it[0]
		var dir: Vector3 = Vector3((it[1] as Vector3).x, 0.0, (it[1] as Vector3).z).normalized()
		node.visible = true
		node.position = p
		node.rotation = Vector3(0.0, atan2(-dir.z, dir.x), 0.0)
		var taxi: bool = bool(it[2])
		var paint: StandardMaterial3D = c[1]
		paint.albedo_color = YELLOW if taxi else SEDANS[int(it[4]) % SEDANS.size()]
		(c[3] as Node3D).visible = taxi
		for ck in c[4]:
			(ck as Node3D).visible = taxi
		var sm: StandardMaterial3D = c[2]
		sm.emission_energy_multiplier = 2.4 if (taxi and not bool(it[3])) else 0.15

# --- the car ---------------------------------------------------------------------------------------------------

# the roof and belt lines along the car (x: back -24 .. front +24)
const TOP: Array = [Vector2(-24.0, 8.6), Vector2(-23.2, 11.2), Vector2(-21.0, 12.7), Vector2(-14.0, 13.5), Vector2(-9.5, 19.6),
	Vector2(-7.0, 21.0), Vector2(4.5, 21.3), Vector2(7.5, 19.8), Vector2(13.0, 13.9), Vector2(21.5, 12.6), Vector2(23.4, 10.6), Vector2(24.0, 8.2)]
const BELT: float = 13.6

func _top_at(x: float) -> float:
	for i in TOP.size() - 1:
		var a: Vector2 = TOP[i]
		var b: Vector2 = TOP[i + 1]
		if x <= b.x:
			var u: float = clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(a.y, b.y, u)
	return (TOP[TOP.size() - 1] as Vector2).y

# one cross-section, from the left sill round over the roof to the right sill: [point, is glass]
func _section(x: float) -> Array:
	var top: float = _top_at(x)
	var belt: float = minf(BELT, top - 0.4)
	var glass_house: bool = top > BELT + 1.0
	var end_k: float = clampf((24.0 - absf(x)) / 2.0, 0.0, 1.0)       # the ends drawn in, rounded
	var w: float = 10.5 * lerpf(0.86, 1.0, end_k)
	var half: Array = []
	half.append([Vector2(-w + 1.0, 2.6), false])
	half.append([Vector2(-w, 4.4), false])
	half.append([Vector2(-w - 0.15, belt - 2.4), false])
	half.append([Vector2(-w + 0.3, belt), false])
	if glass_house:
		half.append([Vector2(-w + 1.3, belt + 0.5), true])
		half.append([Vector2(-w + 3.0, top - 0.9), true])
		half.append([Vector2(-w + 4.0, top - 0.1), false])
	else:
		half.append([Vector2(-w + 1.2, lerpf(belt, top, 0.5)), false])
		half.append([Vector2(-w + 2.4, top - 0.15), false])
		half.append([Vector2(-w + 4.0, top), false])
	half.append([Vector2(0.0, top + 0.25), false])
	var ring: Array = half.duplicate()
	for i in range(half.size() - 2, -1, -1):
		var h: Array = half[i]
		ring.append([Vector2(-(h[0] as Vector2).x, (h[0] as Vector2).y), h[1]])
	return ring

func _body_mesh(m: Dictionary) -> ArrayMesh:
	var xs: Array = []
	var n_x: int = 40
	for i in n_x + 1:
		var u: float = float(i) / float(n_x)
		xs.append(-24.0 + 48.0 * (0.5 - 0.5 * cos(u * PI)))      # denser toward the rounded ends
	var rings: Array = []
	for x in xs:
		rings.append(_section(float(x)))
	var body_st: SurfaceTool = SurfaceTool.new()
	body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass_st: SurfaceTool = SurfaceTool.new()
	glass_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var npts: int = (rings[0] as Array).size()
	var pos: Array = []
	for i in rings.size():
		var row: Array = []
		for j in npts:
			var pt: Vector2 = (rings[i][j] as Array)[0]
			row.append(Vector3(float(xs[i]), pt.y, pt.x))
		pos.append(row)
	# smooth normals: across the section and along the car
	var nrm: Array = []
	for i in rings.size():
		var row2: Array = []
		for j in npts:
			var along: Vector3 = (pos[mini(i + 1, rings.size() - 1)][j] as Vector3) - (pos[maxi(i - 1, 0)][j] as Vector3)
			var across: Vector3 = (pos[i][mini(j + 1, npts - 1)] as Vector3) - (pos[i][maxi(j - 1, 0)] as Vector3)
			var nn: Vector3 = across.cross(along).normalized()
			var outward: Vector3 = (pos[i][j] as Vector3) - Vector3(float(xs[i]), 10.0, 0.0)
			if nn.dot(outward) < 0.0:
				nn = -nn
			row2.append(nn)
		nrm.append(row2)
	for i in rings.size() - 1:
		var x_mid: float = (float(xs[i]) + float(xs[i + 1])) * 0.5
		for j in npts - 1:
			var glass: bool = bool((rings[i][j] as Array)[1]) and bool((rings[i][j + 1] as Array)[1] or (rings[i][j] as Array)[1])
			# the windshield and the rear window across the roof's slopes, and the B pillar on the side glass
			var top_face: bool = j >= 5 and j < npts - 6
			if top_face and ((x_mid > 7.6 and x_mid < 12.8) or (x_mid > -13.8 and x_mid < -9.6)):
				glass = true
			if glass and not top_face and x_mid > -1.6 and x_mid < -0.2:
				glass = false
			var st: SurfaceTool = glass_st if glass else body_st
			var quad: Array = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for q in quad:
				st.set_normal(nrm[q[0]][q[1]])
				st.add_vertex(pos[q[0]][q[1]])
	# close the two ends (fans to the section's center)
	for e in [0, rings.size() - 1]:
		var cen: Vector3 = Vector3(float(xs[e]), 7.0, 0.0)
		var en: Vector3 = Vector3(signf(float(xs[e])), 0.0, 0.0)
		for j in npts - 1:
			for v in [cen, pos[e][j], pos[e][j + 1]]:
				body_st.set_normal(en)
				body_st.add_vertex(v)
	var mesh: ArrayMesh = body_st.commit()
	mesh.surface_set_material(0, m["paint"])
	glass_st.commit(mesh)
	mesh.surface_set_material(1, m["glass"])
	return mesh

func _materials() -> Dictionary:
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.06, 0.08)
	glass.metallic = 0.6
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var chrome: StandardMaterial3D = StandardMaterial3D.new()
	chrome.albedo_color = Color(0.82, 0.84, 0.88)
	chrome.metallic = 0.95
	chrome.roughness = 0.18
	var rubber: StandardMaterial3D = StandardMaterial3D.new()
	rubber.albedo_color = Color(0.04, 0.04, 0.045)
	rubber.roughness = 0.85
	var trim: StandardMaterial3D = StandardMaterial3D.new()
	trim.albedo_color = Color(0.10, 0.10, 0.11)
	trim.roughness = 0.5
	var head: StandardMaterial3D = StandardMaterial3D.new()
	head.albedo_color = Color(1.0, 0.97, 0.88)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.95, 0.82)
	head.emission_energy_multiplier = 3.0
	var tail: StandardMaterial3D = StandardMaterial3D.new()
	tail.albedo_color = Color(0.8, 0.08, 0.06)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.12, 0.08)
	tail.emission_energy_multiplier = 2.2
	var checker: StandardMaterial3D = StandardMaterial3D.new()
	var img: Image = Image.create(20, 2, false, Image.FORMAT_RGB8)
	for x in 20:
		for y in 2:
			img.set_pixel(x, y, Color(0.04, 0.04, 0.04) if (x + y) % 2 == 0 else Color(0.95, 0.92, 0.80))
	checker.albedo_texture = ImageTexture.create_from_image(img)
	checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	checker.roughness = 0.4
	var shadow: StandardMaterial3D = StandardMaterial3D.new()
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gg: Gradient = Gradient.new()
	gg.set_color(0, Color(0, 0, 0, 0.75))
	gg.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = gg
	shadow.albedo_texture = gt
	return {"paint": null, "glass": glass, "chrome": chrome, "rubber": rubber, "trim": trim, "head": head, "tail": tail,
		"checker": checker, "shadow": shadow}

func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	mi.rotation_degrees = rot
	return mi

func _make_car(body: ArrayMesh, m: Dictionary) -> Array:
	var node: Node3D = Node3D.new()
	root.add_child(node)
	node.visible = false
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = YELLOW
	paint.metallic = 0.35
	paint.roughness = 0.28
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.06
	var bmi: MeshInstance3D = MeshInstance3D.new()
	bmi.mesh = body
	bmi.set_surface_override_material(0, paint)
	node.add_child(bmi)
	# the shadow under it
	var sq: QuadMesh = QuadMesh.new()
	sq.size = Vector2(62.0, 30.0)
	_add(node, sq, m["shadow"], Vector3(0.0, 0.5, 0.0), Vector3(-90.0, 0.0, 0.0))
	# the wheels: tire, chrome rim, hub
	var tire: CylinderMesh = CylinderMesh.new()
	tire.top_radius = 4.7
	tire.bottom_radius = 4.7
	tire.height = 3.4
	tire.radial_segments = 20
	var rim: CylinderMesh = CylinderMesh.new()
	rim.top_radius = 2.9
	rim.bottom_radius = 2.9
	rim.height = 3.6
	rim.radial_segments = 16
	for wx in [-14.5, 14.0]:
		for wz in [-9.0, 9.0]:
			_add(node, tire, m["rubber"], Vector3(wx, 4.7, wz), Vector3(90.0, 0.0, 0.0))
			_add(node, rim, m["chrome"], Vector3(wx, 4.7, wz), Vector3(90.0, 0.0, 0.0))
	# bumpers, a grille, mirrors
	var bump: BoxMesh = BoxMesh.new()
	bump.size = Vector3(2.2, 3.2, 20.6)
	_add(node, bump, m["chrome"], Vector3(24.2, 5.4, 0.0))
	_add(node, bump, m["trim"], Vector3(-24.2, 5.6, 0.0))
	var grille: BoxMesh = BoxMesh.new()
	grille.size = Vector3(0.6, 2.4, 9.0)
	_add(node, grille, m["trim"], Vector3(24.05, 8.8, 0.0))
	var mirror: BoxMesh = BoxMesh.new()
	mirror.size = Vector3(1.6, 1.4, 2.0)
	for mz in [-1.0, 1.0]:
		_add(node, mirror, m["trim"], Vector3(11.4, 14.6, mz * 11.0))
	# the lenses: headlamps in the nose, tail lamps in the back
	var lens: SphereMesh = SphereMesh.new()
	lens.radius = 1.6
	lens.height = 2.0
	for lz in [-6.8, 6.8]:
		var hl: MeshInstance3D = _add(node, lens, m["head"], Vector3(23.6, 9.7, lz))
		hl.scale = Vector3(0.5, 0.9, 1.6)
		var tl: MeshInstance3D = _add(node, lens, m["tail"], Vector3(-23.7, 10.2, lz))
		tl.scale = Vector3(0.5, 0.9, 1.6)
	# a cab's checker band along each flank, and its roof sign
	var checks: Array = []
	var band: QuadMesh = QuadMesh.new()
	band.size = Vector2(38.0, 1.5)
	for sz in [-1.0, 1.0]:
		var bq: MeshInstance3D = _add(node, band, m["checker"], Vector3(-1.0, 10.4, sz * 10.68), Vector3(0.0, 0.0 if sz > 0.0 else 180.0, 0.0))
		checks.append(bq)
	var sign_m: StandardMaterial3D = StandardMaterial3D.new()
	sign_m.albedo_color = Color(1.0, 0.92, 0.60)
	sign_m.emission_enabled = true
	sign_m.emission = Color(1.0, 0.80, 0.35)
	sign_m.emission_energy_multiplier = 2.4
	var sign_node: Node3D = Node3D.new()
	node.add_child(sign_node)
	sign_node.position = Vector3(-1.0, 22.6, 0.0)
	var sb: BoxMesh = BoxMesh.new()
	sb.size = Vector3(4.5, 2.8, 10.0)
	_add(sign_node, sb, sign_m, Vector3.ZERO)
	var foot: BoxMesh = BoxMesh.new()
	foot.size = Vector3(3.5, 0.8, 7.0)
	_add(sign_node, foot, m["trim"], Vector3(0.0, -1.6, 0.0))
	for sd in [-1.0, 1.0]:
		var lb: Label3D = Label3D.new()
		lb.text = "TAXI"
		lb.font_size = 32
		lb.pixel_size = 0.07
		lb.modulate = Color(0.12, 0.08, 0.02)
		lb.outline_size = 0
		lb.shaded = false
		sign_node.add_child(lb)
		lb.position = Vector3(sd * 2.3, 0.0, 0.0)
		lb.rotation_degrees = Vector3(0.0, 90.0 if sd > 0.0 else -90.0, 0.0)
	return [node, paint, sign_m, sign_node, checks]
