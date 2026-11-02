extends RefCounted
class_name BridgeArt

# THE MECHANICAL BRIDGE standing against the wall in Pockets' billiard room, as real 3-D (2026-11-02):
# a turned wooden pole with a black butt and a chrome ferrule, and on top the head as the user described
# it -- two legs that stand on the cloth and a dent along the top for the cue -- bent from a THICK
# CHROME WIRE (a solid plate of that shape was "vulgar"), with a brace across the middle where the
# pole fits, turned a little so it reads in depth. Rendered ONCE per pixel height; texture() is null
# until it exists.
#
# (A drawn hook-hung rake, then a drawn cross, then a solid plate were the wrong things.)

const VIEW_H: float = 9.2              # world units the camera sees top to bottom
const ASPECT: float = 0.26             # texture width / height
const FOOT_Y: float = 0.96             # where the pole's foot is, as a share of the texture height

static var _tex: Dictionary = {}        # px_h -> ImageTexture (null while rendering)

static func texture(host: Node, px_h: int) -> Texture2D:
	if not _tex.has(px_h):
		if not host.is_inside_tree():
			return null
		_tex[px_h] = null
		var rn: _Renderer = _Renderer.new()
		rn.px_h = px_h
		host.add_child(rn)
		return null
	return _tex[px_h]

# The wire's path, in the head's own plane (x across, y up): up the left leg, across the top with the
# dent for the cue in the middle, down the right leg. And the brace across the middle, where the pole
# meets it.
const WIRE: Array = [Vector2(-0.92, -0.80), Vector2(-0.86, 0.05), Vector2(-0.74, 0.50), Vector2(-0.48, 0.68),
	Vector2(-0.22, 0.66), Vector2(-0.10, 0.48), Vector2(0.0, 0.40), Vector2(0.10, 0.48), Vector2(0.22, 0.66),
	Vector2(0.48, 0.68), Vector2(0.74, 0.50), Vector2(0.86, 0.05), Vector2(0.92, -0.80)]
const BRACE: Array = [Vector2(-0.87, -0.12), Vector2(0.87, -0.12)]

class _Renderer extends Node:
	var px_h: int = 256

	func _ready() -> void:
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(int(round(float(px_h) * ASPECT)), px_h)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env: WorldEnvironment = WorldEnvironment.new()
		var e: Environment = Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.80, 0.80, 0.72)
		e.ambient_light_energy = 0.45
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		vp.add_child(env)
		var key: DirectionalLight3D = DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-40.0, -40.0, 0.0)
		key.light_color = Color(1.0, 0.92, 0.75)
		key.light_energy = 1.0
		vp.add_child(key)
		var rim: DirectionalLight3D = DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
		rim.light_color = Color(1.0, 0.85, 0.6)
		rim.light_energy = 0.5
		vp.add_child(rim)
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = VIEW_H
		var foot_world: float = 0.0
		var aim: Vector3 = Vector3(0.0, foot_world + VIEW_H * (FOOT_Y - 0.5), 0.0)
		cam.position = aim + Vector3(0.0, 0.0, 30.0)
		vp.add_child(cam)
		cam.look_at(aim)
		var wood: StandardMaterial3D = StandardMaterial3D.new()
		wood.albedo_color = Color(0.62, 0.43, 0.23)
		wood.roughness = 0.45
		var black: StandardMaterial3D = StandardMaterial3D.new()
		black.albedo_color = Color(0.08, 0.07, 0.07)
		black.roughness = 0.35
		var chrome: StandardMaterial3D = StandardMaterial3D.new()
		chrome.albedo_color = Color(0.88, 0.90, 0.93)
		chrome.metallic = 0.45
		chrome.roughness = 0.20
		chrome.metallic_specular = 0.9
		var pole_top: float = 7.55
		_add(vp, _cylinder(0.10, 0.075, 0.0, pole_top), wood)
		_add(vp, _cylinder(0.105, 0.10, 0.0, 1.1), black)
		_add(vp, _cylinder(0.085, 0.085, pole_top - 0.30, pole_top + 0.05), chrome)
		for path: Array in [BridgeArt.WIRE, BridgeArt.BRACE]:
			var head: MeshInstance3D = MeshInstance3D.new()
			head.mesh = _tube(path, 0.11)
			chrome.cull_mode = BaseMaterial3D.CULL_DISABLED
			head.material_override = chrome
			# the brace sits on the pole's tip; the head is turned a little so it reads in depth
			head.position = Vector3(0.0, pole_top + 0.05, 0.0)
			# turned about the horizontal so its dent rests against the wall and the feet point out
			head.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(12.0), 0.0)
			head.scale = Vector3(0.30, 0.30, 0.30)
			vp.add_child(head)
		var hub: MeshInstance3D = MeshInstance3D.new()
		var hm: SphereMesh = SphereMesh.new()
		hm.radius = 0.09
		hm.height = 0.18
		hub.mesh = hm
		hub.material_override = chrome
		hub.position = Vector3(0.0, pole_top + 0.05, 0.0)
		vp.add_child(hub)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if is_inside_tree():
			BridgeArt._tex[px_h] = ImageTexture.create_from_image(vp.get_texture().get_image())
		else:
			BridgeArt._tex.erase(px_h)
		queue_free()

	func _add(vp: SubViewport, mesh: Mesh, mat: BaseMaterial3D) -> void:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		vp.add_child(mi)

	func _cylinder(r0: float, r1: float, y0: float, y1: float) -> Mesh:
		var cm: CylinderMesh = CylinderMesh.new()
		cm.bottom_radius = r0
		cm.top_radius = r1
		cm.height = y1 - y0
		cm.radial_segments = 24
		var st: SurfaceTool = SurfaceTool.new()
		st.create_from(cm, 0)
		var arr: Array = st.commit_to_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] += Vector3(0.0, (y0 + y1) * 0.5, 0.0)
		arr[Mesh.ARRAY_VERTEX] = verts
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	# A round wire of radius `r` along `path` (in the head's plane), smoothed through its points.
	func _tube(path: Array, r: float) -> Mesh:
		var pts: Array = []
		for i in path.size() - 1:
			var p0: Vector2 = path[maxi(i - 1, 0)]
			var p1: Vector2 = path[i]
			var p2: Vector2 = path[i + 1]
			var p3: Vector2 = path[mini(i + 2, path.size() - 1)]
			for k in 4:
				var t: float = float(k) / 4.0
				var t2: float = t * t
				var t3: float = t2 * t
				pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		pts.append(path[path.size() - 1])
		var ring: int = 10
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings: Array = []
		for i2 in pts.size():
			var a: Vector2 = pts[maxi(i2 - 1, 0)]
			var b: Vector2 = pts[mini(i2 + 1, pts.size() - 1)]
			var tg: Vector3 = Vector3((b - a).x, (b - a).y, 0.0).normalized()
			var side: Vector3 = tg.cross(Vector3(0, 0, 1)).normalized()
			var up: Vector3 = Vector3(0, 0, 1)
			var c: Vector3 = Vector3((pts[i2] as Vector2).x, (pts[i2] as Vector2).y, 0.0)
			var rr: Array = []
			for k2 in ring:
				var ang: float = TAU * float(k2) / float(ring)
				var n: Vector3 = side * cos(ang) + up * sin(ang)
				rr.append([c + n * r, n])
			rings.append(rr)
		for i3 in rings.size() - 1:
			for k3 in ring:
				var q: Array = [rings[i3][k3], rings[i3][(k3 + 1) % ring], rings[i3 + 1][(k3 + 1) % ring], rings[i3 + 1][k3]]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(q[idx][1])
					st.add_vertex(q[idx][0])
		return st.commit()
