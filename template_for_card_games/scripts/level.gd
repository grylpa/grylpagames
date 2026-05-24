extends CanvasLayer

var game: GenericGameUtil

var max_difficulty := 8	
var time_increased_difficulty_ms = 0
var difficulty := 0
var num_corrects_for_next_level := 5

var cards = []
var times_to_answer := []

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

# @export var card_scene: PackedScene = load("res://friends/scenes/card.tscn")
@export var card_scene: PackedScene = load("res://friends/scenes/resizeable_card.tscn")

var ambient_audios := [ 
	preload("res://art/sounds/ocean-waves-250310.mp3"), 
	preload("res://art/sounds/relaxing-ocean-waves-high-quality-recorded-177004.mp3"), 
	preload("res://art/sounds/small-ocean-lapping-waves-220314.mp3")
]

signal started_playing
signal sig_level_is_done(didwin:bool)

func _ready() -> void:
	game = FriendsG.game
	game.sig_time_over.connect(on_time_over)
	difficulty = FriendsG.starting_difficulty
	increase_difficulty(false)

	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

func new_game(from_scratch=true):
	game.level_is_ready = false
	if from_scratch:
		difficulty = FriendsG.starting_difficulty

	FriendsG.back_textures.shuffle()
	FriendsG.shuffle_people()

	increase_difficulty(game.need_to_increase_difficulty)
	game.need_to_increase_difficulty = false
	game.level_label_changed("Level %d" % difficulty)
	create_board()

	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")

	started_playing.emit()
	BE.upsert_game_state("Friends", 
		{"state":"new","starting_difficulty": difficulty})

func use_b12(b):
	return b == 1 or (b == 2 and game.rng.randi() % 2 == 0)

func create_board() -> void:
	while !cards.is_empty():
		cards.pop_back().queue_free()

	add_card_at(Vector2(-1,0), 1)
	add_card_at(Vector2( 0,0), 2)
	add_card_at(Vector2( 1,0), 3)

	game.level_is_ready = true

func add_card_at(p: Vector2, card_id: int):
	var card = card_scene.instantiate()
	card.board_pos = p
	card.set_id(card_id)
	add_child(card)
	cards.append(card)
	card.set_center_position(FriendsG.board_to_px(p))
	# card.position = FriendsG.board_to_px(p)
	card.card_pressed.connect(_on_card_pressed)

func find_card(card_id):
	for c in cards:
		if c.id == card_id:
			return c
	return null

func _on_card_pressed(_p, _card_id):
	var c = find_card(_card_id)
	if c != null:
		pass

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
		"difficulty": difficulty,
		"didwin": int(didwin),
	})
	if didwin:
		MainGlobals.global_level_is_done(true)
		game.need_to_increase_difficulty = true
		if difficulty >= max_difficulty:
			game.game_is_done(true,false)
		else:
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms" % mean_time_to_answer_ms()
			game.show_level_done_popup(self, "","", difficulty, textadd)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		difficulty += 1
	difficulty = clamp(difficulty, 1, max_difficulty)
	match  difficulty:
		1:	
			num_corrects_for_next_level = 5
		2:	
			num_corrects_for_next_level = 10
		3:	
			num_corrects_for_next_level = 5
		4:	
			num_corrects_for_next_level = 20
		5:	
			num_corrects_for_next_level = 20
		6:	
			num_corrects_for_next_level = 20
		7:	
			num_corrects_for_next_level = 20
		8:	
			num_corrects_for_next_level = 500
		
	# if MainGlobals.is_mobile():
	game.init_sizes()

func _process(_delta: float) -> void:
	if not game.paused() and not game.level_is_done and game.level_is_ready:
		pass
			
func on_time_over():
	game.stop_sound("ambient")
	
func mean_time_to_answer_ms() -> int:
	var N = times_to_answer.size()
	if N == 0:
		return 9999
	var s := 0
	for t in times_to_answer:
		s += t
	return roundi(s / N)

func _add_time_to_answer_ms(t_ms: int):
	times_to_answer.append(t_ms)
	while times_to_answer.size() > 10:
		times_to_answer.remove_at(0)