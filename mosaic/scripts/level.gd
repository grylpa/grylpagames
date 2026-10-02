extends CanvasLayer

# Mosaic: a picture is shown for a countdown, then cut into pieces and shuffled, and the player
# drags the pieces back where they were -- from memory. A round ends when the picture is whole again
# or when its time runs out. THE SAME PICTURE comes back for every one of the level's rounds -- shown
# again, reshuffled, rebuilt -- whether the last round was rebuilt or not, so what is measured is how
# much faster the player gets at the exact same picture: memory, and how fast a new memory is learned.
#
# THE SHUFFLE IS NOT SHOWN AS MOVEMENT. Pieces sliding to their new places would be a trail to
# follow back, so every piece flips over where it stands (in a staggered wave), the board is briefly
# all backs, and every piece flips up again already in its shuffled place.
#
# Input is the mouse button and mouse motion only: touch is emulated as mouse, and taking both
# would see every touch twice.

var game: GenericGameUtil
var current_level_id: int = 1

# --- level params (MosaicLevelConfig) ---
var cols: int = 3
var rows: int = 3
var picture_kind: String = "scenery"
var study_ms: float = 8000.0
var restudy_ms: float = 4000.0      # the countdown before a round that follows a rebuilt one
var round_ms: float = 45000.0
var max_rounds: int = 4
var pass_pct: int = 60
var rotation_on: bool = false

# --- board ---
# One per piece: {node: TextureRect, frame: Control, home: int, cell: int, turns: int}.
# `home` is the cell the piece belongs in, `cell` where it is now, `turns` quarter turns clockwise
# away from upright.
var pieces: Array = []
var _picture: ImageTexture = null
var _board_rect: Rect2 = Rect2()
var _cell_w: float = 80.0
var _cell_h: float = 80.0
var _piece_aspect: float = 1.0      # height over width: 1 except on a dino card

# --- phases ---
enum Phase { IDLE, STUDY, SHUFFLE, PLAY, SOLVED, TIMEUP, ROUND_CARD, REVEAL, DONE }
var phase: int = Phase.IDLE
var _phase_start: float = 0.0
var _study_caption: String = ""
var _after_rebuilt: bool = false        # this round follows a rebuilt one: the shorter countdown
var _awaiting_round_card: bool = false
var round_index: int = 0          # 1-based once a round starts

# --- what is recorded, per level ---
var moves: int = 0                # swaps
var turns_made: int = 0           # quarter turns
var round_times_ms: Array = []    # play time of every round, rebuilt or not
var round_solved: Array = []      # whether each round was rebuilt (in step with round_times_ms)
var first_try_pct: int = -1       # pieces in place when the first round ended
var failed_rounds: int = 0
var solved_rounds: int = 0

# --- dragging ---
const TAP_SLOP: float = 12.0
var _press_piece: int = -1
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO

# --- ui (built in code) ---
var _bg: ColorRect = null
var _board_bg: ColorRect = null
var _board: Control = null
var _caption: Label = null
var _count: Label = null
var _feedback: Label = null
var _bar_track: ColorRect = null
var _bar_fill: ColorRect = null
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0

const BG: Color = Color(0.075, 0.09, 0.14)
const BOARD_BG: Color = Color(0.05, 0.06, 0.09)
const FLIP_SEC: float = 0.16
const STAGGER_SEC: float = 0.30
const FEEDBACK_SEC: float = 1.0

var swap_audio = preload("res://art/sounds/swoosh.mp3")
var solved_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")

signal sig_level_is_done(didwin: bool)
signal started_playing

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	game = MosaicG.game
	game.add_sound(self, "swap", swap_audio)
	game.add_sound(self, "solved", solved_audio)
	_rng.randomize()
	_build_ui()

# --- UI ------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_board_bg = ColorRect.new()
	_board_bg.color = BOARD_BG
	_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_bg)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	_bar_track = ColorRect.new()
	_bar_track.color = Color(0, 0, 0, 0.38)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	add_child(_bar_fill)
	_caption = _make_label(Color(1, 1, 1, 0.92))
	add_child(_caption)
	_count = _make_label(Color(0.976, 0.792, 0.353))
	_count.z_index = 30
	add_child(_count)
	_feedback = _make_label(Color(0.3, 0.9, 0.45))
	_feedback.z_index = 40
	_feedback.hide()
	add_child(_feedback)

func _make_label(col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)

func _layout() -> void:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var hh: float = float(MainGlobals.header_height)
	MainGlobals.set_font_size(_caption, 20)
	MainGlobals.set_font_size(_count, 44)
	MainGlobals.set_font_size(_feedback, 48)
	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	# two lines on a rotation level ("Put it back together" / "Tap a piece to turn it")
	var cap_h: float = (48.0 if mob else 36.0) * (2.0 if rotation_on else 1.0)
	# below the level number, which main.gd moves to y 92-132
	var cap_top: float = 136.0
	_place(_caption, 0.0, cap_top, sw, cap_h)
	# The board: everything between the caption and the app's bottom button bar.
	var top: float = cap_top + cap_h + 10.0
	var bar_h: float = 70.0 if mob else 44.0
	var bottom: float = sh - maxf(20.0, bar_h - float(MainGlobals.footer_height) + 12.0)
	var avail: Vector2 = Vector2(sw - 32.0, maxf(60.0, bottom - top))
	_cell_w = floorf(minf(avail.x / float(cols), avail.y / (float(rows) * _piece_aspect)))
	_cell_h = floorf(_cell_w * _piece_aspect)
	var bw: float = _cell_w * cols
	var bh: float = _cell_h * rows
	# Right under the caption, not centred in what is left: a gap above the board read as a mistake.
	_board_rect = Rect2((sw - bw) * 0.5, top, bw, bh)
	_place(_board_bg, _board_rect.position.x - 6.0, _board_rect.position.y - 6.0, bw + 12.0, bh + 12.0)
	_place(_count, _board_rect.position.x, _board_rect.position.y + bh * 0.5 - 50.0, bw, 100.0)
	_place(_feedback, 0.0, _board_rect.position.y + bh * 0.5 - 60.0, sw, 120.0)
	for p: Dictionary in pieces:
		_size_piece(p)
		_put(p, int(p["cell"]), false)

# --- level flow ----------------------------------------------------------------------------------

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if from_scratch:
		current_level_id = MosaicG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = MosaicLevelConfig.next_id(current_level_id)
	game.need_to_increase_level = false
	_clear_board()
	moves = 0
	turns_made = 0
	round_times_ms.clear()
	round_solved.clear()
	first_try_pct = -1
	failed_rounds = 0
	solved_rounds = 0
	round_index = 0
	_awaiting_round_card = false
	phase = Phase.IDLE
	_feedback.hide()
	_count.hide()
	_caption.text = ""
	_bar_fill.visible = false
	_load_level(current_level_id)
	_build_board()
	_layout()
	call_deferred("_layout")
	if game.tutorial_mode:
		game.level_is_ready = true
		started_playing.emit()
		return
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Level %d" % current_level_id, briefing_text())

func briefing_text() -> String:
	var lines: Array = []
	lines.append("Rounds: %d" % max_rounds)
	lines.append("Pieces: %d x %d" % [cols, rows])
	lines.append("Picture: " + picture_kind.capitalize())
	lines.append("Each round: %d s" % int(round_ms / 1000.0))
	lines.append("Rotated pieces: " + ("Yes" if rotation_on else "No"))
	lines.append("To pass: %d%% of rounds" % pass_pct)
	lines.append("")
	var how: String = "Remember the picture. It will be cut up and shuffled, and you put it back together by dragging one piece onto another to swap them."
	if rotation_on:
		how += " Some pieces will be rotated too, and a tap rotates a piece a quarter turn."
	lines.append(how + " The same picture comes back for every round, so you can get faster at it. To pass, rebuild it in the last round too.")
	return "\n".join(lines)

func _on_game_popup_closed() -> void:
	if _awaiting_round_card:
		_awaiting_round_card = false
		_next_round()
		return
	if not game.level_is_done and not game.level_is_ready:
		_layout()
		game.level_is_ready = true
		started_playing.emit()

func stop_level() -> void:
	_awaiting_round_card = false
	_clear_board()
	phase = Phase.IDLE
	_feedback.hide()
	_count.hide()
	_bar_fill.visible = false

# The picture kind for this play of the level: one of the level's list, at random -- so a dino level
# is not limited to the finite set of cards. An EMPTY list means every kind (MosaicPicture.KINDS), and
# on a level with rotation every kind that can be rotated (ROTATABLE). On a rotation level a dino card
# is left out whenever the list has anything else (see rotation_on below).
func pick_picture(def: Dictionary) -> String:
	var raw = def.get("picture", [])
	var kinds: Array = (raw as Array).duplicate() if raw is Array else [str(raw)]
	var rotating: bool = bool(def.get("rotation", false))
	# An empty list means every kind -- on a rotation level, every kind that can be rotated.
	if kinds.is_empty():
		kinds = (MosaicPicture.ROTATABLE if rotating else MosaicPicture.KINDS).duplicate()
	if rotating:
		var turnable: Array = kinds.filter(func(k) -> bool: return str(k) != "dino")
		if not turnable.is_empty():
			kinds = turnable
	return str(kinds[_rng.randi_range(0, kinds.size() - 1)])

func _load_level(id: int) -> void:
	var def: Dictionary = MosaicLevelConfig.get_level(id)
	cols = maxi(2, int(def.get("cols", 3)))
	rows = maxi(2, int(def.get("rows", 3)))
	picture_kind = pick_picture(def)
	study_ms = float(def.get("study_sec", 8)) * 1000.0
	restudy_ms = float(def.get("restudy_sec", float(def.get("study_sec", 8)) * 0.5)) * 1000.0
	pass_pct = clampi(int(def.get("pass_pct", 60)), 0, 100)
	round_ms = float(def.get("round_sec", 45)) * 1000.0
	max_rounds = maxi(1, int(def.get("rounds", 4)))
	# Never on a dino card: it keeps its whole picture, so its pieces are not square and a quarter turn
	# would not fit back in the cell. (A quilt CAN be rotated -- the level table just does not ask for
	# it, since turned swatches with nothing to lead you back are a lot; a 2 x 2 quilt might not be.)
	rotation_on = bool(def.get("rotation", false)) and picture_kind != "dino"
	game.level_label_changed("Level " + str(def.get("name", id)))
	game.set_task_signature({"grid": "%dx%d" % [cols, rows], "picture": picture_kind, "rotation": rotation_on,
		"study_sec": int(study_ms / 1000.0), "restudy_sec": int(restudy_ms / 1000.0),
		"round_sec": int(round_ms / 1000.0), "rounds": max_rounds})

# --- the board -------------------------------------------------------------------------------------

func _clear_board() -> void:
	for p: Dictionary in pieces:
		if is_instance_valid(p["node"]):
			(p["node"] as Node).queue_free()
	pieces.clear()
	_picture = null

func _build_board() -> void:
	var img: Image = MosaicPicture.make(picture_kind, cols, rows, rotation_on, _rng)
	_picture = ImageTexture.create_from_image(img)
	_piece_aspect = float(img.get_height() * cols) / float(img.get_width() * rows)
	for i in cols * rows:
		var tr_node: TextureRect = TextureRect.new()
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = _picture
		at.region = Rect2(MosaicPicture.piece_rect(img, cols, rows, i % cols, int(float(i) / cols)))
		tr_node.texture = at
		tr_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_node.stretch_mode = TextureRect.STRETCH_SCALE
		tr_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var frame: Control = Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.visible = false
		# The outline every piece wears from the shuffle until the picture is whole again.
		frame.draw.connect(func() -> void:
			var r: Rect2 = Rect2(Vector2.ZERO, frame.size)
			frame.draw_rect(r, Color(0.04, 0.04, 0.06, 0.95), false, 3.0)
			frame.draw_rect(r.grow(-2.5), Color(1, 1, 1, 0.55), false, 1.0))
		tr_node.add_child(frame)
		_board.add_child(tr_node)
		var p: Dictionary = {"node": tr_node, "frame": frame, "home": i, "cell": i, "turns": 0}
		pieces.append(p)
		_size_piece(p)
		_put(p, i, false)

func _size_piece(p: Dictionary) -> void:
	var n: TextureRect = p["node"]
	n.size = Vector2(_cell_w, _cell_h)
	n.pivot_offset = n.size * 0.5
	n.rotation = float(p["turns"]) * PI * 0.5

func cell_origin(cell: int) -> Vector2:
	return _board_rect.position + Vector2(float(cell % cols) * _cell_w, float(int(float(cell) / cols)) * _cell_h)

func cell_at(pt: Vector2) -> int:
	if not _board_rect.has_point(pt):
		return -1
	var local: Vector2 = pt - _board_rect.position
	var c: int = clampi(int(local.x / _cell_w), 0, cols - 1)
	var r: int = clampi(int(local.y / _cell_h), 0, rows - 1)
	return r * cols + c

func _piece_in(cell: int) -> int:
	for i in pieces.size():
		if int(pieces[i]["cell"]) == cell:
			return i
	return -1

func _put(p: Dictionary, cell: int, animate: bool) -> void:
	p["cell"] = cell
	var n: TextureRect = p["node"]
	var dest: Vector2 = cell_origin(cell)
	if animate:
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "position", dest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		n.position = dest

func _set_frames(on: bool) -> void:
	for p: Dictionary in pieces:
		(p["frame"] as Control).visible = on
		(p["frame"] as Control).queue_redraw()

func is_solved() -> bool:
	for p: Dictionary in pieces:
		if int(p["cell"]) != int(p["home"]) or int(p["turns"]) % 4 != 0:
			return false
	return true

func pieces_in_place() -> int:
	var n: int = 0
	for p: Dictionary in pieces:
		if int(p["cell"]) == int(p["home"]) and int(p["turns"]) % 4 == 0:
			n += 1
	return n

# A new arrangement: a random permutation with few pieces left where they belong (at most one in
# eight), and on a level with rotation, a random turn for each piece with at least half of them
# turned.
func shuffled_layout() -> Array:
	var n: int = pieces.size()
	var cells: Array = range(n)
	var allowed_home: int = maxi(0, int(n / 8.0))
	for _attempt in 60:
		cells.shuffle()
		var at_home: int = 0
		for i in n:
			if int(cells[i]) == i:
				at_home += 1
		if at_home <= allowed_home:
			break
	var turned: Array = []
	for i in n:
		turned.append(0)
	if rotation_on:
		var count_turned: int = 0
		while count_turned < int(ceilf(n * 0.5)):
			count_turned = 0
			for i in n:
				turned[i] = _rng.randi_range(0, 3)
				if int(turned[i]) != 0:
					count_turned += 1
	return [cells, turned]

# --- the flip -------------------------------------------------------------------------------------

# Every piece flips over where it stands, staggered; while all are face down they take their new
# places (and turns); then every piece flips up again, staggered. Nothing slides, so there is no
# path to follow back.
func _flip_to(cells: Array, turned: Array, on_done: Callable) -> void:
	var latest: float = 0.0
	var delays: Array = []
	for i in pieces.size():
		delays.append(_rng.randf_range(0.0, STAGGER_SEC))
	for i in pieces.size():
		var n: TextureRect = pieces[i]["node"]
		var tw: Tween = n.create_tween()
		tw.tween_interval(float(delays[i]))
		tw.tween_property(n, "scale:x", 0.0, FLIP_SEC).set_trans(Tween.TRANS_SINE)
		latest = maxf(latest, float(delays[i]) + FLIP_SEC)
	var rest: SceneTreeTimer = get_tree().create_timer(latest + 0.12)
	rest.timeout.connect(_flip_back.bind(cells, turned, on_done))

func _flip_back(cells: Array, turned: Array, on_done: Callable) -> void:
	if pieces.is_empty():
		return
	var latest: float = 0.0
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		p["turns"] = int(turned[i])
		_size_piece(p)
		_put(p, int(cells[i]), false)
		var n: TextureRect = p["node"]
		var d: float = _rng.randf_range(0.0, STAGGER_SEC)
		var tw: Tween = n.create_tween()
		tw.tween_interval(d)
		tw.tween_property(n, "scale:x", 1.0, FLIP_SEC).set_trans(Tween.TRANS_SINE)
		latest = maxf(latest, d + FLIP_SEC)
	var settle: SceneTreeTimer = get_tree().create_timer(latest + 0.05)
	settle.timeout.connect(func() -> void:
		if not pieces.is_empty():
			on_done.call())

# --- phases ---------------------------------------------------------------------------------------

func _can_play() -> bool:
	return game.playing and not game.paused() and not game.level_is_done and game.level_is_ready

func _enter(ph: int) -> void:
	phase = ph
	_phase_start = game.game_time

func _start_study() -> void:
	round_index += 1
	_set_frames(false)
	_feedback.hide()
	_study_caption = "Remember the picture" if round_index == 1 else "Round %d of %d" % [round_index, max_rounds]
	# The first look is a study; after a rebuilt round the picture is known, so the look before the
	# next round is the shorter reminder. After a round that ran out, the full study again.
	_after_rebuilt = round_index > 1 and not round_solved.is_empty() and bool(round_solved.back())
	_caption.text = _study_caption
	_enter(Phase.STUDY)
	game.tutorial_notify("study")

func _start_shuffle() -> void:
	_count.hide()
	_caption.text = ""
	_bar_fill.visible = false
	_enter(Phase.SHUFFLE)
	var lay: Array = shuffled_layout()
	_flip_to(lay[0], lay[1], _start_play)

func _start_play() -> void:
	if phase != Phase.SHUFFLE:
		return
	_set_frames(true)
	_caption.text = ("Put it back together" + ("\nTap a piece to rotate it" if rotation_on else "")) \
		if round_index == 1 else "Round %d of %d" % [round_index, max_rounds]
	_enter(Phase.PLAY)
	game.tutorial_notify("shuffled")

func _round_ended(was_solved: bool) -> void:
	var played: float = game.game_time - _phase_start
	round_times_ms.append(int(played))
	round_solved.append(was_solved)
	if first_try_pct < 0:
		first_try_pct = int(round(100.0 * float(pieces_in_place()) / float(maxi(1, pieces.size()))))
	_cancel_drag()
	if was_solved:
		solved_rounds += 1
		_set_frames(false)
		game.play_sound("solved")
		# Points: what was left of the round, plus 20 for rebuilding it at all.
		var left_s: int = int(maxf(0.0, round_ms - played) / 1000.0)
		game.add_score_and_time(left_s + 20, 0, true)
		game.add_correct_or_mistake(1, 0)
		_feedback.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
		_feedback.text = "Whole again!"
		_feedback.show()
		_enter(Phase.SOLVED)
		game.tutorial_notify("solved")
	else:
		failed_rounds += 1
		if not game.tutorial_mode:
			MosaicG.add_failed_round(current_level_id)
		# A failed round still counts as having played: the session is saved.
		game.add_score_and_time(0, 0, true)
		game.add_correct_or_mistake(0, 1)
		_feedback.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
		_feedback.text = "Time's up"
		_feedback.show()
		_enter(Phase.TIMEUP)
		game.tutorial_notify("time_up")

func _process(_dt: float) -> void:
	if not _can_play():
		return
	var now: float = game.game_time
	var since: float = now - _phase_start
	match phase:
		Phase.IDLE:
			if not pieces.is_empty():
				_start_study()
		Phase.STUDY:
			var dur: float = study_now_ms()
			var left: float = maxf(0.0, dur - since)
			# The countdown is in the caption, not on the picture: it would cover part of what is
			# being remembered.
			_caption.text = "%s  \u00b7  %d" % [_study_caption, int(ceilf(left / 1000.0))]
			_show_bar(left / dur, Color(0.976, 0.792, 0.353))
			if since >= dur:
				_start_shuffle()
		Phase.PLAY:
			var left_p: float = maxf(0.0, round_ms - since)
			var frac: float = left_p / round_ms
			_show_bar(frac, Color(0.9, 0.3, 0.25).lerp(Color(0.3, 0.8, 0.4), frac))
			if since >= round_ms and not game.tutorial_mode:
				_round_ended(false)
		Phase.SOLVED, Phase.TIMEUP:
			_bar_fill.visible = false
			if since >= FEEDBACK_SEC * 1000.0:
				_feedback.hide()
				if round_index >= max_rounds:
					_level_done(passed())
				elif game.tutorial_mode:
					_next_round()
				else:
					# A short card between rounds: how this one went and how many are left. The next
					# round starts when it is closed.
					_awaiting_round_card = true
					_enter(Phase.ROUND_CARD)
					game.show_game_popup(self, "Round %d of %d" % [round_index, max_rounds], round_card_text())

# The same picture again, rebuilt or not: everything flips back to where it belongs, and the
# countdown starts the next round.
func _next_round() -> void:
	if pieces.is_empty():
		return
	_enter(Phase.REVEAL)
	_set_frames(false)
	var home_cells: Array = []
	var upright: Array = []
	for p: Dictionary in pieces:
		home_cells.append(int(p["home"]))
		upright.append(0)
	_flip_to(home_cells, upright, _start_study)

func round_card_text() -> String:
	var k: int = round_solved.size() - 1
	var ok: bool = bool(round_solved[k])
	var lines: Array = []
	lines.append("Result: " + ("Rebuilt" if ok else "Time ran out"))
	if ok:
		lines.append("Time: " + _fmt_secs(float(round_times_ms[k]) / 1000.0))
	lines.append("Rounds left: %d" % (max_rounds - round_index))
	return "\n".join(lines)

# This round's countdown, read live from the level's values.
func study_now_ms() -> float:
	return restudy_ms if _after_rebuilt else study_ms

# Passed: the LAST round rebuilt -- by the end the picture is learned -- and at least pass_pct of
# all the rounds.
func passed() -> bool:
	if round_solved.is_empty() or not bool(round_solved.back()):
		return false
	return solved_rounds * 100 >= pass_pct * max_rounds

func _show_bar(frac: float, col: Color) -> void:
	_bar_fill.visible = true
	_bar_fill.size = Vector2(_bar_full_w * clampf(frac, 0.0, 1.0), _bar_h)
	_bar_fill.color = col

# --- input: drag to swap, tap to turn ---------------------------------------------------------

func _input(event: InputEvent) -> void:
	if phase != Phase.PLAY or not _can_play():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			var cell: int = cell_at(mb.position)
			if cell < 0:
				return
			_press_piece = _piece_in(cell)
			_press_at = mb.position
			_dragging = false
			if _press_piece >= 0:
				_grab_offset = (pieces[_press_piece]["node"] as Control).position - mb.position
				get_viewport().set_input_as_handled()
		elif _press_piece >= 0:
			get_viewport().set_input_as_handled()
			if _dragging:
				_drop()
			else:
				turn_piece(_press_piece)
			_press_piece = -1
			_dragging = false
	elif event is InputEventMouseMotion and _press_piece >= 0:
		var mm: InputEventMouseMotion = event
		if not _dragging and mm.position.distance_to(_press_at) > TAP_SLOP:
			_dragging = true
			var n: TextureRect = pieces[_press_piece]["node"]
			n.z_index = 20
			n.scale = Vector2(1.08, 1.08)
			game.tutorial_notify("drag_started")
		if _dragging:
			(pieces[_press_piece]["node"] as Control).position = mm.position + _grab_offset
			get_viewport().set_input_as_handled()

func _drop() -> void:
	var i: int = _press_piece
	var n: TextureRect = pieces[i]["node"]
	n.z_index = 0
	n.scale = Vector2.ONE
	# Where the piece's middle is, not the finger: on a phone the finger covers the piece.
	var target: int = cell_at(n.position + n.size * 0.5)
	var from: int = int(pieces[i]["cell"])
	if target < 0 or target == from:
		_put(pieces[i], from, true)
		return
	swap_cells(from, target, true)

func _cancel_drag() -> void:
	if _press_piece >= 0 and _dragging:
		var n: TextureRect = pieces[_press_piece]["node"]
		n.z_index = 0
		n.scale = Vector2.ONE
		_put(pieces[_press_piece], int(pieces[_press_piece]["cell"]), false)
	_press_piece = -1
	_dragging = false

# The piece in `from` goes to `to`, and what was in `to` goes to `from`.
func swap_cells(from: int, to: int, animate: bool) -> void:
	var a: int = _piece_in(from)
	var b: int = _piece_in(to)
	if a < 0 or b < 0 or a == b:
		return
	_put(pieces[a], to, animate)
	_put(pieces[b], from, animate)
	moves += 1
	game.play_sound("swap")
	game.tutorial_notify("swapped")
	if phase == Phase.PLAY and is_solved():
		_round_ended(true)

func turn_piece(i: int) -> void:
	if not rotation_on or i < 0 or i >= pieces.size():
		return
	var p: Dictionary = pieces[i]
	p["turns"] = (int(p["turns"]) + 1) % 4
	turns_made += 1
	var n: TextureRect = p["node"]
	var tw: Tween = n.create_tween()
	var dest: float = n.rotation + PI * 0.5
	tw.tween_property(n, "rotation", dest, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.rotation = float(int(p["turns"])) * PI * 0.5)
	game.tutorial_notify("turned")
	if phase == Phase.PLAY and is_solved():
		_round_ended(true)

# --- the end of a level ---------------------------------------------------------------------------

func _level_done(didwin: bool) -> void:
	if game.level_is_done:
		return
	_enter(Phase.DONE)
	if game.tutorial_mode:
		return
	game.level_is_done = true
	_bar_fill.visible = false
	_count.hide()
	_feedback.hide()
	game.sig_level_is_done.emit(didwin)
	MainGlobals.global_level_is_done(didwin)
	game.need_to_increase_level = didwin and current_level_id < MosaicLevelConfig.max_level()
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	game.show_level_done_popup(self, "", "", current_level_id, result_text(didwin), didwin)

const ROUNDS_AS_ROWS: int = 6
const ROUNDS_PER_ROW: int = 5

func result_text(didwin: bool) -> String:
	var lines: Array = ["", ""]
	# One row per round while they fit on the card (it does not scroll); past ROUNDS_AS_ROWS, five
	# rounds to a row ("Rounds 6-10 (sec): 22, 18, -, 15, 12"), a dash for a round that ran out --
	# short enough to stay one table row each, however many rounds a level has.
	if round_times_ms.size() <= ROUNDS_AS_ROWS:
		for k in round_times_ms.size():
			lines.append("Round %d: %s" % [k + 1, _fmt_secs(float(round_times_ms[k]) / 1000.0) if bool(round_solved[k]) else "time ran out"])
	else:
		var n: int = round_times_ms.size()
		for start in range(0, n, ROUNDS_PER_ROW):
			var parts: Array = []
			for k in range(start, mini(start + ROUNDS_PER_ROW, n)):
				parts.append(str(int(round(float(round_times_ms[k]) / 1000.0))) if bool(round_solved[k]) else "-")
			var span: String = str(start + 1) if parts.size() == 1 else "%d-%d" % [start + 1, start + parts.size()]
			lines.append("Rounds %s (sec): %s" % [span, ", ".join(parts)])
	var faster: int = faster_pct()
	if faster != 0:
		lines.append("Last vs first rebuild: %s" % ("%d%% faster" % faster if faster > 0 else "%d%% slower" % -faster))
	lines.append("Rebuilt: %d of %d" % [solved_rounds, max_rounds])
	lines.append("Total level moves: %d" % moves)
	if rotation_on:
		lines.append("Rotations: %d" % turns_made)
	lines.append("")
	if not didwin:
		lines.append("To pass, rebuild the picture in the last round and in at least %d percent of the rounds. Play this level again." % pass_pct)
	elif current_level_id >= MosaicLevelConfig.max_level():
		lines.append("Level passed. This is the last level, so it comes round again.")
	else:
		lines.append("Level passed. On to level %d." % MosaicLevelConfig.next_id(current_level_id))
	return "\n".join(lines)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

# The LAST round's time, and only when that round was rebuilt (0 otherwise): what the Speed tab and
# its chart show -- how fast the picture went back together at the end of the level.
func solve_ms() -> int:
	if round_solved.is_empty() or not bool(round_solved.back()):
		return 0
	return int(round_times_ms.back())

# The last round that was rebuilt, whichever it was (0 if none): what "faster" is measured to.
func last_solve_ms() -> int:
	for k in range(round_times_ms.size() - 1, -1, -1):
		if bool(round_solved[k]):
			return int(round_times_ms[k])
	return 0

# The first round that was rebuilt, 0 if none.
func first_solve_ms() -> int:
	for k in round_times_ms.size():
		if bool(round_solved[k]):
			return int(round_times_ms[k])
	return 0

# How much faster the last rebuild was than the first, in percent (negative: slower). 0 when fewer
# than two rounds were rebuilt -- there is nothing to compare.
func faster_pct() -> int:
	if solved_rounds < 2:
		return 0
	var a: float = float(first_solve_ms())
	return int(round(100.0 * (a - float(last_solve_ms())) / maxf(a, 1.0)))

func _fmt_secs(s: float) -> String:
	var t: int = int(round(s))
	if t >= 60:
		return "%d:%02d min" % [floori(t / 60.0), t % 60]
	return "%d s" % t

func tick() -> void:
	pass
