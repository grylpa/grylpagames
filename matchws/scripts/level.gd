extends CanvasLayer

var cards = []
var obsolete_cards = []
var difficulty := 0
var score_if_successful := 5
var can_start_clicking := false
var level_start_time_ms: float = 0
var time_pressed_pause_ms: float = 0
var timeout_sec := 30.0
var num_new_cards := 8
var mistakes = []
var last_shown_words = []
var shown_correct := false
var nmistakes := 0
var create_board_index := 0
var board_iteration := 0

@export var card_scene: PackedScene = load("res://matchws/scenes/card.tscn")

var ambient_audios := [ 
	preload("res://art/sounds/ocean-waves-250310.mp3"), 
	preload("res://art/sounds/relaxing-ocean-waves-high-quality-recorded-177004.mp3"), 
	preload("res://art/sounds/small-ocean-lapping-waves-220314.mp3")
]

signal sig_can_start_clicking
signal pressed_new_game
signal sig_level_is_done(didwin:bool)
# signal sig_message(text:String, autohide:bool)
signal show_main_menu
signal show_help
signal pressed_esc
signal pressed_pause
# signal update_score(score:int)
signal update_time(time:float)
signal sig_add_score(score:int)

var rng = RandomNumberGenerator.new()
var game:GenericGameUtil

func timems() -> int:
	return MainGlobals.timems()

func _ready() -> void:
	game = MatchwsG.game
	MatchwsG.init_globals()
	difficulty = MatchwsG.starting_difficulty
	increase_difficulty(false)
	rng.randomize()
	MatchwsG.bottom = MainGlobals.screen_size.y
	
func _make_card_obsolete(c):
	c.hide()
	c.moving = false
	obsolete_cards.append([MainGlobals.timems(), c])

func _delete_old_obsoletes():
	var now = MainGlobals.timems()
	var remaining = []
	for o in obsolete_cards:
		if now - o[0] < 60*1000:
			remaining.append(o)
		else:
			Log.dbg("freeing card %s" % o[1].get_text())
			o[1].queue_free()
	obsolete_cards = remaining

func new_game():
	show()
	increase_difficulty(false)
	score_if_successful = 5 + 2 * difficulty
	create_board()
	ambient_audios.shuffle()
	$AmbientAudio.stream = ambient_audios[0]
	ambient_audios[0].loop = true
	$AmbientAudio.play()
	# time_started_level_ms = MainGlobals.timems()
	BE.upsert_game_state("Matchws", 
		{"state":"new","difficulty": difficulty, "moving":MatchwsG.moving})

func _input(event):
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("new_board"):
		create_board_index += 1
		pressed_new_game.emit()
	elif event.is_action_pressed("mainmenu"):
		create_board_index += 1
		show_main_menu.emit()
	elif event.is_action_pressed("help"):
		show_help.emit()
	elif event.is_action_pressed("esc"):
		pressed_esc.emit()
	elif event.is_action_pressed("pause"):
		pressed_pause.emit()
	elif event.is_action_pressed("change game") and not MainCfg.single_game:
		create_board_index += 1

func auto_pos_card(card):
	var sz = MainGlobals.get_viewport_size()
	var add_y := 0
	if MatchwsG.moving:
		add_y = 0 - sz.y
		if card.second_batch:
			add_y -= sz.y

	var mx = 8
	var my = 8
	var card_rect = card.get_bounding_rect()
	var card_size = card_rect.size
	var ok = false
	var tries = 0
	var p:Vector2 = Vector2(0,0)
	while !ok and tries < 100:
		tries += 1
		p.x = rng.randf_range(mx, sz.x-mx - card_size.x)
		p.y = rng.randf_range(my, sz.y-my - card_size.y) + MainGlobals.header_height + add_y
		ok = true
		for c in cards:
			var rect = Rect2(p, card_size).grow_individual(mx,my,mx,my)
			var c_br = c.get_bounding_rect()
			# Log.dbg(card_size, c_br.size)
			if rect.intersects(c_br, true):# or !MainGlobals.rect_in_viewport(rect):
				ok = false
				break
			# else:
			# 	print("was good with ", rect.position, rect.position+rect.size, c_br.position, c_br.position+c_br.size)
	if !ok:
		tries = 0
		mx = 4
		my = 4
		while !ok and tries < 100:
			tries += 1
			p.x = rng.randf_range(mx, sz.x-mx - card_size.x)
			p.y = rng.randf_range(my, sz.y-my - card_size.y) + MainGlobals.header_height + add_y
			ok = true
			for c in cards:
				var rect = Rect2(p, card_size).grow_individual(mx,my,mx,my)
				var c_br = c.get_bounding_rect()
				if rect.intersects(c_br, true):# or !MainGlobals.rect_in_viewport(rect):
					ok = false
					break
	if !ok:
		print("didnt find a place for the card")			
		if !MatchwsG.level_done:
			_make_card_obsolete(card)
		return null
	p += card_size/2
	card.position = p
	return card

func add_card_at(p: Vector2, card_id, text, color, clickable: bool, should_be_clicked: bool, word_index: int,
	moving: bool, second_batch: bool, font_size: int):
	var card = card_scene.instantiate()
	card.second_batch = second_batch
	if MatchwsG.speed_mode:
		card.set_min_size(Vector2(600,88))
	card.set_font_size(font_size)
	add_child(card)
	card.position = p
	card.hide()
	card.set_card_data(card_id, text, color, clickable, should_be_clicked, word_index, moving)	
	card.z_index = max(1, RenderingServer.CANVAS_ITEM_Z_MAX - MainGlobals.screen_size.y - p.y - 100)
	card.rotation = 0.0 if MatchwsG.speed_mode else deg_to_rad(rng.randf_range(-3,3))
	# print("put card ", card.get_text(), " at ", card.get_bounding_rect())
	cards.append(card)
	card.card_pressed.connect(_on_card_pressed)
	card.card_reached_bottom.connect(_on_card_moved_to_bottom)
	card.card_below_bottom.connect(_on_card_moved_below_bottom)
	card.card_double_clicked.connect(_on_card_double_clicked)
	return card

func find_card_by_text(text):
	for c in cards:
		if c.get_text() == text:
			return c
	return null

func _board_iter_of_word(_word_index):
	for i in range(last_shown_words.size()-1, -1, -1):
		var v = last_shown_words[i]
		if v.y < board_iteration - 10:
			last_shown_words.remove_at(i)
		if v.x == _word_index:
			return v.y
	return -100

func create_board() -> void:
	level_start_time_ms = timems()
	board_iteration += 1
	var this_create_board_index = create_board_index
	nmistakes = 0
	update_time.emit(timeout_sec)
	var oldcards = cards.duplicate()
	cards.clear()
	oldcards.map(func(c): _make_card_obsolete(c))
	_delete_old_obsoletes()
	shown_correct = false
	
	var cx = MainGlobals.get_viewport_center()
	# print("cx is " + str(cx))
		
	var center_word_type = rng.randi_range(0,6)
	var center_words
	var outside_words
	if center_word_type == 0:
		center_words = MatchwsG.words.hard_words
		outside_words = MatchwsG.words.easy_words
	else:
		center_words = MatchwsG.words.easy_words
		outside_words = MatchwsG.words.hard_words

	var word_index := -1
	while word_index < 1:
		if mistakes.size() > 0:
			var choose_from_mistakes = rng.randi_range(0,1)
			if choose_from_mistakes != 0:
				var pick_idx = rng.randi_range(0, mistakes.size()-1)
				var mistake = mistakes.pop_at(pick_idx)
				word_index = mistake.x		
				if board_iteration - _board_iter_of_word(word_index) < 3:
					mistakes.append(Vector2i(word_index, mistake.y))
					word_index = -1
				elif mistake.y > 0:
					mistakes.append(Vector2i(word_index, mistake.y-1))
		if word_index < 0:
			word_index = MatchwsG.words.get_real_word_index_and_advance()
		if board_iteration - _board_iter_of_word(word_index) < 3:
			word_index = -1

	last_shown_words.append(Vector2i(word_index, board_iteration))
	var center_fs := 28
	var outside_fs := 24
	if MatchwsG.speed_mode or MainGlobals.is_mobile():
		center_fs = 46
		outside_fs = 42
	var center_word = center_words[word_index]
	var c_ref = add_card_at(cx, 0, center_word, Color(0.5,0.9,1), false, false, word_index, false, false, center_fs)	
	c_ref.hide()
	c_ref.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	$TextureRect/BottomRect.z_index = RenderingServer.CANVAS_ITEM_Z_MAX-1

	var outside_indices = MatchwsG.words.word_indices.duplicate(true)
	outside_indices.shuffle()

	var initial_card_color := Color(0.9,0.9,0.9)
	# var sz = MainGlobals.get_viewport_size()
	# var sz = c_ref.card_size
	var N = min(num_new_cards, MatchwsG.words.hard_words.size())
	# var card_positions = positions.duplicate(true)
	# card_positions.shuffle()

	# var dang = 360.0 / N
	# var r = sz.x / 3.0
	var outside_index := 0
	var correct_outside_text = outside_words[word_index]
	var endloopval = 2*N if MatchwsG.moving else N
	var outside_word
	for i in endloopval:
		if i == 0:
			outside_index = word_index
			outside_word = outside_words[outside_index]
		else:
			for tries in 10000:
				if outside_indices.is_empty():
					outside_indices = MatchwsG.words.word_indices.duplicate(true)
					outside_indices.shuffle()
				outside_index = outside_indices.pop_front()
				if outside_index != word_index:
					outside_word = outside_words[outside_index]
					if find_card_by_text(outside_word) == null:
						break
		# var a = deg_to_rad(dang * i + dang / 2.0)
		# var p = Vector2(cos(a) * r, sin(a) * r)
		# var p = Vector2(card_positions[i][0] * sz.x, card_positions[i][1] * sz.y) + cx
		
		var other_word = center_words[outside_index]
		# var p = Vector2(-1,-1)
		var p = Vector2(200,i * 100 + 60)
		var _c = add_card_at(p, i + 1, outside_word, initial_card_color, true, 
			outside_word == correct_outside_text or center_word == other_word, 
			outside_index, MatchwsG.moving, i >= N, outside_fs)
		if _c != null:
			_c.hide()
			_c.calc_speed(timeout_sec)
		# var c_sz = c.card_size * 1.2
		# var sz_to_use = Vector2(max(sz.x, c_sz.x), max(sz.y, c_sz.y))
		# p = Vector2(card_positions[i][0] * sz_to_use.x, card_positions[i][1] * sz_to_use.y) + cx
		# c.position = p

	await get_tree().process_frame
	if this_create_board_index != create_board_index:
		return
	var c_ref_br = c_ref.get_bounding_rect()
	var next_y_to_use := 0
	var next_y_pad := 20
	if MatchwsG.speed_mode:
		c_ref.position.y = MainGlobals.header_height + next_y_pad + 80 + c_ref_br.size.y/2
		c_ref_br = c_ref.get_bounding_rect()
		next_y_to_use = c_ref_br.end.y + next_y_pad
	elif MatchwsG.moving:
		c_ref.position.y = MainGlobals.screen_size.y - c_ref_br.size.y/2
	else:
		c_ref.position.y = cx.y - c_ref_br.size.y/2
	MatchwsG.bottom = c_ref.position.y - c_ref_br.size.y/2
	if MatchwsG.moving:
		$TextureRect/BottomRect.position.y = MatchwsG.bottom
		$TextureRect/BottomRect.show()
	else:
		$TextureRect/BottomRect.hide()

	var unpositioned_cards = cards.duplicate()
	cards.clear()
	cards.append(unpositioned_cards.pop_front())
	c_ref.show()
	if !MatchwsG.moving and !MatchwsG.speed_mode:
		# await MainGlobals.sleep(max(1, min(3, timeout_sec - 2)));
		if this_create_board_index != create_board_index:
			return

	if MatchwsG.speed_mode:
		unpositioned_cards.shuffle()
		for _c in unpositioned_cards:
			_c.time_to_show = MainGlobals.timems() + 2000
			var rc = _c.get_bounding_rect()
			_c.position = Vector2(c_ref.position.x, next_y_to_use + rc.size.y/2)
			rc = _c.get_bounding_rect()
			cards.append(_c)
			next_y_to_use = rc.end.y + next_y_pad
	else:
		for _c in unpositioned_cards:
			_c.time_to_show = MainGlobals.timems() + max(1, min(3, timeout_sec - 2))*1000
			var positioned_card = auto_pos_card(_c)
			if positioned_card != null:
				cards.append(_c)

	for _c in cards:
		_c.show()

	can_start_clicking = true
	sig_can_start_clicking.emit()
	level_start_time_ms = timems()
	# update_time.emit(0)
	update_time.emit(timeout_sec)
		
func level_is_done(didwin: bool, duration: float):
	MainGlobals.do_after(0.1, _deferred_level_is_done.bind(didwin, duration))
	# call_deferred("_deferred_level_is_done", didwin, duration)

func _deferred_level_is_done(didwin: bool, duration: float):
	Log.dbg("level_is_done")
	BE.send_event("level_done", "Matchws", {
		"difficulty": difficulty,
		"moving":MatchwsG.moving,
		"didwin": int(didwin),
		"durationms": roundi(duration*1000),
		"new_lang": MatchwsG.words.selected_new_lang_id,
		"known_lang": MatchwsG.words.selected_known_lang_id,
		"collection": MatchwsG.words.selected_collection_id,
		"num_new_cards": num_new_cards,
		"nmistakes": nmistakes,
		"speed_mode": int(MatchwsG.speed_mode),
		"timeout_sec": timeout_sec,
	})
	if didwin:
		increase_difficulty()
		if !MatchwsG.speed_mode:
			MainGlobals.sleep(1.0)
	sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if increase:
		# difficulty += 1
		pass
	if MatchwsG.speed_mode:
		match difficulty:
			1: 
				timeout_sec = 30
				num_new_cards = 3
			2: 
				timeout_sec = 15
				num_new_cards = 3
			3: 
				timeout_sec = 7
				num_new_cards = 3
			4: 
				timeout_sec = 3
				num_new_cards = 3
			_: 
				timeout_sec = 15
				num_new_cards = 3
	elif MatchwsG.moving:
		match difficulty:
			1: 
				timeout_sec = 30
				num_new_cards = 10
			2: 
				timeout_sec = 20	
				num_new_cards = 20
			3: 
				timeout_sec = 10
				num_new_cards = 20
			4: 
				timeout_sec = 5
				num_new_cards = 20
			_: 
				timeout_sec = 30
				num_new_cards = 20
	else:
		match difficulty:
			1: 
				timeout_sec = 30
				num_new_cards = 5
			2: 
				timeout_sec = 20	
				num_new_cards = 7
			3: 
				timeout_sec = 10
				num_new_cards = 8
			4: 
				timeout_sec = 5
				num_new_cards = 8
			_: 
				timeout_sec = 30
				num_new_cards = 8

func find_card_index(card_id):
	return cards.find_custom(func(c): return c.id == card_id)

func find_card(card_id):
	var i = find_card_index(card_id)
	return null if i < 0 else cards[i]
	# for c in cards:
	# 	if c.id == card_id:
	# 		return c
	# return null

func find_first_correct_card():
	var ccs = find_correct_cards()
	if ccs.size() > 0:
		return ccs[0]
	else:
		return null

func find_correct_cards():
	return cards.filter(func(c): return c.should_be_clicked)

func show_correct_cards(was_correct: bool, clicked_card_id: int = -1):
	if shown_correct:
		return
	Log.dbg("show_correct_cards")
	# MatchwsG.level_done = true
	shown_correct = true 
	var ccs = find_correct_cards()
	for c in cards:
		if c.id == clicked_card_id:
			c.moving = false
			c.z_index = RenderingServer.CANVAS_ITEM_Z_MAX-2;
		elif !c.should_be_clicked:
			c.set_fast_speed()
			
	if ccs.size() > 0:
		if !MatchwsG.speed_mode and (!was_correct or ccs.size() > 1):
			ccs.map(func(c): c.clicked())
			var ntimes = 3 if ccs.size() == 1 else 5
			for i in ntimes:
				ccs.map(func(c): if c.id != clicked_card_id: c.clicked())
				await MainGlobals.sleep(0.5)
				ccs.map(func(c): if c.id != clicked_card_id: c.hide_color())
				await MainGlobals.sleep(0.3)
		ccs.map(func(c): c.clicked())
		var delay := 2.0
		if MatchwsG.speed_mode:
			delay = 0.3 if was_correct else 2.0
		if !was_correct:
			var mistaken_word_index = ccs[0].word_index
			mistakes.append(Vector2i(mistaken_word_index,5))
		await MainGlobals.sleep(delay)
	MatchwsG.level_done = true
	Log.dbg("show_correct_cards done")

func _on_card_moved_to_bottom(_p, _card_id):
	if MatchwsG.level_done:
		return
	var c = find_card(_card_id)
	var ccs = find_correct_cards()
	if c.should_be_clicked:
		if ccs.size() > 1:
			return
		MatchwsG.level_done = true
		can_start_clicking = false
		var now = timems()
		var duration = (now - level_start_time_ms)/1000.0
		Log.dbg("_on_card_moved_to_bottom")
		await show_correct_cards(false)
		level_is_done(false, duration)	

func _on_card_moved_below_bottom(_p, _card_id):
	if MatchwsG.level_done:
		return
	var i = find_card_index(_card_id)
	if i >= 0:
		var c = cards[i]
		if c.id == _card_id:
			cards.remove_at(i)
			if !MatchwsG.level_done:
				_make_card_obsolete(c)

func made_mistake(wrong_card):
	var cc = find_first_correct_card()
	nmistakes += 1
	sig_add_score.emit(-2)
	if wrong_card != null:
		wrong_card.rot_speed = 4000
		mistakes.append(Vector2i(wrong_card.word_index,5))
	if cc != null:
		mistakes.append(Vector2i(cc.word_index,5))

func _on_card_double_clicked(_p, _card_id):
	if !can_start_clicking or MatchwsG.level_done:
		return
	Log.dbg("_on_card_double_clicked")
	var c = find_card(_card_id)
	if c != null:
		mistakes.append(Vector2i(c.word_index,5))

func _on_card_pressed(_p, _card_id):
	# await MainGlobals.sleep(0.5)
	call_deferred("_on_card_pressed_when_idle", _p, _card_id)

func _on_card_pressed_when_idle(_p, _card_id):
	if !can_start_clicking or MatchwsG.level_done:
		return
	var durationms = timems() - level_start_time_ms
	var c = find_card(_card_id)
	if c != null:
		var save_rot_speed = c.rot_speed
		c.clicked()
		if !c.should_be_clicked:
			made_mistake(c)
		else:
			if durationms > 8000:
				mistakes.append(Vector2i(c.word_index,5))
			sig_add_score.emit(score_if_successful + int(max(0, timeout_sec - durationms / 1000.0)))
			if !MatchwsG.speed_mode:
				var effect = rng.randi_range(0,1)
				if effect == 0:
					var tween_pos = MainGlobals.make_tween()
					var cp = c.position
					tween_pos.tween_property(c, "position", cp - Vector2(0,10), 0.1)
					tween_pos.tween_property(c, "position", cp, 0.1)
				else:
					var tween_scale = MainGlobals.make_tween()
					tween_scale.tween_property(c, "scale", Vector2(1.1,1.1), 0.15)
					tween_scale.tween_property(c, "scale", Vector2(1.0,1.0), 0.15)
		if !c.should_be_clicked and !MatchwsG.speed_mode:
		# if MatchwsG.moving and !c.should_be_clicked:
			await MainGlobals.sleep(1)
			c.hide_color()
			c.rot_speed = save_rot_speed
			return
		# MatchwsG.level_done = true
		can_start_clicking = false
		if !c.should_be_clicked:
			await MainGlobals.sleep(0.3 if MatchwsG.speed_mode else 1.0)
			c.rot_speed = save_rot_speed
		Log.dbg("_on_card_pressed")
		await show_correct_cards(c.should_be_clicked, _card_id)
		MatchwsG.level_done = true
		level_is_done(c.should_be_clicked, durationms / 1000.0)

func pause_state_changed():
	if game.paused():
		time_pressed_pause_ms = timems()
	else:
		var now = timems()
		var dur = now - time_pressed_pause_ms
		level_start_time_ms += dur

func _on_countup_timer_timeout() -> void:
	if game.paused() or MatchwsG.level_done or !game.playing:
		return
	if can_start_clicking:
		var now = timems()
		var duration = (now - level_start_time_ms)/1000.0
		var left_time = max(0, timeout_sec - duration)
		# update_time.emit(duration)
		update_time.emit(left_time)
		if duration >= timeout_sec and !MatchwsG.moving:
			made_mistake(null)
			can_start_clicking = false
			# await MainGlobals.sleep(0.5)
			Log.dbg("_on_countup_timer_timeout")
			await show_correct_cards(false)
			level_is_done(false, duration)
