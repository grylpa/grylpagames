class_name PathSmoother
extends RefCounted

# Rounds the corners of a path for DRAWING. The route games move their creatures tile center to tile
# center, so every turn is a right angle taken on the spot; easing only the facing still looked
# like turning in place. Fed the true position every frame, this keeps the last `window` of travel
# and returns a point that equals the true position on a straight run but cuts a short arc through
# a corner, and a heading along that arc.
#
# How: the average of the last `window` of path lies window/2 behind the true position on a straight
# run, so adding window/2 back along (true - average) gives the true position exactly; at a corner
# the average is pulled across it, which rounds the turn. When the path doubles back (a reversal)
# that direction shrinks to nothing, so the point blends back onto the true position.

var window: float = 16.0
var _pts: Array[Vector2] = []
var _len: float = 0.0
var _point: Vector2 = Vector2.ZERO
var _heading_ok: bool = false
var _heading: float = 0.0


func _init(_window: float = 16.0) -> void:
	window = _window


func push(p: Vector2) -> void:
	if _pts.is_empty() or p.distance_to(_pts[-1]) > window * 3.0:
		# first sample, or a jump (a respawn, a teleport): start over there
		_pts = [p]
		_len = 0.0
	elif p.distance_to(_pts[-1]) > 0.01:
		_len += p.distance_to(_pts[-1])
		_pts.append(p)
		# trim the oldest travel so exactly `window` remains
		while _pts.size() > 2 and _len - _pts[0].distance_to(_pts[1]) >= window:
			_len -= _pts[0].distance_to(_pts[1])
			_pts.pop_front()
		if _len > window and _pts.size() >= 2:
			var seg: float = _pts[0].distance_to(_pts[1])
			var cut: float = _len - window
			_pts[0] = _pts[0].lerp(_pts[1], cut / seg)
			_len = window
	_solve()


func point() -> Vector2:
	return _point


# Whether the path is clear enough to give a heading (not standing, not doubling back).
func has_heading() -> bool:
	return _heading_ok


func heading() -> float:
	return _heading


func _solve() -> void:
	var last: Vector2 = _pts[-1]
	_heading_ok = false
	if _pts.size() < 2 or _len < window * 0.5:
		_point = last
		return
	var acc: Vector2 = Vector2.ZERO
	for k in range(1, _pts.size()):
		var a: Vector2 = _pts[k - 1]
		var b: Vector2 = _pts[k]
		acc += (a + b) * 0.5 * a.distance_to(b)
	var avg: Vector2 = acc / _len
	var v: Vector2 = last - avg
	var half: float = _len * 0.5
	var ratio: float = v.length() / half
	var k_blend: float = smoothstep(0.0, 0.5, ratio)
	if v.length() > 0.001:
		_point = last.lerp(avg + v.normalized() * half, k_blend)
	else:
		_point = last
	if ratio > 0.5:
		_heading_ok = true
		_heading = v.angle()
