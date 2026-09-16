extends Node

# Ants orchestrator. The standard skeleton from how_to_add_a_new_game.txt.
#
# The score IS the allowance: initial_score is the level's, every crumb the colony gets home takes
# one off it, and a crushed ant takes KILL_PENALTY. game_over_on_zero_score ends the round when the
# colony has had what it came for; outlasting the clock is the win, which is why
# game_over_on_time_out is off and sig_time_over is taken instead.
#
# This was a simulation with nothing to measure for most of its life, and the HUD counter was fed
# through add_score_and_time(..., is_actual_score = false) so that no session would ever write a
# row. It scores for real now -- the columns below, and the matching SUMMARY_ROWS entries in
# scripts/game_instrument.gd.

# The top strip's icons are 32 px boxes in the shared HUD scene -- lives, packets and the paired
# counters alike. The ant is baked bigger for a clean edge and scaled down to match.
const HUD_ICON_PX: int = 32

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = AntsG.game
	# Running out of time is how you WIN here, not how you lose, so the HUD must not end the game
	# on it -- sig_time_over is taken below instead. Losing is the colony getting its allowance
	# home, which is the score reaching zero.
	game.game_over_on_time_out = false
	game.game_over_on_zero_score = true
	game.sig_time_over.connect(_on_time_over)
	game.score_columns = ["didwin", "aborted", "level", "crumbs_through", "ants_killed"]

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3a2e24ff))
	AntsG.init_globals()
	AntsG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", AntsLevelConfig.level_names())
	refresh_menu()
	show_main_menu()

	hud.set_game(game)
	hud.show()
	# One number: ants crushed. Crushing is not the job and it costs five times a crumb, and nothing
	# said so until the score dropped and the player was left to work out which of the two things
	# that just happened had done it. Color.WHITE so the ant keeps its own colors instead of the
	# strip's yellow tint -- a yellow ant on pale soil is the one icon nobody can see.
	# set_lives_icon sizes the box as TEXTURE SIZE x scale, and the icon is baked at 64 px, so a
	# scale of 1 makes it twice the 32 px every other icon on the strip is.
	hud.set_lives_icon(AntsG.ant_icon(), Vector2.ONE * (float(HUD_ICON_PX) / float(AntsG.ICON_PX)),
		Color.WHITE)
	hud.show_tally(func() -> int: return $Level.ants_killed())
	hud.update_all()

	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)

	$Help.set_texts({"N": "New game", "M": "Main menu"})
	$Help.close_help.connect(_on_help_close_help)

	game.set_instructions("Ants",
		"A colony is carrying food home. Keep it out.\n" +
		"Tap the ground to pick a tool, and HOLD a tool\n" +
		"to see what it does.\n" +
		"You have only a few of each, so tap something you\n" +
		"already placed to pick it up and use it again.\n" +
		"Block them and they wear a new road around it — so\n" +
		"watch where that is forming and get there first.\n" +
		"Every crumb that reaches the nest costs you.\n" +
		"Do not drop anything on an ant.\n" +
		"Drag to look around when the world is larger than the screen.", 23)
	if not game.shown_instructions:
		game.show_instructions(self)
		AntsG.save_settings()

	main_menu.show_continue_and_start_new(false)

	# Teach instead of showing the menu when the player asked for the tutorial from the chooser's
	# "How to play", OR when this is their first ever run. MUST stay at the end of _ready, after
	# show_instructions above: that call's suppression guard asks whether a tutorial is pending, so
	# consuming the flag earlier lets the text wall through.
	if MainGlobals.take_pending_tutorial("ants") \
			or MainGlobals.take_auto_tutorial("ants", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://ants/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level lives on AntsG, not the game util, so the snapshot does not cover it.
	_tutorial_saved_level = AntsG.starting_level_id
	AntsG.starting_level_id = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The caption must not sit on the nest or the pile, which is what most of it talks about.
	# What the coach must never sit on. The tool menu goes in CELL BY CELL: the runner only moves a
	# caption once it buries half of a zone, and a caption across the bottom row of tools covers
	# barely a third of the ring as a whole.
	runner.keep_clear = [
		func(): return $Level.tutorial_nest_rect(),
		func(): return $Level.tutorial_pile_rect(),
		func(): return $Level.tutorial_last_placed_rect(),
	]
	for i in 8:
		var idx: int = i
		runner.keep_clear.append(func(): return $Level.tutorial_menu_cell(idx))
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback, so the stashed level would stay applied.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_level >= 0:
		AntsG.starting_level_id = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

func show_main_menu() -> void:
	main_menu.show_continue_and_start_new(false)

	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])
	MainGlobals.add_action_button(null)

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help", "mute"])
	MainGlobals.add_action_button(null)

func new_game(from_scratch: bool = true) -> void:
	if from_scratch:
		_did_per_level_save = false
	_time_over = false
	show_level()
	hud.new_game(from_scratch)
	# The allowance is the starting score and it is per level, so it has to be set before reset()
	# copies it into the score.
	game.initial_score = int(AntsLevelConfig.get_level(AntsG.starting_level_id)["allowance"])
	if game.tutorial_mode:
		# A coached run must not be able to lose while the coach is still talking -- and the lesson
		# about the road re-forming takes a minute of real colony time to land.
		game.initial_score = 100000
	game.reset(from_scratch)
	$Level.new_game(from_scratch)
	hud.update_all()

# Surviving the clock is the win. The HUD emits this every tick once the time is gone, so it is
# taken exactly once.
var _time_over: bool = false

func _on_time_over() -> void:
	if _time_over or not game.playing:
		return
	_time_over = true
	game.game_is_done(true, false)

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _on_level_sig_level_is_done(didwin: bool) -> void:
	if game.playing:
		game.game_is_done(didwin, false)

func _on_main_menu_start_game(_start_new: bool) -> void:
	AntsG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		AntsG.starting_level_id = AntsLevelConfig.LEVELS[idx]["id"]
		AntsG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

# The saved row. Must stay in step with score_columns above and with SUMMARY_ROWS in
# scripts/game_instrument.gd, which is what names these two numbers on the summary.
func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.current_level_id,
		$Level.crumbs_through, $Level.ants_killed()]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	# The round is over, so nothing more is scored. Without this the level goes on taking crumbs off
	# an allowance that is already at zero, and each one calls straight back in here -- one probe
	# run drove thousands of end-of-round chains and slowed to a fiftieth of its speed.
	game.playing = false
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score() -> void:
	game.save_ongoing_score(get_game_score(false, false))

func _on_hud_start_game() -> void:
	new_game(true)

func _on_help_close_help() -> void:
	game.pause(false)
	$Help.hide()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, Callable(self, "new_game")):
		pass
	elif game.handle_main_menu(self, event, Callable(self, "_on_level_show_main_menu")):
		pass
	elif event.is_action_pressed("help"):
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			_on_help_close_help()
	else:
		game.handle_event(event, self)

func refresh_menu() -> void:
	main_menu.update_option(1, AntsLevelConfig.id_to_index(AntsG.starting_level_id))
