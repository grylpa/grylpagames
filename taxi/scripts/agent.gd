extends Area2D

# signal hit(id)
signal remove_agent(id, arrived)
signal agent_pressed(agent)
# signal sig_agent_started_moving(_transaction_id)
signal sig_agent_timeout(agent)
signal sig_agent_finished_arriving(agent)
signal sig_out_of_gas(agent)
signal sig_finished_filling_gas(agent, percentage_filled)

var life_time_ms = TaxiG.time_for_customer_to_give_up_ms
var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var set_target_once := false
var arrived := false
var was_hit := false
var agent_type := 1
var agent_id := 0
var speed := 80.0 / 0.1			# pixels / sec
var speed_scale := 1.0
var is_moving := false
var transaction_id := -1
var time_created_ms := 0.0
var signalled_timeout := false
var is_taxi := false
var is_selected := false
var goal_pos:Array[Vector2i]
var waiting_pos := Vector2i(-1000,-1000)
var passangers:Array
var dropoff_pos:Vector2i
var being_carried := false
var assigned_to_taxi = null
var assigned_to_customer = null
var is_blocked := false
var tick_set_board_pos := Vector2i(-1000,-1000)
var time_started_to_fill_gas_ms := 0.0
var out_of_gas := false
var going_to_fill_gas := false
var is_filling_gas := false
var fuel_level := 1.0

var path:Array[Vector2i] = []
var angles = []
var is_embarking := false

var color := Color(1,1,1,1)
var isready = false

var game:GenericGameUtil

func _ready() -> void:
	game = TaxiG.game
	# color = game.next_color()
	set_type(agent_type)
	%Selected.hide()
	%Selected.modulate = Color(1,1,1,0.7)
	%Assigned.hide()
	%PassengerAssigned.hide()
	$Head.self_modulate = color
	$Head.rotation = PI/2
	if is_taxi:
		$Head.play("HeadTaxi")
	else:
		$Head.play("HeadEyes")
	$Head.speed_scale = 0.5
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true
	time_created_ms = game.game_time
	%GasSprite.visible = is_taxi

func set_id(_id):
	agent_id = _id

func set_color(_color):
	color = _color
	$Head.self_modulate = color

func set_type(_agent_type):
	agent_type = _agent_type
	# var coloridx = agent_type-1
	# if speed_scale < 1.8:
	# 	coloridx = 0
	# elif speed_scale < 2.6:
	# 	coloridx = 1
	# else:
	# 	coloridx = 2
	# color = game.color_by_index(coloridx)
	# set_color(color)

func set_pos(p, dir):
	set_rot(dir)
	if !isready:
		return
	position = p

# How long a taxi takes to swing round to a new heading. Kept well under the time it takes to cross
# a tile, so the turn reads as a turn and not as a delay.
const TURN_TIME_SEC: float = 0.12

# The angle the head is DRAWN at. `angles[0]` stays the logical heading — the body segments trail
# off it — while this one is tweened, so a taxi rounding a corner swings instead of snapping.
var _head_angle: float = 0.0
var _head_angle_set: bool = false
var _turn_tween: Tween = null

func set_rot(dir):
	direction = dir
	angles[0] = dir * PI/2
	_turn_head_to(angles[0])
	set_rots()

func _turn_head_to(target: float) -> void:
	if not _head_angle_set:
		# First heading of this taxi's life: no turn to animate, just face that way.
		_head_angle = target
		_head_angle_set = true
		return
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	# Shortest way round, so a right turn from "up" does not unwind three quarters of a circle.
	var to: float = _head_angle + wrapf(target - _head_angle, -PI, PI)
	if absf(to - _head_angle) < 0.01:
		_head_angle = to
		return
	_turn_tween = MainGlobals.make_tween()
	_turn_tween.tween_property(self, "_head_angle", to, TURN_TIME_SEC)

var time_set_target_pos := 0.0

func set_board_pos(bp):
	board_pos = bp
	var dt = game.major_tick_time_ms * game.time_scale / 1000.0
	var tween_pos = MainGlobals.make_tween()
	tween_pos.tween_property(self, "position", game.board_to_px(bp), dt)
	# position = game.board_to_px(bp)

func set_target_pos(p):
	is_moving = true
	target_position = p
	starting_position = position
	time_set_target_pos = game.game_time
	set_target_once = true
	# Log.dbg("set_target_pos p:", p, " position: ", position)

var last_vibrate_time := 0
var is_actually_not_moving := false
# var prev_pos := Vector2(-1000,-1000)
var _last_position_for_fuel := Vector2(-1000,-1000)
var _last_process_game_time := 0.0

func _process(_delta: float) -> void:
	if game.paused():
		return
	# The turn tween moves _head_angle; the sprite only picks it up when set_rots() happens to run,
	# which is not every frame — so a standing taxi snapped to its new heading instead of swinging.
	if _head_angle_set:
		$Head.rotation = _head_angle

	var now = game.game_time
	if is_taxi:
		if _last_position_for_fuel.x > -999:
			var dt_fuel = position.distance_to(_last_position_for_fuel)
			var consumption
			if dt_fuel == 0:
				var time_idle_ms = now - _last_process_game_time
				consumption = time_idle_ms / 1000.0 / TaxiG.time_to_empty_fuel_tank_on_idle_sec
			else:
				consumption = dt_fuel / game.tile_size / TaxiG.num_tiles_for_empty_fuel_tank
			fuel_level = max(0, fuel_level - consumption)
		_last_position_for_fuel = position
		_last_process_game_time = now

		if check_gas():
			return
		if MainGlobals.timems() - last_vibrate_time >= 25:
			var mg = 0.4
			if is_blocked:
				mg = 1
			var vib_x = clamp(game.rng.randfn(0,mg),-2*mg,2*mg)
			var vib_y = clamp(game.rng.randfn(0,mg),-2*mg,2*mg)
			var vib_pos = Vector2(vib_x,vib_y)
			$Head.position = vib_pos
			for pas in passangers:
				pas.position = vib_pos
			last_vibrate_time = MainGlobals.timems()
	if !is_taxi and life_time_ms > 0:
		if !signalled_timeout and now >= time_created_ms + life_time_ms:
			mark_timeout()
			signalled_timeout = true

	# 	var v_to_target = target_position - position
	# 	var d_to_target = v_to_target.length()
	# 	var should_halt = d_to_target <= 2 or \
	# 		MainGlobals.are_opposite(v_to_target, target_position - starting_position)

	# 	if !should_halt:
	# 		var v = (_delta * speed * speed_scale / game.time_scale) * v_to_target / d_to_target
	# 		var last = position
	# 		position += v
	# 		angles[0] = last.angle_to_point(position)
	# 		if Vector2i(target_position) != Vector2i(starting_position):
	# 		var idx
	# 			if idx >= 0:

	# 		set_rots()
	# 		is_actually_not_moving = prev_pos.distance_to(position) < 1
	# 		prev_pos = position

func set_rots():
	# Drawn from _head_angle, not angles[0]: this runs every frame while moving, and reading the
	# logical heading here would snap the head back and undo the turn tween.
	if not _head_angle_set:
		_head_angle = angles[0]
		_head_angle_set = true
	$Head.rotation = _head_angle

func mark_arrived():
	arrived = true
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,0.2), 0.7)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.5, 0.4)
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.5)
	tween_scale.tween_callback(finished_arriving)

func finished_arriving():
	sig_agent_finished_arriving.emit(self)
	remove_agent.emit(agent_id, true)

func mark_hit():
	# set_color(Color(0,0,0))
	was_hit = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	# tween_color.tween_property(self, "modulate", Color(1,1,1,0.4), 0.65)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 3.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

func mark_timeout():
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.7), 2.0)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.4, 1.5)
	tween_scale.tween_callback(end_agent_timeout)

func end_agent_timeout():
	sig_agent_timeout.emit(self)
	remove_agent.emit(agent_id, false)

func distance_to_point(p):
	var d = (position - p).length()
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	return d

func get_major_tick():
	return game.major_tick_time_ms * game.time_scale / speed_scale

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(self)

func set_selected(_selected: bool):
	is_selected = _selected
	if is_selected:
		%Selected.show()
		scale = Vector2(1.5,1.5)
	else:
		%Selected.hide()
		scale = Vector2(1,1)

func assign(_transaction_id):
	transaction_id = _transaction_id
	if is_taxi:
		%Assigned.visible = _transaction_id >= 0				
		if _transaction_id < 0:
			goal_pos.clear()
			path.clear()

func assign_taxi(taxi):
	assigned_to_taxi = taxi
	%PassengerAssigned.visible = taxi != null
	# Log.dbg("passenger " + str(transaction_id) + " assigned: ", taxi != null)

func assign_customer(agent):
	assigned_to_customer = agent

func set_blocked(_blocked: bool):
	%Blocked.visible = _blocked
	is_blocked = _blocked

func reset_gas_level():
	out_of_gas = false
	fuel_level = 1.0
	disp_gas_level()

func disp_gas_level():
	if is_taxi:
		%GasSprite.show()
		var w = %GasSprite.texture.get_width()
		var h = %GasSprite.texture.get_height()
		var dtfilling:float = (game.game_time - time_started_to_fill_gas_ms) / TaxiG.dtime_to_fill_full_tank_ms if is_filling_gas else 0.0
		var dtgas = min(1, fuel_level + dtfilling)
		var wuse = int(w - w * dtgas)
		var r = Rect2(0, 0, wuse, h)
		%GasSprite.region_rect = r

func set_fuel_level(fuel:float):
	fuel_level = fuel

func check_gas():
	disp_gas_level()
	if is_taxi:
		if out_of_gas:
			return true
		var dtfilling:float = (game.game_time - time_started_to_fill_gas_ms) / TaxiG.dtime_to_fill_full_tank_ms if is_filling_gas else 0.0
		var dtgas = min(1, fuel_level + dtfilling)
		if is_filling_gas:
			if dtgas >= 1:
				is_filling_gas = false
				sig_finished_filling_gas.emit(self, dtfilling)
				fuel_level = 1.0
				modulate = Color(1,1,1,1)
				disp_gas_level()
				stop_gas_station_anim()
			return
		if dtgas <= 1e-5:
			out_of_gas = true
			$Head.stop()
			$Head.modulate = Color(0.5,0.5,0.5,1)
			sig_out_of_gas.emit(self)
		return out_of_gas
	return false

func start_filling_gas(_gas_station):
	# Log.dbg("starting to fill gas")
	going_to_fill_gas = false
	is_filling_gas = true
	time_started_to_fill_gas_ms = game.game_time
	activate_gas_station_anim(_gas_station)

var _current_gas_station = null
# var _tween_gas_station
var _tween_taxi_filling_gas

func activate_gas_station_anim(_gas_station):
	_current_gas_station = _gas_station
	modulate = Color(0,1,0,1)
	# _gas_station.modulate = Color(0,1,0,1)
	# _tween_gas_station = MainGlobals.make_tween()
	# _tween_gas_station.set_loops() # loops forever
	# _tween_gas_station.tween_property(_gas_station, "modulate", Color(0,1,0,1), 2.0)
	# _tween_gas_station.tween_property(_gas_station, "modulate", Color(1,1,1,1), 2.0)

	_tween_taxi_filling_gas = MainGlobals.make_tween()
	_tween_taxi_filling_gas.set_loops() # loops forever
	# _tween_taxi_filling_gas.tween_property($Head, "scale", Vector2(1.1,1.1), 2.0)
	# _tween_taxi_filling_gas.tween_property($Head, "scale", Vector2(0.9,0.9), 2.0)
	_tween_taxi_filling_gas.tween_property(self, "modulate", Color(0,0.6,0,1), 2.0)
	_tween_taxi_filling_gas.tween_property(self, "modulate", Color(0,1,0,1), 2.0)

func stop_gas_station_anim():
	# if _tween_gas_station != null:
	# 	_tween_gas_station.kill()
	# 	_tween_gas_station = null
	if _tween_taxi_filling_gas != null:
		_tween_taxi_filling_gas.kill()
		_tween_taxi_filling_gas = null
	# if _current_gas_station != null:
	# 	# _current_gas_station.scale = Vector2(1,1)
	# 	_current_gas_station.modulate = Color(1,1,1,1)
	# $Head.scale = Vector2(1,1)
	modulate = Color(1,1,1,1)

func get_state() -> Dictionary:
	return {
		"position": position,
	}

func set_state(data: Dictionary) -> void:
	position = data.get("position", position)
