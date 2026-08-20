extends CanvasLayer

signal start_game

var gameover_audio := preload("res://art/sounds/gameover-1.mp3")
var game:GenericGameUtil

var _last_countdown_time := 0
var _time_for_countdown := 0
var _countdown_value := 0
var game_already_over := false
var message_transparent_bg: bool = false

func _ready() -> void:
	$Message.hide()
	$StartButton.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$LivesContainer.hide()
	$PacketsContainer.hide()
	$CountdownLabel.hide()
	$CorrectsMistakesContainer.hide()
	# On mobile the bottom button bar is taller, so lift the "Restart Game" button
	# higher (its margin_bottom = 60 in the scene overlaps the bar). grow_vertical is
	# BEGIN, so the container just grows upward to fit — no other offsets needed.
	if MainGlobals.is_mobile():
		$StartButton.add_theme_constant_override("margin_bottom", 115)
	# $TimeLeftLabel.hide()
	update_all()
	$Panel.hide()
	%LevelLabel.hide()
	$GameOverAudio.stream = gameover_audio
	MainGlobals.sig_global_update_hud.connect(_on_update_hud)
	MainGlobals.sig_global_start_countdown.connect(_on_sig_global_start_countdown)

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

func hide_message() -> void:
	$Message.hide()

func disp(text, autohide=false):
	$Message.text = text
	$Message.show()
	if autohide:
		$MessageTimer.start()

func reminder(text, autohide=true):
	if $Dispatch.visible:
		return false
	if text is Array:
		$Reminder.bbcode_enabled = true
		$Reminder.clear()
		for line in text:
			var hex_color = line[1].to_html()
			$Reminder.append_text("[color=%s]%s[/color]\n" % [hex_color, line[0]])
	else:
		$Reminder.text = text
	$Reminder.visible = !$Reminder.visible
	if autohide and $Reminder.visible:
		$ReminderTimer.start()
	return $Reminder.visible		
		
# `col` tints the line in the color of whatever it is about — the truck a delivery list belongs
# to, for instance. Games with several actors on screen at once need it to say WHICH one the order
# is for; the clue list has always done this (see reminder()), and the dispatch line reading a
# fixed yellow made the two disagree. Omit it and the line keeps the theme color, as before.
var _dispatch_default_col = null

func dispatch(text, autohide=true, col=null):
	if _dispatch_default_col == null:
		_dispatch_default_col = $Dispatch.get_theme_color("font_color")
	$Reminder.visible = false
	$Dispatch.text = text
	$Dispatch.add_theme_color_override("font_color", col if col != null else _dispatch_default_col)
	$Dispatch.show()
	if autohide:
		$DispatchTimer.start()		
	
func reset():
	$Message.hide()
	$Reminder.hide()
	$Dispatch.hide()
	$StartButton.hide()
	$Panel.hide()
	$CountdownLabel.hide()	
	game_already_over = false
	# $LivesContainer.hide()

func new_game(from_scratch = true):
	reset()
	if from_scratch:
		game.score = 0
		game.reset_time_left()
		game.reset_lives()
		update_all()
	
func game_over(_didwin: bool, _wasaborted: bool):
	if game_already_over:
		return
	game_already_over = true
	MainGlobals.kill_active_tweens()
	$Panel.show()
	$GameOverAudio.play()
	if _didwin:
		disp("You Finished!")
		# disp("You Finished!\n\nScore: " + $Score.text)
	else:
		disp("Game Over")
		# disp("Game Over\nScore: " + $Score.text)

	$Message.pivot_offset = $Message.size / 2
	var tween_scale = MainGlobals.make_tween()
	tween_scale.tween_property($Message, "scale", Vector2(1.5,1.5), 0.3)
	tween_scale.tween_property($Message, "scale", Vector2(1.0,1.0), 0.3)
	await MainGlobals.sleep(1)
	$StartButton.show()
	
func set_game(_game):
	game = _game
	game.sig_game_is_done.connect(on_game_is_done)
	game.sig_level_label_changed.connect(show_level_label)
	update_all()
	
func on_game_is_done(_didwin: bool, _wasaborted: bool):
	game_over(_didwin,_wasaborted)

func update_score():
	if game == null:
		$Score.text = "0"
		$TimeLeftLabel.text = "00:00:00"
		return
	$Score.text = str(game.score)
	$TimeLeftLabel.text = game.time_left_str()
	
func _on_message_timer_timeout() -> void:
	$Message.hide()

func _on_start_button_pressed() -> void:
	$StartButton.hide()
	$Message.hide()
	start_game.emit()

func _on_reminder_timer_timeout() -> void:
	$Reminder.hide()

func _on_dispatch_timer_timeout() -> void:
	$Dispatch.hide()

func check_time_run_out():
	if game.did_time_run_out():
		if game.game_over_on_time_out:
			game.playing = false
			$TimeLeftTimer.stop()
			game.sig_time_over.emit()
			game_over(false, false)
		else:
			game.sig_time_over.emit()

func add_score_and_time(add_score: int, add_time: int, is_actual_score:bool = true):
	game.add_score_and_time(add_score, add_time, is_actual_score)
	update_all()
	check_time_run_out()

func restart_time_left_timer():
	# Re-baseline the countdown to the freshly-reset game clock. game.reset() sets
	# game_time back to ~0 each level, but _last_time_left_timer_tick otherwise keeps
	# a stale (larger) value from the menu / previous level, which freezes the
	# countdown until game_time climbs back up to it.
	if game:
		_last_time_left_timer_tick = game.game_time
	$TimeLeftTimer.autostart = true
	$TimeLeftTimer.start()

var _last_time_left_timer_tick := 0.0
func _on_time_left_timer_timeout() -> void:
	var now = game.game_time
	if now - _last_time_left_timer_tick >= 1000:
		_last_time_left_timer_tick = now
		if game.playing and not game.paused():
			add_score_and_time(0,-1, false)

func delivered_one():
	game.delivered_one()
	update_all()
	check_time_run_out()

func collided():
	game.collided()
	check_time_run_out()
	check_killed_and_lives_run_out()
	update_all()

func update_lives():
	if game and game.count_lives:
		%LivesLabel.text = str(game.lives_left)

func check_killed_and_lives_run_out():
	if game.kill_and_did_lives_run_out():
		game.playing = false
		$TimeLeftTimer.stop()
		game.sig_lives_depleted.emit()
		game_over(false, false)

func show_lives():
	$LivesContainer.show()

func show_corrects_mistakes():
	$CorrectsMistakesContainer.show()

func add_life():
	game.lives_left += 1
	update_lives()

func show_packets():
	$PacketsContainer.show()

func dec_packet():
	game.dec_packet()

func update_packets():
	if game:
		%PacketsLabel.text = str(game.packets_left)

func update_all():
	update_packets()
	update_lives()
	update_score()
	update_corrects_mistakes()

func _on_update_hud():
	update_all()

func start_countdown(time_sec: int):
	if time_sec < 0:
		_countdown_value = 0
		$CountdownLabel.hide()
		$CountdownLabel.text = ""
		return
	$CountdownLabel.show()
	_time_for_countdown = time_sec
	_countdown_value = time_sec
	_last_countdown_time = MainGlobals.timems()
	update_countdown()
	$CountdownTimer.start()

func _on_countdown_timer_timeout() -> void:
	if game and game.paused():
		return
	var now = MainGlobals.timems()
	if now - _last_countdown_time >= 1000:
		_countdown_value = max(0, _countdown_value - 1)
		if _countdown_value == 0:
			$CountdownLabel.hide()
			$CountdownTimer.stop()
			MainGlobals.global_countdown_finished()
		else:
			_last_countdown_time = now
			update_countdown()

func update_countdown():
	$CountdownLabel.text = str(_countdown_value)
	# $CountdownLabel.pivot_offset = $CountdownLabel.size / 2
	var tween_scale = MainGlobals.make_tween()
	var sf := 1.1
	tween_scale.tween_property($CountdownLabel, "scale", Vector2(sf,sf), 0.2)
	tween_scale.tween_property($CountdownLabel, "scale", Vector2(1.0,1.0), 0.05)

func _on_sig_global_start_countdown(start_from):
	start_countdown(start_from)

func set_lives_icon(_texture, _scale:Vector2 = Vector2(1,1), _modulate = null):
	%LivesIcon.texture = _texture
	var tex_size = %LivesIcon.texture.get_size()
	var new_sz = tex_size * _scale
	%LivesIcon.set_size(new_sz)
	%LivesIcon.custom_minimum_size = new_sz
	# %LivesIcon.texture.scale = Vector2(_scale,_scale)
	if _modulate:
		%LivesIcon.modulate = _modulate


func set_packets_icon(_texture, _scale := 1.0):
	%PacketsIcon.texture = _texture
	var tex_size = %PacketsIcon.texture.get_size()
	%PacketsIcon.custom_minimum_size = tex_size * _scale

func update_corrects_mistakes():
	if game == null:
		%CorrectsLabel.text = "0"
		%MistakesLabel.text = "0"
		return
	%CorrectsLabel.text = str(game.corrects)
	%MistakesLabel.text = str(game.mistakes)

func show_level_label(level_name: String):
	%LevelLabel.text = level_name
	%LevelLabel.show()
