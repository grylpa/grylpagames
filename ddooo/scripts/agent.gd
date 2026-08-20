extends Area2D

signal need_to_remove_agent(agent)
signal agent_pressed(agent)

var board_pos: Vector2i
var time_created_ms: float = 0.0
var color = [Color(1,1,1,1),Color(1,1,1,1)]
var time_to_hide_ms: int = 2000
var is_correct: bool = false
var is_model: bool = false
var id: int = 0
var timed_out: bool = false
var texture_idx: int = 0

var game:GenericGameUtil
var shader_material_lr: ShaderMaterial = null

static var next_agent_texture_idx := 0
static var agent_textures = [
	preload("res://ddooo/art/shape-circle.png"),
	preload("res://ddooo/art/shape-circle-4.png"),
	preload("res://ddooo/art/shape-circle-swirl.png"),
	preload("res://ddooo/art/shape-circle-w-2-dots.png"),
	preload("res://ddooo/art/shape-circle-w-3-dots.png"),
	preload("res://ddooo/art/shape-circle-w-4-dots.png"),
	preload("res://ddooo/art/shape-circle-w-5-dots.png"),
]

func _ready() -> void:
	game = DdoooG.game
	z_index = 10
	time_created_ms = game.game_time
	%SpriteLR.visible = true
	set_texture(texture_idx)
	if %SpriteLR.material is ShaderMaterial:
		%SpriteLR.material = %SpriteLR.material.duplicate()
		shader_material_lr = %SpriteLR.material

func set_rand_texture(index_to_avoid=-1):
	while true:
		texture_idx = next_agent_texture_idx
		next_agent_texture_idx = (next_agent_texture_idx + 1) % agent_textures.size()
		if texture_idx != index_to_avoid:
			set_texture(texture_idx)
			return texture_idx

func set_texture(idx):
	texture_idx = idx % agent_textures.size()
	%SpriteLR.texture = agent_textures[texture_idx]

func set_colors(_color):
	color = _color.duplicate(true)
	if shader_material_lr:
		shader_material_lr.set_shader_parameter("color_left", color[0])
		shader_material_lr.set_shader_parameter("color_right", color[1])

func set_pos(p, dir):
	rotation = dir * PI/2
	position = p

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(self)

# Held by the coach so it cannot time out mid-lesson. A tutorial's ACTION steps run unpaused —
# that is the whole point of them — so "the timeout is measured in game_time, which excludes paused
# time" only protects the TALKING steps. While the player is deciding, or reading a caption that
# does not pause, the model or the lineup would expire and the board reset under them.
var tutorial_hold: bool = false

func _process(_delta: float) -> void:
	if tutorial_hold:
		# Keep the deadline the same distance away for as long as the hold lasts.
		time_created_ms = game.game_time
		return
	var tm = game.game_time
	if tm - time_created_ms >= time_to_hide_ms:
		%SpriteLR.visible = false
		timed_out = true
		need_to_remove_agent.emit(self)
