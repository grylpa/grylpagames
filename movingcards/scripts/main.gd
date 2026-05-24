extends Node

var game: GenericGameUtil
var main_menu

func _ready() -> void:
	game = MovingCardsG.game
	$HUD.set_message_transparent_bg(true)
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0xFF8A5CFF))
	MovingCardsG.load_settings()
	main_menu = game.create_main_menu(self)
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, MovingCardsLevelConfig.LEVELS.size(), false)
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"C": "Clue",
		"N": "New game",
	})
	$Help.close_help.connect(_on_help_close_help)

	game.add_sound(self, "tap", preload("res://art/sounds/tap-1.mp3"))
	game.add_sound(self, "correct", preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg"))
	game.add_sound(self, "wrong", preload("res://art/sounds/swoosh.mp3"))

	game.set_instructions("Moving Cards",
		"Remember the cards and the order you need to click\n\n" +
		"The cards will move — follow them!\n\n" +
		"Click the cards in the order shown")
	if !game.shown_instructions:
		game.show_instructions(self)
		MovingCardsG.save_settings()

func show_main_menu() -> void:
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar("hto")

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar("htc")

func new_game(from_scratch: bool = true) -> void:
	show_level()
	if from_scratch:
		game.score = 0
		game.score_was_changed = false
	$HUD.new_game()
	$HUD.update_score(game.score, 0)
	MovingCardsG.reset()
	$Level.new_game(from_scratch)

func _on_level_sig_level_is_done(didwin: bool, score_increment: int) -> void:
	if didwin:
		game.add_score_and_time(score_increment, 0)
		$HUD.update_score(game.score, 0)
		$HUD.game_over(true)
		game.save_ongoing_score([])

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	MovingCardsG.save_settings()
	new_game()

func get_game_score(_didwin: bool, _wasaborted: bool) -> Array:
	return [_didwin, _wasaborted, $Level.level]

func _on_level_show_main_menu() -> void:
	MovingCardsG.game.playing = false
	show_main_menu()
	game.save_score(get_game_score(false, true))

func close_help_window() -> void:
	MovingCardsG.game.pause(false)
	$Help.hide()

func _on_help_close_help() -> void:
	close_help_window()

func _on_level_show_help() -> void:
	if $Help.is_visible():
		close_help_window()
	else:
		$Help.show()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		close_help_window()

func _on_hud_help_button_pressed() -> void:
	$Help.show()

func _on_level_sig_can_start_clicking() -> void:
	MovingCardsG.game.playing = true

func _on_level_sig_message(text: String, autohide: bool) -> void:
	if text == null or text.is_empty():
		$HUD.hide_message()
	else:
		$HUD.disp(text, autohide)

func _on_level_update_score(_score: int) -> void:
	game.add_score_and_time(_score, 0)
	$HUD.update_score(game.score, 0)

func refresh_menu() -> void:
	main_menu.update_val(1, MovingCardsG.starting_level)

func on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		MovingCardsG.starting_level = roundi(val)
	MovingCardsG.save_settings()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, new_game):
		pass
	elif game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		_on_level_show_help()
	elif event.is_action_pressed("esc"):
		_on_level_pressed_esc()
	else:
		game.handle_event(event, self)
