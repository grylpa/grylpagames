extends Button

func set_text_val(_text):
	%Text.text = _text

func set_title_val(_title):
	%Title.text = _title

func set_vals(_title, _text):
	set_title_val(_title)
	set_text_val(_text)

func set_font_sizes(title_size: int, text_size: int) -> void:
	%Title.add_theme_font_size_override("font_size", title_size)
	var ls: LabelSettings = LabelSettings.new()
	ls.font = load("res://art/fonts/OpenSans-SemiBold.ttf")
	ls.font_size = text_size
	ls.line_spacing = -30
	%Text.label_settings = ls