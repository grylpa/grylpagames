extends CanvasLayer

var _tutorial_host: Node = null
var _tutorial_game = null

var _bg: Control = null
var _bg_t: float = 0.0

func _ready():
	MainGlobals.set_visible("instructions",true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)
	_restyle()

# The third screen to get the drawn ground (scripts/screen_backdrop.gd), in its own color: the menu
# is blue-slate, help is green, instructions are indigo. Three screens a player moves between
# should not be three copies of one photo.
func _restyle() -> void:
	var panel: PanelContainer = $BackgroundPanel
	$BackgroundPanel/TextureRect.texture = null
	_bg = ScreenBackdrop.attach(panel)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void:
			ScreenBackdrop.draw(_bg, _bg_t, ScreenBackdrop.INSTR_TOP, ScreenBackdrop.INSTR_BOT,
				ScreenBackdrop.ACCENT))
	var frame: PanelContainer = %Text.get_parent().get_parent() as PanelContainer
	if frame != null:
		frame.add_theme_stylebox_override("panel", ScreenBackdrop.card_style(28))
	ScreenBackdrop.style_title(%Title, ScreenBackdrop.ACCENT)
	ScreenBackdrop.style_close(_find_close(), ScreenBackdrop.ACCENT)
	%Text.add_theme_font_override("font", MainGlobals.get_text_font())
	%Text.add_theme_color_override("font_color", Color(0.929, 0.941, 0.969))
	set_process(true)

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()

func close_window() -> void:
	MainGlobals.set_visible("instructions",false)
	queue_free()

func set_title(title):
	%Title.text = title

func set_text(text):
	%Text.text = text

func _on_x_close_scene_button_pressed() -> void:
	close_window()

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc"):
		close_window()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
		return

# ONE footer row holds both buttons: the tutorial offer truly centred, "Got it" pinned right.
#
# A plain Control, not an HBoxContainer — in an HBox the centre child is only centred in the space
# the others leave it, so the tutorial button would sit visibly left of centre once "Got it" took
# room on the right. _layout_footer places each one itself, and the row exists whether one button is
# added or both.
#
# Created on demand by whichever function needs it first, so the call order does not matter.
var _footer: Control = null
var _tut_btn: Button = null
var _close_btn: Button = null

const FOOTER_H: int = 44
# Clear space between the two buttons, and from the row's right edge. Desktop units.
const FOOTER_GAP: int = 20
# This row's own top inset. The card's bottom margin sits above it, so the visible gap over the
# buttons is the two added together — see _footer_row.
const FOOTER_GAP_TOP: int = 6
# The type shrinks to make them fit, but only this far — past it the buttons are unreadable and the
# right answer is a narrower label, not smaller type.
const FOOTER_FONT_MAX: int = 24
const FOOTER_FONT_MIN: int = 13

func _footer_row() -> Control:
	if _footer != null and is_instance_valid(_footer):
		return _footer
	var margin: MarginContainer = MarginContainer.new()
	# The SAME side margins as the card above, taken from the card's own container rather than
	# picked — so "Got it"'s right edge lines up with the card's right edge instead of sitting a few
	# pixels inside it. A hardcoded 16 against the card's 10 is exactly the kind of near-miss that
	# reads as sloppy without being obviously wrong.
	var side: int = _card_margin("margin_right", 10)
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	# Equal air above and below the buttons.
	#
	# The gap ABOVE is not this container's alone: the card's own bottom margin is already there, and
	# the two stack. So the space under the buttons has to match the SUM, or the row sits visibly
	# closer to the bottom edge than to the card — which is what a matching pair of numbers here
	# would have produced.
	var top: int = FOOTER_GAP_TOP
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", _card_margin("margin_bottom", 10) + top)
	_footer = Control.new()
	_footer.custom_minimum_size = Vector2(0, MainGlobals.ui_font_size(FOOTER_H))
	margin.add_child(_footer)
	%Title.get_parent().get_parent().add_child(margin)
	# Re-run whenever the row's width changes — rotation, a resized window, a different canvas.
	_footer.resized.connect(_layout_footer)
	return _footer

# Place the footer buttons, shrinking the type until they fit.
#
# Anchor PRESETS were the first attempt and they are wrong for this: PRESET_CENTER_RIGHT centres the
# node ON the right edge, so half of "Got it" hung off the screen. Positions are computed here
# instead, from each button's measured minimum width, which is also what makes the fitting possible.
#
# The two must never touch, and the fixed 240/140 widths could not promise that — a narrow screen or
# a larger mobile scale simply overlapped them. So the font drops a point at a time until
#
#     tutorial_width / 2 + FOOTER_GAP + close_width  <=  row_width / 2
#
# which is the real no-overlap condition when one button is centred and the other is right-aligned.
func _layout_footer() -> void:
	if _footer == null or not is_instance_valid(_footer):
		return
	var w: float = _footer.size.x
	if w <= 1.0:
		return
	var gap: float = float(MainGlobals.ui_font_size(FOOTER_GAP))
	var fs: int = FOOTER_FONT_MAX
	var tut_w: float = 0.0
	var close_w: float = 0.0
	while true:
		for b: Button in [_tut_btn, _close_btn]:
			if b != null and is_instance_valid(b):
				MainGlobals.set_font_size(b, fs)
		tut_w = _min_w(_tut_btn)
		close_w = _min_w(_close_btn)
		# Centred button spans w/2 +/- tut_w/2; the right one occupies the last close_w.
		var fits: bool = (tut_w * 0.5 + gap + close_w) <= w * 0.5 and tut_w <= w and close_w <= w
		if fits or fs <= FOOTER_FONT_MIN:
			break
		fs -= 1
	var h: float = _footer.size.y
	if _tut_btn != null and is_instance_valid(_tut_btn):
		var th: float = _tut_btn.get_combined_minimum_size().y
		_tut_btn.size = Vector2(tut_w, th)
		_tut_btn.position = Vector2((w - tut_w) * 0.5, (h - th) * 0.5)
	if _close_btn != null and is_instance_valid(_close_btn):
		var ch: float = _close_btn.get_combined_minimum_size().y
		_close_btn.size = Vector2(close_w, ch)
		# Right edge flush with the row, which the 16px margin already insets from the screen.
		_close_btn.position = Vector2(w - close_w, (h - ch) * 0.5)

# Give a footer button the CARD's shape, read off the card itself.
#
# The buttons carried no stylebox at all — just a font colour — so they fell back to the project
# theme's default Button look and spoke a different language from the rounded, thin-bordered card
# they sit in.
#
# Copied from the live stylebox rather than restated as numbers here: restyle the card and the
# buttons follow it, which is the only version of this that stays true. The card is the PanelContainer
# wrapping the scrolling text.
func _style_footer_button(btn: Button) -> void:
	var card: Control = %Text.get_parent().get_parent() as Control
	var src: StyleBoxFlat = null
	if card != null:
		src = card.get_theme_stylebox("panel") as StyleBoxFlat
	var normal: StyleBoxFlat = src.duplicate() as StyleBoxFlat if src != null else StyleBoxFlat.new()
	if src == null:
		normal.bg_color = Color(0, 0, 0, 0)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(20)
	# Room for the label inside the border; the card's own margins are sized for a page of text.
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal", normal)
	# Pressed and hovered fill faintly with the border's own colour, so the button reacts without
	# introducing a third palette.
	var accent: Color = normal.border_color
	for state: String in ["hover", "focus"]:
		var s: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		s.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
		btn.add_theme_stylebox_override(state, s)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.34)
	btn.add_theme_stylebox_override("pressed", pressed)

# The card's own insets, so the footer can share them. The card is the PanelContainer around the
# scrolling text; the margins live on the MarginContainer above it.
func _card_margin(which: String, fallback: int) -> int:
	var card: Node = %Text.get_parent().get_parent()
	var holder: Control = card.get_parent() as Control if card != null else null
	if holder != null and holder.has_theme_constant(which):
		return holder.get_theme_constant(which)
	return fallback

func _min_w(b: Button) -> float:
	if b == null or not is_instance_valid(b):
		return 0.0
	return b.get_combined_minimum_size().x

# "Interactive tutorial" — offered where a player already goes when they have forgotten how a game
# works. Named for what it is rather than for what it does for you: it sits directly under a wall of
# instructions, and the useful distinction to draw there is that this one is played, not read. This
# is the app's only tutorial entry besides the game's own main menu, since the chooser's "How to
# play" picker is gone: a game with a tutorial teaches itself on the first run, and after that the
# offer belongs next to the text it replaces.
#
# `host` is the game's main scene. Whether it HAS a tutorial is read off the scene — if its main.gd
# defines start_tutorial(), it has one — the same test main_menu.gd uses, so no game opts in and a
# game that gains a tutorial later gets the button for free.
func offer_tutorial(host: Node, game_util) -> void:
	if host == null or not host.has_method("start_tutorial"):
		return
	_tutorial_host = host
	_tutorial_game = game_util
	_tut_btn = Button.new()
	_tut_btn.text = "Interactive tutorial"
	_tut_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	# NO fixed width: _layout_footer measures the button to decide whether the two fit, so a width
	# forced here would defeat the fitting it is measuring for.
	_tut_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tut_btn.pressed.connect(_on_tutorial_pressed)
	_style_footer_button(_tut_btn)
	_footer_row().add_child(_tut_btn)
	_layout_footer()

# "Got it" — the way OUT, at the end of the text.
#
# The X in the corner was the only way to dismiss this, and on a wall of text it is a small target
# that a reader scanning downwards does not necessarily look for. This sits where their eyes and
# thumb already are when they reach the end.
#
# Tap-anywhere was considered and rejected: the text SCROLLS, so a flick that begins as a tap — or
# the tap people use to stop momentum scrolling — would close the thing they are reading, and it
# would misfire worst on the longest instructions. Tap-outside-the-card was rejected too, because
# BackgroundPanel is anchors_preset 15 with a 10px margin: there is no outside to tap, and a 10px
# strip that dismisses reads as a bug rather than an affordance.
#
# Shares the footer row with the tutorial offer: that one centred, this one hard right.
func add_close_button() -> void:
	_close_btn = Button.new()
	_close_btn.text = "Got it"
	_close_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.pressed.connect(close_window)
	_style_footer_button(_close_btn)
	_footer_row().add_child(_close_btn)
	_layout_footer()

func _on_tutorial_pressed() -> void:
	var host: Node = _tutorial_host
	if host == null or not is_instance_valid(host) or not host.has_method("start_tutorial"):
		return
	# Close FIRST: this popup registers itself with MainGlobals.set_visible("instructions"), which
	# is one of the things game.paused() reads — a tutorial started underneath it would begin
	# frozen, and its own freeze/unfreeze would then be fighting a screen the player cannot see.
	close_window()
	if _tutorial_game != null:
		MainGlobals.note_tutorial_started(_tutorial_game.file_names_prefix)
	# Deferred so the tutorial starts on a clean frame, after this popup has actually gone.
	host.call_deferred("start_tutorial")

# ONE size for every game's instructions, scaled for mobile in one place.
#
# It used to be whatever each game passed, and three conventions had grown up: seven games passed a
# hand-written `36 if is_mobile() else 22`, couples passed a bare 30 that never scaled at all, and
# the other ~28 passed nothing and inherited the scene's theme. Couples and weris ended up visibly
# different sizes on the same screen.
#
# The per-game argument survives for a game that genuinely needs its own size, but nothing passes one
# now. Smaller type for longer text is not needed either: this screen scrolls, and the games with the
# longest instructions have a tutorial instead.
const DEFAULT_TEXT_SIZE: int = 22

func set_font_size(_font_size: int):
	# Desktop size in, mobile scaling out — the same rule as everywhere else in the app. The seven
	# hand-written pairs were doing 22 -> 36 by hand, which is 1.64 against the 1.6 this applies.
	MainGlobals.set_font_size(%Text, _font_size if _font_size > 0 else DEFAULT_TEXT_SIZE)

func _on_background_panel_gui_input(_event: InputEvent) -> void:
	pass
	# if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	# 	(event is InputEventScreenTouch and event.pressed):
	# 	close_window()
	# 	get_viewport().set_input_as_handled()
	# 	return

# The close X, wherever this screen keeps it.
func _find_close() -> Node:
	for n in _all_children(self):
		if n.name == "XCloseScene":
			return n
	return null

func _all_children(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out
