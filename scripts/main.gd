extends Node2D

# var login_scene = load("res://scenes/login.tscn").instantiate()
var level_is_done_audio := preload("res://art/sounds/game-level-done.mp3")

func _ready() -> void:
	var ev := InputEventScreenTouch.new()
	InputMap.action_add_event("touch", ev)

	var grad: Gradient = Gradient.new()
	grad.remove_point(1)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.5, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = grad
	_path_line.texture = tex
	_path_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	# var osname = OS.get_name()
	# Log.dbg("os name:" + osname)
	await get_tree().process_frame
	# get_viewport().canvas_transform.origin = Vector2(0, 0)
	# get_viewport().canvas_transform = Transform2D(0, Vector2(0, 0))
	# if osname.containsn("Android") or osname.containsn("iOS"):
	# 	var vsz = Vector2(680, 680*2)
	var viewport = get_viewport_rect()
	# Log.dbg("viewport: " + str(viewport))				# logical window size set in project settings
	# Log.dbg("window size: " + str(get_window().size))	# actual device resolution
	var screen_size_to_use = viewport.size

	MainGlobals.sig_generic_game_hud_show.connect(on_sig_generic_game_hud_show)
	MainGlobals.sig_path_clear.connect(_clear_path)
	# screen_size_to_use.y -= 40
	# screen_size_to_use.y = MainGlobals.header_height + screen_size_to_use.x
	MainGlobals.init_globals(screen_size_to_use)

	# call_deferred("_apply_canvas_transform")
	# print("window size: " + str(get_window().size))	
	# 	# viewport.size_override = true
	# 	viewport.size = vsz
	# 	print("set new viewport size to " + str(vsz))
	# 	get_window().size = vsz

	#   viewport.set_size_override(true, Vector2(Width_Set, Height_Set)) # Custom size for 2D.
	#   viewport.set_size_override_stretch(true) # Enable stretch for custom size.

	MainGlobals.load_settings()
	BE.sig_created_player.connect(_on_BE_sig_created_player)
	BE.sig_logged_in.connect(_on_BE_sig_logged_in)
	BE.sig_show_login_screen.connect(_on_show_login_screen)
	BE.sig_session_expired.connect(_on_session_expired)
	BE.start()

	$GlobalLevelIsDoneAudio.stream = level_is_done_audio
	MainGlobals.sig_update_bottom_bar.connect(_on_sig_update_bottom_bar)
	MainGlobals.sig_global_level_is_done.connect(_on_global_level_is_done)
	show_game_chooser()

	if _should_force_guest_name() and not MainGlobals.has_named_guest():
		$LoginScreen.show_guest_name_only()


func _should_force_guest_name() -> bool:
	return not MainCfg.use_BE or MainCfg.is_anonymous_user

# func _apply_canvas_transform():
# 	get_canvas_transform().origin = Vector2(0,-500)
# 	# get_viewport().canvas_transform = Transform2D(0, Vector2(0, 0))

func _on_BE_sig_created_player(success: bool, _fail_reason: BE.SignupFailReasons) -> void:
	# Log.dbg("BE.sig_created_player in main")
	if !success:
		_on_show_login_screen()

func _on_BE_sig_logged_in(success: bool, _fail_reason: BE.LoginFailReasons) -> void:
	# Log.dbg("BE.sig_login_player in main")
	if success:	
		do_after_login()
	elif !MainCfg.is_anonymous_user:
		_on_show_login_screen()

func do_after_login():
	if MainCfg.is_anonymous_user:
		BE.upsert_user_activity()
		# user_file_key was already set by register_guest_name() before sign_in_anon()
	else:
		var old_key: String = MainGlobals.user_file_key
		MainGlobals.set_user_file_key(BE.stored_email)
		MainGlobals.migrate_scores_to_user_key(old_key)
	MainGlobals.save_settings()
	MainGlobals.on_logged_in_sync()
	# login_scene.queue_free()
	# var strcnt = BE.get_prop("times_run", "0")
	# var times_run = strcnt.to_int()
	# print("Times run: %s" % times_run)
	# BE.set_prop("times_run", str(strcnt.to_int() + 1))

func _on_game_chooser_selected_game(scene: Variant, game_name: String) -> void:
	MainGlobals.active_game = scene
	BE.send_event("game_selected", game_name, {})
	# print("sent event for game start: " + game_name)
	add_child(scene)
	# The game's _ready has run by now and consumed any tutorial request. Clear it either way, so
	# a game that has no tutorial hook cannot leave the flag armed for a later, unrelated launch.
	MainGlobals.pending_tutorial = ""
	# scene.new_game(true)
	$GameChooser.hide()

func _on_game_chooser_stop_active_game() -> void:
	if MainGlobals.active_game != null:
		MainGlobals.active_game.queue_free()
		MainGlobals.active_game = null
	show_game_chooser()

func show_game_chooser():
	$GameChooser.show()
	MainGlobals.update_bottom_bar("")
	# $BottomOptionButtons.set_buttons("")

func _on_show_login_screen() -> void:
	$LoginScreen.quiet = false
	$LoginScreen.show()

# var min_swipe_distance = 20
# var swipe_active = false
# var swipe_start = null
# const actions = [["left", "right"], ["up", "down"]]

# func _input(event):
# 	if event is InputEventScreenTouch:
# 		if event.pressed:
# 			swipe_start = event.position
# 			swipe_active = true
# 		else:
# 			swipe_active = false			

# 	elif event is InputEventScreenDrag and swipe_active:
# 		var drag_vector = event.relative  # Movement since last frame
# 		var direction = Vector2(0, 0)
# 		var action: String
# 		if abs(drag_vector.x) > abs(drag_vector.y):
# 			if abs(drag_vector.x) > min_swipe_distance:
# 				direction.x = sign(drag_vector.x)
# 				action = actions[0][(direction.x > 0) as int]
# 		else:
# 			if abs(drag_vector.y) > min_swipe_distance:
# 				direction.y = sign(drag_vector.y)
# 				action = actions[1][(direction.y > 0) as int]
# 		if action != null:
# 			MainGlobals.sim_action(action)

# 	elif event.is_action_pressed("mute"):
# 		MainGlobals.mute = !MainGlobals.mute
# 		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), MainGlobals.mute)

const actions := [["left", "right"],["up", "down"]]

var swipe_accum := Vector2.ZERO
var swipe_axis := 0 # 0 = none, 1 = horizontal, 2 = vertical
var swipe_start_pos:Vector2

@export var min_swipe_distance := 50.0
@export var axis_lock_threshold := 6.0
@export var switch_ratio := 1.25
@export var cross_damp := 0.6
@export var flick_threshold := 28.0
@export var dir_smooth := 0.5
@export var dir_threshold := 3.0

var swipe_did_step: bool = false
var swipe_dir: Vector2 = Vector2.ZERO

var _drawn_path: Array[Vector2i] = []
var _path_last_board_pos: Vector2i = Vector2i(-1, -1)
var _path_fade_tween: Tween = null
var _raw_swipe_pts: PackedVector2Array = PackedVector2Array()

@onready var _path_line: Line2D = $PathOverlay/PathLine

func _process(_delta:float) -> void:
	if not MainGlobals.swipe_active or MainGlobals.popup_open:
		MainGlobals.is_in_digitized_swipe_up = false
		MainGlobals.is_in_digitized_swipe_dn = false

func _input(event: InputEvent) -> void:
	if MainGlobals.popup_open:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if MainGlobals.draw_path_mode:
				if _path_fade_tween != null:
					_path_fade_tween.kill()
					_path_fade_tween = null
				_path_line.modulate.a = 1.0
				_raw_swipe_pts = PackedVector2Array([event.position])
				_path_line.points = _raw_swipe_pts
				_drawn_path = []
				_path_last_board_pos = Vector2i(-1, -1)
				MainGlobals.swipe_active = true
				MainGlobals.swipe_was_drag = false
				_path_extend(event.position)
				return
			MainGlobals.swipe_active = true
			swipe_accum = Vector2.ZERO
			swipe_axis = 0
			swipe_did_step = false
			swipe_start_pos = event.position
			swipe_dir = Vector2.ZERO
		else:
			if MainGlobals.draw_path_mode:
				if MainGlobals.swipe_active:
					MainGlobals.sig_path_drawn.emit(_drawn_path.duplicate())
				_path_fade_tween = create_tween()
				_path_fade_tween.tween_property(_path_line, "modulate:a", 0.0, 0.6)
				_path_fade_tween.tween_callback(func() -> void:
					_path_line.points = PackedVector2Array())
				_drawn_path = []
				_path_last_board_pos = Vector2i(-1, -1)
				MainGlobals.swipe_active = false
				return
			if MainGlobals.swipe_active:
				if not swipe_did_step:
					var d: Vector2 = event.position - swipe_start_pos
					var ax: float = abs(d.x)
					var ay: float = abs(d.y)

					if !MainGlobals.digitized_swipe_mode:
						if ax >= flick_threshold or ay >= flick_threshold:
							if ax >= ay:
								var action: String = actions[0][(d.x > 0.0) as int]
								MainGlobals.sim_action(action)
							else:
								var action: String = actions[1][(d.y > 0.0) as int]
								MainGlobals.sim_action(action)
						MainGlobals.sim_action("stop")

			MainGlobals.swipe_active = false
			swipe_accum = Vector2.ZERO
			swipe_axis = 0
			swipe_did_step = false
			swipe_dir = Vector2.ZERO

	elif event is InputEventScreenDrag and MainGlobals.swipe_active:
		MainGlobals.swipe_was_drag = true
		if MainGlobals.draw_path_mode:
			_raw_swipe_pts.append(event.position)
			_path_line.points = _raw_swipe_pts
			_path_extend(event.position)
			return
		swipe_accum += event.relative
		swipe_dir = swipe_dir.lerp(event.relative, dir_smooth)

		var ax: float = abs(swipe_accum.x)
		var ay: float = abs(swipe_accum.y)

		if swipe_axis == 0:
			if ax < axis_lock_threshold and ay < axis_lock_threshold:
				return
			swipe_axis = 1 if ax >= ay else 2

		var dx: float = abs(swipe_dir.x)
		var dy: float = abs(swipe_dir.y)

		if swipe_axis == 1:
			var did_step: bool = _process_horizontal_steps()
			if did_step:
				swipe_did_step = true

			if dy >= dir_threshold and dy >= dx * switch_ratio:
				swipe_axis = 2
			elif did_step:
				swipe_accum.y *= cross_damp

		else:
			var did_step: bool = _process_vertical_steps()
			if did_step:
				swipe_did_step = true

			if dx >= dir_threshold and dx >= dy * switch_ratio:
				swipe_axis = 1
			elif did_step:
				swipe_accum.x *= cross_damp

		if swipe_axis == 2:
			var th:float = 30
			if MainGlobals.is_in_digitized_swipe_up:
				MainGlobals.is_in_digitized_swipe_up = swipe_accum.y < th
				MainGlobals.is_in_digitized_swipe_dn = !MainGlobals.is_in_digitized_swipe_up
			elif MainGlobals.is_in_digitized_swipe_dn:
				MainGlobals.is_in_digitized_swipe_dn = swipe_accum.y > -th
				MainGlobals.is_in_digitized_swipe_up = !MainGlobals.is_in_digitized_swipe_dn
			else:
				MainGlobals.is_in_digitized_swipe_up = swipe_accum.y < 0
				MainGlobals.is_in_digitized_swipe_dn = !MainGlobals.is_in_digitized_swipe_up

	elif event.is_action_pressed("mute"):
		MainGlobals.mute = !MainGlobals.mute
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), MainGlobals.mute)


func _path_extend(px_pos: Vector2) -> void:
	var tile_f: float = float(MainGlobals.path_tile_size)
	if tile_f <= 0.0:
		return
	# Convert screen-space touch position to world/canvas space (accounts for camera zoom/pan)
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * px_pos
	var off: Vector2 = Vector2(MainGlobals.path_screen_offset) + Vector2(0.0, float(MainGlobals.header_height))
	var new_bp: Vector2i = Vector2i((world_pos - off) / tile_f)

	var bs: Vector2i = MainGlobals.path_board_size
	if bs != Vector2i.ZERO:
		new_bp.x = clampi(new_bp.x, 0, bs.x - 1)
		new_bp.y = clampi(new_bp.y, 0, bs.y - 1)

	if _path_last_board_pos == Vector2i(-1, -1):
		_path_last_board_pos = new_bp
		_drawn_path = [new_bp]
		return

	if new_bp == _path_last_board_pos:
		return

	var safety: int = 0
	while _path_last_board_pos != new_bp and safety < 200:
		safety += 1
		var delta: Vector2i = new_bp - _path_last_board_pos
		var step: Vector2i
		if abs(delta.x) >= abs(delta.y):
			step = Vector2i(sign(delta.x), 0)
		else:
			step = Vector2i(0, sign(delta.y))
		var next_pos: Vector2i = _path_last_board_pos + step

		if _drawn_path.size() >= 2 and next_pos == _drawn_path[-2]:
			# backtrack: trim last cell
			_drawn_path.pop_back()
			_path_last_board_pos = next_pos
		elif not _drawn_path.has(next_pos):
			_drawn_path.append(next_pos)
			_path_last_board_pos = next_pos
		else:
			break

func _process_horizontal_steps() -> bool:
	var did_step := false
	while abs(swipe_accum.x) >= min_swipe_distance:
		if !MainGlobals.digitized_swipe_mode:
			var action: String = actions[0][(swipe_accum.x > 0.0) as int]
			MainGlobals.sim_action(action)
		swipe_accum.x -= sign(swipe_accum.x) * min_swipe_distance
		did_step = true
	return did_step

func _process_vertical_steps() -> bool:
	var did_step := false
	while abs(swipe_accum.y) >= min_swipe_distance:
		if !MainGlobals.digitized_swipe_mode:
			var action: String = actions[1][(swipe_accum.y > 0.0) as int]
			MainGlobals.sim_action(action)
		swipe_accum.y -= sign(swipe_accum.y) * min_swipe_distance
		did_step = true
	return did_step


# @export var min_swipe_distance := 24.0
# var swipe_active := false
# var swipe_start := Vector2.ZERO

# func _input(event: InputEvent) -> void:
# 	if event is InputEventScreenTouch:
# 		if event.pressed:
# 			swipe_active = true
# 			swipe_start = event.position
# 		else:
# 			swipe_active = false

# 	elif event is InputEventScreenDrag and swipe_active:
# 		var delta:Vector2 = event.position - swipe_start

# 		if abs(delta.x) >= abs(delta.y):
# 			_handle_axis(true, delta, event.position)
# 		else:
# 			_handle_axis(false, delta, event.position)

# 	elif event.is_action_pressed("mute"):
# 		MainGlobals.mute = !MainGlobals.mute
# 		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),MainGlobals.mute)


# func _handle_axis(horizontal: bool, delta: Vector2, current_pos: Vector2) -> void:
# 	if horizontal:
# 		while abs(delta.x) >= min_swipe_distance:
# 			var action:String = actions[0][(delta.x > 0.0) as int]
# 			MainGlobals.sim_action(action)

# 			swipe_start.x += sign(delta.x) * min_swipe_distance
# 			delta = current_pos - swipe_start

# 		# damp perpendicular drift
# 		swipe_start.y = lerp(swipe_start.y, current_pos.y, 0.35)

# 	else:
# 		while abs(delta.y) >= min_swipe_distance:
# 			var action:String = actions[1][(delta.y > 0.0) as int]
# 			MainGlobals.sim_action(action)

# 			swipe_start.y += sign(delta.y) * min_swipe_distance
# 			delta = current_pos - swipe_start

# 		swipe_start.x = lerp(swipe_start.x, current_pos.x, 0.35)


func _clear_path() -> void:
	if _path_fade_tween != null:
		_path_fade_tween.kill()
		_path_fade_tween = null
	_path_line.points = PackedVector2Array()
	_path_line.modulate.a = 1.0
	_drawn_path = []
	_path_last_board_pos = Vector2i(-1, -1)
	MainGlobals.swipe_active = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 1
		MainGlobals.sim_action("lost_focus")
		_clear_path()
		# get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		MainGlobals.sim_action("resumed_focus")
		Engine.max_fps = 0
		# get_tree().paused = false

func _on_sig_update_bottom_bar(buttons_str_or_arr, _text_color: Color, reversed: bool = false):
	$BottomOptionButtons.set_buttons(buttons_str_or_arr, _text_color, reversed)
	
func on_sig_generic_game_hud_show(_show: bool):
	$GenericGameHUD.visible = _show

func _on_global_level_is_done(didwin:bool):
	if didwin:
		$GlobalLevelIsDoneAudio.play()

func _on_session_expired() -> void:
	var popup: ReauthPopup = preload("res://scenes/reauth_popup.tscn").instantiate() as ReauthPopup
	add_child(popup)
