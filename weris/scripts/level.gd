extends CanvasLayer

var game: GenericGameUtil

var max_difficulty := 6
var level := 1
var num_corrects_in_level_so_far := 0
var num_corrects_for_next_level := 3
var grid_cols := 2
var grid_rows := 2

var times_to_answer := []

enum Phase { STUDY, FIND, FEEDBACK }
var phase := Phase.STUDY

var target_idx := 0
var study_start_time_ms := 0
var find_start_time_ms := 0
var feedback_start_time_ms := 0
var feedback_level_done := false

const FEEDBACK_DURATION_MS = 1500
const CARD_GAP = 6
const LABEL_BOTTOM = 162  # bottom y of InstructionsLabel/FindLabel in scene (below HUD level label)

# Card aspect ratio used for sizing (width:height = 236:334; matches the shared
# card's ASPECT_H_OVER_W = 334/236 in res://shared/scripts/card.gd)
const CARD_W_UNSCALED = 236.0
const CARD_H_UNSCALED = 334.0

var study_card = null
var find_cards := []

const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")
const YELLOW: Color = Color(1, 0.8039216, 0, 1)  # weris card border color

signal started_playing
signal sig_level_is_done(didwin: bool)

# What the score was when this level began. A level that misses the gate gives its points
# back (see the level-done function): without that, failing forever is a way to earn forever
# — every attempt banked its points and the retry cost nothing.
var _bg: Control = null
var _bg_t: float = 0.0

var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false

func _ready() -> void:
	game = WerisG.game
	game.sig_time_over.connect(on_time_over)
	game.add_sound(self, "correct", preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg"))
	game.add_sound(self, "wrong", preload("res://art/sounds/swoosh.mp3"))
	level = WerisG.starting_level
	increase_difficulty(false)
	_apply_look()

# Cosmetics only: the drawn ground the rest of the app uses (scripts/screen_backdrop.gd) in this
# game's own green, in place of the tiled `res://art/grass.png` every screen used to wear, and the
# labels set in the app's prose face.
func _apply_look() -> void:
	var ground: TextureRect = $TextureRect
	ground.texture = null
	_bg = ScreenBackdrop.attach(ground)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void:
			ScreenBackdrop.draw(_bg, _bg_t, ScreenBackdrop.WERIS_TOP, ScreenBackdrop.WERIS_BOT,
				ScreenBackdrop.ACCENT))
	set_process(true)
	for label: Label in [%InstructionsLabel, %FindLabel, %FeedbackLabel]:
		label.add_theme_font_override("font", MainGlobals.get_text_font())
	%CountdownLabel.add_theme_color_override("font_color", ScreenBackdrop.ACCENT)

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()

func new_game(from_scratch = true):
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
		level = WerisG.starting_level
		WerisG.shuffle_people()
	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	num_corrects_in_level_so_far = 0
	_start_study_phase()
	started_playing.emit()
	game.level_is_ready = true

func _clear_cards():
	for c in find_cards:
		if is_instance_valid(c):
			c.queue_free()
	find_cards.clear()
	if study_card != null and is_instance_valid(study_card):
		study_card.queue_free()
		study_card = null

func _start_study_phase():
	_clear_cards()
	phase = Phase.STUDY
	feedback_level_done = false

	var prev_idx: int = target_idx
	var num_people: int = WerisG.get_num_people()
	if num_people > 1:
		while target_idx == prev_idx:
			target_idx = game.rng.randi_range(0, num_people - 1)
	else:
		target_idx = 0

	var screen_w = MainGlobals.screen_size.x
	var screen_h = MainGlobals.screen_size.y
	var buttons_h = game.buttons_height

	# Study card: fit in vertical space below label, leave room for countdown
	var avail_h = screen_h - (LABEL_BOTTOM + 4) - buttons_h - 70 - 20
	var card_w = int(min(screen_w * 0.45, avail_h * CARD_W_UNSCALED / CARD_H_UNSCALED))
	var card_h = int(card_w * CARD_H_UNSCALED / CARD_W_UNSCALED)

	study_card = CARD_SCRIPT.new()
	add_child(study_card)
	study_card.fit = CARD_SCRIPT.Fit.COVER
	study_card.setup(WerisG.get_person_image(target_idx), YELLOW)
	study_card.set_width(float(card_w))
	study_card.position = Vector2(screen_w / 2.0, LABEL_BOTTOM + 4)

	# Position countdown below the card
	var countdown_y = LABEL_BOTTOM + 4 + card_h + 28
	%CountdownLabel.offset_left = 0.0
	%CountdownLabel.offset_top = float(countdown_y)
	%CountdownLabel.offset_right = float(screen_w)
	%CountdownLabel.offset_bottom = float(countdown_y + 70)
	%CountdownLabel.show()

	var first_name = WerisG.get_person_name(target_idx).split(" ")[0]
	%InstructionsLabel.text = "This is %s" % first_name
	%InstructionsLabel.show()
	%FindLabel.hide()
	%FeedbackLabel.hide()

	study_start_time_ms = int(game.game_time)

func _start_find_phase():
	_clear_cards()
	phase = Phase.FIND
	%CountdownLabel.hide()
	%InstructionsLabel.hide()
	%FeedbackLabel.hide()
	var first_name = WerisG.get_person_name(target_idx).split(" ")[0]
	%FindLabel.text = "Where is %s?" % first_name
	%FindLabel.show()

	var screen_w = MainGlobals.screen_size.x
	var screen_h = MainGlobals.screen_size.y
	var buttons_h = game.buttons_height

	var usable_top = LABEL_BOTTOM + 4
	var usable_h = screen_h - usable_top - buttons_h - 10
	var usable_w = screen_w - 8

	# Compute card size: height-first for portrait ratio
	var card_h_from_rows = int((usable_h - CARD_GAP * (grid_rows - 1)) / grid_rows)
	var card_w_from_cols = int((usable_w - CARD_GAP * (grid_cols - 1)) / grid_cols)
	# Portrait ratio: card_w from height
	var card_w = int(card_h_from_rows * CARD_W_UNSCALED / CARD_H_UNSCALED)
	var card_h = card_h_from_rows
	# If width-constrained, recalculate height
	if card_w > card_w_from_cols:
		card_w = card_w_from_cols
		card_h = int(card_w * CARD_H_UNSCALED / CARD_W_UNSCALED)

	var total_grid_w = grid_cols * card_w + CARD_GAP * (grid_cols - 1)
	var total_grid_h = grid_rows * card_h + CARD_GAP * (grid_rows - 1)
	# start_x is center-x of first card (Node2D centered layout)
	var start_x = int((screen_w - total_grid_w) / 2.0) + card_w / 2
	var start_y = int(usable_top + (usable_h - total_grid_h) / 2.0)

	var grid_size = grid_cols * grid_rows
	var people_in_grid = _build_grid_people(grid_size)

	for i in grid_size:
		var row = i / grid_cols
		var col = i % grid_cols
		var card = CARD_SCRIPT.new()
		add_child(card)
		card.fit = CARD_SCRIPT.Fit.COVER
		card.tappable = true
		card.meta = people_in_grid[i]
		card.setup(WerisG.get_person_image(people_in_grid[i]), YELLOW)
		card.set_width(float(card_w))
		card.position = Vector2(start_x + col * (card_w + CARD_GAP), start_y + row * (card_h + CARD_GAP))
		card.card_pressed.connect(_on_find_card_pressed)
		find_cards.append(card)

	find_start_time_ms = int(game.game_time)

func _build_grid_people(grid_size: int) -> Array:
	var others := []
	var tries := 0
	while others.size() < grid_size - 1 and tries < 1000:
		tries += 1
		var r = game.rng.randi_range(0, WerisG.get_num_people() - 1)
		if r != target_idx and r not in others:
			others.append(r)
	var result = others.duplicate()
	result.resize(grid_size - 1)
	var target_pos = game.rng.randi_range(0, grid_size - 1)
	result.insert(target_pos, target_idx)
	return result

func _on_find_card_pressed(pressed_idx: int):
	if phase != Phase.FIND:
		return
	var elapsed = game.game_time - find_start_time_ms
	_resolve_find(pressed_idx == target_idx, elapsed, false)

func _resolve_find(is_correct: bool, elapsed_ms: int, timed_out: bool):
	if phase != Phase.FIND:
		return
	phase = Phase.FEEDBACK
	_clear_cards()
	%FindLabel.hide()
	%InstructionsLabel.hide()

	if is_correct:
		game.play_sound("correct")
		var score = max(1, 10 - int(elapsed_ms / 200))
		game.add_score_and_time(score, 15)
		game.add_correct_or_mistake(1, 0)
		if elapsed_ms > 0:
			times_to_answer.append(elapsed_ms)
			while times_to_answer.size() > 20:
				times_to_answer.remove_at(0)
		num_corrects_in_level_so_far += 1
		var first_name = WerisG.get_person_name(target_idx).split(" ")[0]
		%FeedbackLabel.text = "Found %s! +%d" % [first_name, score]
		%FeedbackLabel.add_theme_color_override("font_color", Color(0.05, 0.6, 0.1))
	else:
		game.play_sound("wrong")
		game.add_score_and_time(-1, -5)
		game.add_correct_or_mistake(0, 1)
		%FeedbackLabel.text = "Time's up!" if timed_out else "Wrong person!"
		%FeedbackLabel.add_theme_color_override("font_color", Color(0.75, 0.1, 0.05))

	%FeedbackLabel.show()
	feedback_start_time_ms = int(game.game_time)
	feedback_level_done = is_correct and num_corrects_in_level_so_far >= num_corrects_for_next_level

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return
	var now = game.game_time
	match phase:
		Phase.STUDY:
			var elapsed = now - study_start_time_ms
			var remaining_s = ceili((WerisG.study_time_sec * 1000 - elapsed) / 1000.0)
			%CountdownLabel.text = str(max(0, remaining_s))
			if elapsed >= WerisG.study_time_sec * 1000:
				_start_find_phase()
		Phase.FIND:
			if now - find_start_time_ms >= WerisG.find_time_sec * 1000:
				_resolve_find(false, WerisG.find_time_sec * 1000, true)
		Phase.FEEDBACK:
			if now - feedback_start_time_ms >= FEEDBACK_DURATION_MS:
				if feedback_level_done:
					level_is_done(true)
				else:
					_start_study_phase()

func on_time_over():
	pass

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
	if didwin:
		# No fanfare for a level that was not passed.
		MainGlobals.global_level_is_done(passed)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = passed
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage find time: %d ms\nAccuracy: %d%%\n\n%s" % [mean_time_to_answer_ms(), pct, _progress_line(passed, need)]
			game.show_level_done_popup(self, "", "", level, textadd, passed)
	else:
		sig_level_is_done.emit(didwin)

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func increase_difficulty(increase = true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, max_difficulty)
	match level:
		1:
			grid_cols = 2; grid_rows = 2
			num_corrects_for_next_level = 3
			WerisG.study_time_sec = 5
		2:
			grid_cols = 3; grid_rows = 2
			num_corrects_for_next_level = 5
			WerisG.study_time_sec = 4
		3:
			grid_cols = 3; grid_rows = 3
			num_corrects_for_next_level = 5
			WerisG.study_time_sec = 3
		4:
			grid_cols = 4; grid_rows = 3
			num_corrects_for_next_level = 10
			WerisG.study_time_sec = 3
		5:
			grid_cols = 4; grid_rows = 4
			num_corrects_for_next_level = 10
			WerisG.study_time_sec = 2
		6:
			grid_cols = 5; grid_rows = 4
			num_corrects_for_next_level = 15
			WerisG.study_time_sec = 2
	game.init_sizes()

func _can_play() -> bool:
	return not game.paused() and not game.level_is_done and game.level_is_ready and game.playing

func mean_time_to_answer_ms() -> int:
	var N = times_to_answer.size()
	if N == 0:
		return 9999
	var s := 0
	for t in times_to_answer:
		s += t
	return roundi(float(s) / N)

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (level + 1)
