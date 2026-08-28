extends Area2D

signal need_to_remove_agent(agent)
signal agent_pressed(agent)

var board_pos: Vector2i = Vector2i.ZERO
var time_created_ms: float = 0.0
var color: Array = [Color(1, 1, 1, 1), Color(1, 1, 1, 1)]
var time_to_hide_ms: float = 2000.0
var is_correct: bool = false
var is_correct_shape: bool = false
var is_correct_direction: bool = false
var is_model: bool = false
var id: int = 0
var timed_out: bool = false
var texture_idx: int = 0

var game: GenericGameUtil = null
var shader_material_lr: ShaderMaterial = null

static var next_agent_texture_idx: int = 0
static var agent_textures: Array = [
	preload("res://art/shape-circle.png"),
	preload("res://art/shape-circle-4.png"),
	preload("res://art/shape-circle-swirl.png"),
	preload("res://art/shape-circle-w-2-dots.png"),
	preload("res://art/shape-circle-w-3-dots.png"),
	preload("res://art/shape-circle-w-4-dots.png"),
	preload("res://art/shape-circle-w-5-dots.png"),
]

func _ready() -> void:
	game = DidiG.game
	z_index = 10
	time_created_ms = game.game_time
	%SpriteLR.visible = true
	set_texture(texture_idx)
	if %SpriteLR.material is ShaderMaterial:
		%SpriteLR.material = %SpriteLR.material.duplicate()
		shader_material_lr = %SpriteLR.material

func set_rand_texture(index_to_avoid: int = -1) -> int:
	while true:
		texture_idx = next_agent_texture_idx
		next_agent_texture_idx = (next_agent_texture_idx + 1) % agent_textures.size()
		if texture_idx != index_to_avoid:
			set_texture(texture_idx)
			return texture_idx
	return 0

func set_texture(idx: int) -> void:
	texture_idx = idx % agent_textures.size()
	%SpriteLR.texture = agent_textures[texture_idx]

func set_colors(_color: Array) -> void:
	color = _color.duplicate(true)
	if shader_material_lr:
		shader_material_lr.set_shader_parameter("color_left", color[0])
		shader_material_lr.set_shader_parameter("color_right", color[1])

func set_pos(p: Vector2, dir: int) -> void:
	rotation = dir * PI / 2.0
	position = p

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(self)

func _process(_delta: float) -> void:
	var tm: float = game.game_time
	if tm - time_created_ms >= time_to_hide_ms:
		%SpriteLR.visible = false
		timed_out = true
		need_to_remove_agent.emit(self)
