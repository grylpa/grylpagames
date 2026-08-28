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
	_sync_top_strip()
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
	_sync_top_strip()
	if autohide:
		$DispatchTimer.start()		
	
func reset():
	$Message.hide()
	$Reminder.hide()
	$Dispatch.hide()
	_sync_top_strip()
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
	$Panel.add_theme_stylebox_override("panel", _scrim_style())
	$Panel.show()
	$GameOverAudio.play()
	_style_banner(_didwin)
	_style_restart_button(_didwin)
	if _didwin:
		disp("You Finished!")
	else:
		disp("Game Over")

	# A banner does not just appear: it drops in, overshoots, and settles. Same two tweens as
	# before, but starting from squashed and off-center so it reads as landing rather than growing.
	$Message.pivot_offset = $Message.size / 2
	$Message.scale = Vector2(0.4, 0.4)
	$Message.rotation = deg_to_rad(-7.0 if _didwin else 4.0)
	var tween_scale = MainGlobals.make_tween()
	tween_scale.tween_property($Message, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_scale.parallel().tween_property($Message, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_scale.tween_property($Message, "scale", Vector2(1.0, 1.0), 0.16)
	await MainGlobals.sleep(1)
	$StartButton.show()
	# and the button arrives after it, rising into place
	var btn: Control = $StartButton
	btn.modulate.a = 0.0
	btn.scale = Vector2.ONE
	btn.pivot_offset = btn.size * 0.5
	# One heartbeat at a time. Game over -> restart -> game over would otherwise leave the previous
	# loop running on the same button, and two tweens driving one scale fight each other.
	if _beat != null and _beat.is_valid():
		_beat.kill()
	var rise: Tween = MainGlobals.make_tween()
	rise.tween_property(btn, "modulate:a", 1.0, 0.22)
	rise.parallel().tween_property(btn, "position:y", btn.position.y, 0.28).from(btn.position.y + 26.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# ...and then keeps breathing. A button that is the only thing left to do should look like it
	# wants pressing, not sit there being available.
	# btn.create_tween(), NOT MainGlobals.make_tween(): that one is parented to the scene root, and
	# an endless loop tween made there outlives the HUD it animates. Bound to the button, it dies
	# with it.
	_beat = btn.create_tween()
	_beat.set_loops()
	_beat.tween_property(btn, "scale", Vector2(1.045, 1.045), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_beat.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- the game-over look ---------------------------------------------------------------------
# This screen used to be a cyan pill with a 4px black border and a default-themed "Restart Game"
# button — the two most-seen controls in the app, and the two least designed. Colors are the app's
# (ResultCard), so it belongs to the same product, but the shapes are heavier: a banner that lands
# and a chunky button with a lip, which is what a game does at the end of a run.

const _WIN_BG: Color = Color(0.976, 0.792, 0.353)      # ResultCard.ACCENT
const _WIN_INK: Color = Color(0.153, 0.118, 0.043)
const _LOSE_BG: Color = Color(0.780, 0.271, 0.243)
const _LOSE_INK: Color = Color(1.0, 0.949, 0.910)

func _scrim_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.043, 0.071, 0.82)
	return sb

# The banner is DRAWN, not a styled rectangle. A rounded box with a 5px rim on three sides and a
# 9px one underneath reads as a rendering mistake — an asymmetric border only says "lip" when the
# rest of the shape supports it. A ribbon does: a body with folded tails behind it, one light
# source, and a burst of rays behind the whole thing turning slowly.
#
# It is a CHILD of the message label with show_behind_parent, so it inherits the label's rect and
# the drop-in tween — the rays and the ribbon land with the text instead of being animated
# separately and drifting out of step.
var _banner_fx: Control = null
var _fx_t: float = 0.0
var _beat: Tween = null

func _style_banner(didwin: bool) -> void:
	var bg: Color = _WIN_BG if didwin else _LOSE_BG
	var ink: Color = _WIN_INK if didwin else _LOSE_INK
	# The label paints text only; everything behind it is the drawn ribbon.
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 54.0
	sb.content_margin_right = 54.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 22.0
	$Message.add_theme_stylebox_override("normal", sb)
	$Message.add_theme_color_override("font_color", ink)
	# An outline separates the letters from what is behind them, so it has to contrast with the
	# INK. "Game Over" is cream on crimson and a dark outline sharpens it; "You Finished!" is dark
	# ink on gold, and the same dark outline merged into the letters and turned them to mud. Dark
	# ink takes a LIGHT outline — the same rule as mother's goal labels.
	$Message.add_theme_color_override("font_outline_color",
		bg.lightened(0.72) if didwin else bg.darkened(0.62))
	$Message.add_theme_constant_override("outline_size", 6 if didwin else 10)
	$Message.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size($Message, 46)

	# Restart the show, so the first burst opens just after the banner lands rather than wherever
	# the clock happened to be from a previous game.
	_fx_t = 0.0
	if _banner_fx == null or not is_instance_valid(_banner_fx):
		_banner_fx = Control.new()
		_banner_fx.show_behind_parent = true
		_banner_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		$Message.add_child(_banner_fx)
	var fx: Control = _banner_fx
	for c in fx.draw.get_connections():
		fx.draw.disconnect(c["callable"])
	fx.draw.connect(func() -> void: _draw_banner(fx, bg, didwin))
	set_process(true)

func _process(delta: float) -> void:
	if _banner_fx != null and is_instance_valid(_banner_fx) and _banner_fx.is_visible_in_tree():
		_fx_t += delta
		_banner_fx.queue_redraw()

func _draw_banner(fx: Control, bg: Color, didwin: bool) -> void:
	var w: float = fx.size.x
	var h: float = fx.size.y
	if w < 4.0 or h < 4.0:
		return
	var mid: Vector2 = Vector2(w, h) * 0.5

	# Behind the ribbon: fireworks for a win, drifting ash for a loss. NOT a rotating starburst —
	# a wheel turning under fixed text is the one motion the eye cannot ignore or adapt to, and it
	# goes from festive to a headache in about ten seconds. Both of these settle instead: a burst
	# rises, fades and is gone, and the next one is somewhere else.
	if didwin:
		_draw_fireworks(fx, mid, w, h, bg)
	else:
		_draw_ash(fx, w, h, bg)

	# Folded tails, behind and darker, poking out both sides with a notch cut into the end.
	var tail_w: float = 40.0
	var tail_col: Color = bg.darkened(0.42)
	var ty: float = h * 0.22
	var tb: float = h * 0.78
	fx.draw_colored_polygon(PackedVector2Array([
		Vector2(-tail_w, ty + 10.0), Vector2(18.0, ty), Vector2(18.0, tb),
		Vector2(-tail_w, tb - 10.0), Vector2(-tail_w + 16.0, (ty + tb) * 0.5)]), tail_col)
	fx.draw_colored_polygon(PackedVector2Array([
		Vector2(w + tail_w, ty + 10.0), Vector2(w - 18.0, ty), Vector2(w - 18.0, tb),
		Vector2(w + tail_w, tb - 10.0), Vector2(w + tail_w - 16.0, (ty + tb) * 0.5)]), tail_col)

	# Body: one shadow, one gradient, one sheen, one dark base. Every edge the same weight.
	var body: Rect2 = Rect2(0.0, 0.0, w, h)
	fx.draw_rect(Rect2(body.position + Vector2(0.0, 10.0), body.size), Color(0, 0, 0, 0.45), true)
	fx.draw_rect(Rect2(body.position + Vector2(0.0, h - 12.0), Vector2(w, 12.0)), bg.darkened(0.45), true)
	fx.draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h - 10.0), Vector2(0.0, h - 10.0)]),
		PackedColorArray([bg.lightened(0.18), bg.lightened(0.18), bg.darkened(0.12), bg.darkened(0.12)]))
	fx.draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h * 0.34), Vector2(0.0, h * 0.34)]),
		PackedColorArray([Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# stitch line, the detail that says "ribbon" rather than "rectangle"
	var dash: float = 14.0
	var x: float = 12.0
	while x < w - 12.0:
		fx.draw_line(Vector2(x, 8.0), Vector2(x + dash * 0.55, 8.0), Color(1, 1, 1, 0.30), 2.0)
		fx.draw_line(Vector2(x, h - 18.0), Vector2(x + dash * 0.55, h - 18.0), Color(0, 0, 0, 0.22), 2.0)
		x += dash

# Deterministic 0..1 from an integer, so every spark can be recomputed from the clock instead of
# stored. No particle lives anywhere.
static func _rnd(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)

# THREE small bursts per cycle, each about a second, then a pause. Modest is the point: a shell
# goes up, opens, falls and is gone. Nothing loops in place.
const _FW_CYCLE: float = 3.4
const _FW_LIFE: float = 1.15
const _FW_SPARKS: int = 13

func _draw_fireworks(fx: Control, mid: Vector2, w: float, h: float, bg: Color) -> void:
	var tints: Array = [bg.lightened(0.30), Color(1.0, 0.98, 0.92), bg.lightened(0.05)]
	for b in 3:
		var seed_i: int = b * 7 + 1
		var start: float = float(b) * 0.62
		var t: float = fposmod(_fx_t - start, _FW_CYCLE)
		if t > _FW_LIFE:
			continue
		# a different spot each cycle, spread around the banner rather than on top of the text
		var cycle: int = int((_fx_t - start) / _FW_CYCLE)
		var origin: Vector2 = mid + Vector2(
			(_rnd(seed_i + cycle * 31) - 0.5) * w * 1.5,
			(_rnd(seed_i + cycle * 57) - 0.5) * h * 1.9 - h * 0.35)
		var fade: float = clampf(1.0 - t / _FW_LIFE, 0.0, 1.0)
		var col: Color = tints[b % tints.size()]
		# the flash at the moment it opens
		if t < 0.10:
			fx.draw_circle(origin, 9.0 * (1.0 - t / 0.10), Color(1, 1, 1, 0.5))
		for s in _FW_SPARKS:
			var a: float = TAU * float(s) / float(_FW_SPARKS) + _rnd(seed_i + s) * 0.5
			var speed: float = 95.0 + _rnd(seed_i * 13 + s) * 65.0
			var p: Vector2 = origin + Vector2(cos(a), sin(a)) * speed * t
			p.y += 150.0 * t * t          # they fall
			var r: float = 3.4 * fade
			if r < 0.4:
				continue
			fx.draw_circle(p, r, Color(col.r, col.g, col.b, fade * fade * 0.9))
			# a short trail back toward where it came from
			fx.draw_line(p, p - Vector2(cos(a), sin(a)) * speed * t * 0.16,
				Color(col.r, col.g, col.b, fade * 0.28), 2.0)

# A loss gets EMBERS, not fanfare — the fire is out and what is left is drifting down. The first
# version was a dozen flecks in the banner's own crimson at 0.1 alpha, which on a near-black scrim
# is invisible: it has to be seen to be a mood. These are bigger, hotter, twice as many, each with
# a soft glow behind it, and they breathe as they cool.
#
# Still calm: everything falls slowly in one direction and nothing spins.
const _EMBERS: int = 18

# One ember at a moment in time, so the drawing and the checks agree on where it is.
# Returns [position, radius, alpha, heat] — heat 0 is a cooled fleck, 1 is a live coal.
func _ember(i: int, t: float, w: float, h: float) -> Array:
	var seed_i: int = i * 5 + 3
	# Near embers are bigger, brighter and faster; far ones hang back. One number drives all three,
	# which is what makes it read as depth instead of noise.
	var near: float = _rnd(seed_i * 23)
	var span: float = h * 3.4
	var speed: float = 26.0 + near * 44.0
	var y: float = fposmod(_rnd(seed_i * 3) * span + t * speed, span) - h * 1.2
	var sway: float = sin(t * (0.5 + _rnd(seed_i * 7) * 0.5) + float(i)) * (10.0 + near * 16.0)
	var x: float = (_rnd(seed_i * 11) - 0.5) * w * 2.0 + w * 0.5 + sway
	var flicker: float = 0.82 + 0.18 * sin(t * (1.8 + _rnd(seed_i * 29) * 2.0) + float(i) * 1.7)
	var radius: float = 2.0 + near * 2.2
	var alpha: float = (0.17 + near * 0.25) * flicker
	return [Vector2(x, y), radius, alpha, near * flicker]

func _draw_ash(fx: Control, w: float, h: float, bg: Color) -> void:
	var hot: Color = Color(1.0, 0.612, 0.263)
	var cool: Color = bg.lightened(0.10)
	for i in _EMBERS:
		var e: Array = _ember(i, _fx_t, w, h)
		var pos: Vector2 = e[0]
		var radius: float = e[1]
		var alpha: float = e[2]
		var col: Color = cool.lerp(hot, float(e[3]))
		# One soft halo and the coal. Three stacked circles plus tails on the bright ones turned a
		# quiet fall into a fireworks display of its own, which is the opposite of the point.
		fx.draw_circle(pos, radius * 1.9, Color(col.r, col.g, col.b, alpha * 0.18))
		fx.draw_circle(pos, radius, Color(col.r, col.g, col.b, alpha))

# The restart button is the app's standard game button (see scripts/game_button.gd), which was
# lifted out of here so the main menu's Start could be the same object.
func _style_restart_button(didwin: bool) -> void:
	var bg: Color = _WIN_BG if didwin else Color(0.976, 0.792, 0.353)
	GameButton.style($StartButton/StartButtonCtrl, bg, _WIN_INK,
		44 if MainGlobals.is_mobile() else 28)

func set_game(_game):
	game = _game
	game.sig_game_is_done.connect(on_game_is_done)
	game.sig_level_label_changed.connect(show_level_label)
	if not game.uses_session_clock:
		$TimeLeftLabel.hide()
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
	_sync_top_strip()

func _on_dispatch_timer_timeout() -> void:
	$Dispatch.hide()
	_sync_top_strip()

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
	_counters_wanted = true
	$CorrectsMistakesContainer.show()
	_sync_top_strip()

func hide_dispatch() -> void:
	$Dispatch.hide()
	$DispatchTimer.stop()
	_sync_top_strip()

# The counters and the transient line (Dispatch/Reminder) are both anchored top-center and their
# rects overlap — counters (256,0)-(424,60), dispatch (216,3)-(463,53). No game had hit it because
# none used both: the 14 games that dispatch never show counters, and none of the 22 that show
# counters dispatch.
#
# The LINE moves, not the counters. The counters are level state — a running tally the player
# watches across the whole level — and the line is per round, so letting the line hide them made
# the tally blink out and back on every single round. A line 60px lower is the cheaper cost.
#
# A game that does not show counters is untouched: the offsets stay exactly as the scene set them.
const _TOP_STRIP_DROP: float = 62.0
var _counters_wanted: bool = false

func _sync_top_strip() -> void:
	var drop: float = _TOP_STRIP_DROP if _counters_wanted else 0.0
	for n: Control in [$Dispatch, $Reminder]:
		n.offset_top = 3.0 + drop
		n.offset_bottom = 53.0 + drop

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


# `_modulate` exists because the icon carries a yellow tint from the scene, to match the yellow
# number beside it. That is right for a one-color pictogram and wrong for an icon made of a game's
# own sprite art, which comes out muddy under it — pneumo's crash icon passes white.
func set_packets_icon(_texture, _scale := 1.0, _modulate = null):
	%PacketsIcon.texture = _texture
	var tex_size = %PacketsIcon.texture.get_size()
	%PacketsIcon.custom_minimum_size = tex_size * _scale
	if _modulate != null:
		%PacketsIcon.modulate = _modulate

func update_corrects_mistakes():
	if game == null:
		%CorrectsLabel.text = "0"
		%MistakesLabel.text = "0"
		return
	%CorrectsLabel.text = str(game.corrects)
	%MistakesLabel.text = str(game.mistakes)

# The label sits over whatever the game draws behind it, and the games are getting drawn boards
# rather than flat tiles — a 63%-alpha yellow over whack's fairground awning was unreadable. Full
# opacity, the app's prose face, and a dark outline so it holds up over anything.
func show_level_label(level_name: String):
	%LevelLabel.text = level_name
	%LevelLabel.modulate = Color(1, 1, 1, 1)
	%LevelLabel.add_theme_font_override("font", MainGlobals.get_text_font())
	%LevelLabel.add_theme_color_override("font_color", ScreenBackdrop.ACCENT)
	%LevelLabel.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	%LevelLabel.add_theme_constant_override("outline_size", 8)
	%LevelLabel.show()
