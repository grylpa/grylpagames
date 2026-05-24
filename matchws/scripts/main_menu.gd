extends CanvasLayer

signal menu_start_game
signal sig_show_add_new_words
signal sig_slider_changed(_id, _val)

@export var entry_label_scene: PackedScene = load("res://scenes/main_menu_item_label.tscn")
@export var entry_slider_scene: PackedScene = load("res://scenes/menu_slider_scene.tscn")

@onready var grid = %GridContainer

var sliders = []

var words_list_scene = preload("res://matchws/scenes/words_list.tscn")

var user_texture = load("res://art/user_white_16.png")
var no_user_texture = load("res://art/option_button_icon_empty_16.png")

func _ready() -> void:
	# $DownloadingMessage.hide()
	$DownloadingMessage.message_timer_timeout.connect(_on_message_timer_timeout)
	%Title.text = MatchwsG.game.name.to_upper()
	refresh()
	var c = Color(1, 1, 0, 1)
	%HelpButton.modulate = c
	%StatsButton.modulate = c
	%WordsListButton.modulate = c
	%AddNewWordsButton.modulate = c

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

func update_val(_id, _val):
	for s in sliders:
		if s.id == _id:
			s.set_value_no_signal(_val)
			break

func _show_buttons(_show: bool):
	%StartGameButton.visible = true
	%StartGameButton.disabled = !_show
	# %StartGameButton.visible = _show
	%StatsButton.visible = false#_show
	%WordsListButton.visible = _show
	%AddNewWordsButton.visible = _show and !MainGlobals.is_mobile()

func refresh() -> void:
	if MatchwsG.words.has_got_words():
		hide_message()
		_show_buttons(true)
		var nlangs := 0
		%NewLangList.clear()
		%OldLangList.clear()
		for langid in MatchwsG.words.languages:
			nlangs += 1
			var lang_name = MatchwsG.words.languages[langid]
			%NewLangList.add_item(lang_name, langid)
			%OldLangList.add_item(lang_name, langid)
		if nlangs > 1:
			%NewLangList.select(max(0,MainGlobals.find_id_in_option_button(%NewLangList, MatchwsG.words.selected_new_lang_id)))
			%OldLangList.select(max(0,MainGlobals.find_id_in_option_button(%OldLangList, MatchwsG.words.selected_known_lang_id)))

		%CollectionList.clear()
		%CollectionList.add_item("All", -1000)
		%CollectionList.set_item_metadata(%CollectionList.item_count-1, true)

		for collection in MatchwsG.words.collections:
			var collection_id = int(collection.get("collection_id", -1))
			var collection_name = collection.get("collection_name", "unknown")#.capitalize()# .replace("_", " ")
			var user_id = collection.get("user_id", "")
			if typeof(user_id) != TYPE_NIL and typeof(user_id) == TYPE_STRING and user_id.length() > 0:
				%CollectionList.add_icon_item(user_texture, collection_name, collection_id)
			else:
				# %CollectionList.add_icon_item(no_user_texture, collection_name, collection_id)
				%CollectionList.add_item(collection_name, collection_id)
			%CollectionList.set_item_metadata(%CollectionList.item_count-1, true)
			
		if %CollectionList.item_count > 0:
			%CollectionList.select(max(0,MainGlobals.find_id_in_option_button(%CollectionList, MatchwsG.words.selected_collection_id)))
	else:
		_show_buttons(false)
		if MatchwsG.words.failed_getting_words:
			message("Retry downloading words...")
		else:
			message("Downloading words...")

func _on_start_game_button_pressed() -> void:
	MatchwsG.words.create_words_from_collection()
	menu_start_game.emit()

func _on_new_lang_list_item_selected(index: int) -> void:
	if MatchwsG.words != null:
		var id = %NewLangList.get_item_id(index)
		MatchwsG.words.selected_new_lang_id = id
		if id == MatchwsG.words.selected_known_lang_id:
			var another = MatchwsG.words.get_another_lang(id)
			if another >= 0:
				MatchwsG.words.selected_known_lang_id = another
				%OldLangList.select(max(0,MainGlobals.find_id_in_option_button(%OldLangList, MatchwsG.words.selected_known_lang_id)))
		MatchwsG.words.get_words_per_langs()

func _on_old_lang_list_item_selected(index: int) -> void:
	if MatchwsG.words != null:
		var id = %OldLangList.get_item_id(index)
		MatchwsG.words.selected_known_lang_id = id
		if id == MatchwsG.words.selected_new_lang_id:
			var another = MatchwsG.words.get_another_lang(id)
			if another >= 0:
				MatchwsG.words.selected_new_lang_id = another
				%NewLangList.select(max(0,MainGlobals.find_id_in_option_button(%NewLangList, MatchwsG.words.selected_new_lang_id)))
		MatchwsG.words.get_words_per_langs()

func do_on_got_words() -> void:
	MatchwsG.words.create_words_from_collection()

func do_failed_getting_words() -> void:
	refresh()

func _on_collection_list_item_selected(index: int) -> void:
	if MatchwsG.words != null:
		var id = %CollectionList.get_item_id(index)
		MatchwsG.words.selected_collection_id = id
		MatchwsG.words.create_words_from_collection()

func _on_message_timer_timeout() -> void:
	pass

func message(text : String) -> void:
	$DownloadingMessage.show()
	$DownloadingMessage.disp(text)

func hide_message() -> void:
	$DownloadingMessage.reset()

func _on_stats_button_pressed() -> void:
	MatchwsG.words.get_personal_stats(MatchwsG.words.selected_new_lang_id, 
		MatchwsG.words.selected_known_lang_id, MatchwsG.words.selected_collection_id)

func _on_words_list_button_pressed() -> void:
	var scene = words_list_scene.instantiate()
	add_child(scene)
	scene.create_list()

func _on_add_new_words_button_pressed() -> void:
	sig_show_add_new_words.emit()

func _on_help_button_pressed() -> void:
	MainGlobals.sim_action("help")

func _on_visibility_changed() -> void:
	MainGlobals.set_visible("main_menu",visible)

func _on_reload_words_button_pressed() -> void:
	MatchwsG.words.redownload_all()
	refresh()
