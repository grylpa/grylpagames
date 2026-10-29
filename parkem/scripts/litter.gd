class_name ParkemLitter
extends RefCounted

# Detour's courtyard litter: a few fallen leaves and small weed tufts lying about on the paving, at
# random spots (never per cell), clear of bricks, docks and the doors' junctions. Sparse and small.
# One Node2D added to the level after the floor, so it is above the paving and under everything else.

static func scatter(level: Node, board: Array, game, pipes: Array) -> void:
	var pen: Node2D = level.get_node_or_null("Litter") as Node2D
	if pen == null:
		pen = Node2D.new()
		pen.name = "Litter"
		pen.draw.connect(func() -> void: _draw(pen))
		level.add_child(pen)
	# just above the paving: after the last floor tile, before the doors and creatures
	if not pipes.is_empty():
		level.move_child(pen, (pipes[-1] as Node).get_index() + 1)
	var tile: float = float(game.tile_size)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x2545F491 + board.size() * 97
	var items: Array = []
	for pipe in pipes:
		if pipe.get("blocked") or rng.randf() > 0.30:
			continue
		var bp: Vector2i = pipe.board_pos
		if board[bp.y][bp.x].door_type >= 0 or board[bp.y][bp.x].istarget:
			continue
		var p: Vector2 = pipe.position + Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.42, 0.42)) * tile
		items.append({"p": p, "kind": "weed" if rng.randf() < 0.35 else "leaf", "seed": rng.randi()})
	# ROUND THE COURTYARD: the grass pockets between its bays and the strip along its edge get
	# shrubs and ferns hugging the paving -- some pockets left bare, each clump its own size and
	# placed off-center, so the edge looks overgrown, not patterned
	for y in board.size():
		for x in board[y].size():
			var cell = board[y][x]
			if cell.ispipe or cell.istarget:
				continue
			var touches: bool = false
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x].ispipe:
					touches = true
			if not touches or rng.randf() > 0.55:
				continue
			var c: Vector2 = game.board_to_px(Vector2i(x, y)) + Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22)) * tile
			items.append({"p": c, "kind": "fern" if rng.randf() < 0.3 else "shrub", "seed": rng.randi()})
	pen.set_meta("items", items)
	pen.queue_redraw()


static func _draw(pen: Node2D) -> void:
	for it in pen.get_meta("items", []):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(it["seed"])
		var p: Vector2 = it["p"]
		if it["kind"] == "shrub":
			var base: Color = Color(0.11, 0.30, 0.13).lerp(Color(0.16, 0.34, 0.12), rng.randf())
			var n_b: int = rng.randi_range(2, 4)
			var offs: Array = []
			for k in n_b:
				offs.append(Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5)))
			for o: Vector2 in offs:
				pen.draw_circle(p + o + Vector2(1.6, 2.2), 6.0, Color(0, 0, 0, 0.25), true, -1.0, true)
			for o: Vector2 in offs:
				var br: float = rng.randf_range(4.5, 7.5)
				pen.draw_circle(p + o, br, base, true, -1.0, true)
				pen.draw_circle(p + o - Vector2(1.3, 1.5), br * 0.6, base.lightened(0.12), true, -1.0, true)
			continue
		if it["kind"] == "fern":
			for k in 7:
				var a2: float = TAU * float(k) / 7.0 + rng.randf() * 0.4
				var tip: Vector2 = p + Vector2(cos(a2), sin(a2)) * rng.randf_range(7.0, 10.0)
				pen.draw_line(p, tip, Color(0.20, 0.40, 0.16), 2.2, true)
				pen.draw_line(p, tip, Color(0.30, 0.52, 0.22), 1.0, true)
			continue
		if it["kind"] == "leaf":
			var cols: Array = [Color(0.62, 0.36, 0.14), Color(0.70, 0.52, 0.18), Color(0.48, 0.30, 0.16)]
			var col: Color = cols[rng.randi() % cols.size()]
			var ang: float = rng.randf() * TAU
			var d: Vector2 = Vector2(cos(ang), sin(ang))
			var n: Vector2 = Vector2(-d.y, d.x)
			var L: float = rng.randf_range(5.5, 7.5)
			var leaf: PackedVector2Array = PackedVector2Array([p - d * L, p + n * L * 0.45, p + d * L, p - n * L * 0.45])
			var sh: PackedVector2Array = PackedVector2Array()
			for q: Vector2 in leaf:
				sh.append(q + Vector2(0.6, 0.9))
			pen.draw_colored_polygon(sh, Color(0, 0, 0, 0.22))
			pen.draw_colored_polygon(leaf, col)
			pen.draw_line(p - d * L * 0.9, p + d * L * 0.9, col.darkened(0.3), 0.9, true)
		else:
			for k in rng.randi_range(3, 5):
				var a: float = -PI * 0.5 + rng.randf_range(-0.9, 0.9)
				var l2: float = rng.randf_range(4.5, 7.5)
				pen.draw_line(p, p + Vector2(cos(a), sin(a)) * l2, Color(0.28, 0.42, 0.18), 1.4, true)
