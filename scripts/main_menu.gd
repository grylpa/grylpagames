extends CanvasLayer

signal sig_start_game(continue_saved)
signal sig_slider_changed(_id, _val)
signal sig_option_changed(_id, _idx)

var game:GenericGameUtil

@export var entry_label_scene: PackedScene = load("res://scenes/main_menu_item_label.tscn")
@export var entry_slider_scene: PackedScene = load("res://scenes/menu_slider_scene.tscn")

@onready var grid = %GridContainer
@onready var _option_rows_vbox = %OptionRowsVBox

var sliders = []
var _option_buttons: Array = []
var _option_theme = load("res://scenes/option_list_theme.tres")

# Level lists are usually "<number> <tag>" — "1 Sh1", "9 LD2", "10 LBo2". In a proportional face
# the numbers do not line up, the one- and two-digit rows step sideways, and the list reads as a
# jumble. A list whose entries ALL start with a digit is therefore drawn in the project's mono
# face, which lines the numbers up into a column. Word lists ("Easy", "Hard") are left alone —
# mono buys them nothing.
const _MONO_PATH: String = "res://art/fonts/JetBrainsMono.ttf"
static var _mono_font: FontFile = null

func _mono() -> FontFile:
	if _mono_font == null and ResourceLoader.exists(_MONO_PATH):
		_mono_font = ResourceLoader.load(_MONO_PATH) as FontFile
	return _mono_font

# A MAJORITY of entries starting with a digit is enough, not every one of them. The breathing
# games list seven timing patterns alongside "Active" and sometimes "User 4-2-4-2": those two are
# exactly the rows that gain nothing from mono, and requiring unanimity let them veto the alignment
# for the seven rows that need it. Word-only lists ("Easy", "Hard") still come out proportional.
func _looks_numbered(options: Array) -> bool:
	if options.size() < 2:
		return false
	var numbered: int = 0
	for o in options:
		var s: String = str(o).strip_edges()
		if not s.is_empty() and s.substr(0, 1).is_valid_int():
			numbered += 1
	return numbered >= 2 and numbered * 2 > options.size()

# Applies to the button AND its drop list, so the collapsed value and the open list agree.
func _apply_option_font(btn: OptionButton, options: Array) -> void:
	var mf: FontFile = _mono()
	if mf == null or not _looks_numbered(options):
		return
	btn.add_theme_font_override("font", mf)
	btn.get_popup().add_theme_font_override("font", mf)
	var longest: String = ""
	for o in options:
		if str(o).length() > longest.length():
			longest = str(o)
	btn.set_meta("_mono_longest", longest)
	if not btn.has_meta("_mono_fit"):
		btn.set_meta("_mono_fit", true)
		btn.resized.connect(func() -> void: _fit_option_font(btn, mf))
	_fit_option_font.call_deferred(btn, mf)   # the row has not been laid out yet on the first call

# Shrink the mono size until the widest entry fits the COLLAPSED button, so a descriptive level
# name ("10 N2 Letter+color") is never clipped. The caption eats most of the row — measured, the
# dropdown gets 282 px of a 600 px row against a 288 px caption minimum — so how much text fits
# depends on how short the game made its caption. Only ever shrinks below the theme size, never
# grows past it, and the DROP LIST keeps the full size since it sizes itself to its content.
func _fit_option_font(btn: OptionButton, mf: FontFile) -> void:
	if not is_instance_valid(btn) or btn.size.x < 40.0:
		return
	var longest: String = str(btn.get_meta("_mono_longest", ""))
	if longest == "":
		return
	if not btn.has_meta("_mono_base_fs"):
		btn.set_meta("_mono_base_fs", btn.get_theme_font_size("font_size"))
	var base: int = int(btn.get_meta("_mono_base_fs"))
	var avail: float = btn.size.x - 24.0        # the button's own horizontal padding
	var fs: int = base
	while fs > 14 and mf.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	btn.add_theme_font_size_override("font_size", fs)

func _ready() -> void:
	%Title.text = PneumoG.game.name.to_upper()
	refresh()

func refresh() -> void:
	pass	
	# difficulty_slider.set_value_no_signal(PneumoG.starting_level)

func set_game(_game):
	game = _game
	%Title.text = game.name
	if MainCfg.show_reset_scores:
		_add_reset_scores_button()
	_maybe_add_tutorial_button()
	_restyle()
	call_deferred("_ensure_full_width")

# --- the look ---------------------------------------------------------------------------------
# The menu was a tiled grass photo with a 1px dark-green rounded outline around the options and two
# flat gold-text buttons whose pressed state was the same StyleBox as their normal one — pressing
# START did not look like pressing anything. The table, the switches and the sliders are untouched;
# what changed is the ground they sit on and the two things the player is here to press.

const BG_TOP: Color = Color(0.114, 0.137, 0.204)
const BG_BOT: Color = Color(0.043, 0.055, 0.086)
const ACCENT: Color = Color(0.976, 0.792, 0.353)
const INK: Color = Color(0.153, 0.118, 0.043)

var _bg: Control = null
var _bg_t: float = 0.0

func _restyle() -> void:
	var ground: TextureRect = $ColorRect
	# The grass came from res://art/ and every screen in the app used to wear it. Nothing is tiled
	# now; the backdrop is drawn.
	ground.texture = null
	if _bg == null or not is_instance_valid(_bg):
		_bg = Control.new()
		_bg.name = "Backdrop"
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		ground.add_child(_bg)
		ground.move_child(_bg, 0)
		_bg.draw.connect(_draw_backdrop)
	set_process(true)

	# The options table: a card, like the rest of the app, instead of an outline on grass.
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = Color(1.0, 1.0, 1.0, 0.045)
	frame.set_corner_radius_all(24)
	frame.content_margin_left = 20.0
	frame.content_margin_right = 20.0
	frame.content_margin_top = 14.0
	frame.content_margin_bottom = 14.0
	frame.border_width_left = 1
	frame.border_width_top = 1
	frame.border_width_right = 1
	frame.border_width_bottom = 1
	frame.border_color = Color(1.0, 1.0, 1.0, 0.10)
	%OptionsFrame.add_theme_stylebox_override("panel", frame)

	%Title.add_theme_font_override("font", MainGlobals.get_text_font())
	%Title.add_theme_color_override("font_color", ACCENT)
	%Title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	%Title.add_theme_constant_override("outline_size", 6)

	# The two buttons the player came here for. Same object as the game-over Restart, and the SAME
	# SIZE in every game — these used to inherit whatever height the surrounding VBox had left
	# over, so START was huge in dino and ordinary in Moving Cards.
	for pair in [[%StartNewGameButton, GameButton.primary_size(), GameButton.PRIMARY_FONT],
			[%ContinueGameButton, GameButton.continue_size(), GameButton.CONTINUE_FONT]]:
		var b: Button = pair[0]
		b.theme = null                     # start_button.tres used one StyleBox for every state
		b.custom_minimum_size = pair[1]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# the margin parents must not stretch them either
		var holder: Control = b.get_parent() as Control
		if holder != null:
			holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		GameButton.style(b, ACCENT, INK, int(pair[2]))
	if _pulse == null or not _pulse.is_valid():
		_pulse = GameButton.pulse(%StartNewGameButton, ACCENT)

var _pulse: Tween = null

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()

func _draw_backdrop() -> void:
	var w: float = _bg.size.x
	var h: float = _bg.size.y
	if w < 4.0 or h < 4.0:
		return
	_bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOT, BG_BOT]))
	# A pool of light under the title, so the screen has a top rather than being evenly dark.
	var glow: Texture2D = MainGlobals.menu_glow_texture()
	if glow != null:
		var gw: float = w * 1.5
		_bg.draw_texture_rect(glow, Rect2(w * 0.5 - gw * 0.5, -gw * 0.30, gw, gw * 0.75), false,
			Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14))
	# Slow dust. Twelve specks, positions derived from the clock — enough that the screen is not
	# a still image, far too slow to pull the eye off the options.
	for i in 18:
		var seed_f: float = float(i) * 1.6180339
		var speed: float = 5.0 + fmod(seed_f * 31.0, 7.0)
		var y: float = h - fposmod(fmod(seed_f * 197.0, h) + _bg_t * speed, h)
		var x: float = fmod(seed_f * 389.0, w) + sin(_bg_t * 0.35 + seed_f * 5.0) * 18.0
		var a: float = 0.08 + 0.11 * (0.5 + 0.5 * sin(_bg_t * 0.6 + seed_f * 3.0))
		_bg.draw_circle(Vector2(x, y), 1.7 + fmod(seed_f * 7.0, 1.9), Color(1, 1, 1, a))
	# Vignette, so the edges settle and the card in the center is where the eye lands.
	var vw: float = 120.0
	var dark: Color = Color(0.0, 0.0, 0.0, 0.30)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	_bg.draw_polygon(PackedVector2Array([Vector2(w - vw, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - vw, h)]),
		PackedColorArray([clear, dark, dark, clear]))
	_bg.draw_polygon(PackedVector2Array([Vector2(0, h - vw * 1.4), Vector2(w, h - vw * 1.4), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, dark, dark]))

func _ensure_full_width() -> void:
	%OptionsFrame.custom_minimum_size.x = MainGlobals.screen_size.x - 40

# "How to play" on the game's OWN menu, for a player who is already inside the game and should not
# have to go back out to the chooser to find the tutorial.
#
# Whether this game has a tutorial is read off the host scene — if its main.gd defines
# start_tutorial(), it has one. That means no game has to opt in, and a game that gains a tutorial
# later gets the button for free.
func _maybe_add_tutorial_button() -> void:
	var host: Node = get_parent()
	if host == null or not host.has_method("start_tutorial"):
		return
	var vbox: Node = %MarginStartNewGame.get_parent()
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	var btn: Button = Button.new()
	btn.text = "How to play"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(GameButton.primary_size().x * 0.72, 0.0)
	# Ghost: the same button as START, in its secondary form — present, not competing with it.
	GameButton.style(btn, ACCENT, INK, GameButton.SECONDARY_FONT, true)
	btn.pressed.connect(_on_tutorial_button_pressed)
	margin.add_child(btn)
	vbox.add_child(margin)

func _on_tutorial_button_pressed() -> void:
	var host: Node = get_parent()
	if host == null or not host.has_method("start_tutorial"):
		return
	# Safe to run mid-session: begin_tutorial() snapshots the player's score, level and ongoing
	# row, every write is suppressed while it runs, and end_tutorial() puts all of it back.
	if game != null:
		MainGlobals.note_tutorial_started(game.file_names_prefix)
	host.call("start_tutorial")

func _add_reset_scores_button() -> void:
	var vbox: Node = %MarginStartNewGame.get_parent()
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	var btn: Button = Button.new()
	btn.text = "Reset Scores"
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(180, 0)
	btn.pressed.connect(_on_reset_scores_pressed)
	margin.add_child(btn)
	vbox.add_child(margin)

func _on_reset_scores_pressed() -> void:
	game.show_yesno_dlg(self, "Reset Scores",
		"Delete ALL saved scores for %s?\nThis cannot be undone." % game.name,
		"Reset", "Cancel",
		Callable(self, "_on_reset_scores_confirmed"), Callable())

func _on_reset_scores_confirmed() -> void:
	game.reset_local_scores()
	BE.delete_game_scores(game.file_names_prefix, Callable(self, "_on_cloud_reset_done"))

func _on_cloud_reset_done(ok: bool) -> void:
	var msg: String = "Scores reset." if ok else "Local scores cleared.\n(Cloud delete failed — check connection.)"
	game.show_yesno_dlg(self, "Reset Scores", msg, "OK", "", Callable(), Callable())

func _on_continue_game_button_pressed() -> void:
	sig_start_game.emit(false)

func _input(event):
	if game:
		game.test_open_scores_screen(event,self)

func _on_visibility_changed() -> void:
	MainGlobals.set_visible("main_menu",visible)
	# Showing the menu ends any running tutorial. The coach lives on a CanvasLayer owned by the
	# game's main scene, so it does NOT hide with the level — pressing M mid-tutorial left the
	# balloon sitting on top of the menu. This is the one place every game passes through on its
	# way back, so no game has to remember to do it.
	# Ending here is safe: abort() restores the player's session exactly as finishing would, and
	# it is a no-op both when nothing is running and when the tutorial has just completed (which
	# is itself what brought the menu back).
	# DEFERRED on purpose. A game's "back to the menu" handler typically calls show_main_menu()
	# and THEN runs its save path (dino: _save_ongoing_score + convert_ongoing_score_to_permanent).
	# Ending the tutorial synchronously here would clear tutorial_mode first and let those writes
	# through, so quitting a tutorial could commit the player's pending real session. Deferring
	# keeps tutorial_mode true for the rest of that handler — every write stays suppressed — and
	# the tutorial ends a frame later.
	if visible and game != null:
		game.call_deferred("abort_tutorial")

func add_entry(_id, _name, _min_val, _max_val, _is_bool):
	var lbl = entry_label_scene.instantiate()
	var slid = entry_slider_scene.instantiate()
	lbl.text = _name
	grid.add_child(lbl)
	grid.add_child(slid)
	slid.init(_id, _min_val, _max_val, _is_bool)
	slid.value_changed.connect(on_slider_val_changed)
	sliders.append(slid)
	_normalize_slider_widths()

func _normalize_slider_widths() -> void:
	var max_w: float = 0.0
	for s in sliders:
		max_w = maxf(max_w, s.get_label_min_width())
	for s in sliders:
		s.set_label_min_width(max_w)

func on_slider_val_changed(id, val):
	sig_slider_changed.emit(id, val)

func add_option_entry(_id: int, _name: String, _options: Array) -> void:
	var lbl = entry_label_scene.instantiate()
	lbl.text = _name
	var btn: OptionButton = OptionButton.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.fit_to_longest_item = false
	btn.clip_text = true
	btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn.theme = _option_theme
	for opt in _options:
		btn.add_item(str(opt))
	_apply_option_font(btn, _options)
	var popup: PopupMenu = btn.get_popup()
	popup.about_to_popup.connect(func():
		if MainGlobals.is_mobile():
			popup.add_theme_constant_override("v_separation", 48)
		popup.reset_size()
	)
	btn.item_selected.connect(func(idx): sig_option_changed.emit(_id, idx))
	_option_buttons.append({"id": _id, "btn": btn})
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.add_child(lbl)
	hbox.add_child(btn)
	var row_margin: MarginContainer = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_top", 24)
	row_margin.add_theme_constant_override("margin_bottom", 24)
	row_margin.add_child(hbox)
	_option_rows_vbox.add_child(row_margin)

func update_option(_id: int, _idx: int) -> void:
	for entry in _option_buttons:
		if entry["id"] == _id:
			entry["btn"].select(_idx)
			break

func set_option_items(_id: int, _options: Array) -> void:
	for entry in _option_buttons:
		if entry["id"] == _id:
			entry["btn"].clear()
			for opt in _options:
				entry["btn"].add_item(str(opt))
			_apply_option_font(entry["btn"], _options)   # the list can change shape, so re-decide
			break

func update_val(_id, _val):
	for s in sliders:
		if s.id == _id:
			s.set_value_no_signal(_val)
			break

func hide_frame():
	%OptionsFrame.hide()

func _on_start_new_game_button_pressed() -> void:
	sig_start_game.emit(true)

func show_continue_and_start_new(_visible:bool):
	%StartNewGameButton.text = "NEW GAME" if _visible else "START"
	# No font override here. This line set 80 for every game that called it — whether or not it
	# was showing a Continue button — which is why START was huge in dino, whack and taxi and
	# ordinary in Moving Cards and Polka Dots. The size comes from GameButton.PRIMARY_FONT now,
	# once, for everyone.
	if _visible:
		%MarginContinue.show()
	else:
		%MarginContinue.hide()
	

func _on_color_rect_visibility_changed() -> void:
	MainGlobals.set_visible("main_menu",visible)


func _on_title_margin_visibility_changed() -> void:
	MainGlobals.set_visible("main_menu",visible)


func _on_title_visibility_changed() -> void:
	MainGlobals.set_visible("main_menu",visible)
