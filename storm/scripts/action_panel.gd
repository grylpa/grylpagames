extends PanelContainer

var game = null
const disabled_color:Color = Color(1,1,1,0.2)

func _ready() -> void:
	game = StormG.game

# `tool_name` and `fill` are for the five tools StormToolArt draws; `fill` is 0..1 of that tool's
# own capacity. `level` is the old shader's raw level, still used by anything left on a texture.
func init(box_w, sep, swatch_color:Color, text:String = "", count_text:String = "", textures: Array = [], level: float = 0,
		tool_name: String = "", fill: float = 0.0):
	game = StormG.game
	set_custom_minimum_size(Vector2(box_w + 2*sep, box_w + 2*sep))
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color.TRANSPARENT
	sbs.set_border_width_all(sep)
	# sbs.border_color = Color.TRANSPARENT#Color(0.1, 0.1, 0.1, 0)
	sbs.border_color = Color(0.9, 0.9, 0.4, 1.0)
	add_theme_stylebox_override("panel", sbs)

	var swatch = %Swatch
	swatch.modulate = swatch_color
	swatch.set_custom_minimum_size(Vector2(box_w, box_w))

	if StormToolArt.draws(tool_name):
		%Texture.texture = null
		%Texture.visible = false
		var drawn: Control = Control.new()
		drawn.custom_minimum_size = Vector2(box_w, box_w)
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawn.draw.connect(func() -> void:
			StormToolArt.draw_tool(drawn, tool_name, drawn.size * 0.5, minf(drawn.size.x, drawn.size.y) * 0.92, fill))
		add_child(drawn)
		move_child(drawn, %Texture.get_index() + 1)
	elif textures.size() > 0:
		%Texture.texture = textures[0]
		%Texture.visible = true
		%Texture.material = %Texture.material.duplicate()
		var mat = %Texture.material as ShaderMaterial
		mat.set_shader_parameter("mask_tex", textures[1] if textures.size() > 1 else textures[0])
		mat.set_shader_parameter("fill_amount", level)
	else:
		%Texture.texture = null
		%Texture.visible = false

	if count_text.is_empty():
		%Texture.set_custom_minimum_size(Vector2(box_w - 4, box_w - 4))
	else:
		%Texture.set_custom_minimum_size(Vector2(box_w * 3 / 4, box_w * 3 / 4))

	if text.length() > 0:
		%Text.visible = textures.size() == 0
		%Text.text = text
	else:
		%Text.hide()

	if count_text.length() > 0:
		%CountText.show()
		%CountText.text = count_text
		if count_text.is_valid_int():
			var count = count_text.to_int()
			if count == 0:
				%Text.modulate = disabled_color
				%Texture.modulate = disabled_color
	else:
		%CountText.hide()

	return swatch
