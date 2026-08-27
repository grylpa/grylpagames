extends Node

# Dev-only preview of the end-of-game screen — the banner and the Restart button, which are
# otherwise only reachable by actually losing a game.
#
#   godot --path . res://dev/preview_game_over.tscn
#
# SPACE / click / tap  replays it, alternating "Game Over" and "You Finished!".
# Nothing in the app references this folder; delete it whenever.

var _hud: Node = null
var _game: GenericGameUtil = null
var _win: bool = false

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	_game = GenericGameUtil.new("Preview", "preview_game_over", 0, 2, 0)
	_game.tutorial_mode = true   # never write a score file from the preview

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.11, 0.13, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hint: Label = Label.new()
	hint.text = "SPACE or tap: replay  ·  alternates lose / win"
	hint.add_theme_font_override("font", MainGlobals.get_text_font())
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(float(MainGlobals.screen_size.x) * 0.5 - 190.0, 8.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_hud = load("res://scenes/generic_game_hud.tscn").instantiate()
	add_child(_hud)
	_hud.set_game(_game)
	_hud.show()
	_hud.show_corrects_mistakes()
	# something on the clock and the counters, so the screen is not empty behind the banner
	_game.score = 1240
	_game.corrects = 18
	_game.mistakes = 4
	_hud.update_all()
	await get_tree().process_frame
	_replay()

func _replay() -> void:
	_win = not _win
	_hud.set("game_already_over", false)
	_hud.get_node("Panel").hide()
	_hud.get_node("Message").hide()
	_hud.get_node("Message").scale = Vector2.ONE
	_hud.get_node("Message").rotation = 0.0
	_hud.get_node("StartButton").hide()
	_hud.get_node("StartButton").modulate.a = 1.0
	_hud.call("game_over", _win, false)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_replay()
