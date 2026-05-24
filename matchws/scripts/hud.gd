extends CanvasLayer

signal start_game(was_success: bool)
signal help_button_pressed

var was_success := false

func _ready() -> void:
	$Message.hide()
	$StartButton.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$TimePassedLabel.hide()
	update_score(0)

func hide_message():
	$Message.hide()

func disp(text, autohide=false):
	$Message.text = text
	$Message.show()
	if autohide:
		$MessageTimer.start()
	else:
		$MessageTimer.stop()

func reminder(text, autohide=true):
	if $Dispatch.visible:
		return false
	$Reminder.text = text
	$Reminder.visible = !$Reminder.visible
	if autohide and $Reminder.visible:
		$ReminderTimer.start()
	return $Reminder.visible
		
func hide_dispatch():
	$Dispatch.hide()

func dispatch(text, autohide=true):
	$Reminder.visible = false
	$Dispatch.text = text
	$Dispatch.show()
	if autohide:
		$DispatchTimer.start()		
	
func reset():
	$Message.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$StartButton.hide()

func new_game():
	reset()
	
func game_over(didwin: bool):
	if didwin:
		was_success = true
		$StartButton/StartButtonCtrl.text = "Continue"
		disp("Level is done!\nScore: " + $Score.text)
	else:
		was_success = false
		$StartButton/StartButtonCtrl.text = "Retry"
		disp("Failed level\nScore: " + $Score.text)
	await MainGlobals.sleep(1)
	$StartButton.show()
	
func update_time(time_str):
	$TimePassedLabel.text = time_str
	$TimePassedLabel.visible = !MatchwsG.moving

func update_score(score):
	$Score.text = str(score)
	
func _on_message_timer_timeout() -> void:
	$Message.hide()

func _on_start_button_pressed() -> void:
	$StartButton.hide()
	$Message.hide()
	start_game.emit(was_success)

func _on_reminder_timer_timeout() -> void:
	$Reminder.hide()

func _on_dispatch_timer_timeout() -> void:
	$Dispatch.hide()

func _on_help_button_pressed() -> void:
	help_button_pressed.emit()
