class_name PneumoCollisionIcon
extends RefCounted

# The crash counter's icon: TWO of this game's own capsule segments — one run coming in
# horizontally, one coming down vertically — snapped off where they met, with cartoon impact marks
# over the break.
#
# It is built from `res://art/agent_body1.png`, the same 30x25 body segment the capsules on
# the board are made of — scaled, tinted with two of the game's palette colors, and rotated onto the
# diagonal. Nothing here is invented art: the counter counts capsules crashing, so it shows the
# capsule the player looks at all game, in the colors they see it in.
#
# Earlier attempts, all worth not repeating: `res://art/bomb1.png`, which reads as a hazard sitting
# on the board rather than as two capsules hitting each other; the whole thing drawn from scratch as
# line-art, throwing away the one picture that already says "capsule"; each tube given a far half
# carrying on out the other side, which is four arms and just reads as a cross; and the sprite
# blitted untinted, which comes out white because the board tints it at runtime.

const SIZE: int = 64

# A HEAD-ON collision on one diagonal: two capsules running at each other along the same 45 degree
# track, snapped where they met, with the burst in the gap between their two torn ends.
#
# The arrangement matters more than the parts. Laid out as an L — one tube along the bottom, one
# down the side, meeting at a corner — the same pieces read as a pipe junction, and the burst had
# nowhere to sit but off to one side of it. Facing each other, the gap between the ends IS the
# impact, the burst belongs in it, and the picture fills the frame corner to corner.
const TUBE_LONG: int = 30    # along the tube
const TUBE_THICK: int = 24   # across it
const CENTER: Vector2 = Vector2(float(SIZE) * 0.5, float(SIZE) * 0.5)
# How far each torn end is pulled back from the middle, along the diagonal. Both ends face the same
# point; this is the room left for the burst between them.
const GAP: float = 7.0
const DIAG: Vector2 = Vector2(0.70710678, 0.70710678)

# The strokes thrown off the impact. Yellow against the two capsule colors, and the reason the
# tubes must not both be yellow.
const SPARK: Color = Color(1.0, 0.86, 0.32, 1.0)
const SPARK_EDGE: Color = Color(1.0, 0.55, 0.15, 1.0)

# The two colors are passed in rather than chosen here: they are the game's own palette entries, so
# the icon shows two capsules of different colors hitting each other, exactly as the board does.
# The sprite itself is near-white and is TINTED at runtime (agent.gd modulates it per capsule) —
# blitted raw it comes out white, which is what the first version of this icon looked like.
static func make(color_a: Color, color_b: Color) -> ImageTexture:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# One tube is drawn once, torn end on the right, and then placed twice: rotated 45 degrees so it
	# runs down-right into the middle, and rotated 225 so it runs up-left into the same middle.
	_place_tube(img, _tube(color_a), deg_to_rad(45.0), CENTER - DIAG * GAP)
	_place_tube(img, _tube(color_b), deg_to_rad(225.0), CENTER + DIAG * GAP)
	_burst(img)
	_sparks(img)
	return ImageTexture.create_from_image(img)

# One capsule: the board's own body segment, scaled, tinted, and snapped off at its right end.
static func _tube(col: Color) -> Image:
	var tex: Texture2D = load("res://art/agent_body1.png")
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TUBE_LONG, TUBE_THICK, Image.INTERPOLATE_LANCZOS)
	for y in TUBE_THICK:
		for x in TUBE_LONG:
			var px: Color = img.get_pixel(x, y)
			# Multiply, which is what a modulate does — the sprite keeps its own shading.
			img.set_pixel(x, y, Color(px.r * col.r, px.g * col.g, px.b * col.b, px.a))
	_tear(img)
	return img

# Bite a ragged wedge out of the right end, so it reads as snapped rather than as stopping.
static func _tear(img: Image) -> void:
	var w: float = float(TUBE_LONG)
	var h: float = float(TUBE_THICK)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(w + 1.0, -1.0),
		Vector2(w - 9.0, h * 0.16),
		Vector2(w - 2.0, h * 0.40),
		Vector2(w - 10.0, h * 0.66),
		Vector2(w - 3.0, h * 0.86),
		Vector2(w + 1.0, h + 1.0),
	])
	_fill_poly_in(img, TUBE_LONG, TUBE_THICK, pts, Color(0, 0, 0, 0), true)

# Rotate a tube into the icon. `anchor` is where the MIDDLE OF ITS TORN END lands, so both copies
# can be aimed at the same point from opposite sides without any per-copy arithmetic.
#
# Every destination pixel is mapped BACK into the tube and sampled, rather than the tube's pixels
# being thrown forward: a forward blit at 45 degrees leaves a lattice of gaps where two source
# pixels round to the same destination.
static func _place_tube(dst: Image, tube: Image, angle: float, anchor: Vector2) -> void:
	var src_anchor: Vector2 = Vector2(float(TUBE_LONG), float(TUBE_THICK) * 0.5)
	var ca: float = cos(-angle)
	var sa: float = sin(-angle)
	for y in SIZE:
		for x in SIZE:
			var d: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - anchor
			var sp: Vector2 = Vector2(d.x * ca - d.y * sa, d.x * sa + d.y * ca) + src_anchor
			if sp.x < 0.0 or sp.y < 0.0 or sp.x >= float(TUBE_LONG) or sp.y >= float(TUBE_THICK):
				continue
			var col: Color = tube.get_pixel(int(sp.x), int(sp.y))
			if col.a > 0.0:
				_blend(dst, x, y, col)

# The cartoon part, in the gap the two torn ends leave for it.
static func _burst(img: Image) -> void:
	var pts: Array = []
	var spikes: int = 9
	for i in spikes * 2:
		var ang: float = TAU * float(i) / float(spikes * 2) - PI / 2.0
		var r: float = 13.0 if i % 2 == 0 else 5.5
		pts.append(CENTER + Vector2(cos(ang), sin(ang)) * r)
	_fill_poly(img, PackedVector2Array(pts), SPARK_EDGE)
	var inner: Array = []
	for i in spikes * 2:
		var ang: float = TAU * float(i) / float(spikes * 2) - PI / 2.0
		var r: float = 9.0 if i % 2 == 0 else 3.5
		inner.append(CENTER + Vector2(cos(ang), sin(ang)) * r)
	_fill_poly(img, PackedVector2Array(inner), SPARK)

# Strokes flying out ACROSS the track — the two corners the tubes do not occupy.
static func _sparks(img: Image) -> void:
	for ang_deg: float in [125.0, 145.0, 305.0, 325.0]:
		var ang: float = deg_to_rad(ang_deg)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var a: Vector2 = CENTER + dir * 15.0
		var b: Vector2 = CENTER + dir * 27.0
		_fill_poly(img, PackedVector2Array([
			a + perp * 3.2, b + perp * 1.5, b - perp * 1.5, a - perp * 3.2]), SPARK_EDGE)
		_fill_poly(img, PackedVector2Array([
			a + perp * 1.7, b + perp * 0.7, b - perp * 0.7, a - perp * 1.7]), SPARK)

static func _fill_poly(img: Image, pts: PackedVector2Array, col: Color, replace: bool = false) -> void:
	_fill_poly_in(img, SIZE, SIZE, pts, col, replace)

# Even-odd scanline fill. Godot's Image has no polygon primitive, and the two shapes here are a torn
# edge and a stroke, so there is nothing to build them out of but this. `replace` writes the color
# straight in, which is how the tear erases (blending a transparent color changes nothing).
static func _fill_poly_in(img: Image, w: int, h: int, pts: PackedVector2Array, col: Color, replace: bool = false) -> void:
	if pts.size() < 3:
		return
	var min_y: int = h
	var max_y: int = 0
	for p: Vector2 in pts:
		min_y = mini(min_y, int(floor(p.y)))
		max_y = maxi(max_y, int(ceil(p.y)))
	min_y = maxi(min_y, 0)
	max_y = mini(max_y, h - 1)
	var n: int = pts.size()
	for y in range(min_y, max_y + 1):
		var yc: float = float(y) + 0.5
		var xs: Array = []
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var i2: int = 0
		while i2 + 1 < xs.size():
			var x0: int = maxi(int(round(float(xs[i2]))), 0)
			var x1: int = mini(int(round(float(xs[i2 + 1]))) - 1, w - 1)
			for x in range(x0, x1 + 1):
				if replace:
					img.set_pixel(x, y, col)
				else:
					_blend(img, x, y, col)
			i2 += 2

static func _blend(img: Image, x: int, y: int, col: Color) -> void:
	var dst: Color = img.get_pixel(x, y)
	var a: float = col.a + dst.a * (1.0 - col.a)
	if a <= 0.0:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r: float = (col.r * col.a + dst.r * dst.a * (1.0 - col.a)) / a
	var g: float = (col.g * col.a + dst.g * dst.a * (1.0 - col.a)) / a
	var b: float = (col.b * col.a + dst.b * dst.a * (1.0 - col.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))

# A text picture of what make() produced, for checking the composition without opening an image.
static func ascii(color_h: Color = Color.CYAN, color_v: Color = Color.MAGENTA) -> String:
	var img: Image = make(color_h, color_v).get_image()
	var ramp: String = " .:-=+*#%@"
	var out: String = ""
	for y in range(0, SIZE, 2):
		for x in range(0, SIZE):
			var a: float = img.get_pixel(x, y).a
			out += ramp[clampi(int(a * float(ramp.length() - 1) + 0.5), 0, ramp.length() - 1)]
		out += "\n"
	return out
