extends Control

signal reveal_finished

var dot_positions: Array = []
var dot_radius: float = 4.0
# var dot_color: Color = Color(0.08, 0.08, 0.38, 1.0)
var dot_color: Color = Color(1, 1, 1, 1.0)

var _reveal_texture: Texture2D = null
var _reveal_rect: Rect2 = Rect2()
var _reveal_alpha: float = 0.0
var _reveal_tween: Tween = null

func _draw() -> void:
	if _reveal_texture != null and _reveal_alpha > 0.0:
		draw_texture_rect(_reveal_texture, _reveal_rect, false, Color(0.78, 0.78, 0.78, _reveal_alpha))
	for pos in dot_positions:
		draw_circle(pos, dot_radius, dot_color)

func clear_dots() -> void:
	dot_positions = []
	queue_redraw()

func clear_reveal() -> void:
	if _reveal_tween:
		_reveal_tween.kill()
		_reveal_tween = null
	_reveal_alpha = 0.0
	queue_redraw()

func set_dots(positions: Array, radius: float, texture: Texture2D, dot_rect: Rect2, _color: Color) -> void:
	dot_color = _color
	if _reveal_tween:
		_reveal_tween.kill()
		_reveal_tween = null
		reveal_finished.emit()
	dot_positions = positions
	dot_radius = radius
	_reveal_texture = texture
	_reveal_rect = dot_rect
	_reveal_alpha = 0.0
	queue_redraw()

func reveal_letter() -> void:
	_reveal_alpha = 0.0
	if _reveal_tween:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(func(a: float) -> void:
		_reveal_alpha = a
		queue_redraw()
	, 0.0, 0.45, 1.2)
	_reveal_tween.tween_callback(func() -> void:
		_reveal_tween = null
		reveal_finished.emit()
	)
