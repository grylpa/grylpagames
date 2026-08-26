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
	ls.font = MainGlobals.get_text_font()
	ls.font_size = text_size
	# 0, not the -30 this used to carry. That was clawing back an inflated line box: the shared
	# OpenSans FontFile had the very tall Noto Symbols fallbacks attached to it (a Font's line
	# height is the MAX over its fallbacks), so a description line cost 2.09x the font size and had
	# to be pulled back by hand. With the face clean, -30 collapses the lines into each other.
	ls.line_spacing = 0
	%Text.label_settings = ls