class_name TaxiCitySurround
extends RefCounted

# ROUND TAXI'S SQUARE: THE CITY AT NIGHT, SEEN FROM ABOVE (2026-11-12; buildings in perspective 2026-11-19). A
# SIDEWALK ring of dark concrete slabs round the square, STREETLIGHTS along it, and beyond it THE BLOCKS: the camera
# hangs over the square's center, so every building leans away from it -- its roof raised and pushed outward, and the
# walls that face the camera showing between its footprint and its roof: floors of windows (some lit), a shop front
# with an awning on the ground floor facing the square, neon on some. Far rows first, a side wall only above a
# shorter neighbor. The roofs: a parapet with a lit cap and its shadow inside, gravel, tar or ribbed metal, and on
# them AC units, stair bulkheads, water tanks on legs, skylights and vents, each in 3-D with its moon shadow.
# (They were flat colored slabs -- "strange big panels", the user, 2026-11-19 -- and stopped where the lawn did, so
# on a big board, with the camera zoomed out, the lawn showed above and below.)
# Shop-light pools and the streetlights' pools are ADDED light drawn under the street (build_night).
# The whole surround is DRAWN ONCE (DrawnOnce, following the camera's view): it never changes during a level.

const SIDEWALK: float = 1.35                  # the sidewalk ring's width, in cells (2.4 pushed the rooftops off the screen)
const PAVE: Color = Color(0.16, 0.16, 0.18)
const JOINT: Color = Color(0.10, 0.10, 0.11)

static func build(level: Node, board: Array, game) -> void:
	var field: Control = level.find_child("GrassField", true, false) as Control
	if field == null or board.is_empty():
		return
	var pen: DrawnOnce = field.get_node_or_null("City") as DrawnOnce
	if pen == null:
		var old: Node = field.get_node_or_null("City")
		if old != null:
			old.free()
		pen = DrawnOnce.new()
		pen.name = "City"
		pen.cover_view = true
		var keep_pen: DrawnOnce = pen
		pen.fn = func(d: Control) -> void: _draw(keep_pen, d)
		field.add_child(pen)
	var tile: float = float(game.tile_size)
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


const FACADES: Array = [Color(0.30, 0.16, 0.12), Color(0.34, 0.29, 0.22), Color(0.25, 0.26, 0.28), Color(0.19, 0.27, 0.28),
	Color(0.37, 0.34, 0.29), Color(0.27, 0.20, 0.24)]
const LIGHT: Vector2 = Vector2(-0.55, -0.83)        # the moon, from the upper left: shadows fall to the lower right

static func _draw(pen: DrawnOnce, d: CanvasItem) -> void:
	var area: Rect2 = d.get_meta("area", Rect2())
	var br: Rect2 = pen.get_meta("board", Rect2())
	var tile: float = pen.get_meta("tile", 40.0)
	if not area.has_area() or not br.has_area():
		return
	var ring: Rect2 = br.grow(SIDEWALK * tile)
	d.draw_rect(area, Color(0.035, 0.035, 0.045))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242 + int(br.size.x) * 7 + int(br.size.y)
	var cam: Vector2 = br.get_center()
	var eye_h: float = tile * 30.0
	var lots: Array = _lay_lots(area, ring, tile, rng)
	# far rows first; in a row, the lower first (a taller one's side wall then stands over the lower one's roof)
	lots.sort_custom(func(x, y): return int(x["row"]) > int(y["row"]) if int(x["row"]) != int(y["row"]) else float(x["h"]) < float(y["h"]))
	for lot in lots:
		_building(d, lot, lots, cam, eye_h, ring, tile)
	_sidewalk(d, br, ring, tile, rng)


# the lots: rows parallel to each side of the sidewalk, out to the view's edge, each row cut into buildings with an
# alley now and then; the top and bottom bands run the view's full width
static func _lay_lots(area: Rect2, ring: Rect2, tile: float, rng: RandomNumberGenerator) -> Array:
	var lots: Array = []
	var bands: Array = [
		[Rect2(area.position.x, area.position.y, area.size.x, ring.position.y - area.position.y), Vector2.UP],
		[Rect2(area.position.x, ring.end.y, area.size.x, area.end.y - ring.end.y), Vector2.DOWN],
		[Rect2(area.position.x, ring.position.y, ring.position.x - area.position.x, ring.size.y), Vector2.LEFT],
		[Rect2(ring.end.x, ring.position.y, area.end.x - ring.end.x, ring.size.y), Vector2.RIGHT],
	]
	for band in bands:
		var b: Rect2 = band[0]
		var out: Vector2 = band[1]                     # away from the square
		if b.size.x < 4.0 or b.size.y < 4.0:
			continue
		var horizontal: bool = absf(out.y) > 0.5
		var depth_all: float = b.size.y if horizontal else b.size.x
		var span: float = b.size.x if horizontal else b.size.y
		var dd: float = 0.0
		var row: int = 0
		while dd < depth_all:
			var depth: float = minf(rng.randf_range(3.2, 5.4) * tile, depth_all - dd)
			if depth_all - dd - depth < tile * 1.5:
				depth = depth_all - dd
			var t: float = 0.0
			while t < span:
				var w: float = minf(rng.randf_range(2.0, 4.4) * tile, span - t)
				if span - t - w < tile * 1.2:
					w = span - t
				var gap: float = tile * 0.22 if rng.randf() < 0.18 else 0.0
				var r: Rect2
				if horizontal:
					var y0: float = (b.end.y - dd - depth) if out.y < 0.0 else (b.position.y + dd)
					r = Rect2(b.position.x + t, y0, w - gap, depth)
				else:
					var x0: float = (b.end.x - dd - depth) if out.x < 0.0 else (b.position.x + dd)
					r = Rect2(x0, b.position.y + t, depth, w - gap)
				var hgt: float = rng.randf_range(0.9, 2.6) * tile * (1.0 + 0.25 * float(mini(row, 2)))
				lots.append({"r": r.grow(-1.0), "h": hgt, "row": row, "out": out, "facade": FACADES[rng.randi() % FACADES.size()],
					"roof": rng.randi() % 4, "seed": rng.randi(), "front": row == 0})
				t += w
			dd += depth
			row += 1
	return lots


# a point at height z above ground point p, as the camera over `cam` at `eye_h` sees it
static func _proj(p: Vector2, z: float, cam: Vector2, eye_h: float) -> Vector2:
	return cam + (p - cam) * eye_h / maxf(eye_h - z, 1.0)

static func _lot_at(lots: Array, p: Vector2) -> Dictionary:
	for lot in lots:
		if (lot["r"] as Rect2).grow(1.5).has_point(p):
			return lot
	return {}


# ONE BUILDING: the walls that face the camera (each from the top of whatever stands against it), then the roof
static func _building(d: CanvasItem, lot: Dictionary, lots: Array, cam: Vector2, eye_h: float, ring: Rect2, tile: float) -> void:
	var r: Rect2 = lot["r"]
	var hgt: float = lot["h"]
	var corners: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(lot["seed"])
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var mid: Vector2 = (a + b) * 0.5
		var n: Vector2 = Vector2(b.y - a.y, a.x - b.x).normalized()       # outward (corners run clockwise on screen)
		if (cam - mid).dot(n) <= 0.0:
			continue
		var z0: float = 0.0
		var nb: Dictionary = _lot_at(lots, mid + n * 3.0)
		if not nb.is_empty() and nb != lot:
			z0 = float(nb["h"])
		if z0 >= hgt - 1.0:
			continue
		var street: bool = nb.is_empty() and ring.grow(tile * 0.4).has_point(mid + n * tile * 0.5)
		_wall(d, a, b, z0, hgt, lot, cam, eye_h, tile, street, rng)
	_roof(d, lot, cam, eye_h, tile, rng)


# a wall from a to b, z0 to z1: its face shaded by which way it looks and lit from the street below; floors of
# windows; on a street front, the shop at its foot and maybe a neon sign at its top
static func _wall(d: CanvasItem, a: Vector2, b: Vector2, z0: float, z1: float, lot: Dictionary, cam: Vector2, eye_h: float,
		tile: float, street: bool, rng: RandomNumberGenerator) -> void:
	var base: Color = lot["facade"]
	var n: Vector2 = Vector2(b.y - a.y, a.x - b.x).normalized()
	var face: float = clampf(0.55 + 0.45 * (-n).dot(LIGHT) * 0.6, 0.25, 1.0)
	var lo_c: Color = base * face
	var hi_c: Color = base * face * 0.82
	if street:
		lo_c = lo_c.lerp(Color(0.55, 0.40, 0.25), 0.25)
	lo_c.a = 1.0
	hi_c.a = 1.0
	var q: PackedVector2Array = PackedVector2Array([_proj(a, z0, cam, eye_h), _proj(b, z0, cam, eye_h), _proj(b, z1, cam, eye_h), _proj(a, z1, cam, eye_h)])
	d.draw_polygon(q, PackedColorArray([lo_c, lo_c, hi_c, hi_c]))
	var fpx: float = q[0].distance_to(q[3]) / maxf(z1 - z0, 1.0)      # how many screen units a unit of height is here
	if fpx * (z1 - z0) < 4.0:
		return
	var length: float = a.distance_to(b)
	var fh: float = tile * 0.34                       # a floor
	var ncol: int = maxi(1, int(length / (tile * 0.42)))
	var pt: Callable = func(u: float, z: float) -> Vector2: return _proj(a.lerp(b, u), z, cam, eye_h)
	# floor lines
	var f: int = 1
	while float(f) * fh < z1 - 2.0:
		var zf: float = float(f) * fh
		if zf > z0 + 1.0:
			d.draw_line(pt.call(0.0, zf), pt.call(1.0, zf), Color(0, 0, 0, 0.22), maxf(0.6, fpx * 0.9))
		f += 1
	# windows
	var first_floor: int = 1 if street else 0
	var floors: int = int((z1 - 3.0) / fh)
	for fl in range(first_floor, floors):
		var zb: float = float(fl) * fh + fh * 0.30
		var zt: float = float(fl) * fh + fh * 0.80
		if zb < z0 + 0.5 or zt > z1 - 1.5:
			continue
		for c in ncol:
			var u0: float = (float(c) + 0.28) / float(ncol)
			var u1: float = (float(c) + 0.72) / float(ncol)
			var lit: float = rng.randf()
			var glass: Color
			if lit < 0.20:
				glass = Color(1.0, 0.78, 0.46)
			elif lit < 0.28:
				glass = Color(0.70, 0.84, 1.0)
			elif lit < 0.31:
				glass = Color(0.45, 0.55, 1.0)
			else:
				glass = Color(0.07, 0.08, 0.11).lerp(Color(0.18, 0.22, 0.30), rng.randf() * 0.5)
			var wq: PackedVector2Array = PackedVector2Array([pt.call(u0, zb), pt.call(u1, zb), pt.call(u1, zt), pt.call(u0, zt)])
			if lit < 0.31:
				var halo: PackedVector2Array = PackedVector2Array([pt.call(u0 - 0.06, zb - 1.5), pt.call(u1 + 0.06, zb - 1.5), pt.call(u1 + 0.06, zt + 1.5), pt.call(u0 - 0.06, zt + 1.5)])
				d.draw_colored_polygon(halo, Color(glass, 0.18))
				d.draw_polygon(wq, PackedColorArray([glass, glass, glass.darkened(0.25), glass.darkened(0.25)]))
				# a mullion and a blind half down, now and then
				d.draw_line(pt.call((u0 + u1) * 0.5, zb), pt.call((u0 + u1) * 0.5, zt), Color(0, 0, 0, 0.35), 0.8)
			else:
				d.draw_colored_polygon(wq, glass)
				d.draw_line(pt.call(u0, zt), pt.call(u1, zt), Color(0.5, 0.55, 0.65, 0.25), 0.7)    # the sky in its top
			# the sill
			d.draw_line(pt.call(u0 - 0.03, zb), pt.call(u1 + 0.03, zb), Color(1, 1, 1, 0.10), 0.8)
	if not street:
		return
	# THE SHOP: a lit window along the ground floor, its frame, an awning of striped canvas above it
	var shops: Array = [Color(1.0, 0.82, 0.55), Color(0.85, 0.95, 1.0), Color(1.0, 0.65, 0.40), Color(0.95, 0.85, 1.0)]
	var sc: Color = shops[rng.randi() % shops.size()]
	var zs0: float = fh * 0.12
	var zs1: float = fh * 0.78
	var sq: PackedVector2Array = PackedVector2Array([pt.call(0.08, zs0), pt.call(0.92, zs0), pt.call(0.92, zs1), pt.call(0.08, zs1)])
	d.draw_polygon(sq, PackedColorArray([sc, sc, sc.darkened(0.35), sc.darkened(0.35)]))
	var nmull: int = maxi(2, int(length / (tile * 0.8)))
	for m in nmull + 1:
		var um: float = lerpf(0.08, 0.92, float(m) / float(nmull))
		d.draw_line(pt.call(um, zs0), pt.call(um, zs1), Color(0.08, 0.07, 0.07), 1.0)
	d.draw_polyline(PackedVector2Array([sq[0], sq[1], sq[2], sq[3], sq[0]]), Color(0.08, 0.07, 0.07), 1.2)
	var awn: Array = [Color(0.62, 0.12, 0.12), Color(0.12, 0.34, 0.24), Color(0.15, 0.22, 0.46), Color(0.55, 0.38, 0.10)]
	var ac: Color = awn[rng.randi() % awn.size()]
	var stripes: int = maxi(4, int(length / (tile * 0.22)))
	for k in stripes:
		var ua: float = lerpf(0.05, 0.95, float(k) / float(stripes))
		var ub: float = lerpf(0.05, 0.95, float(k + 1) / float(stripes))
		var col: Color = ac if k % 2 == 0 else Color(0.85, 0.82, 0.74)
		d.draw_colored_polygon(PackedVector2Array([pt.call(ua, zs1 + fh * 0.04), pt.call(ub, zs1 + fh * 0.04), pt.call(ub, zs1 + fh * 0.22), pt.call(ua, zs1 + fh * 0.22)]), col * Color(0.8, 0.8, 0.8, 1.0))
	# the awning's shadow line and its lit scallop
	d.draw_line(pt.call(0.05, zs1 + fh * 0.04), pt.call(0.95, zs1 + fh * 0.04), Color(0, 0, 0, 0.45), 1.0)
	# NEON at the top of the front, now and then
	if rng.randf() < 0.45 and z1 - z0 > fh * 2.0:
		var neon: Array = [Color(1.0, 0.35, 0.70), Color(0.30, 0.85, 1.0), Color(1.0, 0.72, 0.25), Color(0.55, 1.0, 0.45)]
		var nc: Color = neon[rng.randi() % neon.size()]
		var zn: float = z1 - fh * 0.45
		var na: Vector2 = pt.call(0.22, zn)
		var nbp: Vector2 = pt.call(0.78, zn)
		d.draw_line(na, nbp, Color(nc, 0.10), 10.0)
		d.draw_line(na, nbp, Color(nc, 0.25), 5.0)
		d.draw_line(na, nbp, nc.lightened(0.45), 1.8)


# THE ROOF: the parapet's cap round it, the surface sunk a little inside it with the parapet's shadow along the
# sides toward the moon, its material, and what stands on it
static func _roof(d: CanvasItem, lot: Dictionary, cam: Vector2, eye_h: float, tile: float, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = lot["r"]
	var hgt: float = lot["h"]
	var kind: int = lot["roof"]
	var mats: Array = [Color(0.21, 0.20, 0.19), Color(0.10, 0.10, 0.11), Color(0.23, 0.25, 0.28), Color(0.19, 0.23, 0.21)]
	var base: Color = mats[kind]
	var outer: Rect2 = _proj_rect(r, hgt, cam, eye_h)
	var inner_r: Rect2 = r.grow(-maxf(2.0, tile * 0.07))
	var inner: Rect2 = _proj_rect(inner_r, hgt - 1.5, cam, eye_h)
	var cap: Color = Color(0.34, 0.34, 0.36).lerp(Color(lot["facade"]), 0.35)
	d.draw_rect(outer, cap)
	d.draw_rect(Rect2(outer.position, Vector2(outer.size.x, 1.2)), cap.lightened(0.30))
	d.draw_rect(Rect2(outer.position, Vector2(1.2, outer.size.y)), cap.lightened(0.20))
	if inner.size.x < 3.0 or inner.size.y < 3.0:
		return
	d.draw_rect(inner, base)
	# the surface's material
	var px_per: float = inner.size.x / maxf(inner_r.size.x, 1.0)
	match kind:
		0, 3:      # gravel / weathered membrane: speckle in two tones
			var count: int = int(inner.size.x * inner.size.y / 14.0)
			for i in count:
				var p: Vector2 = inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
				var k: float = rng.randf_range(-0.05, 0.06)
				d.draw_rect(Rect2(p, Vector2(1.1, 1.1)), Color(base.r + k, base.g + k, base.b + k))
		1:         # tar: seams across, patched here and there
			var step: float = tile * 0.55 * px_per
			var y: float = inner.position.y + step
			while y < inner.end.y:
				d.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(0.20, 0.20, 0.21, 0.6), 0.8)
				y += step
			for i in 3:
				var pr: Rect2 = Rect2(inner.position + Vector2(rng.randf() * inner.size.x * 0.7, rng.randf() * inner.size.y * 0.7), Vector2(inner.size.x * 0.18, inner.size.y * 0.12))
				d.draw_rect(pr, Color(0.07, 0.07, 0.08, 0.7))
		2:         # ribbed metal: ribs with a lit edge
			var rstep: float = tile * 0.16 * px_per
			var horizontal_ribs: bool = inner.size.x < inner.size.y
			var t: float = rstep
			var span: float = inner.size.y if horizontal_ribs else inner.size.x
			while t < span:
				if horizontal_ribs:
					d.draw_line(Vector2(inner.position.x, inner.position.y + t), Vector2(inner.end.x, inner.position.y + t), base.lightened(0.25), 0.8)
					d.draw_line(Vector2(inner.position.x, inner.position.y + t + 1.0), Vector2(inner.end.x, inner.position.y + t + 1.0), base.darkened(0.4), 0.8)
				else:
					d.draw_line(Vector2(inner.position.x + t, inner.position.y), Vector2(inner.position.x + t, inner.end.y), base.lightened(0.25), 0.8)
					d.draw_line(Vector2(inner.position.x + t + 1.0, inner.position.y), Vector2(inner.position.x + t + 1.0, inner.end.y), base.darkened(0.4), 0.8)
				t += rstep
	# WEATHER: the moon's light across it (brighter toward the upper left), water stains where it ponds, and a drain
	# in a corner
	d.draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([Color(0.75, 0.82, 1.0, 0.07), Color(0.75, 0.82, 1.0, 0.02), Color(0, 0, 0, 0.14), Color(0, 0, 0, 0.05)]))
	var mind: float = minf(inner.size.x, inner.size.y)
	for st in rng.randi_range(1, 3):
		var sr: float = mind * rng.randf_range(0.10, 0.24)
		var sc: Vector2 = inner.position + Vector2(rng.randf_range(sr, inner.size.x - sr), rng.randf_range(sr, inner.size.y - sr))
		var squash: float = rng.randf_range(0.55, 1.0)
		for ring_k in 5:
			d.draw_set_transform(sc, rng.randf() * 0.4, Vector2(1.0, squash))
			d.draw_circle(Vector2.ZERO, sr * (1.0 - 0.17 * float(ring_k)), Color(0.02, 0.02, 0.03, 0.045))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if mind > 10.0:
		var dc: Vector2 = Vector2(inner.end.x - mind * 0.12, inner.end.y - mind * 0.12)
		d.draw_circle(dc, maxf(1.2, mind * 0.035), Color(0.05, 0.05, 0.06))
		d.draw_arc(dc, maxf(1.2, mind * 0.035), 0.0, TAU, 12, Color(0.45, 0.45, 0.48, 0.6), 0.7, true)
	# the parapet's shadow inside it, along the top and left (the moon is up and to the left)
	var sw: float = maxf(2.0, tile * 0.12 * px_per)
	d.draw_rect(Rect2(inner.position, Vector2(inner.size.x, sw)), Color(0, 0, 0, 0.30))
	d.draw_rect(Rect2(inner.position, Vector2(sw, inner.size.y)), Color(0, 0, 0, 0.24))
	d.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1.0), Vector2(inner.size.x, 1.0)), Color(1, 1, 1, 0.07))
	# WHAT STANDS ON IT
	var room: Rect2 = inner_r.grow(-tile * 0.25)
	if room.size.x < tile * 0.6 or room.size.y < tile * 0.6:
		return
	var placed: Array = []
	var count2: int = rng.randi_range(2, 4)
	for c in count2:
		var which: int = rng.randi() % 5
		var fs: Vector2 = [Vector2(0.55, 0.40), Vector2(0.75, 0.55), Vector2(0.55, 0.55), Vector2(0.70, 0.45), Vector2(0.22, 0.22)][which] * tile
		if fs.x > room.size.x or fs.y > room.size.y:
			continue
		var at: Vector2 = room.position + Vector2(rng.randf() * (room.size.x - fs.x), rng.randf() * (room.size.y - fs.y))
		var fr: Rect2 = Rect2(at, fs)
		var clash: bool = false
		for pr2 in placed:
			if (pr2 as Rect2).grow(tile * 0.12).intersects(fr):
				clash = true
		if clash:
			continue
		placed.append(fr)
		match which:
			0:
				_box(d, fr, hgt - 1.5, tile * 0.22, Color(0.52, 0.53, 0.55), cam, eye_h, "ac")
			1:
				_box(d, fr, hgt - 1.5, tile * 0.50, Color(lot["facade"]).lightened(0.10), cam, eye_h, "stair")
			2:
				_tank(d, fr, hgt - 1.5, tile, cam, eye_h)
			3:
				_skylight(d, fr, hgt - 1.5, tile, cam, eye_h)
			_:
				_vent(d, fr, hgt - 1.5, tile, cam, eye_h)

static func _proj_rect(r: Rect2, z: float, cam: Vector2, eye_h: float) -> Rect2:
	var p0: Vector2 = _proj(r.position, z, cam, eye_h)
	var p1: Vector2 = _proj(r.end, z, cam, eye_h)
	return Rect2(p0, p1 - p0)

# its shadow on the roof, away from the moon, `oh` tall
static func _shadow(d: CanvasItem, fr: Rect2, z: float, oh: float, cam: Vector2, eye_h: float) -> void:
	var off: Vector2 = -LIGHT * oh * 0.9
	var pts: PackedVector2Array = PackedVector2Array()
	for p in [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]:
		pts.append(_proj(p, z, cam, eye_h))
	for p2 in [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]:
		pts.append(_proj(p2 + off, z, cam, eye_h))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() >= 4:
		d.draw_colored_polygon(hull, Color(0, 0, 0, 0.32))

# a box on the roof: an AC unit (a fan grille on top) or a stair bulkhead (a door in its face toward the camera)
static func _box(d: CanvasItem, fr: Rect2, z: float, oh: float, col: Color, cam: Vector2, eye_h: float, kind: String) -> void:
	_shadow(d, fr, z, oh, cam, eye_h)
	var corners: Array = [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var n: Vector2 = Vector2(b.y - a.y, a.x - b.x).normalized()
		if (cam - (a + b) * 0.5).dot(n) <= 0.0:
			continue
		var shade: float = clampf(0.55 + 0.35 * (-n).dot(LIGHT), 0.3, 1.0)
		var wc: Color = Color(col.r * shade, col.g * shade, col.b * shade)
		var q: PackedVector2Array = PackedVector2Array([_proj(a, z, cam, eye_h), _proj(b, z, cam, eye_h), _proj(b, z + oh, cam, eye_h), _proj(a, z + oh, cam, eye_h)])
		d.draw_polygon(q, PackedColorArray([wc.darkened(0.15), wc.darkened(0.15), wc, wc]))
		if kind == "stair" and a.distance_to(b) > oh * 0.6:
			var dq: PackedVector2Array = PackedVector2Array([_proj(a.lerp(b, 0.35), z, cam, eye_h), _proj(a.lerp(b, 0.65), z, cam, eye_h),
				_proj(a.lerp(b, 0.65), z + oh * 0.7, cam, eye_h), _proj(a.lerp(b, 0.35), z + oh * 0.7, cam, eye_h)])
			d.draw_colored_polygon(dq, Color(0.12, 0.10, 0.09))
			d.draw_circle(_proj(a.lerp(b, 0.40), z + oh * 0.35, cam, eye_h), 0.7, Color(0.8, 0.7, 0.4))
	var top: Rect2 = _proj_rect(fr, z + oh, cam, eye_h)
	d.draw_rect(top, col.lightened(0.12))
	d.draw_rect(Rect2(top.position, Vector2(top.size.x, 1.0)), col.lightened(0.35))
	if kind == "ac":
		var fc: Vector2 = top.get_center() + Vector2(top.size.x * 0.15, 0.0)
		var fr2: float = minf(top.size.x, top.size.y) * 0.36
		d.draw_circle(fc, fr2, Color(0.16, 0.17, 0.19))
		for k in 3:
			var ang: float = TAU * float(k) / 3.0 + 0.4
			d.draw_line(fc, fc + Vector2.from_angle(ang) * fr2 * 0.9, Color(0.45, 0.46, 0.48), 1.0)
		d.draw_arc(fc, fr2, 0.0, TAU, 20, Color(0.62, 0.63, 0.66), 1.0, true)
		d.draw_line(top.position + Vector2(2, top.size.y - 2), top.position + Vector2(top.size.x * 0.4, top.size.y - 2), Color(0.3, 0.3, 0.32), 1.0)
	else:
		d.draw_rect(top.grow(-1.5), col, false, 1.0)

# a water tank: a wooden tub with iron hoops on four legs, its conical lid
static func _tank(d: CanvasItem, fr: Rect2, z: float, tile: float, cam: Vector2, eye_h: float) -> void:
	var c: Vector2 = fr.get_center()
	var rad: float = fr.size.x * 0.48
	var legs: float = tile * 0.35
	var body: float = tile * 0.55
	_shadow(d, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), z, legs + body, cam, eye_h)
	for k in 4:
		var lp: Vector2 = c + Vector2.from_angle(PI * 0.25 + PI * 0.5 * float(k)) * rad * 0.75
		d.draw_line(_proj(lp, z, cam, eye_h), _proj(lp, z + legs, cam, eye_h), Color(0.12, 0.12, 0.13), 1.2)
	# the tub: the hull of its bottom and top rims, shaded across, then the lid
	var zb: float = z + legs
	var zt: float = zb + body
	var bot: PackedVector2Array = PackedVector2Array()
	var topv: PackedVector2Array = PackedVector2Array()
	for k in 24:
		var ang: float = TAU * float(k) / 24.0
		bot.append(_proj(c + Vector2.from_angle(ang) * rad, zb, cam, eye_h))
		topv.append(_proj(c + Vector2.from_angle(ang) * rad, zt, cam, eye_h))
	var hull: PackedVector2Array = Geometry2D.convex_hull(bot + topv)
	if hull.size() >= 4:
		d.draw_colored_polygon(hull, Color(0.30, 0.20, 0.12))
	for hoop in 3:
		var zh: float = lerpf(zb, zt, 0.2 + 0.3 * float(hoop))
		var ring: PackedVector2Array = PackedVector2Array()
		for k in 25:
			ring.append(_proj(c + Vector2.from_angle(TAU * float(k) / 24.0) * rad, zh, cam, eye_h))
		d.draw_polyline(ring, Color(0.10, 0.10, 0.11), 1.0, true)
	d.draw_colored_polygon(topv, Color(0.40, 0.28, 0.17))
	var apex: Vector2 = _proj(c, zt + body * 0.35, cam, eye_h)
	for k in 24:
		var p0: Vector2 = topv[k]
		var p1: Vector2 = topv[(k + 1) % 24]
		var lit: float = clampf(0.5 + 0.5 * (-(Vector2.from_angle(TAU * (float(k) + 0.5) / 24.0))).dot(LIGHT), 0.0, 1.0)
		d.draw_colored_polygon(PackedVector2Array([p0, p1, apex]), Color(0.22, 0.16, 0.11).lerp(Color(0.48, 0.36, 0.24), lit))

# a skylight: a pitched glass roof on a low curb, a warm room under it
static func _skylight(d: CanvasItem, fr: Rect2, z: float, tile: float, cam: Vector2, eye_h: float) -> void:
	var oh: float = tile * 0.10
	_box(d, fr, z, oh, Color(0.36, 0.37, 0.39), cam, eye_h, "curb")
	var g: Rect2 = _proj_rect(fr.grow(-1.5), z + oh, cam, eye_h)
	d.draw_rect(g, Color(0.42, 0.34, 0.22))
	d.draw_rect(Rect2(g.position, Vector2(g.size.x * 0.5, g.size.y)), Color(0.62, 0.50, 0.32))
	var panes: int = maxi(2, int(fr.size.x / (tile * 0.18)))
	for k in panes + 1:
		var x: float = g.position.x + g.size.x * float(k) / float(panes)
		d.draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Color(0.20, 0.20, 0.22), 1.0)
	d.draw_line(g.position + Vector2(0, g.size.y * 0.5), g.position + Vector2(g.size.x, g.size.y * 0.5), Color(0.28, 0.28, 0.30), 1.2)
	d.draw_line(g.position + Vector2(1, 1), g.position + Vector2(g.size.x * 0.45, 1), Color(1, 1, 1, 0.25), 1.0)

# a vent: a short pipe with a mushroom cap
static func _vent(d: CanvasItem, fr: Rect2, z: float, tile: float, cam: Vector2, eye_h: float) -> void:
	var c: Vector2 = fr.get_center()
	var oh: float = tile * 0.22
	_shadow(d, Rect2(c - fr.size * 0.25, fr.size * 0.5), z, oh, cam, eye_h)
	d.draw_line(_proj(c, z, cam, eye_h), _proj(c, z + oh, cam, eye_h), Color(0.35, 0.36, 0.38), maxf(1.5, fr.size.x * 0.30))
	var cap: Vector2 = _proj(c, z + oh, cam, eye_h)
	d.draw_circle(cap, fr.size.x * 0.48, Color(0.30, 0.31, 0.33))
	d.draw_circle(cap + Vector2(-0.5, -0.5), fr.size.x * 0.32, Color(0.46, 0.47, 0.50))

# THE SIDEWALK: slabs on the board's own grid, each in four, a little uneven; the curb of the building line; the
# streetlights (their light is added by build_night): a pole's base and the lamp's head from above
static func _sidewalk(d: CanvasItem, br: Rect2, ring: Rect2, tile: float, rng: RandomNumberGenerator) -> void:
	d.draw_rect(ring, PAVE)
	var cols: int = int(ceil(ring.size.x / (tile * 0.5)))
	var rows: int = int(ceil(ring.size.y / (tile * 0.5)))
	for j in rows:
		for i in cols:
			var r: Rect2 = Rect2(ring.position + Vector2(i, j) * tile * 0.5, Vector2.ONE * tile * 0.5)
			if br.encloses(r):
				continue
			var k: float = rng.randf_range(-0.018, 0.018)
			d.draw_rect(r.grow(-0.7), Color(PAVE.r + k, PAVE.g + k, PAVE.b + k + 0.004))
	for j2 in rows + 1:
		var y: float = ring.position.y + float(j2) * tile * 0.5
		d.draw_line(Vector2(ring.position.x, y), Vector2(ring.end.x, y), JOINT, 1.0 if j2 % 2 == 0 else 0.6)
	for i2 in cols + 1:
		var x: float = ring.position.x + float(i2) * tile * 0.5
		d.draw_line(Vector2(x, ring.position.y), Vector2(x, ring.end.y), JOINT, 1.0 if i2 % 2 == 0 else 0.6)
	d.draw_rect(ring, Color(0.03, 0.03, 0.035), false, 3.0)
	for p: Vector2 in _lamp_spots(br, tile):
		d.draw_circle(p + Vector2(2.5, 3.5), 5.0, Color(0, 0, 0, 0.45))
		d.draw_circle(p, 4.6, Color(0.20, 0.20, 0.22))
		d.draw_circle(p, 3.0, Color(1.0, 0.86, 0.58))
		d.draw_circle(p + Vector2(-0.9, -0.9), 1.1, Color(1, 1, 1, 0.9))


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
