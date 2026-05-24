extends CanvasLayer

signal sig_clue_pressed
signal sig_fast_pressed
signal sig_slow_pressed
# signal sig_menu_pressed
signal sig_help_pressed
signal sig_zoom_pressed
signal sig_pause_pressed
signal sig_mute_pressed
signal sig_scores_pressed

# @onready var tex_mute = preload("res://art/mute.svg")
# @onready var tex_unmute = preload("res://art/unmute.svg")
@onready var tex_mute = preload("res://art/mute64.png")
@onready var tex_unmute = preload("res://art/unmute64_centered.png")

var button_audio := preload("res://art/sounds/tap-1.mp3")

@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		if is_inside_tree():
			_update_theme()

@export var scores_visible: bool = true:
	set(value):
		scores_visible = value
		if is_inside_tree():
			_update_theme()

@export var clue_visible: bool = true:
	set(value):
		clue_visible = value
		if is_inside_tree():
			_update_theme()

@export var fast_visible: bool = true:
	set(value):
		fast_visible = value
		if is_inside_tree():
			_update_theme()

@export var slow_visible: bool = true:
	set(value):
		slow_visible = value
		if is_inside_tree():
			_update_theme()

@export var menu_visible: bool = true:
	set(value):
		menu_visible = value
		if is_inside_tree():
			_update_theme()

# @export var help_visible: bool = true:
# 	set(value):
# 		help_visible = value
# 		if is_inside_tree():
# 			_update_theme()

@export var zoom_visible: bool = false:
	set(value):
		zoom_visible = value
		if is_inside_tree():
			_update_theme()

@export var mute_visible: bool = false:
	set(value):
		mute_visible = value
		if is_inside_tree():
			_update_theme()

@export var pause_visible: bool = true:
	set(value):
		pause_visible = value
		if is_inside_tree():
			_update_theme()


@onready var buttons_node := %HBoxContainer

var _scores_badge: Panel
var _new_best_pending := false

var _hamburger_icon: Texture2D = preload("res://art/hamburger.svg")

func _ready() -> void:
	$ButtonAudio.stream = button_audio
	_setup_scores_badge()
	%MenuButton.text = ""
	%MenuButton.icon = _hamburger_icon
	%MenuButton.expand_icon = true
	%MenuButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_theme()

func _setup_scores_badge() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.5, 0.0, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_scores_badge = Panel.new()
	_scores_badge.add_theme_stylebox_override("panel", style)
	_scores_badge.size = Vector2(8, 8)
	_scores_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scores_badge.visible = false
	_scores_badge.z_index = 100
	%ScoresButton.add_child(_scores_badge)
	call_deferred("_reposition_badge")
	MainGlobals.sig_new_best_score.connect(_on_new_best_score)
	MainGlobals.sig_scores_viewed.connect(_on_scores_viewed)

func _reposition_badge() -> void:
	if not is_instance_valid(_scores_badge) or not is_instance_valid(%ScoresButton):
		return
	var btn_size: Vector2 = %ScoresButton.size
	_scores_badge.position = Vector2(btn_size.x - 10, 2)

func _on_new_best_score() -> void:
	_new_best_pending = true
	_update_badge()

func _on_scores_viewed() -> void:
	_new_best_pending = false
	_update_badge()

func _update_badge() -> void:
	if is_instance_valid(_scores_badge):
		_scores_badge.visible = _new_best_pending

func _update_theme():
	if !is_instance_valid(buttons_node):
		return

	%ClueButton.visible = clue_visible
	%FastButton.visible = fast_visible
	%SlowButton.visible = slow_visible
	%MenuButton.visible = menu_visible
	%HelpButton.visible = false #help_visible
	%ZoomButton.visible = zoom_visible
	%MuteButton.visible = mute_visible
	%PauseButton.visible = pause_visible
	%ScoresButton.visible = scores_visible
	_update_badge()

	var prop_names := [
		"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_disabled_color",
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]
	for child in buttons_node.get_children():
		if child is Button:
			# child.size_flags_vertical = Control.SIZE_EXPAND
			for prop_name in prop_names:
				child.add_theme_color_override(prop_name, text_color)
				
	if MainGlobals.is_mobile():
		set_button_font_size(70)
		buttons_node.add_theme_constant_override("separation", 8)
	else:
		set_button_font_size(40)
		buttons_node.add_theme_constant_override("separation", 8)

func set_button_font_size(size: int) -> void:
	for child in buttons_node.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", size)
			# child.add_theme_constant_override("icon_max_width", size*5)
			# child.add_theme_constant_override("icon_max_height", size*5)
			child.custom_minimum_size.y = size# + 12
			child.custom_minimum_size.x = size# + 12
			# for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			# 	var sb = child.get_theme_stylebox(state)
			# 	if sb and sb is StyleBoxFlat:
			# 		var copy := sb.duplicate() as StyleBoxFlat
			# 		copy.content_margin_top = 10
			# 		copy.content_margin_bottom = 10
			# 		child.add_theme_stylebox_override(state, copy)

func _on_clue_button_pressed() -> void:
	$ButtonAudio.play()
	sig_clue_pressed.emit()
	MainGlobals.sim_action("clue")

func _on_pause_button_pressed() -> void:
	$ButtonAudio.play()
	sig_pause_pressed.emit()
	MainGlobals.sim_action("pause")

func _on_menu_button_pressed() -> void:
	$ButtonAudio.play()
	_on_help_button_pressed()
	# sig_menu_pressed.emit()
	# MainGlobals.sim_action("mainmenu")

func _on_fast_button_pressed() -> void:
	$ButtonAudio.play()
	sig_fast_pressed.emit()
	MainGlobals.sim_action("faster")

func _on_slow_button_pressed() -> void:
	$ButtonAudio.play()
	sig_slow_pressed.emit()
	MainGlobals.sim_action("slower")

func _on_help_button_pressed() -> void:
	$ButtonAudio.play()
	sig_help_pressed.emit()
	MainGlobals.ignore_keyboard_actions = false
	MainGlobals.sim_action("help")

func _on_zoom_button_pressed() -> void:
	$ButtonAudio.play()
	sig_zoom_pressed.emit()
	MainGlobals.sim_action("zoom")

func set_buttons(buttons_str_or_arr, _text_color: Color = Color.YELLOW):
	if buttons_str_or_arr is String:
		var buttons = buttons_str_or_arr
		var lbuttons = buttons.to_lower()
		clue_visible = "c" in lbuttons
		fast_visible = "f" in lbuttons
		slow_visible = "l" in lbuttons
		menu_visible = "m" in lbuttons or "h" in lbuttons
		# help_visible = "c" in lbuttons
		zoom_visible = "z" in lbuttons
		mute_visible = "t" in lbuttons
		pause_visible = "p" in lbuttons
		scores_visible = "o" in lbuttons
	else:
		var lbuttons:Array = buttons_str_or_arr
		for i in range(lbuttons.size()):
			lbuttons[i] = lbuttons[i].to_lower()
		clue_visible = "clue" in lbuttons
		fast_visible = "fast" in lbuttons
		slow_visible = "slow" in lbuttons
		menu_visible = "menu" in lbuttons or "help" in lbuttons
		# help_visible = "c" in lbuttons
		zoom_visible = "zoom" in lbuttons
		mute_visible = "mute" in lbuttons
		pause_visible = "pause" in lbuttons
		scores_visible = "scores" in lbuttons
	text_color = _text_color
	_update_theme()

func _on_mute_button_pressed() -> void:
	$ButtonAudio.play()
	sig_mute_pressed.emit()
	MainGlobals.sim_action("mute")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		%MuteButton.icon = tex_unmute if MainGlobals.mute else tex_mute

func _on_scores_button_pressed() -> void:
	$ButtonAudio.play()
	sig_scores_pressed.emit()
	MainGlobals.sim_action("scores")
