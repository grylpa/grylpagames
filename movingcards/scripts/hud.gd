extends CanvasLayer

signal help_button_pressed

var message_transparent_bg: bool = false

func set_message_transparent_bg(value: bool) -> void:
	message_transparent_bg = value
	var style: StyleBoxFlat = $Message.get_theme_stylebox("normal") as StyleBoxFlat
	if style:
		var a: float = 0.0 if value else 1.0
		var c: Color = style.bg_color
		c.a = a
		style.bg_color = c
		var bc: Color = style.border_color
		bc.a = a
		style.border_color = bc

func _ready() -> void:
	$Message.hide()
	$StartButton.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$TimeLeftLabel.hide()
	$Message.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	update_score(0, 0)

func hide_message() -> void:
	$Message.hide()

func disp(text: String, autohide: bool = false) -> void:
	$Message.text = text
	$Message.show()
	if autohide:
		$MessageTimer.start()
	else:
		$MessageTimer.stop()

func reminder(text: String, autohide: bool = true) -> bool:
	if $Dispatch.visible:
		return false
	$Reminder.text = text
	$Reminder.visible = !$Reminder.visible
	if autohide and $Reminder.visible:
		$ReminderTimer.start()
	return $Reminder.visible

func hide_dispatch() -> void:
	$Dispatch.hide()

func dispatch(text: String, autohide: bool = true) -> void:
	$Reminder.visible = false
	$Dispatch.text = text
	$Dispatch.show()
	if autohide:
		$DispatchTimer.start()

func reset() -> void:
	$Message.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$StartButton.hide()

func new_game() -> void:
	reset()

# Rounds auto-cycle — just show a brief message, no button needed.
func game_over(didwin: bool) -> void:
	if didwin:
		disp("Level Up!\nScore: " + $Score.text, true)

func update_score(score: int, time_left: int) -> void:
	$Score.text = str(score)
	$TimeLeftLabel.text = str(time_left)

func _on_message_timer_timeout() -> void:
	$Message.hide()

func _on_reminder_timer_timeout() -> void:
	$Reminder.hide()

func _on_dispatch_timer_timeout() -> void:
	$Dispatch.hide()

func _on_help_button_pressed() -> void:
	help_button_pressed.emit()
