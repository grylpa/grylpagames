extends HBoxContainer

func _ready() -> void:
	MainGlobals._action_buttons_scene = self

var action_button_scene = preload("res://scenes/action_button.tscn")

## Adds a new button with a given PNG path or Texture2D.
## @param image String (file path) or Texture2D
## @param button_size Vector2 to set button size and scale the icon
func add_button(_image, _button_size: Vector2 = Vector2.ZERO):
	if _image == null:
		for c in get_children():
			c.queue_free()
		return null

	# Load texture
	var tex: Texture2D = null
	if typeof(_image) == TYPE_STRING:
		tex = load(_image)
	elif _image is Texture2D:
		tex = _image

	var btn = action_button_scene.instantiate()
	if tex:
		btn.add_theme_color_override("icon_disabled_color", Color.WHITE)
		btn.add_theme_color_override("icon_focus_color", Color.WHITE)
		btn.add_theme_color_override("icon_hover_color", Color.WHITE)
		btn.add_theme_color_override("icon_pressed_color", Color.WHITE)

		# btn.flat = true                      # hide gray background
		btn.custom_minimum_size = _button_size       # force size
		btn.icon = tex
		btn.expand_icon = true               # scale PNG to fill button
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# optional: remove text margin so PNG truly fills
	btn.add_theme_constant_override("icon_max_width", int(_button_size.x))
	btn.add_theme_constant_override("icon_max_height", int(_button_size.y))

	# Force button size
	if _button_size != Vector2.ZERO:
		btn.custom_minimum_size = _button_size
	
	add_child(btn)
	return btn

