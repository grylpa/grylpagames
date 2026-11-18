extends "res://scripts/menu_poster3d.gd"

# POCKETS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A BILLIARD ROOM AT
# NIGHT, seen low over the table -- REAL 3-D since 2026-11-18 (the drawn table and bare room were "flat"): the felt
# running away under a long green-shaded billiard lamp, rubber cushions, polished rails inlaid with diamond sights, a
# leather pocket in the near rail; wood-paneled walls with a rack of cues, a bead scoreboard and a framed print;
# bottles of beer standing on the far rail; a cue lying across the near corner. The game's own pair of balls
# (scripts/ball_art.gd) rolls up the felt toward the pocket -- placed by the 3-D camera, so its size and place follow
# the table's perspective, its labels turning as it rolls -- and drops in; then the next pair. The room is baked, one
# picture per platform (`menu_room.webp`, `menu_room_d.webp`); the balls are live. Made up, never the board.

const PAIRS: Array = [
	[{"text": "7", "color": Color(0.95, 0.75, 0.20)}, {"shape": "★", "color": Color(0.35, 0.60, 0.95)}],
	[{"shape": "●", "color": Color(0.90, 0.30, 0.30)}, {"text": "3", "color": Color(0.40, 0.80, 0.45)}],
	[{"text": "A", "color": Color(0.80, 0.45, 0.90)}, {"shape": "▲", "color": Color(0.95, 0.55, 0.20)}],
]
const ROLL: float = 3.2          # seconds up the felt
const DROP: float = 1.0          # then into the pocket
const TABLE_Y: float = 165.0     # (a table's height off the floor: at 80 it sat on the floor with stubs for legs -- the user)
const FAR_Z: float = -1500.0
const POCKET: Vector3 = Vector3(0.0, TABLE_Y, 10.0)
const BALL_R: float = 26.0

var _balls: BallArt = null
var _pair: int = -1
var _bsize: Vector2 = Vector2.ZERO

func _baked_path() -> String:
	return "res://bucketmadness/art/menu_room.webp" if mobile else "res://bucketmadness/art/menu_room_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 560.0, 860.0) if mobile else Vector3(0.0, 610.0, 1080.0)

func _aim() -> Vector3:
	return Vector3(0.0, 110.0, -520.0) if mobile else Vector3(0.0, 170.0, -600.0)

func _fov() -> float:
	return 48.0

# the lamp hangs higher on a desktop, whose short band put it behind the title
func _lamp_y() -> float:
	return 470.0 if mobile else 700.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.02, 0.02)
	env.ambient_light_color = Color(0.60, 0.48, 0.38)
	env.ambient_light_energy = 0.40

func _build_lights() -> void:
	# the billiard lamp's three bulbs pouring light down onto the felt; a dim warm fill for the room
	# light along the WHOLE table (unlit, its far end vanished into the room and the balls there seemed to float)
	for k in 5:
		spot(Vector3(0.0, _lamp_y(), -200.0 - float(k) * 300.0), Vector3(0.0, TABLE_Y, -200.0 - float(k) * 300.0), Color(1.0, 0.92, 0.74), 5.5, 900.0, 44.0)
	light(Vector3(0.0, 400.0, 200.0), Color(1.0, 0.80, 0.55), 0.7, 1400.0)
	# a low light from the front and right, so the apron's carving, the beads and the turned legs catch highlights on
	# their clearcoat and read against the rug
	light(Vector3(380.0, 90.0, 700.0), Color(1.0, 0.90, 0.78), 1.4, 1500.0)
	light(Vector3(-420.0, 60.0, 500.0), Color(0.80, 0.86, 1.0), 0.7, 1200.0)
	# picture lights on the far wall, showing the cue rack, the scoreboard and the print
	for wl in [-420.0, 0.0, 380.0]:
		light(Vector3(wl, 520.0, FAR_Z - 300.0), Color(1.0, 0.82, 0.58), 2.2, 380.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _felt(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var nap: float = 0.5 + 0.5 * sin(float(x + y) * 1.4)
			img.set_pixel(x, y, Color(0.05, 0.30, 0.17).lerp(Color(0.08, 0.38, 0.22), nap * 0.5 + 0.5 * h01(x * 13 + y * 7)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _panels(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var c: Color = Color(0.44, 0.30, 0.16).lerp(Color(0.54, 0.38, 0.22), 0.5 + 0.5 * sin(float(x) * 0.25 + sin(float(y) * 0.05) * 2.0))
			var px: int = x % (n / 2)
			var py: int = y % (n / 2)
			if px < 4 or py < 4:
				c = Color(0.28, 0.17, 0.08)
			elif px < 8 or py < 8:
				c = c.lightened(0.12)
			img.set_pixel(x, y, c.darkened(0.06 * h01(x * 7 + y * 3)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE RUG, hand-knotted (2026-11-18; the user: "improve the rug texture" -- it was pixel diamonds): a PALE ivory field
# (so the dark mahogany stands out against it) under an all-over lattice of fine indigo lines with a small rosette at
# each crossing, a lobed CENTRAL MEDALLION in rust ringed in indigo with a gold heart, quarter medallions in the
# corners (small, rust ringed in indigo: solid indigo ones were dark blots at the near end); a BORDER of guard stripes (indigo, gold) round a rust band with a running vine and its flowers; the wool's
# pile mottling it, the abrash (bands where a new dye lot came in) along its length, and the middle worn paler
func _rug(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var ivory: Color = Color(0.86, 0.80, 0.68)
	var rust: Color = Color(0.62, 0.24, 0.16)
	var indigo: Color = Color(0.18, 0.22, 0.36)
	var gold: Color = Color(0.82, 0.62, 0.30)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.9
	var abrash: FastNoiseLite = FastNoiseLite.new()
	abrash.seed = 3
	abrash.frequency = 0.012
	var bw: float = float(w) * 0.11           # the border's width
	for y in h:
		for x in w:
			var fx: float = float(x)
			var fy: float = float(y)
			var ex: float = minf(fx, float(w - 1) - fx)
			var ey: float = minf(fy, float(h - 1) - fy)
			var e: float = minf(ex, ey)
			var c: Color = ivory
			if e < bw:
				# the border: outer guard, main band, inner guard
				var t1: float = e / bw
				if t1 < 0.10:
					c = indigo
				elif t1 < 0.16 or t1 > 0.90:
					c = gold if t1 > 0.90 else ivory
				elif t1 > 0.84:
					c = indigo
				else:
					c = rust
					# the running vine: a wave along the band, its flowers in the troughs and crests
					var along: float = fy if ex < ey else fx
					var across: float = (t1 - 0.16) / 0.68 * 2.0 - 1.0
					var wave: float = 0.55 * sin(along / bw * 2.4)
					if absf(across - wave) < 0.09:
						c = ivory
					var ph: float = fposmod(along / bw * 2.4 / PI, 2.0)
					var flower_at: float = 0.55 if ph < 1.0 else -0.55
					var dfl: Vector2 = Vector2(fposmod(along, bw * PI / 2.4) - bw * PI / 4.8, (across - flower_at) * bw * 0.34)
					var rr: float = dfl.length() / (bw * 0.20)
					var petal: float = 1.0 + 0.30 * cos(atan2(dfl.y, dfl.x) * 6.0)
					if rr < 0.45 * petal:
						c = gold if rr < 0.20 else indigo
			else:
				# the field: a lattice of fine indigo lines, a rosette at each crossing
				var cx: float = fx - float(w) * 0.5
				var cy: float = fy - float(h) * 0.5
				var cell: float = bw * 0.9
				var la: float = fposmod((cx + cy) / cell, 1.0)
				var lb: float = fposmod((cx - cy) / cell, 1.0)
				if la < 0.035 or lb < 0.035:
					c = indigo.lerp(ivory, 0.35)
				var ra: float = minf(la, 1.0 - la) * cell
				var rb: float = minf(lb, 1.0 - lb) * cell
				var rose: float = sqrt(ra * ra + rb * rb) / (cell * 0.16)
				if rose < 1.0:
					c = rust if rose > 0.45 else gold
				# the medallion: lobed, in rust ringed indigo, its heart gold
				var mr: float = Vector2(cx, cy * 0.62).length() / (float(w) * 0.30)
				var ang: float = atan2(cy * 0.62, cx)
				var lobe: float = 1.0 + 0.10 * cos(ang * 8.0) + 0.05 * cos(ang * 16.0)
				if mr < lobe:
					c = rust
					if mr > lobe - 0.06:
						c = indigo
					elif mr < 0.42 * lobe:
						c = gold if mr > 0.32 * lobe else indigo
						if mr < 0.16:
							c = rust
					elif absf(mr - 0.70 * lobe) < 0.025:
						c = ivory
				# the corner pieces: quarter medallions in indigo
				var qx: float = ex - bw
				var qy: float = ey - bw
				var qr: float = Vector2(qx, qy).length() / (float(w) * 0.12)
				var qlobe: float = 1.0 + 0.10 * cos(atan2(qy, qx) * 10.0)
				if qr < qlobe:
					c = rust.lerp(ivory, 0.15)
					if qr > qlobe - 0.12:
						c = indigo
					elif qr < 0.30:
						c = gold if qr > 0.16 else indigo
				# the middle worn a little paler
				var wear: float = 1.0 - clampf(Vector2(cx / float(w), cy / float(h)).length() * 2.4, 0.0, 1.0)
				c = c.lerp(ivory.lightened(0.1), 0.18 * wear)
			# the pile and the abrash
			var nz: float = noise.get_noise_2d(fx, fy) * 0.06
			c = c.lightened(nz) if nz > 0.0 else c.darkened(-nz)
			c = c.darkened(0.05 + 0.05 * abrash.get_noise_1d(fy))
			if (x + y * 3) % 7 == 0:
				c = c.darkened(0.04)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _labels(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var band: bool = y > n * 4 / 10 and y < n * 7 / 10
			img.set_pixel(x, y, Color(0.92, 0.86, 0.66) if band else base)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the room and the table: baked --------------------------------------------------------------------------------

func _build_still() -> void:
	var felt: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _felt(128), Vector3(4, 12, 1))
	var rail_wood: StandardMaterial3D = mat(Color.WHITE, 0.2, 0.0, tex_wood(128, Color(0.36, 0.15, 0.06), 4), Vector3(1, 14, 1))
	rail_wood.clearcoat_enabled = true
	rail_wood.clearcoat = 1.0
	var cushion: StandardMaterial3D = mat(Color(0.05, 0.24, 0.14), 0.9)
	var leather: StandardMaterial3D = mat(Color(0.20, 0.10, 0.05), 0.5)
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.30), 0.25, 0.85)
	var pearl: StandardMaterial3D = mat(Color(0.95, 0.94, 0.90), 0.2, 0.3)
	var length: float = -FAR_Z + 60.0
	var zc: float = (FAR_Z + 40.0) * 0.5
	# the floor and the paneled walls
	box(Vector3(4000.0, 4.0, 4000.0), mat(Color.WHITE, 0.6, 0.0, tex_wood(128, Color(0.52, 0.36, 0.20), 6), Vector3(12, 12, 1)), Vector3(0.0, -2.0, -800.0))
	var panels: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, _panels(128), Vector3(8, 3, 1))
	box(Vector3(4000.0, 1200.0, 10.0), panels, Vector3(0.0, 600.0, FAR_Z - 420.0))
	for sx in [-1.0, 1.0]:
		# along the table already (turned 90 degrees, one stood ACROSS the room and hid the far end)
		box(Vector3(10.0, 1200.0, 4000.0), panels, Vector3(sx * 1150.0, 600.0, -800.0))
	# THE TABLE: the slate bed under the felt, the cushions along its edges, the rails with their diamonds, the legs
	box(Vector3(600.0, 20.0, length), mat(Color(0.12, 0.10, 0.09), 0.7), Vector3(0.0, TABLE_Y - 12.0, zc))
	box(Vector3(600.0, 2.0, length), felt, Vector3(0.0, TABLE_Y - 1.0, zc))
	for sx2 in [-1.0, 1.0]:
		# the cushion: a rubber wedge along the rail, its face sloping to the felt (a tilted cylinder lay across the table)
		box(Vector3(13.0, 13.0, length), cushion, Vector3(sx2 * 296.0, TABLE_Y + 2.0, zc), Vector3(0.0, 0.0, 45.0))
		box(Vector3(56.0, 22.0, length + 112.0), rail_wood, Vector3(sx2 * 328.0, TABLE_Y + 4.0, zc))
		for dm in 6:
			var dz: float = FAR_Z + float(dm + 1) * length / 7.0
			var d_m: MeshInstance3D = sphere(3.4, pearl, Vector3(sx2 * 328.0, TABLE_Y + 15.2, dz))
			d_m.scale = Vector3(1.0, 0.25, 1.6)
		# THE BODY under the rails: a deep apron of mahogany with a molded bead, a carved panel between beads
		box(Vector3(20.0, 46.0, length + 112.0), rail_wood, Vector3(sx2 * 346.0, TABLE_Y - 30.0, zc))
		cyl(3.0, 3.0, length + 112.0, brass, Vector3(sx2 * 357.0, TABLE_Y - 9.0, zc), Vector3(90.0, 0.0, 0.0), null, 10)
		# THE LEGS: three a side, turned -- a block under the apron, a bulb, a taper to a brass-shod foot
		for lz in [40.0, zc, FAR_Z - 20.0]:
			var lp: Vector3 = Vector3(sx2 * 320.0, 0.0, float(lz))
			# a square block under the apron, a collar, a turned bulb, a long taper down to a brass-shod foot
			var top_l: float = TABLE_Y - 53.0
			box(Vector3(46.0, 30.0, 46.0), rail_wood, lp + Vector3(0.0, top_l - 15.0, 0.0))
			cyl(22.0, 22.0, 6.0, rail_wood, lp + Vector3(0.0, top_l - 33.0, 0.0), Vector3.ZERO, null, 20)
			var bulb: MeshInstance3D = sphere(24.0, rail_wood, lp + Vector3(0.0, top_l - 56.0, 0.0))
			bulb.scale = Vector3(1.0, 1.0, 1.0)
			cyl(15.0, 10.0, top_l - 90.0, rail_wood, lp + Vector3(0.0, 12.0 + (top_l - 90.0) * 0.5 - 2.0, 0.0), Vector3.ZERO, null, 18)
			cyl(12.0, 13.0, 10.0, brass, lp + Vector3(0.0, 5.0, 0.0), Vector3.ZERO, null, 16)
			cyl(10.0, 10.0, 4.0, brass, lp + Vector3(0.0, 1.0, 0.0), Vector3.ZERO, null, 16)
	box(Vector3(712.0, 22.0, 56.0), rail_wood, Vector3(0.0, TABLE_Y + 4.0, FAR_Z - 28.0))
	box(Vector3(712.0, 22.0, 56.0), rail_wood, Vector3(0.0, TABLE_Y + 4.0, 38.0))
	# the near end's apron, its carved panels framed in beads, the brass bead along its top
	box(Vector3(712.0, 46.0, 20.0), rail_wood, Vector3(0.0, TABLE_Y - 30.0, 66.0))
	cyl(3.0, 3.0, 712.0, brass, Vector3(0.0, TABLE_Y - 9.0, 77.0), Vector3(0.0, 0.0, 90.0), null, 10)
	for ap in 4:
		box(Vector3(130.0, 26.0, 2.0), mat(Color.WHITE, 0.3, 0.0, tex_wood(64, Color(0.28, 0.11, 0.05), 8)), Vector3(-240.0 + float(ap) * 160.0, TABLE_Y - 32.0, 77.0))
	box(Vector3(712.0, 46.0, 20.0), rail_wood, Vector3(0.0, TABLE_Y - 30.0, FAR_Z - 66.0))
	# A RUG under the table: hand-knotted, pale, a medallion and border (`_rug`), its fringes at the ends
	var rug_l: float = length + 500.0
	var rug_pm: PlaneMesh = PlaneMesh.new()        # (a box spread the texture over six faces)
	rug_pm.size = Vector2(1100.0, rug_l)
	put(rug_pm, mat(Color.WHITE, 0.95, 0.0, _rug(512, 1024)), Vector3(0.0, 1.2, zc))
	# the rug's thickness at its edges, and its FRINGES at both ends: cream warp threads in little knotted bunches
	var wool_edge: StandardMaterial3D = mat(Color(0.20, 0.22, 0.34), 0.95)
	for es in [-1.0, 1.0]:
		box(Vector3(6.0, 1.2, rug_l), wool_edge, Vector3(es * 550.0, 0.6, zc))
	var warp: StandardMaterial3D = mat(Color(0.86, 0.82, 0.72), 0.95)
	for fe in [-1.0, 1.0]:
		var fz: float = zc + fe * rug_l * 0.5
		box(Vector3(1100.0, 1.4, 6.0), wool_edge, Vector3(0.0, 0.7, fz))
		for fk in 110:
			var fx: float = -545.0 + float(fk) * 10.0
			var flen: float = 26.0 + 6.0 * h01(fk + int(fe * 7.0) + 20)
			var fringe: MeshInstance3D = box(Vector3(2.4, 1.0, flen), warp, Vector3(fx + 3.0 * (h01(fk * 3) - 0.5), 0.5, fz + fe * flen * 0.5), Vector3(0.0, (h01(fk * 7) - 0.5) * 14.0, 0.0))
			fringe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(600.0, 13.0, 13.0), cushion, Vector3(0.0, TABLE_Y + 2.0, FAR_Z + 4.0), Vector3(45.0, 0.0, 0.0))
	# THE POCKET in the near rail: a leather cup under a brass-bound mouth, dark inside
	cyl(BALL_R * 1.6, BALL_R * 1.2, 50.0, leather, POCKET + Vector3(0.0, -20.0, 0.0), Vector3.ZERO, null, 32)
	cyl(BALL_R * 1.45, BALL_R * 1.45, 2.0, mat(Color(0.02, 0.02, 0.02), 1.0), POCKET + Vector3(0.0, 6.0, 0.0), Vector3.ZERO, null, 32)
	var lip: TorusMesh = TorusMesh.new()
	lip.inner_radius = BALL_R * 1.45
	lip.outer_radius = BALL_R * 1.75
	put(lip, brass, POCKET + Vector3(0.0, 7.0, 0.0))
	# THE LAMP: a long green shade over the table on two chains, its three bulbs
	var lamp_z: float = -680.0
	var shade: StandardMaterial3D = mat(Color(0.10, 0.36, 0.22), 0.25, 0.3)
	shade.clearcoat_enabled = true
	box(Vector3(120.0, 30.0, 680.0), shade, Vector3(0.0, _lamp_y() + 20.0, lamp_z))
	box(Vector3(130.0, 4.0, 690.0), brass, Vector3(0.0, _lamp_y() + 4.0, lamp_z))
	for ch in [-1.0, 1.0]:
		cyl(1.2, 1.2, 600.0, brass, Vector3(0.0, _lamp_y() + 335.0, lamp_z + ch * 260.0))
	for k in 3:
		sphere(10.0, glow(Color(1.0, 0.95, 0.80)), Vector3(0.0, _lamp_y() - 4.0, -380.0 - float(k) * 300.0))
	# on the far wall: a rack of cues, a bead scoreboard, a framed print
	box(Vector3(260.0, 14.0, 20.0), rail_wood, Vector3(-420.0, 160.0, FAR_Z - 400.0))
	box(Vector3(260.0, 14.0, 20.0), rail_wood, Vector3(-420.0, 420.0, FAR_Z - 400.0))
	for cq in 6:
		var cqx: float = -520.0 + float(cq) * 40.0
		cyl(3.0, 5.5, 300.0, mat(Color.WHITE, 0.3, 0.0, tex_wood(64, Color(0.70, 0.48, 0.26), cq)), Vector3(cqx, 290.0, FAR_Z - 392.0), Vector3.ZERO, null, 12)
	box(Vector3(300.0, 70.0, 10.0), rail_wood, Vector3(380.0, 420.0, FAR_Z - 405.0))
	for wire in 2:
		cyl(0.8, 0.8, 280.0, brass, Vector3(380.0, 405.0 + float(wire) * 30.0, FAR_Z - 396.0), Vector3(0.0, 0.0, 90.0), null, 6)
		for bead in 14:
			var bxp: float = 250.0 + float(bead) * 12.0 + (90.0 if bead > 5 + wire * 3 else 0.0)
			sphere(5.0, mat(Color(0.95, 0.94, 0.88) if bead % 5 != 4 else Color(0.15, 0.12, 0.10), 0.3), Vector3(bxp, 405.0 + float(wire) * 30.0, FAR_Z - 394.0))
	box(Vector3(180.0, 140.0, 8.0), mat(Color(0.75, 0.58, 0.28), 0.3, 0.7), Vector3(0.0, 560.0, FAR_Z - 406.0))
	box(Vector3(160.0, 120.0, 2.0), mat(Color.WHITE, 0.8, 0.0, _labels(64, Color(0.20, 0.30, 0.22))), Vector3(0.0, 560.0, FAR_Z - 401.0))
	_hall(rail_wood, brass, leather)
	# BOTTLES of beer on the far rail: glass bodies, necks, labels, caps
	for b in 4:
		var bp: Vector3 = Vector3(-220.0 + float(b) * 130.0 + (40.0 if b >= 2 else 0.0), TABLE_Y + 15.0, FAR_Z - 28.0)
		var gc: Color = [Color(0.30, 0.16, 0.05, 0.85), Color(0.10, 0.30, 0.12, 0.85)][b % 2]
		var glass: StandardMaterial3D = mat(gc, 0.05, 0.3)
		cyl(14.0, 14.0, 64.0, glass, bp + Vector3(0.0, 32.0, 0.0), Vector3.ZERO, null, 20)
		cyl(5.0, 14.0, 22.0, glass, bp + Vector3(0.0, 75.0, 0.0), Vector3.ZERO, null, 20)
		cyl(4.6, 5.0, 24.0, glass, bp + Vector3(0.0, 98.0, 0.0), Vector3.ZERO, null, 16)
		cyl(5.4, 5.4, 4.0, mat(Color(0.80, 0.70, 0.30), 0.3, 0.8), bp + Vector3(0.0, 112.0, 0.0), Vector3.ZERO, null, 16)
		cyl(14.4, 14.4, 26.0, mat(Color.WHITE, 0.6, 0.0, _labels(32, Color(0.60, 0.12, 0.10) if b % 2 == 0 else Color(0.85, 0.75, 0.40))), bp + Vector3(0.0, 30.0, 0.0), Vector3.ZERO, null, 20)
	# TWO CUES lying on the felt along the left cushion, one a little across the other, their tips toward the far end
	# (one lay half off the table at a slant that read as the table standing on the floor -- the user)
	for cq in 2:
		var butt: Vector3 = Vector3(-250.0 + float(cq) * 36.0, TABLE_Y + 6.0 + float(cq) * 1.0, -60.0 - float(cq) * 70.0)
		var tip: Vector3 = Vector3(-200.0 + float(cq) * 70.0, TABLE_Y + 3.6 + float(cq) * 1.0, -620.0 - float(cq) * 50.0)
		var dirc: Vector3 = (tip - butt).normalized()
		var lenc: float = butt.distance_to(tip)
		var basis: Basis = Basis(Quaternion(Vector3.UP, dirc))
		var shaft: MeshInstance3D = cyl(3.0, 6.0, lenc, mat(Color.WHITE, 0.3, 0.0, tex_wood(64, [Color(0.86, 0.72, 0.50), Color(0.78, 0.60, 0.40)][cq], 2 + cq)), (butt + tip) * 0.5)
		shaft.basis = basis
		var wrap_m: MeshInstance3D = cyl(6.2, 6.4, lenc * 0.22, mat(Color(0.10, 0.08, 0.08) if cq == 0 else Color(0.30, 0.08, 0.06), 0.6), butt + dirc * lenc * 0.13)
		wrap_m.basis = basis
		var cap: MeshInstance3D = cyl(6.3, 6.3, 6.0, mat(Color(0.12, 0.10, 0.10), 0.4), butt + dirc * 3.0)
		cap.basis = basis
		var ferrule: MeshInstance3D = cyl(3.1, 3.1, 9.0, mat(Color(0.95, 0.94, 0.90), 0.3), tip - dirc * 4.5)
		ferrule.basis = basis
		var chalk: MeshInstance3D = cyl(3.1, 3.1, 2.5, mat(Color(0.30, 0.50, 0.85), 0.6), tip + dirc * 0.5)
		chalk.basis = basis
	# a cube of blue chalk on the rail
	box(Vector3(10.0, 10.0, 10.0), mat(Color(0.25, 0.45, 0.80), 0.8), Vector3(300.0, TABLE_Y + 20.0, 20.0), Vector3(0.0, 20.0, 0.0))

# THE HALL ROUND THE TABLE (the user: "there's not a lot going on here concerning background"): a BAR along the back
# wall at the right -- a counter with a brass foot rail, shelves of bottles lit from behind, stools -- a NEON sign
# glowing over it; at the left a high round table with two stools and glasses on it; a cue stand on the floor at the
# right; a jukebox glowing in the far left corner; wall sconces down the side walls
func _hall(wood: StandardMaterial3D, brass: StandardMaterial3D, leather: StandardMaterial3D) -> void:
	var back_z: float = FAR_Z - 410.0
	# the bar: counter, its top, a foot rail; the back bar's shelves, lit, with bottles
	var bar_x: float = 640.0
	box(Vector3(560.0, 110.0, 70.0), wood, Vector3(bar_x, 55.0, back_z + 120.0))
	box(Vector3(580.0, 8.0, 84.0), mat(Color(0.20, 0.10, 0.05), 0.15, 0.1), Vector3(bar_x, 114.0, back_z + 120.0))
	cyl(3.0, 3.0, 560.0, brass, Vector3(bar_x, 18.0, back_z + 162.0), Vector3(0.0, 0.0, 90.0), null, 12)
	var shelf_glow: StandardMaterial3D = glow(Color(1.0, 0.70, 0.40))
	box(Vector3(500.0, 200.0, 2.0), mat(Color(0.55, 0.36, 0.20), 0.3, 0.2), Vector3(bar_x, 260.0, back_z + 6.0))
	box(Vector3(480.0, 6.0, 2.0), shelf_glow, Vector3(bar_x, 172.0, back_z + 8.0))
	for sh in 3:
		var sy: float = 180.0 + float(sh) * 62.0
		box(Vector3(500.0, 5.0, 26.0), wood, Vector3(bar_x, sy, back_z + 18.0))
		for bt in 13:
			var bx: float = bar_x - 230.0 + float(bt) * 38.0 + 8.0 * h01(sh * 20 + bt)
			var gc: Color = [Color(0.40, 0.20, 0.06, 0.8), Color(0.12, 0.34, 0.14, 0.8), Color(0.75, 0.70, 0.60, 0.6), Color(0.55, 0.10, 0.10, 0.8)][(bt + sh) % 4]
			var gm: StandardMaterial3D = mat(gc, 0.05, 0.2)
			gm.emission_enabled = true
			gm.emission = Color(gc.r, gc.g, gc.b) * 0.6
			var hgt: float = 34.0 + 12.0 * h01(sh * 30 + bt)
			cyl(7.0, 7.0, hgt, gm, Vector3(bx, sy + 3.0 + hgt * 0.5, back_z + 20.0), Vector3.ZERO, null, 12)
			cyl(2.5, 6.0, 12.0, gm, Vector3(bx, sy + 3.0 + hgt + 6.0, back_z + 20.0), Vector3.ZERO, null, 10)
	light(Vector3(bar_x, 230.0, back_z + 60.0), Color(1.0, 0.70, 0.40), 1.6, 300.0)
	for st in 4:
		var stx: float = bar_x - 200.0 + float(st) * 130.0
		cyl(3.0, 3.0, 80.0, brass, Vector3(stx, 40.0, back_z + 200.0), Vector3.ZERO, null, 10)
		cyl(20.0, 22.0, 8.0, leather, Vector3(stx, 84.0, back_z + 200.0), Vector3.ZERO, null, 20)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 12.0
		ring.outer_radius = 14.0
		put(ring, brass, Vector3(stx, 30.0, back_z + 200.0))
	# the neon over the bar: the word in a glowing tube, a second color round it
	var neon: Label3D = label("BILLIARDS", 56.0, Color(1.0, 0.55, 0.30), Vector3(bar_x + 60.0, 540.0, back_z + 8.0))
	neon.outline_size = 14
	neon.outline_modulate = Color(1.0, 0.25, 0.10, 0.7)
	var neon2: Label3D = label("~ cold beer ~", 28.0, Color(0.55, 0.85, 1.0), Vector3(bar_x + 60.0, 492.0, back_z + 8.0))
	neon2.outline_size = 10
	neon2.outline_modulate = Color(0.20, 0.55, 1.0, 0.6)
	light(Vector3(bar_x + 60.0, 520.0, back_z + 60.0), Color(1.0, 0.50, 0.30), 1.2, 320.0)
	# a high round table at the left with two stools, two glasses of beer
	var ht: Vector3 = Vector3(-660.0, 0.0, -420.0)
	cyl(52.0, 52.0, 6.0, wood, ht + Vector3(0.0, 108.0, 0.0), Vector3.ZERO, null, 32)
	cyl(4.0, 4.0, 104.0, brass, ht + Vector3(0.0, 54.0, 0.0), Vector3.ZERO, null, 12)
	cyl(30.0, 34.0, 4.0, brass, ht + Vector3(0.0, 2.0, 0.0), Vector3.ZERO, null, 24)
	for gl in 2:
		var gp: Vector3 = ht + Vector3(-16.0 + float(gl) * 30.0, 111.0, 8.0 - float(gl) * 14.0)
		cyl(8.0, 7.0, 26.0, mat(Color(0.95, 0.70, 0.25, 0.75), 0.05, 0.1), gp + Vector3(0.0, 13.0, 0.0), Vector3.ZERO, null, 16)
		cyl(8.2, 8.2, 5.0, mat(Color(0.98, 0.96, 0.90), 0.8), gp + Vector3(0.0, 28.0, 0.0), Vector3.ZERO, null, 16)
	for sk in [-1.0, 1.0]:
		var sp: Vector3 = ht + Vector3(sk * 80.0, 0.0, 30.0)
		cyl(3.0, 3.0, 76.0, brass, sp + Vector3(0.0, 38.0, 0.0), Vector3.ZERO, null, 10)
		cyl(19.0, 21.0, 8.0, leather, sp + Vector3(0.0, 80.0, 0.0), Vector3.ZERO, null, 20)
	# a floor cue stand at the right, its cues leaning in it
	var cs: Vector3 = Vector3(640.0, 0.0, -360.0)
	box(Vector3(90.0, 10.0, 40.0), wood, cs + Vector3(0.0, 5.0, 0.0))
	box(Vector3(90.0, 8.0, 14.0), wood, cs + Vector3(0.0, 120.0, -10.0))
	for cq in 5:
		var cue: MeshInstance3D = cyl(2.6, 5.0, 300.0, mat(Color.WHITE, 0.3, 0.0, tex_wood(64, Color(0.70, 0.48, 0.26), cq + 9)), cs + Vector3(-34.0 + float(cq) * 17.0, 150.0, -14.0), Vector3(-6.0, 0.0, 0.0), null, 12)
		cue.scale = Vector3.ONE
	# the JUKEBOX in the far left corner: an arched cabinet, its lit front with bubble tubes, chrome grille
	var jb: Vector3 = Vector3(-860.0, 0.0, back_z + 60.0)
	box(Vector3(110.0, 150.0, 60.0), wood, jb + Vector3(0.0, 75.0, 0.0))
	cyl(55.0, 55.0, 60.0, wood, jb + Vector3(0.0, 150.0, 0.0), Vector3(90.0, 0.0, 0.0), null, 32)
	box(Vector3(80.0, 60.0, 2.0), glow(Color(1.0, 0.62, 0.28)), jb + Vector3(0.0, 120.0, 31.0))
	for bb in [-1.0, 1.0]:
		cyl(5.0, 5.0, 140.0, glow(Color(0.40, 0.75, 1.0) if bb < 0.0 else Color(1.0, 0.40, 0.55)), jb + Vector3(bb * 46.0, 110.0, 31.0), Vector3.ZERO, null, 12)
	box(Vector3(70.0, 36.0, 2.0), mat(Color(0.80, 0.80, 0.82), 0.2, 0.9), jb + Vector3(0.0, 40.0, 31.0))
	light(jb + Vector3(0.0, 120.0, 80.0), Color(1.0, 0.60, 0.40), 1.0, 260.0)
	# A SECOND TABLE at the back left under its own lamp, two balls on it, a cue across
	var t2: Vector3 = Vector3(-760.0, 0.0, -1450.0)
	box(Vector3(260.0, 14.0, 460.0), mat(Color(0.06, 0.32, 0.18), 0.9), t2 + Vector3(0.0, TABLE_Y - 2.0, 0.0))
	box(Vector3(290.0, 20.0, 490.0), wood, t2 + Vector3(0.0, TABLE_Y - 14.0, 0.0))
	for l2x in [-1.0, 1.0]:
		for l2z in [-1.0, 1.0]:
			cyl(12.0, 9.0, TABLE_Y - 24.0, wood, t2 + Vector3(l2x * 120.0, (TABLE_Y - 24.0) * 0.5, l2z * 210.0), Vector3.ZERO, null, 12)
	sphere(12.0, mat(Color(0.95, 0.94, 0.88), 0.2), t2 + Vector3(30.0, TABLE_Y + 12.0, 60.0))
	sphere(12.0, mat(Color(0.85, 0.15, 0.12), 0.2), t2 + Vector3(-40.0, TABLE_Y + 12.0, -80.0))
	box(Vector3(70.0, 22.0, 300.0), mat(Color(0.10, 0.36, 0.22), 0.25, 0.3), t2 + Vector3(0.0, 440.0, 0.0))
	cyl(1.0, 1.0, 400.0, brass, t2 + Vector3(0.0, 650.0, 0.0))
	spot(t2 + Vector3(0.0, 420.0, 0.0), t2 + Vector3(0.0, TABLE_Y, 0.0), Color(1.0, 0.90, 0.70), 3.0, 700.0, 40.0)
	# FRAMED PRINTS on the side walls, each under a little picture light
	for pw in 4:
		var side: float = -1.0 if pw % 2 == 0 else 1.0
		var pz: float = -500.0 - float(pw / 2) * 700.0
		var fr: Vector3 = Vector3(side * 1142.0, 330.0, pz)
		box(Vector3(6.0, 150.0, 200.0), brass, fr)
		box(Vector3(2.0, 130.0, 180.0), mat(Color.WHITE, 0.8, 0.0, _labels(64, [Color(0.20, 0.30, 0.40), Color(0.40, 0.22, 0.18)][pw % 2])), fr + Vector3(-side * 3.5, 0.0, 0.0))
		light(fr + Vector3(-side * 60.0, 110.0, 0.0), Color(1.0, 0.85, 0.62), 1.2, 240.0)
	# A WINDOW onto the street in the back wall's left, a neon sign's red glow outside
	var wz: float = FAR_Z - 404.0
	box(Vector3(300.0, 260.0, 2.0), mat(Color(0.20, 0.06, 0.10), 0.1), Vector3(-560.0, 300.0, wz))
	box(Vector3(160.0, 50.0, 1.0), glow(Color(1.0, 0.25, 0.30)), Vector3(-540.0, 330.0, wz - 2.0))
	for wb in [[Vector3(316.0, 14.0, 10.0), Vector3(-560.0, 436.0, wz + 4.0)], [Vector3(316.0, 14.0, 10.0), Vector3(-560.0, 164.0, wz + 4.0)], [Vector3(12.0, 270.0, 10.0), Vector3(-716.0, 300.0, wz + 4.0)], [Vector3(12.0, 270.0, 10.0), Vector3(-404.0, 300.0, wz + 4.0)], [Vector3(8.0, 260.0, 8.0), Vector3(-560.0, 300.0, wz + 4.0)]]:
		box(wb[0], wood, wb[1])
	light(Vector3(-560.0, 300.0, wz + 120.0), Color(1.0, 0.30, 0.35), 1.2, 400.0)
	# sconces down the side walls, each a pool of warm light on the panelling
	for sw in [-1.0, 1.0]:
		for sz in [-200.0, -900.0, -1600.0]:
			var scp: Vector3 = Vector3(sw * 1140.0, 300.0, sz)
			cyl(10.0, 4.0, 18.0, brass, scp, Vector3(0.0, 0.0, 90.0 * sw), null, 12)
			sphere(9.0, glow(Color(1.0, 0.86, 0.60)), scp + Vector3(-sw * 14.0, 6.0, 0.0))
			light(scp + Vector3(-sw * 30.0, 10.0, 0.0), Color(1.0, 0.80, 0.55), 1.4, 260.0)

# --- live: the pair of balls rolling up the felt into the pocket ---------------------------------------------------

# THE NEAR RAIL OVER THE SINKING BALL: the balls are 2-D over the baked table, so one going into the pocket was drawn
# over the rail round the hole ("they fall into the table wood", the user). The rail's face below its inner top edge is
# drawn again from the baked picture OVER them -- with the lower half of the pocket's mouth cut out of its top edge -- so
# a ball dropping in goes down behind the rail, into the hole
func _rail_cover() -> void:
	if _bg_tex == null or _cam3 == null:
		return
	var off: Vector2 = Vector2(0.0, _cy3 - BAKE_CY)
	var ts: Vector2 = _bg_tex.get_size()
	var left: Vector2 = screen_of(Vector3(-260.0, TABLE_Y + 15.0, POCKET.z))
	var right: Vector2 = screen_of(Vector3(260.0, TABLE_Y + 15.0, POCKET.z))
	var pts: PackedVector2Array = PackedVector2Array([left])
	var rr: float = BALL_R * 1.42
	for k in 25:
		# the mouth's near half, from its left to its right, at the lip's height
		var a: float = PI - PI * float(k) / 24.0
		pts.append(screen_of(POCKET + Vector3(cos(a) * rr, 7.0, sin(a) * rr)))
	pts.append(right)
	var depth: float = 140.0
	pts.append(right + Vector2(0.0, depth))
	pts.append(left + Vector2(0.0, depth))
	var uvs: PackedVector2Array = PackedVector2Array()
	for p in pts:
		uvs.append((p - off) / ts)
	cv.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _bg_tex)

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _cam3 == null:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if full.x <= 0.0:
		return            # no screen size yet: balls made now would have zero-sized labels
	var cycle: float = ROLL + DROP
	var n: int = int(t / cycle)
	var u: float = fmod(t, cycle)
	var ref_at: Vector3 = Vector3(0.0, TABLE_Y + BALL_R, POCKET.z - 120.0)
	var ref_px: float = screen_of(ref_at + Vector3(100.0, 0.0, 0.0)).distance_to(screen_of(ref_at))
	if n != _pair or _balls == null:
		_pair = n
		if _balls != null:
			_balls.queue_free()
		var pr: Array = PAIRS[n % PAIRS.size()]
		# the pair's picture at the near end: two balls of BALL_R and the gap, by the camera's own scale there
		_bsize = Vector2(ref_px * 1.15, ref_px * 1.15 * 0.48)
		_balls = BallArt.make(self, _bsize, pr[0], pr[1], 50 + n)
		add_child(_balls)
		if _top != null:
			move_child(_top, get_child_count() - 1)
	# THE ROLL, in perspective and in physics: struck at the far end, the pair travels the table losing speed
	# (constant friction), its size and place given by the 3-D camera, its labels turning by the distance rolled
	var p: float = clampf(u / ROLL, 0.0, 1.0)
	# losing speed but never stopping: it still rolls as it reaches the pocket and drops straight in (decelerating to a
	# stop at the lip, it paused there -- the user)
	var dist: float = p * (1.55 - 0.55 * p)
	var z: float = lerpf(FAR_Z + 200.0, POCKET.z - 50.0, dist)     # struck at the far end, rolling on to the lip
	var world: Vector3 = Vector3(sin(dist * 2.4) * 60.0 * (1.0 - dist), TABLE_Y + BALL_R, z)
	var here_px: float = screen_of(world + Vector3(100.0, 0.0, 0.0)).distance_to(screen_of(world))
	var sc: float = here_px / maxf(1.0, ref_px)
	var ctr: Vector2 = screen_of(world)
	_balls.roll_angle = dist * 26.0
	_balls.scale = Vector2(sc, sc)
	_balls.position = ctr - _bsize * 0.5 * sc
	if u >= ROLL and not _balls.has_meta("sinking"):
		_balls.set_meta("sinking", true)
		var pocket_px: Vector2 = screen_of(POCKET + Vector3(0.0, 6.0, 0.0))
		_balls.sink_into((pocket_px - _balls.position) / sc, 46.0 / sc)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	_rail_cover()
	title("Pockets", "Send rolling balls into the right pocket", Color(0.98, 0.88, 0.60), Color(0.12, 0.06, 0.02), Color(1.0, 0.8, 0.4, 0.22))
