extends "res://scripts/menu_poster3d.gd"

# CHANGE'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world behind, see scripts/menu_poster3d.gd): AT A CORNER
# SHOP'S COUNTER (2026-11-18, real 3-D -- the plain felt behind was "flat"): mahogany with a brass rail, a brass cash
# register (keys, the sale flags in its window, a crank, a drawer), a jar of coins, a bell, a receipt spike, shelves
# of jars and tins behind under a warm pendant lamp -- and the game's own coins in a slow-motion SHOWER in front of it
# all, three depths of them: small and
# dim far back, mid, and a few big and sharp up front -- each spinning on its edge as it falls (its width
# following the spin), and a large shop price tag hanging in the foreground, barely stirring: $2.85. A picture, not a counter
# (the user: a tray with coins dropping into it looked "too much like something that is playable").
# Made up, never the board.

const COIN = preload("res://change/scripts/coin.gd")
const VALUES: Array = [1.0, 0.25, 0.5, 0.10, 0.05, 1.0, 0.01, 0.25, 0.5, 0.10, 1.0, 0.05, 0.25, 0.5]
const COUNT: int = 21

var _layer: Node2D = null
var _coins: Array = []          # [node, depth 0..2, x frac, speed, phase, spin]

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	_layer = Node2D.new()
	add_child(_layer)
	# far coins first, so the near ones are drawn over them
	var order: Array = []
	for k in COUNT:
		order.append([k % 3, k])
	order.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for e in order:
		var depth: int = int(e[0])
		var k: int = int(e[1])
		var c: Node2D = COIN.new()
		_layer.add_child(c)
		c.call("setup", float(VALUES[k % VALUES.size()]), [22.0, 36.0, 60.0][depth])
		c.modulate = [Color(0.55, 0.55, 0.52), Color(0.82, 0.82, 0.80), Color(1, 1, 1)][depth]
		_coins.append([c, depth, h01(k * 3 + 1), [40.0, 70.0, 110.0][depth] * (0.8 + 0.4 * h01(k + 50)), h01(k * 3 + 2), 0.6 + 1.4 * h01(k + 80)])
	if _top != null:
		move_child(_top, get_child_count() - 1)

# --- the shop: real 3-D, baked ---------------------------------------------------------------------------------

func _baked_path() -> String:
	return "res://change/art/menu_shop.webp" if mobile else "res://change/art/menu_shop_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 210.0, 620.0) if mobile else Vector3(0.0, 220.0, 760.0)

func _aim() -> Vector3:
	return Vector3(0.0, 190.0, 0.0)

func _fov() -> float:
	return 56.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_color = Color(0.60, 0.52, 0.45)
	env.ambient_light_energy = 0.40

func _build_lights() -> void:
	# the pendant lamp over the counter, warm; a soft fill from the shop's window at the left
	spot(Vector3(40.0, 760.0, 200.0), Vector3(40.0, 150.0, 0.0), Color(1.0, 0.86, 0.62), 7.0, 1300.0, 50.0, true)
	light(Vector3(0.0, 380.0, 260.0), Color(1.0, 0.84, 0.60), 1.2, 700.0)
	light(Vector3(-500.0, 300.0, 300.0), Color(0.70, 0.80, 1.0), 0.8, 900.0)
	# a light on the register from the right front, so its brass shines
	spot(Vector3(420.0, 520.0, 420.0), Vector3(175.0, 250.0, 20.0), Color(1.0, 0.90, 0.72), 2.2, 900.0, 22.0)
	# the sconces' light washing the wallpaper up and down from each, and a warm pool on the shelves' middle
	for sxs in [-1.0, 1.0]:
		spot(Vector3(sxs * 560.0, 450.0, -370.0), Vector3(sxs * 560.0, 900.0, -420.0), Color(1.0, 0.82, 0.55), 0.6, 500.0, 36.0)
		spot(Vector3(sxs * 560.0, 420.0, -370.0), Vector3(sxs * 560.0, 0.0, -420.0), Color(1.0, 0.82, 0.55), 0.4, 500.0, 40.0)
		light(Vector3(sxs * 560.0, 440.0, -360.0), Color(1.0, 0.82, 0.55), 0.8, 220.0)

# THE WALLPAPER (the user: "make it textured and lighted"): a deep green DAMASK -- a mirrored floral medallion in a
# darker green with a thin gold line round it, repeating -- printed on paper with a fine weave, faded and foxed a
# little, a darker stain here and there
func _wallpaper(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u: float = float(x) / float(n)
			var v: float = float(y) / float(n)
			# the medallion: mirrored left-right, a lobed outline in polar terms round the cell's center
			var q: Vector2 = Vector2(absf(u - 0.5) * 2.0, (v - 0.5) * 2.0)
			var r: float = q.length()
			var a: float = atan2(q.y, q.x)
			var lobe: float = 0.55 + 0.18 * cos(a * 4.0) + 0.10 * cos(a * 7.0 + 1.0)
			var inside: float = 1.0 - smoothstep(lobe - 0.03, lobe + 0.03, r)
			var leaf: float = smoothstep(0.08, 0.0, absf(r - lobe * 0.55)) * (0.5 + 0.5 * cos(a * 6.0))
			var c: Color = Color(0.20, 0.30, 0.22).lerp(Color(0.13, 0.21, 0.15), inside)
			c = c.lerp(Color(0.62, 0.52, 0.28), 0.55 * smoothstep(0.03, 0.0, absf(r - lobe)))
			c = c.lerp(Color(0.26, 0.38, 0.28), leaf * 0.6)
			var weave: float = 0.5 + 0.5 * sin(float(x) * 2.1) * sin(float(y) * 2.3)
			c = c.darkened(0.05 * weave + 0.06 * h01(x * 7 + y * 3))
			img.set_pixel(x, y, c)
	for k in 6:
		var sc: Vector2 = Vector2(h01(k + 40) * float(n), h01(k + 41) * float(n))
		var sr: float = 8.0 + 14.0 * h01(k + 42)
		for y2 in range(int(sc.y - sr), int(sc.y + sr)):
			for x2 in range(int(sc.x - sr), int(sc.x + sr)):
				var dd: float = Vector2(float(x2), float(y2)).distance_to(sc) / sr
				if dd < 1.0:
					var px: int = posmod(x2, n)
					var py: int = posmod(y2, n)
					img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.30, 0.28, 0.16), 0.12 * (1.0 - dd)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	var mahog: StandardMaterial3D = mat(Color.WHITE, 0.22, 0.0, tex_wood(128, Color(0.40, 0.16, 0.08), 3), Vector3(4, 1, 1))
	mahog.clearcoat_enabled = true
	mahog.clearcoat = 0.9
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.30), 0.22, 0.85)
	var glass: StandardMaterial3D = mat(Color(0.85, 0.92, 0.95, 0.28), 0.04, 0.2)
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, tex_wood(128, Color(0.26, 0.13, 0.07), 9), Vector3(3, 1, 1))
	# the back wall papered in stripes, a skirting, the floor
	box(Vector3(2400.0, 1200.0, 6.0), mat(Color.WHITE, 0.75, 0.0, _wallpaper(256), Vector3(16, 8, 1)), Vector3(0.0, 400.0, -420.0))
	box(Vector3(2400.0, 30.0, 10.0), dark_wood, Vector3(0.0, 15.0, -414.0))
	# wainscot under a dado rail, panels in mouldings; a picture rail above the shelves; a cornice
	box(Vector3(2400.0, 190.0, 8.0), dark_wood, Vector3(0.0, 95.0, -414.0))
	box(Vector3(2400.0, 10.0, 14.0), mahog, Vector3(0.0, 195.0, -410.0))
	for wp in 14:
		box(Vector3(130.0, 120.0, 3.0), mahog, Vector3(-1100.0 + float(wp) * 170.0, 100.0, -409.0))
	box(Vector3(2400.0, 8.0, 12.0), dark_wood, Vector3(0.0, 640.0, -411.0))
	box(Vector3(2400.0, 22.0, 20.0), dark_wood, Vector3(0.0, 760.0, -408.0))
	# brass SCONCES either side of the shelves, each a frosted tulip glowing, throwing a scallop up the paper
	for sxs in [-1.0, 1.0]:
		var sp: Vector3 = Vector3(sxs * 560.0, 420.0, -404.0)
		cyl(9.0, 9.0, 4.0, brass, sp + Vector3(0.0, 0.0, 2.0), Vector3(90.0, 0.0, 0.0), null, 20)
		put(tube_mesh(PackedVector3Array([sp + Vector3(0.0, 0.0, 4.0), sp + Vector3(0.0, -8.0, 18.0), sp + Vector3(0.0, 6.0, 30.0)]), 2.0, 8), brass, Vector3.ZERO)
		cyl(13.0, 6.0, 22.0, glow(Color(1.0, 0.86, 0.62)), sp + Vector3(0.0, 18.0, 30.0), Vector3.ZERO, null, 20)
	box(Vector3(2400.0, 4.0, 1600.0), mat(Color.WHITE, 0.6, 0.0, tex_wood(128, Color(0.36, 0.24, 0.14), 4), Vector3(10, 8, 1)), Vector3(0.0, -2.0, 0.0))
	# SHELVES on the wall behind: boards on brackets, jars of sweets, tins, boxes, bottles
	for row in 3:
		var sy: float = 230.0 + float(row) * 110.0
		box(Vector3(900.0, 8.0, 50.0), dark_wood, Vector3(0.0, sy, -390.0))
		for br in 4:
			box(Vector3(4.0, 30.0, 30.0), brass, Vector3(-420.0 + float(br) * 280.0, sy - 18.0, -400.0))
		var x: float = -420.0
		var k: int = row * 31
		while x < 420.0:
			var kind: int = int(h01(k + 3) * 4.0)
			var col: Color = [Color(0.75, 0.20, 0.18), Color(0.20, 0.42, 0.65), Color(0.85, 0.65, 0.20), Color(0.30, 0.55, 0.30), Color(0.80, 0.78, 0.70)][int(h01(k + 4) * 5.0) % 5]
			var w: float = 30.0 + 20.0 * h01(k + 5)
			if kind == 0:
				cyl(w * 0.4, w * 0.4, 60.0, glass, Vector3(x + w * 0.5, sy + 34.0, -385.0), Vector3.ZERO, null, 20)
				for sw in 5:
					sphere(5.0, mat(col.lightened(0.2 * h01(k + sw)), 0.3), Vector3(x + w * 0.5 + (h01(k * 3 + sw) - 0.5) * w * 0.5, sy + 10.0 + float(sw) * 7.0, -385.0))
				cyl(w * 0.42, w * 0.42, 8.0, brass, Vector3(x + w * 0.5, sy + 68.0, -385.0), Vector3.ZERO, null, 20)
			elif kind == 1:
				cyl(w * 0.45, w * 0.45, 50.0, mat(col, 0.35, 0.5), Vector3(x + w * 0.5, sy + 29.0, -385.0), Vector3.ZERO, null, 20)
				cyl(w * 0.46, w * 0.46, 4.0, mat(col.lightened(0.3), 0.3, 0.6), Vector3(x + w * 0.5, sy + 30.0, -385.0), Vector3.ZERO, null, 20)
			elif kind == 2:
				box(Vector3(w, 70.0, 34.0), mat(col, 0.7), Vector3(x + w * 0.5, sy + 39.0, -385.0))
				box(Vector3(w * 0.7, 20.0, 0.6), mat(Color(0.95, 0.92, 0.82), 0.7), Vector3(x + w * 0.5, sy + 44.0, -367.6))
			else:
				cyl(w * 0.25, w * 0.30, 64.0, mat(Color(col.r * 0.5, col.g * 0.6, col.b * 0.4, 0.8), 0.05, 0.3), Vector3(x + w * 0.5, sy + 36.0, -385.0), Vector3.ZERO, null, 16)
				cyl(w * 0.09, w * 0.12, 18.0, mat(Color(col.r * 0.5, col.g * 0.6, col.b * 0.4, 0.8), 0.05, 0.3), Vector3(x + w * 0.5, sy + 76.0, -385.0), Vector3.ZERO, null, 12)
			x += w + 8.0
			k += 1
	# THE COUNTER across the front: mahogany panels with mouldings, a polished top with a rounded edge, a brass rail
	box(Vector3(1100.0, 150.0, 90.0), mahog, Vector3(0.0, 75.0, 40.0))
	for pn in 6:
		box(Vector3(150.0, 100.0, 2.0), dark_wood, Vector3(-450.0 + float(pn) * 180.0, 74.0, 86.0))
	box(Vector3(1120.0, 10.0, 110.0), mahog, Vector3(0.0, 155.0, 40.0))
	cyl(5.0, 5.0, 1120.0, mahog, Vector3(0.0, 155.0, 95.0), Vector3(0.0, 0.0, 90.0), null, 16)
	cyl(3.0, 3.0, 1100.0, brass, Vector3(0.0, 40.0, 100.0), Vector3(0.0, 0.0, 90.0), null, 16)
	_register(Vector3(175.0, 160.0, 30.0), mahog, dark_wood)
	# a JAR OF COINS at the left, a little BELL, a RECEIPT SPIKE
	var jar_c: Vector3 = Vector3(-270.0, 160.0, 50.0)
	cyl(34.0, 34.0, 90.0, glass, jar_c + Vector3(0.0, 45.0, 0.0), Vector3.ZERO, null, 32)
	cyl(26.0, 26.0, 6.0, glass, jar_c + Vector3(0.0, 93.0, 0.0), Vector3.ZERO, null, 32)
	for cn in 26:
		var ca: float = h01(cn + 200) * TAU
		var cr: float = 22.0 * sqrt(h01(cn + 201))
		var coin_m: StandardMaterial3D = mat(Color(0.85, 0.66, 0.30) if cn % 3 == 0 else Color(0.80, 0.80, 0.82), 0.25, 0.9)
		var cm: MeshInstance3D = cyl(9.0, 9.0, 2.0, coin_m, jar_c + Vector3(cos(ca) * cr, 4.0 + float(cn) * 1.6, sin(ca) * cr), Vector3(h01(cn + 202) * 60.0, 0.0, h01(cn + 203) * 60.0), null, 18)
		cm.scale = Vector3.ONE
	var bell_c: Vector3 = Vector3(-120.0, 160.0, 70.0)
	cyl(14.0, 16.0, 4.0, mat(Color(0.15, 0.10, 0.08), 0.4), bell_c + Vector3(0.0, 2.0, 0.0), Vector3.ZERO, null, 24)
	sphere(13.0, mat(Color(0.82, 0.82, 0.86), 0.12, 0.95), bell_c + Vector3(0.0, 4.0, 0.0), null, true)
	sphere(2.6, mat(Color(0.82, 0.82, 0.86), 0.12, 0.95), bell_c + Vector3(0.0, 18.0, 0.0))
	cyl(10.0, 10.0, 3.0, dark_wood, Vector3(-40.0, 161.0, 30.0), Vector3.ZERO, null, 20)
	cyl(0.8, 0.4, 40.0, mat(Color(0.75, 0.76, 0.78), 0.2, 0.9), Vector3(-40.0, 182.0, 30.0), Vector3.ZERO, null, 8)
	for rc in 4:
		box(Vector3(24.0, 0.6, 30.0), mat(Color(0.97, 0.96, 0.92), 0.7), Vector3(-40.0, 166.0 + float(rc) * 5.0, 30.0), Vector3(0.0, float(rc) * 17.0, 0.0))
	# THE PENDANT LAMP: its cord and green enamel shade, the bulb
	# (the pendant lamp hangs above the picture: only its light is seen)

# THE CASH REGISTER (the user: "very nice idea but very poorly executed -- both the machine and that paper and number
# above it"): a National-style brass machine -- on a mahogany CASH DRAWER with a brass pull and a keyhole, a BRASS
# CASE with a beaded edge and scrolled relief panels on its flanks, the KEYBOARD stepped up its sloping front (rows of
# round keys, white enamel faces in brass bezels, each on its stem, the figures on them), and over it the DISPLAY TOWER:
# the sale's tabs standing in a glass window -- "$", "2", "8", "5" -- under an ARCHED CREST with "AMOUNT PURCHASED"
# and a finial; the crank on its side, ball feet under the drawer
func _register(reg: Vector3, mahog: StandardMaterial3D, dark_wood: StandardMaterial3D) -> void:
	var brass: StandardMaterial3D = mat(Color.WHITE, 0.34, 0.55, tex_speckle(64, Color(0.86, 0.66, 0.30), 0.10, 17), Vector3(2, 2, 1))
	var bright: StandardMaterial3D = mat(Color(0.96, 0.80, 0.42), 0.22, 0.65)
	var enamel: StandardMaterial3D = mat(Color(0.96, 0.95, 0.90), 0.22, 0.0)
	enamel.clearcoat_enabled = true
	var glass: StandardMaterial3D = mat(Color(0.85, 0.92, 0.95, 0.20), 0.03, 0.2)
	var ink: Color = Color(0.12, 0.08, 0.05)
	# ball feet, the drawer
	for fx in [-1.0, 1.0]:
		for fz in [-1.0, 1.0]:
			sphere(7.0, bright, reg + Vector3(fx * 80.0, 5.0, fz * 50.0))
	put(rbox_mesh(92.0, 62.0, 44.0, 6.0, 3.0), mahog, reg + Vector3(0.0, 8.0, 0.0))
	box(Vector3(160.0, 30.0, 2.0), dark_wood, reg + Vector3(0.0, 30.0, 62.5))
	put(tube_mesh(PackedVector3Array([reg + Vector3(-34.0, 30.0, 64.0), reg + Vector3(-30.0, 30.0, 72.0), reg + Vector3(30.0, 30.0, 72.0), reg + Vector3(34.0, 30.0, 64.0)]), 2.2, 10), bright, Vector3.ZERO)
	cyl(5.0, 5.0, 1.5, bright, reg + Vector3(60.0, 32.0, 63.5), Vector3(90.0, 0.0, 0.0), null, 16)
	box(Vector3(1.6, 5.0, 1.0), mat(Color(0.05, 0.04, 0.03), 0.6), reg + Vector3(60.0, 32.0, 64.4))
	# THE CASE
	var cb: Vector3 = reg + Vector3(0.0, 52.0, -12.0)
	put(rbox_mesh(80.0, 50.0, 70.0, 12.0, 5.0), brass, cb)
	# its beaded edges, along the front and the top
	for bd in 31:
		var bx: float = -78.0 + float(bd) * 5.2
		sphere(1.6, bright, cb + Vector3(bx, 1.5, 50.5))
		sphere(1.6, bright, cb + Vector3(bx, 69.5, 45.0))
	# scrolled relief on the flanks: C-scrolls of rolled brass, a rosette at their meeting
	for side in [-1.0, 1.0]:
		var fc: Vector3 = cb + Vector3(side * 80.5, 36.0, 0.0)
		for sc in 2:
			var sp: PackedVector3Array = PackedVector3Array()
			for k in 14:
				var aa: float = PI * 1.6 * float(k) / 13.0
				var rr: float = 16.0 - float(k) * 0.7
				sp.append(fc + Vector3(side * 1.5, sin(aa) * rr * (1.0 if sc == 0 else -1.0) * 0.8, (-18.0 + float(sc) * 36.0) + cos(aa) * rr * (1.0 if sc == 0 else -1.0)))
			put(tube_mesh(sp, 1.8, 8), bright, Vector3.ZERO)
		var ros: MeshInstance3D = sphere(5.0, bright, fc + Vector3(side * 1.0, 0.0, 0.0))
		ros.scale = Vector3(0.5, 1.0, 1.0)
	# THE KEYBOARD: four rows stepping up and back, seven keys each, figures on the caps
	var figs: Array = [["1", "2", "3", "4", "5", "6", "7"], ["10", "20", "30", "40", "50", "60", "70"], ["$1", "$2", "$3", "$4", "$5", "$6", "$7"], ["NS", "CH", "PD", "RC", "", "", ""]]
	# (a sloped bed along the case's lower front, the rows stepping up it; the caps face up toward you)
	var bed: MeshInstance3D = box(Vector3(166.0, 4.0, 52.0), brass, cb + Vector3(0.0, 24.0, 64.0), Vector3(28.0, 0.0, 0.0))
	bed.scale = Vector3.ONE
	for kr in 4:
		var row_y: float = 14.0 + float(kr) * 11.0
		var row_z: float = 84.0 - float(kr) * 11.0
		for kc in 7:
			var fig: String = str(figs[3 - kr][kc])
			if fig == "":
				continue
			var kp: Vector3 = cb + Vector3(-66.0 + float(kc) * 22.0, row_y + 8.0, row_z)
			cyl(1.4, 1.4, 10.0, bright, kp + Vector3(0.0, -5.0, -1.0), Vector3(15.0, 0.0, 0.0), null, 8)
			cyl(8.0, 8.0, 2.6, bright, kp, Vector3(28.0, 0.0, 0.0), null, 20)
			cyl(6.6, 6.6, 3.0, enamel, kp + Vector3(0.0, 0.5, 0.5), Vector3(28.0, 0.0, 0.0), null, 20)
			var kl: Label3D = label(fig, 5.0 if fig.length() > 1 else 6.5, ink, kp + Vector3(0.0, 2.0, 0.9), Vector3(-62.0, 0.0, 0.0))
			kl.outline_size = 0
	# THE DISPLAY TOWER, its glass window and the sale's tabs standing in it
	var tw: Vector3 = cb + Vector3(0.0, 70.0, -18.0)
	put(rbox_mesh(56.0, 28.0, 46.0, 8.0, 3.0), brass, tw)
	box(Vector3(102.0, 34.0, 2.0), mat(Color(0.06, 0.05, 0.04), 0.7), tw + Vector3(0.0, 22.0, 27.0))
	var tabs: Array = ["$", "2", "8", "5"]
	for tb in 4:
		var tx: float = -36.0 + float(tb) * 24.0
		box(Vector3(20.0, 26.0, 0.8), enamel, tw + Vector3(tx, 22.0, 28.2))
		var tl: Label3D = label(str(tabs[tb]), 17.0, Color(0.55, 0.06, 0.06) if tb > 0 else ink, tw + Vector3(tx, 22.0, 28.8))
		tl.outline_size = 0
	var dot: Label3D = label(".", 17.0, Color(0.55, 0.06, 0.06), tw + Vector3(0.0, 14.0, 28.8))
	dot.outline_size = 0
	box(Vector3(104.0, 36.0, 1.0), glass, tw + Vector3(0.0, 22.0, 30.0))
	for gx in [-1.0, 1.0]:
		box(Vector3(4.0, 40.0, 4.0), bright, tw + Vector3(gx * 54.0, 22.0, 30.0))
	box(Vector3(112.0, 4.0, 6.0), bright, tw + Vector3(0.0, 2.0, 30.0))
	box(Vector3(112.0, 4.0, 6.0), bright, tw + Vector3(0.0, 42.0, 30.0))
	# the arched crest over it, its words, a finial
	var crest: CylinderMesh = CylinderMesh.new()
	crest.top_radius = 50.0
	crest.bottom_radius = 50.0
	crest.height = 6.0
	crest.radial_segments = 40
	put(crest, brass, tw + Vector3(0.0, 46.0, 10.0), Vector3(90.0, 0.0, 0.0))
	var arc: PackedVector3Array = PackedVector3Array()
	for ak in 25:
		var a2: float = PI * float(ak) / 24.0
		arc.append(tw + Vector3(cos(a2) * 51.0, 46.0 + sin(a2) * 51.0, 14.0))
	put(tube_mesh(arc, 2.4, 8), bright, Vector3.ZERO)
	var w1: Label3D = label("AMOUNT", 9.0, ink, tw + Vector3(0.0, 72.0, 13.5))
	w1.outline_size = 0
	var w2: Label3D = label("PURCHASED", 7.0, ink, tw + Vector3(0.0, 60.0, 13.5))
	w2.outline_size = 0
	sphere(6.0, bright, tw + Vector3(0.0, 100.0, 10.0))
	cyl(1.2, 3.0, 10.0, bright, tw + Vector3(0.0, 110.0, 10.0), Vector3.ZERO, null, 10)
	# THE CRANK on the right flank: a hub, its arm, a turned wooden handle
	var hub: Vector3 = cb + Vector3(84.0, 34.0, 10.0)
	cyl(12.0, 12.0, 5.0, bright, hub, Vector3(0.0, 0.0, 90.0), null, 24)
	box(Vector3(5.0, 42.0, 8.0), bright, hub + Vector3(4.0, -16.0, 6.0), Vector3(-20.0, 0.0, 0.0))
	cyl(4.0, 5.0, 22.0, mat(Color.WHITE, 0.35, 0.0, tex_wood(32, Color(0.30, 0.14, 0.06), 6)), hub + Vector3(16.0, -32.0, 14.0), Vector3(0.0, 0.0, 90.0), null, 14)

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _layer == null:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 250.0 if mobile else 160.0     # the shower starts under the name
	var span: float = bottom - top + 120.0
	for e in _coins:
		var c: Node2D = e[0]
		var depth: int = int(e[1])
		var y: float = fmod(float(e[4]) * span + t * float(e[3]), span) + top - 60.0
		var sway: float = sin(t * 0.7 + float(e[4]) * 9.0) * (8.0 + 8.0 * float(depth))
		c.position = Vector2(full.x * (0.06 + 0.88 * float(e[2])) + sway, y)
		# spinning on its edge: the coin's width follows the spin, never quite to nothing
		var spin: float = cos(t * float(e[5]) * 0.5 + float(e[4]) * 6.0)
		c.scale = Vector2(0.55 + 0.45 * absf(spin), 1.0)     # turning, never edge-on (thin coins read as slivers)
		c.rotation = sin(t * 0.5 + float(e[4]) * 4.0) * 0.4
		# fade in at the top, out into the panel
		var a: float = clampf((y - top + 60.0) / 80.0, 0.0, 1.0) * clampf((bottom - y) / 60.0, 0.0, 1.0)
		var base: Color = [Color(0.55, 0.55, 0.52), Color(0.82, 0.82, 0.80), Color(1, 1, 1)][depth]
		c.modulate = Color(base, a)

func _paint_top(full: Vector2, bottom: float) -> void:
	# THE PRICE TAG: a shop's manila tag, cut to a point at its eyelet, a brass-ringed hole, a twisted red-and-white
	# string up to its pin, the paper shaded and ruled, the price in deep red ink. It hangs a touch askew and barely
	# stirs (the user: the plain card swinging on a white thread was "a bit ugly")
	var pin: Vector2 = Vector2(full.x * 0.30, (196.0 if mobile else 132.0))
	var stir: float = deg_to_rad(1.4) * sin(t * 0.7)
	var tw: float = 260.0 if mobile else 186.0
	var th: float = 120.0 if mobile else 86.0
	var hang: float = clampf((bottom - pin.y) * 0.36, 50.0, 260.0)
	cv.draw_set_transform(pin, stir - 0.06, Vector2.ONE)
	# the string: two thin twisted strands, red and white
	var n_tw: int = 14
	for strand in 2:
		var pts: PackedVector2Array = PackedVector2Array()
		for k in n_tw + 1:
			var v: float = float(k) / float(n_tw)
			pts.append(Vector2(sin(v * TAU * 5.0 + float(strand) * PI) * 1.4, v * hang))
		cv.draw_polyline(pts, Color(0.80, 0.14, 0.12) if strand == 0 else Color(0.96, 0.94, 0.90), 1.6, true)
	# and on UP from the knot, fading into the dark: the string hangs from somewhere above, it does not end in the air
	var up_len: float = 150.0
	for strand2 in 2:
		var col: Color = Color(0.80, 0.14, 0.12) if strand2 == 0 else Color(0.96, 0.94, 0.90)
		for k2 in 16:
			var v0: float = float(k2) / 16.0
			var v1: float = float(k2 + 1) / 16.0
			var p0: Vector2 = Vector2(sin(-v0 * TAU * 4.0 + float(strand2) * PI) * 1.4, -v0 * up_len)
			var p1: Vector2 = Vector2(sin(-v1 * TAU * 4.0 + float(strand2) * PI) * 1.4, -v1 * up_len)
			cv.draw_line(p0, p1, Color(col, 1.0 - v1), 1.6, true)
	# the tag: point up at the eyelet, then the body; its shadow first
	var e: Vector2 = Vector2(0.0, hang)
	var cut: float = th * 0.42
	var body: PackedVector2Array = PackedVector2Array([e + Vector2(0, -6), e + Vector2(tw * 0.5, cut), e + Vector2(tw * 0.5, cut + th * 1.55),
		e + Vector2(-tw * 0.5, cut + th * 1.55), e + Vector2(-tw * 0.5, cut)])
	var shadow: PackedVector2Array = PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(7, 10))
	cv.draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
	cv.draw_polygon(body, PackedColorArray([Color(0.97, 0.90, 0.72), Color(0.95, 0.87, 0.68), Color(0.86, 0.76, 0.55), Color(0.88, 0.78, 0.57), Color(0.96, 0.89, 0.70)]))
	# a ruled border inset, and a dotted fold line under the eyelet's corner
	var inset: PackedVector2Array = PackedVector2Array()
	var ctr: Vector2 = e + Vector2(0.0, cut + th * 0.70)
	for p2 in body:
		inset.append(ctr + (p2 - ctr) * 0.90)
	inset.append(inset[0])
	cv.draw_polyline(inset, Color(0.62, 0.20, 0.14, 0.55), 1.5, true)
	var fold_y: float = e.y + cut + 6.0
	var dx: float = -tw * 0.40
	while dx < tw * 0.40:
		cv.draw_line(Vector2(dx, fold_y), Vector2(dx + 4.0, fold_y), Color(0.45, 0.35, 0.22, 0.6), 1.2)
		dx += 9.0
	# the eyelet: a brass ring round the hole
	var eye: Vector2 = e + Vector2(0.0, cut * 0.45)
	cv.draw_circle(eye, 9.0, Color(0.62, 0.46, 0.18))
	cv.draw_circle(eye + Vector2(-1, -1), 7.5, Color(0.92, 0.76, 0.40))
	cv.draw_circle(eye, 4.2, Color(0.10, 0.18, 0.12))
	# the words: a small line over the price, the price large
	var f: Font = MainGlobals.get_text_font()
	var fs_small: int = 20 if mobile else 15
	var lead: String = "PAY EXACTLY"
	var lw: float = f.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
	cv.draw_string(f, Vector2(-lw * 0.5, fold_y + 10.0 + float(fs_small)), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(0.42, 0.30, 0.18, 0.9))
	var fs: int = 64 if mobile else 46
	var price: String = "$2.85"
	var pw: float = f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var py: float = fold_y + 14.0 + float(fs_small) + float(fs) * 0.92
	cv.draw_string(f, Vector2(-pw * 0.5 + 1.5, py + 1.5), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.30, 0.06, 0.04, 0.25))
	cv.draw_string(f, Vector2(-pw * 0.5, py), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.58, 0.10, 0.08))
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the name last: the tag's string runs up BEHIND it
	title("Change", "Pay the exact amount", Color(0.97, 0.80, 0.38), Color(0.12, 0.08, 0.02), Color(1.0, 0.85, 0.4, 0.25))
