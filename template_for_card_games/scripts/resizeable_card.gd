extends Control

signal card_pressed(p, card_id)

var board_pos: Vector2
var id := 0
var show_label := true
var use_transparent_label := false
var push_texture_above_label := false

@onready var texture_rect = %Texture
@onready var label = %LabelTransparent if use_transparent_label else %Label

func set_center_position(center_pos: Vector2):
	var new_position = center_pos - size / 2.0
	position = new_position

func set_card_size(width: float, height: float):
	var s := 32
	size = Vector2(width - s, height - s)

func set_id(_id):
	id = _id
	# var cardidx = id % FriendsG.back_textures.size()
	# $CardBack.texture = load(FriendsG.back_textures[cardidx])

func _ready():
	_set_texture(FriendsG.get_person(id))
	%NinePatchRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_card_size(100, 150)
	if show_label:
		label = %LabelTransparent if use_transparent_label else %Label
		label.show()
		if !use_transparent_label and push_texture_above_label:
			%MarginContainer.add_theme_constant_override("margin_bottom", 16)

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
