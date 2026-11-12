class_name TaxiCitySurround
extends RefCounted

# ROUND TAXI'S SQUARE: THE CITY AT NIGHT, SEEN FROM ABOVE (2026-11-12). A SIDEWALK ring of dark concrete
# slabs round the square, STREETLIGHTS along it, and beyond it the ROOFTOPS of the blocks round the
# plaza -- tar, gravel and metal roofs with parapets, AC units, water tanks, skylights, and a NEON sign
# on the edge facing the square. Shop-light pools spill from the building line onto the sidewalk and the
# streetlights cast warm pools; both are added light drawn UNDER the street (on top they read as a haze
# over the whole screen). The ring is a few cells wide: the square fills most of the screen, and on a
# phone the rooftops show above and below it.
# Before: a plain dark brick paving all round (and before that warm terracotta; a ring of rooftops
# alone was tried once, when it showed only under the button bar).
# Drawn by one Node2D under the GrassField, which it covers.

const SIDEWALK: float = 1.35                  # the sidewalk ring's width, in cells (2.4 pushed the rooftops off the screen)
const PAVE: Color = Color(0.16, 0.16, 0.18)
const JOINT: Color = Color(0.10, 0.10, 0.11)

static func build(level: Node, board: Array, game) -> void:
	var field: Control = level.find_child("GrassField", true, false) as Control
	if field == null or board.is_empty():
		return
	var pen: Node2D = field.get_node_or_null("City") as Node2D
	if pen == null:
		pen = Node2D.new()
		pen.name = "City"
		field.add_child(pen)
		pen.draw.connect(func() -> void: _draw(pen))
	var tile: float = float(game.tile_size)
	pen.set_meta("size", field.size)
	var sq: Rect2 = _square_rect(board, game)
	pen.set_meta("board", Rect2(sq.position - field.position, sq.size))
	pen.set_meta("tile", tile)
	pen.queue_redraw()


# the SQUARE's own extent (its road cells, the bays included), in level space: the board is larger --
# its outer rows hold the docks -- and a ring measured from the board lay off the screen
static func _square_rect(board: Array, game) -> Rect2:
	var lo: Vector2i = Vector2i(1 << 20, 1 << 20)
	var hi: Vector2i = Vector2i(-(1 << 20), -(1 << 20))
	for y in board.size():
		for x in board[y].size():
			if board[y][x] != null and board[y][x].ispipe:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var tile: float = float(game.tile_size)
	if hi.x < lo.x:
		return Rect2()
	var tl: Vector2 = game.board_to_px(lo) - Vector2(tile, tile) * 0.5
	return Rect2(tl, Vector2(hi - lo + Vector2i.ONE) * tile)


static func _draw(pen: Node2D) -> void:
	var area: Vector2 = pen.get_meta("size", Vector2.ZERO)
	var br: Rect2 = pen.get_meta("board", Rect2())
	var tile: float = pen.get_meta("tile", 40.0)
	var ring: Rect2 = br.grow(SIDEWALK * tile)
	pen.draw_rect(Rect2(Vector2.ZERO, area), Color(0.05, 0.05, 0.06))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	# ROOFTOPS: the four bands round the sidewalk, each cut into buildings
	var bands: Array = [
		Rect2(0, 0, area.x, ring.position.y),
		Rect2(0, ring.end.y, area.x, area.y - ring.end.y),
		Rect2(0, ring.position.y, ring.position.x, ring.size.y),
		Rect2(ring.end.x, ring.position.y, area.x - ring.end.x, ring.size.y),
	]
	for bi in bands.size():
		var b: Rect2 = bands[bi]
		if b.size.x < 8.0 or b.size.y < 8.0:
			continue
		var horizontal: bool = bi < 2
		var facing: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][bi]
		var t: float = 0.0
		var span: float = b.size.x if horizontal else b.size.y
		while t < span:
			var w: float = rng.randf_range(2.2, 4.6) * tile
			var lot: Rect2 = Rect2(b.position + Vector2(t, 0), Vector2(w, b.size.y)) if horizontal \
				else Rect2(b.position + Vector2(0, t), Vector2(b.size.x, w))
			_roof(pen, lot.grow(-3.0), facing, rng, tile)
			t += w
	# THE SIDEWALK: slabs on the board's own grid, each in four, a little uneven
	pen.draw_rect(ring, PAVE)
	var cols: int = int(ceil(ring.size.x / (tile * 0.5)))
	var rows: int = int(ceil(ring.size.y / (tile * 0.5)))
	for j in rows:
		for i in cols:
			var r: Rect2 = Rect2(ring.position + Vector2(i, j) * tile * 0.5, Vector2.ONE * tile * 0.5)
			if br.encloses(r):
				continue
			var k: float = rng.randf_range(-0.018, 0.018)
			pen.draw_rect(r.grow(-0.7), Color(PAVE.r + k, PAVE.g + k, PAVE.b + k + 0.004))
	for j2 in rows + 1:
		var y: float = ring.position.y + float(j2) * tile * 0.5
		pen.draw_line(Vector2(ring.position.x, y), Vector2(ring.end.x, y), JOINT, 1.0 if j2 % 2 == 0 else 0.6)
	for i2 in cols + 1:
		var x: float = ring.position.x + float(i2) * tile * 0.5
		pen.draw_line(Vector2(x, ring.position.y), Vector2(x, ring.end.y), JOINT, 1.0 if i2 % 2 == 0 else 0.6)
	# the curb of the building line: a darker step where the sidewalk meets the blocks
	pen.draw_rect(ring, Color(0.03, 0.03, 0.035), false, 3.0)
	# STREETLIGHTS (their light is added by build_night): a pole's base and the lamp's head from above
	for p: Vector2 in _lamp_spots(br, tile):
		pen.draw_circle(p + Vector2(2.5, 3.5), 5.0, Color(0, 0, 0, 0.45))
		pen.draw_circle(p, 4.6, Color(0.20, 0.20, 0.22))
		pen.draw_circle(p, 3.0, Color(1.0, 0.86, 0.58))
		pen.draw_circle(p + Vector2(-0.9, -0.9), 1.1, Color(1, 1, 1, 0.9))


# where the streetlights stand: along the sidewalk, a little out from the square, every few cells
static func _lamp_spots(br: Rect2, tile: float) -> Array:
	var out: Array = []
	var d: float = tile * 0.62
	var step: float = tile * 4.0
	var x: float = br.position.x + tile * 1.5
	while x < br.end.x - tile:
		out.append(Vector2(x, br.position.y - d))
		out.append(Vector2(x, br.end.y + d))
		x += step
	var y: float = br.position.y + tile * 3.5
	while y < br.end.y - tile:
		out.append(Vector2(br.position.x - d, y))
		out.append(Vector2(br.end.x + d, y))
		y += step
	return out


# ONE ROOFTOP: its material, a parapet round it, and what stands on it; a neon sign on the edge facing
# the square now and then
static func _roof(pen: Node2D, r: Rect2, facing: Vector2, rng: RandomNumberGenerator, tile: float) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	var kinds: Array = [Color(0.13, 0.13, 0.14), Color(0.19, 0.17, 0.15), Color(0.16, 0.18, 0.21), Color(0.21, 0.13, 0.12)]
	var base: Color = kinds[rng.randi() % kinds.size()]
	pen.draw_rect(r, base)
	# texture: gravel speckle on the light roofs, tar seams on the dark ones
	var n: int = int(r.size.x * r.size.y / 90.0)
	for i in n:
		var p: Vector2 = r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var k: float = rng.randf_range(-0.04, 0.05)
		pen.draw_rect(Rect2(p, Vector2(1.6, 1.6)), Color(base.r + k, base.g + k, base.b + k))
	# the parapet: lit along its top and left, a shadow inside along its bottom and right
	var pw: float = 3.0
	pen.draw_rect(Rect2(r.position, Vector2(r.size.x, pw)), base.lightened(0.28))
	pen.draw_rect(Rect2(r.position, Vector2(pw, r.size.y)), base.lightened(0.20))
	pen.draw_rect(Rect2(r.position + Vector2(0, r.size.y - pw), Vector2(r.size.x, pw)), base.darkened(0.35))
	pen.draw_rect(Rect2(r.position + Vector2(r.size.x - pw, 0), Vector2(pw, r.size.y)), base.darkened(0.30))
	pen.draw_rect(Rect2(r.position + Vector2(pw, pw), Vector2(r.size.x - pw * 2.0, 3.0)), Color(0, 0, 0, 0.25))
	var inner: Rect2 = r.grow(-pw - 4.0)
	if inner.size.x < 10.0 or inner.size.y < 10.0:
		return
	# things on the roof
	var count: int = rng.randi_range(1, 3)
	for c in count:
		var at: Vector2 = inner.position + Vector2(rng.randf() * maxf(1.0, inner.size.x - 16.0), rng.randf() * maxf(1.0, inner.size.y - 16.0))
		match rng.randi() % 3:
			0:      # an AC unit: a pale box with a fan grille
				var b: Rect2 = Rect2(at, Vector2(14, 11))
				pen.draw_rect(Rect2(b.position + Vector2(2, 3), b.size), Color(0, 0, 0, 0.35))
				pen.draw_rect(b, Color(0.55, 0.56, 0.58))
				pen.draw_rect(Rect2(b.position, Vector2(b.size.x, 2)), Color(0.70, 0.71, 0.73))
				pen.draw_circle(b.position + Vector2(9.5, 5.5), 3.6, Color(0.22, 0.23, 0.25))
				pen.draw_arc(b.position + Vector2(9.5, 5.5), 3.6, 0.0, TAU, 16, Color(0.40, 0.41, 0.44), 1.0, true)
			1:      # a water tank: a round wooden tub with iron hoops
				var cc: Vector2 = at + Vector2(8, 8)
				pen.draw_circle(cc + Vector2(3, 4), 8.0, Color(0, 0, 0, 0.35))
				pen.draw_circle(cc, 8.0, Color(0.34, 0.22, 0.13))
				pen.draw_circle(cc + Vector2(-1.2, -1.2), 6.0, Color(0.44, 0.30, 0.18))
				pen.draw_arc(cc, 8.0, 0.0, TAU, 24, Color(0.16, 0.14, 0.13), 1.4, true)
				pen.draw_arc(cc, 4.5, 0.0, TAU, 20, Color(0.25, 0.17, 0.10), 1.0, true)
			_:      # a skylight: a glass panel in a frame, a faint warm light under it
				var s: Rect2 = Rect2(at, Vector2(16, 10))
				pen.draw_rect(s, Color(0.30, 0.31, 0.33))
				pen.draw_rect(s.grow(-1.5), Color(0.22, 0.24, 0.30))
				pen.draw_rect(Rect2(s.position + Vector2(1.5, 1.5), Vector2(s.size.x * 0.5 - 1.5, s.size.y - 3.0)), Color(0.40, 0.34, 0.24, 0.6))
				pen.draw_line(s.position + Vector2(s.size.x * 0.5, 1.0), s.position + Vector2(s.size.x * 0.5, s.size.y - 1.0), Color(0.30, 0.31, 0.33), 1.0)
	# a NEON sign on the edge facing the square, now and then
	if rng.randf() < 0.45:
		var neon: Array = [Color(1.0, 0.35, 0.70), Color(0.30, 0.85, 1.0), Color(1.0, 0.72, 0.25), Color(0.55, 1.0, 0.45)]
		var nc: Color = neon[rng.randi() % neon.size()]
		var along: Vector2 = Vector2(absf(facing.y), absf(facing.x))
		var edge_mid: Vector2 = r.get_center() + facing * (r.size * 0.5 - Vector2(pw + 2.0, pw + 2.0))
		var half: float = minf(r.size.x * along.x + r.size.y * along.y, tile * 2.0) * 0.32
		var a0: Vector2 = edge_mid - along * half
		var a1: Vector2 = edge_mid + along * half
		pen.draw_line(a0, a1, Color(nc, 0.10), 12.0)
		pen.draw_line(a0, a1, Color(nc, 0.22), 6.0)
		pen.draw_line(a0, a1, nc.lightened(0.35), 2.2)


# NIGHT LIGHT: shop-light pools spilling from the building line onto the sidewalk (amber, magenta, cyan)
# and the streetlights' warm pools -- soft radial glows ADDED to what is under them, drawn under the
# street, so they never wash over the square.
static func build_night(level: Node, board: Array, game) -> void:
	var old: Node = level.find_child("NightGlow", true, false)
	if old != null:
		old.free()
	if board.is_empty():
		return
	var field: Control = level.find_child("GrassField", true, false) as Control
	if field == null:
		return
	var pen: Node2D = Node2D.new()
	pen.name = "NightGlow"
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pen.material = mat
	field.add_child(pen)
	pen.position = -field.position
	var tile: float = float(game.tile_size)
	var br: Rect2 = _square_rect(board, game)
	var ring: Rect2 = br.grow(SIDEWALK * tile)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31337 + board.size()
	var cols: Array = [Color(1.0, 0.62, 0.22), Color(0.95, 0.25, 0.65), Color(0.20, 0.75, 0.95), Color(1.0, 0.80, 0.40)]
	var glows: Array = []
	# shop light along the building line
	var perim: float = (ring.size.x + ring.size.y) * 2.0
	var t: float = rng.randf_range(0.0, 120.0)
	while t < perim:
		var p: Vector2
		if t < ring.size.x:
			p = ring.position + Vector2(t, 0)
		elif t < ring.size.x + ring.size.y:
			p = ring.position + Vector2(ring.size.x, t - ring.size.x)
		elif t < ring.size.x * 2.0 + ring.size.y:
			p = ring.position + Vector2(ring.size.x - (t - ring.size.x - ring.size.y), ring.size.y)
		else:
			p = ring.position + Vector2(0, ring.size.y - (t - ring.size.x * 2.0 - ring.size.y))
		glows.append([p, rng.randf_range(60.0, 110.0), cols[rng.randi() % cols.size()], 0.40])
		t += rng.randf_range(110.0, 220.0)
	# the streetlights
	for lp: Vector2 in _lamp_spots(br.grow(0.0), tile):
		glows.append([lp, 70.0, Color(1.0, 0.80, 0.50), 0.55])
	var tex: Texture2D = MainGlobals.menu_glow_texture()
	pen.draw.connect(func() -> void:
		for g in glows:
			var rad: float = g[1]
			pen.draw_texture_rect(tex, Rect2(Vector2(g[0]) - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false,
				Color(Color(g[2]), float(g[3]))))
	pen.queue_redraw()
