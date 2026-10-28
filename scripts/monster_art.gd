class_name MonsterArt
extends Node2D

# The drawn look of the route games' MONSTERS -- the "Enemy" head of scenes/head_anim.tscn (Gorilla,
# Storm, Wolves, Mind Palace, Detour) and Detour's "EnemyBody" segments (parkem/scenes/
# tube_animation.tscn). They were white images tinted per game: a spotted blob for a head and
# ovals ringed with yellow spikes for a body.
#
# Now a menacing bug: the head a shell with a dark armored crown and long swept-back horns, glowing
# amber slit eyes slanted into a scowl, and two curved fangs that snap; a body segment a large
# armored plate (bigger than the old oval) with side spines, two bands, a dark ridge and four long
# jointed legs that scuttle. (A first, rounder version with white eyes and feelers looked friendly.) Facing +x, drawn in the 32 units
# the 128 px frames were shown at.
#
# HOW IT GETS THERE, as with DockArt: `MainGlobals` hands every AnimatedSprite2D entering the tree to
# `watch()`, and one whose frames include a monster animation gets this as a SIBLING of the node
# that carries its color (the head sprite itself; a body's TubeAnimation, which is tinted rather
# than its sprite). The art shows only while a monster animation is playing -- the same head scene
# is also a player's face, a bomb and more -- and hides the sprite's pixels only then. A sibling,
# not a child, so the eyes keep their own glow under any tint.

const HEAD_ANIMS: Array = [&"Enemy"]
const BODY_ANIMS: Array = [&"EnemyBody", &"EnemyBodyShort"]
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)
const SHADOW_OFS: Vector2 = Vector2(1.6, 2.4)
const EYE_GLOW: Color = Color(1.0, 0.78, 0.18)
const PUPIL: Color = Color(0.08, 0.07, 0.10)

var sprite: AnimatedSprite2D = null
var carrier: Node2D = null       # the node whose transform and tint the art copies
var is_body: bool = false
var _phase: float = 0.0
var _turned_once: bool = false
var _path: PathSmoother = PathSmoother.new(18.0)
const BODY_TURN_RATE: float = PI * 0.5 / 0.10


static func watch(spr: AnimatedSprite2D) -> void:
	if spr.sprite_frames == null or spr.has_meta("monster_art"):
		return
	var head: bool = spr.sprite_frames.has_animation(HEAD_ANIMS[0])
	# head_anim.tscn carries an EnemyBody animation too, so only a sprite WITHOUT the head one is a
	# body segment
	var body: bool = not head and spr.sprite_frames.has_animation(BODY_ANIMS[0])
	if not head and not body:
		return
	spr.set_meta("monster_art", true)
	_attach.call_deferred(spr, body)


static func _attach(spr: AnimatedSprite2D, body: bool) -> void:
	if not is_instance_valid(spr) or spr.get_parent() == null:
		return
	var art: MonsterArt = MonsterArt.new()
	art.sprite = spr
	art.is_body = body
	art.carrier = (spr.get_parent() as Node2D) if body else spr
	if art.carrier == null or art.carrier.get_parent() == null:
		return
	art.name = String(art.carrier.name) + "Monster"
	art._phase = randf() * TAU
	var host: Node = art.carrier.get_parent()
	host.add_child(art)
	host.move_child(art, art.carrier.get_index() + 1)
	art._follow()


func _active() -> bool:
	var anims: Array = BODY_ANIMS if is_body else HEAD_ANIMS
	return sprite.animation in anims


func _follow() -> void:
	var on: bool = _active()
	sprite.self_modulate.a = 0.0 if on else 1.0
	visible = on and carrier.visible and sprite.visible
	if is_body:
		# A body segment sits on its creature's trail, which turns at right angles; draw it on a
		# rounded version of its own path and swing its facing toward that path's heading (a head's
		# carrier is head_anim.gd, which already does both).
		_path.push(carrier.global_position)
		global_position = _path.point()
		var want: float = _path.heading() if _path.has_heading() else carrier.global_rotation
		var diff: float = wrapf(want - global_rotation, -PI, PI)
		var step: float = BODY_TURN_RATE * get_process_delta_time()
		if absf(diff) <= step or not _turned_once:
			global_rotation = want
		else:
			global_rotation += signf(diff) * step
		_turned_once = true
	else:
		position = carrier.position
		rotation = carrier.rotation
	scale = carrier.scale * 4.0
	z_index = carrier.z_index
	z_as_relative = carrier.z_as_relative
	modulate = Color(1, 1, 1, carrier.modulate.a)


func _process(_delta: float) -> void:
	if not is_instance_valid(sprite) or not is_instance_valid(carrier):
		queue_free()
		return
	_follow()
	if is_visible_in_tree():
		queue_redraw()


func _hue() -> Color:
	var c: Color = carrier.modulate
	return Color(c.r, c.g, c.b, 1.0)


func _ellipse(ctr: Vector2, r: Vector2, n: int = 28) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n:
		var a: float = TAU * float(k) / float(n)
		pts.append(ctr + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _shaded(pts: PackedVector2Array, base: Color, ctr: Vector2, half: Vector2, light: Vector2) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in pts:
		var t: float = clampf(((p - ctr) / half).dot(light), -1.0, 1.0)
		cols.append(base.lightened(0.28 * t) if t > 0.0 else base.darkened(-0.34 * t))
	draw_polygon(pts, cols)


func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, w, true)


func _draw() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(SHADOW_OFS)
	var t: float = float(Time.get_ticks_msec()) * 0.001 + _phase
	if is_body:
		_draw_body(_hue(), light, ofs, t)
	else:
		_draw_head(_hue(), light, ofs, t)


func _spike(base: Vector2, out: Vector2, half_w: float, length: float, col: Color) -> void:
	var n: Vector2 = out.normalized()
	var t: Vector2 = Vector2(-n.y, n.x) * half_w
	draw_colored_polygon(PackedVector2Array([base + t, base + n * length, base - t]), col)


func _draw_head(hue: Color, light: Vector2, ofs: Vector2, t: float) -> void:
	var body_col: Color = hue
	var ink: Color = hue.darkened(0.82)   # near black: an olive edge on a yellow monster read soft
	var r: Vector2 = Vector2(12.0, 12.5)
	draw_colored_polygon(_ellipse(ofs, r + Vector2(2.0, 2.0)), Color(0, 0, 0, 0.28))
	# swept-back horns, reaching well past the shell
	for sy: float in [-1.0, 1.0]:
		var horn: PackedVector2Array = PackedVector2Array([Vector2(1.0, 10.0 * sy), Vector2(-8.0, 15.0 * sy),
			Vector2(-18.0, 18.5 * sy), Vector2(-9.0, 11.0 * sy), Vector2(-4.0, 8.0 * sy)])
		draw_colored_polygon(horn, ink)
		draw_line(Vector2(-3.0, 11.0 * sy), Vector2(-15.0, 17.2 * sy), Color(hue.lightened(0.25), 0.7), 0.9, true)
	# two curved fangs, snapping shut
	var bite: float = pow(0.5 + 0.5 * sin(t * 4.0), 3.0)
	for sy: float in [-1.0, 1.0]:
		var root: Vector2 = Vector2(9.0, 5.5 * sy)
		var bend: Vector2 = Vector2(16.5, (8.0 - 1.5 * bite) * sy)
		var tip: Vector2 = Vector2(20.5, (2.5 - 1.5 * bite) * sy)
		var fang: PackedVector2Array = PackedVector2Array([root + Vector2(0.0, 2.6 * sy), bend + Vector2(0.6, 1.6 * sy),
			tip, bend + Vector2(-0.8, -1.4 * sy), root + Vector2(0.0, -2.2 * sy)])
		draw_colored_polygon(fang, ink)
		draw_line(root, bend, Color(hue.lightened(0.3), 0.6), 0.8, true)
	# the shell
	var shell: PackedVector2Array = _ellipse(Vector2.ZERO, r)
	_shaded(shell, body_col, Vector2.ZERO, r, light)
	# a dark armored crown over the back of the head
	var crown: PackedVector2Array = PackedVector2Array()
	for k in 13:
		var ang: float = PI * 0.5 + PI * float(k) / 12.0
		crown.append(Vector2(cos(ang) * r.x * 0.98, sin(ang) * r.y * 0.98))
	crown.append(Vector2(-1.0, -7.0))
	crown.append(Vector2(1.5, 0.0))
	crown.append(Vector2(-1.0, 7.0))
	draw_colored_polygon(crown, Color(ink, 0.28))
	_outline(shell, ink, 1.6)
	# glowing slit eyes, slanted into a scowl
	for sy: float in [-1.0, 1.0]:
		var e: Vector2 = Vector2(5.5, 4.6 * sy)
		var ang: float = -0.55 * sy
		var eye: PackedVector2Array = PackedVector2Array()
		for k in 16:
			var a: float = TAU * float(k) / 16.0
			eye.append(e + Vector2(cos(a) * 4.2, sin(a) * 2.2).rotated(ang))
		draw_colored_polygon(_ellipse(e, Vector2(5.5, 4.0)), Color(EYE_GLOW, 0.25))
		draw_colored_polygon(eye, EYE_GLOW)
		_outline(eye, ink, 1.2)
		draw_line(e + Vector2(0.4, -1.8).rotated(ang), e + Vector2(0.4, 1.8).rotated(ang), PUPIL, 1.3, true)
		draw_line(e + Vector2(-4.5, -3.3 * sy).rotated(ang), e + Vector2(4.0, -3.5 * sy).rotated(ang), ink, 2.0,
			true)


func _draw_body(hue: Color, light: Vector2, ofs: Vector2, t: float) -> void:
	var body_col: Color = hue
	var ink: Color = hue.darkened(0.82)   # near black: an olive edge on a yellow monster read soft
	var r: Vector2 = Vector2(14.5, 12.0)
	draw_colored_polygon(_ellipse(ofs, r + Vector2(1.5, 1.5)), Color(0, 0, 0, 0.25))
	# four long jointed legs, scuttling: in a dark shade of the monster's color with a black edge,
	# reaching well past the plate (near-black legs mostly under the plate were invisible on a dark
	# floor)
	var leg_col: Color = hue.darkened(0.35)
	for k in 2:
		var x: float = -5.5 + 11.0 * float(k)
		for sy: float in [-1.0, 1.0]:
			var swing: float = sin(t * 9.0 + float(k) * PI + (0.0 if sy > 0.0 else PI)) * 3.5
			var knee: Vector2 = Vector2(x + 3.0 + swing * 0.5, 18.0 * sy)
			var foot: Vector2 = Vector2(x - 1.0 + swing, 24.0 * sy)
			var leg: PackedVector2Array = PackedVector2Array([Vector2(x, 8.0 * sy), knee, foot])
			draw_polyline(leg, ink, 4.2, true)
			draw_polyline(leg, leg_col, 2.4, true)
			draw_circle(knee, 1.9, ink, true, -1.0, true)
	# side spines
	for k in 3:
		var a: float = lerpf(-0.9, 0.9, float(k) / 2.0)
		for sy: float in [-1.0, 1.0]:
			var p: Vector2 = Vector2(sin(a) * r.x, cos(a) * r.y * sy)
			_spike(p * 0.92, p.normalized() * Vector2(0.4, 1.0), 1.8, 4.5, ink)
	var plate: PackedVector2Array = _ellipse(Vector2.ZERO, r)
	_shaded(plate, body_col, Vector2.ZERO, r, light)
	# two armor bands and a spined ridge
	for x: float in [-5.5, 5.5]:
		var band: PackedVector2Array = PackedVector2Array()
		for k in 9:
			var y: float = -10.5 + 21.0 * float(k) / 8.0
			band.append(Vector2(x + 2.0 * (1.0 - pow(y / 10.5, 2.0)), y))
		draw_polyline(band, Color(ink, 0.65), 1.4, true)
	draw_line(Vector2(-12.0, 0.0), Vector2(12.0, 0.0), Color(ink, 0.55), 2.2, true)
	_outline(plate, ink, 1.6)
