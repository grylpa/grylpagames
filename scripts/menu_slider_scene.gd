extends HBoxContainer

signal value_changed(_id, _value)

var is_bool := false
var yes_no_strs = ["No", "Yes"]
var id := 0
var _label_min_width: float = 0.0

func _ready() -> void:
	var lbl_style: StyleBoxFlat = StyleBoxFlat.new()
	lbl_style.bg_color = Color(1, 1, 1, 0.313726)
	lbl_style.border_width_left = 6
	lbl_style.border_width_top = 6
	lbl_style.border_width_right = 6
	lbl_style.border_width_bottom = 6
	lbl_style.border_color = Color(0, 0.0627451, 0, 1)
	lbl_style.border_blend = true
	lbl_style.corner_radius_top_left = 8
	lbl_style.corner_radius_top_right = 8
	lbl_style.corner_radius_bottom_left = 8
	lbl_style.corner_radius_bottom_right = 8
	lbl_style.content_margin_left = 4.0
	lbl_style.content_margin_right = 4.0
	$Label.add_theme_stylebox_override("normal", lbl_style)
	$Label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_value_no_signal(0)

func init(_id, _min_val, _max_val, _is_bool := false):
	id = _id
	is_bool = _is_bool
	if is_bool:
		$HSlider.max_value = 1
		$HSlider.min_value = 0
	else:
		$HSlider.max_value = _max_val
		$HSlider.min_value = _min_val
	var candidates: Array = ["Yes", "No"] if is_bool else [str(int(_min_val)), str(int(_max_val))]
	var font: Font = $Label.get_theme_font("font")
	var fs: int = $Label.get_theme_font_size("font_size")
	var max_w: float = 0.0
	for c in candidates:
		max_w = maxf(max_w, font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	_label_min_width = ceil(max_w) + 20
	$Label.custom_minimum_size = Vector2(_label_min_width, 40)
	$Label.update_minimum_size()
	_update(_min_val)

func get_label_min_width() -> float:
	return _label_min_width

func set_label_min_width(w: float) -> void:
	_label_min_width = w
	$Label.custom_minimum_size = Vector2(w, 40)
	$Label.update_minimum_size()
	$Label.queue_redraw()

func set_yes_no(str_array:Array):
	yes_no_strs = str_array

func _on_h_slider_drag_ended(_value_changed:bool) -> void:
	var val = $HSlider.value
	_update(val)
	value_changed.emit(id,val)

func set_value_no_signal(_val):
	var cval = clamp(_val, $HSlider.min_value, $HSlider.max_value)
	$HSlider.set_value_no_signal(cval)
	_update(_val)

func _on_h_slider_value_changed(_val:float) -> void:
	_update(_val)

func _update(_val):
	if is_bool:
		$Label.text = yes_no_strs[1] if _val > 0.5 else yes_no_strs[0]
	else:
		$Label.text = str(roundi(_val))
