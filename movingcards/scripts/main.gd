extends Node

var game: GenericGameUtil
var main_menu

func _ready() -> void:
	game = MovingCardsG.game
	$HUD.set_game(game)
	$HUD.set_message_transparent_bg(true)
	# The counters the level is graded on, so the player can see where they stand against the
	# pass threshold instead of finding out on the summary card.
	$HUD.show_corrects_mistakes()
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
	$HUD.new_game(from_scratch)
	$HUD.update_all()
	MovingCardsG.reset()
	$Level.new_game(from_scratch)

# The level is over — the card says whether it was passed, and play resumes when it is closed.
# This game had no such moment at all: a level ended by silently becoming the next one.
func _on_level_sig_level_is_done(passed: bool, pct: int, bonus: int) -> void:
	if passed:
		game.add_score_and_time(bonus, 0)
	$HUD.update_all()
	game.save_ongoing_score([])
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	_last_level_passed = passed
	var need: int = int($Level.current_level_cfg.get("pass_pct", 66))
	var body: String = "\n\nAccuracy: %d%%\nCards this level: %d\n\n%s" % [
		pct, int($Level.num_cards), _progress_line(passed, need)]
	# A failed level earns nothing: the row saved here holds the kept score, and the screen keeps
	# showing what the player had while playing until they press Continue.
	if not passed:
		var earned: int = game.score
		game.score = $Level.score_at_level_start()
		game.save_score(get_game_score(passed, false))
		game.score = earned
		$Level.mark_score_rollback()
	else:
		game.save_score(get_game_score(passed, false))
	game.show_level_done_popup(self, "", body, $Level.level_name(), "", passed)

func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	if $Level.is_last_level():
		return "Level passed."
	return "Level passed — on to level %d." % ($Level.level_name() + 1)

var _last_level_passed: bool = false

func _on_level_done_popup_closed() -> void:
	$Level.continue_after_level(_last_level_passed)

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

func _on_level_sig_can_start_clicking() -> void:
	MovingCardsG.game.playing = true


# The level's instruction line ("ORDER: 3,1,2", "Wrong!"), shown the way deliverem and delemfp
# show theirs — hud.dispatch, the shared top strip. An empty text means "clear it".
func _on_level_sig_message(text: String, autohide: bool) -> void:
	if text == "":
		$HUD.hide_dispatch()
	else:
		$HUD.dispatch(text, autohide)

func _on_level_update_score(_score: int) -> void:
	game.add_score_and_time(_score, 0)
	$HUD.update_all()

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
