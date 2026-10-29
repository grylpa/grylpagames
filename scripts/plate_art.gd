class_name PlateArt
extends Node2D

# The drawn look of the PLATE a shape stands on in the three study games -- Lineup (ooo), Witness
# (ddooo) and Glimpse (pop): any Sprite2D showing art/box.png, which was a flat gray square with a
# hard black edge. Now a slate tile: rounded, a soft shadow, a beveled rim and a faint inset well.
#
# KEPT NEUTRAL ON PURPOSE (see StudyBackdrop in CLAUDE.md): one even mid-gray, no color, no pattern,
# and the same on every plate, so a plate never draws the eye to one position over another. The
# bevel is the only light, and it is identical on all of them.
#
# Hooked like DockArt: `MainGlobals` hands every Sprite2D entering the tree to `dress()`; the art is
# the sprite's CHILD (it shows, hides, moves and tints with it) and the sprite's pixels are hidden.

const TEXTURE_PATH: String = "res://art/box.png"
const HALF: float = 28.0
const RAD: float = 7.0
const FACE: Color = Color(0.27, 0.28, 0.30)


static func dress(spr: Sprite2D) -> void:
	if spr.texture == null or spr.texture.resource_path != TEXTURE_PATH or spr.has_node("PlateArt"):
		return
	var art: PlateArt = PlateArt.new()
	art.name = "PlateArt"
	art.scale = Vector2.ONE * (float(spr.texture.get_width()) / (HALF * 2.0))
	spr.self_modulate = Color(1, 1, 1, 0)
	spr.add_child(art)


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cs: Array = [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c: Array in cs:
		for k in 5:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw() -> void:
	var outer: Rect2 = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	draw_colored_polygon(_rrect(Rect2(outer.position + Vector2(1.5, 2.5), outer.size), RAD), Color(0, 0, 0, 0.35))
	draw_colored_polygon(_rrect(outer, RAD), Color(0.10, 0.10, 0.11))
	# the beveled rim: lighter toward the top left, darker toward the bottom right
	var rim: PackedVector2Array = _rrect(outer.grow(-1.5), RAD - 1.0)
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in rim:
		var t: float = clampf((p / HALF).dot(Vector2(-0.6, -0.8)), -1.0, 1.0)
		cols.append(FACE.lightened(0.22 * t) if t > 0.0 else FACE.darkened(-0.30 * t))
	draw_polygon(rim, cols)
	# the face, and a faint inset well
	draw_colored_polygon(_rrect(outer.grow(-5.0), RAD - 3.0), FACE)
	draw_polyline(_closed(_rrect(outer.grow(-5.0), RAD - 3.0)), Color(0, 0, 0, 0.30), 1.2, true)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out
