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
	_dress_face()

# THE FRONT is a clean cream tile: a soft bevel (a lit top-left edge, a shaded bottom-right one) and
# the number large in deep navy -- nothing else on it. A tap marks it unmistakably: a thick ring in
# green or red and a wash of the same color over the face (`clicked`, `_mark`). It was a plain white
# square with a black number in a black and white frame; then, briefly, a playing card with corner
# indices (not the goal) whose right/wrong frame was too faint to notice.
const FACE_PAPER: Color = Color(0.985, 0.965, 0.905)
const FACE_INK: Color = Color(0.11, 0.16, 0.31)
const MARK_RIGHT: Color = Color(0.20, 0.72, 0.30)
const MARK_WRONG: Color = Color(0.86, 0.20, 0.18)
var _face: Node2D = null
var _mark: int = 0                    # 0 none, 1 right, -1 wrong

func _dress_face() -> void:
	$CardFront.self_modulate = Color(1, 1, 1, 0)
	$CardFront/CardFrontFrame.hide()       # the mark is drawn by the face now
	# the edge round both sides: a fine dark navy line, not 2 px of black
	var bsb: StyleBoxFlat = ($CardBorder.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	bsb.border_color = Color(0.06, 0.08, 0.14, 0.85)
	bsb.set_border_width_all(1)
	$CardBorder.add_theme_stylebox_override("panel", bsb)
	_face = Node2D.new()
	_face.draw.connect(_draw_face)
	$CardFront.add_child(_face)
	$CardFront.move_child(_face, 0)

func _draw_face() -> void:
	var r: Rect2 = Rect2(-40.0, -40.0, 80.0, 80.0)
	_face.draw_rect(r, FACE_PAPER, true)
	# the bevel: light along the top and left, shade along the bottom and right
	var lit: Color = Color(1, 1, 1, 0.8)
	var shade: Color = Color(0.55, 0.45, 0.30, 0.35)
	_face.draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(40, -40), Vector2(35, -35), Vector2(-35, -35)]),
		PackedColorArray([lit, lit, Color(lit, 0.0), Color(lit, 0.0)]))
	_face.draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(-35, -35), Vector2(-35, 35), Vector2(-40, 40)]),
		PackedColorArray([lit, Color(lit, 0.0), Color(lit, 0.0), lit]))
	_face.draw_polygon(PackedVector2Array([Vector2(-40, 40), Vector2(-35, 35), Vector2(35, 35), Vector2(40, 40)]),
		PackedColorArray([shade, Color(shade, 0.0), Color(shade, 0.0), shade]))
	_face.draw_polygon(PackedVector2Array([Vector2(40, -40), Vector2(40, 40), Vector2(35, 35), Vector2(35, -35)]),
		PackedColorArray([shade, shade, Color(shade, 0.0), Color(shade, 0.0)]))
	if _mark != 0:
		var col: Color = MARK_RIGHT if _mark > 0 else MARK_WRONG
		_face.draw_rect(r, Color(col, 0.22), true)
		_face.draw_rect(r.grow(-3.5), col, false, 7.0)

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

func hide_card() -> void:
	$CardLabel.hide()
	$CardBack.show()
	$CardFront.hide()

func reveal_card() -> void:
	$CardLabel.show()
	$CardFront.show()

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
