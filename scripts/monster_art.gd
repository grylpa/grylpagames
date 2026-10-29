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
# The same head scene plays "Bomb" for the bombs (Gorilla, Storm, Mind Palace and Lights Out agents,
# bomb_scene.tscn, and the bombs Lights Out puts inside its docks). Drawn here too, so one node
# owns the head sprite's visibility.
const BOMB_ANIM: StringName = &"Bomb"
const PLAYER_ANIMS: Array = [&"HeadEyes", &"circular"]
const TAXI_ANIM: StringName = &"HeadTaxi"
const TAXI_YELLOW: Color = Color(0.99, 0.82, 0.16)
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
var _in_head: bool = false          # drawn as the head's first child (see _attach)
var _gas: Sprite2D = null           # taxi's fuel overlay, read for the fuel level and hidden
var _hid: bool = false
var _gait: float = 0.0              # leg phase, advanced by the distance traveled
var _last_gp: Vector2 = Vector2.INF
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
	# Another drawing already owns this sprite (Wolves' beast_art.gd, the delivery trucks'
	# cargo_train_art.gd hide it in their _ready, before this deferred call): leave it alone, or
	# both would draw, and this would keep un-hiding the sprite.
	if spr.self_modulate.a < 0.01:
		return
	var art: MonsterArt = MonsterArt.new()
	art.sprite = spr
	art.is_body = body
	art.carrier = (spr.get_parent() as Node2D) if body else spr
	if art.carrier == null or art.carrier.get_parent() == null:
		return
	art.name = String(art.carrier.name) + "Monster"
	art._phase = randf() * TAU
	# A head with overlays of its own as children (taxi's: the fuel gauge, the Selected, Blocked and
	# Assigned marks) gets the art as its FIRST child, so it draws over the head's picture but under
	# those overlays. Every other head has none and keeps the art as a sibling, so a tint on the
	# head does not reach the eyes.
	if not body and spr.get_child_count() > 0:
		art._in_head = true
		spr.add_child(art)
		spr.move_child(art, 0)
		art._gas = spr.get_node_or_null("GasSprite") as Sprite2D
	else:
		var host: Node = art.carrier.get_parent()
		host.add_child(art)
		host.move_child(art, art.carrier.get_index() + 1)
	art._follow()


func _active() -> bool:
	var anims: Array = BODY_ANIMS if is_body else HEAD_ANIMS
	return sprite.animation in anims or _is_bomb() or _is_player() or _is_taxi() or _is_passenger()


# The PLAYER's head (Mind Palace, Storm, Lights Out, Gorilla): the same scene's "HeadEyes" /
# "circular" blob. (The delivery trucks play it too, but their own art hides
# the sprite first, and _attach leaves such a sprite alone.)
func _is_player() -> bool:
	# not taxi's passengers (their heads carry overlays): they keep their own faces, the player's
	# creature does not fit them (user, 2026-10-29)
	return not is_body and not _in_head and sprite.animation in PLAYER_ANIMS


# Taxi's PASSENGERS (the same blob, inside a head that carries taxi's overlays): a person waiting
# for a cab, seen from above -- shoulders in their color, a head with hair, an arm raised to hail
# that waves now and then. The player's creature did not fit them, and the old blob was dull.
func _is_passenger() -> bool:
	return not is_body and _in_head and sprite.animation in PLAYER_ANIMS


func _is_taxi() -> bool:
	return not is_body and sprite.animation == TAXI_ANIM



func _is_bomb() -> bool:
	return not is_body and sprite.animation == BOMB_ANIM


func _follow() -> void:
	var on: bool = _active()
	# hide the sprite's own picture while this draws, and give back only what this hid
	if on:
		sprite.self_modulate.a = 0.0
		_hid = true
	elif _hid:
		sprite.self_modulate.a = 1.0
		_hid = false
	if _in_head:
		# inside the head: its transform, visibility and tint already apply; draw in screen units
		visible = on
		position = Vector2.ZERO
		rotation = 0.0
		scale = Vector2(4.0, 4.0)
		if _gas != null:
			_gas.self_modulate.a = 0.0
		return
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
		# a bomb stands upright, its fuse up, whichever way its creature faces
		if _is_bomb():
			global_rotation = 0.0
		else:
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
		var gp: Vector2 = global_position
		if _last_gp != Vector2.INF:
			_gait += gp.distance_to(_last_gp) / maxf(absf(global_scale.x), 0.01) * 0.15   # an unhurried gait: faster was distracting
		_last_gp = gp
		queue_redraw()


func _hue() -> Color:
	# the carrier's tint times the sprite's own (taxi colors its cabs and passengers through
	# self_modulate; its alpha is what this hides the sprite with, so only the color is read)
	var c: Color = carrier.modulate
	var sm: Color = sprite.self_modulate
	return Color(c.r * sm.r, c.g * sm.g, c.b * sm.b, 1.0)


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
	elif _is_bomb():
		_draw_bomb(_hue(), ofs, t)
	elif _is_player():
		_draw_player(_hue(), light, ofs, t)
	elif _is_taxi():
		_draw_taxi(_hue(), light, ofs, t)
	elif _is_passenger():
		_draw_passenger(_hue(), ofs, t)
	else:
		_draw_head(_hue(), light, ofs, t)


# A round bomb, its BODY centered on the node (the old picture's body sat well below its center,
# which put it off-center in a dock): glossy black with a band in the game's color, a brass collar,
# a curling fuse and a flickering spark. Upright, lit from the top left.
func _draw_bomb(hue: Color, ofs: Vector2, t: float) -> void:
	var r: float = 10.5
	var body_col: Color = Color(0.13, 0.13, 0.15).lerp(hue, 0.12)
	draw_circle(ofs * 1.2, r + 0.5, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, body_col, true, -1.0, true)
	# shading: darker toward the bottom right, a soft lit area toward the top left
	draw_circle(Vector2(1.6, 1.8), r * 0.82, body_col.darkened(0.45), true, -1.0, true)
	draw_circle(Vector2(-1.2, -1.4), r * 0.80, body_col, true, -1.0, true)
	draw_circle(Vector2(-2.5, -2.8), r * 0.55, body_col.lightened(0.10), true, -1.0, true)
	# the colored band, curved round the sphere
	var band: PackedVector2Array = PackedVector2Array()
	for k in 17:
		var a: float = lerpf(PI * 0.12, PI * 0.88, float(k) / 16.0)
		band.append(Vector2(-cos(a) * r * 0.86, sin(a) * r * 0.30 + 2.5))
	draw_polyline(band, hue.lightened(0.15), 3.0, true)
	# gloss
	draw_circle(Vector2(-4.2, -4.6), 2.3, Color(1, 1, 1, 0.55), true, -1.0, true)
	draw_circle(Vector2(-2.2, -6.6), 0.9, Color(1, 1, 1, 0.45), true, -1.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0, 0, 0, 0.9), 1.3, true)
	# the brass collar at the top right
	var cdir: Vector2 = Vector2(0.55, -0.83)
	var cpos: Vector2 = cdir * (r - 0.8)
	var cn: Vector2 = Vector2(-cdir.y, cdir.x)
	var collar: PackedVector2Array = PackedVector2Array([cpos - cn * 3.2, cpos + cn * 3.2,
		cpos + cn * 2.6 + cdir * 3.0, cpos - cn * 2.6 + cdir * 3.0])
	draw_colored_polygon(collar, Color(0.80, 0.62, 0.25))
	draw_polyline(PackedVector2Array([collar[0], collar[1], collar[2], collar[3], collar[0]]),
		Color(0.35, 0.24, 0.06), 1.0, true)
	draw_line(cpos - cn * 2.0 + cdir * 0.8, cpos + cn * 2.0 + cdir * 0.8, Color(1.0, 0.88, 0.55, 0.8), 0.8, true)
	# the fuse, curling up and over
	var f0: Vector2 = cpos + cdir * 3.0
	var fuse: PackedVector2Array = PackedVector2Array()
	for k in 9:
		var u: float = float(k) / 8.0
		fuse.append(f0 + Vector2(u * 5.0 + sin(u * PI) * 1.5, -u * 6.5 + sin(u * PI * 1.4) * 1.2))
	draw_polyline(fuse, Color(0.42, 0.33, 0.22), 1.6, true)
	# the spark: a glow, a flickering star and a hot core
	var tip: Vector2 = fuse[fuse.size() - 1]
	var flick: float = 0.75 + 0.25 * sin(t * 31.0) * sin(t * 17.0)
	draw_circle(tip, 4.5 * flick, Color(1.0, 0.65, 0.15, 0.25), true, -1.0, true)
	for k in 4:
		var a: float = float(k) * PI * 0.25 + t * 2.0
		var v: Vector2 = Vector2(cos(a), sin(a)) * 4.0 * flick
		draw_line(tip - v, tip + v, Color(1.0, 0.85, 0.35, 0.9), 0.9, true)
	draw_circle(tip, 1.5, Color(1.0, 0.97, 0.80), true, -1.0, true)


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
	# three pairs of jointed legs, scuttling with the distance actually traveled (a lone head had
	# none, and nothing moved on it but a small snap); a slow twitch while it stands
	var leg_col: Color = hue.darkened(0.35)
	for k in 3:
		var x: float = 5.0 - 6.5 * float(k)
		for sy: float in [-1.0, 1.0]:
			var ph: float = _gait + float(k) * 2.1 + (0.0 if sy > 0.0 else PI)
			var swing: float = sin(ph) * 4.0 + sin(t * 3.0 + float(k)) * 0.6
			var lift: float = maxf(0.0, cos(ph)) * 1.5
			var knee: Vector2 = Vector2(x + 1.5 + swing * 0.5, (15.5 + lift) * sy)
			var foot: Vector2 = Vector2(x - 3.0 + swing, (20.0 - lift * 0.5) * sy)
			var leg: PackedVector2Array = PackedVector2Array([Vector2(x, 8.0 * sy), knee, foot])
			draw_polyline(leg, ink, 3.2, true)
			draw_polyline(leg, leg_col, 1.6, true)
			draw_circle(knee, 1.4, ink, true, -1.0, true)
	# two curved fangs that swing open on their roots and SNAP shut
	var s_: float = 0.5 + 0.5 * sin(t * 3.0)
	var open_ang: float = lerpf(0.55, -0.15, pow(s_, 4.0))
	for sy: float in [-1.0, 1.0]:
		var root: Vector2 = Vector2(9.0, 5.5 * sy)
		var rot: float = open_ang * sy
		var bend: Vector2 = root + Vector2(7.5, 2.5 * sy).rotated(rot)
		var tip: Vector2 = root + Vector2(11.5, -3.0 * sy).rotated(rot)
		var fang: PackedVector2Array = PackedVector2Array([root + Vector2(0.0, 2.6 * sy),
			bend + Vector2(0.6, 1.6 * sy).rotated(rot), tip, bend + Vector2(-0.8, -1.4 * sy).rotated(rot),
			root + Vector2(0.0, -2.2 * sy)])
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
			var swing: float = sin(t * 3.0 + float(k) * PI + (0.0 if sy > 0.0 else PI)) * 3.5
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


# The PLAYER: a friendly round creature, deliberately unlike the menacing monsters. A glossy ball
# in its color, big eyes looking the way it is heading (the head faces +x), a blink now and then,
# and little feet that paddle with the distance it travels.
func _draw_player(hue: Color, light: Vector2, ofs: Vector2, t: float) -> void:
	# drawn 1.3x: at 12 units it came out smaller than the old player (user, 2026-10-29)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.3, 1.3))
	var r: float = 12.0
	var ink: Color = hue.darkened(0.75)
	draw_circle(ofs * 1.1, r + 0.5, Color(0, 0, 0, 0.28), true, -1.0, true)
	# feet, under the body, paddling
	for sy: float in [-1.0, 1.0]:
		var ph: float = _gait * 1.6 + (0.0 if sy > 0.0 else PI)
		var f: Vector2 = Vector2(-1.0 + sin(ph) * 3.0, (r - 1.0) * sy)
		draw_circle(f, 3.4, ink, true, -1.0, true)
		draw_circle(f, 2.5, hue.darkened(0.25), true, -1.0, true)
	# the body: shaded toward the light, with a glossy highlight
	# a light edge shading only: a dark rim made it read less clearly against the board
	draw_circle(Vector2.ZERO, r, hue.darkened(0.14), true, -1.0, true)
	draw_circle(light * 1.2, r * 0.90, hue, true, -1.0, true)
	draw_circle(light * 3.6, r * 0.55, hue.lightened(0.18), true, -1.0, true)
	draw_circle(light * 6.6, 2.3, Color(1, 1, 1, 0.6), true, -1.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, ink, 1.8, true)
	# eyes at the front, pupils forward; a blink about every 3.5 s
	var blink: float = fposmod(t + _phase * 2.0, 3.5)
	var open: float = 1.0 if blink > 0.14 else absf(blink - 0.07) / 0.07
	for sy: float in [-1.0, 1.0]:
		var e: Vector2 = Vector2(5.0, 4.6 * sy)
		var eye: PackedVector2Array = _ellipse(e, Vector2(3.4, 3.6 * maxf(open, 0.12)), 20)
		draw_colored_polygon(eye, Color(0.99, 0.99, 0.97))
		_outline(eye, ink, 1.0)
		if open > 0.3:
			draw_circle(e + Vector2(1.4, 0.0), 1.9, PUPIL, true, -1.0, true)
			draw_circle(e + Vector2(0.8, -0.9), 0.6, Color(1, 1, 1, 0.9), true, -1.0, true)
	# a small smile at the front edge
	var smile: PackedVector2Array = PackedVector2Array()
	for k in 7:
		var a: float = lerpf(-0.5, 0.5, float(k) / 6.0)
		smile.append(Vector2(8.6 + cos(a) * 1.2, sin(a) * 3.0))
	draw_polyline(smile, ink, 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# A TAXI cab from above, facing +x, in its color (yellow by default): a rounded body lit across,
# a dark windshield and rear window, the roof sign with its checker band, headlights and tail
# lights, mirrors. The 160x125 picture it replaces was shown at 0.25: 40 x 31 units.
func _draw_taxi(hue: Color, light: Vector2, ofs: Vector2, t: float) -> void:
	# an untinted cab is taxi yellow (the old picture had its yellow baked in); any other tint stays
	if hue.r > 0.97 and hue.g > 0.97 and hue.b > 0.97:
		hue = TAXI_YELLOW
	var ink: Color = hue.darkened(0.65)
	var glass: Color = Color(0.16, 0.22, 0.30)
	var body: PackedVector2Array = _rbox(Rect2(-19.0, -12.5, 38.0, 25.0), 7.0)
	var sh: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in body:
		sh.append(p + ofs)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.28))
	for sy: float in [-1.0, 1.0]:
		draw_colored_polygon(_rbox(Rect2(5.0, 12.0 * sy - 1.5, 3.0, 3.0), 1.0), ink)     # mirrors
	_shaded(body, hue, Vector2.ZERO, Vector2(19.0, 12.5), light)
	_outline(body, ink, 1.4)
	# windshield toward the front, rear window, the roof between them
	draw_colored_polygon(_rbox(Rect2(4.0, -9.5, 6.0, 19.0), 2.5), glass)
	draw_line(Vector2(5.5, -7.0), Vector2(6.5, -2.0), Color(1, 1, 1, 0.45), 1.0, true)
	draw_colored_polygon(_rbox(Rect2(-14.5, -8.5, 4.5, 17.0), 2.0), glass)
	draw_colored_polygon(_rbox(Rect2(-10.0, -9.5, 14.0, 19.0), 3.0), hue.lightened(0.12))
	# the roof sign: a light box with a checker band, glowing now and then
	var glow: float = 0.5 + 0.5 * sin(t * 2.0)
	draw_colored_polygon(_rbox(Rect2(-6.5, -5.0, 7.0, 10.0), 1.5), Color(1.0, 0.97, 0.85).lerp(Color(1, 1, 0.7), glow))
	for k in 4:
		var y: float = -4.0 + 2.0 * float(k)
		draw_rect(Rect2(-2.0 if k % 2 == 0 else -3.5, y, 1.5, 2.0), Color(0.1, 0.1, 0.1))
	_outline(_rbox(Rect2(-6.5, -5.0, 7.0, 10.0), 1.5), ink, 0.9)
	# lights
	for sy: float in [-1.0, 1.0]:
		draw_colored_polygon(_rbox(Rect2(16.0, 8.0 * sy - 2.0, 2.8, 4.0), 1.2), Color(1.0, 0.96, 0.75))
		draw_colored_polygon(_rbox(Rect2(-19.0, 8.0 * sy - 2.0, 2.0, 4.0), 0.8), Color(0.9, 0.15, 0.12))
	# THE FUEL, over everything and see-through, so the red fills the whole cab and the cab still shows
	# through it (under the windows it was too narrow to see): as the tank empties, red creeps over the cab from the back (taxi's GasSprite region,
	# which the game sets, read for the level -- the overlay itself is hidden)
	if _gas != null and _gas.visible and _gas.texture != null:
		var empty: float = clampf(_gas.region_rect.size.x / float(_gas.texture.get_width()), 0.0, 1.0)
		if empty > 0.01:
			var cut: PackedVector2Array = PackedVector2Array([Vector2(-20.0, -14.0),
				Vector2(-19.0 + 38.0 * empty, -14.0), Vector2(-19.0 + 38.0 * empty, 14.0), Vector2(-20.0, 14.0)])
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(body, cut):
				draw_colored_polygon(piece, Color(0.95, 0.10, 0.08, 0.55))
			draw_line(Vector2(-19.0 + 38.0 * empty, -12.0), Vector2(-19.0 + 38.0 * empty, 12.0),
				Color(1.0, 0.85, 0.80, 0.9), 1.2, true)


func _rbox(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cs: Array = [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c: Array in cs:
		for k in 5:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw_passenger(hue: Color, _ofs: Vector2, t: float) -> void:
	# A BOLD BADGE, readable at phone size: a disc in their color with a dark rim and a white person
	# (head and shoulders) on it, over a soft shadow; it bobs gently now and then, as if waving for
	# a cab. (A tiny drawn person with a raised arm could not be read on a small screen.)
	var bob: float = absf(sin(t * 6.0)) * 1.5 if fposmod(t + _phase, 3.0) < 0.8 else 0.0
	draw_set_transform(Vector2(0.0, -bob).rotated(-global_rotation), -global_rotation, Vector2(1.3, 1.3))
	var ink: Color = hue.darkened(0.70)
	draw_circle(Vector2(1.0, 2.0 + bob), 11.0, Color(0, 0, 0, 0.30), true, -1.0, true)
	draw_circle(Vector2.ZERO, 11.0, ink, true, -1.0, true)
	draw_circle(Vector2.ZERO, 9.6, hue, true, -1.0, true)
	draw_arc(Vector2.ZERO, 8.2, PI * 1.1, PI * 1.6, 12, hue.lightened(0.4), 1.4, true)
	# white on the badge, dark on a light one (a white passenger's figure vanished)
	var white: Color = Color(1.0, 1.0, 1.0, 0.97) if hue.get_luminance() < 0.7 else hue.darkened(0.75)
	draw_circle(Vector2(0.0, -2.6), 3.2, white, true, -1.0, true)
	var shoulders: PackedVector2Array = PackedVector2Array()
	for k in 13:
		var a2: float = PI + PI * float(k) / 12.0
		shoulders.append(Vector2(cos(a2) * 6.0, 7.0 + sin(a2) * 5.2))
	draw_colored_polygon(shoulders, white)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
