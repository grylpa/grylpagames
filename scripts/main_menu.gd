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
	# the room the text really has: the box less its padding AND the dropdown's arrow (the user could not see the
	# "7" of "7 · Weighmaster": measured against the box less 24, the name was too wide, and a right-aligned
	# clipped text loses its START -- the number)
	var sb: StyleBox = btn.get_theme_stylebox("normal")
	var pad: float = (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)) if sb != null else 24.0
	var arrow: Texture2D = btn.get_theme_icon("arrow")
	var arrow_w: float = (float(arrow.get_width()) + float(btn.get_theme_constant("arrow_margin"))) if arrow != null else 24.0
	var avail: float = btn.size.x - pad - arrow_w - 6.0
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
	# DEFERRED, because whether this game has instructions is not known yet. create_main_menu() runs
	# early in a game's _ready (weris: line 17) while set_instructions() comes much later (line 37),
	# so a check made here would find the text empty in every game and the button would never appear
	# for the games that need it most. One frame later, _ready has finished and the answer is real.
	_restyle()
	_build_card()
	call_deferred("_maybe_add_tutorial_button")
	call_deferred("_finish_card")
	call_deferred("_ensure_full_width")

# --- the look ---------------------------------------------------------------------------------
# The menu was a tiled grass photo with a 1px dark-green rounded outline around the options and two
# flat gold-text buttons whose pressed state was the same StyleBox as their normal one — pressing
# START did not look like pressing anything. The table, the switches and the sliders are untouched;
# what changed is the ground they sit on and the two things the player is here to press.

const ACCENT: Color = Color(0.976, 0.792, 0.353)
const INK: Color = Color(0.153, 0.118, 0.043)

var _bg: Control = null
var _bg_t: float = 0.0
var _pulse: Tween = null

func _restyle() -> void:
	var ground: TextureRect = $ColorRect
	# The grass came from res://art/ and every screen in the app used to wear it. Nothing is tiled
	# now; the backdrop is drawn (see scripts/screen_backdrop.gd), in the menu's own colors.
	ground.texture = null
	_bg = ScreenBackdrop.attach(ground)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void:
			ScreenBackdrop.draw(_bg, _bg_t, ScreenBackdrop.MENU_TOP, ScreenBackdrop.MENU_BOT, ACCENT))
	set_process(true)

	# MORE CONTRAST ON A PHONE (the user, 2026-11-17: "the contrast of the main menu is too low on
	# mobile"): the options panel a step lighter than the night behind it, with a visible edge
	var frame_sb: StyleBoxFlat = ScreenBackdrop.card_style()
	frame_sb.bg_color = Color(1.0, 1.0, 1.0, 0.085)
	frame_sb.border_color = Color(ACCENT, 0.30)
	%OptionsFrame.add_theme_stylebox_override("panel", frame_sb)
	ScreenBackdrop.style_title(%Title, ACCENT)

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
		var holder: Control = b.get_parent() as Control
		if holder != null:
			holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		GameButton.style(b, ACCENT, INK, int(pair[2]))
	if %StartNewGameButton.text == "START":
		%StartNewGameButton.text = "PLAY"
	if _pulse == null or not _pulse.is_valid():
		_pulse = GameButton.pulse(%StartNewGameButton, ACCENT)

# THE OPENING CARD (2026-11-17; the user: "i kind of hate it that the first screen the player sees, for
# each game they run, is that same, bland, main menu"). Everything sits on ONE CARD in the middle of the
# screen: the game's name, its one-line pitch (MainCfg.games), the level, PLAY, and "How to play" and
# "Settings" as a row of small links -- the other options FOLD under Settings, only a level row stays
# out. Behind the card is the GAME'S OWN WORLD when it offers one: a game's main scene may define
# `menu_backdrop() -> Control`, a full-screen Control the menu puts behind the card under a light scrim
# (Tip the Scales: its weigh-house). A game without one gets its chooser icon made into a poster
# (menu_icon_poster.gd). (The picture used to be a small icon left of the title, then large on the card.)
const CARD_PAD: float = 26.0
const ICON_POSTER: Script = preload("res://scripts/menu_icon_poster.gd")
var _card: PanelContainer = null
var _world: Control = null
var _pitch: Label = null
var _links: HBoxContainer = null
var _settings_btn: Button = null
var _settings_open: bool = false

func _card_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.085, 0.86)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(2)
	sb.border_color = Color(ACCENT, 0.40)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	sb.anti_aliasing = true
	sb.content_margin_left = CARD_PAD
	sb.content_margin_right = CARD_PAD
	sb.content_margin_top = CARD_PAD
	sb.content_margin_bottom = CARD_PAD
	return sb

func _build_card() -> void:
	if _card != null:
		return
	var vb: VBoxContainer = %MarginStartNewGame.get_parent() as VBoxContainer
	var center: Control = vb.get_parent() as Control
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(_card)
	_card.owner = self
	vb.reparent(_card, false)       # reparent keeps the owner, so the %names still resolve
	vb.add_theme_constant_override("separation", 10)
	# the name moves from the top of the screen into the card
	var title: Label = %Title
	var title_margin: Control = title.get_parent() as Control
	title.reparent(vb, false)
	title.owner = self
	vb.move_child(title, 0)
	title.custom_minimum_size = Vector2(0, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_margin.hide()
	# its pitch under it
	_pitch = Label.new()
	_pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pitch.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(_pitch, 19)
	_pitch.add_theme_color_override("font_color", Color(0.93, 0.90, 0.84, 0.92))
	_pitch.text = _pitch_text()
	_pitch.visible = _pitch.text != ""
	vb.add_child(_pitch)
	vb.move_child(_pitch, 1)
	# the options a little apart from the words above them
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap)
	vb.move_child(gap, 2)
	# the small links under PLAY
	var lm: MarginContainer = MarginContainer.new()
	lm.add_theme_constant_override("margin_top", 22)
	_links = HBoxContainer.new()
	_links.alignment = BoxContainer.ALIGNMENT_CENTER
	_links.add_theme_constant_override("separation", 18)
	lm.add_child(_links)
	vb.add_child(lm)
	# the START button and the Continue button come closer under a card
	%MarginStartNewGame.add_theme_constant_override("margin_top", 22)
	%MarginContinue.add_theme_constant_override("margin_top", 22)

func _pitch_text() -> String:
	if game == null:
		return ""
	for g in MainCfg.games:
		if str(g[0]) == str(game.file_names_prefix):
			return str(g[2])
	return ""

# One frame after set_game, when the game has added its options: its world or its picture, and the fold.
func _finish_card() -> void:
	var host: Node = get_parent()
	if _world == null and host != null and host.has_method("menu_backdrop"):
		_world = host.call("menu_backdrop") as Control
		if _world != null:
			var ground: Control = $ColorRect
			ground.add_child(_world)
			ground.move_child(_world, 1)       # over the night backdrop (child 0), under everything else
			if _world.has_method("menu_draws_title") and bool(_world.call("menu_draws_title")):
				_to_poster()
			else:
				var scrim: ColorRect = ColorRect.new()
				scrim.color = Color(0.0, 0.0, 0.0, 0.22)
				scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
				scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
				ground.add_child(scrim)
				ground.move_child(scrim, 2)
	if _world == null and game != null:
		# no poster of its own: the game's icon made into one (menu_icon_poster.gd)
		var ip: Control = ICON_POSTER.new()
		ip.call("setup", str(game.file_names_prefix), str(game.name), _pitch_text())
		_world = ip
		var ground2: Control = $ColorRect
		ground2.add_child(_world)
		ground2.move_child(_world, 1)
		_to_poster()
	_setup_fold()
	_menu_sound.call_deferred()

# THE POSTER (a world that draws its own title, `menu_draws_title()`): the scene is the screen -- the
# game's name set in its own style, and what the game is about -- and the card shrinks to a slim panel
# at the FOOT holding only the level, PLAY and the links, so it hides as little of the scene as it can.
# The world is told where the panel starts (`set_scene_bottom(y)`), to lay its scene out above it.
var _poster: bool = false

func _to_poster() -> void:
	_poster = true
	%Title.hide()
	if _pitch != null:
		_pitch.hide()
	var center: Control = _card.get_parent() as Control
	center.anchor_top = 1.0
	center.anchor_bottom = 1.0
	var foot: float = 92.0 if MainGlobals.is_mobile() else 52.0
	center.offset_bottom = -foot
	center.offset_top = -foot
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# NO SLAB (the user: "maybe we don't need that big slab of opaque background and gold frame"): the controls stand
	# on the scene itself, over a deep soft gradient rising from the foot (`_foot_fade`), their words outlined
	var sb: StyleBoxFlat = _card_style()
	sb.draw_center = false
	sb.set_border_width_all(0)
	sb.shadow_size = 0
	sb.content_margin_top = CARD_PAD * 0.7
	sb.content_margin_bottom = CARD_PAD * 0.7
	_card.add_theme_stylebox_override("panel", sb)
	# tight: the scene is what the player should look at
	var mobile: bool = MainGlobals.is_mobile()
	%MarginStartNewGame.add_theme_constant_override("margin_top", 14 if mobile else 8)
	%MarginContinue.add_theme_constant_override("margin_top", 14 if mobile else 8)
	if _links != null:
		(_links.get_parent() as MarginContainer).add_theme_constant_override("margin_top", 14 if mobile else 8)
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.draw_center = false
	flat.content_margin_left = 6.0
	flat.content_margin_right = 6.0
	flat.content_margin_top = 2.0
	flat.content_margin_bottom = 2.0
	%OptionsFrame.add_theme_stylebox_override("panel", flat)
	(%MarginStartNewGame.get_parent() as VBoxContainer).add_theme_constant_override("separation", 4)
	if not mobile:
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 12.0
	# THE PANEL HOLDS ONLY THE LEVEL AND PLAY (2026-11-18; the user: the scenes "occupy too little of the screen", their
	# foot hidden behind the panel -- on a desktop it took half the screen; then: "the play button should always be
	# alone and centered"). PLAY stands alone, centered, a step smaller; a Continue (Taxi, mid-game) stands BESIDE it,
	# smaller still. "How to play" moves down into the bottom button bar, centered on its icons' line, and "Settings"
	# becomes a small frameless COG at the end of the level row. The links' row is kept, hidden, as their state.
	var play_row: HBoxContainer = HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 16 if mobile else 12)
	var vb: VBoxContainer = %MarginStartNewGame.get_parent() as VBoxContainer
	vb.add_child(play_row)
	vb.move_child(play_row, %MarginStartNewGame.get_index())
	play_row.owner = self
	%MarginStartNewGame.reparent(play_row, false)
	%MarginContinue.reparent(play_row, false)
	%MarginContinue.add_theme_constant_override("margin_top", 14 if mobile else 8)
	var play: Button = %StartNewGameButton
	play.custom_minimum_size = Vector2(MainGlobals.screen_size.x * (0.40 if mobile else 0.30), 88.0 if mobile else 58.0)
	play.add_theme_font_size_override("font_size", 48 if mobile else 34)
	var cont: Button = %ContinueGameButton
	cont.custom_minimum_size = Vector2(MainGlobals.screen_size.x * (0.26 if mobile else 0.20), 66.0 if mobile else 44.0)
	cont.add_theme_font_size_override("font_size", 32 if mobile else 24)
	if _links != null:
		(_links.get_parent() as Control).hide()
	# the cog, at the end of the level row
	_cog = Button.new()
	_cog.flat = true
	_cog.focus_mode = Control.FOCUS_NONE
	_cog.custom_minimum_size = Vector2.ONE * _cog_size()
	_cog.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cog.tooltip_text = "Settings"
	_cog.draw.connect(func() -> void: _draw_cog(_cog))
	_cog.pressed.connect(func() -> void:
		if _settings_btn != null:
			_settings_btn.pressed.emit()
		_cog.queue_redraw())
	# at the PLAY row's right end, a twin of its size at the left end so PLAY stays centered (at the level row's end it
	# took room from the level list -- the user)
	_cog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cog_holder: MarginContainer = MarginContainer.new()
	cog_holder.add_theme_constant_override("margin_top", 14 if mobile else 8)
	cog_holder.add_child(_cog)
	play_row.add_child(cog_holder)
	_cog_twin = Control.new()
	_cog_twin.custom_minimum_size = Vector2.ONE * _cog_size()
	_cog_twin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_row.add_child(_cog_twin)
	play_row.move_child(_cog_twin, 0)
	# the row spans the panel (the level list's width), PLAY centered between two equal stretches: the cog sits at the
	# bottom right, its right edge on the list's
	play_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in 2:
		var stretch: Control = Control.new()
		stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_row.add_child(stretch)
		play_row.move_child(stretch, 1 if k == 0 else cog_holder.get_index())
	# a soft dark fade at the foot, behind the bottom bar, so its icons read over a bright scene (Dispatch's lawn)
	var foot_fade: TextureRect = TextureRect.new()
	var fg: GradientTexture2D = GradientTexture2D.new()
	fg.fill_from = Vector2(0.0, 0.0)
	fg.fill_to = Vector2(0.0, 1.0)
	fg.width = 4
	fg.height = 64
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.30, Color(0.02, 0.015, 0.01, 0.50))
	grad.set_color(grad.get_point_count() - 1, Color(0.02, 0.015, 0.01, 0.86))
	fg.gradient = grad
	foot_fade.texture = fg
	foot_fade.stretch_mode = TextureRect.STRETCH_SCALE
	foot_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foot_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot_fade.z_index = 1
	foot_fade.anchor_left = 0.0
	foot_fade.anchor_right = 1.0
	foot_fade.anchor_top = 1.0
	foot_fade.anchor_bottom = 1.0
	foot_fade.offset_top = -(420.0 if mobile else 300.0)
	add_child(foot_fade)
	_foot_fade = foot_fade
	move_child(foot_fade, $ColorRect.get_index() + 1)
	# "How to play", down in the bottom bar: a small outlined link centered on the icons' line
	_bar_howto = _link_button("How to play")
	_bar_howto.custom_minimum_size = Vector2(0.0, 52.0 if mobile else 32.0)
	_bar_howto.add_theme_font_size_override("font_size", 26 if mobile else 18)
	# a dark backing, as the panel's, so it reads over any scene (over Dispatch's bright lawn it did not)
	for st_name in ["normal", "hover", "pressed", "focus"]:
		var bsb: StyleBoxFlat = (_bar_howto.get_theme_stylebox(st_name) as StyleBoxFlat).duplicate() as StyleBoxFlat
		if bsb != null:
			bsb.draw_center = true
			bsb.bg_color = Color(0.05, 0.035, 0.025, 0.80 if st_name == "normal" else 0.92)
			_bar_howto.add_theme_stylebox_override(st_name, bsb)
	_bar_howto.pressed.connect(_on_tutorial_button_pressed)
	add_child(_bar_howto)
	_bar_howto.z_index = 2              # over the backdrop (its ColorRect stands at z 1)
	var bar_mid: float = 35.0 if mobile else 21.0
	_bar_howto.anchor_left = 0.5
	_bar_howto.anchor_right = 0.5
	_bar_howto.anchor_top = 1.0
	_bar_howto.anchor_bottom = 1.0
	_bar_howto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar_howto.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bar_howto.offset_top = -bar_mid
	_bar_howto.offset_bottom = -bar_mid
	_sync_poster_links()
	for n2 in %OptionsFrame.find_children("*", "Label", true, false):
		(n2 as Label).add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		(n2 as Label).add_theme_constant_override("outline_size", 8 if mobile else 6)
		(n2 as Label).add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		(n2 as Label).add_theme_constant_override("shadow_offset_y", 2)
	# and the level row a step smaller on a desktop, where the scenes were authored for a phone's sizes
	if not mobile:
		for n in %OptionsFrame.find_children("*", "", true, false):
			if n is Label or n is OptionButton:
				(n as Control).add_theme_font_size_override("font_size", 24)
	_card.resized.connect(func() -> void: _tell_scene_bottom.call_deferred())
	_tell_scene_bottom.call_deferred()

# "How to play" centered on the bottom bar's icons, wherever the bar's layout put them
func _place_bar_link() -> void:
	if _bar_howto == null:
		return
	var bar: Node = get_tree().root.find_child("BottomOptionButtons", true, false)
	if bar == null:
		return
	var hb: Control = bar.get_node_or_null("%HBoxContainer") as Control
	if hb == null:
		return
	var mid: float = -1.0
	for c in hb.get_children():
		if c is Button and (c as Button).visible:
			mid = (c as Button).get_global_rect().get_center().y
			break
	if mid < 0.0:
		return
	var full_h: float = get_viewport().get_visible_rect().size.y
	var off: float = mid - full_h
	_bar_howto.offset_top = off
	_bar_howto.offset_bottom = off

var _cog: Button = null
var _cog_twin: Control = null
var _foot_fade: TextureRect = null
var _bar_howto: Button = null

func _cog_size() -> float:
	return 52.0 if MainGlobals.is_mobile() else 34.0

# the poster's cog and bar link follow the hidden links they stand for
func _sync_poster_links() -> void:
	if not _poster:
		return
	if _bar_howto != null:
		_bar_howto.visible = _howto_added
	if _cog != null:
		_cog.visible = _settings_btn != null and _settings_btn.visible
		_cog.get_parent().visible = _cog.visible
		_cog_twin.visible = _cog.visible
		_cog.queue_redraw()
	_ensure_full_width()

# a gear: a ring of eight square-cut teeth round a wheel with a hole, gold, brighter while the settings are open
func _draw_cog(btn: Button) -> void:
	var c: Vector2 = btn.size * 0.5
	var r: float = minf(btn.size.x, btn.size.y) * 0.5 * 0.86
	var col: Color = Color(ACCENT, 1.0 if _settings_open else 0.80)
	if btn.is_hovered():
		col = col.lightened(0.15)
	var pts: PackedVector2Array = PackedVector2Array()
	var teeth: int = 8
	for k in teeth * 4:
		var a: float = TAU * (float(k) - 0.5) / float(teeth * 4)
		var outer: bool = (k % 4) == 1 or (k % 4) == 2
		pts.append(c + Vector2(cos(a), sin(a)) * (r if outer else r * 0.74))
	btn.draw_colored_polygon(pts, col)
	btn.draw_circle(c, r * 0.30, Color(0.05, 0.035, 0.025, 1.0))
	btn.draw_arc(c, r * 0.30, 0.0, TAU, 24, col.darkened(0.25), 1.5, true)

# the panel's new size settles a frame after a fold; the poster re-lays itself above it then
func _tell_scene_bottom_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_tell_scene_bottom()

func _tell_scene_bottom() -> void:
	_place_bar_link()
	if _foot_fade != null and _card != null:
		var full_h: float = get_viewport().get_visible_rect().size.y
		_foot_fade.offset_top = -(full_h - _card.get_global_rect().position.y) - (150.0 if MainGlobals.is_mobile() else 90.0)
	if _world != null and is_instance_valid(_world) and _world.has_method("set_scene_bottom"):
		_world.call("set_scene_bottom", _card.get_global_rect().position.y - $ColorRect.get_global_rect().position.y)

# THE FOLD: a row naming the level stays on the card; every other option goes under "Settings".
func _is_level_row(row: Node) -> bool:
	for c in row.get_children():
		if c is Label and str((c as Label).text).to_lower().contains("level"):
			return true
	return false

func _foldable() -> Array:
	var out: Array = []
	for row in _option_rows_vbox.get_children():
		if not _is_level_row(row):
			out.append(row)
	# the slider grid: a label then its slider, pair by pair; a level slider stays out like a level list
	if grid != null:
		var kids: Array = grid.get_children()
		var k: int = 0
		while k + 1 < kids.size():
			var lbl: Node = kids[k]
			if not (lbl is Label and str((lbl as Label).text).to_lower().contains("level")):
				out.append(kids[k])
				out.append(kids[k + 1])
			k += 2
	return out

func _setup_fold() -> void:
	if _links == null:
		return
	var rows: Array = _foldable()
	if rows.is_empty():
		if _settings_btn != null:
			_settings_btn.hide()
		_apply_fold()
		return
	if _settings_btn == null:
		_settings_btn = _link_button("Settings")
		_settings_btn.pressed.connect(func() -> void:
			_settings_open = not _settings_open
			_apply_fold())
		_links.add_child(_settings_btn)
	_settings_btn.show()
	_apply_fold()

func _apply_fold() -> void:
	for c in _foldable():
		(c as CanvasItem).visible = _settings_open
	if grid != null:
		var any_shown: bool = false
		for c in grid.get_children():
			if (c as CanvasItem).visible:
				any_shown = true
		grid.visible = any_shown
	var level_rows: int = 0
	for row in _option_rows_vbox.get_children():
		if _is_level_row(row):
			level_rows += 1
	_option_rows_vbox.visible = level_rows > 0 or (_settings_open and _option_rows_vbox.get_child_count() > 0)
	%OptionsFrame.visible = (grid != null and grid.visible) or _option_rows_vbox.visible
	if _settings_btn != null:
		_settings_btn.text = "Hide settings" if _settings_open else "Settings"
	if _poster:
		_sync_poster_links()
		_tell_scene_bottom_later()

func _link_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(GameButton.primary_size().x * 0.40, 0.0)
	GameButton.style(btn, ACCENT, INK, GameButton.SECONDARY_FONT, true)
	return btn

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()

func _ensure_full_width() -> void:
	%OptionsFrame.custom_minimum_size.x = MainGlobals.screen_size.x - 40 - CARD_PAD * 2.0
	if _card != null:
		_card.custom_minimum_size.x = MainGlobals.screen_size.x - 40

# "How to play" on the game's OWN menu, for a player who is already inside the game and should not
# have to go back out to the chooser to find out how it works.
#
# EVERY game gets the button; what it opens depends on what the game has:
#
#   a tutorial      its main.gd defines start_tutorial() -> the coached run
#   no tutorial     its instructions text -> the instructions screen
#
# Both are read off the game itself rather than from a list, so nothing has to opt in: a game that
# gains a tutorial later stops offering the text and starts offering the tutorial, for free, and a
# game that has neither shows no button rather than one that opens nothing.
var _howto_added: bool = false

func _maybe_add_tutorial_button() -> void:
	if _howto_added or _links == null:
		return
	var host: Node = get_parent()
	if host == null:
		return
	var has_tutorial: bool = host.has_method("start_tutorial")
	var has_text: bool = game != null and not String(game.instructions_text).strip_edges().is_empty()
	if not has_tutorial and not has_text:
		return
	# Ghost: the same button as START, in its secondary form — present, not competing with it; on the
	# card's row of links, first
	var btn: Button = _link_button("How to play")
	btn.pressed.connect(_on_tutorial_button_pressed)
	_links.add_child(btn)
	_links.move_child(btn, 0)
	_howto_added = true
	_sync_poster_links()

func _on_tutorial_button_pressed() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	if not host.has_method("start_tutorial"):
		# No coached run for this game — show it the text instead. `false` is the ON-DEMAND form:
		# the automatic path suppresses itself once the player has seen it, which is right for a
		# first-run popup and wrong for a button the player just pressed.
		if game != null:
			game.show_instructions(host, false)
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
	var msg: String = "Scores reset." if ok else "Local scores cleared.\n(Cloud delete failed. Check your connection.)"
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
	_menu_sound.call_deferred()

# the game's ambient, softly, while its menu is up (GenericGameUtil.menu_ambient); a frame late, after the game's own
# way to the menu has stopped it
func _menu_sound() -> void:
	if game != null and is_instance_valid(game):
		game.menu_ambient(visible)

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
	_apply_row_rhythm()
	_setup_fold()

# Sliders land in a GridContainer and options in a VBox beside it, so without this the two halves
# of one menu keep two different vertical rhythms. Set in code rather than the scene so the three
# numbers cannot drift apart again.
const ROW_SEPARATION: int = 14

func _apply_row_rhythm() -> void:
	if grid != null:
		grid.add_theme_constant_override("v_separation", ROW_SEPARATION)
		var inner: Node = grid.get_parent()
		if inner is VBoxContainer:
			inner.add_theme_constant_override("separation", ROW_SEPARATION)
	if _option_rows_vbox != null:
		_option_rows_vbox.add_theme_constant_override("separation", ROW_SEPARATION)
	# An EMPTY container is not free: it still contributes the column's separation, so a menu with
	# only a slider was pushed up by the empty option box below it and one with only a dropdown was
	# pushed down by the empty slider grid above — off centre, in opposite directions, which is
	# exactly the pair of symptoms reported. Hide whichever half has nothing in it.
	if grid != null:
		grid.visible = grid.get_child_count() > 0
	if _option_rows_vbox != null:
		_option_rows_vbox.visible = _option_rows_vbox.get_child_count() > 0

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
	# what does not fit is trimmed at its END ("7 · Weighm…"), never its start: right-aligned and clipped, the
	# level's number was the part cut off
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn.theme = _option_theme
	_style_option_button(btn)
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
	hbox.add_theme_constant_override("separation", 30)   # matches the slider grid's h_separation
	hbox.add_child(lbl)
	hbox.add_child(btn)
	# Added straight to the column, with no per-row padding.
	#
	# Each option row used to be wrapped in a MarginContainer with 24 top AND bottom, which a slider
	# row does not have. Measured on buoy: slider rows came out 60 tall and option rows 108, so the
	# menu had two different rhythms in it and the option half sat much further apart. The spacing
	# between rows belongs to the container, once, not to every other row individually.
	_option_rows_vbox.add_child(hbox)
	_option_labels.append(lbl)
	_align_option_labels()
	_apply_row_rhythm()
	_setup_fold()

# THE DROPDOWN'S VALUE READS (the user: low contrast on a phone): it was Godot's default -- light grey on a
# near-black box that hardly stood off the panel. Now bright cream on a lighter, gold-edged box.
const OPTION_TEXT: Color = Color(1.0, 0.97, 0.90)

func _style_option_button(btn: OptionButton) -> void:
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		if state == "focus":
			sb.draw_center = false
			sb.border_color = Color(ACCENT, 0.0)
		else:
			sb.bg_color = Color(1.0, 1.0, 1.0, 0.16 if state == "normal" else 0.24)
			sb.border_color = Color(ACCENT, 0.55 if state == "normal" else 0.85)
		btn.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(c, OPTION_TEXT)
	btn.add_theme_constant_override("outline_size", 0)

# Every option row's label gets the widest one's width, so the dropdowns start on one line rather
# than each wherever its own label happens to end.
var _option_labels: Array = []

func _align_option_labels() -> void:
	var max_w: float = 0.0
	for l: Control in _option_labels:
		l.custom_minimum_size.x = 0.0
		max_w = maxf(max_w, l.get_combined_minimum_size().x)
	for l: Control in _option_labels:
		l.custom_minimum_size.x = max_w

# An ON/OFF row: the label and a switch (scripts/menu_switch.gd) at the row's right end, in line with
# the dropdowns. It reports through sig_option_changed like a dropdown does -- index 0 off, 1 on --
# and update_option / get_option work on it the same way, so a game handles both alike.
func add_switch_entry(_id: int, _name: String) -> void:
	var lbl = entry_label_scene.instantiate()
	lbl.text = _name
	var sw: MenuSwitch = MenuSwitch.new()
	sw.toggled.connect(func(v: bool): sig_option_changed.emit(_id, 1 if v else 0))
	_switches.append({"id": _id, "sw": sw})
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.add_child(lbl)
	hbox.add_child(sw)
	_option_rows_vbox.add_child(hbox)
	_option_labels.append(lbl)
	_align_option_labels()
	_apply_row_rhythm()
	_setup_fold()

var _switches: Array = []

func update_option(_id: int, _idx: int) -> void:
	for entry in _option_buttons:
		if entry["id"] == _id:
			entry["btn"].select(_idx)
			break
	for entry in _switches:
		if entry["id"] == _id:
			(entry["sw"] as MenuSwitch).set_on(_idx != 0)
			break

# The index an option list is SHOWING, or -1 if there is no such list. A game that starts from the
# menu can read the choice from here rather than trusting a copy it kept from the last change.
func get_option(_id: int) -> int:
	for entry in _option_buttons:
		if entry["id"] == _id:
			return int(entry["btn"].selected)
	for entry in _switches:
		if entry["id"] == _id:
			return 1 if (entry["sw"] as MenuSwitch).on else 0
	return -1

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
	if _settings_btn != null:
		_settings_btn.hide()
	_sync_poster_links()

func _on_start_new_game_button_pressed() -> void:
	sig_start_game.emit(true)

func show_continue_and_start_new(_visible:bool):
	%StartNewGameButton.text = "NEW GAME" if _visible else "PLAY"
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
