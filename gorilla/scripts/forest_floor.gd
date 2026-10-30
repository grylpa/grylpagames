extends RefCounted

# GORILLA'S RAINFOREST FLOOR (2026-10-30), laid over the shared lawn (scripts/grass_field.gd), whose
# node, size and sowing stay as they are -- only its blades are hidden under this:
#  - the ground itself: forest_floor.gdshader (soil, moss, leaf litter, dappled light), one rect
#    covering the field
#  - a few FERNS, sparse, at random spots on the ground outside the room (never per cell, never on the
#    room's floor), small enough to sit inside a cell's worth of space
#  - big TROPICAL LEAVES overhanging from outside the board, only beyond its edge, so nothing the
#    player watches is covered
# Everything here is a child of the GrassField, so it is behind the board and follows the camera.

const FLOOR_SHADER: Shader = preload("res://gorilla/scripts/forest_floor.gdshader")
const FERN_DENSITY: float = 0.07        # ferns tried per free cell
const LEAF_DENSITY: float = 0.035       # big fallen leaves tried per free cell
const SHADOW: Color = Color(0, 0, 0, 0.28)

# The ground: after GrassField.fit, every time it runs.
static func lay(bg_layer: Node, seed_i: int) -> void:
	var field: Control = bg_layer.get_node_or_null("GrassField") as Control if bg_layer != null else null
	if field == null:
		return
	var blades: CanvasItem = field.get_node_or_null("Blades") as CanvasItem
	if blades != null:
		blades.visible = false
	var ground: ColorRect = field.get_node_or_null("Forest") as ColorRect
	if ground == null:
		ground = ColorRect.new()
		ground.name = "Forest"
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = FLOOR_SHADER
		mat.set_shader_parameter("seed", float(seed_i))
		ground.material = mat
		field.add_child(ground)
	ground.position = Vector2.ZERO
	ground.size = field.size


# The plants: once the board is built (they keep off the room and the board's edge).
static func plant(bg_layer: Node, board: Array, game, seed_i: int) -> void:
	var field: Control = bg_layer.get_node_or_null("GrassField") as Control if bg_layer != null else null
	if field == null or board.is_empty():
		return
	var pen: Node2D = field.get_node_or_null("Plants") as Node2D
	if pen == null:
		pen = Node2D.new()
		pen.name = "Plants"
		field.add_child(pen)
		pen.draw.connect(func() -> void: _draw_plants(pen))
	var tile: float = float(game.tile_size)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x51ed27 + seed_i * 977 + board.size() * 31
	var ferns: Array = []
	var fallen: Array = []
	for y in board.size():
		for x in board[y].size():
			var cell = board[y][x]
			if cell == null or cell.ispipe or not _clear_of_room(board, x, y):
				continue
			var roll: float = rng.randf()
			var c: Vector2 = game.board_to_px(Vector2i(x, y)) - field.position \
				+ Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * tile
			if roll < FERN_DENSITY:
				ferns.append([c, tile * rng.randf_range(0.45, 0.62), rng.randf() * TAU, rng.randi()])
			elif roll < FERN_DENSITY + LEAF_DENSITY:
				fallen.append([c - Vector2.from_angle(rng.randf() * TAU) * tile * 0.3, tile * rng.randf_range(0.7, 0.95),
					rng.randf() * TAU, rng.randi()])
	# overhanging leaves: along the field's outer band, outside the board's rect
	var tl: Vector2 = game.board_to_px(Vector2i(0, 0)) - Vector2(tile, tile) * 0.5 - field.position
	var br: Vector2 = game.board_to_px(game.board_size) - Vector2(tile, tile) * 0.5 - field.position
	var leaves: Array = []
	var area: Vector2 = field.size
	for k in 26:
		var p: Vector2 = Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var inside: bool = p.x > tl.x - tile * 0.6 and p.y > tl.y - tile * 0.6 and p.x < br.x + tile * 0.6 and p.y < br.y + tile * 0.6
		if inside:
			continue
		# point the leaf toward the board, so it reaches in from outside
		var to_board: Vector2 = ((tl + br) * 0.5 - p).normalized()
		leaves.append([p, tile * rng.randf_range(0.9, 1.5), to_board.angle() + rng.randf_range(-0.6, 0.6), rng.randi()])
	pen.set_meta("ferns", ferns)
	pen.set_meta("fallen", fallen)
	pen.set_meta("leaves", leaves)
	pen.set_meta("board_rect", Rect2(tl, br - tl))
	pen.queue_redraw()


# A ground cell next to the room's floor stays bare, so nothing sits against the room.
static func _clear_of_room(board: Array, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var yy: int = y + dy
			var xx: int = x + dx
			if yy >= 0 and yy < board.size() and xx >= 0 and xx < board[yy].size():
				var c = board[yy][xx]
				if c != null and c.ispipe:
					return false
	return true


static func _draw_plants(pen: Node2D) -> void:
	for fl in pen.get_meta("fallen", []):
		_draw_big_leaf(pen, fl[0], fl[1], fl[2], int(fl[3]), Rect2(), true)
	for f in pen.get_meta("ferns", []):
		_draw_fern(pen, f[0], f[1], f[2], int(f[3]))
	var r: Rect2 = pen.get_meta("board_rect", Rect2())
	for l in pen.get_meta("leaves", []):
		_draw_big_leaf(pen, l[0], l[1], l[2], int(l[3]), r)


# A fern from above: five to seven fronds from one root, each a stem with small leaflets along it.
static func _draw_fern(pen: Node2D, at: Vector2, rad: float, turn: float, sd: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sd
	var n: int = rng.randi_range(5, 7)
	var green: Color = Color(0.20, 0.42, 0.14).lerp(Color(0.28, 0.50, 0.16), rng.randf())
	for pass_i in 2:
		for i in n:
			var a: float = turn + TAU * float(i) / float(n) + rng.randf_range(-0.2, 0.2)
			var dir: Vector2 = Vector2.from_angle(a)
			var side: Vector2 = Vector2(-dir.y, dir.x)
			var length: float = rad * rng.randf_range(0.8, 1.05)
			var off: Vector2 = Vector2(1.2, 1.8) if pass_i == 0 else Vector2.ZERO
			var col: Color = SHADOW if pass_i == 0 else green
			pen.draw_line(at + off, at + dir * length + off, col, 1.4, true)
			for k in range(1, 7):
				var t: float = float(k) / 7.0
				var base: Vector2 = at + dir * length * t + off
				var ll: float = rad * 0.34 * (1.0 - t * 0.65)
				for sg: float in [-1.0, 1.0]:
					var tip: Vector2 = base + (side * sg + dir * 0.5).normalized() * ll
					pen.draw_colored_polygon(PackedVector2Array([base - dir * ll * 0.25, tip, base + dir * ll * 0.3]),
						col if pass_i == 0 else col.lightened(0.06 * float(k % 2)))


# A broad tropical leaf, its stalk from outside: a pointed oval with a midrib and side veins, a soft
# shadow under it; clipped to stay out of the board's rect.
# `fallen`: lying flat on the ground -- browner, a softer, closer shadow, and allowed anywhere.
static func _draw_big_leaf(pen: Node2D, at: Vector2, length: float, ang: float, sd: int, board: Rect2,
		fallen: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sd
	var dir: Vector2 = Vector2.from_angle(ang)
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var width: float = length * rng.randf_range(0.34, 0.44)
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 16
	for i in n + 1:
		var t: float = float(i) / float(n)
		pts.append(at + dir * length * t + side * width * pow(sin(PI * t), 0.8) * (1.0 - 0.25 * t))
	for i in range(n - 1, 0, -1):
		var t2: float = float(i) / float(n)
		pts.append(at + dir * length * t2 - side * width * pow(sin(PI * t2), 0.8) * (1.0 - 0.25 * t2))
	# keep the board clear: a leaf any point of which would reach into it is not drawn
	if not fallen:
		for p: Vector2 in pts:
			if board.grow(-2.0).has_point(p):
				return
	var drop: Vector2 = Vector2(1.2, 1.8) if fallen else Vector2(3.0, 5.0)
	var shadow: PackedVector2Array = PackedVector2Array()
	for p2: Vector2 in pts:
		shadow.append(p2 + drop)
	pen.draw_colored_polygon(shadow, Color(0, 0, 0, 0.22 if fallen else 0.30))
	var green: Color = Color(0.10, 0.30, 0.12).lerp(Color(0.16, 0.38, 0.14), rng.randf())
	if fallen:
		green = Color(0.24, 0.32, 0.12).lerp(Color(0.42, 0.30, 0.12), rng.randf())
	pen.draw_colored_polygon(pts, green)
	# the lit half
	var half: PackedVector2Array = PackedVector2Array()
	for i in n + 1:
		half.append(pts[i])
	half.append(at + dir * length)
	pen.draw_colored_polygon(half, green.lightened(0.08))
	pen.draw_line(at - dir * length * 0.15, at + dir * length * 0.96, green.lightened(0.25), 1.4, true)
	for k in range(1, 6):
		var t3: float = float(k) / 6.0
		var b: Vector2 = at + dir * length * t3
		var wv: float = width * pow(sin(PI * t3), 0.8) * 0.85
		for sg: float in [-1.0, 1.0]:
			pen.draw_line(b, b + (side * sg * 0.9 + dir * 0.45).normalized() * wv, green.lightened(0.15), 0.8, true)
