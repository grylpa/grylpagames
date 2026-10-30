class_name TaxiCitySurround
extends RefCounted

# ROUND TAXI'S BOARD (2026-10-30): a city SIDEWALK instead of lawn -- pale paving slabs in
# staggered rows, in warm terracotta and sandstone (a cool gray one read as cold and uninviting;
# street trees in the pockets distracted and were dropped). (A city of rooftops round the
# board was tried and dropped: the board fills the screen, so it only showed below the button bar.)
# Drawn by one Node2D under the GrassField, which it covers.

# The look round the square: "night" (the current try) or "paving" (warm terracotta, an option).
const STYLE: String = "night"
const PAVE: Color = Color(0.72, 0.56, 0.42) if STYLE == "paving" else Color(0.13, 0.12, 0.15)
const JOINT: Color = Color(0.58, 0.44, 0.33) if STYLE == "paving" else Color(0.09, 0.085, 0.10)
const SLAB: Vector2 = Vector2(26.0, 16.0)

static func build(level: Node, board: Array, _game) -> void:
	var field: Control = level.find_child("GrassField", true, false) as Control
	if field == null or board.is_empty():
		return
	var pen: Node2D = field.get_node_or_null("City") as Node2D
	if pen == null:
		pen = Node2D.new()
		pen.name = "City"
		field.add_child(pen)
		pen.draw.connect(func() -> void: _draw(pen))
	pen.set_meta("size", field.size)
	pen.queue_redraw()


static func _draw(pen: Node2D) -> void:
	var area: Vector2 = pen.get_meta("size", Vector2.ZERO)
	pen.draw_rect(Rect2(Vector2.ZERO, area), PAVE)
	# staggered slabs, each a touch lighter or darker
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var row: int = 0
	var y: float = 0.0
	while y < area.y:
		var x: float = -SLAB.x * 0.5 * float(row % 2)
		while x < area.x:
			var k: float = rng.randf_range(-0.035, 0.035)
			var sandy: float = rng.randf() * 0.35
			var tone: Color = PAVE.lerp(Color(0.78, 0.68, 0.52) if STYLE == "paving" else Color(0.16, 0.15, 0.18), sandy)
			pen.draw_rect(Rect2(x + 0.6, y + 0.6, SLAB.x - 1.2, SLAB.y - 1.2), Color(tone.r + k, tone.g + k, tone.b + k))
			x += SLAB.x
		pen.draw_line(Vector2(0, y), Vector2(area.x, y), JOINT, 1.0)
		y += SLAB.y
		row += 1


# NIGHT: shop-light pools spilling onto the square from the sidewalk round it -- soft radial glows in
# amber, magenta and cyan at irregular spots along the edge, ADDED to what is under them (so they
# light the sidewalk rather than paint over it), drawn under the street. Static.
static func build_night(level: Node, board: Array, game) -> void:
	var old: Node = level.find_child("NightGlow", true, false)
	if old != null:
		old.free()
	if STYLE != "night" or board.is_empty():
		return
	# on the SIDEWALK only: a child of the sidewalk's drawing, under the street, so the light pools
	# never wash over the board (on top, at z 5, they read as a haze over the whole screen)
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
	var tl: Vector2 = game.board_to_px(Vector2i(0, 0)) - Vector2(tile, tile) * 0.5
	var size_px: Vector2 = Vector2(board[0].size(), board.size()) * tile
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31337 + board.size()
	var cols: Array = [Color(1.0, 0.62, 0.22), Color(0.95, 0.25, 0.65), Color(0.20, 0.75, 0.95), Color(1.0, 0.80, 0.40)]
	var glows: Array = []
	var perim: float = (size_px.x + size_px.y) * 2.0
	var t: float = rng.randf_range(0.0, 120.0)
	while t < perim:
		var p: Vector2
		if t < size_px.x:
			p = tl + Vector2(t, 0)
		elif t < size_px.x + size_px.y:
			p = tl + Vector2(size_px.x, t - size_px.x)
		elif t < size_px.x * 2.0 + size_px.y:
			p = tl + Vector2(size_px.x - (t - size_px.x - size_px.y), size_px.y)
		else:
			p = tl + Vector2(0, size_px.y - (t - size_px.x * 2.0 - size_px.y))
		glows.append([p, rng.randf_range(70.0, 130.0), cols[rng.randi() % cols.size()]])
		t += rng.randf_range(110.0, 220.0)
	var tex: Texture2D = MainGlobals.menu_glow_texture()
	pen.draw.connect(func() -> void:
		for g in glows:
			var rad: float = g[1]
			pen.draw_texture_rect(tex, Rect2(Vector2(g[0]) - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false,
				Color(Color(g[2]), 0.42)))
	pen.queue_redraw()
