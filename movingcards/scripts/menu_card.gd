extends Node2D

# A CARD FOR THE MENU POSTER ONLY (menu_world.gd): a playful glazed tile, like a children's memory game --
# the user wanted the cards pretty, but not like poker cards (gilt, corner indices and filigree looked like a
# gambling game). A rounded square with a visible edge (its thickness), in a soft pastel of its own; the FACE
# warm white with the number in white inside a big colored disc ringed with dots; the BACK the pastel itself,
# soft white arcs across it and a five-petal flower at its heart; a glaze highlight over both. Centered on its
# origin. The poster bakes each face with `flat` set (no shadow, no edge) and lays it on a 3-D tile of its own.

const S: float = 92.0
const RADIUS: float = 18.0
const EDGE: float = 6.0
const HUES: Array = [Color(0.95, 0.52, 0.45), Color(0.30, 0.66, 0.70), Color(0.96, 0.74, 0.30), Color(0.62, 0.46, 0.78),
	Color(0.52, 0.74, 0.46), Color(0.44, 0.62, 0.92), Color(0.94, 0.56, 0.70)]

var number: int = 1
var flat: bool = false            # for baking a face into a texture: no shadow, no edge
var face_up: bool = false
static var _font: Font = null

func _ready() -> void:
	if _font == null:
		_font = MainGlobals.get_text_font()

func set_face(up: bool) -> void:
	if up != face_up:
		face_up = up
		queue_redraw()

func _hue() -> Color:
	return HUES[(number - 1) % HUES.size()]

func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for c in 4:
		for k in 6:
			var a: float = -PI * 0.5 + PI * 0.5 * float(c) + PI * 0.5 * float(k) / 5.0
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts

func _draw() -> void:
	var r: Rect2 = Rect2(-S * 0.5, -S * 0.5, S, S)
	var hue: Color = _hue()
	# its shadow, then its edge (the tile's thickness), then its top -- the first two not when baked flat
	if not flat:
		draw_colored_polygon(_rounded(Rect2(r.position + Vector2(4, EDGE + 6), r.size), RADIUS), Color(0, 0, 0, 0.22))
		draw_colored_polygon(_rounded(Rect2(r.position + Vector2(0, EDGE), r.size), RADIUS), (Color(0.82, 0.76, 0.66) if face_up else hue.darkened(0.35)))
	var top: PackedVector2Array = _rounded(r, RADIUS)
	var cols: PackedColorArray = PackedColorArray()
	for p in top:
		var u: float = clampf((p.x - r.position.x + p.y - r.position.y) / (S * 2.0), 0.0, 1.0)
		if face_up:
			cols.append(Color(1.0, 0.99, 0.96).lerp(Color(0.95, 0.91, 0.84), u))
		else:
			cols.append(hue.lightened(0.25).lerp(hue.darkened(0.05), u))
	draw_polygon(top, cols)
	if face_up:
		# the number in a big colored disc, a ring of dots round it
		draw_circle(Vector2(0, 2), 31.0, hue.darkened(0.15))
		draw_circle(Vector2.ZERO, 31.0, hue)
		draw_circle(Vector2(-8, -9), 14.0, Color(1, 1, 1, 0.16))
		for k in 16:
			var a: float = TAU * float(k) / 16.0
			draw_circle(Vector2(cos(a), sin(a)) * 38.0, 2.0, Color(hue, 0.55))
		var txt: String = str(number)
		var fs: int = 40
		var tw: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(-tw * 0.5 + 1.0, fs * 0.36 + 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.15))
		draw_string(_font, Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	else:
		# soft white arcs sweeping across from a corner, and a flower at the heart
		for k in 4:
			var rr: float = 22.0 + float(k) * 16.0
			draw_arc(r.position + Vector2(S, S), rr, PI, PI * 1.5, 18, Color(1, 1, 1, 0.20 - 0.03 * float(k)), 5.0, true)
		for k in 5:
			var a2: float = TAU * float(k) / 5.0 - PI * 0.5
			draw_circle(Vector2(cos(a2), sin(a2)) * 11.0, 9.0, Color(1, 1, 1, 0.85))
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.86, 0.40))
	# the glaze: a soft highlight across the upper left
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(10, 6), r.position + Vector2(46, 6), r.position + Vector2(6, 46), r.position + Vector2(6, 14)]), Color(1, 1, 1, 0.22))
