extends "res://scripts/menu_poster3d.gd"

# PINPOINT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): a STAKEOUT, seen
# from a high window at night -- the street below is REAL 3-D now (it was a drawn picture): an old brick building with a
# deep doorway and two upper windows (one lit, curtained), the HOTEL beside it -- its lobby lit behind tall glass (a warm
# back wall, a chandelier, the desk, a palm), a striped awning, the neon HOTEL sign -- stone pavement, the kerb, the wet
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
const KERB_Z: float = -30.0
const DOOR: Vector3 = Vector3(-250.0, 0.0, -170.0)
const LAMP: Vector3 = Vector3(290.0, 230.0, -55.0)
const SIGN: Vector3 = Vector3(165.0, 215.0, -150.0)

var _walkers: Array = []
var _lookout: Node2D = null
var _layer: Node2D = null
var _clip: Control = null
var _drops: Array = []

func _baked_path() -> String:
	return "res://didi/art/menu_street.webp" if mobile else "res://didi/art/menu_street_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 560.0, 520.0) if mobile else Vector3(0.0, 470.0, 640.0)

func _aim() -> Vector3:
	return Vector3(0.0, 60.0, -90.0) if mobile else Vector3(0.0, 80.0, -100.0)

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
	for _i in 46:
		_drops.append([rng.randf(), rng.randf(), rng.randf_range(2.5, 6.0), rng.randf_range(0.03, 0.12)])
	if _top != null:
		move_child(_top, get_child_count() - 1)

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
	var view: Rect2 = Rect2(34.0, (230.0 if mobile else 150.0), full.x - 68.0, bottom - (230.0 if mobile else 150.0) - 30.0)
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
	# THE GROUND: pavement slabs, the kerb, the wet road (dark and glossy)
	box(Vector3(1600.0, 4.0, FACADE_Z * -1.0 + KERB_Z), mat(Color.WHITE, 0.45, 0.0, tex_speckle(128, Color(0.30, 0.30, 0.33), 0.06, 5, 4, Color(0.18, 0.18, 0.20)), Vector3(14, 3, 1)), Vector3(0.0, 2.0, (FACADE_Z + KERB_Z) * 0.5))
	box(Vector3(1600.0, 8.0, 10.0), dressed, Vector3(0.0, 2.0, KERB_Z + 5.0))
	box(Vector3(1600.0, 2.0, 900.0), mat(Color(0.07, 0.08, 0.10), 0.15, 0.25), Vector3(0.0, -1.0, KERB_Z + 455.0))
	for k in 12:
		box(Vector3(36.0, 0.4, 6.0), mat(Color(0.60, 0.58, 0.50), 0.5), Vector3(-560.0 + float(k) * 100.0, 0.4, 180.0))
	# THE OLD BUILDING at the left: brick, a deep doorway with a stone surround and an open door, two upper windows
	box(Vector3(400.0, 330.0, 20.0), brick, Vector3(-220.0, 165.0, FACADE_Z - 10.0))
	box(Vector3(84.0, 160.0, 4.0), dark, Vector3(DOOR.x, 80.0, FACADE_Z - 40.0))
	box(Vector3(70.0, 152.0, 22.0), dark, Vector3(DOOR.x, 76.0, FACADE_Z - 10.0))
	for jx in [-1.0, 1.0]:
		box(Vector3(12.0, 166.0, 26.0), dressed, Vector3(DOOR.x + jx * 41.0, 83.0, FACADE_Z - 8.0))
	box(Vector3(100.0, 14.0, 28.0), dressed, Vector3(DOOR.x, 172.0, FACADE_Z - 7.0))
	box(Vector3(96.0, 8.0, 24.0), dressed, Vector3(DOOR.x, 4.0, FACADE_Z + 8.0))
	box(Vector3(28.0, 140.0, 4.0), mat(Color(0.26, 0.16, 0.10), 0.7), Vector3(DOOR.x + 30.0, 72.0, FACADE_Z - 28.0), Vector3(0.0, -70.0, 0.0))
	for w in 2:
		var wx: float = -330.0 + float(w) * 150.0
		box(Vector3(70.0, 90.0, 4.0), glow(Color(1.0, 0.80, 0.48)) if w == 1 else mat(Color(0.10, 0.12, 0.18), 0.1, 0.4), Vector3(wx, 250.0, FACADE_Z + 1.0))
		if w == 1:
			for cs in [-1.0, 1.0]:
				box(Vector3(20.0, 90.0, 1.0), glow(Color(0.55, 0.16, 0.14)), Vector3(wx + cs * 25.0, 250.0, FACADE_Z + 3.4))
		box(Vector3(4.0, 90.0, 3.0), iron, Vector3(wx, 250.0, FACADE_Z + 4.0))
		box(Vector3(70.0, 4.0, 3.0), iron, Vector3(wx, 250.0, FACADE_Z + 4.0))
		box(Vector3(86.0, 8.0, 14.0), dressed, Vector3(wx, 201.0, FACADE_Z + 6.0))
		box(Vector3(84.0, 8.0, 8.0), dressed, Vector3(wx, 299.0, FACADE_Z + 3.0))
	cyl(4.0, 4.0, 330.0, iron, Vector3(-28.0, 165.0, FACADE_Z + 6.0))
	# THE HOTEL: a stone front, its LOBBY behind tall glass (a warm back wall, a chandelier, the desk, a palm), the
	# awning, the sign's board, the windows above
	box(Vector3(420.0, 340.0, 20.0), stone, Vector3(190.0, 170.0, FACADE_Z - 10.0))
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
	# the glass: mullions and a pair of doors, faintly reflecting
	var glass_m: StandardMaterial3D = mat(Color(0.55, 0.60, 0.75, 0.14), 0.05, 0.3)
	box(Vector3(290.0, 160.0, 1.0), glass_m, Vector3(lobby_x, 80.0, FACADE_Z + 0.5))
	for mx in [-145.0, -72.0, -22.0, 22.0, 72.0, 145.0]:
		box(Vector3(5.0, 160.0, 5.0), iron, Vector3(lobby_x + mx, 80.0, FACADE_Z + 1.0))
	box(Vector3(290.0, 6.0, 6.0), iron, Vector3(lobby_x, 120.0, FACADE_Z + 1.0))
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
		var wx2: float = 50.0 + float(w2) * 120.0
		box(Vector3(70.0, 70.0, 4.0), glow(Color(1.0, 0.80, 0.48)) if w2 == 2 else mat(Color(0.10, 0.12, 0.18), 0.1, 0.4), Vector3(wx2, 290.0, FACADE_Z + 1.0))
		box(Vector3(84.0, 8.0, 12.0), dressed, Vector3(wx2, 251.0, FACADE_Z + 5.0))
	# THE LAMP POST on the pavement's edge: a fluted post, a lantern head, its glass lit
	cyl(5.0, 8.0, LAMP.y, iron, Vector3(LAMP.x, LAMP.y * 0.5, LAMP.z))
	cyl(12.0, 14.0, 12.0, iron, Vector3(LAMP.x, 6.0, LAMP.z))
	cyl(6.0, 14.0, 26.0, glow(Color(1.0, 0.92, 0.70)), LAMP + Vector3(0.0, -6.0, 0.0))
	cyl(0.0, 18.0, 14.0, iron, LAMP + Vector3(0.0, 14.0, 0.0))

# --- the walkers and the lookout (2-D, on the 3-D pavement) ---------------------------------------------------------

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _clip == null:
		return
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	_clip.position = view.position
	_clip.size = view.size
	_layer.position = -view.position
	# WALKING, not carried (the user: "as if on conveyor belts"): each keeps its own easy pace along the pavement,
	# a little faster and slower by turns; every step lifts the umbrella a touch and sways it
	for k in _walkers.size():
		var a: Node2D = _walkers[k]
		var dirx: float = 1.0 if k % 2 == 0 else -1.0
		var span: float = 1100.0
		var pace: float = 30.0 + 10.0 * h01(k + 5)
		var walked: float = pace * t + pace * 0.9 * sin(t * 0.35 + float(k)) / 0.35 * 0.15
		var along: float = fmod(float(k) / float(WALKERS) * span + walked, span) - span * 0.5
		var wp: Vector3 = Vector3(along * dirx, 0.0, -110.0 if k % 2 == 0 else -65.0)
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
		a.call("set_light", Color(0.62, 0.60, 0.66).lerp(Color(1.6, 1.6, 1.8), fl))
		a.queue_redraw()
	# the lookout in the doorway: seen ONLY in the flash (between flashes, faint, it read as a phantom umbrella)
	var lp: Vector2 = screen_of(DOOR + Vector3(0.0, 0.0, 14.0))
	var lppu: float = screen_of(DOOR + Vector3(100.0, 0.0, 14.0)).distance_to(lp) / 100.0
	_lookout.position = lp
	_lookout.scale = Vector2.ONE * lppu * 0.9
	_lookout.modulate.a = clampf(fl * 1.6, 0.0, 1.0)
	_lookout.call("set_light", Color(0.5, 0.5, 0.55).lerp(Color(1.7, 1.7, 1.9), fl))
	_lookout.queue_redraw()

# the lamp and the sign mirrored in the wet road, broken by the rain; and the rain falling outside
func _paint(full: Vector2, _bottom: float) -> void:
	if bake_mode:
		return
	cv.draw_rect(Rect2(Vector2.ZERO, full), Color(0.03, 0.03, 0.05))

func _street_fx(view: Rect2, fl: float) -> void:
	if _cam3 == null:
		return
	var breathe: float = 0.85 + 0.15 * sin(t * 0.9)
	for k in 7:
		var z: float = KERB_Z + 20.0 + float(k) * 26.0
		var wob: float = sin(t * 3.0 + float(k) * 1.7) * 4.0
		var lp: Vector2 = screen_of(Vector3(LAMP.x, 0.0, z)) + Vector2(wob, 0.0)
		ellipse(lp, 12.0, 3.0, Color(1.0, 0.85, 0.55, 0.16 - 0.018 * float(k)))
		var sp: Vector2 = screen_of(Vector3(SIGN.x, 0.0, z + 8.0)) - Vector2(wob, 0.0)
		ellipse(sp, 30.0, 2.5, Color(1.0, 0.30, 0.45, (0.12 - 0.014 * float(k)) * breathe))
	for k2 in 70:
		var rx2: float = view.position.x + h01(k2 * 3) * view.size.x
		var ry2: float = view.position.y + fmod(h01(k2 * 3 + 1) * view.size.y + t * 520.0 * (0.8 + 0.4 * h01(k2)), view.size.y)
		cv.draw_line(Vector2(rx2, ry2), Vector2(rx2 - 4.0, ry2 + 14.0), Color(0.70, 0.76, 0.90, 0.25 + 0.3 * fl), 1.0)

func _paint_top(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	_street_fx(view, fl)
	# RAIN ON THE GLASS: drops sliding down, each leaving a faint trail
	for d in _drops:
		var x: float = view.position.x + float(d[0]) * view.size.x
		var y: float = view.position.y + fmod(float(d[1]) * view.size.y + t * float(d[2]) * 12.0, view.size.y)
		var r: float = 2.0 + float(d[3]) * 30.0
		cv.draw_line(Vector2(x, y - r * 6.0), Vector2(x, y), Color(0.75, 0.82, 0.95, 0.10 + 0.25 * fl), r * 0.5)
		cv.draw_circle(Vector2(x, y), r, Color(0.70, 0.78, 0.92, 0.22 + 0.3 * fl))
		cv.draw_circle(Vector2(x - r * 0.3, y - r * 0.3), r * 0.35, Color(1, 1, 1, 0.35))
	# the flash: the street whitened under it, and on the glass itself
	if fl > 0.02:
		cv.draw_rect(view, Color(0.80, 0.86, 1.0, 0.30 * fl))
	# THE ROOM round the window, near black (the 3-D street runs on behind it)
	var room: Color = Color(0.03, 0.03, 0.05)
	cv.draw_rect(Rect2(0.0, 0.0, full.x, view.position.y), room)
	cv.draw_rect(Rect2(0.0, view.end.y, full.x, full.y - view.end.y), room)
	# THE WINDOW FRAME round the view, dark wood, a cross bar
	var fc: Color = Color(0.06, 0.05, 0.05)
	cv.draw_rect(Rect2(0.0, view.position.y - 18.0, full.x, 18.0), fc)
	cv.draw_rect(Rect2(0.0, view.end.y, full.x, 26.0), fc)
	cv.draw_rect(Rect2(0.0, view.position.y, view.position.x, view.size.y), fc)
	cv.draw_rect(Rect2(view.end.x, view.position.y, full.x - view.end.x, view.size.y), fc)
	cv.draw_rect(Rect2(view.position.x, view.position.y + view.size.y * 0.42, view.size.x, 10.0), fc)
	cv.draw_rect(Rect2(view.get_center().x - 5.0, view.position.y, 10.0, view.size.y), fc)
	cv.draw_line(Vector2(view.position.x, view.end.y + 2.0), Vector2(view.end.x, view.end.y + 2.0), Color(0.20, 0.17, 0.15), 2.0)
	title("Pinpoint", "Catch the courier and the lookout in a flash of lightning", Color(0.86, 0.92, 1.0).lerp(Color.WHITE, fl),
		Color(0.02, 0.03, 0.06), Color(0.5, 0.6, 1.0, 0.15 + 0.4 * fl))
