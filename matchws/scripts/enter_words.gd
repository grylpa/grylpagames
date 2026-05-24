extends CanvasLayer


func _ready() -> void:
	var default_font: Font = MainGlobals.get_system_sans_font()
	for field in [%CollectionLineEdit, %GroupLineEdit, %Lang1LineEdit, %Lang2LineEdit, %NewWords]:
		field.add_theme_font_override("font", default_font)

func start():
	if not MainGlobals.is_mobile():
		%NewWords.grab_focus()
	fill()
	show()

func fill():
	if MatchwsG.words.has_got_words():
		%Lang1List.clear()
		%Lang2List.clear()
		for langid in MatchwsG.words.languages:
			var lang_name = MatchwsG.words.languages[langid]
			%Lang1List.add_item(lang_name, langid)
			%Lang2List.add_item(lang_name, langid)
		%Lang1List.add_item("New group", -1000)
		%Lang2List.add_item("New group", -1000)
		%Lang1List.select(max(0,MainGlobals.find_id_in_option_button(%Lang1List, MatchwsG.words.selected_new_lang_id)))
		%Lang2List.select(max(0,MainGlobals.find_id_in_option_button(%Lang2List, MatchwsG.words.selected_known_lang_id)))

		# %CollectionList.clear()
		# for collection in MatchwsG.words.collections:
		# 	var collection_id = int(collection.get("collection_id", -1))
		# 	var collection_name = collection.get("collection_name", "unknown").capitalize()# .replace("_", " ")
		# 	var user_id = collection.get("user_id", "")
		# 	if typeof(user_id) != TYPE_NIL and typeof(user_id) == TYPE_STRING and user_id.length() > 0:
		# 		%CollectionList.add_item(collection_name, collection_id)
		# %CollectionList.add_item("New collection", -1000)
		# %CollectionList.select(0);

		%GroupList.clear()
		for group in MatchwsG.words.groups:
			var group_id = int(group.get("group_id", -1))
			var group_name = group.get("group_name", "unknown")#.capitalize()# .replace("_", " ")
			var user_id = group.get("user_id", "")
			if typeof(user_id) != TYPE_NIL and typeof(user_id) == TYPE_STRING and user_id.length() > 0:
				%GroupList.add_item(group_name, group_id)
		%GroupList.add_item("New group", -1000)
		%GroupList.select(0);

func _on_cancel_button_pressed() -> void:
	hide()

func _show_cannot_dialog(reason: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Cannot add new words" 
	dialog.dialog_text = reason
	dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	dialog.confirmed.connect(Callable(dialog, "queue_free"))
	dialog.close_requested.connect(Callable(dialog, "queue_free"))
	add_child(dialog)	
	dialog.popup_centered() # center on screen
	# dialog.show()

func _on_save_words_button_pressed() -> void:
	var group_id = %GroupList.get_selected_id()

	var group_name:String
	if group_id == -1000:
		group_name = %GroupLineEdit.text
	else:
		group_name = %GroupList.get_item_text(%GroupList.selected)

	var lang1id = %Lang1List.get_selected_id()
	var lang2id = %Lang2List.get_selected_id()

	var lang1name = %Lang1List.get_item_text(%Lang1List.selected)
	var lang2name = %Lang2List.get_item_text(%Lang2List.selected)

	if lang1id == -1000:
		lang1name = %Lang1LineEdit.text
	if lang2id == -1000:
		lang2name = %Lang2LineEdit.text
	
	var text:String = %NewWords.text.strip_edges()
	if text.length() == 0:
		_show_cannot_dialog("No words were entered into the words box")		
	else:
		var lines = text.split("\n")
		var all_ok = true
		var unique_lines = {}
		for line in lines:
			var seline = line.strip_edges()
			if !seline.is_empty():
				var first_comma = seline.find(",")
				if first_comma <= 0 or first_comma >= seline.length() - 1:
					all_ok = false
					break
				var w1 = seline.substr(0, first_comma).strip_edges()
				var w2 = seline.substr(first_comma+1).strip_edges()
				var w1w2 = w1 + "," + w2
				unique_lines[w1w2] = null
		if !all_ok:
			_show_cannot_dialog("Each line should be two words separated with a comma")
			return

		var non_unique_str = ""
		if unique_lines.size() < lines.size():
			non_unique_str = "\n\nThere were %d lines that were not unique" % [lines.size() - unique_lines.size()]
		var dialog = ConfirmationDialog.new() 
		dialog.title = "Add new words" 
		dialog.dialog_text = "Do you want to add\n\n%d words\nlanguages: %s,%s\ngroup: %s\n\n?%s\n" % \
			[unique_lines.size(), lang1name, lang2name, group_name, non_unique_str]
		# dialog.get_child(1, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
		dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		dialog.canceled.connect(Callable(dialog, "queue_free"))
		dialog.confirmed.connect(save_dialog_confirmed.bind(dialog))
		dialog.get_ok_button().text = "Yes"
			
		add_child(dialog)	
		dialog.popup_centered() # center on screen
		# dialog.show()
		
func save_dialog_confirmed(dialog:ConfirmationDialog):
	message("Sending words to server")
	dialog.queue_free()
	var group_id = %GroupList.get_selected_id()

	var group_name:String
	if group_id == -1000:
		group_name = %GroupLineEdit.text
	else:
		group_name = %GroupList.get_item_text(%GroupList.selected)

	var lang1id = %Lang1List.get_selected_id()
	var lang2id = %Lang2List.get_selected_id()

	var lang1name = %Lang1List.get_item_text(%Lang1List.selected)
	var lang2name = %Lang2List.get_item_text(%Lang2List.selected)

	if lang1id == -1000:
		lang1name = %Lang1LineEdit.text
	if lang2id == -1000:
		lang2name = %Lang2LineEdit.text

	var languages = [{"id": lang1id, "name": lang1name}, {"id": lang2id, "name": lang2name}]
	
	var text = %NewWords.text
	var lines = text.split("\n")

	var all_words_array: Array = []
	var unique_lines = {}
	for line in lines:
		var seline = line.strip_edges()
		if !seline.is_empty():
			var first_comma = seline.find(",")
			if first_comma > 0 and first_comma < seline.length() - 1:
				var w1 = seline.substr(0, first_comma).strip_edges()
				var w2 = seline.substr(first_comma+1).strip_edges()
				var w1w2 = w1 + "," + w2
				if !unique_lines.has(w1w2):
					unique_lines[w1w2] = null
					all_words_array.append([w1, w2])

	# var callback = Callable(self, "_on_sent_new_words")
	# BE.send_rpc_data("add_words_for_user", {'data': all_words_array}, "p_payload", callback)

	var callback = Callable(self, "_on_added_words_for_group")
	BE.send_rpc_data("add_words_for_group", 
		{'data': all_words_array, 'group_name': group_name, "languages": languages}, "p_payload", callback)

func _on_sent_new_words(data):
	if data is int:
		Log.dbg("got response for sending of new words: ", data)
	else:
		Log.dbg("got response for sending of new words, but not an int")

func _on_added_words_for_group(data):
	Log.dbg("got result for add_words_for_group: ", data)
	if typeof(data) == TYPE_DICTIONARY and data.has("status"):
		var status = data["status"]
		if typeof(status) == TYPE_STRING and status.nocasecmp_to("success") == 0:
			MatchwsG.words.request_global_data()
			MatchwsG.words.get_words_per_langs()
			message("Finished sending words")
			return
	message("Words were not sent to server\nTry again later")

func _on_visibility_changed() -> void:
	MainGlobals.ignore_keyboard_actions = visible# is_visible_in_tree()

func _on_new_words_focus_entered() -> void:
	MainGlobals.ignore_keyboard_actions = visible


func _on_x_close_scene_button_pressed() -> void:
	hide()

func message(text : String) -> void:
	$FullScreenMessage.show()
	$FullScreenMessage.disp(text, true)

func hide_message() -> void:
	$FullScreenMessage.reset()
