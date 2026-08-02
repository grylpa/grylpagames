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

func _looks_numbered(options: Array) -> bool:
	if options.size() < 2:
		return false
	for o in options:
		var s: String = str(o).strip_edges()
		if s.is_empty() or not s.substr(0, 1).is_valid_int():
			return false
	return true

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
	call_deferred("_ensure_full_width")

func _ensure_full_width() -> void:
	%OptionsFrame.custom_minimum_size.x = MainGlobals.screen_size.x - 40

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
	%StartNewGameButton.add_theme_font_size_override("font_size", 80)
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
