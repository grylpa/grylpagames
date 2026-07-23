extends CanvasLayer

# Couples gameplay: each board shows an NC x NR grid of dino cards. Exactly ONE image
# appears TWICE (the two copies are placed non-adjacent unless the grid is too small).
# The player finds the pair and taps both cards. Modeled on the Dino game — same dino
# pictures, white zigzag card frame, dino background, phase machine, scoring and level
# flow (per-level time budget that advances the level when it elapses).

var game: GenericGameUtil

var current_level_id: int = 1

# --- level params (from CouplesLevelConfig) ---
var nc: int = 2
var nr: int = 2
var show_time_ms: float = 6000.0
var gap_ms: float = 1000.0
var duration_sec: int = 40

# --- board state ---
var _cards: Array = []          # [{node, img_idx, cell, pos:Vector2, rect:Rect2}]
var _target_cells: Array = []   # the two cell indices holding the duplicated image
var _selected: int = -1         # index into _cards of the currently selected card (-1 none)
var _answered: bool = false

# --- grid area (from _layout) ---
var _grid_left: float = 0.0
var _grid_top: float = 0.0
var _grid_w: float = 200.0
var _grid_h: float = 200.0

# --- phase machine ---
enum Phase { IDLE, SHOW, FEEDBACK, GAP }
var phase: int = Phase.IDLE
var _phase_start_ms: float = 0.0
var _show_start_ms: float = 0.0

# --- per-level stats ---
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []

# --- ui (built in code) ---
var _bg: TextureRect = null
var _instruction: Label = null
var _feedback: Label = null
var _bar_track: ColorRect = null
var _bar_fill: ColorRect = null
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0

const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")  # shared card (default thin frame)
const CARD_ASPECT: float = 566.0 / 374.0  # uniform card frame aspect: max dino img height / max width
                                          # (cards use FILL fit, so every card is exactly this aspect)
const WHITE: Color = Color(1, 1, 1, 1)
const FEEDBACK_MS: float = 950.0

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = CouplesG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	_build_ui()
	set_process(true)

# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_bar_track = ColorRect.new()
	_bar_track.color = Color(0, 0, 0, 0.38)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.3, 0.8, 0.4, 1.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	add_child(_bar_fill)

	_instruction = _make_label(30, Color(1, 1, 1, 1))
	_instruction.text = "Tap the two matching cards"
	add_child(_instruction)

	_feedback = _make_label(84, Color(0.2, 0.8, 0.3, 1.0))
	_feedback.text = ""
	_feedback.z_index = 30
	_feedback.hide()
	add_child(_feedback)

func _make_label(font_size: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	c.custom_minimum_size = Vector2(w, h)

func _layout() -> void:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var hh: float = float(MainGlobals.header_height)

	_instruction.add_theme_font_size_override("font_size", 38 if mob else 28)
	_feedback.add_theme_font_size_override("font_size", 110 if mob else 78)

	# timeout bar just under the header (level label is moved down below it in main.gd)
	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	_bar_fill.size = Vector2(_bar_full_w, _bar_h)

	# instruction below the (moved) level number
	var instr_line: float = 50.0 if mob else 38.0
	var text_top: float = hh + (96.0 if mob else 84.0)
	_place(_instruction, 0.0, text_top, sw, instr_line)

	# grid area: from below the instruction down to just above the app bottom button bar.
	# That bar is anchored to the full-canvas bottom and is taller than the footer reserve on
	# mobile (~70px vs ~44px desktop), so screen_size (sh) doesn't fully exclude it — subtract
	# its intrusion so the grid never runs under the bar on any platform.
	_grid_top = text_top + instr_line + (14.0 if mob else 10.0)
	var bar_h: float = 70.0 if mob else 44.0
	var bottom_reserve: float = maxf(20.0, bar_h - float(MainGlobals.footer_height) + 10.0)
	_grid_h = maxf(50.0, (sh - bottom_reserve) - _grid_top)
	var side: float = 16.0
	_grid_left = side
	_grid_w = sw - side * 2.0

	# feedback overlays the (fixed) center of the grid
	_place(_feedback, 0.0, _grid_top + _grid_h * 0.5 - 60.0, sw, 120.0)

	# reposition an existing board to the (possibly new) area
	if not _cards.is_empty():
		_position_cards()

# --- Level flow -------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if _from_scratch:
		current_level_id = CouplesG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, CouplesLevelConfig.max_level())
	game.need_to_increase_level = false
	total_rounds = 0
	total_corrects = 0
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_clear_board()
	_answered = false
	phase = Phase.IDLE
	if _bar_fill != null:
		_bar_fill.visible = false
	_load_level(current_level_id)
	_layout()
	call_deferred("_layout")  # re-apply once the menu->level transition settles (see dino)
	_feedback.hide()

	var intro: PopupText = game.show_text_popup(self, "Level %d" % current_level_id,
		# parentheses required — `%` binds tighter than `+`
		("Find the two\nmatching cards\nand tap them.\n\n" +
		"Grid: %d x %d\n" +
		"Board time: %s\n" +
		"Total: %s") % [
			nc, nr, _fmt_secs(show_time_ms / 1000.0), _fmt_secs(float(duration_sec))
		])
	intro.closed.connect(_on_game_popup_closed)

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		_layout()
		game.level_is_ready = true
		started_playing.emit()

func stop_level() -> void:
	_clear_board()
	phase = Phase.IDLE
	_answered = true
	if _feedback != null:
		_feedback.hide()
	if _bar_fill != null:
		_bar_fill.visible = false

func _load_level(id: int) -> void:
	var def: Dictionary = CouplesLevelConfig.get_level(id)
	nc = maxi(2, int(def.get("nc", 2)))
	nr = maxi(2, int(def.get("nr", 2)))
	show_time_ms = float(def.get("show_time_sec", 6.0)) * 1000.0
	gap_ms = float(def.get("gap_sec", 1.0)) * 1000.0
	duration_sec = int(def.get("duration_sec", 40))

	var bgpath: String = "res://art/dinos/bk1.jpg"
	if ResourceLoader.exists(bgpath):
		_bg.texture = load(bgpath)

	game.set_reset_time_left(duration_sec)
	game.set_time_left(0, 0, duration_sec)
	game.level_label_changed("Level " + str(def.get("name", id)))

# --- Board construction -----------------------------------------------------

func _show_board() -> void:
	_clear_board()
	_build_board()
	_selected = -1
	_answered = false
	_feedback.hide()
	phase = Phase.SHOW
	_show_start_ms = game.game_time
	_phase_start_ms = game.game_time

func _build_board() -> void:
	var cells: int = nc * nr
	var avail: int = CouplesG.num_dinos()
	var num_distinct: int = mini(cells - 1, avail)

	# distinct dino image indices for this board
	var pool: Array = []
	for i in avail:
		pool.append(i)
	pool.shuffle()
	var imgs: Array = pool.slice(0, num_distinct)

	# one of them is the duplicated image
	var target_img: int = imgs[game.rng.randi_range(0, imgs.size() - 1)]
	_target_cells = _pick_target_cells(nc, nr)

	# fill the cell -> image map
	var content: Array = []
	content.resize(cells)
	content[_target_cells[0]] = target_img
	content[_target_cells[1]] = target_img
	var others: Array = imgs.duplicate()
	others.erase(target_img)
	var free_cells: Array = []
	for c in cells:
		if c != _target_cells[0] and c != _target_cells[1]:
			free_cells.append(c)
	free_cells.shuffle()
	for i in mini(others.size(), free_cells.size()):
		content[free_cells[i]] = others[i]

	# create cards, each with a transparent hit Control on top (GUI handles the coordinate
	# transform automatically — more robust than manual hit-testing in _input).
	for cell in cells:
		var img_idx: int = int(content[cell])
		var card = CARD_SCRIPT.new()
		card.fit = CARD_SCRIPT.Fit.FILL        # uniform frame; image stretched to fill it
		card.fixed_aspect = CARD_ASPECT
		add_child(card)
		card.setup(CouplesG.dino_texture(img_idx), WHITE)
		var idx: int = _cards.size()
		var hit: Control = Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect(_on_card_gui_input.bind(idx))
		add_child(hit)
		_cards.append({"node": card, "hit": hit, "img_idx": img_idx, "cell": cell, "pos": Vector2.ZERO, "rect": Rect2()})
	_position_cards()

func _position_cards() -> void:
	# Card size is derived purely from the available grid area (`_grid_*`), so it adapts to any
	# platform/screen — no mobile/desktop-specific sizes. Between cards AND at the outer edges
	# we reserve exactly enough room for the enlarge pop: a selected card scales to 1.12, i.e.
	# grows ENLARGE/2 = 0.06 of its size on each side. So two adjacent cards need ENLARGE*size
	# of clear space between them, and an edge card needs ENLARGE/2*size to the area boundary.
	# Small absolute minimums (MIN_GAP/MIN_EDGE) keep un-enlarged cards from visually touching.
	var enlarge: float = 0.12
	var min_gap: float = 4.0
	var min_edge: float = 4.0

	# Largest card that fits each axis once those gaps/edges are reserved. Solving
	#   n*size + (n-1)*(enlarge*size + min_gap) + 2*(enlarge/2*size + min_edge) <= avail
	# gives  size <= (avail - (n-1)*min_gap - 2*min_edge) / (n*(1+enlarge)).
	var wfit: float = (_grid_w - float(nc - 1) * min_gap - 2.0 * min_edge) / (float(nc) * (1.0 + enlarge))
	var hfit: float = (_grid_h - float(nr - 1) * min_gap - 2.0 * min_edge) / (float(nr) * (1.0 + enlarge))
	var card_w: float = maxf(20.0, minf(wfit, hfit / CARD_ASPECT))
	var ch: float = card_w * CARD_ASPECT  # exact: couples cards use FILL fit at CARD_ASPECT

	var gap_x: float = enlarge * card_w + min_gap
	var gap_y: float = enlarge * ch + min_gap

	# Center the block (cards + inter-card gaps) in the grid area; leftover space becomes outer
	# margin, always >= the enlarge/2 edge room the fit reserved (more on the unconstrained axis).
	var block_w: float = float(nc) * card_w + float(nc - 1) * gap_x
	var block_h: float = float(nr) * ch + float(nr - 1) * gap_y
	var left0: float = _grid_left + maxf(0.0, (_grid_w - block_w) * 0.5)
	var top0: float = _grid_top + maxf(0.0, (_grid_h - block_h) * 0.5)

	for entry in _cards:
		var cell: int = entry["cell"]
		var r: int = cell / nc
		var c: int = cell % nc
		var card = entry["node"]
		if not is_instance_valid(card):
			continue
		card.set_width(card_w)
		var cx: float = left0 + float(c) * (card_w + gap_x) + card_w * 0.5
		var cy: float = top0 + float(r) * (ch + gap_y)
		var pos: Vector2 = Vector2(cx, cy)
		card.position = pos
		card.scale = Vector2(1, 1)
		card.z_index = 0
		card.modulate = WHITE
		entry["pos"] = pos
		entry["rect"] = Rect2(cx - card_w * 0.5, cy, card_w, ch)
		var hit = entry.get("hit", null)
		if hit != null and is_instance_valid(hit):
			hit.position = Vector2(cx - card_w * 0.5, cy)
			hit.size = Vector2(card_w, ch)

func _pick_target_cells(cols: int, rows: int) -> Array:
	# two cells with Chebyshev distance >= 2 (not 8-neighbors); fall back to any two
	# distinct cells when that's impossible (e.g. a 2x2 grid).
	var cells: int = cols * rows
	# Only HALF the time require the pair to be non-adjacent (Chebyshev distance >= 2).
	# Always requiring it has odd side effects -- e.g. in a 3x3 the center cell (a neighbor
	# of every other cell) could never be part of the couple. The other half allows any two
	# distinct cells, so the pair is sometimes adjacent.
	if game.rng.randf() < 0.5:
		for _attempt in 300:
			var a: int = game.rng.randi_range(0, cells - 1)
			var b: int = game.rng.randi_range(0, cells - 1)
			if a != b and _cheby(a, b, cols) >= 2:
				return [a, b]
	var x: int = game.rng.randi_range(0, cells - 1)
	var y: int = game.rng.randi_range(0, cells - 1)
	while y == x:
		y = game.rng.randi_range(0, cells - 1)
	return [x, y]

func _cheby(a: int, b: int, cols: int) -> int:
	return maxi(absi(a / cols - b / cols), absi(a % cols - b % cols))

func _clear_board() -> void:
	for entry in _cards:
		var node = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
		var hit = entry.get("hit", null)
		if hit != null and is_instance_valid(hit):
			hit.queue_free()
	_cards.clear()
	_target_cells = []
	_selected = -1

# --- Selection / resolution -------------------------------------------------

func _highlight(idx: int, on: bool) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	var entry: Dictionary = _cards[idx]
	var card = entry["node"]
	if not is_instance_valid(card):
		return
	var ch: float = (entry["rect"] as Rect2).size.y
	if on:
		card.scale = Vector2(1.12, 1.12)
		card.z_index = 10
		card.position = (entry["pos"] as Vector2) - Vector2(0.0, ch * 0.06)  # grow centered-ish
	else:
		card.scale = Vector2(1, 1)
		card.z_index = 0
		card.position = entry["pos"]

func _on_card_tapped(idx: int) -> void:
	# ignore a too-early tap (e.g. a leftover press as the board appears)
	if game.game_time - _show_start_ms < 150.0:
		return
	if _selected < 0:
		_selected = idx
		_highlight(idx, true)
	elif _selected == idx:
		_highlight(idx, false)
		_selected = -1
	else:
		var is_match: bool = int(_cards[_selected]["img_idx"]) == int(_cards[idx]["img_idx"])
		if is_match:
			# correct: enlarge the 2nd card too and leave BOTH enlarged until the board clears
			_highlight(idx, true)
		else:
			_highlight(_selected, false)
		_selected = -1
		_resolve(is_match, false)

func _resolve(is_correct: bool, timed_out: bool) -> void:
	if _answered:
		return
	_answered = true
	total_rounds += 1
	_reveal_target()
	if is_correct:
		total_corrects += 1
		var elapsed: float = game.game_time - _show_start_ms
		times_to_answer.append(maxf(elapsed, 0.0))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var bonus: int = maxi(0, 10 - int(elapsed / 700.0))
		game.add_score_and_time(15 + bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		_feedback.text = "Correct!"
		_feedback.add_theme_color_override("font_color", Color(0.25, 0.85, 0.35, 1.0))
	else:
		var penalty: int = mini(4, maxi(0, game.score))
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		_feedback.text = "Too slow" if timed_out else "Wrong"
		_feedback.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25, 1.0))
	_feedback.show()
	MainGlobals.global_update_hud()
	phase = Phase.FEEDBACK
	_phase_start_ms = game.game_time

func _reveal_target() -> void:
	# tint the correct pair green so the player always sees the answer
	for entry in _cards:
		if _target_cells.has(entry["cell"]):
			var card = entry["node"]
			if is_instance_valid(card):
				card.modulate = Color(0.45, 1.0, 0.45, 1.0)
				card.z_index = 5

# --- Frame update -----------------------------------------------------------

func _can_play() -> bool:
	return game.playing and not game.paused() and not game.level_is_done and game.level_is_ready

func _process(_dt: float) -> void:
	if not _can_play():
		return
	var now: float = game.game_time
	match phase:
		Phase.IDLE:
			_bar_fill.visible = false
			_show_board()
		Phase.SHOW:
			var frac: float = clampf(1.0 - (now - _show_start_ms) / show_time_ms, 0.0, 1.0)
			_bar_fill.visible = true
			_bar_fill.size = Vector2(_bar_full_w * frac, _bar_h)
			_bar_fill.color = Color(0.9, 0.3, 0.25, 1.0).lerp(Color(0.3, 0.8, 0.4, 1.0), frac)
			if now - _show_start_ms >= show_time_ms:
				_resolve(false, true)
		Phase.FEEDBACK:
			_bar_fill.visible = false
			if now - _phase_start_ms >= FEEDBACK_MS:
				phase = Phase.GAP
				_phase_start_ms = now
				_feedback.hide()
		Phase.GAP:
			_bar_fill.visible = false
			if now - _phase_start_ms >= gap_ms:
				_show_board()

# --- Input (tap cards) ------------------------------------------------------

func _on_card_gui_input(event: InputEvent, idx: int) -> void:
	# Handle ONLY the mouse-button press. Both mouse->touch and touch->mouse emulation are
	# on, so a single tap fires a mouse event AND a touch event; processing both would
	# select then immediately deselect the card (net nothing). Mouse-button alone covers
	# both mouse and touch.
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not _can_play() or phase != Phase.SHOW or _answered:
		return
	get_viewport().set_input_as_handled()
	_on_card_tapped(idx)

# --- Level completion -------------------------------------------------------

func _on_time_over() -> void:
	if game.level_is_done:
		return
	_level_done(true)

func _level_done(didwin: bool) -> void:
	if game.level_is_done:
		return
	game.level_is_done = true
	_clear_board()
	_feedback.hide()
	game.sig_level_is_done.emit(didwin)
	if not didwin:
		sig_level_is_done.emit(false)
		return
	MainGlobals.global_level_is_done(true)
	if current_level_id >= CouplesLevelConfig.max_level():
		sig_level_is_done.emit(true)
		return
	game.need_to_increase_level = true
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s" % [
		pct_correct(),
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A"
	]
	game.show_level_done_popup(self, "", "", current_level_id, extra)

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

func _fmt_secs(s: float) -> String:
	var t: int = int(round(s))
	if t >= 60:
		return "%d:%02d min" % [t / 60, t % 60]
	return "%d sec" % t

func tick() -> void:
	pass
