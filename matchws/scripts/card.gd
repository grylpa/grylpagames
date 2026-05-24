extends Node2D

signal card_pressed(p, card_id)
signal card_reached_bottom(p, card_id)
signal card_below_bottom(p, card_id)
signal card_double_clicked(p, card_id)

var id := 0
var word_index := 0
var clicked_correct := false
var clicked_incorrect := false
var clickable := true
var should_be_clicked := false
var moving := false
var second_batch := false

var rot_dir := 1.0
var rot_speed := 100.0
var rot_max_deg := 10.0
var fall_speed := 20.0
var move_duration_ms := 0
var stop_duration_ms := 0
var time_started_move_ms := 0
var time_started_stop_ms := 0
var sent_moved_to_bottom := false
var sent_moved_below_bottom := false
var time_to_show := 0
var cardtext := ""
var texthidden := false

func _ready() -> void:
	# var sz = MainGlobals.get_viewport_size()
	# var w = int(sz.x / 4.0)
	# var h = 4
	# set_card_size(Vector2(w, h))
	var rng = RandomNumberGenerator.new()	
	rot_speed = rng.randf_range(50, 150)
	rot_dir = rng.randi_range(0,1)*2-1
	rot_max_deg = rng.randf_range(4,7)
	time_started_stop_ms = MainGlobals.timems()

func _process(delta: float) -> void:
	if _waiting_for_long_press and _is_down and MainGlobals.timems() - _time_started_down_ms > 500:
		card_double_clicked.emit(position, id)
		card_pressed.emit(position, id)
		_waiting_for_long_press = false
		_is_down = false

	if time_to_show > 0:
		var t = MainGlobals.timems()
		if t >= time_to_show and texthidden:
			%CardLabel.set("theme_override_colors/font_color",Color(0,0,0))
			time_to_show = 0
			texthidden = false
		elif !texthidden:
			texthidden = true
			%CardLabel.set("theme_override_colors/font_color",Color(1,1,1))

	if MatchwsG.game.paused():
		return

	var canmove = moving and not MatchwsG.level_done
	if canmove:
		var now = MainGlobals.timems()
		if time_started_move_ms > time_started_stop_ms:
			canmove = true
			if now - time_started_move_ms > move_duration_ms:
				canmove = false
				time_started_stop_ms = now
		else:
			canmove = false
			if now - time_started_stop_ms > stop_duration_ms:
				canmove = true
				time_started_move_ms = now
		
	# if MatchwsG.paused() or MatchwsG.level_done:
	# 	canmove = false

	var r = get_bounding_rect()
	# var inviewport = MainGlobals.rect_above_bottom(r)
	var inviewport = r.position.y + r.size.y < MatchwsG.bottom
	if !inviewport and moving:
		_moved_to_screen_bottom()
		# if abs(rotation) > deg_to_rad(1.0):
		# rot_dir = -sign(rotation)
	# if MainGlobals.rect_below_bottom(r):
	if r.position.y > MatchwsG.bottom and moving:
		_moved_below_screen_bottom()

	if canmove:
		position.y += delta * fall_speed
	
	if MatchwsG.speed_mode:
		rotation = 0
	else:
		# var speed = rot_speed * ((abs(rad_to_deg(abs(rotation)) - rot_max_deg) / rot_max_deg) + 0.2)
		var speed = rot_speed
		rotation += rot_dir * delta * speed / 1000.0
		if rotation >= deg_to_rad(rot_max_deg):
			rot_dir = -1.0
		elif rotation <= -deg_to_rad(rot_max_deg):
			rot_dir = 1.0

func set_fast_speed():
	calc_speed(0.5)

func calc_speed(timeout_sec: float):
	var sz = MainGlobals.get_viewport_size()	
	var nsteps = 1
	var full_step_time_ms = int(timeout_sec * 1000.0 / nsteps)
	move_duration_ms = int(full_step_time_ms / 1)
	stop_duration_ms = full_step_time_ms - move_duration_ms
	if nsteps == 1:
		move_duration_ms *= 4
	fall_speed = float(sz.y * 2.0) / float(move_duration_ms * nsteps / 1000.0)

func get_bounding_rect():		
	var inflate := !MatchwsG.speed_mode
	# var rect = $PanelContainer.get_rect()
	var rect = %CardLabel.get_rect()
	if inflate:
		rect = rect.grow_individual(0,0,40,40)
	rect.position -= rect.size/2
	# var sz = $PanelContainer.get_size()	
	# Log.dbg(rect.size,sz,label_rect.size)
	rect.position += position
	return rect

func set_min_size(sz: Vector2):
	%CardLabel.custom_minimum_size = sz
	$PanelContainer.custom_minimum_size = sz
	
func set_card_size(sz: Vector2):
	# Vector2 textSize = %CardLabel.GetThemeDefaultFont()#.GetMultilineStringSize("text", HorizontalAlignment.Center, MaxLabelWidth)
	%CardLabel.set_custom_minimum_size(sz - Vector2(8,8))
	$PanelContainer.custom_minimum_size = sz
		
func make_bold():
	%CardLabel.add_theme_constant_override("outline_size",1)

func set_font_size(fsz: int = 24):
	%CardLabel.add_theme_font_size_override("font_size",fsz)

func get_text():
	return %CardLabel.text

func set_card_data(_id, _text, color, _clickable, _should_be_clicked, _word_index, _moving):
	cardtext = MainGlobals.cap_first_word(_text)
	id = _id
	word_index = _word_index
	clickable = _clickable
	should_be_clicked = _should_be_clicked
	# %CardLabel.text = _text	+ "\n" + _text + "\n" + _text
	%CardLabel.text = cardtext
	# var stylebox := $CardBorder.get_theme_stylebox("panel") as StyleBoxFlat
	# if stylebox:
	# 	stylebox.bg_color = color
	_set_color(color)
	moving = _moving

func _set_color(color):
	modulate = color
	# var original := %CardLabel.get_theme_stylebox("normal") as StyleBoxFlat
	# if original:
	# 	var unique_style := original.duplicate() as StyleBoxFlat
	# 	unique_style.bg_color = color
	# 	%CardLabel.add_theme_stylebox_override("normal", unique_style)
	# # var original := $CardBorder.get_theme_stylebox("panel") as StyleBoxFlat
	# # if original:
	# # 	var unique_style := original.duplicate() as StyleBoxFlat
	# # 	unique_style.bg_color = color
	# # 	$CardBorder.add_theme_stylebox_override("panel", unique_style)

var _is_down := false
var _time_started_down_ms := 0.0	
var _waiting_for_long_press := false

func _input(e):
	if clickable and !texthidden and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var r = get_bounding_rect()
		if !r.has_point(e.position):
			return
		if !e.pressed:
			if _is_down:
				card_pressed.emit(position, id)				
			_is_down = false
			_waiting_for_long_press = false
		if e.double_click:
			card_double_clicked.emit(position, id)

# func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
# 	if event.is_action_pressed("lclick") and clickable and !texthidden:
# 		card_pressed.emit(position, id)

func clicked():
	if should_be_clicked:
		_set_color(Color(0.5,1,0.5))
	else:
		_set_color(Color(1,0.4,0.4))

func hide_color():
	_set_color(Color(1,1,1))

func _on_card_label_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("lclick") and clickable and !texthidden:
		if _is_down and MainGlobals.timems() - _time_started_down_ms > 500:
			card_double_clicked.emit(position, id)
		elif !_is_down:
			_time_started_down_ms = MainGlobals.timems()
			_is_down = true
			_waiting_for_long_press = true
		# card_pressed.emit(position, id)

func _moved_to_screen_bottom():
	if !sent_moved_to_bottom and !MatchwsG.level_done:
		card_reached_bottom.emit(position, id)
		sent_moved_to_bottom = true

func _moved_below_screen_bottom():
	if !sent_moved_below_bottom and !MatchwsG.level_done:
		card_below_bottom.emit(position, id)
		sent_moved_below_bottom = true
