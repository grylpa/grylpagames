extends Area2D

signal card_pressed(p, card_id)

var board_pos: Vector2
var id := 0
var show_label := false

func _ready() -> void:
	$CardLabel.visible = show_label
	hide_card()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_id(_id):
	id = _id
	$CardLabel.text = str(id)
	var cardidx = id % FriendsG.back_textures.size()
	$CardBack.texture = load(FriendsG.back_textures[cardidx])

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		card_pressed.emit(board_pos, id)

func hide_card():
	$CardLabel.hide()
	$CardBack.show()
	$CardFront.hide()

func reveal_card():
	$CardLabel.visible = show_label
	$CardFront.show()

func clicked(correct: bool):
	if correct:
		$CardFront/CardFrontFrame.set_modulate(Color(0.5,1,0.5))
	else:
		$CardFront/CardFrontFrame.set_modulate(Color(1,0.2,0.2))
