extends "res://scripts/menu_poster.gd"

# MOVING CARDS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): A CAROUSEL IN A ROOM,
# ALL IN 3-D (the user: "make sure to do everything in correct 3d", the cards with thickness, a better room,
# the curtains moving in the wind). One camera (`_proj`) sees one small room: a papered back wall with a dado,
# a floor of boards running away from us, an open window at dusk whose curtains billow into the room in the
# breeze (each fold lit or shaded by its angle), a floor lamp's glowing shade, and a round oak table on a
# pedestal. Above the table the cards ride a ring: real thin boxes (a face, a back and four edges), each
# facing out from the ring, so as one comes round to the front its FACE turns to us and going round the back
# we see its BACK -- they turn over because they are turning, not by a trick. The faces are glazed memory
# tiles (menu_card.gd, rendered once into pictures and laid on the projected card). Their shadows lie on the
# tabletop. Not a card table (the user: playing cards "looks like a gambling game"). Made up, never the board.

const TILE: Script = preload("res://movingcards/scripts/menu_card.gd")
const N: int = 7
const SPEED: float = 0.30            # radians a second round the ring
const CARD_W: float = 112.0          # world units
const CARD_T: float = 9.0            # its thickness
const RING_R: float = 190.0
const RING_Y: float = 110.0          # above the tabletop
const TABLE_R: float = 240.0
const FLOOR_Y: float = -190.0
const WALL_Z: float = -620.0

var _room: Control = null
var _cards_layer: Control = null
var _face_tex: Array = []            # per card: [face texture, back texture]
var _baked: bool = false
var _cam: Dictionary = {}

func _setup() -> void:
	_room = Control.new()
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room.draw.connect(func() -> void: _draw_room(_room))
	add_child(_room)
	_cards_layer = Control.new()
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_layer.draw.connect(func() -> void: _draw_cards(_cards_layer))
	add_child(_cards_layer)
	_bake_faces()

# every card's face and back rendered once, all in ONE frame (never a hold-up), to lay on the 3-D cards
func _bake_faces() -> void:
	var px: int = 192
	var vps: Array = []
	for k in N:
		for face in [true, false]:
			var vp: SubViewport = SubViewport.new()
			vp.size = Vector2i(px, px)
			vp.transparent_bg = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var tile: Node2D = TILE.new()
			tile.set("number", k + 1)
			tile.set("flat", true)
			tile.set("face_up", face)
			tile.position = Vector2(px, px) * 0.5
			tile.scale = Vector2.ONE * (float(px) / float(TILE.S))
			vp.add_child(tile)
			add_child(vp)
			vps.append(vp)
	await RenderingServer.frame_post_draw
	_face_tex.clear()
	for k in N:
		var pair: Array = []
		for j in 2:
			var vp2: SubViewport = vps[k * 2 + j]
			var img: Image = vp2.get_texture().get_image()
			vp2.queue_free()
			if img != null:
				img.generate_mipmaps()
			pair.append(ImageTexture.create_from_image(img) if img != null else null)
		_face_tex.append(pair)
	_baked = true

# --- the camera ----------------------------------------------------------------------------------------

func _camera() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 230.0 if mobile else 150.0
	var eye: Vector3 = Vector3(0.0, 330.0, 1250.0)
	var target: Vector3 = Vector3(0.0, 90.0, -120.0)
	var f: Vector3 = (target - eye).normalized()
	var r: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = r.cross(f)
	return {"eye": eye, "f": f, "r": r, "u": u, "focal": full.x * 1.70,
		"center": Vector2(full.x * 0.5, top + (bottom - top) * 0.52), "full": full, "bottom": bottom, "top": top}

func _proj(p: Vector3) -> Vector2:
	var v: Vector3 = p - _cam["eye"]
	var z: float = maxf(v.dot(_cam["f"]), 1.0)
	return Vector2(_cam["center"]) + Vector2(v.dot(_cam["r"]), -v.dot(_cam["u"])) * float(_cam["focal"]) / z

func _depth(p: Vector3) -> float:
	return (p - _cam["eye"]).dot(_cam["f"])

func _quad(d: CanvasItem, pts: Array, col: Color) -> void:
	var q: PackedVector2Array = PackedVector2Array()
	for p in pts:
		q.append(_proj(p))
	if Geometry2D.triangulate_polygon(q).size() > 0:
		d.draw_colored_polygon(q, col)

func _tick(_delta: float) -> void:
	_cam = _camera()
	_room.queue_redraw()
	_cards_layer.queue_redraw()

# --- the room --------------------------------------------------------------------------------------------

func _wind(y: float, x: float) -> float:
	# the breeze through the open window: a slow swell with gusts running down the cloth
	return (0.5 + 0.5 * sin(t * 0.6)) * (0.6 + 0.4 * sin(t * 2.1 - y * 0.012 + x * 0.02))

func _draw_room(d: Control) -> void:
	if _cam.is_empty():
		_cam = _camera()
	var wall_top: float = 900.0
	# THE BACK WALL: papered in warm stripes, a dado rail, panelling below
	_quad(d, [Vector3(-1400, FLOOR_Y, WALL_Z), Vector3(1400, FLOOR_Y, WALL_Z), Vector3(1400, wall_top, WALL_Z), Vector3(-1400, wall_top, WALL_Z)], Color(0.36, 0.25, 0.19))
	var x: float = -1400.0
	while x < 1400.0:
		_quad(d, [Vector3(x, FLOOR_Y + 120.0, WALL_Z), Vector3(x + 26.0, FLOOR_Y + 120.0, WALL_Z), Vector3(x + 26.0, wall_top, WALL_Z), Vector3(x, wall_top, WALL_Z)], Color(1.0, 0.88, 0.72, 0.05))
		x += 70.0
	_quad(d, [Vector3(-1400, FLOOR_Y, WALL_Z), Vector3(1400, FLOOR_Y, WALL_Z), Vector3(1400, FLOOR_Y + 120.0, WALL_Z), Vector3(-1400, FLOOR_Y + 120.0, WALL_Z)], Color(0.26, 0.15, 0.08))
	_quad(d, [Vector3(-1400, FLOOR_Y + 116.0, WALL_Z + 4.0), Vector3(1400, FLOOR_Y + 116.0, WALL_Z + 4.0), Vector3(1400, FLOOR_Y + 128.0, WALL_Z + 4.0), Vector3(-1400, FLOOR_Y + 128.0, WALL_Z + 4.0)], Color(0.44, 0.28, 0.14))
	# THE WINDOW in the back wall, open, dusk beyond: its sky and roofs, its reveal, sill and frame
	var wx0: float = -470.0
	var wx1: float = -190.0
	var wy0: float = 80.0
	var wy1: float = 470.0
	var sky: PackedVector2Array = PackedVector2Array([_proj(Vector3(wx0, wy0, WALL_Z)), _proj(Vector3(wx1, wy0, WALL_Z)), _proj(Vector3(wx1, wy1, WALL_Z)), _proj(Vector3(wx0, wy1, WALL_Z))])
	if Geometry2D.triangulate_polygon(sky).size() > 0:
		d.draw_polygon(sky, PackedColorArray([Color(0.98, 0.64, 0.50), Color(0.96, 0.60, 0.50), Color(0.26, 0.24, 0.52), Color(0.22, 0.22, 0.48)]))
	for k in 4:
		var bx: float = lerpf(wx0, wx1, 0.05 + 0.24 * float(k))
		var bh: float = 40.0 + 50.0 * h01(k + 3)
		_quad(d, [Vector3(bx, wy0, WALL_Z - 1.0), Vector3(bx + 70.0, wy0, WALL_Z - 1.0), Vector3(bx + 70.0, wy0 + bh, WALL_Z - 1.0), Vector3(bx, wy0 + bh, WALL_Z - 1.0)], Color(0.22, 0.16, 0.28))
	for k in 3:
		var sp: Vector2 = _proj(Vector3(lerpf(wx0, wx1, 0.2 + 0.3 * float(k)), wy1 - 60.0 - 50.0 * h01(k + 9), WALL_Z - 1.0))
		d.draw_circle(sp, 1.5, Color(1, 1, 1, 0.7))
	_quad(d, [Vector3(wx0, wy0, WALL_Z), Vector3(wx0, wy0, WALL_Z + 30.0), Vector3(wx0, wy1, WALL_Z + 30.0), Vector3(wx0, wy1, WALL_Z)], Color(0.46, 0.34, 0.26))
	_quad(d, [Vector3(wx0 - 20.0, wy0, WALL_Z + 40.0), Vector3(wx1 + 20.0, wy0, WALL_Z + 40.0), Vector3(wx1 + 20.0, wy0 - 12.0, WALL_Z + 40.0), Vector3(wx0 - 20.0, wy0 - 12.0, WALL_Z + 40.0)], Color(0.86, 0.80, 0.70))
	for e in [[wx0, wy0, wx1, wy0 + 10.0], [wx0, wy1 - 10.0, wx1, wy1], [wx0, wy0, wx0 + 10.0, wy1], [wx1 - 10.0, wy0, wx1, wy1],
			[(wx0 + wx1) * 0.5 - 5.0, wy0, (wx0 + wx1) * 0.5 + 5.0, wy1], [wx0, (wy0 + wy1) * 0.5 - 5.0, wx1, (wy0 + wy1) * 0.5 + 5.0]]:
		_quad(d, [Vector3(e[0], e[1], WALL_Z + 2.0), Vector3(e[2], e[1], WALL_Z + 2.0), Vector3(e[2], e[3], WALL_Z + 2.0), Vector3(e[0], e[3], WALL_Z + 2.0)], Color(0.90, 0.85, 0.76))
	# THE CURTAINS, drawn back to each side of the window and billowing into the room in the breeze: each a
	# sheet of vertical folds hanging from the rod, pushed out (toward us, +z) more the lower it hangs; every
	# fold strip shaded by how it faces the light
	var rod_y: float = wy1 + 50.0
	_quad(d, [Vector3(wx0 - 140.0, rod_y, WALL_Z + 20.0), Vector3(wx1 + 140.0, rod_y, WALL_Z + 20.0), Vector3(wx1 + 140.0, rod_y + 6.0, WALL_Z + 20.0), Vector3(wx0 - 140.0, rod_y + 6.0, WALL_Z + 20.0)], Color(0.70, 0.54, 0.30))
	for side in [-1.0, 1.0]:
		var x_in: float = (wx0 + 30.0) if side < 0.0 else (wx1 - 30.0)
		var x_out: float = x_in + side * 110.0
		var strips: int = 16
		var folds: float = 7.0              # each fold two strips: its lit side and its shaded side
		var rows_n: int = 10
		for sidx in strips:
			var u0: float = float(sidx) / float(strips)
			var u1: float = float(sidx + 1) / float(strips)
			for r in rows_n:
				var v0: float = float(r) / float(rows_n)
				var v1: float = float(r + 1) / float(rows_n)
				var corners: Array = []
				for uv in [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]:
					var uu: float = uv[0]
					var vv: float = uv[1]
					var cy: float = lerpf(rod_y, FLOOR_Y + 40.0, vv)
					var cx: float = lerpf(x_out, x_in, uu) + side * -18.0 * vv
					var fold: float = sin(uu * folds * TAU) * 22.0
					var billow: float = _wind(cy, cx) * 90.0 * vv * vv * (0.4 + 0.6 * (1.0 - uu))
					corners.append(Vector3(cx, cy, WALL_Z + 24.0 + fold + billow))
				var facing: float = cos(((u0 + u1) * 0.5) * folds * TAU)
				var shade: Color = Color(0.74, 0.34, 0.24).lerp(Color(0.34, 0.11, 0.08), 0.5 - 0.5 * facing)
				_quad(d, corners, shade)
	# THE FLOOR: boards running away from us, toward the wall
	_quad(d, [Vector3(-1400, FLOOR_Y, WALL_Z), Vector3(1400, FLOOR_Y, WALL_Z), Vector3(1400, FLOOR_Y, 900.0), Vector3(-1400, FLOOR_Y, 900.0)], Color(0.24, 0.14, 0.07))
	var bxs: float = -1400.0
	var bi: int = 0
	while bxs < 1400.0:
		_quad(d, [Vector3(bxs, FLOOR_Y, WALL_Z), Vector3(bxs + 3.0, FLOOR_Y, WALL_Z), Vector3(bxs + 3.0, FLOOR_Y, 900.0), Vector3(bxs, FLOOR_Y, 900.0)], Color(0.10, 0.05, 0.02, 0.6))
		var joint_z: float = lerpf(WALL_Z, 900.0, h01(bi + 5))
		_quad(d, [Vector3(bxs, FLOOR_Y, joint_z), Vector3(bxs + 90.0, FLOOR_Y, joint_z), Vector3(bxs + 90.0, FLOOR_Y, joint_z + 3.0), Vector3(bxs, FLOOR_Y, joint_z + 3.0)], Color(0.10, 0.05, 0.02, 0.5))
		bxs += 90.0
		bi += 1
	# the window's light falling on the floor, slanting in
	_quad(d, [Vector3(wx0, FLOOR_Y, WALL_Z), Vector3(wx1, FLOOR_Y, WALL_Z), Vector3(wx1 + 160.0, FLOOR_Y, WALL_Z + 420.0), Vector3(wx0 + 160.0, FLOOR_Y, WALL_Z + 420.0)], Color(1.0, 0.72, 0.56, 0.10))
	# THE FLOOR LAMP at the back right, IN 3-D (it was flat, the user): a round weighted base, a pole shaded as
	# a cylinder, a conical fabric shade lit from inside -- glowing through, darker round its far side, its
	# lower rim bright where the bulb shows under it -- a pool of light on the floor beneath, its glow on the wall
	var lamp_base: Vector3 = Vector3(400.0, FLOOR_Y, WALL_Z + 160.0)
	var shade_y: float = 300.0
	var lc: Vector2 = _proj(Vector3(400.0, shade_y + 30.0, WALL_Z + 160.0))
	for k in 24:
		d.draw_circle(lc, 300.0 * (1.0 - float(k) / 24.0), Color(1.0, 0.80, 0.50, 0.016))
	_ell_proj(d, lamp_base, 150.0, Color(1.0, 0.82, 0.55, 0.06))
	_ell_proj(d, lamp_base, 90.0, Color(1.0, 0.82, 0.55, 0.06))
	_ell_proj(d, lamp_base + Vector3(0, 6, 0), 42.0, Color(0.10, 0.07, 0.05))
	_ell_proj(d, lamp_base + Vector3(0, 10, 0), 36.0, Color(0.22, 0.16, 0.10))
	var p0: Vector2 = _proj(lamp_base + Vector3(0, 10, 0))
	var p1: Vector2 = _proj(Vector3(400.0, shade_y, WALL_Z + 160.0))
	d.draw_line(p0, p1, Color(0.10, 0.07, 0.05), 6.0)
	d.draw_line(p0 + Vector2(-1.5, 0), p1 + Vector2(-1.5, 0), Color(0.42, 0.32, 0.20), 1.5)
	# the shade: a frustum, wider at the bottom; drawn as strips round it, each lit by how it faces us and the
	# room, the light inside showing through
	var top_r: float = 34.0
	var bot_r: float = 62.0
	var shade_h: float = 74.0
	var strips: int = 24
	for k in strips:
		var a0: float = TAU * float(k) / float(strips)
		var a1: float = TAU * float(k + 1) / float(strips)
		var am: float = (a0 + a1) * 0.5
		var facing: float = sin(am)                     # +1 toward the camera (z+)
		if facing < -0.05:
			continue
		var ctr: Vector3 = Vector3(400.0, shade_y, WALL_Z + 160.0)
		var q: Array = [ctr + Vector3(cos(a0) * bot_r, 0.0, sin(a0) * bot_r), ctr + Vector3(cos(a1) * bot_r, 0.0, sin(a1) * bot_r),
			ctr + Vector3(cos(a1) * top_r, shade_h, sin(a1) * top_r), ctr + Vector3(cos(a0) * top_r, shade_h, sin(a0) * top_r)]
		var side_lit: float = 0.70 + 0.30 * facing - 0.15 * cos(am)
		_quad(d, q, Color(1.0 * side_lit, 0.84 * side_lit, 0.58 * side_lit))
	# its bright lower rim and the bulb's glow under it
	var rim_pts: PackedVector2Array = PackedVector2Array()
	for k in 25:
		var ar: float = TAU * float(k) / 24.0
		rim_pts.append(_proj(Vector3(400.0 + cos(ar) * bot_r, shade_y, WALL_Z + 160.0 + sin(ar) * bot_r)))
	d.draw_polyline(rim_pts, Color(1.0, 0.95, 0.80), 2.5, true)
	var bulb: Vector2 = _proj(Vector3(400.0, shade_y + 10.0, WALL_Z + 160.0))
	for k in 8:
		d.draw_circle(bulb, 26.0 - float(k) * 3.0, Color(1.0, 0.96, 0.82, 0.10))
	# THE TABLE: a round oak top with its edge, on a pedestal
	_ell_proj(d, Vector3(0.0, FLOOR_Y, 0.0), 120.0, Color(0, 0, 0, 0.30))
	d.draw_line(_proj(Vector3(0.0, FLOOR_Y, 0.0)), _proj(Vector3(0.0, -16.0, 0.0)), Color(0.30, 0.17, 0.08), 26.0)
	_ell_proj(d, Vector3(0.0, FLOOR_Y + 6.0, 0.0), 80.0, Color(0.32, 0.18, 0.08))
	var rim: PackedVector2Array = PackedVector2Array()
	for k in 33:
		var a3: float = PI * float(k) / 32.0
		rim.append(_proj(Vector3(cos(a3) * TABLE_R, 0.0, sin(a3) * TABLE_R)))
	for k in 33:
		var a4: float = PI - PI * float(k) / 32.0
		rim.append(_proj(Vector3(cos(a4) * TABLE_R, -18.0, sin(a4) * TABLE_R)))
	_safe(d, rim, Color(0.30, 0.17, 0.08))
	_ell_proj(d, Vector3.ZERO, TABLE_R, Color(0.52, 0.31, 0.15))
	for k in 6:
		_ell_proj(d, Vector3.ZERO, TABLE_R * (0.92 - 0.14 * float(k)), Color(0.42, 0.24, 0.11, 0.22))
	_ell_proj(d, Vector3(80.0, 0.0, -40.0), 90.0, Color(1.0, 0.88, 0.62, 0.08))
	# the cards' shadows on the tabletop, under each card
	for k in N:
		var a5: float = t * SPEED + TAU * float(k) / float(N)
		_ell_proj(d, Vector3(sin(a5) * RING_R, 0.0, cos(a5) * RING_R), 34.0, Color(0.12, 0.06, 0.02, 0.18))

# a horizontal disc in the world, projected
func _ell_proj(d: CanvasItem, c: Vector3, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 32:
		var a: float = TAU * float(k) / 32.0
		pts.append(_proj(c + Vector3(cos(a) * r, 0.0, sin(a) * r)))
	_safe(d, pts, col)

# a projected shape can fold over itself at some angles; such a frame it is simply not drawn
func _safe(d: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		d.draw_colored_polygon(pts, col)

# --- the cards: thin boxes riding the ring, their faces and backs mapped from the baked tiles ---------------

func _draw_cards(d: Control) -> void:
	if _cam.is_empty() or not _baked:
		return
	var items: Array = []
	for k in N:
		var a: float = t * SPEED + TAU * float(k) / float(N)
		var bob: float = 10.0 * sin(t * 1.1 + float(k))
		var c: Vector3 = Vector3(sin(a) * RING_R, RING_Y + bob, cos(a) * RING_R)
		items.append([_depth(c), k, a, c])
	items.sort_custom(func(x, y): return float(x[0]) > float(y[0]))      # far first
	for it in items:
		_card_box(d, int(it[1]), float(it[2]), it[3])

# THE CARD AS A ROUNDED TILE IN 3-D (a square box behind the rounded face showed its corners, "like it's
# printed on a square glass box", the user): the face and the back are the tile's rounded outline, the edge
# runs all round that outline, each piece of it lit by the way it faces
func _outline(hw: float) -> Array:
	var pts: Array = []
	var rad: float = hw * float(TILE.RADIUS) / (float(TILE.S) * 0.5)
	var corners: Array = [Vector2(hw - rad, -(hw - rad)), Vector2(hw - rad, hw - rad), Vector2(-(hw - rad), hw - rad), Vector2(-(hw - rad), -(hw - rad))]
	for ci in 4:
		for k in 5:
			var ang: float = -PI * 0.5 + PI * 0.5 * float(ci) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(corners[ci]) + Vector2(cos(ang), sin(ang)) * rad)
	return pts          # x right, y DOWN, in the card's plane

func _card_box(d: Control, k: int, a: float, c: Vector3) -> void:
	# the card faces out from the ring (its normal along the radius), tilted back a touch, rocking gently
	var side: Vector3 = Vector3(cos(a), 0.0, -sin(a))
	var tilt: float = 0.12 + 0.05 * sin(t * 1.3 + float(k))
	var n: Vector3 = (Vector3(sin(a), 0.0, cos(a)) * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var up: Vector3 = n.cross(side).normalized()
	var hw: float = CARD_W * 0.5
	var ht: float = CARD_T * 0.5
	var outl: Array = _outline(hw)
	var front3: Array = []
	var back3: Array = []
	for p2 in outl:
		var q: Vector2 = p2
		front3.append(c + n * ht + side * q.x - up * q.y)
		back3.append(c - n * ht + side * q.x - up * q.y)
	var to_eye: Vector3 = (Vector3(_cam["eye"]) - c).normalized()
	# which face we see, tested from the eye to THAT face (not to the card's center: at the sides of the ring the
	# two differ, and the card flipped a frame early or late -- a jump)
	var eye: Vector3 = _cam["eye"]
	var show_front: bool = n.dot(eye - (c + n * ht)) > 0.0
	# the edge all round: a strip between face and back for each step of the outline, drawn where it faces us
	var m: int = outl.size()
	var body: Color = Color(0.92, 0.88, 0.80)
	for i2 in m:
		var j2: int = (i2 + 1) % m
		var mid2: Vector2 = (Vector2(outl[i2]) + Vector2(outl[j2])) * 0.5
		var en: Vector3 = (side * mid2.x - up * mid2.y).normalized()
		var strip_mid: Vector3 = (Vector3(front3[i2]) + Vector3(back3[j2])) * 0.5
		if en.dot(eye - strip_mid) <= 0.0:
			continue
		var lit: float = clampf(0.55 + 0.45 * en.dot(Vector3(-0.4, 0.8, 0.4).normalized()), 0.35, 1.0)
		var poly: PackedVector2Array = PackedVector2Array([_proj(front3[i2]), _proj(front3[j2]), _proj(back3[j2]), _proj(back3[i2])])
		var hull: PackedVector2Array = Geometry2D.convex_hull(poly)
		if hull.size() >= 4:
			hull.remove_at(hull.size() - 1)
			# a strip seen exactly side-on has no area and will not triangulate
			if Geometry2D.triangulate_polygon(hull).size() > 0 and absf(_area(hull)) > 0.5:
				d.draw_colored_polygon(hull, Color(body.r * lit, body.g * lit, body.b * lit))
	# the face toward the camera, the baked tile laid on its rounded outline in perspective
	var face3: Array = front3 if show_front else back3
	var tex: Texture2D = _face_tex[k][0 if show_front else 1]
	var pts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var light: float = clampf(0.72 + 0.28 * absf(n.dot(to_eye)), 0.0, 1.0)
	for i3 in m:
		pts.append(_proj(face3[i3]))
		var q2: Vector2 = outl[i3]
		# seen from behind the card's left and right are swapped
		var ux: float = q2.x if show_front else -q2.x
		uvs.append(Vector2(0.5 + ux / (2.0 * hw) * (float(TILE.S) / float(TILE.S)), 0.5 + q2.y / (2.0 * hw)))
		cols.append(Color(light, light, light))
	# exactly edge-on the face is a line with no area (and will not triangulate); only then is it left out
	if absf(_area(pts)) > 0.5 and Geometry2D.triangulate_polygon(pts).size() > 0:
		d.draw_polygon(pts, cols, uvs, tex)

func _area(poly: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return sum * 0.5

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Moving Cards", "Remember moving cards", Color(1.0, 0.94, 0.82), Color(0.16, 0.08, 0.04), Color(1.0, 0.82, 0.55, 0.25))
