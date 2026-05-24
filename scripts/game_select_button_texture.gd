extends TextureButton

# @onready var _sm := (material as ShaderMaterial)
@onready var yellow_frame := %YellowFrame
@onready var black_frame := %BlackFrame

func _ready() -> void:
	_update_shader_size()
	resized.connect(_update_shader_size)
	yellow_frame = %YellowFrame
	black_frame = %BlackFrame

func _update_shader_size() -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("draw_size_px", size)		
	# if _sm:
	# 	_sm.set_shader_parameter("draw_size_px", size)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_shader_size()