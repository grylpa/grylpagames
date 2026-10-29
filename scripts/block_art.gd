class_name BlockArt
extends Node2D

# The drawn look of the BRICK blocks (Gorilla, Storm, Wolves, Mind Palace, Detour): any Sprite2D
# showing art/bricks1-3.png. Those were small photo-textured squares, the last photographic thing
# among the drawn art. Now a chunky block of bricks seen from above: a bevel lit from the screen's
# top left, a soft shadow, three courses of bricks with mortar, each brick a little different.
# The three textures stay three distinct TYPES, as the old images were (user, 2026-10-29): deep red
# long bricks; pale pink narrow bricks; red bricks with sandy ones mixed in (`STYLES`), all in one
# mortar.
#
# Hooked like DockArt: `MainGlobals` hands every Sprite2D entering the tree to `dress()`. The art is
# the sprite's CHILD, so it shows, hides, moves, scales and tints with it however a game drives it,
# and the sprite's own pixels are hidden with self_modulate.

const TEXTURES: Dictionary = {
	"res://art/bricks1.png": 0,
	"res://art/bricks2.png": 1,
	"res://art/bricks3.png": 2,
}
const HALF: float = 16.0
const RAD: float = 3.5
# ONE mortar for every type: with a pale mortar on one and a dark one on another, the pale one read
# as a framed block and the others did not (user, 2026-10-29). The types differ in their bricks.
const MORTAR: Color = Color(0.56, 0.51, 0.45)
# per type: brick color, a second color mixed in (and how often), mortar, courses, bricks per course
const STYLES: Array = [
	{"tone": Color(0.70, 0.27, 0.16), "mix": Color(0.62, 0.22, 0.13), "mix_p": 0.35,
		"mortar": MORTAR, "courses": 3, "per": 2},
	{"tone": Color(0.86, 0.56, 0.47), "mix": Color(0.80, 0.47, 0.40), "mix_p": 0.4,
		"mortar": MORTAR, "courses": 4, "per": 3},
	{"tone": Color(0.76, 0.38, 0.24), "mix": Color(0.86, 0.72, 0.52), "mix_p": 0.3,
		"mortar": MORTAR, "courses": 4, "per": 2},
]
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)

var variant: int = 0
# Detour (parkem) has ONE brick sprite per cell, always bricks1.png: there the type is picked from
# the cell's place on the board instead, so its walls mix all three types like the other games.
var by_place: bool = false


static func dress(spr: Sprite2D) -> void:
	if spr.texture == null or spr.has_node("BlockArt"):
		return
	var v = TEXTURES.get(spr.texture.resource_path)
	if v == null:
		return
	var art: BlockArt = BlockArt.new()
	art.name = "BlockArt"
	art.variant = int(v)
	art.by_place = String(spr.name) == "Bricks"
	# drawn in the 32 px the images were made at, whatever size they were shown
	art.scale = Vector2(spr.texture.get_width(), spr.texture.get_height()) / (HALF * 2.0)
	spr.self_modulate = Color(1, 1, 1, 0)
	spr.add_child(art)


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs: Array = [[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0], [Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5],
		[Vector2(r.position.x + rr, r.position.y + rr), PI]]
	for c: Array in cs:
		for k in 4:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 3.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(Vector2(1.8, 2.6))
	if by_place:
		var cell: Vector2i = Vector2i((global_position / 40.0).floor())
		variant = posmod(cell.x * 7 + cell.y * 13 + (cell.x * cell.y) % 5, STYLES.size())
	var st: Dictionary = STYLES[variant % STYLES.size()]
	var outer: Rect2 = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	var sh: PackedVector2Array = _rrect(Rect2(outer.position + ofs, outer.size), RAD)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.30))
	# the mortar bed, the whole block
	var bed: PackedVector2Array = _rrect(outer, RAD)
	draw_colored_polygon(bed, st["mortar"])
	# courses of bricks, alternate courses offset by half a brick
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7 + variant * 31
	var inset: float = 1.8
	var gap: float = 1.3
	var courses: int = st["courses"]
	var per: int = st["per"]
	var course_h: float = (HALF * 2.0 - inset * 2.0 - gap * float(courses - 1)) / float(courses)
	var bw: float = (HALF * 2.0 - inset * 2.0 - gap * float(per - 1)) / float(per)
	for row in courses:
		var y0: float = -HALF + inset + float(row) * (course_h + gap)
		var x: float = -HALF + inset - (0.0 if row % 2 == 0 else 0.5) * (bw + gap)
		while x < HALF - inset - 0.5:
			var x0: float = maxf(x, -HALF + inset)
			var x1: float = minf(x + bw, HALF - inset)
			if x1 - x0 > 2.0:
				var tone: Color = st["mix"] if rng.randf() < float(st["mix_p"]) else st["tone"]
				tone = tone.lightened(rng.randf_range(0.0, 0.08)) if rng.randf() < 0.5 \
					else tone.darkened(rng.randf_range(0.0, 0.08))
				var br: Rect2 = Rect2(x0, y0, x1 - x0, course_h)
				var pts: PackedVector2Array = _rrect(br, 1.2)
				var cols: PackedColorArray = PackedColorArray()
				for p: Vector2 in pts:
					var t: float = clampf(((p - br.get_center()) / (br.size * 0.5)).dot(light), -1.0, 1.0)
					cols.append(tone.lightened(0.16 * t) if t > 0.0 else tone.darkened(-0.20 * t))
				draw_polygon(pts, cols)
				# a lit lip along the brick's edge toward the light
				var lip_y: float = br.position.y + 0.6 if light.y < 0.0 else br.end.y - 0.6
				draw_line(Vector2(x0 + 1.0, lip_y), Vector2(x1 - 1.0, lip_y), Color(1, 0.92, 0.82, 0.30), 0.7, true)
			x += bw + gap
	# the block's bevel: a lit rim toward the light, a dark rim away from it
	var closed: PackedVector2Array = bed.duplicate()
	closed.append(bed[0])
	var pairs: int = closed.size() - 1
	for k in pairs:
		var a: Vector2 = closed[k]
		var b: Vector2 = closed[k + 1]
		var t2: float = (((a + b) * 0.5) / HALF).dot(light)
		var col: Color = Color(1, 0.95, 0.88, 0.45 * t2) if t2 > 0.0 else Color(0.12, 0.06, 0.04, -0.55 * t2)
		draw_line(a, b, col, 1.4, true)
	draw_polyline(closed, Color(0.20, 0.10, 0.06, 0.65), 0.8, true)
