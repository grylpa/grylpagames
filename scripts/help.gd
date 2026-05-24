extends CanvasLayer

signal close_help
signal help_key(key)

@onready var grid = %GridContainer

@export var label_scene: PackedScene = load("res://scenes/help_label.tscn")
@export var btn_scene: PackedScene = load("res://scenes/help_button.tscn")
@export var btn_label_scene: PackedScene = load("res://scenes/help_button_label.tscn")

var def_help_text = {
	# "G": "Change Game",
	"I": "Instructions",
	"M": "Main Menu",
	# "T": "Mute/Un-Mute",
	# "H,?": "help",
}

var help_text
var just_closed := false

func _ready():
	if MainGlobals.is_mobile():
		grid.add_theme_constant_override("v_separation", 40)

func set_texts(_help_text, add_def: bool = true):
	help_text = _help_text.duplicate()
	if not MainCfg.single_game:
		def_help_text["G"] = "Change Game"

	if add_def:
		help_text.merge(def_help_text)
	for key in help_text.keys():
		add_help_label(key, help_text[key])

func add_help_label(key: String, text: String) -> void:
	var key_label = btn_scene.instantiate()
	var text_label = btn_label_scene.instantiate()
	key_label.text = key.to_upper()
	text_label.text = text
	grid.add_child(key_label)
	grid.add_child(text_label)
	key_label.connect("pressed", self._on_button_pressed.bind(key))
	text_label.connect("pressed", self._on_button_pressed.bind(key))

func _on_close_button_pressed() -> void:
	just_closed = true
	hide()
	close_help.emit()

func sim_action(act):
	MainGlobals.sim_action(act)
	# var e = InputEventAction.new()
	# e.action = act
	# e.pressed = true
	# Input.parse_input_event(e)

	# # e = InputEventAction.new()
	# # e.action = act
	# # e.pressed = false
	# # Input.parse_input_event(e)
	
func _on_button_pressed(key):
	help_key.emit(key)
	_on_close_button_pressed()
	match key:
		"G": 
			if not MainCfg.single_game:
				sim_action("change game")
			# MainGlobals.sig_stop_active_game.emit()	
		"N":
			sim_action("new_board")
		"M":
			sim_action("mainmenu")
		"P":
			sim_action("pause")
		"F":
			sim_action("faster")
		"L":
			sim_action("slower")
		"C":
			sim_action("clue")
		"R":
			sim_action("reminder")
		"Z":
			sim_action("zoom")
		"T":
			sim_action("mute")
		"I":
			sim_action("instructions")
		# "H,?":
		# 	_on_close_button_pressed()
		# "H":
		# 	_on_close_button_pressed()
		# "?":
		# 	_on_close_button_pressed()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I:
			sim_action("instructions")

func is_just_closed():
	var j = just_closed
	just_closed = false
	return j

func _on_x_close_scene_button_pressed() -> void:
	_on_close_button_pressed()

func _on_visibility_changed() -> void:
	MainGlobals.set_visible("help",visible)
