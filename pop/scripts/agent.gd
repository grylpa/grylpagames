extends Area2D

# signal hit(id)
signal need_to_remove_agent(agent)
signal agent_pressed(agent)

var board_pos: Vector2i
var time_created_ms := 0.0
var color := [Color(1,1,1,1),Color(1,1,1,1)]
var time_to_hide_ms := 2000
var is_correct := false
var is_model := false
var id := 0
var timed_out := false
var texture_idx := 0

var game:GenericGameUtil
var shader_material_lr: ShaderMaterial = null

static var next_agent_texture_idx := 0
static var agent_textures = [
	preload("res://pop/art/shape-circle.png"),
	preload("res://pop/art/shape-circle-4.png"),
	preload("res://pop/art/shape-circle-swirl.png"),
	preload("res://pop/art/shape-circle-w-2-dots.png"),
	preload("res://pop/art/shape-circle-w-3-dots.png"),
	preload("res://pop/art/shape-circle-w-4-dots.png"),
	preload("res://pop/art/shape-circle-w-5-dots.png"),
]

func _ready() -> void:
	game = PopG.game
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
		# The set_shader_parameter function links to the 'uniforms' in the GDShader
		shader_material_lr.set_shader_parameter("color_left", color[0])
		shader_material_lr.set_shader_parameter("color_right", color[1])

func set_pos(p, dir):
	rotation = dir * PI/2
	position = p
			
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(self)

func _process(_delta: float) -> void:
	var tm = game.game_time
	if tm - time_created_ms >= time_to_hide_ms:
		%SpriteLR.visible = false
		timed_out = true
		need_to_remove_agent.emit(self)