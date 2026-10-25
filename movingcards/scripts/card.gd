extends Area2D

signal card_pressed(p, card_id)

var end_pixel_pos: Vector2 = Vector2.ZERO
var id: int = 0

# A card used to slide dead straight from A to B, which reads as a slide rather than a card being
# moved. It now travels a shallow arc: the same two endpoints, bowed to one side, so the eye has
# something to follow. `bow` is the sideways offset at the halfway point, in pixels, and is set by
# the level (which is the only thing that knows the margins the arc must not bow into).
var bow: float = 0.0
var start_pixel_pos: Vector2 = Vector2.ZERO
var _travel: float = 0.0    # 0..1 along the path
var _span: float = 0.0

func _ready() -> void:
	$CardLabel.add_theme_font_override("font", MainGlobals.get_text_font())
	$CardLabel.add_theme_color_override("font_color", FACE_INK)
	$CardLabel.add_theme_color_override("font_shadow_color", Color(0.45, 0.35, 0.2, 0.30))
	$CardLabel.add_theme_constant_override("shadow_offset_x", 1)
	$CardLabel.add_theme_constant_override("shadow_offset_y", 2)
	_dress_face()

# THE FRONT is a clean cream tile: a warm gradient, a soft bevel (a lit top-left edge, a shaded
# bottom-right one), a fine gold line inset with rounded corners, and the number large in deep navy
# with a soft shadow. A tap marks it unmistakably: a thick ring in
# green or red and a wash of the same color over the face (`clicked`, `_mark`). It was a plain white
# square with a black number in a black and white frame; then, briefly, a playing card with corner
# indices (not the goal) whose right/wrong frame was too faint to notice.
const FACE_PAPER: Color = Color(0.985, 0.965, 0.905)
const FACE_INK: Color = Color(0.11, 0.16, 0.31)
const FACE_PAPER_LOW: Color = Color(0.955, 0.915, 0.825)
const FACE_GOLD: Color = Color(0.74, 0.56, 0.24)
# one corner radius for the face, the mark, the edge and the back (rounded.gdshader), so the card is
# one rounded shape on both sides; the inner gold line follows it
const CARD_RADIUS: float = 14.0
const MARK_RIGHT: Color = Color(0.20, 0.72, 0.30)
const MARK_WRONG: Color = Color(0.86, 0.20, 0.18)
var _face: Node2D = null
static var _round_back: ShaderMaterial = null
var _mark: int = 0                    # 0 none, 1 right, -1 wrong

func _dress_face() -> void:
	$CardFront.self_modulate = Color(1, 1, 1, 0)
	$CardFront/CardFrontFrame.hide()       # the mark is drawn by the face now
	# the edge round both sides: a fine dark navy line, not 2 px of black
	var bsb: StyleBoxFlat = ($CardBorder.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	bsb.border_color = Color(0.06, 0.08, 0.14, 0.85)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(int(CARD_RADIUS))
	bsb.anti_aliasing = true
	$CardBorder.add_theme_stylebox_override("panel", bsb)
	if _round_back == null:
		_round_back = ShaderMaterial.new()
		_round_back.shader = preload("res://movingcards/scripts/rounded.gdshader")
		_round_back.set_shader_parameter("radius_px", CARD_RADIUS)
	$CardBack.material = _round_back
	_face = Node2D.new()
	_face.draw.connect(_draw_face)
	$CardFront.add_child(_face)
	$CardFront.move_child(_face, 0)

# The outline of a rounded rect (CARD_RADIUS), as a polygon, for the face and its bevel.
func _round_rect_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cs: Array = [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for c: Array in cs:
		for k in 7:
			pts.append((c[0] as Vector2) + Vector2.from_angle(float(c[1]) + PI * 0.5 * float(k) / 6.0) * rad)
	return pts

func _draw_face() -> void:
	var r: Rect2 = Rect2(-40.0, -40.0, 80.0, 80.0)
	var outline: PackedVector2Array = _round_rect_pts(r, CARD_RADIUS)
	# warm cream stock, a touch deeper toward the bottom
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in outline:
		cols.append(FACE_PAPER.lerp(FACE_PAPER_LOW, (p.y - r.position.y) / r.size.y))
	_face.draw_polygon(outline, cols)
	# the bevel: a lit edge along the top-left of the rounded outline, a shaded one along the
	# bottom-right
	var inner: PackedVector2Array = _round_rect_pts(r.grow(-2.0), CARD_RADIUS - 2.0)
	var n: int = inner.size()
	for k in n:
		var a: Vector2 = inner[k]
		var b: Vector2 = inner[(k + 1) % n]
		var facing: float = ((a + b) * 0.5).normalized().dot(Vector2(-0.7, -0.7))
		var col: Color = Color(1, 1, 1, 0.75 * facing) if facing > 0.0 else Color(0.55, 0.45, 0.30, -0.40 * facing)
		_face.draw_line(a, b, col, 3.0, true)
	# a fine gold line inset, rounded at the corners, and a fainter one inside it
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	sb.border_color = FACE_GOLD
	sb.set_corner_radius_all(int(CARD_RADIUS) - 7)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	_face.draw_style_box(sb, r.grow(-7.0))
	sb.border_color = Color(FACE_GOLD, 0.35)
	sb.set_corner_radius_all(int(CARD_RADIUS) - 10)
	_face.draw_style_box(sb, r.grow(-10.0))
	if _mark != 0:
		var mcol: Color = MARK_RIGHT if _mark > 0 else MARK_WRONG
		var msb: StyleBoxFlat = StyleBoxFlat.new()
		msb.bg_color = Color(mcol, 0.22)
		msb.border_color = mcol
		msb.set_border_width_all(6)
		msb.corner_detail = 12
		msb.set_corner_radius_all(int(CARD_RADIUS))
		msb.anti_aliasing = true
		_face.draw_style_box(msb, r)

# A soft SHADOW under the card, down and to the right, so it lies on the table instead of looking
# pasted onto it. Drawn by the card itself, so it is under its sprites and moves with it. Only the
# shadow: the card's face and back are the stimulus and are untouched. ONE pre-blurred texture drawn
# filtered, not stacked hard-edged rects: those edges snapped from pixel to pixel as the card moved
# at sub-pixel steps, and the moving card flickered.
static var _shadow_tex: Texture2D = null

static func _make_shadow() -> Texture2D:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			# a rounded box: 0 inside the card's footprint, rising to 1 over the blur margin
			var px: float = (absf(float(x) + 0.5 - n * 0.5) - n * 0.5 + 10.0) / 10.0
			var py: float = (absf(float(y) + 0.5 - n * 0.5) - n * 0.5 + 10.0) / 10.0
			var d: float = Vector2(maxf(px, 0.0), maxf(py, 0.0)).length()
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.15, 0.05, 0.0, 0.30 * a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	if _shadow_tex == null:
		_shadow_tex = _make_shadow()
	draw_texture_rect(_shadow_tex, Rect2(Vector2(-46.0, -44.0), Vector2(98.0, 98.0)), false)

func set_id(_id: int) -> void:
	id = _id
	$CardLabel.text = str(id)
	if _face != null:
		_face.queue_redraw()
	var cardidx: int = id % MovingCardsG.back_textures.size()
	$CardBack.texture = load(MovingCardsG.back_textures[cardidx])

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		card_pressed.emit(position, id)

# THE CARD FLIPS. Showing or hiding a face turns the card over: it narrows to its edge (scale.x to
# 0), the other face is put up, and it opens again -- a fifth of a second in all. The faces used to
# swap in one frame.
const FLIP_HALF_S: float = 0.10
var _face_up: bool = true
var _flip: Tween = null

func _set_face(up: bool) -> void:
	$CardLabel.visible = up
	$CardFront.visible = up
	$CardBack.visible = true

func _flip_to(up: bool) -> void:
	if up == _face_up and (_flip == null or not _flip.is_valid()):
		_set_face(up)
		return
	_face_up = up
	if _flip != null and _flip.is_valid():
		_flip.kill()
	_flip = create_tween()
	_flip.tween_property(self, "scale:x", 0.0, FLIP_HALF_S * scale.x).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip.tween_callback(_set_face.bind(up))
	_flip.tween_property(self, "scale:x", 1.0, FLIP_HALF_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_card() -> void:
	_flip_to(false)

func reveal_card() -> void:
	_flip_to(true)

func begin_move(from: Vector2, to: Vector2, side_bow: float) -> void:
	start_pixel_pos = from
	end_pixel_pos = to
	bow = side_bow
	_travel = 0.0
	_span = from.distance_to(to)

func move_card(delta: float) -> bool:
	if _span < 1.0:
		# never given a path (a stationary level): fall back to a straight approach
		var u: Vector2 = end_pixel_pos - position
		var d: float = u.length()
		if d < 1.0 or MovingCardsG.card_move_speed * delta >= d:
			position = end_pixel_pos
			return false
		position += (u / d) * MovingCardsG.card_move_speed * delta
		return true
	_travel += MovingCardsG.card_move_speed * delta / _span
	if _travel >= 1.0:
		position = end_pixel_pos
		return false
	# sin() is zero at both ends, so the arc starts and finishes exactly on the endpoints the
	# level laid out — the bow only ever affects the midpoint of the trip.
	var along: Vector2 = start_pixel_pos.lerp(end_pixel_pos, _travel)
	var side: Vector2 = (end_pixel_pos - start_pixel_pos).normalized().orthogonal()
	position = along + side * bow * sin(PI * _travel)
	return true

func clicked(correct: bool) -> void:
	_mark = 1 if correct else -1
	_face.queue_redraw()
