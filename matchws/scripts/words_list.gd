extends CanvasLayer

var cell_width = 300
var panlabel_scene = preload("res://scenes/grid_panel_label.tscn")
var word_list_row = preload("res://scenes/words_list_row.tscn")

var user_texture = load("res://art/user_white_16.png")
var no_user_texture = load("res://art/option_button_icon_empty_16.png")

func _ready():
	$Window.size = MainGlobals.full_screen_size
	$Window.position = Vector2.ZERO
	$Window.unresizable = true
	$Window.borderless = true
	
func add_line(texts, is_from_user):
	var row = word_list_row.instantiate()
	var texture = row.get_node("HBox/TextureIcon")
	var lpanel = row.get_node("HBox/LPanel")
	var rpanel = row.get_node("HBox/RPanel")
	var llabel = lpanel.get_node("Label")
	var rlabel = rpanel.get_node("Label")
	if is_from_user:
		texture.texture = user_texture
	else:
		texture.texture = no_user_texture
	llabel.text = MainGlobals.cap_first_word(texts[0])
	rlabel.text = MainGlobals.cap_first_word(texts[1])
	lpanel.custom_minimum_size = Vector2(cell_width, 1)
	rpanel.custom_minimum_size = Vector2(cell_width, 1)
	%GridContainer.add_child(row)
	# %GridContainer.call_deferred("add_child", row)

	# region dynamic row creation without a preloaded scene
	# var hbox = HBoxContainer.new()
	# hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# hbox.size_flags_vertical = Control.SIZE_FILL
	# hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# hbox.add_theme_constant_override("separation", 4)

	# for text in texts:
	# 	var panlabel = panlabel_scene.instantiate()
	# 	var label = panlabel.get_node("Label")
	# 	var panel = panlabel#.get_node("Panel")
	# 	label.text = MainGlobals.cap_first_word(text)

	# 	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 	label.custom_minimum_size = Vector2(cell_width, 1)
	# 	label.size_flags_horizontal = Control.SIZE_FILL
	# 	# label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Match height to content
	# 	label.clip_text = false

	# 	# panel.custom_minimum_size = Vector2(cell_width, 0)
	# 	# panel.size_flags_horizontal = Control.SIZE_FILL
	# 	# panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 	hbox.add_child(panlabel)

	# var row = PanelContainer.new()
	# row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# var style = StyleBoxFlat.new()
	# style.bg_color = Color(0, 0, 0, 0.5)
	# # row.set("custom_styles/bg", style)
	# row.add_theme_stylebox_override("panel", style)

	# row.add_child(hbox)
	# %GridContainer.add_child(row)
	# # call_deferred("add_child", row)
	# endregion

func create_list():
	%PreparingMessage.show()
	%PreparingMessage.disp("Preparing word list")
	# var scroll = %ScrollContainer
	var grid = %GridContainer
	for child in grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	var fixed_width = %MarginContainer.get_child(0).get_size().x
	# Log.dbg("fixed width ", fixed_width)
	var columns = 2
	var spacing = 0
	var iconsize = 32
	cell_width = (fixed_width - iconsize - spacing) / columns
	
	var hard_words = MatchwsG.words.hard_words
	var easy_words = MatchwsG.words.easy_words
	var is_user_word = MatchwsG.words.is_user_word
	var N = min(hard_words.size(), easy_words.size())
	var last_update_time = 0
	for i in N:
		if is_user_word[i]:
			var texts = [hard_words[i], easy_words[i]]
			# call_deferred("add_line", texts)
			add_line(texts, is_user_word[i])
			#%PreparingMessage.disp("Preparing word list\n%02d%%" % int(100 * (i+1) / N))
			#%PreparingMessage.disp("Preparing word list\n%02d%%" + str(int(100 * (i+1) / N)) + "%")
			var now = MainGlobals.timems()
			if now - last_update_time > 160 or i == 20:
				last_update_time = now
				%PreparingMessage.set_progress(int(100 * (i+1) / N))
				await get_tree().process_frame

	for i in N:
		if !is_user_word[i]:
			var texts = [hard_words[i], easy_words[i]]
			# call_deferred("add_line", texts)
			add_line(texts, is_user_word[i])
			#%PreparingMessage.disp("Preparing word list\n%02d%%" % int(100 * (i+1) / N))
			#%PreparingMessage.disp("Preparing word list\n%02d%%" + str(int(100 * (i+1) / N)) + "%")
			var now = MainGlobals.timems()
			if now - last_update_time > 160 or i == 20:
				last_update_time = now
				%PreparingMessage.set_progress(int(100 * (i+1) / N))
				await get_tree().process_frame
	%PreparingMessage.hide()


func _on_x_close_scene_button_pressed() -> void:
	queue_free()
	# hide()
