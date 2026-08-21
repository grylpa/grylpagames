extends Area2D

signal target_pressed(target_id, board_pos)

var id: int = 1
var is_receiver: bool = false
var is_sender: bool = false
var color
var board_pos: Vector2i
var transaction_id: int = -1

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id, show_id=true):
	id = _id
	$TargetText.text = str(id)
	$TargetText.visible = show_id
	$TargetImage.visible = true
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	# color = PneumoG.PneumoG.color_by_index(destination_type-1)
	# $ReceiverImage.set_modulate(color)
	
func reset_sender_receiver():
	$TargetImage.visible = true
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	is_sender = false
	is_receiver = false
	color = Color(1,1,1,1)
	modulate = Color(1,1,1,1)

func set_receiver(_is_receiver: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	$TargetText.text = str(transaction_id)
	is_receiver = _is_receiver
	# The pairing is COLOR-coded; the transaction number is internal bookkeeping and is never
	# shown. Same as taxi and parkem. The text is still assigned, so it is there in the remote
	# inspector when a mismatch has to be traced.
	$TargetText.visible = false
	if is_receiver:
		is_sender = false
	# receiver-w-circle-4x.png carries the circle itself (the plain receiver art did not, which is
	# why an activated gate used to lose its circle and arrow), so the base sprite is swapped out
	# rather than layered under. Same art and same swap as wolves, storm, mmm and lightsout.
	$TargetImage.visible = !is_receiver
	$ReceiverImage.visible = is_receiver
	color = _color
	$ReceiverImage.set_modulate(color)

func set_sender(_is_sender: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	$TargetText.text = str(transaction_id)
	is_sender = _is_sender
	$TargetText.visible = false
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