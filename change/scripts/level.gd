extends CanvasLayer

# Change gameplay: each board shows a target amount to pay and a pile of overlapping coins.
# The player drags coins from the pile into the tray and presses Pay; the sum in the tray is
# checked against the target (with an epsilon, to avoid float rounding). A board always has at
# least one exact solution — the target is built as the sum of a subset of the coins present.
#
# Modeled on the Couples/Dino games: same top timeout bar, per-level time budget that advances
# the level, phase machine (IDLE -> SHOW -> FEEDBACK -> GAP), scoring and level flow. The card
# grid is replaced by draggable drawn coins (see coin.gd).

var game: GenericGameUtil

var current_level_id: int = 1

# --- level params (from ChangeLevelConfig) ---
var coin_size_key: String = "med"
var board_time_ms: float = 30000.0
var gap_ms: float = 1000.0
var duration_sec: int = 60
var num_coins: int = 6
var overlap_key: String = "med"
var show_level_instruction: bool = false

# --- coin denominations (values in money; parallel relative sizes: a dime < a quarter, etc.) ---
const DENOMS: Array = [0.01, 0.05, 0.10, 0.25, 0.50, 1.00]
const DENOM_REL: Array = [0.84, 0.96, 0.80, 1.00, 1.16, 1.06]
const DENOM_WEIGHT: Array = [2, 5, 5, 5, 3, 2]  # picking bias (fewer pennies / dollars)
const PAY_EPSILON: float = 0.005               # < smallest coin, so no false positives

# --- board state ---
var _coins: Array = []            # [{node, value:float, radius:float}]
var _target_amount: float = 0.0
var _answered: bool = false

# --- drag state ---
var _drag_coin = null             # the {node,...} entry currently being dragged (or null)
var _drag_offset: Vector2 = Vector2.ZERO
var _top_z: int = 10

# --- regions (from _layout) ---
var _pile_rect: Rect2 = Rect2(0, 0, 200, 200)
var _basket_rect: Rect2 = Rect2(0, 0, 200, 200)
var _clamp_rect: Rect2 = Rect2(0, 0, 200, 400)
var _coin_base_d: float = 100.0

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
var _target_label: Label = null
var _instruction: Label = null
var _feedback: Label = null
var _bar_track: ColorRect = null
var _bar_fill: ColorRect = null
var _basket_panel: Panel = null
var _basket_label: Label = null
var _pay_btn: Button = null
var _catcher: Control = null
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0
var _feedback_cy: float = 0.0
var _fb_font_big: int = 66    # short messages ("Correct!", "Too slow")
var _fb_font_small: int = 40  # the longer two-line "You paid … / needed …" message

const COIN_SCRIPT: GDScript = preload("res://change/scripts/coin.gd")
# How long the Correct!/Too slow banner stays up. A var, not a const, only so a tutorial can
# shorten it; _load_level puts it back, so a tutorial can never leave real play running fast.
const FEEDBACK_DEFAULT_MS: float = 1200.0
var feedback_ms: float = FEEDBACK_DEFAULT_MS

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = ChangeG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	_build_ui()
	set_process(true)

# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	_bar_track = ColorRect.new()
	_bar_track.color = Color(0, 0, 0, 0.38)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.3, 0.8, 0.4, 1.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	add_child(_bar_fill)

	_target_label = _make_label(56, Color(1, 0.94, 0.6, 1.0))
	_target_label.text = ""
	add_child(_target_label)

	if show_level_instruction:
		_instruction = _make_label(28, Color(0.92, 0.94, 0.9, 1.0))
		_instruction.text = "Drag coins into the tray to pay the exact amount, then press Pay"
		add_child(_instruction)

	# tray/basket (drawn behind the coins; no sum is ever shown here)
	_basket_panel = Panel.new()
	_basket_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.22)
	st.set_border_width_all(3)
	st.border_color = Color(1, 0.9, 0.55, 0.7)
	st.set_corner_radius_all(18)
	_basket_panel.add_theme_stylebox_override("panel", st)
	add_child(_basket_panel)
	_basket_label = _make_label(26, Color(1, 1, 1, 0.35))
	_basket_label.text = "TRAY"
	_basket_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_basket_label)

	# drag catcher (invisible, full-screen). Coins are Node2D and don't take GUI input, so a
	# single STOP control under them handles all drags. Added BEFORE the Pay button so the
	# button wins clicks in its own rect.
	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_gui_input)
	add_child(_catcher)

	_feedback = _make_label(72, Color(0.2, 0.8, 0.3, 1.0))
	_feedback.text = ""
	_feedback.z_index = 120
	_feedback.autowrap_mode = TextServer.AUTOWRAP_OFF  # hug the (short) text so the panel fits it
	_feedback.custom_minimum_size = Vector2.ZERO
	var fbg: StyleBoxFlat = StyleBoxFlat.new()
	fbg.bg_color = Color(0, 0, 0, 0.5)  # semi-transparent backdrop for readability over the coins
	fbg.set_corner_radius_all(18)
	fbg.set_content_margin_all(20)
	_feedback.add_theme_stylebox_override("normal", fbg)
	_feedback.hide()
	add_child(_feedback)

	_pay_btn = Button.new()
	_pay_btn.text = "PAY"
	_pay_btn.z_index = 100
	_pay_btn.focus_mode = Control.FOCUS_NONE
	_pay_btn.add_theme_font_size_override("font_size", 40)
	_style_pay_button()
	_pay_btn.pressed.connect(_on_pay_pressed)
	add_child(_pay_btn)

func _style_pay_button() -> void:
	var mk = func(bg: Color) -> StyleBoxFlat:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = bg
		s.set_corner_radius_all(14)
		s.set_content_margin_all(8)
		return s
	_pay_btn.add_theme_stylebox_override("normal", mk.call(Color(0.16, 0.55, 0.28, 1.0)))
	_pay_btn.add_theme_stylebox_override("hover", mk.call(Color(0.20, 0.63, 0.33, 1.0)))
	_pay_btn.add_theme_stylebox_override("pressed", mk.call(Color(0.12, 0.44, 0.22, 1.0)))
	_pay_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

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

	_target_label.add_theme_font_size_override("font_size", 66 if mob else 48)
	if show_level_instruction:
		_instruction.add_theme_font_size_override("font_size", 32 if mob else 24)
	_fb_font_big = 96 if mob else 66
	_fb_font_small = 54 if mob else 38
	_feedback.add_theme_font_size_override("font_size", _fb_font_big)
	_pay_btn.add_theme_font_size_override("font_size", 48 if mob else 34)

	# full-screen drag catcher
	_place(_catcher, 0.0, 0.0, sw, sh)

	# timeout bar just under the header (level label is moved down below it in main.gd)
	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	_bar_fill.size = Vector2(_bar_full_w, _bar_h)

	# target amount (prominent) + instruction, below the moved level number
	var target_top: float = hh + (92.0 if mob else 80.0)
	var target_h: float = 66.0 if mob else 50.0
	_place(_target_label, 0.0, target_top, sw, target_h)
	var instr_top: float = target_top + target_h + (2.0 if mob else 2.0)
	var instr_h: float = 62.0 if mob else 46.0
	if show_level_instruction:
		_place(_instruction, 12.0, instr_top, sw - 24.0, instr_h)

	# vertical budget: reserve the app bottom button bar (taller on mobile than the footer),
	# then the Pay button, then split the rest into pile (top) and tray (bottom).
	var side: float = 16.0
	var bar_h_bottom: float = 70.0 if mob else 44.0
	var bottom_reserve: float = maxf(20.0, bar_h_bottom - float(MainGlobals.footer_height) + 10.0)
	var bottom_limit: float = sh - bottom_reserve

	var pay_h: float = 84.0 if mob else 52.0
	var pay_w: float = minf(sw - side * 2.0, 420.0)
	var pay_y: float = bottom_limit - pay_h
	_place(_pay_btn, (sw - pay_w) * 0.5, pay_y, pay_w, pay_h)

	var play_top: float = instr_top + instr_h + (10.0 if mob else 8.0)
	var region_bottom: float = pay_y - (14.0 if mob else 12.0)
	var region_h: float = maxf(120.0, region_bottom - play_top)
	var basket_h: float = clampf(region_h * 0.42, 130.0, 380.0)
	var basket_top: float = region_bottom - basket_h
	_basket_rect = Rect2(side, basket_top, sw - side * 2.0, basket_h)
	_place(_basket_panel, _basket_rect.position.x, _basket_rect.position.y, _basket_rect.size.x, _basket_rect.size.y)
	_place(_basket_label, _basket_rect.position.x, _basket_rect.position.y + 6.0, _basket_rect.size.x, 34.0)

	var pile_bottom: float = basket_top - (16.0 if mob else 12.0)
	_pile_rect = Rect2(side, play_top, sw - side * 2.0, maxf(80.0, pile_bottom - play_top))

	# coins may be dragged anywhere between the pile top and the tray bottom
	_clamp_rect = Rect2(side, play_top, sw - side * 2.0, (basket_top + basket_h) - play_top)

	# base coin diameter as a fraction of width (platform-independent), scaled per size key
	var base_frac: float = 0.155
	match coin_size_key:
		"big":
			base_frac = 0.20
		"med":
			base_frac = 0.155
		"small":
			base_frac = 0.122
	_coin_base_d = sw * base_frac
	if not mob:
		_coin_base_d *= 0.70  # coins run 30% smaller off mobile (wider/shorter screens)

	# feedback is centered in the play area; it's sized to its text in _size_feedback_to_text
	_feedback_cy = play_top + _pile_rect.size.y * 0.5
	if _feedback.visible:
		_size_feedback_to_text()

# --- Level flow -------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if _from_scratch:
		current_level_id = ChangeG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, ChangeLevelConfig.max_level())
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
	call_deferred("_layout")  # re-apply once the menu->level transition settles (see couples)
	_feedback.hide()
	_target_label.text = ""

	if game.tutorial_mode:
		# The tutorial teaches all of this by doing it; showing the popup too would make the
		# player dismiss a wall of text before being taught it.
		_tutorial_setup()
		_on_game_popup_closed()
		return

	# The shared briefing card (ResultCard) wraps prose itself and sets "Label: value" lines as a
	# table, so the sentence is written as a sentence.
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Level %d" % current_level_id,
		# parentheses required — `%` binds tighter than `+`
		("Pay the exact amount by dragging coins into the tray, then press Pay.\n\n" +
		"Coins: %d\n" +
		"Board time: %s\n" +
		"Total: %s") % [
			num_coins, _fmt_secs(board_time_ms / 1000.0), _fmt_secs(float(duration_sec))
		])

# The boards come from tutorial.gd so the coins on screen and the amounts the coach names can
# never drift apart. The per-board clock is stretched because the bar is being explained.
func _tutorial_setup() -> void:
	var tut: Script = load("res://change/scripts/tutorial.gd")
	_forced_boards = tut.tutorial_boards()
	board_time_ms = 180000.0
	# The coach announces the next pile and then the player waits staring at nothing: the feedback
	# banner and the inter-board gap both run first. 1200 + 1000 -> 500 + 200.
	gap_ms = 200.0
	feedback_ms = 500.0

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
	var def: Dictionary = ChangeLevelConfig.get_level(id)
	coin_size_key = str(def.get("coin_size", "med"))
	board_time_ms = float(def.get("board_time_sec", 30.0)) * 1000.0
	feedback_ms = FEEDBACK_DEFAULT_MS
	gap_ms = float(def.get("gap_sec", 1.0)) * 1000.0
	duration_sec = int(def.get("duration_sec", 60))
	num_coins = maxi(2, int(def.get("num_coins", 6)))
	overlap_key = str(def.get("overlap", "med"))

	game.set_reset_time_left(duration_sec)
	game.set_time_left(0, 0, duration_sec)
	game.level_label_changed("Level " + str(def.get("name", id)))

# --- Board construction -----------------------------------------------------

func _show_board() -> void:
	_clear_board()
	_build_board()
	_answered = false
	_feedback.hide()
	phase = Phase.SHOW
	_show_start_ms = game.game_time
	_phase_start_ms = game.game_time
	game.tutorial_notify("board_shown")   # no-op outside tutorial mode

# Tutorial support: a queue of fixed boards, consumed one per round. A tutorial has to be able to
# say "you need 35 cents" and know that is actually solvable with the coins on screen, which a
# random board cannot promise. Empty in normal play, so _build_board runs untouched.
# Each entry: {"values": Array[float], "target": float, "overlap": String}
var _forced_boards: Array = []
# The board currently on screen, so a tutorial can put it back and let the player try again.
var _forced_current: Dictionary = {}

func _build_forced_board(spec: Dictionary) -> void:
	overlap_key = String(spec.get("overlap", overlap_key))
	var values: Array = spec.get("values", [])
	num_coins = values.size()
	for v in values:
		var val: float = float(v)
		var di: int = DENOMS.find(val)
		if di < 0:
			di = 0
		var rad: float = _coin_base_d * float(DENOM_REL[di]) * 0.5
		var coin = COIN_SCRIPT.new()
		add_child(coin)
		coin.setup(val, rad)
		_coins.append({"node": coin, "value": val, "radius": rad})
	_target_amount = float(spec.get("target", 0.0))
	_forced_current = spec
	_place_coins()
	_update_target_label()

# Any coin left in the tray by an earlier lesson counts toward the next payment, which made the
# coach's own instruction impossible to obey: after "drag a coin into the tray" put a 5c in there,
# "put in exactly 35 cents" came to 40c and was rejected. The player pays exactly what they were
# told and is marked wrong.
func tutorial_clear_tray() -> void:
	for entry in _coins:
		if not _in_basket(entry):
			continue
		var node = entry["node"]
		if not is_instance_valid(node):
			continue
		var rad: float = float(entry["radius"])
		node.position = Vector2(
			game.rng.randf_range(_pile_rect.position.x + rad, _pile_rect.end.x - rad),
			game.rng.randf_range(_pile_rect.position.y + rad, _pile_rect.end.y - rad))
		node.set_in_tray(false)

func _build_board() -> void:
	if not _forced_boards.is_empty():
		_build_forced_board(_forced_boards.pop_front())
		return
	# pick denominations for every coin
	var vidx: Array = []
	for i in num_coins:
		vidx.append(_weighted_denom_index())

	# choose a solution subset so an exact answer always exists (a proper, non-trivial subset
	# when possible). The target is the sum of that subset's values.
	var order: Array = []
	for i in num_coins:
		order.append(i)
	order.shuffle()
	var k: int
	if num_coins >= 3:
		k = clampi(int(round(num_coins * game.rng.randf_range(0.34, 0.6))), 2, num_coins - 1)
	else:
		k = clampi(int(round(num_coins * 0.6)), 1, num_coins)
	var target_cents: int = 0
	for i in k:
		target_cents += int(round(DENOMS[vidx[order[i]]] * 100.0))
	_target_amount = float(target_cents) / 100.0

	# create the coin nodes
	for i in num_coins:
		var di: int = vidx[i]
		var v: float = DENOMS[di]
		var rad: float = _coin_base_d * float(DENOM_REL[di]) * 0.5
		var coin = COIN_SCRIPT.new()
		add_child(coin)
		coin.setup(v, rad)
		_coins.append({"node": coin, "value": v, "radius": rad})
	_place_coins()
	_update_target_label()

func _weighted_denom_index() -> int:
	var total: int = 0
	for w in DENOM_WEIGHT:
		total += int(w)
	var r: int = game.rng.randi_range(0, total - 1)
	var acc: int = 0
	for i in DENOM_WEIGHT.size():
		acc += int(DENOM_WEIGHT[i])
		if r < acc:
			return i
	return DENOM_WEIGHT.size() - 1

func _place_coins() -> void:
	# min-center-distance as a fraction of the summed radii: >=1 means no overlap.
	var factor: float
	match overlap_key:
		"none":
			factor = 1.04
		"max":
			factor = 0.16
		_:
			factor = 0.55
	_top_z = 10
	var placed: Array = []  # [{pos:Vector2, r:float}]
	var rng: RandomNumberGenerator = game.rng
	for entry in _coins:
		var r: float = entry["radius"]
		var lo_x: float = _pile_rect.position.x + r
		var hi_x: float = maxf(lo_x, _pile_rect.position.x + _pile_rect.size.x - r)
		var lo_y: float = _pile_rect.position.y + r
		var hi_y: float = maxf(lo_y, _pile_rect.position.y + _pile_rect.size.y - r)
		var best_pos: Vector2 = Vector2((lo_x + hi_x) * 0.5, (lo_y + hi_y) * 0.5)
		var best_score: float = -1.0e9
		var tries: int = 80 if overlap_key == "none" else 26
		for _t in tries:
			var cand: Vector2 = Vector2(rng.randf_range(lo_x, hi_x), rng.randf_range(lo_y, hi_y))
			var mind: float = 1.0e9
			for p in placed:
				var need: float = maxf(1.0, r + float(p["r"]))
				mind = minf(mind, cand.distance_to(p["pos"]) / need)
			if overlap_key == "none":
				# accept the first non-overlapping spot; otherwise keep the roomiest
				if mind >= factor:
					best_pos = cand
					best_score = mind
					break
				if mind > best_score:
					best_score = mind
					best_pos = cand
			else:
				# want SOME overlap near `factor` (not fully apart, not perfectly stacked)
				var s: float = -absf(mind - factor)
				if s > best_score:
					best_score = s
					best_pos = cand
		var node = entry["node"]
		node.position = best_pos
		node.z_index = _top_z
		_top_z += 1
		placed.append({"pos": best_pos, "r": r})

func _update_target_label() -> void:
	_target_label.text = "Pay  " + _fmt_money(_target_amount)

func _clear_board() -> void:
	for entry in _coins:
		var node = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
	_coins.clear()
	_drag_coin = null

# --- Dragging ---------------------------------------------------------------

func _on_catcher_gui_input(event: InputEvent) -> void:
	# Handle ONLY mouse events. Both mouse->touch and touch->mouse emulation are on, so each
	# tap/drag fires both a mouse and a touch event; mouse alone covers finger and pointer.
	if not _can_play() or phase != Phase.SHOW or _answered:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var entry = _topmost_coin_at(event.position)
			if entry != null:
				_drag_coin = entry
				_drag_offset = (entry["node"] as Node2D).position - event.position
				_raise_coin(entry)
				get_viewport().set_input_as_handled()
		else:
			_drop_coin()
	elif event is InputEventMouseMotion and _drag_coin != null:
		var node = _drag_coin["node"]
		if is_instance_valid(node):
			node.position = _clamp_coin(event.position + _drag_offset, float(_drag_coin["radius"]))
			node.set_in_tray(_in_basket(_drag_coin))  # live feedback (halo) while dragging

func _drop_coin() -> void:
	# on release, snap a coin whose center is in the tray FULLY inside it (so "in the tray" is
	# unambiguous), and lock in the halo state.
	if _drag_coin == null:
		return
	var entry = _drag_coin
	if _in_basket(entry):
		_snap_into_tray(entry)
	var node = entry["node"]
	var landed: bool = _in_basket(entry)
	if is_instance_valid(node):
		node.set_in_tray(landed)
	_drag_coin = null
	game.tutorial_notify("coin_in_tray" if landed else "coin_out_of_tray")
	# Fires wherever the coin ended up. A tutorial step that just wants "the player moved a coin"
	# — shifting the top of the pile to see what is under it — should not care which.
	game.tutorial_notify("coin_moved")

func _snap_into_tray(entry) -> void:
	var node = entry["node"]
	if not is_instance_valid(node):
		return
	var r: float = float(entry["radius"])
	var tray: Rect2 = _basket_rect
	var x: float
	if tray.size.x >= 2.0 * r:
		x = clampf(node.position.x, tray.position.x + r, tray.position.x + tray.size.x - r)
	else:
		x = tray.position.x + tray.size.x * 0.5  # tray narrower than the coin: center it
	var y: float
	if tray.size.y >= 2.0 * r:
		y = clampf(node.position.y, tray.position.y + r, tray.position.y + tray.size.y - r)
	else:
		y = tray.position.y + tray.size.y * 0.5  # tray shorter than the coin: center it
	node.position = Vector2(x, y)

func _topmost_coin_at(p: Vector2):
	var best = null
	var best_z: int = -2147483648
	for entry in _coins:
		var node = entry["node"]
		if not is_instance_valid(node):
			continue
		if p.distance_to(node.position) <= float(entry["radius"]):
			if node.z_index >= best_z:
				best_z = node.z_index
				best = entry
	return best

func _raise_coin(entry) -> void:
	var node = entry["node"]
	if is_instance_valid(node):
		node.z_index = _top_z
		_top_z += 1

func _clamp_coin(p: Vector2, r: float) -> Vector2:
	var x: float = clampf(p.x, _clamp_rect.position.x + r, _clamp_rect.position.x + _clamp_rect.size.x - r)
	var y: float = clampf(p.y, _clamp_rect.position.y + r, _clamp_rect.position.y + _clamp_rect.size.y - r)
	return Vector2(x, y)

func _in_basket(entry) -> bool:
	var node = entry["node"]
	if not is_instance_valid(node):
		return false
	return _basket_rect.has_point((node as Node2D).position)

# --- Pay / resolution -------------------------------------------------------

func _on_pay_pressed() -> void:
	if not _can_play() or phase != Phase.SHOW or _answered:
		return
	var paid: float = 0.0
	for entry in _coins:
		if _in_basket(entry):
			paid += float(entry["value"])
	# epsilon compare avoids float rounding errors (never plain ==)
	var is_correct: bool = absf(paid - _target_amount) < PAY_EPSILON
	_resolve(is_correct, false, paid)

func _resolve(is_correct: bool, timed_out: bool, paid: float) -> void:
	if _answered:
		return
	_answered = true
	_drag_coin = null
	total_rounds += 1
	if is_correct:
		total_corrects += 1
		var elapsed: float = game.game_time - _show_start_ms
		times_to_answer.append(maxf(elapsed, 0.0))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var bonus: int = maxi(0, 10 - int(elapsed / 2500.0))
		game.add_score_and_time(15 + bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		_feedback.add_theme_font_size_override("font_size", _fb_font_big)
		_feedback.text = "Correct!\n" + _fmt_money(paid)
		_feedback.add_theme_color_override("font_color", Color(0.25, 0.85, 0.35, 1.0))
	else:
		var penalty: int = mini(4, maxi(0, game.score))
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		if timed_out:
			_feedback.add_theme_font_size_override("font_size", _fb_font_big)
			_feedback.text = "Too slow"
		else:
			_feedback.add_theme_font_size_override("font_size", _fb_font_small)
			_feedback.text = "You paid " + _fmt_money(paid) + "\nneeded " + _fmt_money(_target_amount)
		_feedback.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3, 1.0))
	_size_feedback_to_text()
	_feedback.show()
	MainGlobals.global_update_hud()
	phase = Phase.FEEDBACK
	_phase_start_ms = game.game_time
	# In a tutorial a missed board comes back instead of being replaced. The lesson is "pay this
	# exact amount"; swapping in a different pile the moment they get it wrong means the one thing
	# the step is teaching never actually happens, and the caption is left naming an amount that no
	# longer matches anything on screen.
	if game.tutorial_mode and not _forced_current.is_empty() \
			and (not is_correct or not _coach_wants_payment()):
		_forced_boards.push_front(_forced_current)
	if not timed_out:
		game.tutorial_notify("paid_correct" if is_correct else "paid_wrong")
		game.tutorial_notify("paid")

# Is the coach actually waiting for a payment right now? PAY is pressable at any moment, and a
# payment that happens to be CORRECT used to consume the staged pile even when the coach was still
# on an earlier step — "drag a coin into the tray", say. The level then moved on to the next pile
# while the caption still named the previous one, which is how "put in exactly 35 cents" ended up
# over a 60-cent board and a correct 35 was marked wrong.
func _coach_wants_payment() -> bool:
	if not game.tutorial_mode:
		return true
	var r = game.tutorial_runner
	if r == null or not is_instance_valid(r):
		return true
	return String(r._await_event).begins_with("paid")

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
			var frac: float = clampf(1.0 - (now - _show_start_ms) / board_time_ms, 0.0, 1.0)
			_bar_fill.visible = true
			_bar_fill.size = Vector2(_bar_full_w * frac, _bar_h)
			_bar_fill.color = Color(0.9, 0.3, 0.25, 1.0).lerp(Color(0.3, 0.8, 0.4, 1.0), frac)
			if now - _show_start_ms >= board_time_ms:
				_resolve(false, true, _basket_total())
		Phase.FEEDBACK:
			_bar_fill.visible = false
			if now - _phase_start_ms >= feedback_ms:
				phase = Phase.GAP
				_phase_start_ms = now
				_feedback.hide()
				_clear_board()
				_target_label.text = ""
		Phase.GAP:
			_bar_fill.visible = false
			if now - _phase_start_ms >= gap_ms:
				_show_board()

func _size_feedback_to_text() -> void:
	# shrink the label (and its backdrop panel) to hug the current text, centered in the play area
	_feedback.custom_minimum_size = Vector2.ZERO
	_feedback.reset_size()
	var sz: Vector2 = _feedback.get_combined_minimum_size()
	var sw: float = float(MainGlobals.screen_size.x)
	_feedback.size = sz
	_feedback.position = Vector2((sw - sz.x) * 0.5, _feedback_cy - sz.y * 0.5)

func _basket_total() -> float:
	var s: float = 0.0
	for entry in _coins:
		if _in_basket(entry):
			s += float(entry["value"])
	return s

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
	_target_label.text = ""
	game.sig_level_is_done.emit(didwin)
	if not didwin:
		sig_level_is_done.emit(false)
		return
	var pct: int = pct_correct()
	var need: int = int(ChangeLevelConfig.get_level(current_level_id).get("pass_pct", 70))
	# Passing is a RESULT, not a formality: below the level's own accuracy the SAME level comes
	# round again instead of the next one.
	var passed: bool = pct >= need
	MainGlobals.global_level_is_done(passed)
	if current_level_id >= ChangeLevelConfig.max_level():
		sig_level_is_done.emit(true)
		return
	game.need_to_increase_level = passed   # a failed level is played again
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s\n\n%s" % [
		pct_correct(),
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A",
		_progress_line(passed, need)
	]
	game.show_level_done_popup(self, "", "", current_level_id, extra, passed)

# What the player gets next, in words. "Accuracy: 40%" alone does not say whether they are moving
# on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (current_level_id + 1)

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

func _fmt_money(v: float) -> String:
	# under a dollar reads as cents ("75¢"); a dollar or more reads as "$1.35" (standard)
	var cents: int = int(round(v * 100.0))
	if cents < 100:
		return "%d¢" % cents
	return "$%d.%02d" % [int(cents / 100), cents % 100]

func _fmt_secs(s: float) -> String:
	var t: int = int(round(s))
	if t >= 60:
		return "%d:%02d min" % [t / 60, t % 60]
	return "%d sec" % t

func tick() -> void:
	pass
