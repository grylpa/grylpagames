extends RefCounted
class_name BottleArt

# BEER BOTTLES standing on the pool table's rails in Pockets (bucketmadness), as real 3-D (2026-11-02):
# four different bottles turned on a lathe -- glass body, shoulder, neck, a cap on top and a base
# below -- each with a paper label wrapped round it, lit like the room. A flat drawing read as a can.
#
#   0  brown longneck, cream label with a red band, gold cap
#   1  dark brown bottle, white label with a red band and gold foil round the neck, gold cap (no green
#      bottles: the user's call)
#   2  amber stubby, blue label, silver cap
#   3  clear bottle with the beer showing in it, black-and-gold label, red cap
#
# Rendered ONCE per pixel height, all four in one viewport side by side, then cut into four textures;
# texture() is null until they exist (the caller polls and draws nothing that frame).

const KINDS: int = 4
const CELL: float = 4.0                 # world units between bottles in the render
const VIEW_H: float = 8.2               # world units the camera sees top to bottom
const ASPECT: float = CELL / VIEW_H     # width / height of each bottle's texture

static var _sets: Dictionary = {}       # px_h -> Array of 4 textures (empty while rendering)

static func texture(host: Node, kind: int, px_h: int) -> Texture2D:
	if not _sets.has(px_h):
		if not host.is_inside_tree():
			return null
		_sets[px_h] = []
		var rn: _Renderer = _Renderer.new()
		rn.px_h = px_h
		host.add_child(rn)
		return null
	var arr: Array = _sets[px_h]
	return arr[kind % KINDS] if arr.size() == KINDS else null

class _Renderer extends Node:
	var px_h: int = 128

	func _ready() -> void:
		var px_w: int = int(round(float(px_h) * ASPECT))
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(px_w * KINDS, px_h)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env: WorldEnvironment = WorldEnvironment.new()
		var e: Environment = Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.85, 0.82, 0.70)
		e.ambient_light_energy = 0.45
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		vp.add_child(env)
		var key: DirectionalLight3D = DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)       # the lamp, above and to the left
		key.light_color = Color(1.0, 0.92, 0.75)
		key.light_energy = 1.0
		vp.add_child(key)
		var rim: DirectionalLight3D = DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
		rim.light_color = Color(1.0, 0.85, 0.6)
		rim.light_energy = 0.5
		vp.add_child(rim)
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = VIEW_H
		var aim: Vector3 = Vector3(0.0, 3.6, 0.0)
		var pitch: float = deg_to_rad(16.0)                     # we look a little down onto the rail
		cam.position = aim + Vector3(0.0, sin(pitch), cos(pitch)) * 30.0
		vp.add_child(cam)
		cam.look_at(aim)
		for k in KINDS:
			var x: float = (float(k) - float(KINDS - 1) * 0.5) * CELL
			_bottle(vp, k, Vector3(x, 0.0, 0.0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			BottleArt._sets.erase(px_h)
			queue_free()
			return
		var img: Image = vp.get_texture().get_image()
		var out: Array = []
		for k2 in KINDS:
			out.append(ImageTexture.create_from_image(img.get_region(Rect2i(k2 * px_w, 0, px_w, px_h))))
		BottleArt._sets[px_h] = out
		queue_free()

	# --- one bottle: a lathe profile (radius, height) from the base up, the label band, the cap ---
	func _bottle(vp: SubViewport, kind: int, at: Vector3) -> void:
		var prof: Array
		var glass: Color
		var cap: Color
		var label_y: Vector2
		var label_tex: ImageTexture
		var neck_foil: bool = false
		var see_through: bool = false
		match kind:
			0:
				prof = [Vector2(0.0, 0.0), Vector2(0.92, 0.0), Vector2(1.0, 0.12), Vector2(1.0, 3.1), Vector2(0.92, 3.6),
					Vector2(0.55, 4.3), Vector2(0.38, 4.9), Vector2(0.36, 6.4), Vector2(0.42, 6.55), Vector2(0.0, 6.6)]
				glass = Color(0.30, 0.13, 0.03)
				cap = Color(0.85, 0.68, 0.25)
				label_y = Vector2(0.9, 2.6)
				label_tex = _label_tex(Color(0.94, 0.90, 0.78), Color(0.78, 0.15, 0.12), Color(0.25, 0.12, 0.05))
			1:
				prof = [Vector2(0.0, 0.0), Vector2(0.98, 0.0), Vector2(1.08, 0.14), Vector2(1.08, 3.3), Vector2(0.98, 3.8),
					Vector2(0.52, 4.6), Vector2(0.40, 5.1), Vector2(0.38, 6.2), Vector2(0.44, 6.35), Vector2(0.0, 6.4)]
				glass = Color(0.16, 0.07, 0.02)
				cap = Color(0.85, 0.68, 0.25)
				label_y = Vector2(1.0, 2.8)
				label_tex = _label_tex(Color(0.96, 0.96, 0.93), Color(0.70, 0.12, 0.10), Color(0.70, 0.55, 0.20))
				neck_foil = true
			2:
				prof = [Vector2(0.0, 0.0), Vector2(1.06, 0.0), Vector2(1.16, 0.14), Vector2(1.16, 2.5), Vector2(1.02, 3.0),
					Vector2(0.55, 3.6), Vector2(0.42, 4.0), Vector2(0.40, 4.6), Vector2(0.46, 4.75), Vector2(0.0, 4.8)]
				glass = Color(0.55, 0.30, 0.06)
				cap = Color(0.80, 0.82, 0.85)
				label_y = Vector2(0.7, 2.1)
				label_tex = _label_tex(Color(0.15, 0.30, 0.62), Color(0.95, 0.95, 0.95), Color(0.95, 0.85, 0.40))
			_:
				prof = [Vector2(0.0, 0.0), Vector2(0.90, 0.0), Vector2(0.98, 0.12), Vector2(0.98, 3.2), Vector2(0.90, 3.7),
					Vector2(0.50, 4.4), Vector2(0.36, 5.0), Vector2(0.34, 6.3), Vector2(0.40, 6.45), Vector2(0.0, 6.5)]
				glass = Color(0.80, 0.86, 0.80, 0.38)
				cap = Color(0.80, 0.16, 0.12)
				label_y = Vector2(1.0, 2.5)
				label_tex = _label_tex(Color(0.08, 0.08, 0.09), Color(0.85, 0.68, 0.25), Color(0.85, 0.68, 0.25))
				see_through = true
		# the beer inside the clear bottle, up to the shoulder
		if see_through:
			var beer: Array = [Vector2(0.0, 0.08), Vector2(0.92, 0.08), Vector2(0.92, 3.3), Vector2(0.0, 3.3)]
			var bm: StandardMaterial3D = StandardMaterial3D.new()
			bm.albedo_color = Color(0.85, 0.58, 0.12)
			bm.roughness = 0.3
			_add(vp, _lathe(beer, 0.0, 1.0), bm, at)
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = glass
		gm.roughness = 0.06
		gm.metallic_specular = 0.9
		if see_through:
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add(vp, _lathe(prof, 0.0, 1.0), gm, at)
		# the paper label, wrapped round the body just proud of the glass
		# (the body's full width: the profile has no points inside the label's span, only at its ends)
		var body_r: float = 0.0
		for p: Vector2 in prof:
			body_r = maxf(body_r, p.x)
		var lm: StandardMaterial3D = StandardMaterial3D.new()
		lm.albedo_texture = label_tex
		lm.roughness = 0.7
		_add(vp, _lathe([Vector2(body_r * 1.012, label_y.x), Vector2(body_r * 1.012, label_y.y)], 0.0, 1.0, true), lm, at)
		# gold foil round the neck
		var top_y: float = (prof[prof.size() - 1] as Vector2).y
		if neck_foil:
			var fm: StandardMaterial3D = StandardMaterial3D.new()
			fm.albedo_color = Color(0.80, 0.64, 0.25)
			fm.metallic = 0.8
			fm.roughness = 0.3
			_add(vp, _lathe([Vector2(0.42, top_y - 1.5), Vector2(0.41, top_y - 0.1)], 0.0, 1.0, true), fm, at)
		# the crown cap: a short fluted cylinder with its top closed
		var cm: StandardMaterial3D = StandardMaterial3D.new()
		cm.albedo_color = cap
		cm.metallic = 0.6
		cm.roughness = 0.35
		var cap_prof: Array = [Vector2(0.47, top_y - 0.35), Vector2(0.47, top_y + 0.05), Vector2(0.40, top_y + 0.12), Vector2(0.0, top_y + 0.13)]
		_add(vp, _lathe(cap_prof, 0.06, 18.0), cm, at)

	func _add(vp: SubViewport, mesh: Mesh, mat: Material, at: Vector3) -> void:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.position = at
		vp.add_child(mi)

	# A surface of revolution from `prof` (radius, height), 40 segments round. `flute` ripples the
	# radius `flute_n` times round (a crown cap's crimps). `open` leaves it a band (a label, foil).
	func _lathe(prof: Array, flute: float, flute_n: float, _open: bool = false) -> Mesh:
		var seg: int = 40
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y0: float = (prof[0] as Vector2).y
		var y1: float = (prof[prof.size() - 1] as Vector2).y
		var span: float = maxf(y1 - y0, 0.001)
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			var slope: Vector2 = (b - a)
			var nrm2: Vector2 = Vector2(slope.y, -slope.x).normalized()     # outward in (r, y)
			for k in seg:
				var t0: float = float(k) / float(seg)
				var t1: float = float(k + 1) / float(seg)
				var quad: Array = []
				for c: Array in [[a, t0], [a, t1], [b, t1], [b, t0]]:
					var pr: Vector2 = c[0]
					var ang: float = float(c[1]) * TAU
					var r: float = pr.x * (1.0 + flute * sin(ang * flute_n))
					quad.append([Vector3(cos(ang) * r, pr.y, sin(ang) * r), Vector3(cos(ang) * nrm2.x, nrm2.y, sin(ang) * nrm2.x),
						Vector2(1.0 - float(c[1]), 1.0 - (pr.y - y0) / span)])
				for idx in [0, 2, 1, 0, 3, 2]:
					var q: Array = quad[idx]
					st.set_normal(q[1])
					st.set_uv(q[2])
					st.add_vertex(q[0])
		var m: ArrayMesh = st.commit()
		return m

	# A label's artwork, wrapped round the bottle: the paper, a band of colour across it, and a few
	# bars where the lettering would be -- centred on the side facing the viewer.
	func _label_tex(paper: Color, band: Color, ink: Color) -> ImageTexture:
		var img: Image = Image.create(256, 64, false, Image.FORMAT_RGBA8)
		img.fill(paper)
		img.fill_rect(Rect2i(0, 26, 256, 14), band)
		img.fill_rect(Rect2i(0, 2, 256, 2), ink)
		img.fill_rect(Rect2i(0, 60, 256, 2), ink)
		# the front of the label (u = 0.75 faces the camera after the lathe's mapping): a name and a crest
		var cx: int = 192
		img.fill_rect(Rect2i(cx - 20, 10, 40, 8), ink)
		img.fill_rect(Rect2i(cx - 14, 46, 28, 5), ink)
		for k in 6:
			img.fill_rect(Rect2i(cx - 22 + k * 8, 29, 5, 8), paper)
		return ImageTexture.create_from_image(img)
