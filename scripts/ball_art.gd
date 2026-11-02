extends Control
class_name BallArt

# A BUCKETMADNESS ITEM AS TWO BILLIARD BALLS (2026-11-02): glossy ivory balls side by side, each
# carrying one of the pair's two items on a dark round label in its exact color -- the pair stays two
# equal, separate things. They roll down the pool table (scripts/chute_view.gd) into a pocket
# (scripts/bucket_view.gd).
#
# Cheap on a phone, like the parcels (scripts/parcel_art.gd): the ivory sphere is rendered in 3-D ONCE
# per pixel size and cached; the labels, the roll and the gloss are 2-D on top. A label is a cap
# printed on the sphere: turned theta away from the viewer it projects to an ellipse centred
# R*cos(a)*sin(theta) off the middle with semi-axes R*sin(a) and R*sin(a)*cos(theta) (sin(a) = LABEL).
#
# While the balls are in play they only ROCK (the labels sway a little along the roll), never turn
# right over: the player is reading them the whole time they fall. They spin properly only as they
# drop into the pocket (spin()).
#
# Usage: BallArt.make(host, Vector2(w, h), left, right, seed), left / right being {"text": "7"} or
# {"shape": "★"} with "color" (and optionally "font").

const LABEL: float = 0.60              # the label's radius, as a share of the ball's
const GAP: float = 0.10                # the gap between the balls, as a share of a ball's diameter
const TAG: Color = Color(0.110, 0.122, 0.157)
const TAG_EDGE: Color = Color(0.95, 0.92, 0.84)

static var _sphere: Dictionary = {}     # px -> ImageTexture (null while rendering)

var _descs: Array = []
var _phase: Array = [0.0, 0.0]
var _t: float = 0.0
var _spin: float = -1.0                 # <0 rocking; else turned this far (radians) into the drop
var _px: int = 64
# The two balls side by side (the game), or along the diagonal (the chooser tile, where it fits
# bigger balls in a square).
var diagonal: bool = false
# THE DROP INTO A POCKET (sink_into): each ball rolls to the hole's centre, shrinking to the hole's
# size as it goes (it is going down, away from us), then falls in -- smaller and darker -- the second
# a beat behind the first. The stage draws the hole under them, so they visibly go INTO it.
const SINK_TIME: float = 0.60
var _sink: float = -1.0
var _sink_to: Vector2 = Vector2.ZERO
var _hole: float = 20.0

static func make(host: Node, unit_size: Vector2, left: Dictionary, right: Dictionary, seed_i: int, diag: bool = false) -> BallArt:
	var b: BallArt = BallArt.new()
	b.size = unit_size
	b.diagonal = diag
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._descs = [left, right]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_i
	b._phase = [r.randf() * TAU, r.randf() * TAU]
	var scale_px: float = 1.0
	if host.is_inside_tree():
		scale_px = clampf(host.get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	b._px = int(ceilf(b._diameter() * scale_px / 16.0) * 16.0)
	_ensure_sphere(host, b._px)
	return b

func _diameter() -> float:
	if diagonal:
		# centers at +/-(r + gap/2) along the diagonal: (r + gap/2) * 0.707 + r fits half the side
		var half: float = minf(size.x, size.y) * 0.5
		return 2.0 * half / (1.0 + 0.7071 * (1.0 + GAP)) * 0.97
	return minf(size.y * 0.94, size.x / (2.0 + GAP))

func _process(delta: float) -> void:
	_t += delta
	if _spin >= 0.0:
		_spin += delta * 14.0
	if _sink >= 0.0:
		_sink += delta / SINK_TIME
	queue_redraw()

# The drop into the pocket: the balls turn right over as they go.
func spin() -> void:
	_spin = 0.0

# Roll into the pocket whose centre is `to` (this control's coordinates) and drop in.
func sink_into(to: Vector2, hole_r: float) -> void:
	_sink_to = to
	_hole = hole_r
	_sink = 0.0
	spin()

func _draw() -> void:
	var d: float = _diameter()
	var r: float = d * 0.5
	var tex: Texture2D = _sphere.get(_px, null)
	var dir: Vector2 = Vector2(0.7071, 0.7071) if diagonal else Vector2(1.0, 0.0)
	for k in 2:
		var c: Vector2 = size * 0.5 + dir * (-1.0 if k == 0 else 1.0) * (r + d * GAP * 0.5)
		if _sink < 0.0:
			_draw_ball(c, r, tex, k, 0.0)
			continue
		var tk: float = clampf((_sink - 0.18 * float(k)) / 0.82, 0.0, 1.0)
		if tk >= 1.0:
			continue
		var roll: float = clampf(tk / 0.72, 0.0, 1.0)
		var e: float = roll * roll * (3.0 - 2.0 * roll)
		var rr: float = lerpf(r, minf(r, _hole * 0.92), e)
		var fall: float = clampf((tk - 0.72) / 0.28, 0.0, 1.0)
		_draw_ball(c.lerp(_sink_to, e), rr * (1.0 - 0.7 * fall), tex, k, fall)

func _draw_ball(c: Vector2, r: float, tex: Texture2D, k: int, fall: float) -> void:
	# its shadow on the felt, a little toward the viewer (the lamp is overhead and behind) -- gone once
	# it is dropping into the hole
	for g in (3 if fall <= 0.0 else 0):
		draw_set_transform(c + Vector2(r * 0.12, r * 0.92), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, r * (0.92 - 0.12 * float(g)), Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tex != null:
		var full: float = r * 2.1
		draw_texture_rect(tex, Rect2(c - Vector2(full, full) * 0.5, Vector2(full, full)), false)
	else:
		draw_circle(c, r, Color(0.93, 0.90, 0.82))
	# the label, turned: rocking along the roll (downward) in play, all the way over in the drop
	var theta: float = 0.22 * sin(_t * 3.2 + float(_phase[k]))
	if _spin >= 0.0:
		theta = _spin + float(_phase[k]) * 0.1
	var ct: float = cos(theta)
	if ct > 0.02:
		var lr: float = r * LABEL
		var cos_a: float = sqrt(1.0 - LABEL * LABEL)
		var phi: float = PI * 0.5
		var off: Vector2 = Vector2.from_angle(phi) * r * cos_a * sin(theta)
		var xf: Transform2D = Transform2D(phi, c + off) * Transform2D(0.0, Vector2(ct, 1.0), 0.0, Vector2.ZERO) * Transform2D(-phi, Vector2.ZERO)
		draw_set_transform_matrix(xf)
		var dim: float = 0.25 * (1.0 - ct)          # turned away, it falls into the ball's shading
		draw_circle(Vector2.ZERO, lr, TAG.darkened(dim))
		draw_arc(Vector2.ZERO, lr, 0.0, TAU, 48, TAG_EDGE.darkened(dim), maxf(1.5, r * 0.05), true)
		var desc: Dictionary = _descs[k]
		var col: Color = (desc.get("color", Sleek.PALETTE["WHITE"]) as Color).darkened(dim)
		if desc.has("shape"):
			var side: float = lr * 1.25
			Sleek.draw_shape(self, str(desc["shape"]), Rect2(-side * 0.5, -side * 0.5, side, side), col)
		else:
			var f: Font = desc.get("font", MainGlobals.get_system_sans_font())
			var txt: String = str(desc["text"])
			var fs: int = int(lr * 1.15)
			while fs > 8 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lr * 1.6:
				fs -= 1
			var sz: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var base: Vector2 = Vector2(-sz.x * 0.5, (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
			draw_string_outline(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.08)), Color(0.04, 0.05, 0.08, 0.9))
			draw_string(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the gloss over everything, label included: it is a shiny ball
	draw_set_transform(c + Vector2(-r * 0.38, -r * 0.42), -0.6, Vector2(1.0, 0.6))
	for g2 in 4:
		draw_circle(Vector2.ZERO, r * (0.30 - 0.06 * float(g2)), Color(1, 1, 1, 0.10 + 0.07 * float(g2)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# falling into the hole: into its dark
	if fall > 0.0:
		draw_circle(c, r * 1.02, Color(0.0, 0.0, 0.0, 0.85 * fall))

# --- the sphere, rendered once per pixel size ------------------------------------------------------

static func _ensure_sphere(host: Node, px: int) -> void:
	if _sphere.has(px) or not host.is_inside_tree():
		return
	_sphere[px] = null
	var rn: _SphereRenderer = _SphereRenderer.new()
	rn.px = px
	host.add_child(rn)

class _SphereRenderer extends Node:
	var px: int = 64

	func _ready() -> void:
		var vp: SubViewport = SubViewport.new()
		var full: int = int(ceilf(float(px) * 1.05))
		vp.size = Vector2i(full, full)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env: WorldEnvironment = WorldEnvironment.new()
		var e: Environment = Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.92, 0.86, 0.78)
		e.ambient_light_energy = 0.55
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		vp.add_child(env)
		var key: DirectionalLight3D = DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
		key.light_color = Color(1.0, 0.92, 0.80)
		key.light_energy = 1.0
		vp.add_child(key)
		var rim: DirectionalLight3D = DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
		rim.light_color = Color(1.0, 0.75, 0.45)
		rim.light_energy = 0.45
		vp.add_child(rim)
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.1
		cam.position = Vector3(0, 0, 3)
		vp.add_child(cam)
		var ball: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 48
		sm.rings = 24
		ball.mesh = sm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.98, 0.96, 0.91)
		m.roughness = 0.16
		m.metallic_specular = 0.8
		ball.material_override = m
		vp.add_child(ball)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if is_inside_tree():
			BallArt._sphere[px] = ImageTexture.create_from_image(vp.get_texture().get_image())
		else:
			BallArt._sphere.erase(px)
		queue_free()
