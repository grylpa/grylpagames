extends Area2D

signal card_pressed(p, card_id)

var end_pixel_pos: Vector2 = Vector2.ZERO
var id: int = 0

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

func move_card(delta: float) -> bool:
	var u: Vector2 = end_pixel_pos - position
	var d: float = u.length()
	if d < 1.0:
		position = end_pixel_pos
		return false
	var step: float = MovingCardsG.card_move_speed * delta
	if step >= d:
		position = end_pixel_pos
		return false
	u /= d
	position += u * step
	return true

func clicked(correct: bool) -> void:
	if correct:
		$CardFront/CardFrontFrame.set_modulate(Color(0.5, 1, 0.5))
	else:
		$CardFront/CardFrontFrame.set_modulate(Color(1, 0.2, 0.2))
