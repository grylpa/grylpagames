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
var dtime_to_show_all_friends_ms := 60 * 1000
var time_to_next_mode_ms = 0
var time_shown_new_person_ms = 0
var max_id_used := 1

const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")
const YELLOW: Color = Color(1, 0.8039216, 0, 1)  # friends card border colour

var ambient_audios := [ 
	preload("res://art/sounds/ocean-waves-2.mp3"), 
	preload("res://art/sounds/ocean-waves-3.mp3"), 
	preload("res://art/sounds/ocean-waves-4.mp3")
]

signal started_playing
signal sig_level_is_done(didwin:bool)

func _ready() -> void:
	game = FriendsG.game
	game.sig_time_over.connect(on_time_over)
	level = FriendsG.starting_level
	increase_difficulty(false)

	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

	FriendsG.board_top = %Instructions.position.y + %Instructions.size.y + 30

func new_game(from_scratch=true):
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
	game.sig_level_is_done.emit(didwin)
	game.stop_sound("ambient")
	BE.send_event("level_done", "Friends", {
		"level": level,
		"didwin": int(didwin),
	})
	if didwin:
		MainGlobals.global_level_is_done(true)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = true
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms" % mean_time_to_answer_ms()
			game.show_level_done_popup(self, "","", level, textadd)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, max_difficulty)
	match level:
		1:	
			num_friends = [2,0]
			num_corrects_for_next_level = 5
		2:	
			num_friends = [3,0]
			num_corrects_for_next_level = 10
		3:	
			num_friends = [4,0]
			num_corrects_for_next_level = 5
		4:	
			num_friends = [3,2]
			num_corrects_for_next_level = 20
		5:	
			num_friends = [3,3]
			num_corrects_for_next_level = 20
		6:	
			num_friends = [4,3]
			num_corrects_for_next_level = 20
		
	# if MainGlobals.is_mobile():
	game.init_sizes()

func _can_play():
	return not game.paused() and not game.level_is_done and game.level_is_ready and game.playing

func _process(_delta: float) -> void:
	if _can_play():
		var now = game.game_time
		if time_to_next_mode_ms > 0 and now >= time_to_next_mode_ms:
			change_to_next_mode()
		elif mode == modes.DISPLAY_SOMEONE and time_shown_new_person_ms > 0:
			if !answered_current_person and now >= time_shown_new_person_ms + dtime_to_ignore_when_no_answer_ms:
				time_shown_new_person_ms = 0
				_on_ignore_button_pressed()
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
	if !_can_play() or mode != modes.DISPLAY_SOMEONE:
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
	answered(!_is_person_friend())
