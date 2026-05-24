extends Node2D

signal card_pressed(p, card_id)

var board_pos: Vector2
var id := 0
var use_transparent_label := false
var push_texture_above_label := false
var scale_factor := 1.0

@onready var texture_rect = %Texture
@onready var label = %LabelTransparent if use_transparent_label else %Label
@onready var container = $Container
@onready var global_mc: MarginContainer = %GlobalMarginContainer

var _base_height: float = 0.0

func unscaled_size() -> Vector2:
	return global_mc.size

func scaled_size() -> Vector2:
	return unscaled_size() * scale_factor

func set_card_position(p: Vector2):
	# p.x -= scaled_size().x / 2.0
	position = p

func set_width(width: float):
	scale_factor = width / unscaled_size().x
	scale = Vector2(scale_factor, scale_factor)

func set_id(_id):
	id = _id
	_set_texture(FriendsG.get_person_image(id))

func _ready():
	# await get_tree().process_frame
	var label_h:float = label.get_minimum_size().y
	_base_height = global_mc.size.y - label_h

	%CenterLabel.hide()
	_set_texture(FriendsG.get_person_image(id))
	%NinePatchRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Texture.mouse_filter = Control.MOUSE_FILTER_IGNORE	
	label = %LabelTransparent if use_transparent_label else %Label
	# label.text = FriendsG.get_person_name(id)
	label.text = FriendsG.first_name(FriendsG.get_person_name(id))
	# label.visible = true
	if !use_transparent_label and push_texture_above_label:
		%MarginContainer.add_theme_constant_override("margin_bottom", 16)

func show_label(v: bool) -> void:
	if is_inside_tree():
		label.visible = v
		_update_height()

func _update_height() -> void:
	await get_tree().process_frame
	var label_h:float = label.get_minimum_size().y if label.visible else 0.0
	var new_h := _base_height + label_h

	var s := global_mc.size
	s.y = new_h
	global_mc.size = s

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:        
		if event.pressed:
			modulate = Color(0.9, 0.9, 0.9) # Slight dim effect on press
		else:
			modulate = Color.WHITE
			card_pressed.emit(board_pos, id)
			get_tree().root.set_input_as_handled()

func _set_texture(card_texture):
	if is_inside_tree() and texture_rect and card_texture:
		texture_rect.texture = card_texture
		%CenterLabel.text = str(id)
		label.text = FriendsG.first_name(FriendsG.get_person_name(id))
