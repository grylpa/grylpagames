extends "res://scripts/menu_poster3d.gd"

# LIGHTS OUT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A COAL MINE
# GALLERY (the game's own coal mine look). A tunnel through dark coal-seamed rock, timber sets every few paces, rails
# on sleepers running away into it, a cart of coal at the near end, lanterns hung on the posts -- and down the
# gallery a side opening with a TNT crate at its mouth (the obstacle) and, far off, a green lamp by the way out (the
# goal). Then, as in the game, THE LIGHTS GO OUT: lantern by lantern from the far end toward you, the dark closing
# in, until only a faint glow is left -- a moment -- and they come on again from the near end, flickering as they
# catch. The gallery is the baked picture (`menu_mine.webp`, lit by its lanterns); the dark is a veil over it with a
# hole round each lit lantern (`add_darkness`), and the flames are drawn live. Made up, never the board.

const SET_EVERY: float = 170.0           # timber sets along the gallery
const SETS: int = 9
const HALF_W: float = 125.0
const HEIGHT: float = 215.0
const CYCLE: float = 9.0
const TNT_Z: float = -560.0
const GOAL_Z: float = -1350.0

var _lanterns: Array = []                # Vector3 per lantern, near to far

func _baked_path() -> String:
	return "res://lightsout/art/menu_mine.webp"

func _eye() -> Vector3:
	return Vector3(-20.0, 140.0, 430.0)

func _aim() -> Vector3:
	return Vector3(10.0, 105.0, -400.0)

func _fov() -> float:
	return 62.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_color = Color(0.40, 0.36, 0.34)
	env.ambient_light_energy = 0.10

func _setup() -> void:
	for k in SETS:
		var z: float = 160.0 - float(k) * SET_EVERY
		var side: float = -1.0 if k % 2 == 0 else 1.0
		_lanterns.append(Vector3(side * (HALF_W - 22.0), 150.0, z + 14.0))
	super._setup()
	add_darkness()

func _build_lights() -> void:
	# each lantern lights its stretch of the gallery, warm; the goal's green lamp far off
	for p in _lanterns:
		light((p as Vector3) + Vector3(0.0, -6.0, 6.0), Color(1.0, 0.70, 0.38), 1.7, 260.0, false)
	light(Vector3(70.0, 120.0, GOAL_Z + 30.0), Color(0.45, 1.0, 0.55), 2.0, 240.0)

# --- the gallery: baked ---------------------------------------------------------------------------------------------

func _rock(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = h01(x * 13 + y * 7) * 0.5 + h01((x / 4) * 31 + (y / 4) * 17) * 0.5
			var c: Color = Color(0.11, 0.11, 0.12).lerp(Color(0.25, 0.24, 0.24), v)
			# coal seams: dark bands that wander across the rock
			var seam: float = sin(float(y) * 0.07 + sin(float(x) * 0.031) * 3.0 + h01((x / 16) * 7 + (y / 16)) * 1.5)
			if seam > 0.93 and h01((x / 8) * 13 + (y / 8) * 5) > 0.3:
				c = Color(0.05, 0.05, 0.06).lerp(Color(0.16, 0.16, 0.18), h01(x + y * 3))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	var rock: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _rock(256), Vector3(10, 2, 1))
	var floor_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, tex_speckle(128, Color(0.20, 0.17, 0.14), 0.12, 4), Vector3(4, 20, 1))
	var timber: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_wood(128, Color(0.36, 0.24, 0.13), 6), Vector3(1, 3, 1))
	var steel: StandardMaterial3D = mat(Color(0.45, 0.42, 0.40), 0.4, 0.7)
	var length: float = 2400.0
	var near_end: float = 640.0          # past the camera: we stand INSIDE the gallery
	# the walls, the roof and the floor of the gallery, and a rough rock face at its far end
	# in pieces a timber set long: the renderer lights an object with at most eight lights, and the gallery has more
	var pieces: int = int(ceil(length / SET_EVERY))
	for pc in pieces:
		var pz: float = near_end - (float(pc) + 0.5) * SET_EVERY
		box(Vector3(2.0 * HALF_W + 40.0, 10.0, SET_EVERY + 0.5), floor_m, Vector3(0.0, -5.0, pz))
		box(Vector3(2.0 * HALF_W + 40.0, 20.0, SET_EVERY + 0.5), rock, Vector3(0.0, HEIGHT + 10.0, pz))
		for side in [-1.0, 1.0]:
			box(Vector3(20.0, HEIGHT + 20.0, SET_EVERY + 0.5), rock, Vector3(side * (HALF_W + 10.0), HEIGHT * 0.5, pz))
	box(Vector3(2.0 * HALF_W + 40.0, HEIGHT + 20.0, 20.0), rock, Vector3(0.0, HEIGHT * 0.5, near_end - length))
	# THE TIMBER SETS: two posts and a cap, wedged, every SET_EVERY
	for k4 in SETS + 6:
		var z4: float = 160.0 + 3.0 * SET_EVERY - float(k4) * SET_EVERY
		for side4 in [-1.0, 1.0]:
			box(Vector3(18.0, HEIGHT - 6.0, 18.0), timber, Vector3(side4 * (HALF_W - 12.0), (HEIGHT - 6.0) * 0.5, z4), Vector3(0.0, 0.0, side4 * -3.0))
		box(Vector3(2.0 * HALF_W, 20.0, 20.0), timber, Vector3(0.0, HEIGHT - 12.0, z4))
		for w in 3:
			box(Vector3(14.0, 6.0, 26.0), timber, Vector3(-60.0 + float(w) * 60.0, HEIGHT - 1.0, z4))
	# THE RAILS on their sleepers, running away down the gallery
	for k5 in 72:
		box(Vector3(120.0, 6.0, 16.0), timber, Vector3(0.0, 3.0, 620.0 - float(k5) * 32.0))
	for rx in [-38.0, 38.0]:
		for pc2 in pieces:
			box(Vector3(5.0, 7.0, SET_EVERY + 0.5), steel, Vector3(rx, 9.0, near_end - (float(pc2) + 0.5) * SET_EVERY))
	# the lanterns: a hook on the post, a wire cage, the glass and its flame
	for p in _lanterns:
		var lp: Vector3 = p
		var into: float = signf(lp.x)
		box(Vector3(18.0, 3.0, 3.0), steel, lp + Vector3(into * 8.0, 20.0, 0.0))
		cyl(7.0, 7.0, 2.0, steel, lp + Vector3(0.0, 13.0, 0.0))
		cyl(6.0, 6.0, 18.0, mat(Color(1.0, 0.85, 0.55, 0.55), 0.1), lp + Vector3(0.0, 2.0, 0.0))
		cyl(7.5, 7.5, 3.0, steel, lp + Vector3(0.0, -9.0, 0.0))
		sphere(3.5, glow(Color(1.0, 0.82, 0.45)), lp + Vector3(0.0, 1.0, 0.0))
	# A CART of coal at the near end, on the rails
	var cart: Vector3 = Vector3(0.0, 0.0, -300.0)
	box(Vector3(100.0, 56.0, 120.0), mat(Color(0.30, 0.22, 0.16), 0.6, 0.5), cart + Vector3(0.0, 46.0, 0.0))
	box(Vector3(104.0, 6.0, 124.0), steel, cart + Vector3(0.0, 76.0, 0.0))
	for k6 in 22:
		sphere(10.0 + 6.0 * h01(k6 + 80), mat(Color(0.06, 0.06, 0.07), 0.3, 0.2), cart + Vector3((h01(k6 + 81) - 0.5) * 80.0, 78.0 + 6.0 * h01(k6 + 82), (h01(k6 + 83) - 0.5) * 100.0))
	for wx in [-38.0, 38.0]:
		for wz in [-40.0, 40.0]:
			cyl(13.0, 13.0, 6.0, steel, cart + Vector3(wx, 13.0, wz), Vector3(0.0, 0.0, 90.0))
	# THE SIDE OPENING on the right, dark, and the TNT crate at its mouth (the obstacle)
	box(Vector3(30.0, 150.0, 120.0), mat(Color(0.0, 0.0, 0.0), 1.0), Vector3(HALF_W + 2.0, 75.0, TNT_Z))
	var tnt: Vector3 = Vector3(HALF_W - 40.0, 0.0, TNT_Z + 10.0)
	box(Vector3(46.0, 34.0, 38.0), mat(Color(0.62, 0.20, 0.12), 0.7), tnt + Vector3(0.0, 17.0, 0.0), Vector3(0.0, 20.0, 0.0))
	label("TNT", 14.0, Color(1.0, 0.90, 0.60), tnt + Vector3(-12.0, 20.0, 15.0), Vector3(0.0, -40.0, 0.0))
	# far down, the way out: a green lamp on a post and a sign
	cyl(3.0, 3.0, 120.0, steel, Vector3(70.0, 60.0, GOAL_Z))
	sphere(8.0, glow(Color(0.45, 1.0, 0.55)), Vector3(70.0, 124.0, GOAL_Z))
	box(Vector3(60.0, 26.0, 3.0), mat(Color(0.12, 0.40, 0.18), 0.6), Vector3(70.0, 96.0, GOAL_Z + 4.0))

# --- live: the lanterns going out and coming back ------------------------------------------------------------------

# how lit lantern k is now (0 out .. 1 lit): out one by one from the far end, back from the near end
func _lit(k: int) -> float:
	var u: float = fmod(t, CYCLE)
	var n: float = float(_lanterns.size())
	var far_first: float = n - 1.0 - float(k)               # 0 for the farthest
	var off_at: float = 3.0 + far_first * 0.32
	var on_at: float = 6.8 + float(k) * 0.22
	var lit: float = 1.0 - smoothstep(off_at, off_at + 0.25, u) + smoothstep(on_at, on_at + 0.20, u)
	lit = clampf(lit, 0.0, 1.0)
	# catching: a flicker as it comes on
	if u > on_at and u < on_at + 0.6:
		lit *= 0.65 + 0.35 * sin((u - on_at) * 60.0 + float(k))
	return lit * (0.90 + 0.10 * sin(t * 13.0 + float(k) * 3.1) * sin(t * 7.3 + float(k)))

func _animate(_delta: float) -> void:
	if _dark == null:
		return
	var lamps: Array = []
	var any: float = 0.0
	for k in _lanterns.size():
		var lt: float = _lit(k)
		any = maxf(any, lt)
		var sp: Vector2 = screen_of(_lanterns[k])
		var near: float = screen_of((_lanterns[k] as Vector3) + Vector3(0.0, 100.0, 0.0)).distance_to(sp)
		lamps.append(Vector4(sp.x, sp.y, near * 1.5, 1.1 * lt))
	# the goal's lamp stays: the one thing left in the dark, faint
	var gp: Vector2 = screen_of(Vector3(70.0, 124.0, GOAL_Z))
	lamps.append(Vector4(gp.x, gp.y, 50.0, 0.7))
	var u: float = fmod(t, CYCLE)
	var dark: float = lerpf(0.55, 0.96, smoothstep(3.0, 5.6, u) * (1.0 - smoothstep(6.6, 8.6, u)))
	set_darkness(dark, Color(0.0, 0.0, 0.01), lamps)

# the flames over the dark: a small bright core and a soft halo, for each lit lantern
func _paint_top(_full: Vector2, _bottom: float) -> void:
	if _dark != null:
		for k in _lanterns.size():
			var lt: float = _lit(k)
			if lt <= 0.02:
				continue
			var sp: Vector2 = screen_of(_lanterns[k])
			var sc: float = screen_of((_lanterns[k] as Vector3) + Vector3(0.0, 100.0, 0.0)).distance_to(sp) / 100.0
			for j in 6:
				cv.draw_circle(sp, (26.0 - float(j) * 4.0) * sc, Color(1.0, 0.75, 0.40, 0.07 * lt))
			cv.draw_circle(sp, 3.2 * sc, Color(1.0, 0.95, 0.75, lt))
	title("Lights Out", "Remember your path, goal, and obstacles", Color(1.0, 0.82, 0.50), Color(0.10, 0.06, 0.02),
		Color(1.0, 0.7, 0.35, 0.25))
