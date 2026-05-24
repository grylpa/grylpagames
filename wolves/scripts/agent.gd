extends Area2D

# signal hit(id)
signal remove_agent(id, good_remove)
signal agent_pressed(_transaction_id, _board_pos)

@export var jitter_strength := randf_range(1.5,2.5)
@export var jitter_speed := randf_range(300.0, 600)

var noise := FastNoiseLite.new()
var t_jitter := 0.0

var board_pos: Vector2i
var direction: int
var was_removed := false
var agent_type := 0
var agent_id := 0
var last_major_tick_ms := -10000
var speed_scale := 1.0
var transaction_id := -1
var time_created_ms := 0
var angles = []

var scared:bool = false
var trying_to_enter:bool = false
var to_sheep:bool = false

var color = Color.WHITE
var isready = false
var game:GenericGameUtil

var path:Array[Vector2i] = []

func _ready() -> void:
	# color = game.next_color()
	game = WolvesG.game
	noise.seed = randi()
	# noise.frequency = 0.01
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	# $Head.play("HeadEyes")
	if agent_type == 0:
		$Head.play("Sheep")
	else:
		$Head.play("Enemy")
	$Head.speed_scale = 0.5
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true
	time_created_ms = MainGlobals.timems()

	if agent_type == 0:
		var s = $Head.scale
		$Head.scale = Vector2(s.x,s.y * 0.8)

func set_id(_id):
	agent_id = _id

func set_type(_agent_type):
	agent_type = _agent_type

func set_color(_color):
	color = _color
	$Head.set_modulate(color)
		
func set_color_idx(_color_idx = -1):
	var coloridx = 0
	if _color_idx >= 0:
		coloridx = _color_idx % game.colors.size()
	else:
		if speed_scale < 1.8:
			coloridx = 0
		elif speed_scale < 2.6:
			coloridx = 1
		else:
			coloridx = 2
	color = game.color_by_index(coloridx)
	set_color(color)	
	
func set_pos(p, dir):
	direction = dir
	angles[0] = dir * PI/2
	set_rots()
	if !isready:
		return
	position = p

var _speed_mul := 1.0
var last_time_moved := MainGlobals.timems()

func _process(_delta: float) -> void:
	if agent_type == 0:
		t_jitter += _delta * jitter_speed	
		var jitter := Vector2(noise.get_noise_1d(t_jitter),noise.get_noise_1d(t_jitter + 1000.0)) * jitter_strength
		$Head.position = jitter

	if eaten:
		return

	var v:Vector2 = Vector2.ZERO
	var target_position = game.board_to_px(board_pos)
	var dv = target_position - position
	var dt = MainGlobals.timems() - last_time_moved
	var speed = 50.0 * speed_scale * _speed_mul / game.major_tick_time_ms / game.time_scale
	if dv.length() > 1e-3:
		v = dv / dv.length() * speed
	else:
		return
	var last = position
	var newpos = position + v * dt
	if (last - newpos).length_squared() > (last - target_position).length_squared():
		newpos = target_position
	if newpos == position:
		return
	position = newpos
	var actual_dx = position - last
	# print(actual_dx.length())
	if actual_dx.length() > 0.01 and !eating and !eaten:
		angles[0] = last.angle_to_point(position)
	last_time_moved = MainGlobals.timems()
	set_rots()
		
func set_rots():
	$Head.rotation = angles[0]
	
var eaten := false

func mark_eaten(pos_to):
	if eaten:
		return
	eaten = true
	var node_to_shake = $Head
	angles[0] = pos_to.angle_to_point(position)
	node_to_shake.rotation = angles[0]
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(1.0,0.4,0.4,1), 0.3)
	# tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,1), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.3, 0.2)
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.5, 0.2)
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.1, 0.2)

	var tween_pos = MainGlobals.make_tween()
	tween_pos.tween_property(self, "position", pos_to, 0.6)

	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

var eating := false
var eating_tween_scale = null
func mark_eating(pos_to):
	if eating:
		return
	eating = true
	var node_to_shake = $Head
	angles[0] = position.angle_to_point(pos_to)
	node_to_shake.rotation = angles[0]
	eating_tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.7, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.0, 0.15)
	eating_tween_scale.tween_callback(
		func(): 
			eating = false
	)

func mark_removed():
	# set_color(Color(0,0,0))
	was_removed = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 2.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

var scared_tween_color = null
var _in_scared_tween = false
func mark_scared(_scared:bool = true):
	if _scared:
		if scared or _in_scared_tween:
			return
		scared = true
		if eating:
			eating = false
			if eating_tween_scale != null:
				eating_tween_scale.kill()
				eating_tween_scale = null
		_in_scared_tween = true
		var node_to_shake = $Head
		scared_tween_color = MainGlobals.make_tween()
		scared_tween_color.tween_property(self, "modulate", Color(1.0,0.7,0.7,1), 0.3)
		# scared_tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,1), 0.3)
		var tween_scale = MainGlobals.make_tween()
		var oldscale = node_to_shake.scale
		tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.3, 0.3)
		tween_scale.tween_property(node_to_shake, "scale", oldscale * 1, 0.3)
		# oldscale = scale
		# tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
		
		tween_scale.tween_callback(
			func():
				_in_scared_tween = false;
		)
	else:
		if scared_tween_color != null:
			scared_tween_color.kill()
			scared_tween_color = null
		scared = false
		modulate = Color(1,1,1,1)
	set_speed_mul()

func set_speed_mul():
	_speed_mul = 5.0 if scared else 1.0

func can_set_target_pos():
	if eaten:
		return false
	var supposed_to_be_px = game.board_to_px(board_pos)
	if (supposed_to_be_px - position).length() < game.tile_size / 10:
		set_speed_mul()
		return true
	else:
		return MainGlobals.timems() - last_time_moved > 1000
		# return false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(transaction_id, board_pos)
