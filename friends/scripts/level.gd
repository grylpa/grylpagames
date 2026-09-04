extends CanvasLayer

var game: GenericGameUtil

var max_difficulty := 6
var time_increased_difficulty_ms = 0
var level := 0
var num_corrects_for_next_level := 5
var num_corrects_in_level_so_far := 0

var num_friends := [3,0]	# per row

var cards = []
var times_to_answer := []

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

var card_size := Vector2i(100,150)
var new_person_size := Vector2i(150,225)

enum modes {DISPLAY_ALL_FRIENDS, DISPLAY_SOMEONE }
var mode = modes.DISPLAY_ALL_FRIENDS

var dtime_to_ignore_when_no_answer_ms := 4 * 1000
# True only while the grow-to-full-size timeout is driving the Ignore handler, so an unanswered
# arrival is recorded as "no answer" rather than as a deliberate Ignore.
var _auto_ignoring: bool = false
var dtime_to_show_all_friends_ms := 60 * 1000
var time_to_next_mode_ms = 0
var time_shown_new_person_ms = 0
var max_id_used := 1

const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")
const YELLOW: Color = Color(1, 0.8039216, 0, 1)  # friends card border color

var ambient_audios := [ 
	preload("res://art/sounds/ocean-waves-2.mp3"), 
	preload("res://art/sounds/ocean-waves-3.mp3"), 
	preload("res://art/sounds/ocean-waves-4.mp3")
]

signal started_playing
signal sig_level_is_done(didwin:bool)

var _bg: Control = null
var _bg_t: float = 0.0
var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false

# What the score was when this level began. A level that misses the gate gives its points
# back (see the level-done function): without that, failing forever is a way to earn forever
# — every attempt banked its points and the retry cost nothing.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false

func _ready() -> void:
	game = FriendsG.game
	game.sig_time_over.connect(on_time_over)
	level = FriendsG.starting_level
	increase_difficulty(false)
	_apply_look()

	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

	FriendsG.board_top = %Instructions.position.y + %Instructions.size.y + 30

# Cosmetics, plus the one thing that was not cosmetic: SAY HI is on the RIGHT now, because a right
# swipe and the right arrow are what say it. A button on the left labelled with the gesture that
# goes right is a trap, and the project has been caught by it before.
func _apply_look() -> void:
	var ground: TextureRect = $TextureRect
	ground.texture = null
	_bg = ScreenBackdrop.attach(ground)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void:
			ScreenBackdrop.draw(_bg, _bg_t, ScreenBackdrop.FRIENDS_TOP, ScreenBackdrop.FRIENDS_BOT,
				ScreenBackdrop.ACCENT))
	set_process(true)

	# [left spacer] Ignore [gap] Say Hi [right spacer]. Moving Ignore in front of Say Hi on its own
	# leaves the row's middle spacer stranded on the far side of the pair, so the two buttons end up
	# touching; the spacer is moved back between them.
	var row: HBoxContainer = $HBoxContainer
	var gap: Control = row.get_node_or_null("MarginContainer3") as Control
	row.move_child(%IgnoreButton, 1)
	if gap != null:
		row.move_child(gap, 2)
	row.add_theme_constant_override("separation", 18)
	%IgnoreButton.text = "\u2190  Ignore"
	%SayHiButton.text = "Say Hi  \u2192"
	var fs: int = 34 if MainGlobals.is_mobile() else 24
	GameButton.style(%IgnoreButton, ScreenBackdrop.ACCENT, ResultCard.HEADER_INK, fs, true)
	GameButton.style(%SayHiButton, ScreenBackdrop.ACCENT, ResultCard.HEADER_INK, fs)
	GameButton.style($ReadyButton, ScreenBackdrop.ACCENT, ResultCard.HEADER_INK, fs)
	ScreenBackdrop.style_caption(%Instructions)
	%CorrectText.add_theme_font_override("font", MainGlobals.get_text_font())
	%WrongText.add_theme_font_override("font", MainGlobals.get_text_font())

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()
	_tick_person()

# Right is Hi, left is Ignore — the same pairing the buttons are laid out in and the arrows point
# at. Both the arrow keys and a horizontal swipe say it.
func _input(event: InputEvent) -> void:
	# `answered_current_person` and not just the row's visibility: the row is hidden inside
	# answered(), but two events can arrive in the same frame before that happens.
	if answered_current_person or not $HBoxContainer.visible or not _can_play():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_tracking = true
		else:
			_swipe_tracking = false
	elif event is InputEventScreenDrag and _swipe_tracking:
		var delta: Vector2 = event.position - _swipe_start
		if delta.length() > 60.0:
			_swipe_tracking = false
			MainGlobals.swipe_was_drag = true
			if abs(delta.x) >= abs(delta.y):
				if delta.x > 0.0:
					_on_say_hi_button_pressed()
				else:
					_on_ignore_button_pressed()
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_on_say_hi_button_pressed()
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_on_ignore_button_pressed()

func new_game(from_scratch=true):
	# The failed level's points go back HERE, on Continue, together with everything else that is
	# cleared — so the summary card was still read against the score the player had while playing.
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	_score_at_level_start = game.score
	# A replay has to be a FRESH attempt. The gate reads these, so a retry that inherited the
	# misses which failed the level could not pass it even played perfectly; and the summary's
	# timing average would fold in the attempt the player is being made to redo.
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	game.level_is_ready = false
	if from_scratch:
		level = FriendsG.starting_level

	mode = modes.DISPLAY_ALL_FRIENDS
	FriendsG.back_textures.shuffle()
	FriendsG.shuffle_people()

	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	create_board()

	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")

	started_playing.emit()
	BE.upsert_game_state("Friends", 
		{"state":"new","starting_level": level})

func use_b12(b):
	return b == 1 or (b == 2 and game.rng.randi() % 2 == 0)

var new_person_card_pos := Vector2(0, 0)

func create_board() -> void:
	while !cards.is_empty():
		cards.pop_back().queue_free()

	var tmp_c = CARD_SCRIPT.new()
	add_child(tmp_c)
	tmp_c.fit = CARD_SCRIPT.Fit.COVER
	tmp_c.show_label(true)

	var card_w = MainGlobals.screen_size.x / 6
	if MainGlobals.is_mobile():
		card_w = MainGlobals.screen_size.x / 4 - 10

	tmp_c.set_width(card_w)
	await get_tree().process_frame
	var card_h = tmp_c.scaled_size().y

	tmp_c.show_label(false)
	await get_tree().process_frame
	tmp_c.set_width(card_w)
	var card_h_no_label = tmp_c.scaled_size().y

	tmp_c.queue_free()

	FriendsG.p_scale = Vector2(MainGlobals.screen_size.x / 4, card_h + 40)
	
	card_size = Vector2i(int(card_w), int(card_h))
	new_person_size = Vector2i(int(card_w * 2.0), int(card_h_no_label * 2.0))

	var top_of_bottom_card := 0
	var bottom := 0
	var id := 0
	var radd := 0#1 if num_friends[1] == 0 else 0
	for r in 2:
		var start:float = 0.5 - num_friends[r] / 2.0
		for c in num_friends[r]:
			var newcard = add_card_at(Vector2(start + c,r + radd), id)
			id += 1
			top_of_bottom_card = max(top_of_bottom_card, newcard.position.y)
	bottom = top_of_bottom_card + card_size.y
	max_id_used = id - 1

	$ReadyButton.show()
	var p = FriendsG.board_to_px(Vector2(0,0))
	p.y = bottom + 30
	p.x -= $ReadyButton.size.x/2
	$ReadyButton.position = p

	set_new_person_id(0)
	new_person_card.hide()
	$HBoxContainer.hide()
	await get_tree().process_frame
	p = FriendsG.board_to_px(Vector2(0,0))
	p.y = new_person_card.position.y + new_person_size.y + 30
	p.x -= $HBoxContainer.size.x/2
	$HBoxContainer.position = p

	%CorrectText.position.y = p.y
	%WrongText.position.y = p.y

	if new_person_card != null:
		new_person_card.hide()

	%Instructions.text = "These are your friends\nRemember them"

	$HBoxContainer.hide()
	%CorrectText.hide()
	%WrongText.hide()
	%Instructions.show()
	$ReadyButton.show()

	num_corrects_in_level_so_far = 0
	time_to_next_mode_ms = game.game_time + dtime_to_show_all_friends_ms

	game.level_is_ready = true

var new_person_card = null

func set_new_person_id(card_id: int):
	if new_person_card == null:
		new_person_card = CARD_SCRIPT.new()
		add_child(new_person_card)
		new_person_card.fit = CARD_SCRIPT.Fit.COVER
		new_person_card.set_width(new_person_size.x)
		new_person_card.set_card_position(FriendsG.board_to_px(new_person_card_pos))
	new_person_card.meta = card_id  # the guessed person shows no name
	new_person_card.setup(FriendsG.get_person_image(card_id), YELLOW)
	return new_person_card

func add_card_at(p: Vector2, card_id: int):
	var card = CARD_SCRIPT.new()
	add_child(card)
	card.fit = CARD_SCRIPT.Fit.COVER
	card.meta = card_id
	card.setup(FriendsG.get_person_image(card_id), YELLOW)
	card.set_label(FriendsG.first_name(FriendsG.get_person_name(card_id)))
	card.set_width(card_size.x)
	card.set_card_position(FriendsG.board_to_px(p))
	cards.append(card)
	return card

func find_card(card_id):
	for c in cards:
		if c.meta == card_id:
			return c
	return null

var last_major_tick := 0.0
var last_one_sec_tick := 0.0

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return
							
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):	
	game.level_is_done = true
	# The gate is decided BEFORE the level's score row is written: main.gd saves that row on
	# game.sig_level_is_done, and it has to carry the score the player actually KEEPS, or
	# failing the same level over and over is a way to farm the score list.
	#
	# Passing is a RESULT, not a formality: below this level's accuracy the SAME level comes
	# round again. The bar rises with the level, from 60% to at most 80%.
	var need: int = mini(60 + 5 * (level - 1), 80)
	var pct: int = game.session_pct_correct()
	var passed: bool = true
	if didwin and level < max_difficulty:
		passed = pct >= need
		_rollback_score_on_next_level = not passed
	if passed:
		game.sig_level_is_done.emit(didwin)
	else:
		# The kept value is put in place just for the save. The SCREEN keeps showing the score
		# the player had while playing, because watching it drop out from under a summary you
		# are still reading is alarming; the visible rollback lands on Continue, in new_game().
		var earned_this_level: int = game.score
		game.score = _score_at_level_start
		game.sig_level_is_done.emit(didwin)
		game.score = earned_this_level
	game.stop_sound("ambient")
	BE.send_event("level_done", "Friends", {
		"level": level,
		"didwin": int(didwin),
	})
	if didwin:
		# No fanfare for a level that was not passed.
		MainGlobals.global_level_is_done(passed)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = passed
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms\nAccuracy: %d%%\n\n%s" % [mean_time_to_answer_ms(), pct, _progress_line(passed, need)]
			game.show_level_done_popup(self, "", "", level, textadd, passed)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

# Every per-level value comes from FriendsLevelConfig. This was a `match level:` ladder, and the
# level_config file beside it stated a DIFFERENT set of round counts that nothing read — the two had
# already drifted. Read the table, and there is only one set of numbers to be wrong.
func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, max_difficulty)
	var cfg: Dictionary = FriendsLevelConfig.get_level(level)
	num_friends = (cfg["num_friends"] as Array).duplicate()
	num_corrects_for_next_level = int(cfg["rounds"])
	dtime_to_show_all_friends_ms = int(cfg["study_ms"])
	dtime_to_ignore_when_no_answer_ms = int(cfg["answer_ms"])
	game.init_sizes()

func _can_play():
	return not game.paused() and not game.level_is_done and game.level_is_ready and game.playing

func _tick_person() -> void:
	if _can_play():
		var now = game.game_time
		if time_to_next_mode_ms > 0 and now >= time_to_next_mode_ms:
			change_to_next_mode()
		elif mode == modes.DISPLAY_SOMEONE and time_shown_new_person_ms > 0:
			if !answered_current_person and now >= time_shown_new_person_ms + dtime_to_ignore_when_no_answer_ms:
				time_shown_new_person_ms = 0
				# Letting the card reach full size scores as an Ignore, but it is NOT a decision —
				# the player answered nothing. It must not be counted as a deliberate "no".
				_auto_ignoring = true
				_on_ignore_button_pressed()
				_auto_ignoring = false
			else:
				var dt = now - time_shown_new_person_ms
				var pct = float(dt) / float(dtime_to_ignore_when_no_answer_ms)
				new_person_card.scale = Vector2(pct, pct)  # shared card is pixel-sized (scale 1 = full)
			
func on_time_over():
	game.stop_sound("ambient")
	
func mean_time_to_answer_ms() -> int:
	var N = times_to_answer.size()
	if N == 0:
		return 9999
	var s := 0
	for t in times_to_answer:
		s += t
	return roundi(float(s) / N)

func _add_time_to_answer_ms(t_ms: int):
	if t_ms <= 0:
		return
	times_to_answer.append(t_ms)
	while times_to_answer.size() > 10:
		times_to_answer.remove_at(0)

func _on_ready_button_pressed() -> void:
	if mode == modes.DISPLAY_ALL_FRIENDS:
		change_to_next_mode()
			
func change_to_next_mode():
	if _can_play():
		if mode == modes.DISPLAY_ALL_FRIENDS:
			mode = modes.DISPLAY_SOMEONE
			%Instructions.text = "If this person is your\nfriend, say Hi"
			move_to_display_someone_mode()
		elif mode == modes.DISPLAY_SOMEONE:
			move_to_failed_mode()

func move_to_failed_mode():
	if _can_play():
		time_to_next_mode_ms = 0
		_on_ignore_button_pressed()

func move_to_display_someone_mode():
	if _can_play():
		$ReadyButton.hide()
		$HBoxContainer.show()
		for c in cards:
			c.hide()
		time_to_next_mode_ms = 0
		display_new_person()

func answered(correct: bool):
	answered_current_person = true
	if correct:
		var time_since_shown_person_ms = game.game_time - time_shown_new_person_ms
		var score_to_add = max(1, int(10 - time_since_shown_person_ms / 200))
		_add_time_to_answer_ms(time_since_shown_person_ms)
		game.add_score_and_time(score_to_add,15)
		game.add_correct_or_mistake(1,0)
		num_corrects_in_level_so_far += 1		
		game.play_sound("delivery")
		if num_corrects_in_level_so_far >= num_corrects_for_next_level:
			MainGlobals.do_after(2, func(): level_is_done(true))
			$HBoxContainer.hide()
			return
	else:
		game.add_score_and_time(-1,-5)
		game.add_correct_or_mistake(0,1)
		game.play_sound("swoosh")
	$HBoxContainer.hide()
	MainGlobals.do_after(2, display_new_person)

func get_rand_person_id():
	var max_possible = min(FriendsG.get_num_people()-1, max_id_used * 2)
	return game.rng.randi_range(0, max_possible)

var answered_current_person := false
func display_new_person():
	if mode != modes.DISPLAY_SOMEONE or game.level_is_done:
		return
	# THE STALL. This used to `return` whenever the game was not playable at that instant, and
	# nothing ever called it again — so the round stopped dead with the last person's reaction
	# ("Ann says Hi") on screen and no way forward but a new game.
	#
	# It is reached from a 2-second `do_after` after every answer, and `_can_play()` is false while
	# ANY screen is up (help, the level card, the pause), while the app is out of focus, and before
	# `game.playing` is set. Any of those landing in that 2-second window killed the round. Waiting
	# is the answer, not giving up.
	if !_can_play():
		MainGlobals.do_after(0.5, display_new_person)
		return
	answered_current_person = false
	%CorrectText.hide()
	%WrongText.hide()
	%Instructions.show()
	$HBoxContainer.show()
	time_shown_new_person_ms = game.game_time
	var new_idx = get_rand_person_id()
	while new_idx == new_person_card.meta:
		new_idx = get_rand_person_id()
	set_new_person_id(new_idx)
	new_person_card.show()

func _is_person_friend():
	for c in cards:
		if c.meta == new_person_card.meta:
			return true
	return false

func _on_say_hi_button_pressed() -> void:
	var id = new_person_card.meta
	var pname = FriendsG.first_name(FriendsG.get_person_name(id))
	if _is_person_friend():
		%CorrectText.text = pname + "\nalso says Hi"
		%CorrectText.show()
		%WrongText.hide()
	else:
		%WrongText.text = pname + "\nlooks puzzled"
		%WrongText.show()
		%CorrectText.hide()
	# %Instructions.hide()
	# Saying Hi is the "yes". Greeting more strangers as faces get harder would hold the percentage
	# steady while the false alarms climbed, so the four counts are kept apart.
	game.record_answer(true, _is_person_friend())
	answered(_is_person_friend())

func _on_ignore_button_pressed() -> void:
	var id = new_person_card.meta
	var pname = FriendsG.first_name(FriendsG.get_person_name(id))
	if !_is_person_friend():
		%CorrectText.text = pname + "\nalso ignores you"
		%CorrectText.show()
		%WrongText.hide()
	else:
		%WrongText.text = pname + "\nsays Hi"
		%WrongText.show()
		%CorrectText.hide()
	# %Instructions.hide()
	if _auto_ignoring:
		game.record_no_answer()
	else:
		game.record_answer(false, _is_person_friend())
	answered(!_is_person_friend())

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (level + 1)
