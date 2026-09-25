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

const COLOR: Color = Color(0.20, 0.52, 1.0, 0.95)
const OUTLINE: Color = Color(0.02, 0.06, 0.16, 0.9)
const SIZE: float = 26.0            # arrow length, screen units
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
func track(pipe: Node2D, life_ms: float = 1000.0) -> void:
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

func _draw_arrows() -> void:
	if _player == null or not is_instance_valid(_player) or _leaks.is_empty():
		return
	var inner: Rect2 = _inner_rect()
	var from: Vector2 = _on_screen(_player)
	from = Vector2(clampf(from.x, inner.position.x, inner.end.x), clampf(from.y, inner.position.y, inner.end.y))
	# A slow pulse, so a new arrow is noticed without flashing.
	var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) / 180.0)
	for p in _leaks:
		if not is_instance_valid(p):
			continue
		var to: Vector2 = _on_screen(p)
		var dir: Vector2 = (to - from).normalized()
		if dir == Vector2.ZERO:
			continue
		var tip: Vector2 = edge_point(inner, from, to)
		var s: float = SIZE * pulse
		var n: Vector2 = dir.orthogonal()
		var pts: PackedVector2Array = PackedVector2Array([tip, tip - dir * s + n * s * 0.55,
			tip - dir * s * 0.72, tip - dir * s - n * s * 0.55])
		_draw_node.draw_colored_polygon(pts, COLOR)
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		_draw_node.draw_polyline(loop, OUTLINE, 2.0, true)
