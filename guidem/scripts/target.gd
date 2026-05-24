extends Area2D

var id := 1
var destination_type := 0
var color

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id, show_id=false, _destination_type=0):
	id = _id
	destination_type = _destination_type
	$TargetText.text = str(id)
	$TargetText.visible = show_id
	$TargetImage.visible = destination_type == 0
	$DestinationImage.visible = destination_type > 0
	# $DestinationImage.set_modulate(color)
	
func set_img_rot(rot):
	$TargetImage.rotation = rot
	$DestinationImage.rotation = rot+PI
