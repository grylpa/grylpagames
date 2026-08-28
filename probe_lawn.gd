extends Node

# TEMPORARY PROBE — delete after use.
#
# The continuous lawn (scripts/grass_field.gd) replaced the per-cell grass tile in all twelve
# grass games. For each one this checks that:
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
	{"g": "pop", "layer": ".", "rect": "TextureRect"},
	{"g": "taxi", "layer": ".", "rect": "TextureRect"},
	{"g": "wolves", "layer": ".", "rect": "TextureRect"},
]

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
	print("")
	if _fails.is_empty():
		print("PROBE OK (%d games)" % GAMES.size())
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
