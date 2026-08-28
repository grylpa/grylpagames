extends Node

# TEMPORARY PROBE — delete after use.
#
# The two grounds. Eleven games have the continuous lawn (scripts/grass_field.gd) in place of the
# per-cell grass tile; four have no world in them at all and get a plain backdrop instead
# (scripts/study_backdrop.gd). For each of the eleven this checks that:
#
#   * a GrassField exists and is the FIRST child of the layer it was attached to, so it is behind
#     the board rather than over it;
#   * it is sown BEFORE any board is built — the "solid color background at first" complaint;
#   * it covers the board with a margin on every side;
#   * the tiled TextureRect it replaced is hidden once the field has a size, and still SHOWING
#     while the field has none (a bare screen is worse than a tiled one);
#   * no cell still carries a visible grass sprite.

const GAMES: Array = [
	{"g": "mmm", "layer": "BgLayer", "rect": "BgLayer/TextureRect"},
	{"g": "delemfp", "layer": "BgLayer", "rect": "BgLayer/TextureRect"},
	{"g": "storm", "layer": "BgLayer", "rect": "BgLayer/TextureRect"},
	{"g": "gorilla", "layer": "BgLayer", "rect": "BgLayer/BackgroundRect"},
	{"g": "deliverem", "layer": ".", "rect": "TextureRect"},
	{"g": "guidem", "layer": ".", "rect": "TextureRect"},
	{"g": "lightsout", "layer": ".", "rect": "TextureRect"},
	{"g": "parkem", "layer": ".", "rect": "TextureRect"},
	{"g": "pneumo", "layer": ".", "rect": "TextureRect"},
	{"g": "taxi", "layer": ".", "rect": "TextureRect"},
	{"g": "wolves", "layer": ".", "rect": "TextureRect"},
]

# The games with no ground: a shape flashes and you answer. Same checks, different node, plus the
# one thing that is a GAMEPLAY constraint rather than a look — the backdrop must not be brighter in
# one direction than another. Pinpoint asks which of eight directions a dot flashed in.
const BACKDROP_GAMES: Array = ["ddooo", "didi", "ooo", "pop"]

var _fails: Array = []
var _cur: String = ""

func _fail(m: String) -> void:
	_fails.append("[%s] %s" % [_cur, m])

func _ready() -> void:
	var canvas: Vector2 = Vector2(680, 1200) if OS.get_environment("PROBE_MOBILE") == "1" else Vector2(680, 788)
	MainGlobals.force_mobile = OS.get_environment("PROBE_MOBILE") == "1"
	MainGlobals.init_globals(canvas)
	print("canvas ", canvas)
	for spec: Dictionary in GAMES:
		await _run(spec)
	_check_backdrop_uniformity()
	for folder: String in BACKDROP_GAMES:
		await _run_backdrop(folder)
	await _check_glimpse_boxes()
	print("")
	if _fails.is_empty():
		print("PROBE OK (%d lawns, %d backdrops)" % [GAMES.size(), BACKDROP_GAMES.size()])
	else:
		for f: String in _fails:
			print("PROBE FAIL ", f)
	get_tree().quit()

func _run(spec: Dictionary) -> void:
	_cur = String(spec["g"])
	var main: Node = load("res://%s/scenes/main.tscn" % _cur).instantiate()
	add_child(main)
	for _i in 8:
		await get_tree().process_frame
	var level: Node = main.get_node_or_null("Level")
	var game: GenericGameUtil = main.get("game")
	if level == null or game == null:
		_fail("could not reach the level")
		main.queue_free()
		return

	# --- before any board: the field, or failing that the tile it replaces ------------------------
	var layer: Node = level if String(spec["layer"]) == "." else level.get_node(String(spec["layer"]))
	var rect: CanvasItem = level.get_node_or_null(String(spec["rect"])) as CanvasItem
	var field: Control = layer.get_node_or_null("GrassField") as Control
	if field == null:
		_fail("no GrassField after _ready")
	else:
		if layer.get_child(0) != field:
			_fail("the field is child %d of %s, not the first, so it draws OVER the board"
				% [field.get_index(), spec["layer"]])
		var blades: MultiMeshInstance2D = field.get_node_or_null("Blades") as MultiMeshInstance2D
		var n: int = 0 if blades == null or blades.multimesh == null else blades.multimesh.instance_count
		var sown_early: bool = n > 0
		print("  %-10s before board: %8.0f x %-8.0f %7d blades  tile_visible=%s"
			% [_cur, field.size.x, field.size.y, n, "yes" if rect != null and rect.visible else "no"])
		if not sown_early:
			_fail("nothing sown in _ready, so the first thing shown is a bare background")
		if rect != null and rect.visible and sown_early:
			_fail("the tiled ground is still showing over/under a sown field")
		if rect != null and not rect.visible and not sown_early:
			_fail("the tiled ground was hidden before the field had anything in it")

	# --- build a board and re-measure -------------------------------------------------------------
	game.tutorial_mode = false
	if level.get("_tutorial_board") != null:
		level.set("_tutorial_board", false)
	level.call("new_game", false)
	for _i in 10:
		await get_tree().process_frame
	field = layer.get_node_or_null("GrassField") as Control
	if field == null:
		_fail("the field is gone after a board was built")
	else:
		var blades: MultiMeshInstance2D = field.get_node_or_null("Blades") as MultiMeshInstance2D
		var n: int = 0 if blades == null or blades.multimesh == null else blades.multimesh.instance_count
		var tl: Vector2 = game.board_to_px(Vector2i(0, 0))
		var br: Vector2 = game.board_to_px(game.board_size)
		print("  %-10s after  board: %8.0f x %-8.0f %7d blades  board %s..%s"
			% [_cur, field.size.x, field.size.y, n, tl, br])
		if n < 1000:
			_fail("only %d blades after the board was built" % n)
		if field.position.x > tl.x or field.position.y > tl.y:
			_fail("the field starts inside the board, so the top/left runs out of grass")
		if field.position.x + field.size.x < br.x or field.position.y + field.size.y < br.y:
			_fail("the field ends inside the board, so the bottom/right runs out of grass")
		if rect != null and rect.visible:
			_fail("the tiled ground is still visible with a board on screen")
		# The tile it replaced was anchored to the whole canvas, so the field must be too — otherwise
		# there is a bare band where the board stops short of the screen.
		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size))
		if not Rect2(field.position, field.size).encloses(screen):
			_fail("the field %s does not cover the canvas %s" % [Rect2(field.position, field.size), screen])

	# --- and no cell brought its own tile back ----------------------------------------------------
	var showing: int = 0
	var cells: int = 0
	for n2 in _all(level):
		if n2 is Area2D and n2.has_method("show_hide_walls"):
			cells += 1
			var gr: CanvasItem = n2.get_node_or_null("Grass") as CanvasItem
			if gr != null and gr.visible:
				showing += 1
	if cells > 0 and showing > 0:
		_fail("%d of %d cells still show their own grass tile" % [showing, cells])
	elif cells == 0:
		print("  %-10s (no cells on the board to check)" % _cur)

	main.queue_free()
	for _i in 4:
		await get_tree().process_frame

func _all(n: Node) -> Array:
	var out: Array = []
	if n == null or not is_instance_valid(n):
		return out
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


# The backdrop's ONLY large-scale variation is a lift toward the centre. Read the mesh it actually
# builds and assert it is a fan whose brightness depends on radius alone: every rim vertex the same
# colour, and the centre lift small. A vignette or a vertical gradient would fail here, which is the
# point — Pinpoint's eight directions have to be equally hard to read.
func _check_backdrop_uniformity() -> void:
	_cur = "backdrop"
	if StudyBackdrop.LIFT_ALPHA > 0.06:
		_fail("the centre lift is %.3f alpha; anything you can see is enough to bias a direction"
			% StudyBackdrop.LIFT_ALPHA)
	if StudyBackdrop.DUST_HI_ALPHA > 0.12:
		_fail("the dust is %.3f alpha, which is a pattern rather than a surface"
			% StudyBackdrop.DUST_HI_ALPHA)
	var lift_mesh: ArrayMesh = StudyBackdrop._lift_mesh(Vector2(600, 900), StudyBackdrop.PINPOINT)
	var arrays: Array = lift_mesh.surface_get_arrays(0)
	var verts: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if verts.size() != cols.size() or verts.is_empty():
		_fail("the lift mesh carries no per-vertex colour, so its shape cannot be checked")
		return
	var center: Vector2 = Vector2(300, 450)
	var rim: Array = []
	for i in verts.size():
		if verts[i].distance_to(center) < 1.0:
			# ArrayMesh stores ARRAY_COLOR at 8 bits per channel, so the declared alpha comes back
			# quantised (0.05 -> 12/255 = 0.047). One step of tolerance, not exact equality.
			if absf(cols[i].a - StudyBackdrop.LIFT_ALPHA) > 1.0 / 255.0:
				_fail("a centre vertex is %.3f alpha, not the declared %.3f"
					% [cols[i].a, StudyBackdrop.LIFT_ALPHA])
		else:
			rim.append(cols[i])
	if rim.is_empty():
		_fail("the lift mesh has no rim vertices")
		return
	for c: Color in rim:
		if c != rim[0]:
			_fail("rim vertices differ (%s vs %s), so the backdrop is brighter in some directions"
				% [str(rim[0]), str(c)])
			break
	# And the four games must not have quietly drifted to four different-looking screens.
	for pair: Array in [["WITNESS", StudyBackdrop.WITNESS], ["PINPOINT", StudyBackdrop.PINPOINT],
			["LINEUP", StudyBackdrop.LINEUP], ["GLIMPSE", StudyBackdrop.GLIMPSE]]:
		var col: Color = pair[1]
		var lum: float = col.get_luminance()
		if lum > 0.14:
			_fail("%s is too light (%.3f luminance) for a coloured shape to stand out against"
				% [pair[0], lum])

func _run_backdrop(folder: String) -> void:
	_cur = folder
	var main: Node = load("res://%s/scenes/main.tscn" % folder).instantiate()
	add_child(main)
	for _i in 8:
		await get_tree().process_frame
	var level: Node = main.get_node_or_null("Level")
	var game: GenericGameUtil = main.get("game")
	if level == null or game == null:
		_fail("could not reach the level")
		main.queue_free()
		return
	var rect: CanvasItem = level.get_node_or_null("TextureRect") as CanvasItem
	var bg: Control = level.get_node_or_null("StudyBackdrop") as Control

	if bg == null:
		_fail("no StudyBackdrop after _ready")
	else:
		if level.get_child(0) != bg:
			_fail("the backdrop is child %d of the Level, not the first, so it draws OVER the board"
				% bg.get_index())
		var dust: MultiMeshInstance2D = bg.get_node_or_null("Dust") as MultiMeshInstance2D
		var n: int = 0 if dust == null or dust.multimesh == null else dust.multimesh.instance_count
		# Ink, the number the lawn was got wrong on four times: count alone says nothing, coverage is
		# count x speck area. A speck is DUST_SIZE^2 scaled by s in [0.6, 1.5], so E[area] is
		# DUST_SIZE^2 * (1.5^3 - 0.6^3) / (3 * 0.9).
		var speck_area: float = StudyBackdrop.DUST_SIZE * StudyBackdrop.DUST_SIZE \
			* (pow(1.5, 3.0) - pow(0.6, 3.0)) / 2.7
		var ink: float = float(n) * speck_area / maxf(bg.size.x * bg.size.y, 1.0)
		print("  %-8s before board: %8.0f x %-8.0f %7d specks %3.0f%% ink  tile_visible=%s"
			% [folder, bg.size.x, bg.size.y, n, ink * 100.0,
			"yes" if rect != null and rect.visible else "no"])
		if ink < 0.10:
			_fail("the dust is %.0f%% ink, which is a flat fill with a rash on it" % (ink * 100.0))
		if n <= 0:
			_fail("nothing drawn in _ready, so the first thing shown is a bare background")
		if rect != null and rect.visible and n > 0:
			_fail("the grass TextureRect is still showing behind a populated backdrop")

	game.tutorial_mode = false
	level.call("new_game", false)
	for _i in 10:
		await get_tree().process_frame
	bg = level.get_node_or_null("StudyBackdrop") as Control
	if bg == null:
		_fail("the backdrop is gone after a board was built")
	else:
		var tl: Vector2 = game.board_to_px(Vector2i(0, 0))
		var br: Vector2 = game.board_to_px(game.board_size)
		var area: Rect2 = Rect2(bg.position, bg.size)
		print("  %-8s after  board: %8.0f x %-8.0f board %s..%s" % [folder, bg.size.x, bg.size.y, tl, br])
		if area.position.x > tl.x or area.position.y > tl.y \
				or area.end.x < br.x or area.end.y < br.y:
			_fail("the backdrop %s does not cover the board %s..%s" % [area, tl, br])
		if not area.encloses(Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size))):
			_fail("the backdrop %s does not cover the canvas %s"
				% [area, Vector2(MainGlobals.full_screen_size)])
		if rect != null and rect.visible:
			_fail("the grass TextureRect is still visible with a board on screen")

	# pop is the only one of the four with board cells; its grass must stay hidden too.
	var showing: int = 0
	for n2 in _all(level):
		if n2 is Area2D and n2.has_method("show_hide_walls"):
			var gr: CanvasItem = n2.get_node_or_null("Grass") as CanvasItem
			if gr != null and gr.visible:
				showing += 1
	if showing > 0:
		_fail("%d cells still show a grass tile over the backdrop" % showing)

	main.queue_free()
	for _i in 4:
		await get_tree().process_frame


# Glimpse has no board at all any more — no road pipes, no floored cells. A shape stands on a single
# box, and the box exists EXACTLY as long as the shape does. Both halves matter: a box that outlives
# its shape leaves the player a marker for a question that is over, and a box that never appears
# leaves a shape floating.
#
# Driven by calling the dispatch and removal directly rather than by waiting on game_time, so the
# invariant is checked at the moment it has to hold rather than whenever the clock got there.
func _check_glimpse_boxes() -> void:
	_cur = "pop boxes"
	var main: Node = load("res://pop/scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 8:
		await get_tree().process_frame
	var level: Node = main.get_node_or_null("Level")
	var game: GenericGameUtil = main.get("game")
	if level == null or game == null:
		_fail("could not reach the level")
		main.queue_free()
		return
	game.tutorial_mode = false
	level.set("tutorial_hold_board", true)   # nothing dispatches or times out behind our back
	level.call("new_game", false)
	for _i in 6:
		await get_tree().process_frame

	# Nothing of the old board survives.
	for n in _all(level):
		if n.has_method("show_hide_walls") or n.has_method("set_rot"):
			_fail("a board cell or road pipe is still being built (%s)" % n.get_class())
			break
	if _boxes(level) != 0:
		_fail("%d boxes on an empty board" % _boxes(level))

	# _dispatch_new_agent() does nothing while the game reads as paused, and a probe tree has no
	# screen up and never started playing.
	game.playing = true
	game._pause = false
	game.in_focus = true
	MainGlobals.visible_screens.clear()

	# A shape appears -> exactly one box, on that shape's own cell.
	level.call("_dispatch_new_agent", true, false)
	for _i in 2:
		await get_tree().process_frame
	var agents: Array = level.get("agents")
	if agents.size() != 1:
		_fail("dispatching the model produced %d shapes" % agents.size())
		main.queue_free()
		return
	print("  pop boxes: 1 shape -> %d box(es)" % _boxes(level))
	if _boxes(level) != 1:
		_fail("one shape on screen but %d boxes" % _boxes(level))
	var cell = level.get("board")[agents[0].board_pos.y][agents[0].board_pos.x]
	if cell.box == null or not is_instance_valid(cell.box):
		_fail("the shape's own cell has no box, so the box is somewhere else")
	elif not cell.box.position.is_equal_approx(game.board_to_px(agents[0].board_pos)):
		_fail("the box is at %s, the shape's cell is at %s"
			% [cell.box.position, game.board_to_px(agents[0].board_pos)])
	elif cell.box.z_index >= 10:
		_fail("the box is at z_index %d, at or above the shape's 10, so it covers it" % cell.box.z_index)
	if cell.box is Area2D or cell.box.has_signal("pipe_pressed"):
		_fail("the box is tappable, so it can swallow the tap meant for the shape")

	# A lineup: one box per shape, no more.
	level.call("_dispatch_new_agent", false, true)
	level.call("_dispatch_new_agent", false, false)
	for _i in 2:
		await get_tree().process_frame
	agents = level.get("agents")
	print("  pop boxes: %d shapes -> %d box(es)" % [agents.size(), _boxes(level)])
	if _boxes(level) != agents.size():
		_fail("%d shapes on screen but %d boxes" % [agents.size(), _boxes(level)])

	# ...and the shapes go, and the boxes go with them.
	var guard: int = 0
	while level.get("agents").size() > 0 and guard < 50:
		level.call("on_agent_need_to_remove_agent", level.get("agents")[0])
		guard += 1
	for _i in 4:
		await get_tree().process_frame
	print("  pop boxes: 0 shapes -> %d box(es)" % _boxes(level))
	if _boxes(level) != 0:
		_fail("the shapes are gone but %d boxes are still on screen" % _boxes(level))

	main.queue_free()
	for _i in 4:
		await get_tree().process_frame

# The boxes are the Level's own Sprite2D children; the backdrop is a Control and the shapes are
# Area2D, so nothing else is counted. queue_free() is deferred, so freeing ones are skipped.
func _boxes(level: Node) -> int:
	var n: int = 0
	for c in level.get_children():
		if c is Sprite2D and not c.is_queued_for_deletion():
			n += 1
	return n
