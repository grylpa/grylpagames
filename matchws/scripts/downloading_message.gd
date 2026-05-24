extends CanvasLayer

signal message_timer_timeout

func _ready() -> void:
	show_msg(false)
	$Background.hide()
	$MessagePanel.modulate = Color(0xE0E000FF)

func show_msg(b:bool = true):
	%Message.visible = b
	$MessagePanel.visible = b

func disp(text, autohide=false):
	%Message.text = text
	show_msg(true)
	$Background.show()
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