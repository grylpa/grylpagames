extends CanvasLayer

# PICKPOCKET: a shell game on a busy street.
#
# Each ROUND: the hustler lifts the cup with the ball under it, puts it down and shuffles the cups.
# While he does, somewhere on the street around the table a pickpocket comes up behind someone and
# lifts their wallet. When the cups stop the street FREEZES; the player taps the cup with the ball,
# then the person who was robbed (or, on later levels, the pickpocket, or "No one" when nothing
# happened). A round counts as right only when BOTH answers are.
#
# That is the whole point of the game: following the cups needs the eyes on the table (look away
# during a swap and the ball is lost), and the theft happens away from it, so it can only be caught
# out of the corner of the eye.
#
# THE THEFT IS CHOREOGRAPHED, not left to chance. At the start of a round _plan_theft() picks a
# victim already on the street and sends a new walker in from behind them at the speed that brings
# them together at a chosen moment inside the shuffle, at a spot where both will still be on screen
# when the street freezes. Nothing about the thief marks them: they come from the same pool of
# looks, at a walking speed inside the ordinary range, and blend back in afterwards.

const PASSERBY: GDScript = preload("res://pickpocket/scripts/passerby.gd")
const STREET: GDScript = preload("res://pickpocket/scripts/street.gd")
const TABLE: GDScript = preload("res://pickpocket/scripts/shell_table.gd")

var game: GenericGameUtil
var current_level_id: int = 1

# --- level params (PickpocketLevelConfig) ---
var n_cups: int = 3
var n_swaps: int = 4
var swap_ms: float = 700.0
var crowd: int = 5
var lift_ms: float = 900.0
var cue: bool = true
var thief_q: float = 0.0
var empty_p: float = 0.0
var far_thefts: bool = true   # may a theft happen across the road, by the shops (level config)
var fake_p: float = 0.0
var rounds_per_level: int = 6

const PEEK_UP_MS: float = 380.0
const PEEK_HOLD_MS: float = 700.0
const SWAP_GAP_MS: float = 60.0
const FREEZE_MS: float = 450.0
const REVEAL_MS: float = 320.0
const FEEDBACK_MS: float = 2600.0
const GAP_MS: float = 700.0

enum Phase { IDLE, PEEK, SHUFFLE, FREEZE, ASK_CUP, CUP_SHOWN, ASK_PERSON, FEEDBACK, GAP }
var phase: int = Phase.IDLE
var _phase_t0: float = 0.0
var _last_now: float = -1.0

# --- the round ---
var _swaps_left: int = 0
var _victim = null
var _thief = null
var _ask_thief: bool = false
var _empty_round: bool = false
var _cup_right: bool = false
var _picked_cup: int = -1
var _ask_t0: float = 0.0

# --- stats ---
var total_rounds: int = 0
var total_corrects: int = 0
var cup_corrects: int = 0
var person_corrects: int = 0
var times_to_answer: Array = []

# --- the scene ---
var _street: Node2D = null
var _far: Node2D = null      # the lane along the shopfronts, behind the table
var _table: Node2D = null
var _near: Node2D = null     # the lane on the near sidewalk, just behind the hustler
var _crowd_node: Node2D = null   # the onlookers at the table's front corners, nearest of all
var _crowd: Array = []           # they stand and watch; the pickpocket may be one of them
var _wallet: Node2D = null
var _glow: Node2D = null     # the lamps' light, added over everything (additive)
var _shade: Node2D = null    # the evening: darker toward the edges of the screen
var _tags: Node2D = null     # the answer's tags, over everything (passerby.draw_tag_to)
var _catcher: Control = null
var _prompt: Label = null
var _prompt_plain: StyleBoxFlat = null
var _prompt_question: StyleBoxFlat = null
var _prompt_tween: Tween = null
var _prompt_is_question: bool = false
var _noone_btn: Button = null
var _people: Array = []

# --- layout ---
var _w: float = 680.0
var _top: float = 60.0
var _bottom: float = 744.0
var _lane_y: Array = [300.0, 700.0]
var _lane_h: Array = [110.0, 130.0]
var _prompt_y: float = 600.0   # on the table's front cloth (see _layout)

# the wallet in flight: {from: Vector2, to: Vector2, t: 0..1, show: bool}
var _wallet_pos: Vector2 = Vector2.ZERO
var _wallet_show: bool = false

var slide_audio = preload("res://art/sounds/pickpocket_slide.ogg")
var tock_audio = preload("res://art/sounds/pickpocket_tock.ogg")
var whistle_audio = preload("res://art/sounds/pickpocket_whistle.ogg")
var ball_audio = preload("res://art/sounds/pickpocket_ball.ogg")
var empty_audio = preload("res://art/sounds/pickpocket_empty.ogg")
var right_audio = preload("res://art/sounds/pickpocket_right.ogg")
var wrong_audio = preload("res://art/sounds/pickpocket_wrong.ogg")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = PickpocketG.game
	game.add_sound(self, "slide", slide_audio)
	game.add_sound(self, "tock", tock_audio)
	game.add_sound(self, "whistle", whistle_audio)
	game.add_sound(self, "ball", ball_audio)
	game.add_sound(self, "empty", empty_audio)
	game.add_sound(self, "right", right_audio)
	game.add_sound(self, "wrong", wrong_audio)
	game.set_sound_volume("slide", -10.0)
	game.set_sound_volume("tock", -6.0)
	game.set_sound_volume("whistle", -8.0)
	_build()
	set_process(true)

func _build() -> void:
	_street = STREET.new()
	add_child(_street)
	# back to front: the far lane, the near lane, then the table and the hustler (everyone is
	# behind the table -- see street.gd)
	_far = Node2D.new()
	add_child(_far)
	_near = Node2D.new()
	add_child(_near)
	_table = TABLE.new()
	add_child(_table)
	_crowd_node = Node2D.new()
	add_child(_crowd_node)
	_glow = Node2D.new()
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	_shade = Node2D.new()
	_shade.draw.connect(_draw_shade)
	_wallet = Node2D.new()
	_wallet.draw.connect(_draw_wallet)
	add_child(_wallet)
	add_child(_shade)
	add_child(_glow)
	_tags = Node2D.new()
	_tags.draw.connect(func() -> void:
		for q in _all_people():
			q.draw_tag_to(_tags, _w))
	add_child(_tags)

	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_gui_input)
	add_child(_catcher)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.86)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	_prompt.add_theme_stylebox_override("normal", sb)
	_prompt_plain = sb
	# A QUESTION wears more than a feedback line: a gold edge and a shadow on its pill, bigger type
	# and a pop as it appears (_say). Plain, the two questions read like captions and were missed.
	var qsb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	qsb.bg_color = Color(0.05, 0.06, 0.11, 0.94)
	qsb.set_border_width_all(3)
	qsb.border_color = Color(0.976, 0.792, 0.353, 0.95)
	qsb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	qsb.shadow_size = 10
	qsb.shadow_offset = Vector2(0, 4)
	qsb.content_margin_top = 8
	qsb.content_margin_bottom = 10
	qsb.content_margin_left = 26
	qsb.content_margin_right = 26
	_prompt_question = qsb
	_prompt.hide()
	add_child(_prompt)

	_noone_btn = Button.new()
	_noone_btn.text = "No one"
	_noone_btn.focus_mode = Control.FOCUS_NONE
	var mk = func(bg: Color) -> StyleBoxFlat:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = bg
		s.set_corner_radius_all(14)
		s.set_content_margin_all(8)
		s.border_color = Color(1.0, 0.92, 0.62, 0.7)
		s.set_border_width_all(2)
		return s
	_noone_btn.add_theme_stylebox_override("normal", mk.call(Color(0.10, 0.11, 0.18, 0.92)))
	_noone_btn.add_theme_stylebox_override("hover", mk.call(Color(0.16, 0.17, 0.26, 0.95)))
	_noone_btn.add_theme_stylebox_override("pressed", mk.call(Color(0.06, 0.07, 0.12, 0.95)))
	_noone_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_noone_btn.pressed.connect(_on_noone_pressed)
	_noone_btn.hide()
	add_child(_noone_btn)

# --- layout ------------------------------------------------------------------

func _layout() -> void:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var bar_h_bottom: float = 70.0 if mob else 44.0
	var bottom_reserve: float = maxf(20.0, bar_h_bottom - float(MainGlobals.footer_height) + 10.0)
	_w = sw
	_top = float(MainGlobals.header_height)
	_bottom = sh - bottom_reserve
	var a: float = _bottom - _top
	# the far lane on the shops' sidewalk, the road, the near lane just behind the hustler, the table
	_lane_y = [_top + 0.29 * a, _top + 0.60 * a, _bottom + 0.03 * a]
	_lane_h = [minf(0.135 * a, 150.0), minf(0.25 * a, 260.0), minf(0.47 * a, 520.0)]
	var table_y: float = _top + 0.80 * a
	# cups the size of real ones next to the hustler, about two thirds of his head (at 0.10 of the
	# height they were as tall as his head and read as buckets)
	var cup_h: float = clampf(0.064 * a, 34.0, 70.0)
	_table.layout(sw, table_y, cup_h, 0.075 * a, n_cups)
	# the street runs to the very bottom of the screen, behind the app's bottom bar (it stopped at
	# the play area's edge and left a plain gray band under the scene)
	_street.setup(sw, _top, float(_lane_y[0]), _top + 0.315 * a, _top + 0.41 * a, float(MainGlobals.full_screen_size.y))
	# on the table's front cloth, just under the cups: where the player is already looking, and
	# where no one stands, so no answer tag can ever be under it (at the top it hid the far lane's)
	_prompt_y = table_y + cup_h * 0.65 + 6.0
	_catcher.position = Vector2.ZERO
	_catcher.size = Vector2(sw, sh)
	MainGlobals.set_font_size(_prompt, 36 if _prompt_is_question else 30)
	MainGlobals.set_font_size(_noone_btn, 26)
	_place_prompt()
	var bw: float = 220.0 if not mob else 300.0
	var bh: float = 52.0 if not mob else 80.0
	_noone_btn.position = Vector2((sw - bw) * 0.5, _top + 0.362 * a - bh * 0.5)
	_noone_btn.size = Vector2(bw, bh)
	for p in _people:
		_fit_person(p)
	_place_crowd()
	_glow.queue_redraw()
	_shade.queue_redraw()

# The prompt hugs a short line; a longer one wraps inside the screen's width. Its size is SET, not
# left to the label: a wrapping label measured before it had a width came out one word per line and
# covered the whole table.
func _place_prompt() -> void:
	var font: Font = _prompt.get_theme_font("font")
	var fs: int = _prompt.get_theme_font_size("font_size")
	var sb: StyleBox = _prompt.get_theme_stylebox("normal")
	var mx: float = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var my: float = sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)
	var max_text: float = _w - 32.0 - mx
	var one: Vector2 = font.get_multiline_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var text_w: float = minf(one.x, max_text)
	var text_h: float = font.get_multiline_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_CENTER, text_w + 1.0, fs, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if one.x > max_text else TextServer.AUTOWRAP_OFF
	var box: Vector2 = Vector2(text_w + mx + 2.0, text_h + my)
	_prompt.custom_minimum_size = Vector2.ZERO
	_prompt.size = box
	_prompt.position = Vector2((_w - box.x) * 0.5, _prompt_y)

# `question`: one of the two questions the player must answer -- bigger, framed in gold, popped in.
func _say(text: String, col: Color = Color(1.0, 0.92, 0.62), question: bool = false) -> void:
	_prompt.text = text
	_prompt.add_theme_color_override("font_color", col)
	# EVERY line is framed and popped now, not only the questions ("You missed..." read like a
	# caption too): a result wears the same pill a step smaller, its edge in the line's own color.
	var frame: StyleBoxFlat = _prompt_question
	if not question:
		frame = _prompt_question.duplicate() as StyleBoxFlat
		frame.border_color = Color(col, 0.95)
	_prompt.add_theme_stylebox_override("normal", frame)
	_prompt_is_question = question
	MainGlobals.set_font_size(_prompt, 36 if question else 30)
	_prompt.show()
	_place_prompt()
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.scale = Vector2.ONE
	_prompt.modulate.a = 1.0
	if true:
		_prompt.pivot_offset = _prompt.size * 0.5
		_prompt.scale = Vector2(0.78, 0.78)
		_prompt.modulate.a = 0.0
		_prompt_tween = create_tween()
		_prompt_tween.set_parallel(true)
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.16)
		_prompt_tween.tween_property(_prompt, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- level flow --------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if _from_scratch:
		current_level_id = PickpocketG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, PickpocketLevelConfig.max_level())
	game.need_to_increase_level = false
	_tutorial = false
	total_rounds = 0
	total_corrects = 0
	cup_corrects = 0
	person_corrects = 0
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_load_level(current_level_id)
	_layout()
	call_deferred("_layout")
	_clear_street()
	_populate()
	phase = Phase.IDLE
	_prompt.hide()
	_noone_btn.hide()
	_last_now = -1.0

	if game.tutorial_mode:
		# The tutorial teaches all of this by doing it; a briefing card first would be a wall of
		# text to dismiss before being taught it.
		_tutorial_setup()
		_layout()
		_clear_street()
		_populate()
		_on_game_popup_closed()
		return

	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	var what: String = "the pickpocket or the person robbed" if thief_q > 0.0 else "the person who was robbed"
	game.show_game_popup(self, "Level %d" % current_level_id,
		("Follow the ball under the cups, and keep an eye on the street: tap the cup, then %s.%s\n\n" +
		"Cups: %d\n" +
		"Rounds: %d") % [what, "\nSometimes no one is robbed." if empty_p > 0.0 else "", n_cups, rounds_per_level])

# THE TUTORIAL'S ROUND: slow cups, few of them, an easy theft (a bright wallet, the victim starts),
# always on the street rather than at the table, and never a question about the pickpocket or an
# empty round. Rounds keep coming until the coach is done; the level never ends under it.
var _tutorial: bool = false

func _tutorial_setup() -> void:
	_tutorial = true
	n_cups = 3
	n_swaps = 4
	swap_ms = 950.0
	crowd = 4
	lift_ms = 1500.0
	cue = true
	thief_q = 0.0
	empty_p = 0.0
	fake_p = 0.0
	rounds_per_level = 1000

# Where the coach points: the table, and the people the answer is about.
func tutorial_table_rect() -> Rect2:
	var r: Rect2 = _table.table_rect
	return Rect2(r.position.x, r.position.y - _table.cup_h * 1.2, r.size.x, r.size.y + _table.cup_h * 1.2)

# A person and the tag over their head, which the coach must not cover either.
func tutorial_victim_rect():
	if _victim != null and is_instance_valid(_victim):
		return _victim.body_rect().grow_side(SIDE_TOP, 60.0)
	return null

func tutorial_thief_rect():
	if _thief != null and is_instance_valid(_thief):
		return _thief.body_rect().grow_side(SIDE_TOP, 60.0)
	return null

# The two lanes of the street, head to foot, and the onlookers at the table's corners: what the
# coach's captions must keep off while the player is meant to be watching or choosing a person.
func tutorial_far_band() -> Rect2:
	var y: float = float(_lane_y[0])
	return Rect2(0.0, y - float(_lane_h[0]) * 1.05, _w, float(_lane_h[0]) * 1.05)

func tutorial_near_band() -> Rect2:
	var y: float = float(_lane_y[1])
	return Rect2(0.0, y - float(_lane_h[1]) * 1.05, _w, float(_lane_h[1]) * 1.05)

func tutorial_crowd_rect(side: int):
	var r: Rect2 = Rect2()
	var any: bool = false
	for p in _crowd:
		if int(p.get_meta("side", 0)) == side:
			r = p.body_rect() if not any else r.merge(p.body_rect())
			any = true
	return r if any else null

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		_layout()
		game.level_is_ready = true
		started_playing.emit()

func stop_level() -> void:
	phase = Phase.IDLE
	_prompt.hide()
	_noone_btn.hide()
	_wallet_show = false
	_wallet.queue_redraw()

func _load_level(id: int) -> void:
	var def: Dictionary = PickpocketLevelConfig.get_level(id)
	n_cups = int(def.get("cups", 3))
	n_swaps = int(def.get("swaps", 4))
	swap_ms = float(def.get("swap_ms", 700))
	crowd = int(def.get("crowd", 5))
	lift_ms = float(def.get("lift_ms", 900))
	cue = bool(def.get("cue", false))
	thief_q = float(def.get("thief_q", 0.0))
	empty_p = float(def.get("empty_p", 0.0))
	fake_p = float(def.get("fake_p", 0.0))
	far_thefts = bool(def.get("far_thefts", true))
	rounds_per_level = int(def.get("rounds", 6))
	game.level_label_changed("Level " + str(def.get("name", id)))

# NO TWO TAGS OVERLAP. The person NEARER the viewer (the larger) keeps theirs where it is; the one
# behind lifts theirs a line at a time until it is clear of every tag already placed. (Only the
# pickpocket's was ever lifted, and only when standing close to the victim: a tag over someone in
# the other lane, or a wrong pick's, could still land on another.)
func _stack_tags() -> void:
	var tagged: Array = []
	# EVERYONE the tag layer draws: the onlookers at the table are not among the street's walkers
	# (_people), and stacking only those left a pickpocket and victim both at the table overlapping
	for p in _all_people():
		if p.tag != "":
			p.tag_raise = 0.0
			tagged.append(p)
	tagged.sort_custom(func(a, b) -> bool: return a.h > b.h)
	var placed: Array = []
	for p in tagged:
		for k in 8:
			var box: Rect2 = p.tag_box(_w).grow(4.0)
			var clear: bool = true
			for q in placed:
				if box.intersects(q):
					clear = false
					break
			if clear:
				break
			p.tag_raise += 1.0
		placed.append(p.tag_box(_w))
	_tags.queue_redraw()

func _can_play() -> bool:
	return game.playing and not game.paused() and not game.level_is_done and game.level_is_ready

# --- the street --------------------------------------------------------------

func _clear_street() -> void:
	for p in _all_people():
		if is_instance_valid(p):
			p.queue_free()
	_people.clear()
	_crowd.clear()
	_victim = null
	_thief = null
	_wallet_show = false

func _base_speed(lane: int) -> float:
	return float(_lane_h[lane]) * 0.62

func _fit_person(p) -> void:
	var hj: float = float(p.get_meta("hj", 1.0))
	p.h = float(_lane_h[p.lane]) * hj
	p.position.y = float(_lane_y[p.lane])
	p.queue_redraw()

func _all_people() -> Array:
	return _people + _crowd

func _free_coat(rng: RandomNumberGenerator) -> int:
	var used: Array = []
	for p in _all_people():
		used.append(p.coat_idx)
	var free: Array = []
	for i in PASSERBY.COATS.size():
		if not used.has(i):
			free.append(i)
	if free.is_empty():
		return rng.randi() % PASSERBY.COATS.size()
	return int(free[rng.randi() % free.size()])

func _spawn(lane: int, x: float, d: int, may_stand: bool):
	var rng: RandomNumberGenerator = game.rng
	var p = PASSERBY.new()
	p.randomize_look(rng, _free_coat(rng))
	p.lane = lane
	p.dir = d
	p.set_meta("hj", rng.randf_range(0.90, 1.06))
	p.speed = _base_speed(lane) * rng.randf_range(0.80, 1.20)
	p.phase = rng.randf() * TAU
	p.position.x = x
	if may_stand and rng.randf() < 0.40:
		p.stand_at_x = rng.randf_range(_w * 0.12, _w * 0.88)
		p.stand_ms = rng.randf_range(2500.0, 7000.0)
	(_far if lane == 0 else _near).add_child(p)
	_people.append(p)
	_fit_person(p)
	return p

func _lane_count(lane: int) -> int:
	var n: int = 0
	for p in _people:
		if p.lane == lane:
			n += 1
	return n

# THE ONLOOKERS: the people the hustler is playing for, standing at the table's two front corners
# and facing the cups -- two a side, or one a side when five cups leave no room. They are nearest
# of all, so they are the largest figures. A shell game has always been the pickpocket's cover,
# so the theft may happen right here: the outer onlooker of a pair lifts the inner one's wallet.
func _build_crowd() -> void:
	var rng: RandomNumberGenerator = game.rng
	var per_side: int = 2 if n_cups <= 4 else 1
	for side in [-1, 1]:
		for k in per_side:
			var p = PASSERBY.new()
			p.randomize_look(rng, _free_coat(rng))
			p.lane = 2
			p.dir = -side           # facing the table
			p.set_meta("hj", rng.randf_range(0.93, 1.03))
			p.set_meta("slot", k)   # 0 outer, 1 inner
			p.set_meta("side", side)
			p.walking = false
			p.stand_until = 1.0e15
			p.idle = rng.randf() * TAU
			p.light_amt = 0.65
			p.light_dir = float(-side)
			_crowd_node.add_child(p)
			_crowd.append(p)
	_place_crowd()

func _place_crowd() -> void:
	var per_side: int = 2 if n_cups <= 4 else 1
	for p in _crowd:
		_fit_person(p)
		var k: int = int(p.get_meta("slot", 0))
		var side: int = int(p.get_meta("side", -1))
		# at the very edges: the outermost cup must never be behind an onlooker
		# a pair stands far enough apart that each can be told apart and tapped
		var from_edge: float = (0.042 if k == 0 else 0.152) if per_side == 2 else 0.06
		p.position.x = _w * 0.5 + float(side) * _w * (0.5 - from_edge)

# Fill the street at the start of a level: people already spread along both lanes, some standing.
func _populate() -> void:
	_build_crowd()
	var rng: RandomNumberGenerator = game.rng
	for i in crowd:
		var lane: int = i % 2
		var x: float = _w * (0.08 + 0.84 * (float(i / 2) + rng.randf_range(0.1, 0.9)) / float(maxi(1, (crowd + 1) / 2)))
		var p = _spawn(lane, x, 1 if rng.randf() < 0.5 else -1, false)
		if rng.randf() < 0.35:
			p.stand_until = game.game_time + rng.randf_range(1500.0, 6000.0)
			p.walking = false

var _next_spawn: float = 0.0

func _update_street(now: float, dt: float) -> void:
	var rng: RandomNumberGenerator = game.rng
	# keep the crowd up: a new walker from an edge, on the emptier lane, not on top of another
	if _people.size() < crowd and now >= _next_spawn:
		_next_spawn = now + rng.randf_range(500.0, 1600.0)
		var lane: int = 0 if _lane_count(0) <= _lane_count(1) else 1
		var d: int = 1 if rng.randf() < 0.5 else -1
		var x0: float = -0.3 * float(_lane_h[lane]) if d > 0 else _w + 0.3 * float(_lane_h[lane])
		var clear: bool = true
		for p in _people:
			if p.lane == lane and absf(p.position.x - x0) < float(_lane_h[lane]) * 0.7:
				clear = false
		if clear:
			_spawn(lane, x0, d, true)
	var gone: Array = []
	for p in _people:
		if p.role == 2:
			_update_thief(p, now, dt)
		elif p.stand_until >= 0.0:
			if now >= p.stand_until and p.role == 0:
				p.stand_until = -1.0
				p.walking = true
		else:
			var step: float = p.speed * dt / 1000.0
			var was: float = p.position.x
			p.position.x += float(p.dir) * step
			p.advance(step)
			if p.stand_at_x >= 0.0 and p.role == 0 and signf(was - p.stand_at_x) != signf(p.position.x - p.stand_at_x):
				p.stand_at_x = -1.0
				p.stand_until = now + p.stand_ms
				p.walking = false
				# a window shopper faces the shops half the time; seen from the side that is either way
				if rng.randf() < 0.5:
					p.dir = -p.dir
				p.queue_redraw()
		if p.position.x < -0.6 * p.h or p.position.x > _w + 0.6 * p.h:
			if p.role == 0:
				gone.append(p)
	for p in gone:
		_people.erase(p)
		p.queue_free()

# --- the light ---------------------------------------------------------------
# Two street lamps and the hustler's lantern. Each person is lit by the nearest lamp: from its side,
# and more strongly the nearer they stand to it. The shop windows add a little to the far lane.

func _lamp_xs() -> Array:
	return _street.lamp_xs()

# Everyone standing keeps moving a little (passerby.tick_idle); the onlookers lean in while the
# cups are moving. Nobody moves while the street is frozen.
func _animate_idle(dt_ms: float) -> void:
	var rng: RandomNumberGenerator = game.rng
	var watching: bool = phase == Phase.SHUFFLE or phase == Phase.PEEK
	for p in _crowd:
		p.excite = lerpf(p.excite, 1.0 if watching else 0.0, clampf(dt_ms / 600.0, 0.0, 1.0))
		p.tick_idle(dt_ms / 1000.0, rng)
	for p in _people:
		if not p.walking and p.role == 0:
			p.tick_idle(dt_ms / 1000.0, rng)

func _light_people() -> void:
	# EVERY lamp lights a person, each by how strongly it reaches them, and the side the light comes
	# from is their blend. Lit by the single NEAREST lamp, a walker's lit side flipped in one step
	# halfway between two lamps (the nearest changed) and swung from one side to the other in a few
	# steps under each lamp: their coat's shading jumped as they passed a post.
	var reach: float = _w * 0.24
	for p in _people:
		var total: float = 0.0
		var side: float = 0.0
		for x in _lamp_xs():
			var dx: float = float(x) - p.position.x
			var wgt: float = exp(-pow(dx / reach, 2.0))
			total += wgt
			side += wgt * clampf(dx / (_w * 0.16), -1.0, 1.0)
		var amt: float = minf(1.0, total) * 0.85 + (0.25 if p.lane == 0 else 0.10)
		var ld: float = clampf(side / maxf(total, 0.35), -1.0, 1.0)
		if p.lane == 2:
			# the onlookers stand at the table: it is the hustler's LANTERN that lights them, from the
			# table's side, and well (under the street lamps alone they were murky at the screen's edges)
			ld = 1.0 if p.position.x < _w * 0.5 else -1.0
			amt = 0.85
		# (the thresholds are small: stepped updates were part of the jump)
		if absf(amt - p.light_amt) > 0.004 or absf(ld - p.light_dir) > 0.004:
			p.light_amt = clampf(amt, 0.0, 1.0)
			p.light_dir = ld
			p.queue_redraw()

static var _radial: GradientTexture2D = null

func _radial_tex() -> GradientTexture2D:
	if _radial == null:
		_radial = GradientTexture2D.new()
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_radial.gradient = g
		_radial.width = 128
		_radial.height = 128
	return _radial

func _draw_glow() -> void:
	var tex: GradientTexture2D = _radial_tex()
	# every lit shop window breathes a warm haze into the street
	for wr_v in _street.window_glows():
		var wr: Rect2 = wr_v
		_glow.draw_texture_rect(tex, wr.grow_individual(wr.size.x * 0.35, wr.size.y * 0.5, wr.size.x * 0.35, wr.size.y * 0.9), false, Color(0.34, 0.22, 0.09, 0.55))
	# THE HUSTLER'S LANTERN lights his corner of the street: a wide warm bloom over the table, him and
	# the onlookers, and a hot core at the flame
	var lan: Vector2 = _table.lantern_world()
	var lr: float = _w * 0.50
	_glow.draw_texture_rect(tex, Rect2(lan - Vector2(lr, lr * 0.62), Vector2(lr * 2.0, lr * 1.24)), false, Color(0.40, 0.26, 0.10, 0.50))
	_glow.draw_texture_rect(tex, Rect2(lan - Vector2(lr * 0.30, lr * 0.26), Vector2(lr * 0.60, lr * 0.52)), false, Color(0.55, 0.38, 0.16, 0.55))
	for x in _lamp_xs():
		var head: Vector2 = _street.lamp_head(float(x))
		# the lamp's CONE: light you can see in the evening air, from the glass down to its pool
		var pool_c: Vector2 = Vector2(float(x), float(_lane_y[1]) - 4.0)
		var half: float = _w * 0.20
		_glow.draw_polygon(PackedVector2Array([head + Vector2(-7.0, 6.0), head + Vector2(7.0, 6.0),
			pool_c + Vector2(half, 0.0), pool_c + Vector2(-half, 0.0)]),
			PackedColorArray([Color(0.50, 0.38, 0.18, 0.20), Color(0.50, 0.38, 0.18, 0.20), Color(0.30, 0.22, 0.10, 0.0), Color(0.30, 0.22, 0.10, 0.0)]))
		# and a narrower, brighter core, so the cone has no hard edge
		_glow.draw_polygon(PackedVector2Array([head + Vector2(-5.0, 6.0), head + Vector2(5.0, 6.0),
			pool_c + Vector2(half * 0.5, 0.0), pool_c + Vector2(-half * 0.5, 0.0)]),
			PackedColorArray([Color(0.50, 0.38, 0.18, 0.20), Color(0.50, 0.38, 0.18, 0.20), Color(0.30, 0.22, 0.10, 0.0), Color(0.30, 0.22, 0.10, 0.0)]))
		_glow.draw_texture_rect(tex, Rect2(head - Vector2(80, 80), Vector2(160, 160)), false, Color(0.55, 0.40, 0.20, 0.55))
		_glow.draw_texture_rect(tex, Rect2(head - Vector2(20, 20), Vector2(40, 40)), false, Color(1.0, 0.85, 0.55, 0.8))
		# a soft pool right at its foot, where the post stands in its own light
		var foot: Vector2 = Vector2(float(x), _street.lamp_head(float(x)).y + _street.lamp_height())
		_glow.draw_texture_rect(tex, Rect2(foot - Vector2(_w * 0.10, 18.0), Vector2(_w * 0.20, 36.0)), false, Color(0.45, 0.33, 0.16, 0.6))
		# the pool it throws on the near sidewalk, and a fainter one across the road
		var pool_y: float = float(_lane_y[1])
		_glow.draw_texture_rect(tex, Rect2(Vector2(float(x) - _w * 0.27, pool_y - 80.0), Vector2(_w * 0.54, 150.0)), false, Color(0.42, 0.30, 0.13, 0.62))
		var far_y: float = float(_lane_y[0])
		_glow.draw_texture_rect(tex, Rect2(Vector2(float(x) - _w * 0.16, far_y - 30.0), Vector2(_w * 0.32, 60.0)), false, Color(0.20, 0.15, 0.07, 0.4))

func _draw_shade() -> void:
	# the evening: the screen's sides and its bottom fall away into dusk (smooth gradients)
	var sh: float = float(MainGlobals.full_screen_size.y)
	var dusk: Color = Color(0.02, 0.02, 0.07, 0.46)
	var clear: Color = Color(0.02, 0.02, 0.07, 0.0)
	# the whole evening a shade cooler and darker, so the lamps and windows are what light it
	_shade.draw_rect(Rect2(0.0, _top, _w, sh - _top), Color(0.05, 0.07, 0.22, 0.20))
	var side: float = _w * 0.20
	_shade.draw_polygon(PackedVector2Array([Vector2(0, _top), Vector2(side, _top), Vector2(side, sh), Vector2(0, sh)]),
		PackedColorArray([dusk, clear, clear, dusk]))
	_shade.draw_polygon(PackedVector2Array([Vector2(_w - side, _top), Vector2(_w, _top), Vector2(_w, sh), Vector2(_w - side, sh)]),
		PackedColorArray([clear, dusk, dusk, clear]))
	var road: float = _top + 0.86 * (_bottom - _top)
	_shade.draw_polygon(PackedVector2Array([Vector2(0, road), Vector2(_w, road), Vector2(_w, sh), Vector2(0, sh)]),
		PackedColorArray([Color(dusk, 0.05), Color(dusk, 0.05), Color(dusk, 0.45), Color(dusk, 0.45)]))
	var roofs: float = _top + (float(_lane_y[0]) - _top) * 0.45
	_shade.draw_polygon(PackedVector2Array([Vector2(0, _top), Vector2(_w, _top), Vector2(_w, roofs), Vector2(0, roofs)]),
		PackedColorArray([Color(dusk, 0.30), Color(dusk, 0.30), clear, clear]))

# --- the theft ---------------------------------------------------------------

# Where a person will be at time t if left to walk (or stand) as they are now.
func _x_at(p, now: float, t: float) -> float:
	if p.stand_until >= 0.0:
		return p.position.x
	return p.position.x + float(p.dir) * p.speed * (t - now) / 1000.0

# A theft at the table: the outer onlooker of a pair, standing behind the inner one's back pocket,
# lifts the wallet without taking a step.
func _plan_crowd_theft(t0: float, tf: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	var side: int = -1 if rng.randf() < 0.5 else 1
	var outer = null
	var inner = null
	for p in _crowd:
		if int(p.get_meta("side", 0)) == side:
			if int(p.get_meta("slot", 0)) == 0:
				outer = p
			else:
				inner = p
	if outer == null or inner == null:
		return false
	var lo: float = t0 + (tf - t0) * 0.12
	var hi: float = maxf(lo, tf - lift_ms - 600.0)
	# EITHER WAY ROUND: the edge onlooker robs the inner one (from the back pocket, which faces the
	# edge), or the inner one robs the edge one (from the side pocket of the coat, which faces them --
	# the edge one's back pocket faces off the screen). It was always the edge one robbing, so an
	# onlooker at the edge was never the victim.
	var th = outer
	var vi = inner
	if rng.randf() < 0.5:
		th = inner
		vi = outer
	_victim = vi
	_thief = th
	vi.role = 1
	th.role = 2
	th.plan = {"step": "approach", "tt": rng.randf_range(lo, hi), "victim": vi, "static": true, "front_pocket": th == inner}
	# drawn in front of the victim, so the hand at the pocket shows
	_crowd_node.move_child(th, -1)
	return true

# Where the thief's hand goes in: the back pocket, or (an inner onlooker robbing the one at the edge)
# the side pocket at the front of the coat.
func _steal_point(p, v) -> Vector2:
	if bool(p.plan.get("front_pocket", false)):
		return v.position + Vector2(float(v.dir) * 0.085 * v.h * v.build, -0.50 * v.h)
	return v.pocket_point()

func _plan_theft(now: float, t0: float, tf: float) -> bool:
	var rng: RandomNumberGenerator = game.rng
	var lo: float = t0 + (tf - t0) * 0.12
	# done well before the freeze, so the pickpocket has time to get away from the victim
	var hi: float = tf - lift_ms - 1200.0
	if hi < lo:
		lo = maxf(now + 600.0, hi)
	var options: Array = []
	for v in _people:
		if v.role != 0 or v.position.x < 0.0 or v.position.x > _w:
			continue
		# the tutorial's theft is in the near lane, the easiest to see; so is every theft on a level
		# without far_thefts (the far people, by the shops, are much harder to notice)
		if (_tutorial or not far_thefts) and v.lane != 1:
			continue
		var standing: bool = v.stand_until >= 0.0
		var vv: float = 0.0 if standing else v.speed
		var d: int = v.dir
		var hv: float = v.h
		var xs: float = -0.35 * hv if d > 0 else _w + 0.35 * hv
		var target_now: float = v.position.x - float(d) * 0.30 * hv
		var gap: float = (target_now - xs) * float(d)
		if gap <= 0.0:
			continue
		for k in 5:
			var s: float = _base_speed(v.lane) * (0.95 + 0.12 * float(k))
			if s <= vv * 1.15:
				continue
			var dt_meet: float = gap / (s - vv) * 1000.0
			var tt: float = now + dt_meet
			if tt < lo or tt > hi:
				continue
			var x_meet: float = v.position.x + float(d) * vv * dt_meet / 1000.0
			var x_freeze: float = v.position.x + float(d) * vv * (tf - now) / 1000.0
			# clear of the onlookers at the screen's edges, who stand in front of both lanes
			if x_meet < _w * 0.24 or x_meet > _w * 0.76:
				continue
			if x_freeze < _w * 0.22 or x_freeze > _w * 0.78:
				continue
			# a standing victim must not walk off before the freeze
			options.append({"v": v, "s": s, "tt": tt, "xs": xs})
	if options.is_empty():
		return false
	var pick: Dictionary = options[rng.randi() % options.size()]
	_victim = pick["v"]
	_victim.role = 1
	_victim.stand_at_x = -1.0
	if _victim.stand_until >= 0.0:
		_victim.stand_until = 1.0e12    # held until the round is over
	var th = _spawn(_victim.lane, float(pick["xs"]), _victim.dir, false)
	th.role = 2
	th.speed = float(pick["s"])
	th.plan = {"step": "approach", "tt": float(pick["tt"]), "victim": _victim}
	# drawn over the victim, so the reaching hand shows
	th.get_parent().move_child(th, -1)
	_thief = th
	return true

# Walk the thief through approach -> lift -> away -> (perhaps) loiter.
func _update_thief(p, now: float, dt: float) -> void:
	var step_name: String = String(p.plan.get("step", ""))
	var v = p.plan.get("victim", null)
	match step_name:
		"approach":
			if bool(p.plan.get("static", false)):
				if now >= float(p.plan["tt"]):
					p.plan["step"] = "lift"
					p.plan["t1"] = now
				return
			var step: float = p.speed * dt / 1000.0
			p.position.x += float(p.dir) * step
			p.advance(step)
			if now >= float(p.plan["tt"]) and v != null and is_instance_valid(v):
				p.position.x = v.position.x - float(v.dir) * 0.30 * v.h
				p.plan["step"] = "lift"
				p.plan["t1"] = now
		"lift":
			var u: float = (now - float(p.plan["t1"])) / lift_ms
			var fixed: bool = bool(p.plan.get("static", false))
			if fixed and v != null and is_instance_valid(v):
				p.reach_at = _steal_point(p, v) - p.position
				p.reach = clampf(u / 0.30, 0.0, 1.0) if u < 0.70 else clampf((1.0 - u) / 0.30, 0.0, 1.0)
				_lift_wallet(p, v, u)
				if u >= 1.0:
					p.reach = 0.0
					p.reach_at = Vector2.INF
					_wallet_show = false
					_wallet.queue_redraw()
					v.jolt = 0.0
					v.queue_redraw()
					p.plan["step"] = "loiter"
				p.queue_redraw()
				return
			if v != null and is_instance_valid(v):
				# keep pace with the victim
				var vstep: float = 0.0 if v.stand_until >= 0.0 else v.speed * dt / 1000.0
				p.position.x = v.position.x - float(v.dir) * 0.30 * v.h
				if vstep > 0.0:
					p.advance(vstep)
				p.walking = vstep > 0.0
				p.reach = clampf(u / 0.30, 0.0, 1.0) if u < 0.70 else clampf((1.0 - u) / 0.30, 0.0, 1.0)
				# the wallet: out of the pocket, into the hand, then into the coat
				if u >= 0.25 and u < 0.92:
					_wallet_show = true
					var from_p: Vector2 = v.pocket_point()
					var to_p: Vector2 = p.hand_point()
					var k: float = clampf((u - 0.25) / 0.30, 0.0, 1.0)
					_wallet_pos = from_p.lerp(to_p, k)
					if u > 0.70:
						_wallet_pos = p.position + Vector2(float(p.dir) * 0.06 * p.h, -0.55 * p.h)
				else:
					_wallet_show = false
				if cue and u >= 0.55:
					v.jolt = clampf((u - 0.55) / 0.30, 0.0, 1.0)
					v.queue_redraw()
				_wallet.queue_redraw()
			if u >= 1.0:
				p.reach = 0.0
				p.walking = true
				_wallet_show = false
				_wallet.queue_redraw()
				if v != null and is_instance_valid(v):
					v.jolt = 0.0
					v.queue_redraw()
				p.speed = _base_speed(p.lane) * game.rng.randf_range(0.95, 1.15)
				# half the time the pickpocket doubles back the way they came
				if game.rng.randf() < 0.5:
					p.dir = -p.dir
				p.plan["step"] = "away"
				p.plan["t2"] = now + game.rng.randf_range(700.0, 1500.0)
			p.queue_redraw()
		"away":
			var step2: float = p.speed * dt / 1000.0
			p.position.x += float(p.dir) * step2
			p.advance(step2)
			var apart: bool = v == null or not is_instance_valid(v) or absf(p.position.x - v.position.x) > p.h * 0.9
			var mid: bool = p.position.x > _w * 0.22 and p.position.x < _w * 0.78
			# in the lesson the pickpocket stops soon, still on screen, so the coach can point them out
			var lesson_stop: bool = _tutorial and p.position.x > _w * 0.12 and p.position.x < _w * 0.88
			if now >= float(p.plan["t2"]) and ((apart and mid) or lesson_stop):
				# blend in: stop at a window like anyone else
				p.plan["step"] = "loiter"
				p.walking = false
				p.queue_redraw()
		"loiter":
			pass
		"done":
			var step3: float = p.speed * dt / 1000.0
			p.position.x += float(p.dir) * step3
			p.advance(step3)
			if p.position.x < -0.6 * p.h or p.position.x > _w + 0.6 * p.h:
				p.role = 0

# The wallet's flight from the victim's pocket to the thief's hand and into the thief's coat, and
# the victim's start on the easy levels.
func _lift_wallet(p, v, u: float) -> void:
	if u >= 0.25 and u < 0.92:
		_wallet_show = true
		var k: float = clampf((u - 0.25) / 0.30, 0.0, 1.0)
		_wallet_pos = _steal_point(p, v).lerp(p.hand_point(), k)
		if u > 0.70:
			_wallet_pos = p.position + Vector2(float(p.dir) * 0.06 * p.h, -0.55 * p.h)
	else:
		_wallet_show = false
	if cue and u >= 0.55:
		v.jolt = clampf((u - 0.55) / 0.30, 0.0, 1.0)
		v.queue_redraw()
	_wallet.queue_redraw()

# For showing the answer: anywhere on screen. (_thief_visible is stricter: whether the pickpocket
# may be ASKED for, which needs them clear of the onlookers at the edges.)
func _thief_on_screen() -> bool:
	if _thief == null or not is_instance_valid(_thief):
		return false
	# an onlooker at the table is always in view, even standing at the screen's very edge (the test
	# below, a fifth of their height in from the side, left the edge onlookers without a tag)
	if _thief in _crowd:
		return true
	return _thief.position.x > _thief.h * 0.2 and _thief.position.x < _w - _thief.h * 0.2

func _thief_visible() -> bool:
	if _thief == null or not is_instance_valid(_thief):
		return false
	if _thief in _crowd:
		return true
	# a pickpocket behind an onlooker at the edges cannot be asked for
	return _thief.position.x > _w * 0.20 and _thief.position.x < _w * 0.80

func _draw_wallet() -> void:
	if not _wallet_show:
		return
	var s: float = float(_lane_h[0]) * 0.13
	if _thief != null and is_instance_valid(_thief):
		s = _thief.h * 0.13
	var col: Color = Color(1.0, 0.80, 0.15) if cue else Color(0.42, 0.25, 0.14)
	var r: Rect2 = Rect2(_wallet_pos - Vector2(s * 0.6, s * 0.42), Vector2(s * 1.2, s * 0.84))
	_wallet.draw_rect(r, col)
	_wallet.draw_rect(r, col.darkened(0.45), false, 1.5)
	_wallet.draw_line(r.position + Vector2(0, r.size.y * 0.35), r.position + Vector2(r.size.x, r.size.y * 0.35), col.darkened(0.3), 1.5)

# --- the round ---------------------------------------------------------------

func _start_round(now: float) -> void:
	var rng: RandomNumberGenerator = game.rng
	_prompt.hide()
	_noone_btn.hide()
	_picked_cup = -1
	_cup_right = false
	_table.set_cups(n_cups)
	_table.ball_cup = rng.randi() % n_cups
	_table.start_peek(_table.ball_cup, now, PEEK_UP_MS, PEEK_HOLD_MS)
	_swaps_left = n_swaps
	var lead: float = _table.lead_ms
	var t0: float = now + lead + PEEK_UP_MS * 2.0 + PEEK_HOLD_MS
	var tf: float = t0 + float(n_swaps) * (lead + swap_ms + SWAP_GAP_MS)
	_pending = []
	_empty_round = rng.randf() < empty_p
	_victim = null
	_thief = null
	# a third of the thefts happen in the crowd at the table, when there is a pair to do it
	var at_table: bool = not _empty_round and _crowd.size() >= 4 and rng.randf() < 0.34 and not _tutorial
	if at_table and not _plan_crowd_theft(t0, tf):
		at_table = false                    # no pair at the table after all: on the street, then
	if not at_table and not _empty_round:
		if not _plan_theft(now, t0, tf):
			# nobody suitable on the street right now: someone stops to look in a window
			for p in _people:
				if p.role == 0 and p.position.x > _w * 0.25 and p.position.x < _w * 0.75:
					p.stand_until = now + 1.0e9
					p.walking = false
					p.queue_redraw()
					if _plan_theft(now, t0, tf):
						break
					p.stand_until = now + rng.randf_range(500.0, 2000.0)
			if _victim == null:
				# A ROUND THAT IS NOT MEANT TO BE EMPTY MUST HAVE A THEFT (it was only the lesson's
				# rule): a window-shopper is placed mid-street to be robbed -- on the near sidewalk,
				# or failing that on the far one. Without this a round with nobody suitable in reach
				# quietly became an empty one, on level 1 too, where no round is empty and (then)
				# there was no "No one" to tap: the question could not be answered right.
				for try_lane in ([1, 0] if far_thefts and not _tutorial else [1]):
					var x: float = _w * (0.38 if rng.randf() < 0.5 else 0.62)
					var shopper = _spawn(try_lane, x, 1 if rng.randf() < 0.5 else -1, false)
					shopper.stand_until = now + 1.0e9
					shopper.walking = false
					if _plan_theft(now, t0, tf):
						break
					shopper.stand_until = now + rng.randf_range(500.0, 2000.0)
			if _victim == null:
				_empty_round = true     # still nobody: an honest empty round, and "No one" is there
	_ask_thief = false
	phase = Phase.PEEK
	_phase_t0 = now
	game.play_sound("tock")

# The next swap is chosen one swap AHEAD, so the hustler's hands can already be on their way to
# those two cups while the current pair settles.
var _pending: Array = []
var _slide_at: float = -1.0

func _pick_swap() -> Array:
	var rng: RandomNumberGenerator = game.rng
	var a: int = rng.randi() % n_cups
	var b: int = (a + 1 + rng.randi() % (n_cups - 1)) % n_cups
	return [a, b, rng.randf() < fake_p]

func _next_swap(now: float) -> void:
	if _pending.is_empty():
		_pending = _pick_swap()
	_table.start_swap(int(_pending[0]), int(_pending[1]), now, swap_ms, bool(_pending[2]))
	_swaps_left -= 1
	_pending = []
	if _swaps_left > 0:
		_pending = _pick_swap()
		_table.set_next(int(_pending[0]), int(_pending[1]))
	# the slide is heard when the cups move, not when the hands set off
	_slide_at = now + _table.lead_ms

func _freeze(now: float) -> void:
	phase = Phase.FREEZE
	_phase_t0 = now
	game.tutorial_notify("street_frozen")
	# everyone stops where they are, mid-stride: the street is a photograph now
	game.play_sound("whistle")
	if _thief != null and is_instance_valid(_thief) and String(_thief.plan.get("step", "")) != "loiter":
		_thief.plan["step"] = "loiter"
	_ask_thief = not _empty_round and _thief_visible() and game.rng.randf() < thief_q

func _ask_cup() -> void:
	phase = Phase.ASK_CUP
	_say("Where is the ball?", Color(1.0, 0.92, 0.62), true)

func _ask_person(now: float) -> void:
	phase = Phase.ASK_PERSON
	_ask_t0 = now
	_say("Who was the pickpocket?" if _ask_thief else "Who was robbed?", Color(1.0, 0.92, 0.62), true)
	# "No one" is offered on EVERY level, also where no round is ever empty: a button that appeared
	# only where it could be the answer would say something, and a round that came out empty by
	# accident must still be answerable.
	_noone_btn.visible = true

func _on_cup_picked(c: int, now: float) -> void:
	_picked_cup = c
	_cup_right = c == _table.ball_cup
	_table.start_reveal(c, now, REVEAL_MS)
	phase = Phase.CUP_SHOWN
	_phase_t0 = now
	_prompt.hide()
	game.tutorial_notify("cup_picked")

func _on_person_picked(p, now: float) -> void:
	var answer = _thief if _ask_thief else _victim
	_resolve(p != null and p == answer, p, now)

func _on_noone_pressed() -> void:
	if phase != Phase.ASK_PERSON or not _can_play():
		return
	_resolve(_empty_round, null, game.game_time)

func _resolve(person_right: bool, picked, now: float) -> void:
	_noone_btn.hide()
	times_to_answer.append(maxf(0.0, now - _ask_t0))
	while times_to_answer.size() > 30:
		times_to_answer.remove_at(0)
	total_rounds += 1
	if _cup_right:
		cup_corrects += 1
	if person_right:
		person_corrects += 1
	var both: bool = _cup_right and person_right
	var pts: int = (5 if _cup_right else 0) + (10 if person_right else 0) + (5 if both else 0)
	if pts > 0:
		game.add_score_and_time(pts, 0)
	if both:
		total_corrects += 1
		game.add_correct_or_mistake(1, 0)
		game.play_sound("right")
	else:
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
	MainGlobals.global_update_hud()
	# show what happened on the street
	if _victim != null and is_instance_valid(_victim):
		_victim.set_mark(PASSERBY.Mark.VICTIM, "Robbed")
	if _thief_on_screen():
		_thief.set_mark(PASSERBY.Mark.THIEF, "Pickpocket")
	if picked != null and not person_right:
		if picked == _victim:
			picked.set_mark(PASSERBY.Mark.PICKED_WRONG, "Robbed (your pick)")
		else:
			picked.set_mark(PASSERBY.Mark.PICKED_WRONG, "Your pick")
	_stack_tags()
	var text: String
	var col: Color
	if both:
		text = "Both right!  +%d" % pts
		col = Color(0.45, 0.95, 0.50)
	elif _cup_right:
		text = "Found the ball, missed the theft"
		col = Color(1.0, 0.70, 0.30)
	elif person_right:
		text = "Caught the theft, lost the ball"
		col = Color(1.0, 0.70, 0.30)
	else:
		text = "Missed both"
		col = Color(1.0, 0.40, 0.35)
	if _empty_round and picked != null:
		text += "\nNo one was robbed this time"
	elif not _empty_round and picked == null:
		text += "\nSomeone was robbed"
	_say(text, col)
	phase = Phase.FEEDBACK
	_phase_t0 = now
	_tags.queue_redraw()
	# LAST: the tutorial freezes the game the moment it hears this, so the tags have to be on
	# already (notified first, the coach pointed at the victim with no "Robbed" over them)
	game.tutorial_notify("person_picked")

func _end_round(now: float) -> void:
	for p in _crowd:
		# the onlookers stay where they are, watching the next round
		p.set_mark(PASSERBY.Mark.NONE)
		p.tag_raise = 0.0
		p.role = 0
		p.plan = {}
	for p in _people:
		p.set_mark(PASSERBY.Mark.NONE)
		p.tag_raise = 0.0
		if p.role == 1:
			p.role = 0
			if p.stand_until >= 0.0:
				p.stand_until = now + game.rng.randf_range(600.0, 2500.0)
		elif p.role == 2:
			# the pickpocket strolls off the street
			p.plan = {"step": "done"}
			p.walking = true
			p.speed = _base_speed(p.lane) * 0.95
	_victim = null
	_thief = null
	_table.lower_all()
	_prompt.hide()
	if total_rounds >= rounds_per_level:
		_level_done()
		return
	phase = Phase.GAP
	_phase_t0 = now

# --- frame -------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _can_play():
		_last_now = -1.0
		return
	var now: float = game.game_time
	var dt: float = 0.0 if _last_now < 0.0 else clampf(now - _last_now, 0.0, 100.0)
	_last_now = now
	var frozen: bool = phase in [Phase.FREEZE, Phase.ASK_CUP, Phase.CUP_SHOWN, Phase.ASK_PERSON, Phase.FEEDBACK]
	if not frozen:
		_update_street(now, dt)
		for p in _crowd:
			if p.role == 2:
				_update_thief(p, now, dt)
		_animate_idle(dt)
	_table.update(now)
	if _slide_at >= 0.0 and now >= _slide_at:
		_slide_at = -1.0
		game.play_sound("slide")
	_light_people()
	_tags.queue_redraw()
	var el: float = now - _phase_t0
	match phase:
		Phase.IDLE:
			_start_round(now)
		Phase.PEEK:
			if not _table.busy():
				phase = Phase.SHUFFLE
				_phase_t0 = now
				_next_swap(now)
		Phase.SHUFFLE:
			if not _table.busy() and el >= _table.lead_ms + swap_ms + SWAP_GAP_MS:
				if _swaps_left > 0:
					_phase_t0 = now
					_next_swap(now)
				else:
					_freeze(now)
		Phase.FREEZE:
			if el >= FREEZE_MS:
				_ask_cup()
		Phase.CUP_SHOWN:
			# a wrong cup: the right one comes up too, so the player sees where the ball went
			if el >= REVEAL_MS + 450.0 and not _cup_right and not _table.busy() \
					and not _table.is_lifted(_table.ball_cup):
				_table.start_reveal(_table.ball_cup, now, REVEAL_MS)
				game.play_sound("ball")
			if el >= REVEAL_MS * 2.0 + 750.0:
				_ask_person(now)
		Phase.FEEDBACK:
			if el >= FEEDBACK_MS:
				_end_round(now)
		Phase.GAP:
			if el >= GAP_MS:
				_start_round(now)

# --- input -------------------------------------------------------------------

func _on_catcher_gui_input(event: InputEvent) -> void:
	if not _can_play():
		return
	if event is InputEventMouseMotion and phase == Phase.ASK_PERSON and not MainGlobals.is_mobile():
		var hov = _person_at(event.position)
		for p in _all_people():
			var m: int = PASSERBY.Mark.HOVER if p == hov else PASSERBY.Mark.NONE
			if p.mark != m:
				p.set_mark(m)
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now: float = game.game_time
	if phase == Phase.ASK_CUP:
		var c: int = _table.cup_at(event.position)
		if c >= 0:
			get_viewport().set_input_as_handled()
			_on_cup_picked(c, now)
			game.play_sound("ball" if c == _table.ball_cup else "empty")
	elif phase == Phase.ASK_PERSON:
		var p = _person_at(event.position)
		if p != null:
			get_viewport().set_input_as_handled()
			for q in _all_people():
				q.set_mark(PASSERBY.Mark.NONE)
			_on_person_picked(p, now)

# The person under a point: the near lane before the far one, and within a lane the one drawn on
# top. A finger is wide, so a person's whole figure is the target.
# The person a tap means: the one whose body, EXACTLY as drawn, is under the point and in front --
# nearer lanes first, and within a lane whoever is drawn on top (passerby.hit). A box round each
# figure picked the wrong one of two overlapping onlookers. Only a tap that lands on no body at all
# (a fat finger just beside someone) falls back to the nearest figure whose box holds it.
func _person_at(pt: Vector2):
	for lane_node in [_crowd_node, _near, _far]:
		var kids: Array = lane_node.get_children()
		kids.reverse()
		for p in kids:
			if (p in _people or p in _crowd) and p.hit(pt):
				return p
	var best = null
	var best_d: float = 1.0e9
	var lane_bias: Dictionary = {_crowd_node: 0.0, _near: 0.04, _far: 0.08}
	for lane_node in [_crowd_node, _near, _far]:
		for p in lane_node.get_children():
			if not (p in _people or p in _crowd) or not p.body_rect().has_point(pt):
				continue
			var d: float = absf(pt.x - p.position.x) / maxf(1.0, p.h) + float(lane_bias[lane_node])
			if d < best_d:
				best_d = d
				best = p
	return best

# --- level end ---------------------------------------------------------------

func _level_done() -> void:
	if game.level_is_done:
		return
	game.level_is_done = true
	phase = Phase.IDLE
	game.sig_level_is_done.emit(true)
	var pct: int = pct_correct()
	var need: int = int(PickpocketLevelConfig.get_level(current_level_id).get("pass_pct", 70))
	var passed: bool = pct >= need
	MainGlobals.global_level_is_done(passed)
	if current_level_id >= PickpocketLevelConfig.max_level():
		sig_level_is_done.emit(true)
		return
	game.need_to_increase_level = passed
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nBoth right: %d of %d\nBall found: %d of %d\nStreet right: %d of %d\n\n%s" % [
		total_corrects, total_rounds, cup_corrects, total_rounds, person_corrects, total_rounds,
		("Level passed. On to level %d." % (current_level_id + 1)) if passed
			else "You need at least %d%% of the rounds with both right to pass to the next level." % need]
	game.show_level_done_popup(self, "", "", current_level_id, extra, passed)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func mean_response_time_ms() -> int:
	if times_to_answer.is_empty():
		return 9999
	var s: float = 0.0
	for t in times_to_answer:
		s += t
	return roundi(s / times_to_answer.size())

func pct_correct() -> int:
	if total_rounds == 0:
		return 0
	return roundi(100.0 * float(total_corrects) / float(total_rounds))

func tick() -> void:
	pass
