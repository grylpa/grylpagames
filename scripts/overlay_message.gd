extends CanvasLayer

signal message_timer_timeout

func _ready() -> void:
	show_msg(false)
	$Background.hide()
	_apply_app_look()

# This panel used to be a saturated yellow MODULATE (0xE0E000) multiplied over a ColorRect that had
# no colour set at all — so the default white came through it as a slab of neon, which is what
# "no scores saved yet" looked like against an otherwise dark app.
#
# It now uses the same card as every other panel: ResultCard's dark ground and light text, with the
# zig frame on top keeping the shape it always had.
func _apply_app_look() -> void:
	$MessagePanel.modulate = Color(1, 1, 1, 1)
	var rect: ColorRect = $MessagePanel/ColorRect
	if rect != null:
		rect.color = ResultCard.CARD_BG
	for lbl: Node in _labels_in($MessagePanel):
		lbl.add_theme_color_override("font_color", ResultCard.TEXT)
		# THE LABEL PAINTS ITS OWN BACKGROUND. The scene gives Message a `normal` stylebox with
		# bg_color white, so it drew a white slab over the dark ground behind it — which is the card
		# that stayed stubbornly white through two earlier attempts at this, because both of them
		# were fixing the ColorRect underneath it.
		#
		# Cleared to transparent rather than removed: the stylebox also carries the 16px top and
		# bottom margins that give the message its height, and dropping it would collapse the card.
		var keep: StyleBoxFlat = StyleBoxFlat.new()
		keep.bg_color = Color(0, 0, 0, 0)
		keep.content_margin_top = 16.0
		keep.content_margin_bottom = 16.0
		lbl.add_theme_stylebox_override("normal", keep)
	# The progress bar shown while a long list loads was a saturated green from the scene — the last
	# bright surface in here, and no relation to anything else in the app. Gold on the same dark
	# ground as the card.
	var bar: ProgressBar = $MessagePanel/MarginContainer/VBoxContainer/ProgressMarginContainer/ProgressPanelContainer/ProgressBar
	if bar != null:
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = ScreenBackdrop.ACCENT
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_color_override("font_color", ResultCard.HEADER_INK)

func _labels_in(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels_in(c))
	return out

func show_msg(b:bool = true):
	%Message.visible = b
	$MessagePanel.visible = b

func disp(text, autohide=false):
	%Message.text = text
	show_msg(true)
	# $Background.show()
	if autohide:
		$MessageTimer.start()

func reset():
	show_msg(false)
	$Background.hide()

func _on_message_timer_timeout() -> void:
	show_msg(false)
	$Background.hide()
	message_timer_timeout.emit()

func set_progress(v: int):
	%ProgressMarginContainer.show()
	%ProgressBar.value = v