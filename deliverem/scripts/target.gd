extends Area2D

var id := 1

func _ready() -> void:
	pass # Replace with function body.

func set_id(_id):
	id = _id
	$TargetText.text = str(id)
	
func set_img_rot(rot):
	$TargetImage.rotation = rot
