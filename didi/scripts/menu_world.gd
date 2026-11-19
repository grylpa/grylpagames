extends "res://scripts/menu_poster3d.gd"

# PINPOINT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): a STAKEOUT, seen
# from a high window at night -- the street below is REAL 3-D now (it was a drawn picture): an old brick building with a
# deep doorway and two upper windows (one lit, curtained), the HOTEL beside it -- its lobby lit behind tall glass (a warm
# back wall, a chandelier, the desk, a palm), a striped awning, the neon HOTEL sign -- stone pavement, the curb, the wet
# road, a lamp post pouring light. In 2-D over it: the game's own people under umbrellas (agent.gd) walking along the
# pavement (placed from the 3-D street), the lamp and the sign mirrored in the wet road, fine rain falling, and through
# the glass streaming with rain (the window's dark frame round the view) -- every few seconds lightning, and in its flash
# the LOOKOUT in the doorway, the yellow raincoat under the clear umbrella, gone into the dark again a moment later. The
# street is baked, one picture per platform (`menu_street.webp`, `menu_street_d.webp`). Not the game's square (a picture,
# not the board). Made up, never the board.

const AGENT: PackedScene = preload("res://didi/scenes/agent.tscn")
const WALKERS: int = 4
const FLASH_EVERY: float = 6.0
const FACADE_Z: float = -160.0
const CURB_Z: float = -30.0
const DOOR: Vector3 = Vector3(-250.0, 0.0, -170.0)
const LAMP: Vector3 = Vector3(290.0, 230.0, -55.0)
const SIGN: Vector3 = Vector3(165.0, 215.0, -150.0)

var _walkers: Array = []
var _lookout: Node2D = null
var _layer: Node2D = null
var _clip: Control = null
var _drops: Array = []
# THE GLASS, THE FRAME AND THE NAME DRAWN ONCE (2026-11-19: redrawn every frame they cost a phone ~15 ms): every color in
# them goes linearly with the flash, so they are drawn twice -- in the dark (_glass0) and at the flash's height
# (_glass1) -- and the second is laid over the first by the flash's strength, which is the same picture. Children of
# the top layer, so over its live parts (the rain outside, the street's glow, the beads that run).
var _glass0: DrawnOnce = null
var _glass1: DrawnOnce = null
var _glass_for: Rect2 = Rect2()

func _baked_path() -> String:
	return "res://didi/art/menu_street.webp" if mobile else "res://didi/art/menu_street_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 380.0, 600.0) if mobile else Vector3(0.0, 360.0, 700.0)

func _aim() -> Vector3:
	return Vector3(-20.0, 150.0, -120.0) if mobile else Vector3(-10.0, 150.0, -120.0)

func _fov() -> float:
	return 58.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.03, 0.05)
	env.ambient_light_color = Color(0.45, 0.50, 0.65)
	env.ambient_light_energy = 0.32

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	# DRAW ORDER WITHOUT Z (the user, 2026-11-19): a z of their own put the far walkers' umbrellas over the window's
	# center bar; lifting the frame's TOP layer to z 2000 then buried the menu's controls under its wall of plaster
	# ("where is the menu?"); sinking the street below zero put it under the menu's own backdrop. So every walker is at
	# z 0 (the agent scene's root carries 3; its only other part, the old sprite, is hidden) and the ORDER is the tree's:
	# the lookout first, then the walkers far to near (re-sorted as they pass), and the top layer, the poster's last
	# child, over them all
	# the people are clipped to the glass: walking in and out, they passed over the window frame
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_layer = Node2D.new()
	_clip.add_child(_layer)
	for k in WALKERS:
		var a: Node2D = _agent(0, k % 7, [Color(0.85, 0.25, 0.25), Color(0.25, 0.45, 0.85), Color(0.95, 0.75, 0.25), Color(0.30, 0.65, 0.40)][k])
		_walkers.append(a)
	_lookout = _agent(1, 0, Color(1, 1, 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for _i in 120:
		_drops.append([rng.randf(), rng.randf(), rng.randf_range(2.5, 6.0), pow(rng.randf(), 2.2) * 0.12])

func _agent(kind: int, print_i: int, col: Color) -> Node2D:
	var a: Node2D = AGENT.instantiate()
	_layer.add_child(a)
	a.set("time_to_hide_ms", 1.0e15)
	a.call("set_kind", kind)
	a.call("set_texture", print_i)
	a.call("set_colors", [col, col.lightened(0.35)])
	return a

func _flash() -> float:
	var u: float = fmod(t + 4.6, FLASH_EVERY)      # the first flash 1.4 s in (at 4 s a player could miss it)
	if u > 0.8:
		return 0.0
	return maxf(exp(-u * 14.0), 0.6 * exp(-absf(u - 0.18) * 16.0))

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = (230.0 if mobile else 150.0) + 38.0
	var view: Rect2 = Rect2(60.0, top, full.x - 120.0, bottom - top - 52.0)
	return {"full": full, "bottom": bottom, "view": view}

func _build_lights() -> void:
	# the night's cool fill, the street lamp, the hotel lobby's warm light out through its glass, the lit window
	var night: DirectionalLight3D = DirectionalLight3D.new()
	night.light_color = Color(0.55, 0.62, 0.85)
	night.light_energy = 0.35
	root.add_child(night)
	night.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	light(LAMP + Vector3(0.0, -10.0, 0.0), Color(1.0, 0.84, 0.55), 2.6, 380.0, true)
	light(Vector3(165.0, 80.0, -120.0), Color(1.0, 0.76, 0.45), 1.6, 300.0)
	light(SIGN + Vector3(0.0, 0.0, 30.0), Color(1.0, 0.35, 0.50), 0.8, 200.0)

# --- the street: baked --------------------------------------------------------------------------------------------

func _brick(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.20, 0.16, 0.15))
	var bh: int = n / 16
	var bw: int = n / 8
	for row in 16:
		var off: int = (bw / 2) if row % 2 == 1 else 0
		for col in 9:
			var x0: int = col * bw - off
			var c: Color = Color(0.42, 0.22, 0.17).lerp(Color(0.52, 0.28, 0.20), h01(row * 31 + col))
			img.fill_rect(Rect2i(maxi(0, x0 + 1), row * bh + 1, mini(bw - 2, n - maxi(0, x0 + 1)), bh - 2), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _awning(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 4, false, Image.FORMAT_RGB8)
	for x in n:
		img.fill_rect(Rect2i(x, 0, 1, 4), Color(0.10, 0.32, 0.22) if (x * 12 / n) % 2 == 0 else Color(0.82, 0.78, 0.64))
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	var brick: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _brick(256), Vector3(4, 3, 1))
	var stone: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_speckle(128, Color(0.48, 0.44, 0.40), 0.08, 3, 4, Color(0.30, 0.28, 0.26)), Vector3(5, 3, 1))
	var dressed: StandardMaterial3D = mat(Color(0.55, 0.52, 0.48), 0.7)
	var dark: StandardMaterial3D = mat(Color(0.03, 0.03, 0.04), 1.0)
	var iron: StandardMaterial3D = mat(Color(0.10, 0.10, 0.12), 0.4, 0.6)
	# THE GROUND: pavement slabs, the curb, the wet road (dark and glossy)
	box(Vector3(1600.0, 4.0, FACADE_Z * -1.0 + CURB_Z), mat(Color.WHITE, 0.45, 0.0, tex_speckle(128, Color(0.30, 0.30, 0.33), 0.06, 5, 4, Color(0.18, 0.18, 0.20)), Vector3(14, 3, 1)), Vector3(0.0, 2.0, (FACADE_Z + CURB_Z) * 0.5))
	box(Vector3(1600.0, 8.0, 10.0), dressed, Vector3(0.0, 2.0, CURB_Z + 5.0))
	box(Vector3(1600.0, 2.0, 900.0), mat(Color(0.07, 0.08, 0.10), 0.15, 0.25), Vector3(0.0, -1.0, CURB_Z + 455.0))
	for k in 12:
		box(Vector3(36.0, 0.4, 6.0), mat(Color(0.60, 0.58, 0.50), 0.5), Vector3(-560.0 + float(k) * 100.0, 0.4, 180.0))
	# THE OLD BUILDING at the left: brick, a deep doorway with a stone surround and an open door, two upper windows
	_wall_with_holes(brick, -420.0, -20.0, 0.0, 330.0, 205.0, 295.0, [-330.0, -180.0], 70.0)
	box(Vector3(84.0, 160.0, 4.0), dark, Vector3(DOOR.x, 80.0, FACADE_Z - 40.0))
	box(Vector3(70.0, 152.0, 22.0), dark, Vector3(DOOR.x, 76.0, FACADE_Z - 10.0))
	for jx in [-1.0, 1.0]:
		box(Vector3(12.0, 166.0, 26.0), dressed, Vector3(DOOR.x + jx * 41.0, 83.0, FACADE_Z - 8.0))
	box(Vector3(100.0, 14.0, 28.0), dressed, Vector3(DOOR.x, 172.0, FACADE_Z - 7.0))
	box(Vector3(96.0, 8.0, 24.0), dressed, Vector3(DOOR.x, 4.0, FACADE_Z + 8.0))
	box(Vector3(28.0, 140.0, 4.0), mat(Color(0.26, 0.16, 0.10), 0.7), Vector3(DOOR.x + 30.0, 72.0, FACADE_Z - 28.0), Vector3(0.0, -70.0, 0.0))
	for w in 2:
		_window3(Vector3(-330.0 + float(w) * 150.0, 250.0, FACADE_Z), 70.0, 90.0, w == 1, Color(0.50, 0.08, 0.09))
	# a floor more over it, its windows, a cornice, chimney stacks with their pots
	_wall_with_holes(brick, -420.0, -20.0, 330.0, 480.0, 365.0, 455.0, [-330.0, -180.0], 70.0)
	_window3(Vector3(-330.0, 410.0, FACADE_Z), 70.0, 90.0, true, Color(0.78, 0.66, 0.36))
	_window3(Vector3(-180.0, 410.0, FACADE_Z), 70.0, 90.0, false, Color.BLACK)
	box(Vector3(412.0, 12.0, 30.0), dressed, Vector3(-220.0, 486.0, FACADE_Z - 5.0))
	box(Vector3(404.0, 8.0, 24.0), dressed, Vector3(-220.0, 476.0, FACADE_Z - 8.0))
	for cx2 in [-370.0, -90.0]:
		box(Vector3(46.0, 60.0, 30.0), brick, Vector3(cx2, 522.0, FACADE_Z - 40.0))
		box(Vector3(52.0, 6.0, 36.0), dressed, Vector3(cx2, 554.0, FACADE_Z - 40.0))
		for pt in [-12.0, 12.0]:
			cyl(5.0, 6.0, 16.0, mat(Color(0.45, 0.28, 0.20), 0.8), Vector3(cx2 + pt, 565.0, FACADE_Z - 40.0))
	cyl(4.0, 4.0, 480.0, iron, Vector3(-28.0, 240.0, FACADE_Z + 6.0))
	# THE HOTEL: a stone front, its LOBBY behind tall glass (a warm back wall, a chandelier, the desk, a palm), the
	# awning, the sign's board, the windows above
	_wall_with_holes(stone, -20.0, 400.0, 0.0, 340.0, 255.0, 325.0, [50.0, 170.0, 290.0], 70.0)
	var lobby_x: float = 165.0
	box(Vector3(290.0, 160.0, 4.0), dark, Vector3(lobby_x, 80.0, FACADE_Z - 11.0))
	box(Vector3(280.0, 150.0, 2.0), glow(Color(0.78, 0.50, 0.26)), Vector3(lobby_x, 78.0, FACADE_Z - 110.0))
	box(Vector3(280.0, 2.0, 100.0), mat(Color(0.40, 0.30, 0.20), 0.4), Vector3(lobby_x, 1.0, FACADE_Z - 60.0))
	for sx2 in [-1.0, 1.0]:
		box(Vector3(2.0, 150.0, 100.0), glow(Color(0.62, 0.38, 0.18)), Vector3(lobby_x + sx2 * 140.0, 78.0, FACADE_Z - 60.0))
	box(Vector3(280.0, 2.0, 100.0), glow(Color(0.55, 0.36, 0.20)), Vector3(lobby_x, 155.0, FACADE_Z - 60.0))
	sphere(12.0, glow(Color(1.0, 0.92, 0.70)), Vector3(lobby_x, 132.0, FACADE_Z - 60.0))
	box(Vector3(90.0, 40.0, 24.0), mat(Color(0.32, 0.16, 0.08), 0.5), Vector3(lobby_x - 80.0, 20.0, FACADE_Z - 80.0))
	cyl(10.0, 12.0, 26.0, mat(Color(0.45, 0.22, 0.12), 0.6), Vector3(lobby_x + 110.0, 13.0, FACADE_Z - 40.0))
	for f in 6:
		var fa: float = TAU * float(f) / 6.0
		var leaf: MeshInstance3D = sphere(14.0, mat(Color(0.16, 0.34, 0.14), 0.7), Vector3(lobby_x + 110.0 + cos(fa) * 14.0, 46.0, FACADE_Z - 40.0 + sin(fa) * 14.0))
		leaf.scale = Vector3(1.4, 0.4, 0.6)
	# the glass: ONE PLATE in its outer frame, faintly reflecting, a pair of brass push bars where the doors are (it had
	# glazing bars across it, and the people walking in front of the lobby -- drawn over it, rightly, as they are
	# nearer -- read as umbrellas passing IN FRONT OF THE WINDOW BARS, a draw-order error: the user, three times)
	var glass_m: StandardMaterial3D = mat(Color(0.55, 0.60, 0.75, 0.14), 0.05, 0.3)
	box(Vector3(290.0, 160.0, 1.0), glass_m, Vector3(lobby_x, 80.0, FACADE_Z + 0.5))
	for mx in [-145.0, 145.0]:
		box(Vector3(6.0, 160.0, 6.0), mat(Color(0.30, 0.24, 0.16), 0.4, 0.6), Vector3(lobby_x + mx, 80.0, FACADE_Z + 1.0))
	for hx in [-8.0, 8.0]:
		box(Vector3(3.0, 30.0, 3.0), mat(Color(0.92, 0.74, 0.36), 0.3, 0.8), Vector3(lobby_x + hx, 60.0, FACADE_Z + 4.0))
	# the awning: striped, sloping out over the pavement
	box(Vector3(320.0, 3.0, 70.0), mat(Color.WHITE, 0.6, 0.0, _awning(64)), Vector3(lobby_x, 178.0, FACADE_Z + 32.0), Vector3(-22.0, 0.0, 0.0))
	for sc in 13:
		var sc_m: MeshInstance3D = sphere(12.5, mat(Color(0.10, 0.32, 0.22) if sc % 2 == 0 else Color(0.82, 0.78, 0.64), 0.6), Vector3(lobby_x - 150.0 + float(sc) * 25.0, 162.0, FACADE_Z + 64.0))
		sc_m.scale = Vector3(1.0, 1.0, 0.35)
	# the sign: a dark board, the neon letters (lit)
	box(Vector3(180.0, 46.0, 6.0), mat(Color(0.08, 0.06, 0.08), 0.6), SIGN + Vector3(0.0, 0.0, -2.0))
	var neon: Label3D = label("HOTEL", 38.0, Color(1.0, 0.55, 0.70), SIGN + Vector3(0.0, 0.0, 2.0))
	neon.outline_size = 10
	neon.outline_modulate = Color(1.0, 0.25, 0.45, 0.8)
	for w2 in 3:
		_window3(Vector3(50.0 + float(w2) * 120.0, 290.0, FACADE_Z), 70.0, 70.0, w2 == 2, Color(0.82, 0.70, 0.42))
	# its upper floor, a cornice, and a water tank on the roof
	_wall_with_holes(stone, -20.0, 400.0, 340.0, 510.0, 385.0, 455.0, [50.0, 170.0, 290.0], 70.0)
	for w3 in 3:
		_window3(Vector3(50.0 + float(w3) * 120.0, 420.0, FACADE_Z), 70.0, 70.0, w3 == 0, Color(0.30, 0.42, 0.62))
	box(Vector3(432.0, 14.0, 32.0), dressed, Vector3(190.0, 516.0, FACADE_Z - 4.0))
	for dn in 30:
		box(Vector3(6.0, 6.0, 6.0), dressed, Vector3(-10.0 + float(dn) * 14.0, 505.0, FACADE_Z + 2.0))
	var tank_c: Vector3 = Vector3(300.0, 523.0, FACADE_Z - 80.0)
	for lg in 4:
		var la: float = TAU * float(lg) / 4.0 + 0.6
		cyl(2.5, 2.5, 50.0, iron, tank_c + Vector3(cos(la) * 30.0, 25.0, sin(la) * 30.0))
	cyl(38.0, 38.0, 60.0, mat(Color.WHITE, 0.9, 0.0, tex_wood(64, Color(0.30, 0.22, 0.16), 7), Vector3(3, 1, 1)), tank_c + Vector3(0.0, 80.0, 0.0), Vector3.ZERO, null, 24)
	cyl(4.0, 42.0, 26.0, mat(Color(0.18, 0.16, 0.16), 0.7), tank_c + Vector3(0.0, 123.0, 0.0), Vector3.ZERO, null, 24)
	for hb in 3:
		cyl(38.6, 38.6, 2.0, iron, tank_c + Vector3(0.0, 60.0 + float(hb) * 20.0, 0.0), Vector3.ZERO, null, 24)
	# THE CITY BEHIND: a hazy night sky glowing low over the town, and a far skyline with a few lit windows
	var sky_sh: ShaderMaterial = ShaderMaterial.new()
	var ssh: Shader = Shader.new()
	ssh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
void fragment() {
	float v = UV.y;
	vec3 top = vec3(0.015, 0.02, 0.05);
	vec3 low = vec3(0.20, 0.13, 0.14);
	vec3 c = mix(top, low, smoothstep(0.25, 1.0, v));
	float cloud = 0.5 + 0.5 * sin(UV.x * 18.0 + sin(UV.y * 9.0) * 2.0) * sin(UV.x * 7.0 - UV.y * 5.0);
	c += vec3(0.05, 0.045, 0.06) * cloud * smoothstep(0.2, 0.7, v);
	ALBEDO = c;
}"""
	sky_sh.shader = ssh
	box(Vector3(4000.0, 1400.0, 2.0), sky_sh, Vector3(0.0, 500.0, -1400.0))
	for sk in 16:
		var sx: float = -1300.0 + float(sk) * 170.0 + 60.0 * h01(sk + 300)
		var sh2: float = 300.0 + 420.0 * h01(sk + 310)
		box(Vector3(150.0, sh2, 60.0), mat(Color(0.05, 0.05, 0.08), 0.9), Vector3(sx, sh2 * 0.5, -1000.0))
		for lw in 8:
			if h01(sk * 20 + lw) > 0.55:
				box(Vector3(10.0, 12.0, 1.0), glow(Color(1.0, 0.78, 0.45).darkened(0.4 * h01(sk * 20 + lw + 7))), Vector3(sx - 50.0 + 100.0 * h01(sk * 20 + lw + 3), sh2 * (0.3 + 0.6 * h01(sk * 20 + lw + 5)), -969.0))
	# THE LAMP POST on the pavement's edge: a fluted post, a lantern head, its glass lit
	# (painted a deep green with a gilt band, so it never reads as one of the window's dark bars -- the user)
	var lamp_paint: StandardMaterial3D = mat(Color(0.14, 0.42, 0.30), 0.35, 0.5)
	lamp_paint.clearcoat_enabled = true
	cyl(5.0, 8.0, LAMP.y, lamp_paint, Vector3(LAMP.x, LAMP.y * 0.5, LAMP.z))
	cyl(12.0, 14.0, 12.0, lamp_paint, Vector3(LAMP.x, 6.0, LAMP.z))
	cyl(9.0, 9.0, 4.0, mat(Color(0.86, 0.68, 0.30), 0.3, 0.8), Vector3(LAMP.x, 30.0, LAMP.z))
	cyl(6.5, 6.5, 3.0, mat(Color(0.86, 0.68, 0.30), 0.3, 0.8), Vector3(LAMP.x, LAMP.y - 30.0, LAMP.z))
	cyl(6.0, 14.0, 26.0, glow(Color(1.0, 0.92, 0.70)), LAMP + Vector3(0.0, -6.0, 0.0))
	cyl(0.0, 18.0, 14.0, lamp_paint, LAMP + Vector3(0.0, 14.0, 0.0))

# a wall FACE with window openings cut in one band (the windows are set INTO the wall, and a solid box hid them)
func _wall_with_holes(m: Material, x0: float, x1: float, y0: float, y1: float, hy0: float, hy1: float, xs: Array, w: float) -> void:
	box(Vector3(x1 - x0, hy0 - y0, 20.0), m, Vector3((x0 + x1) * 0.5, (y0 + hy0) * 0.5, FACADE_Z - 10.0))
	box(Vector3(x1 - x0, y1 - hy1, 20.0), m, Vector3((x0 + x1) * 0.5, (hy1 + y1) * 0.5, FACADE_Z - 10.0))
	var edges: Array = [x0]
	for cx in xs:
		edges.append(float(cx) - w * 0.5)
		edges.append(float(cx) + w * 0.5)
	edges.append(x1)
	for k in range(0, edges.size(), 2):
		var a: float = edges[k]
		var b: float = edges[k + 1]
		if b > a:
			box(Vector3(b - a, hy1 - hy0, 20.0), m, Vector3((a + b) * 0.5, (hy0 + hy1) * 0.5, FACADE_Z - 10.0))

# A WINDOW IN 3-D (the lit one was a flat yellow box between two red ones -- the user: it "needs some lighting and
# texture improvement"): a reveal cut into the wall, a stone sill and lintel, a painted sash with its glazing bars,
# and behind the glass either the dark (a faint sky caught on it) or a LIT ROOM: a warm back wall and ceiling falling
# off from a lamp inside, curtains of heavy cloth hung in folds (a run of rounded pleats) drawn back to the sides,
# glowing where the light comes through them, a pelmet over them -- and the light spilling out onto the brick round
# it and the sill (a real light just outside the glass)
func _window3(c: Vector3, w: float, h: float, lit: bool, curtain: Color) -> void:
	var dressed: StandardMaterial3D = mat(Color(0.58, 0.55, 0.50), 0.75, 0.0, tex_speckle(64, Color(0.62, 0.58, 0.52), 0.10, 11), Vector3(1, 1, 1))
	var reveal: StandardMaterial3D = mat(Color(0.30, 0.20, 0.16), 0.9)
	var sash: StandardMaterial3D = mat(Color(0.86, 0.84, 0.78), 0.45)
	var depth: float = 20.0
	var z: float = c.z
	# the reveal: the opening's sides, head and floor, set back into the wall
	for e in [-1.0, 1.0]:
		box(Vector3(3.0, h, depth), reveal, Vector3(c.x + e * (w * 0.5 + 1.5), c.y, z - depth * 0.5 + 1.0))
	box(Vector3(w + 6.0, 3.0, depth), reveal, Vector3(c.x, c.y + h * 0.5 + 1.5, z - depth * 0.5 + 1.0))
	# the room behind (or the dark)
	var back_z: float = z - depth - 40.0
	if lit:
		var wall_sh: ShaderMaterial = ShaderMaterial.new()
		var sh: Shader = Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 hot = vec3(1.0, 0.82, 0.52);
uniform vec3 cool = vec3(0.55, 0.30, 0.14);
void fragment() {
	vec2 q = UV - vec2(0.62, 0.30);
	float k = exp(-dot(q, q) * 4.0);
	ALBEDO = mix(cool, hot, k);
}"""
		wall_sh.shader = sh
		box(Vector3(w + 30.0, h + 30.0, 2.0), wall_sh, Vector3(c.x, c.y, back_z))
		box(Vector3(w + 30.0, 2.0, 44.0), mat(Color(0.62, 0.42, 0.24), 0.8), Vector3(c.x, c.y + h * 0.5 + 6.0, back_z + 22.0))
		# a picture frame on the back wall, a lampshade glowing at the side
		box(Vector3(22.0, 16.0, 1.5), mat(Color(0.30, 0.18, 0.08), 0.5), Vector3(c.x - w * 0.18, c.y + h * 0.12, back_z + 1.5))
		box(Vector3(17.0, 11.0, 1.0), mat(Color(0.40, 0.48, 0.42), 0.6), Vector3(c.x - w * 0.18, c.y + h * 0.12, back_z + 2.4))
		cyl(7.0, 11.0, 12.0, glow(Color(1.0, 0.86, 0.58)), Vector3(c.x + w * 0.22, c.y - h * 0.18, back_z + 14.0), Vector3.ZERO, null, 20)
		# THE CURTAINS: pleats (half-round folds side by side), drawn back to each side, the light through them
		var cloth: StandardMaterial3D = mat(curtain, 0.85)
		cloth.emission_enabled = true
		cloth.emission = curtain.lightened(0.25)
		cloth.emission_energy_multiplier = 0.55
		for e2 in [-1.0, 1.0]:
			var pleats: int = 5
			var span: float = w * 0.26
			for k in pleats:
				var px: float = c.x + e2 * (w * 0.5 - span * (float(k) + 0.5) / float(pleats))
				var pl: MeshInstance3D = cyl(span / float(pleats) * 0.62, span / float(pleats) * 0.50, h - 6.0, cloth, Vector3(px, c.y - 2.0, z - depth + 4.0), Vector3.ZERO, null, 10)
				pl.scale = Vector3(1.0, 1.0, 0.55)
		# the pelmet over them
		box(Vector3(w + 2.0, 9.0, 6.0), mat(curtain.darkened(0.3), 0.7), Vector3(c.x, c.y + h * 0.5 - 5.0, z - depth + 6.0))
		light(Vector3(c.x, c.y, z + 14.0), Color(1.0, 0.76, 0.46), 0.7, 130.0)
	else:
		box(Vector3(w + 30.0, h + 30.0, 2.0), mat(Color(0.04, 0.04, 0.06), 1.0), Vector3(c.x, c.y, back_z))
	# the glass: a faint sheen of the sky on it
	var glass: StandardMaterial3D = mat(Color(0.45, 0.52, 0.68, 0.10 if lit else 0.30), 0.06, 0.5)
	box(Vector3(w, h, 0.6), glass, Vector3(c.x, c.y, z - depth + 12.0))
	# the sash: a frame and glazing bars (two by two), painted
	var fz: float = z - depth + 13.0
	for e3 in [-1.0, 1.0]:
		box(Vector3(5.0, h, 4.0), sash, Vector3(c.x + e3 * (w * 0.5 - 2.5), c.y, fz))
		box(Vector3(w, 5.0, 4.0), sash, Vector3(c.x, c.y + e3 * (h * 0.5 - 2.5), fz))
	box(Vector3(3.0, h, 3.0), sash, Vector3(c.x, c.y, fz + 0.5))
	box(Vector3(w, 6.0, 4.0), sash, Vector3(c.x, c.y, fz + 0.5))
	# the stone sill, lintel with a keystone
	box(Vector3(w + 22.0, 7.0, 16.0), dressed, Vector3(c.x, c.y - h * 0.5 - 4.0, z + 6.0))
	box(Vector3(w + 18.0, 10.0, 6.0), dressed, Vector3(c.x, c.y + h * 0.5 + 6.0, z + 3.0))
	box(Vector3(12.0, 14.0, 8.0), dressed, Vector3(c.x, c.y + h * 0.5 + 7.0, z + 4.0))

# --- the walkers and the lookout (2-D, on the 3-D pavement) ---------------------------------------------------------

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _clip == null:
		return
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	if _glass0 == null and _top != null:
		_glass0 = DrawnOnce.make(func(d: Control) -> void: _glass(d, 0.0))
		_glass1 = DrawnOnce.make(func(d: Control) -> void: _glass(d, 1.0))
		_top.add_child(_glass0)
		_top.add_child(_glass1)
	if _glass0 != null:
		if view != _glass_for:
			_glass_for = view
			_glass0.queue_redraw()
			_glass1.queue_redraw()
		_glass1.visible = fl > 0.002
		_glass1.modulate = Color(fl, fl, fl, fl)        # (premultiplied: all four)
	_clip.position = view.position
	_clip.size = view.size
	_layer.position = -view.position
	# WALKING, not carried (the user: "as if on conveyor belts"): each keeps its own easy pace along the pavement,
	# a little faster and slower by turns; every step lifts the umbrella a touch and sways it
	var depth: Array = []
	for k in _walkers.size():
		var a: Node2D = _walkers[k]
		var dirx: float = 1.0 if k % 2 == 0 else -1.0
		var span: float = 1100.0
		var pace: float = 30.0 + 10.0 * h01(k + 5)
		var walked: float = pace * t + pace * 0.9 * sin(t * 0.35 + float(k)) / 0.35 * 0.15
		var along: float = fmod(float(k) / float(WALKERS) * span + walked, span) - span * 0.5
		# both lanes out on the open pavement, in front of the hotel's awning (its edge at z -96): the far lane ran
		# UNDER it, at -110, and its umbrellas were drawn over the awning and the lobby's glazing bars (the user,
		# 2026-11-18, three times)
		var wp: Vector3 = Vector3(along * dirx, 0.0, -82.0 if k % 2 == 0 else -50.0)
		var sp: Vector2 = screen_of(wp)
		var ppu: float = screen_of(wp + Vector3(100.0, 0.0, 0.0)).distance_to(sp) / 100.0
		var sc: float = ppu * 0.95
		var stride: float = 20.0
		var ph: float = walked / stride * PI
		a.position = sp - Vector2(0.0, absf(sin(ph)) * 3.0 * sc)
		a.rotation = sin(ph) * 0.045
		a.set("step_phase", fmod(ph, TAU))
		a.set("step_dir", dirx)
		a.scale = Vector2(sc, sc)
		a.set("spin", h01(k + 9) * TAU + sin(t * 0.4 + float(k)) * 0.35)
		# the farther lane below the nearer, and each walker its own band within its lane (10 apart, clear of its
		# parts' own +3 / -4)
		a.z_index = 0
		depth.append([wp.z + float(k) * 0.01, a])     # (the index breaks a tie in a lane: no swapping)
		a.call("set_light", Color(0.62, 0.60, 0.66).lerp(Color(1.6, 1.6, 1.8), fl))
		a.queue_redraw()
	# the lookout in the doorway: seen ONLY in the flash (between flashes, faint, it read as a phantom umbrella)
	var lp: Vector2 = screen_of(DOOR + Vector3(0.0, 0.0, 14.0))
	var lppu: float = screen_of(DOOR + Vector3(100.0, 0.0, 14.0)).distance_to(lp) / 100.0
	_lookout.position = lp
	_lookout.z_index = 0
	depth.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for di in depth.size():
		var w: Node2D = depth[di][1]
		if w.get_index() != di + 1:
			_layer.move_child(w, di + 1)
	if _lookout.get_index() != 0:
		_layer.move_child(_lookout, 0)
	_lookout.scale = Vector2.ONE * lppu * 0.9
	_lookout.modulate.a = clampf(fl * 1.6, 0.0, 1.0)
	_lookout.call("set_light", Color(0.5, 0.5, 0.55).lerp(Color(1.7, 1.7, 1.9), fl))
	_lookout.queue_redraw()

# the lamp and the sign mirrored in the wet road, broken by the rain; and the rain falling outside
func _paint(_full: Vector2, _bottom: float) -> void:
	if bake_mode:
		return
	cv.draw_rect(Rect2(Vector2.ZERO, _full), Color(0.03, 0.03, 0.05))

func _street_fx(view: Rect2, fl: float) -> void:
	if _cam3 == null:
		return
	var breathe: float = 0.85 + 0.15 * sin(t * 0.9)
	for k in 7:
		var z: float = CURB_Z + 20.0 + float(k) * 26.0
		var wob: float = sin(t * 3.0 + float(k) * 1.7) * 4.0
		var lp: Vector2 = screen_of(Vector3(LAMP.x, 0.0, z)) + Vector2(wob, 0.0)
		ellipse(lp, 12.0, 3.0, Color(1.0, 0.85, 0.55, 0.16 - 0.018 * float(k)))
		var sp: Vector2 = screen_of(Vector3(SIGN.x, 0.0, z + 8.0)) - Vector2(wob, 0.0)
		ellipse(sp, 30.0, 2.5, Color(1.0, 0.30, 0.45, (0.12 - 0.014 * float(k)) * breathe))
	# THE RAIN OUTSIDE, falling past between the window and the street: fine streaks, the near ones longer, faster and
	# fainter (out of focus), under the beads on the glass and the frame
	for k2 in 90:
		var near: float = h01(k2 * 3 + 2)
		var rx2: float = view.position.x + h01(k2 * 3) * view.size.x
		var ry2: float = view.position.y + fmod(h01(k2 * 3 + 1) * view.size.y + t * (380.0 + 420.0 * near), view.size.y)
		var ln: float = 8.0 + 18.0 * near
		cv.draw_line(Vector2(rx2, ry2), Vector2(rx2 - ln * 0.22, ry2 + ln), Color(0.70, 0.76, 0.90, (0.20 - 0.10 * near) + 0.3 * fl), 0.8 + 0.6 * near)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	_street_fx(view, fl)
	_beads(view, fl, true)          # the beads that run (live); the still ones, the frame and the name are _glass

# the still part of the glass at a flash `fl`: the beads that do not run, the flash's whitening of the street, the room
# and the window frame, and the name -- drawn once for the dark and once for the flash (_glass0, _glass1)
func _glass(d: Control, fl: float) -> void:
	if bake_mode:
		return
	cv = d
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var full: Vector2 = g["full"]
	_beads(view, fl, false)
	# the flash: the street whitened under it, and on the glass itself
	if fl > 0.02:
		cv.draw_rect(view, Color(0.80, 0.86, 1.0, 0.30 * fl))
	_frame_fx(full, view, fl)
	title("Pinpoint", "Catch the courier and the lookout in a flash of lightning", Color(0.86, 0.92, 1.0).lerp(Color.WHITE, fl),
		Color(0.02, 0.03, 0.06), Color(0.5, 0.6, 1.0, 0.15 + 0.4 * fl))

# RAIN ON THE GLASS (2026-11-18; the user: the drops "keep falling inside our apartment" -- they fell down the view
# like snow): BEADS clinging to the pane, each a little lens -- darker rim at its foot, a bright point of light at
# its top -- most of them still; now and then one grows too heavy and RUNS, in short jerks, leaving a wet trail.
# `running`: only the ones that run (live), or only the still ones (drawn once)
func _beads(view: Rect2, fl: float, running: bool) -> void:
	for d in _drops:
		var r: float = 1.4 + float(d[3]) * 26.0
		var x: float = view.position.x + float(d[0]) * view.size.x
		var y0: float = view.position.y + float(d[1]) * view.size.y
		var y: float = y0
		var runs: bool = float(d[2]) > 4.9
		if runs != running:
			continue
		if runs:
			var cyc: float = 9.0 + float(d[2]) * 2.0
			var u: float = fmod(t + float(d[0]) * 30.0, cyc) / cyc
			var dist: float = 0.0
			for j in 6:
				dist += smoothstep(float(j) / 6.0, float(j) / 6.0 + 0.05, u) * (18.0 + 10.0 * h01(int(d[2] * 100.0) + j))
			y = y0 + dist
			if y > view.end.y - r:
				continue
			cv.draw_line(Vector2(x, y0), Vector2(x + sin(y * 0.05) * 1.5, y - r), Color(0.75, 0.82, 0.95, 0.07 + 0.15 * fl), r * 0.7)
		cv.draw_circle(Vector2(x, y), r, Color(0.20, 0.24, 0.32, 0.18))
		cv.draw_circle(Vector2(x, y - r * 0.15), r * 0.82, Color(0.62, 0.70, 0.86, 0.14 + 0.25 * fl))
		cv.draw_arc(Vector2(x, y), r * 0.92, PI * 0.15, PI * 0.85, 8, Color(0.02, 0.02, 0.04, 0.35), maxf(0.8, r * 0.25), true)
		cv.draw_circle(Vector2(x - r * 0.3, y - r * 0.35), maxf(0.6, r * 0.22), Color(1, 1, 1, 0.55 + 0.4 * fl))

# THE ROOM AND THE WINDOW FRAME, in the dark (they were flat black bands): the wall's plaster round the opening, the
# opening's REVEAL showing the wall's thickness (its faces lit faintly by the street, brighter in the flash), and the
# frame and its cross bars of old painted wood -- grain, a bevel catching the light on the upper and outer edges, a
# shadow under -- and at the foot a deep SILL coming toward us
func _wood(r: Rect2, vertical: bool, fl: float, seed_i: int) -> void:
	# OLD CREAM PAINT on the wood, dimmed by the night (dark, it read as the same thing as the dark lamp post -- the user)
	var base: Color = Color(0.50, 0.47, 0.41).lerp(Color(0.80, 0.82, 0.90), 0.35 * fl)
	cv.draw_rect(r, base)
	var n: int = int((r.size.x if vertical else r.size.y) / 2.5)
	for k in n:
		var f: float = (float(k) + 0.5) / float(n)
		var c: Color = base.lerp(Color(0.0, 0.0, 0.0), 0.12 * h01(seed_i * 37 + k)).lerp(Color(0.36, 0.28, 0.20), (0.30 if h01(seed_i * 41 + k * 3) > 0.93 else 0.0))
		if vertical:
			var x: float = r.position.x + f * r.size.x
			cv.draw_line(Vector2(x + sin(float(k)) * 0.6, r.position.y), Vector2(x, r.end.y), c, 1.0)
		else:
			var y: float = r.position.y + f * r.size.y
			cv.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y + sin(float(k)) * 0.6), c, 1.0)
	# the bevels
	var hi: Color = Color(0.72, 0.68, 0.60, 0.65).lerp(Color(0.95, 0.97, 1.0, 0.85), fl)
	var lo: Color = Color(0.0, 0.0, 0.0, 0.55)
	cv.draw_line(r.position, Vector2(r.end.x, r.position.y), hi, 1.5)
	cv.draw_line(r.position, Vector2(r.position.x, r.end.y), hi.darkened(0.2), 1.5)
	cv.draw_line(Vector2(r.position.x, r.end.y), r.end, lo, 2.0)
	cv.draw_line(Vector2(r.end.x, r.position.y), r.end, lo, 2.0)

func _frame_fx(full: Vector2, view: Rect2, fl: float) -> void:
	var plaster: Color = Color(0.045, 0.042, 0.050).lerp(Color(0.30, 0.32, 0.40), 0.35 * fl)
	var fw: float = 16.0
	var outer: Rect2 = view.abs().grow(fw)        # (abs: on the first frames, before the layout settles, it can be negative)
	var rv: float = 22.0
	var opening: Rect2 = outer.grow(rv)
	# the wall round it, a faint mottle
	cv.draw_rect(Rect2(0.0, 0.0, full.x, opening.position.y), plaster)
	cv.draw_rect(Rect2(0.0, opening.end.y, full.x, full.y - opening.end.y), plaster)
	cv.draw_rect(Rect2(0.0, opening.position.y, opening.position.x, opening.size.y), plaster)
	cv.draw_rect(Rect2(opening.end.x, opening.position.y, full.x - opening.end.x, opening.size.y), plaster)
	for k in 40:
		var mp: Vector2 = Vector2(h01(k * 3 + 700) * full.x, h01(k * 3 + 701) * full.y)
		if opening.has_point(mp):
			continue
		cv.draw_circle(mp, 20.0 + 40.0 * h01(k + 702), Color(0.0, 0.0, 0.0, 0.05))
	# THE REVEAL: four trapezoids from the wall's face in to the frame, the upper and the sides lit by the street
	var street: Color = Color(0.10, 0.10, 0.13).lerp(Color(0.55, 0.60, 0.75), fl)
	var o: Rect2 = opening
	var i: Rect2 = outer
	cv.draw_colored_polygon(PackedVector2Array([o.position, Vector2(o.end.x, o.position.y), Vector2(i.end.x, i.position.y), i.position]), street.darkened(0.45))
	cv.draw_colored_polygon(PackedVector2Array([o.position, i.position, Vector2(i.position.x, i.end.y), Vector2(o.position.x, o.end.y)]), street.darkened(0.25))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(o.end.x, o.position.y), Vector2(o.end.x, o.end.y), i.end, Vector2(i.end.x, i.position.y)]), street.darkened(0.30))
	# the sill: the reveal's floor, deep, catching the most light, a lip at its front
	var sill: Color = Color(0.16, 0.12, 0.10).lerp(Color(0.62, 0.66, 0.80), fl)
	cv.draw_polygon(PackedVector2Array([Vector2(i.position.x, i.end.y), i.end, Vector2(o.end.x + 10.0, o.end.y + 8.0), Vector2(o.position.x - 10.0, o.end.y + 8.0)]),
		PackedColorArray([sill.lightened(0.15), sill.lightened(0.15), sill.darkened(0.2), sill.darkened(0.2)]))
	cv.draw_rect(Rect2(o.position.x - 10.0, o.end.y + 8.0, o.size.x + 20.0, 7.0), sill.darkened(0.45))
	# the frame round the glass, and the cross bars, wooden
	_wood(Rect2(i.position.x, i.position.y, i.size.x, fw), false, fl, 1)
	_wood(Rect2(i.position.x, view.end.y, i.size.x, fw), false, fl, 2)
	_wood(Rect2(i.position.x, view.position.y, fw, view.size.y), true, fl, 3)
	_wood(Rect2(view.end.x, view.position.y, fw, view.size.y), true, fl, 4)
	_wood(Rect2(view.position.x, view.position.y + view.size.y * 0.42 - 5.0, view.size.x, 11.0), false, fl, 5)
	_wood(Rect2(view.get_center().x - 5.5, view.position.y, 11.0, view.size.y), true, fl, 6)
	# a soft shadow the bars cast on the glass's lower edge (inside), and a faint sheen across the panes
	cv.draw_colored_polygon(PackedVector2Array([view.position + Vector2(view.size.x * 0.55, 0.0), view.position + Vector2(view.size.x * 0.75, 0.0), view.position + Vector2(view.size.x * 0.35, view.size.y), view.position + Vector2(view.size.x * 0.15, view.size.y)]), Color(0.75, 0.82, 1.0, 0.025))
