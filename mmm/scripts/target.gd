extends Area2D

signal target_pressed(target_id, board_pos)

var id := 1
var is_receiver := false
var is_sender := false
var color
var board_pos: Vector2i
var transaction_id := -1
var is_bomb := false

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id, show_id=true):
	id = _id
	# $TargetText.text = str(id)
	$TargetText.visible = show_id
	$TargetImage.visible = true
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	# color = MmmG.color_by_index(destination_type-1)
	# $ReceiverImage.set_modulate(color)
	
func set_bomb(_color: Color):
	$TargetImage.set_modulate(_color)
	is_bomb = true
	color = _color
	# $TargetText.text = "X"
	# $TargetText.visible = true
	$TargetBomb.visible = true
	$TargetBomb.modulate = Color(0.5,0.0,0.0,1)
	$TargetBomb.play("Bomb")
	
func set_receiver(_is_receiver: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	# $TargetText.text = str(transaction_id)
	is_receiver = _is_receiver
	$TargetText.visible = is_receiver
	if is_receiver:
		is_sender = false
	$TargetImage.visible = !is_receiver
	$ReceiverImage.visible = is_receiver
	color = _color
	$ReceiverImage.set_modulate(color)

func set_sender(_is_sender: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	# $TargetText.text = str(transaction_id)
	is_sender = _is_sender
	$TargetText.visible = is_sender
	if is_sender:
		is_receiver = false
	$TargetImage.visible = !is_sender
	$SenderImage.visible = is_sender
	color = _color
	$SenderImage.set_modulate(color)

func set_img_rot(rot):
	$TargetImage.rotation = rot
	$ReceiverImage.rotation = rot+PI
	$SenderImage.rotation = rot

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		target_pressed.emit(id, board_pos)

func flash():
	var tween_scale = MainGlobals.make_tween()
	tween_scale.tween_property(self, "scale", Vector2(1.5,1.5), 0.2)
	tween_scale.tween_property(self, "scale", Vector2(1.0,1.0), 0.3)