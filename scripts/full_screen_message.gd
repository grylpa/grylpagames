extends CanvasLayer

signal message_timer_timeout
signal message_pressed

func _ready() -> void:
	# %Message.modulate = Color(0xddbf00)
	$MessagePanel.modulate = Color(0xE0E000FF)
	show_msg(false)
	$Background.hide()

func show_msg(b:bool = true):
	%Message.visible = b
	$MessagePanel.visible = b

func use_opaque_bk(b: bool = true):
	$OpaqueBackground.visible = b
	
func disp(text, autohide=false, timeout_ms: int = 2000):
	%Message.text = text
	show_msg(true)
	$Background.show()
	if autohide:
		%MessageTimer.wait_time = max(0.1, timeout_ms / 1000.0)
		%MessageTimer.start()

func reset():
	show_msg(false)
	$Background.hide()

func _on_message_timer_timeout() -> void:
	show_msg(false)
	$Background.hide()
	message_timer_timeout.emit()

func set_opaque_modulation(m: Color):
	$OpaqueBackground.modulate = m

func set_opaque_color(_c: Color):
	#$OpaqueBackground.color = c
	#$OpaqueBackground.modulate = Color(0.9,0.9,0.9)
	pass

func set_transparent_color(c: Color):
	$Background.color = c


func _on_message_pressed() -> void:
	message_pressed.emit()
