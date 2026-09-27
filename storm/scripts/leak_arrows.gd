class_name StormLeakArrows
extends CanvasLayer

# A CLUE FOR EVERY NEW LEAK YOU CANNOT SEE. With several rooms, a leak can start anywhere in the
# mansion while the camera shows only the player's room. For each new one this draws a blue arrow near
# the edge of the screen, pointing at it: on the line from the player to the leak, where that line
# meets the screen's edge (inset from it, and kept clear of the HUD strip at the top and the button
# bar at the bottom). While it is up it follows as the player moves. It goes after the level's
# `arrow_ms` (StormLevelConfig; negative: it never times out), or once its leak is on screen or a tool
# is catching it -- and a NEW leak out of view replaces it, so there is only ever one arrow: several
# at once, each pointing somewhere else, would say nothing. A new leak already on screen needs no
# arrow and leaves the current one alone. A one-room level has no arrows: all of it is always in view.
#
# Screen positions come from each node's canvas transform (the level's layer follows the camera), so
# the arrows are in screen space and never need to know the camera's zoom.

# A WHOLE ARROW -- shaft and head -- and outlined so it reads on any floor, lawn or water: blue inside a
# white rim inside a dark one, over a soft glow. It was a 26-unit arrowhead with a thin dark outline
# that vanished against the dark ground, and was easy to miss.
const COLOR: Color = Color(0.16, 0.50, 1.0, 1.0)
const RIM: Color = Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE: Color = Color(0.02, 0.05, 0.14, 1.0)
const GLOW: Color = Color(0.35, 0.65, 1.0, 0.28)
const SIZE: float = 66.0            # arrow length, tip to tail, screen units
const HEAD_LEN: float = 0.45        # of SIZE
const HEAD_HALF: float = 0.36       # half the head's width, of SIZE
const SHAFT_HALF: float = 0.13      # half the shaft's width, of SIZE
const OUTLINE_W: float = 5.0        # how far the dark edge reaches past the arrow, screen units
const RIM_W: float = 2.5            # the white rim, inside that
const NUDGE: float = 7.0            # how far it bobs toward the leak, screen units
const INSET: float = 30.0           # from the side edges
const TOP_CLEAR: float = 60.0 + 30.0        # the HUD strip, then the inset
const BOTTOM_CLEAR_DESKTOP: float = 44.0 + 30.0
const BOTTOM_CLEAR_MOBILE: float = 70.0 + 30.0

var _leaks: Array = []              # the pipe whose arrow is up (one at most)
var _born_ms: float = 0.0           # game time the arrow went up
var _life_ms: float = -1.0          # how long it stays up; negative: until found or caught
var _player: Node2D = null
var _draw_node: Node2D = null

func _ready() -> void:
	layer = 5
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_arrows)
	add_child(_draw_node)

func set_player(p: Node2D) -> void:
	_player = p

# A leak has just started. Out of view, it gets the arrow -- the only one -- for `life_ms`.
func track(pipe: Node2D, life_ms: float = 2000.0) -> void:
	if _inner_rect().has_point(_on_screen(pipe)):
		return
	_leaks = [pipe]
	_born_ms = _now()
	_life_ms = life_ms

func _now() -> float:
	return StormG.game.game_time if StormG.game != null else float(Time.get_ticks_msec())

func clear() -> void:
	_leaks.clear()
	_player = null
	_draw_node.queue_redraw()

# The part of the screen arrows live in, and in which a leak counts as seen.
func _inner_rect() -> Rect2:
	var view: Vector2 = _draw_node.get_viewport_rect().size
	var bottom: float = BOTTOM_CLEAR_MOBILE if MainGlobals.is_mobile() else BOTTOM_CLEAR_DESKTOP
	return Rect2(Vector2(INSET, TOP_CLEAR), Vector2(view.x - 2.0 * INSET, view.y - TOP_CLEAR - bottom))

func _on_screen(n: Node2D) -> Vector2:
	return n.get_global_transform_with_canvas().origin

func _process(_delta: float) -> void:
	var inner: Rect2 = _inner_rect()
	if not _leaks.is_empty() and _life_ms >= 0.0 and _now() - _born_ms > _life_ms:
		_leaks.clear()
	for i in range(_leaks.size() - 1, -1, -1):
		var p = _leaks[i]
		if not is_instance_valid(p) or not p.water_active:
			_leaks.remove_at(i)
			continue
		# A tool catching it: nothing to find.
		if not p.action.is_empty() and not p.action_full:
			_leaks.remove_at(i)
			continue
		# On screen: found.
		if inner.has_point(_on_screen(p)):
			_leaks.remove_at(i)
	_draw_node.queue_redraw()

# Where the line from `from` toward `to` leaves `r`, or `to` itself if it is inside.
static func edge_point(r: Rect2, from: Vector2, to: Vector2) -> Vector2:
	if r.has_point(to):
		return to
	var d: Vector2 = to - from
	var t: float = 1.0
	if d.x > 0.0:
		t = minf(t, (r.end.x - from.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (r.position.x - from.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (r.end.y - from.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (r.position.y - from.y) / d.y)
	return from + d * clampf(t, 0.0, 1.0)

# The outline of an arrow of length `s` whose tip is at `tip`, pointing along `dir`: seven points,
# tip first, round the head and down the shaft.
static func arrow_points(tip: Vector2, dir: Vector2, s: float) -> PackedVector2Array:
	var n: Vector2 = dir.orthogonal()
	var neck: Vector2 = tip - dir * s * HEAD_LEN
	var tail: Vector2 = tip - dir * s
	return PackedVector2Array([tip, neck + n * s * HEAD_HALF, neck + n * s * SHAFT_HALF,
		tail + n * s * SHAFT_HALF, tail - n * s * SHAFT_HALF, neck - n * s * SHAFT_HALF,
		neck - n * s * HEAD_HALF])

func _fill_grown(pts: PackedVector2Array, by: float, col: Color) -> void:
	for poly: PackedVector2Array in Geometry2D.offset_polygon(pts, by, Geometry2D.JOIN_ROUND):
		_draw_node.draw_colored_polygon(poly, col)

func _draw_arrows() -> void:
	if _player == null or not is_instance_valid(_player) or _leaks.is_empty():
		return
	var inner: Rect2 = _inner_rect()
	var from: Vector2 = _on_screen(_player)
	from = Vector2(clampf(from.x, inner.position.x, inner.end.x), clampf(from.y, inner.position.y, inner.end.y))
	# A slow pulse, so a new arrow is noticed without flashing.
	var wave: float = sin(float(Time.get_ticks_msec()) / 180.0)
	var pulse: float = 1.0 + 0.08 * wave
	var bob: float = 0.5 + 0.5 * wave
	for p in _leaks:
		if not is_instance_valid(p):
			continue
		var to: Vector2 = _on_screen(p)
		var dir: Vector2 = (to - from).normalized()
		if dir == Vector2.ZERO:
			continue
		# Kept inside the arrow area, then nudged toward the leak and back: motion catches the eye at
		# the edge of vision where a color alone does not.
		var tip: Vector2 = edge_point(inner, from, to) - dir * NUDGE * (1.0 - bob)
		var pts: PackedVector2Array = arrow_points(tip, dir, SIZE * pulse)
		# The rims are the arrow GROWN, not stroked: a thick polyline leaves notches at the tip and
		# the barbs, where its segments do not join.
		_fill_grown(pts, OUTLINE_W + 7.0, GLOW)
		_fill_grown(pts, OUTLINE_W, OUTLINE)
		_fill_grown(pts, RIM_W, RIM)
		_draw_node.draw_colored_polygon(pts, COLOR)
