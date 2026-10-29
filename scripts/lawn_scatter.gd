class_name LawnScatter
extends RefCounted

# A FEW SMALL THINGS LYING ABOUT ON THE LAWN of the road games (Valet, Dispatch, Headlights, Lights
# Out, taxi): stones, bushes, patches of dirt and sand, trees, now and then a pond, rarely a tiny
# house. SPORADIC and SMALL, so the lawn reads as countryside round the roads without shouting:
#  - placed at random spots in the world, never per cell, so nothing lines up with the board's grid
#  - kept clear of every road and dock (and a margin round them), so nothing pokes out from under
#    the asphalt or sits against the game's pieces
#  - muted colors close to the lawn's own, soft shadows, no outlines
# (A block-by-block scenery -- rooftops, crop fields, a toy town, gardens -- read as a tiled pattern
# and was far too loud; see the memory note on board backgrounds.)
#
# Drawn by one Node2D under the GrassField (scripts/grass_field.gd), so it is behind everything on
# the board. `scatter()` is called once the board is built.

const DENSITY: float = 0.5           # items tried per free cell's worth of area
const MARGIN: float = 4.0            # clear space kept round roads and docks
const SHADOW: Color = Color(0, 0, 0, 0.26)

# `density` and `size` scale the defaults; `garden` favors bushes and trees (Detour's courtyard edge).
static func scatter(level: Node, board: Array, game, seed_i: int, density: float = 1.0, size: float = 1.0,
		garden: bool = false) -> void:
	var field: Control = level.find_child("GrassField", true, false) as Control
	if field == null or board.is_empty():
		return
	var pen: Node2D = field.get_node_or_null("Scatter") as Node2D
	if pen == null:
		pen = Node2D.new()
		pen.name = "Scatter"
		field.add_child(pen)
		pen.draw.connect(func() -> void: _draw_all(pen))
	var tile: float = float(game.tile_size)
	var origin: Vector2 = game.board_to_px(Vector2i(0, 0)) - Vector2(tile, tile) * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x5bd1e995 + seed_i * 7919 + board.size() * 131 + board[0].size()
	var items: Array = []
	var area: Rect2 = Rect2(field.position, field.size)
	var tries: int = int(area.size.x * area.size.y / (tile * tile) * DENSITY * density)
	var houses: int = 0
	for _i in tries:
		var p: Vector2 = area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var roll: float = rng.randf()
		if garden:
			roll = [0.10, 0.45, 0.50, 0.85, 0.88, 0.55][rng.randi() % 6] + rng.randf() * 0.04
		var kind: String = "stones"
		var rad: float = 5.0
		if roll < 0.36:
			kind = "stones"; rad = 4.0
		elif roll < 0.58:
			kind = "bush"; rad = 5.5
		elif roll < 0.70:
			kind = "dirt"; rad = rng.randf_range(7.0, 12.0)
		elif roll < 0.77:
			kind = "sand"; rad = rng.randf_range(7.0, 11.0)
		elif roll < 0.90:
			kind = "tree"; rad = rng.randf_range(8.0, 11.0)
		elif roll < 0.96:
			kind = "pond"; rad = rng.randf_range(8.0, 12.0)
		else:
			if houses >= 2:
				continue
			kind = "house"; rad = 10.0
		rad *= size
		if not _free(board, origin, tile, p, rad + MARGIN):
			continue
		# the small grass blocks inside a board (one cell between roads) only take small things
		if rad > 6.0 and not _free(board, origin, tile, p, rad + MARGIN + tile * 0.5):
			continue
		if _crowded(items, p, rad):
			continue
		if kind == "house":
			houses += 1
		items.append({"kind": kind, "p": p - field.position, "r": rad * size, "seed": rng.randi(), "s": size})
	# THE GRASS ON AND ROUND THE BOARD: every empty square of the board and the strip of cells just
	# outside it get a chance at an item, placed off-center at a random size -- many left bare, so
	# it does not read as a pattern. Without this a full-screen board got next to nothing (the random
	# spots above almost never landed in its small grass squares).
	var h: int = board.size()
	var w: int = board[0].size()
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var inside: bool = x >= 0 and y >= 0 and x < w and y < h
			if inside and (board[y][x].ispipe or board[y][x].istarget):
				continue
			if rng.randf() > (0.42 if inside else 0.55) * density:
				continue
			var c: Vector2 = origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * tile \
				+ Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)) * tile
			var roll2: float = rng.randf()
			var kind2: String = "stones" if roll2 < 0.40 else ("bush" if roll2 < 0.80 else "dirt")
			var rad2: float = (4.0 if kind2 == "stones" else (5.5 if kind2 == "bush" else 7.0)) * size
			if not inside and rng.randf() < 0.3:
				kind2 = "tree"
				rad2 = rng.randf_range(8.0, 10.0) * size
			if not _free(board, origin, tile, c, rad2 + MARGIN) or _crowded(items, c, rad2):
				continue
			items.append({"kind": kind2, "p": c - field.position, "r": rad2, "seed": rng.randi(), "s": size})
	pen.set_meta("items", items)
	pen.queue_redraw()


# No road or dock cell within `rad` of `p` (off the board counts as free lawn).
static func _free(board: Array, origin: Vector2, tile: float, p: Vector2, rad: float) -> bool:
	var c0: Vector2i = Vector2i(((p - Vector2(rad, rad) - origin) / tile).floor())
	var c1: Vector2i = Vector2i(((p + Vector2(rad, rad) - origin) / tile).floor())
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if y < 0 or y >= board.size() or x < 0 or x >= board[y].size():
				continue
			var cell = board[y][x]
			if not (cell.ispipe or cell.istarget):
				continue
			var r: Rect2 = Rect2(origin + Vector2(x, y) * tile, Vector2(tile, tile))
			var q: Vector2 = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			if q.distance_to(p) < rad:
				return false
	return true


static func _crowded(items: Array, p: Vector2, rad: float) -> bool:
	for it in items:
		if (it["p"] as Vector2).distance_to(p) < float(it["r"]) + rad + 8.0:
			return true
	return false


static func _blob(c: Vector2, rad: float, rng: RandomNumberGenerator, squash: float = 0.75) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 12
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var w: float = rng.randf_range(0.78, 1.08)
		pts.append(c + Vector2(cos(a), sin(a) * squash) * rad * w)
	return pts


static func _draw_all(pen: Node2D) -> void:
	var items: Array = pen.get_meta("items", [])
	for it in items:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(it["seed"])
		var p: Vector2 = it["p"]
		var r: float = it["r"]
		var k_s: float = float(it.get("s", 1.0))
		pen.draw_set_transform(p, 0.0, Vector2(k_s, k_s))
		p = Vector2.ZERO
		r /= k_s
		match String(it["kind"]):
			"stones":
				for k in rng.randi_range(1, 3):
					var c: Vector2 = p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3))
					var sr: float = rng.randf_range(2.2, 3.8)
					var col: Color = Color(0.54, 0.55, 0.51).lerp(Color(0.64, 0.61, 0.54), rng.randf())
					pen.draw_colored_polygon(_blob(c + Vector2(0.8, 1.0), sr, rng), SHADOW)
					pen.draw_colored_polygon(_blob(c, sr, rng), col)
					pen.draw_circle(c - Vector2(sr * 0.3, sr * 0.3), sr * 0.35, col.lightened(0.18), true, -1.0, true)
			"bush":
				var base: Color = Color(0.15, 0.36, 0.15)
				for k in rng.randi_range(2, 4):
					var c2: Vector2 = p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3))
					pen.draw_circle(c2 + Vector2(1.2, 1.6), 3.8, SHADOW, true, -1.0, true)
				for k in rng.randi_range(2, 4):
					var c3: Vector2 = p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3))
					var br: float = rng.randf_range(3.0, 4.6)
					pen.draw_circle(c3, br, base, true, -1.0, true)
					pen.draw_circle(c3 - Vector2(0.9, 1.0), br * 0.6, base.lightened(0.12), true, -1.0, true)
			"dirt":
				pen.draw_colored_polygon(_blob(p, r, rng, 0.62), Color(0.34, 0.27, 0.17, 0.70))
				pen.draw_colored_polygon(_blob(p + Vector2(1, 0.5), r * 0.6, rng, 0.6), Color(0.34, 0.27, 0.18, 0.45))
			"sand":
				pen.draw_colored_polygon(_blob(p, r, rng, 0.6), Color(0.62, 0.55, 0.40, 0.45))
				pen.draw_colored_polygon(_blob(p - Vector2(1, 0.5), r * 0.55, rng, 0.6), Color(0.70, 0.63, 0.48, 0.35))
			"tree":
				var col2: Color = Color(0.09, 0.25, 0.11).lerp(Color(0.14, 0.30, 0.12), rng.randf())
				pen.draw_circle(p + Vector2(2.4, 3.4), r, SHADOW, true, -1.0, true)
				pen.draw_circle(p, r, col2, true, -1.0, true)
				for k in 4:
					var a: float = TAU * float(k) / 4.0 + rng.randf()
					pen.draw_circle(p + Vector2(cos(a), sin(a)) * r * 0.45, r * 0.5, col2.lightened(0.05), true, -1.0, true)
				pen.draw_circle(p - Vector2(r * 0.3, r * 0.35), r * 0.38, col2.lightened(0.13), true, -1.0, true)
			"pond":
				var shore: PackedVector2Array = _blob(p, r + 1.6, rng, 0.66)
				pen.draw_colored_polygon(shore, Color(0.32, 0.33, 0.27, 0.8))
				pen.draw_colored_polygon(_blob(p, r, rng, 0.66), Color(0.14, 0.27, 0.32))
				pen.draw_arc(p - Vector2(r * 0.2, r * 0.15), r * 0.45, PI * 1.1, PI * 1.6, 8, Color(0.55, 0.70, 0.75, 0.45), 1.0, true)
				for k in 3:
					var rx: Vector2 = p + Vector2(r * rng.randf_range(0.6, 0.9), r * rng.randf_range(-0.3, 0.3) * 0.66)
					pen.draw_line(rx, rx - Vector2(rng.randf_range(-1, 1), 3.5), Color(0.20, 0.32, 0.14), 0.9, true)
			"house":
				var hs: Vector2 = Vector2(14, 11)
				var h: Rect2 = Rect2(p - hs * 0.5, hs)
				var roof: Color = Color(0.45, 0.28, 0.22).lerp(Color(0.38, 0.36, 0.36), rng.randf())
				pen.draw_rect(Rect2(h.position + Vector2(2.0, 2.6), h.size), SHADOW)
				pen.draw_rect(h, roof.darkened(0.2))
				pen.draw_rect(Rect2(h.position, Vector2(h.size.x, h.size.y * 0.5)), roof)
				pen.draw_line(Vector2(h.position.x, h.get_center().y), Vector2(h.end.x, h.get_center().y), roof.lightened(0.15), 1.0)
		pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
