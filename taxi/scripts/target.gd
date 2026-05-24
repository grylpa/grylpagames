extends Area2D

signal target_pressed(target)

var id := 1
var is_receiver := false
var is_sender := false
var color
var board_pos: Vector2i
var transaction_id := -1
var lobby_pos: Vector2i
var dropoff_pos: Vector2i
var showdef := false
var is_gas_station := false

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id, show_id=true):
	id = _id
	$TargetText.text = str(id)
	$TargetText.visible = show_id
	$TargetImage.visible = showdef
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	$SenderImage.scale = Vector2(0.8,0.8) * 0.25
	$ReceiverImage.scale = Vector2(0.8,0.8) * 0.25
	$TargetImage.scale = Vector2(0.8,0.8) * 0.25
	# color = TaxiG.TaxiG.color_by_index(destination_type-1)
	# $ReceiverImage.set_modulate(color)
	
func reset_sender_receiver():
	$TargetImage.visible = showdef
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	is_sender = false
	is_receiver = false
	color = Color(1,1,1,1)
	modulate = Color(1,1,1,1)
	transaction_id = -1

func set_receiver(_is_receiver: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	$TargetText.text = str(transaction_id)
	is_receiver = _is_receiver
	$TargetText.visible = false#is_receiver
	if is_receiver:
		is_sender = false
	$TargetImage.visible = showdef and !is_receiver
	$ReceiverImage.visible = is_receiver
	color = _color
	$ReceiverImage.set_modulate(color)

func set_sender(_is_sender: bool, _color: Color, _transaction_id: int):
	transaction_id = _transaction_id
	$TargetText.text = str(transaction_id)
	is_sender = _is_sender
	$TargetText.visible = false#is_sender
	if is_sender:
		is_receiver = false
	$TargetImage.visible = showdef and !is_sender
	$SenderImage.visible = is_sender
	color = _color
	$SenderImage.set_modulate(color)
	modulate = Color(1,1,1,0.8)

func set_img_rot(rot):
	$TargetImage.rotation = rot
	$ReceiverImage.rotation = rot+PI
	$SenderImage.rotation = rot

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		target_pressed.emit(self)

func flash(times := 1):
	var tween_scale = MainGlobals.make_tween()
	for i in times:
		tween_scale.tween_property(self, "scale", Vector2(1.5,1.5), 0.2)
		tween_scale.tween_property(self, "scale", Vector2(1.0,1.0), 0.3)	

func flash_and_reset():
	var tween_scale = MainGlobals.make_tween()
	tween_scale.tween_property(self, "scale", Vector2(1.5,1.5), 0.2)
	tween_scale.tween_property(self, "scale", Vector2(1.0,1.0), 0.3)
	tween_scale.tween_callback(reset_sender_receiver)

func set_gas_station():
	is_gas_station = true
	$GasStation.show()
	$GasStation.rotation = 0
	$TargetImage.hide()
	position = (position + TaxiG.game.board_to_px(lobby_pos)) / 2