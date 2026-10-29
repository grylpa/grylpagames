extends Area2D

signal target_pressed(target_id, board_pos)

var id: int = 1
var is_receiver: bool = false
var is_sender: bool = false
var color
var board_pos: Vector2i
var transaction_id: int = -1
var lobby_pos: Vector2i

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id, show_id=true):
	id = _id
	$TargetText.text = str(id)
	$TargetText.visible = show_id
	$TargetImage.visible = false#true
	$ReceiverImage.visible = false
	$SenderImage.visible = false
	$SenderImage.scale = Vector2(0.8,0.8) * 0.25
	# color = ParkemG.ParkemG.color_by_index(destination_type-1)
	# $ReceiverImage.set_modulate(color)
	
func reset_sender_receiver():
	$TargetImage.visible = false#true
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
	$TargetText.visible = false#is_receiver
	if is_receiver:
		is_sender = false
	$TargetImage.visible = false#!is_receiver
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
	$TargetImage.visible = false#!is_sender
	$SenderImage.visible = is_sender
	color = _color
	$SenderImage.set_modulate(color)
	modulate = Color(1,1,1,0.8)
	if is_sender:
		# it APPEARS gradually too, quicker than it goes: fades in while growing to full size
		_kill_fade()
		modulate.a = 0.0
		scale = Vector2(0.85, 0.85)
		_fade_tw = MainGlobals.make_tween()
		_fade_tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_fade_tw.tween_property(self, "modulate:a", 0.8, 0.4)
		_fade_tw.tween_property(self, "scale", Vector2.ONE, 0.4)

var _fade_tw: Tween = null

func _kill_fade() -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = null

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

# The sender goes GRADUALLY once its creature is clear of it: it fades out while settling a little
# smaller, over most of a second, then is put back to an idle dock at full size and opacity. (It
# used to swell and snap away in half a second.)
func flash_and_reset():
	_kill_fade()
	var tw = MainGlobals.make_tween()
	_fade_tw = tw
	tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.9)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.9)
	tw.chain().tween_callback(_finish_reset)

func _finish_reset() -> void:
	reset_sender_receiver()
	scale = Vector2.ONE
	# stay transparent until the drawn dock (scripts/dock_art.gd, which copies the sprite's
	# visibility a frame later) has hidden too; restored to full opacity before the next use
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if is_zero_approx(modulate.a) and not is_sender:     # a new sender fades itself in
		modulate.a = 1.0
