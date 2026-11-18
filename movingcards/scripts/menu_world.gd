extends "res://scripts/menu_poster3d.gd"

# MOVING CARDS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A CAROUSEL IN A
# ROOM. The room is REAL 3-D since 2026-11-18 (the hand-drawn one was "flat"): a wall papered in a figured stripe over
# raised wainscot panels and a dado rail, a window at dusk -- sashes, a deep reveal, a sill, the sky and the roofs
# beyond -- framed by velvet curtains hanging in folds from a brass rod, a floor lamp with a pleated shade lighting the
# corner, a patterned rug on oak boards, a framed picture, and a round oak table on a turned pedestal. It is baked, one
# picture per platform (`menu_room.webp`, `menu_room_d.webp`). Above the table the cards ride a ring, LIVE: real thin
# boxes (a face, a back and the edge all round their rounded outline), each facing out from the ring, so as one comes
# round to the front its FACE turns to us and going round the back we see its BACK -- they turn over because they
# are turning, not by a trick. They are projected by the same 3-D camera as the room (`screen_of`). The faces are
# glazed memory tiles (menu_card.gd, rendered once into pictures and laid on the projected card); their shadows lie
# on the tabletop. Not a card table (the user: playing cards "looks like a gambling game"). Made up, never the board.

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
const LAMP_POS: Vector3 = Vector3(430.0, 0.0, -470.0)

var _cards_layer: Control = null
var _face_tex: Array = []            # per card: [face texture, back texture]
var _baked: bool = false

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	_cards_layer = Control.new()
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_layer.draw.connect(func() -> void: _draw_cards(_cards_layer))
	add_child(_cards_layer)
	if _top != null:
		move_child(_top, get_child_count() - 1)
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

# --- the camera and the room: real 3-D, baked -------------------------------------------------------------------

func _baked_path() -> String:
	return "res://movingcards/art/menu_room.webp" if mobile else "res://movingcards/art/menu_room_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 330.0, 1250.0)

func _aim() -> Vector3:
	return Vector3(0.0, 90.0, -120.0)

func _fov() -> float:
	return 33.0

func _frame_frac() -> float:
	return 0.52

func _environment(env: Environment) -> void:
	env.background_color = Color(0.06, 0.04, 0.03)
	env.ambient_light_color = Color(0.70, 0.58, 0.46)
	env.ambient_light_energy = 0.34

func _build_lights() -> void:
	# the floor lamp, warm, its light pooling in the corner and on the table; dusk through the window, cool; a soft
	# warm key from over our shoulder so the room reads
	light(LAMP_POS + Vector3(0.0, FLOOR_Y + 414.0, 60.0), Color(1.0, 0.82, 0.58), 3.0, 1000.0)
	# the shade's open top and foot throw the light up and down the wall behind, in soft scallops
	spot(LAMP_POS + Vector3(0.0, FLOOR_Y + 420.0, 0.0), LAMP_POS + Vector3(0.0, FLOOR_Y + 900.0, -150.0), Color(1.0, 0.84, 0.60), 1.0, 600.0, 34.0)
	spot(LAMP_POS + Vector3(0.0, FLOOR_Y + 410.0, 0.0), LAMP_POS + Vector3(0.0, FLOOR_Y, -60.0), Color(1.0, 0.84, 0.60), 0.8, 600.0, 40.0)
	spot(Vector3(-330.0, 300.0, -700.0), Vector3(-200.0, FLOOR_Y, 100.0), Color(0.60, 0.66, 1.0), 1.4, 1500.0, 40.0)
	spot(Vector3(200.0, 900.0, 900.0), Vector3(0.0, 0.0, -100.0), Color(1.0, 0.93, 0.84), 1.8, 2600.0, 30.0, true)

func _depth(p: Vector3) -> float:
	return (p - _eye()).dot((_aim() - _eye()).normalized())

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _cards_layer == null:
		return
	_cards_layer.queue_redraw()

# --- textures ---

func _paper(n: int) -> ImageTexture:
	# a figured stripe: a deep claret band and a warm sand band, a fine gold pinstripe between, a small sprig in the
	# sand band, the paper's own mottle
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u: float = float(x) / float(n)
			var c: Color = Color(0.50, 0.33, 0.30) if u < 0.5 else Color(0.70, 0.60, 0.48)
			if absf(u - 0.5) < 0.012 or u < 0.012 or u > 0.988:
				c = Color(0.74, 0.60, 0.36)
			if u > 0.5:
				var sx: float = (u - 0.75) * float(n)
				var sy: float = float(y % (n / 2)) - float(n) * 0.25
				if sx * sx + sy * sy * 0.4 < 9.0:
					c = Color(0.56, 0.40, 0.34)
				elif absf(sx) < 0.8 and absf(sy) < 9.0:
					c = Color(0.40, 0.36, 0.20)
			c = c.darkened(0.06 * h01(x * 13 + y * 7))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _velvet(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var weave: float = 0.5 + 0.5 * sin(float(x) * 2.2) * sin(float(y) * 0.6)
			img.set_pixel(x, y, base.darkened(0.10 * weave + 0.08 * h01(x * 11 + y * 5)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _rug(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: Vector2 = Vector2(float(x), float(y)) / float(n) - Vector2(0.5, 0.5)
			var r: float = v.length() * 2.0
			var ang: float = atan2(v.y, v.x)
			var c: Color = Color(0.42, 0.10, 0.10)
			if r > 0.90:
				c = Color(0.16, 0.12, 0.22)
			elif r > 0.84:
				c = Color(0.82, 0.64, 0.34)
			elif r > 0.70:
				c = Color(0.16, 0.12, 0.22) if sin(ang * 24.0) > 0.0 else Color(0.70, 0.30, 0.16)
			elif r > 0.66:
				c = Color(0.82, 0.64, 0.34)
			elif r < 0.22:
				c = Color(0.16, 0.12, 0.22) if r > 0.16 else Color(0.82, 0.64, 0.34)
			elif sin(ang * 8.0 + r * 9.0) > 0.6:
				c = Color(0.62, 0.22, 0.14)
			c = c.darkened(0.12 * h01(x * 7 + y * 3))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _dusk(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = float(y) / float(n)
			var c: Color = Color(0.10, 0.10, 0.28).lerp(Color(0.46, 0.26, 0.46), smoothstep(0.2, 0.7, v)).lerp(Color(1.0, 0.62, 0.40), smoothstep(0.65, 1.0, v))
			if v < 0.5 and h01(x * 97 + y * 13) > 0.996:
				c = Color(1.0, 0.96, 0.86)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _curtain(x0: float, w: float, top_y: float, bot_y: float, z: float, m: StandardMaterial3D, gather: float) -> void:
	# a velvet curtain hanging from the rod in deep folds, drawn in at its foot toward the window's side (`gather`),
	# its hem a little swept back
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 36
	var ny: int = 20
	var grid: Array = []
	for j in ny + 1:
		var v: float = float(j) / float(ny)
		var row: Array = []
		var pinch: float = 1.0 - 0.35 * v * v
		for i in nx + 1:
			var u: float = float(i) / float(nx)
			var x: float = x0 + (gather + (u - gather) * pinch) * w
			var fold: float = sin(u * TAU * 5.0) * (10.0 + 6.0 * v) + sin(u * TAU * 11.0 + v * 2.0) * 2.0
			row.append([Vector3(x, lerpf(top_y, bot_y, v), z + fold + 8.0 * v * v), Vector2(u * 3.0, v * 4.0)])
		grid.append(row)
	for j2 in ny:
		for i2 in nx:
			var q: Array = [grid[j2][i2], grid[j2 + 1][i2], grid[j2 + 1][i2 + 1], grid[j2][i2], grid[j2 + 1][i2 + 1], grid[j2][i2 + 1]]
			for vv in q:
				st.set_uv(vv[1])
				st.add_vertex(vv[0])
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)

func _build_still() -> void:
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.30, 0.0, tex_wood(128, Color(0.52, 0.30, 0.14), 5), Vector3(2, 2, 1))
	oak.clearcoat_enabled = true
	oak.clearcoat = 0.8
	var paint: StandardMaterial3D = mat(Color(0.88, 0.84, 0.76), 0.5)
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, tex_wood(128, Color(0.30, 0.16, 0.08), 7), Vector3(3, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.30), 0.25, 0.85)
	var velvet: StandardMaterial3D = mat(Color.WHITE, 0.75, 0.0, _velvet(64, Color(0.50, 0.12, 0.10)), Vector3(4, 2, 1))
	velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	velvet.rim_enabled = true
	velvet.rim = 0.5
	# THE FLOOR: oak boards running away from us
	box(Vector3(3200.0, 6.0, 2600.0), mat(Color.WHITE, 0.45, 0.0, tex_wood(128, Color(0.40, 0.24, 0.12), 3), Vector3(16, 6, 1)), Vector3(0.0, FLOOR_Y - 3.0, 400.0), Vector3(0.0, 90.0, 0.0))
	# THE BACK WALL with the window's opening in it (four pieces round the hole), papered above the dado
	var wx0: float = -470.0
	var wx1: float = -190.0
	var wy0: float = 80.0
	var wy1: float = 470.0
	var paper: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _paper(128), Vector3(1, 1, 1))
	paper.uv1_triplanar = true
	paper.uv1_scale = Vector3(1.0 / 46.0, 1.0 / 92.0, 1.0)
	var wall_z: float = WALL_Z - 15.0
	var top_y: float = 1100.0
	var dado_y: float = FLOOR_Y + 150.0
	box(Vector3(1600.0 + wx0 - 0.0, top_y - dado_y, 30.0), paper, Vector3((-1600.0 + wx0) * 0.5, (top_y + dado_y) * 0.5, wall_z))
	box(Vector3(1600.0 - wx1, top_y - dado_y, 30.0), paper, Vector3((1600.0 + wx1) * 0.5, (top_y + dado_y) * 0.5, wall_z))
	box(Vector3(wx1 - wx0, top_y - wy1, 30.0), paper, Vector3((wx0 + wx1) * 0.5, (top_y + wy1) * 0.5, wall_z))
	box(Vector3(wx1 - wx0, wy0 - dado_y, 30.0), paper, Vector3((wx0 + wx1) * 0.5, (wy0 + dado_y) * 0.5, wall_z))
	# the wainscot: raised panels in a frame, a molded dado rail, a skirting
	box(Vector3(3200.0, dado_y - FLOOR_Y, 30.0), dark_wood, Vector3(0.0, (dado_y + FLOOR_Y) * 0.5, wall_z))
	var px0: float = -1500.0
	while px0 < 1500.0:
		put(rbox_mesh(70.0, 40.0, 8.0, 6.0, 4.0), dark_wood, Vector3(px0 + 90.0, FLOOR_Y + 75.0, wall_z + 15.0), Vector3(90.0, 0.0, 0.0))
		px0 += 180.0
	box(Vector3(3200.0, 12.0, 14.0), dark_wood, Vector3(0.0, dado_y, wall_z + 20.0))
	cyl(6.0, 6.0, 3200.0, dark_wood, Vector3(0.0, dado_y + 7.0, wall_z + 24.0), Vector3(0.0, 0.0, 90.0), null, 12)
	box(Vector3(3200.0, 22.0, 10.0), dark_wood, Vector3(0.0, FLOOR_Y + 11.0, wall_z + 18.0))
	# a cornice line up under the ceiling
	box(Vector3(3200.0, 30.0, 24.0), paint, Vector3(0.0, top_y - 20.0, wall_z + 20.0))
	# THE WINDOW: its reveal, a sill, two sashes with glazing bars, the dusk and the roofs beyond
	for side in [wx0, wx1]:
		box(Vector3(4.0, wy1 - wy0, 60.0), paint, Vector3(side, (wy0 + wy1) * 0.5, wall_z - 15.0))
	box(Vector3(wx1 - wx0, 4.0, 60.0), paint, Vector3((wx0 + wx1) * 0.5, wy1, wall_z - 15.0))
	box(Vector3(wx1 - wx0 + 40.0, 10.0, 46.0), paint, Vector3((wx0 + wx1) * 0.5, wy0 - 3.0, wall_z + 18.0))
	var sash_z: float = wall_z - 30.0
	var wcx: float = (wx0 + wx1) * 0.5
	for bar_x in [wx0 + 5.0, wcx, wx1 - 5.0]:
		box(Vector3(10.0, wy1 - wy0, 8.0), paint, Vector3(bar_x, (wy0 + wy1) * 0.5, sash_z))
	for bar_y in [wy0 + 5.0, (wy0 + wy1) * 0.5, wy1 - 5.0, wy0 + (wy1 - wy0) * 0.25, wy0 + (wy1 - wy0) * 0.75]:
		box(Vector3(wx1 - wx0, 6.0 if absf(bar_y - (wy0 + wy1) * 0.5) > 1.0 else 12.0, 7.0), paint, Vector3(wcx, bar_y, sash_z))
	var sky: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _dusk(128))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(1400.0, 1000.0, 2.0), sky, Vector3(wcx, 300.0, wall_z - 700.0))
	var roof_m: StandardMaterial3D = mat(Color(0.10, 0.08, 0.14), 0.9)
	for rf in 7:
		var rx: float = wcx - 420.0 + float(rf) * 140.0
		var rh: float = 70.0 + 70.0 * h01(rf + 40)
		box(Vector3(130.0, rh, 40.0), roof_m, Vector3(rx, -40.0 + rh * 0.5, wall_z - 500.0))
		box(Vector3(64.0, 64.0, 40.0), roof_m, Vector3(rx, -40.0 + rh, wall_z - 500.0), Vector3(0.0, 0.0, 45.0))
		if rf % 2 == 0:
			box(Vector3(14.0, 18.0, 2.0), glow(Color(1.0, 0.78, 0.42)), Vector3(rx - 20.0, rh * 0.5 - 10.0, wall_z - 478.0))
	# THE CURTAINS from a brass rod with finials, either side of the window
	cyl(3.5, 3.5, wx1 - wx0 + 260.0, brass, Vector3(wcx, wy1 + 50.0, wall_z + 45.0), Vector3(0.0, 0.0, 90.0), null, 12)
	for fin in [-1.0, 1.0]:
		sphere(8.0, brass, Vector3(wcx + fin * ((wx1 - wx0) * 0.5 + 136.0), wy1 + 50.0, wall_z + 45.0))
		cyl(3.0, 3.0, 40.0, brass, Vector3(wcx + fin * ((wx1 - wx0) * 0.5 + 100.0), wy1 + 50.0, wall_z + 25.0), Vector3(90.0, 0.0, 0.0), null, 10)
	_curtain(wx0 - 120.0, 150.0, wy1 + 46.0, FLOOR_Y + 4.0, wall_z + 50.0, velvet, 1.0)
	_curtain(wx1 - 30.0, 150.0, wy1 + 46.0, FLOOR_Y + 4.0, wall_z + 50.0, velvet, 0.0)
	# A FRAMED PICTURE on the wall to the right: a gilt frame, a landscape inside
	var pic_c: Vector3 = Vector3(130.0, 330.0, wall_z + 18.0)
	var gilt: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.35, 0.45)
	for fb in 4:
		var horiz: bool = fb < 2
		var sgn: float = -1.0 if fb % 2 == 0 else 1.0
		var bar_len: float = 200.0 if horiz else 156.0
		var bc: Vector3 = pic_c + (Vector3(0.0, sgn * 70.0, 0.0) if horiz else Vector3(sgn * 92.0, 0.0, 0.0))
		cyl(8.0, 8.0, bar_len, gilt, bc + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, 90.0) if horiz else Vector3.ZERO, null, 12)
		box(Vector3(bar_len, 4.0, 4.0) if horiz else Vector3(4.0, bar_len, 4.0), gilt, bc * Vector3(1, 1, 1) + (Vector3(0.0, -sgn * 9.0, 10.0) if horiz else Vector3(-sgn * 9.0, 0.0, 10.0)))
	# THE CANVAS: an OIL PAINTING of a summer landscape (2026-11-18; the user: a dusk sky with three lumps of hill read as a
	# window, "a bit empty"): a sky of soft clouds, blue hills, a river winding down between meadows, a stand of trees,
	# a farmhouse with a red roof, a path, a little figure; brushwork in the strokes, the varnish yellowed with age
	var oil: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _painting(256, 200))
	oil.clearcoat_enabled = true
	oil.clearcoat = 0.4
	box(Vector3(176.0, 136.0, 1.0), mat(Color(0.20, 0.16, 0.12), 0.8), pic_c + Vector3(0.0, 0.0, 1.5))
	var canvas: QuadMesh = QuadMesh.new()           # (a box spreads its texture over six faces: only a strip showed)
	canvas.size = Vector2(176.0, 136.0)
	put(canvas, oil, pic_c + Vector3(0.0, 0.0, 2.2))
	light(pic_c + Vector3(0.0, 95.0, 50.0), Color(1.0, 0.86, 0.62), 0.9, 180.0)
	box(Vector3(60.0, 5.0, 10.0), brass, pic_c + Vector3(0.0, 82.0, 14.0))
	# THE FLOOR LAMP (the user: "the standing lamp is bad" -- a thin rod under a small flat shade): a turned brass lamp
	# -- a heavy stepped base, the stem turned with knuckles and collars, a harp up round the bulb and a finial -- under
	# a LINEN DRUM SHADE lit from within (brightest at the bulb's height, the weave showing, darker trim bands at its
	# rims), throwing its light up and down the wall in two soft scallops
	var lx: float = LAMP_POS.x
	var lz: float = LAMP_POS.z
	var fy: float = FLOOR_Y
	var aged: StandardMaterial3D = mat(Color(0.78, 0.58, 0.30), 0.32, 0.85)
	put(_lathe([Vector2(0.0, 0.0), Vector2(58.0, 0.0), Vector2(60.0, 4.0), Vector2(56.0, 9.0), Vector2(40.0, 13.0), Vector2(34.0, 20.0), Vector2(22.0, 26.0), Vector2(14.0, 34.0), Vector2(9.0, 44.0), Vector2(0.0, 44.0)], 40), aged, Vector3(lx, fy, lz))
	put(_lathe([Vector2(0.0, 0.0), Vector2(6.0, 0.0), Vector2(5.0, 120.0), Vector2(8.0, 126.0), Vector2(10.0, 132.0), Vector2(8.0, 138.0), Vector2(5.0, 144.0), Vector2(4.5, 280.0), Vector2(7.5, 286.0), Vector2(9.0, 292.0), Vector2(7.0, 298.0), Vector2(4.0, 302.0), Vector2(4.0, 330.0), Vector2(0.0, 330.0)], 20), aged, Vector3(lx, fy + 44.0, lz))
	var lamp_top: float = fy + 374.0
	# the bulb's socket, the harp's two arms rising round it to the finial
	cyl(7.0, 7.0, 22.0, aged, Vector3(lx, lamp_top + 10.0, lz), Vector3.ZERO, null, 16)
	for hs in [-1.0, 1.0]:
		var harp: PackedVector3Array = PackedVector3Array()
		for hk in 9:
			var hu: float = float(hk) / 8.0
			harp.append(Vector3(lx + hs * sin(hu * PI) * 30.0, lamp_top + 4.0 + hu * 84.0, lz))
		put(tube_mesh(harp, 1.6, 8), aged, Vector3.ZERO)
	sphere(13.0, glow(Color(1.0, 0.95, 0.82)), Vector3(lx, lamp_top + 40.0, lz))
	var shade_sm: ShaderMaterial = ShaderMaterial.new()
	var ssh: Shader = Shader.new()
	ssh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float h = UV.y;                       // 0 top .. 1 foot
	float glow_k = 0.55 + 0.55 * exp(-pow((h - 0.55) / 0.30, 2.0));
	float weave = 0.94 + 0.06 * sin(UV.x * 900.0) * sin(h * 260.0);
	float slub = 0.97 + 0.03 * sin(UV.x * 61.0 + sin(h * 13.0) * 3.0);
	vec3 linen = vec3(1.0, 0.86, 0.62);
	vec3 c = linen * glow_k * weave * slub;
	float rim = smoothstep(0.0, 0.05, h) * smoothstep(1.0, 0.95, h);
	c = mix(vec3(0.55, 0.38, 0.22), c, rim);
	ALBEDO = c * (FRONT_FACING ? 1.0 : 0.75);
}"""
	shade_sm.shader = ssh
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = 50.0
	drum.bottom_radius = 66.0
	drum.height = 80.0
	drum.radial_segments = 48
	drum.cap_top = false
	drum.cap_bottom = false
	put(drum, shade_sm, Vector3(lx, lamp_top + 46.0, lz))
	for ty in [[lamp_top + 86.0, 50.5], [lamp_top + 6.0, 66.5]]:
		var trim: TorusMesh = TorusMesh.new()
		trim.inner_radius = float(ty[1]) - 1.6
		trim.outer_radius = float(ty[1]) + 1.6
		trim.rings = 64
		put(trim, mat(Color(0.62, 0.42, 0.22), 0.7), Vector3(lx, float(ty[0]), lz))
	sphere(6.0, aged, Vector3(lx, lamp_top + 92.0, lz))
	cyl(1.5, 3.5, 10.0, aged, Vector3(lx, lamp_top + 101.0, lz), Vector3.ZERO, null, 12)
	# the cord, off the base and along the floor
	put(tube_mesh(PackedVector3Array([Vector3(lx + 40.0, fy + 3.0, lz), Vector3(lx + 80.0, fy + 1.5, lz + 20.0), Vector3(lx + 140.0, fy + 1.5, lz - 30.0)]), 1.6, 6), mat(Color(0.12, 0.10, 0.09), 0.6), Vector3.ZERO)
	# THE RUG under the table
	cyl(430.0, 430.0, 3.0, mat(Color.WHITE, 0.95, 0.0, _rug(256)), Vector3(0.0, FLOOR_Y + 1.5, 0.0), Vector3.ZERO, null, 64)
	# THE TABLE: a round oak top with a rounded edge, a turned pedestal, three splayed feet
	cyl(TABLE_R, TABLE_R, 12.0, oak, Vector3(0.0, -6.0, 0.0), Vector3.ZERO, null, 64)
	var edge: TorusMesh = TorusMesh.new()
	edge.inner_radius = TABLE_R - 7.0
	edge.outer_radius = TABLE_R + 5.0
	edge.rings = 64
	put(edge, oak, Vector3(0.0, -6.0, 0.0))
	cyl(TABLE_R - 30.0, TABLE_R - 30.0, 16.0, dark_wood, Vector3(0.0, -20.0, 0.0), Vector3.ZERO, null, 48)
	var prof: Array = [[-28.0, 26.0], [-50.0, 18.0], [-70.0, 28.0], [-80.0, 30.0], [-100.0, 20.0], [-130.0, 16.0], [-150.0, 32.0], [-165.0, 40.0]]
	for pi in prof.size() - 1:
		var y0: float = float(prof[pi][0])
		var y1: float = float(prof[pi + 1][0])
		cyl(float(prof[pi][1]), float(prof[pi + 1][1]), y0 - y1, oak, Vector3(0.0, (y0 + y1) * 0.5, 0.0), Vector3.ZERO, null, 32)
	for ft in 3:
		var fa: float = TAU * float(ft) / 3.0 + 0.5
		var foot: MeshInstance3D = put(rbox_mesh(70.0, 14.0, 18.0, 10.0, 5.0), oak, Vector3(cos(fa) * 60.0, FLOOR_Y + 2.0, sin(fa) * 60.0))
		foot.rotation = Vector3(0.0, -fa, 0.0)

func _ell_proj(d: CanvasItem, c: Vector3, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 32:
		var a: float = TAU * float(k) / 32.0
		pts.append(screen_of(c + Vector3(cos(a) * r, 0.0, sin(a) * r)))
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		d.draw_colored_polygon(pts, col)

# --- the cards: thin boxes riding the ring, their faces and backs mapped from the baked tiles ---------------

func _draw_cards(d: Control) -> void:
	if _cam3 == null:
		return
	# the cards' shadows on the tabletop, under each card
	for k in N:
		var a5: float = t * SPEED + TAU * float(k) / float(N)
		_ell_proj(d, Vector3(sin(a5) * RING_R, 0.0, cos(a5) * RING_R), 34.0, Color(0.12, 0.06, 0.02, 0.18))
	if not _baked:
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
	var to_eye: Vector3 = (_eye() - c).normalized()
	# which face we see, tested from the eye to THAT face (not to the card's center: at the sides of the ring the
	# two differ, and the card flipped a frame early or late -- a jump)
	var eye: Vector3 = _eye()
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
		var poly: PackedVector2Array = PackedVector2Array([screen_of(front3[i2]), screen_of(front3[j2]), screen_of(back3[j2]), screen_of(back3[i2])])
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
	var lit_k: float = clampf(0.72 + 0.28 * absf(n.dot(to_eye)), 0.0, 1.0)
	for i3 in m:
		pts.append(screen_of(face3[i3]))
		var q2: Vector2 = outl[i3]
		# seen from behind the card's left and right are swapped
		var ux: float = q2.x if show_front else -q2.x
		uvs.append(Vector2(0.5 + ux / (2.0 * hw) * (float(TILE.S) / float(TILE.S)), 0.5 + q2.y / (2.0 * hw)))
		cols.append(Color(lit_k, lit_k, lit_k))
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

# an oil landscape, painted in strokes: each stroke a short dab along the form, its color jittered, so the surface
# reads as brushwork; then the varnish's yellowing and a faint craquelure
func _painting(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for y in h:
		for x in w:
			var v: float = float(y) / float(h)
			var c: Color = Color(0.42, 0.58, 0.80).lerp(Color(0.92, 0.86, 0.70), smoothstep(0.0, 0.48, v))
			# the hills: two ranges, blue far, green near
			var far_h: float = 0.42 + 0.05 * sin(float(x) * 0.03) + 0.03 * sin(float(x) * 0.09 + 1.0)
			var near_h: float = 0.52 + 0.07 * sin(float(x) * 0.022 + 2.0) + 0.02 * sin(float(x) * 0.11)
			if v > far_h:
				c = Color(0.44, 0.52, 0.66).lerp(Color(0.38, 0.50, 0.46), (v - far_h) * 4.0)
			if v > near_h:
				c = Color(0.46, 0.60, 0.30).lerp(Color(0.30, 0.44, 0.18), (v - near_h) * 2.2)
			# the river: a band winding down to the foot, silver-blue
			var rx: float = 0.55 + 0.18 * sin(v * 9.0) * (v - near_h) * 2.0
			if v > near_h + 0.02 and absf(float(x) / float(w) - rx) < 0.012 + 0.06 * (v - near_h):
				c = Color(0.62, 0.72, 0.80).lerp(Color(0.85, 0.88, 0.86), 0.3 * sin(float(y) * 0.8))
			img.set_pixel(x, y, c)
	# clouds: soft dabs of white and warm gray
	for k in 220:
		var cx: float = rng.randf() * float(w)
		var cy: float = rng.randf_range(0.04, 0.30) * float(h)
		var r: float = rng.randf_range(3.0, 9.0)
		var col: Color = Color(1.0, 0.98, 0.94).lerp(Color(0.78, 0.76, 0.80), rng.randf() * 0.6)
		_dab(img, Vector2(cx, cy), r, Vector2(1.0, 0.25), col, 0.45)
	# a stand of trees at the left and one at the right, dark green crowns over trunks
	for t2 in 90:
		var left: bool = t2 < 60
		var tx: float = (rng.randf_range(0.06, 0.34) if left else rng.randf_range(0.72, 0.90)) * float(w)
		var ty: float = rng.randf_range(0.44, 0.62) * float(h)
		_dab(img, Vector2(tx, ty), rng.randf_range(4.0, 8.0), Vector2(0.5, 0.8), Color(0.14, 0.26, 0.12).lerp(Color(0.30, 0.42, 0.18), rng.randf()), 0.7)
	# the farmhouse: white walls, a red roof, a dark door, by the river
	var hx: int = int(float(w) * 0.62)
	var hy: int = int(float(h) * 0.60)
	img.fill_rect(Rect2i(hx, hy, 16, 10), Color(0.90, 0.86, 0.76))
	for ry in 7:
		img.fill_rect(Rect2i(hx - 2 + ry, hy - 1 - ry, 20 - ry * 2, 1), Color(0.66, 0.22, 0.16))
	img.fill_rect(Rect2i(hx + 6, hy + 4, 3, 6), Color(0.25, 0.16, 0.10))
	img.fill_rect(Rect2i(hx + 11, hy + 3, 3, 3), Color(0.30, 0.36, 0.44))
	# a path down to the foot, and a little figure on it
	for py in range(int(float(h) * 0.70), h):
		var f: float = (float(py) - float(h) * 0.70) / (float(h) * 0.30)
		var px: int = int(float(w) * (0.30 + 0.10 * f * f))
		img.fill_rect(Rect2i(px, py, 2 + int(f * 8.0), 1), Color(0.76, 0.66, 0.46))
	img.fill_rect(Rect2i(int(float(w) * 0.33), int(float(h) * 0.80), 2, 6), Color(0.70, 0.18, 0.14))
	img.fill_rect(Rect2i(int(float(w) * 0.33), int(float(h) * 0.79), 2, 2), Color(0.86, 0.70, 0.56))
	# meadow brushwork: flecks of light and dark green, a few flowers
	for m in 600:
		var mx: float = rng.randf() * float(w)
		var my: float = rng.randf_range(0.56, 1.0) * float(h)
		var mc: Color = img.get_pixel(clampi(int(mx), 0, w - 1), clampi(int(my), 0, h - 1))
		_dab(img, Vector2(mx, my), rng.randf_range(1.0, 2.2), Vector2(1.0, 0.5), mc.lightened(rng.randf_range(-0.15, 0.20)) if m % 9 != 0 else Color(0.95, 0.85, 0.40), 0.6)
	# the varnish: yellowed, darker at the edges; a faint craquelure
	for y2 in h:
		for x2 in w:
			var ex: float = minf(minf(float(x2), float(w - 1 - x2)) / float(w), minf(float(y2), float(h - 1 - y2)) / float(h))
			var c2: Color = img.get_pixel(x2, y2).lerp(Color(0.62, 0.50, 0.26), 0.16).darkened(0.25 * (1.0 - smoothstep(0.0, 0.18, ex)))
			if h01(x2 * 131 + y2 * 37) > 0.985:
				c2 = c2.darkened(0.15)
			img.set_pixel(x2, y2, c2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _dab(img: Image, c: Vector2, r: float, squash: Vector2, col: Color, a: float) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d: float = Vector2((float(x) - c.x) / (r * squash.x + 0.01), (float(y) - c.y) / (r * squash.y + 0.01)).length()
			if d < 1.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a * (1.0 - d * d)))

# a turned solid: the profile (radius, height) swept round the y axis
func _lathe(profile: Array, segs: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		for k in segs:
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var v00: Vector3 = Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01: Vector3 = Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10: Vector3 = Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11: Vector3 = Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			for v in [v00, v10, v11, v00, v11, v01]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()
