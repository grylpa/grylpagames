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
	$CardLabel.add_theme_font_override("font", MainGlobals.get_system_sans_font())

func set_id(_id: int) -> void:
	id = _id
	$CardLabel.text = str(id)
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
	if correct:
		$CardFront/CardFrontFrame.set_modulate(Color(0.5, 1, 0.5))
	else:
		$CardFront/CardFrontFrame.set_modulate(Color(1, 0.2, 0.2))
