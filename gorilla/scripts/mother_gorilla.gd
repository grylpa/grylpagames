extends "res://gorilla/scripts/peripheral_gorilla.gd"

# THE MOTHER (2026-11-09). Each time a baby is rescued, a grown gorilla appears somewhere ELSE in the
# maze holding out a SWORD for a few seconds. Reach her in time and take it: it works as the
# super-food did (it replaced it). A second thing to notice away from where you are, and the reward
# for the first.
#
# The adult figure (silverback, face toward you) from the old peripheral gorilla, standing still and
# breathing, the sword held up beside her and glinting; she fades in, and fades out when the sword
# is taken or her time is up.

var life_ms: float = 8000.0
var _age: float = 0.0
var leaving: bool = false
var _leave_age: float = 0.0
signal gone

func _ready() -> void:
	_view = View.FRONT
	modulate.a = 0.0

func leave() -> void:
	if not leaving:
		leaving = true
		_leave_age = _age

func _process(delta: float) -> void:
	if game != null and game.paused():
		return
	_age += delta
	_phase += delta * 1.0
	if leaving:
		modulate.a = clampf(1.0 - (_age - _leave_age) / 0.6, 0.0, 1.0)
		if modulate.a <= 0.0:
			gone.emit()
			queue_free()
			return
	else:
		modulate.a = clampf(_age / 0.6, 0.0, 1.0)
		# the last second of her wait: she starts to fade, a warning
		var left: float = life_ms / 1000.0 - _age
		if left < 1.0:
			modulate.a = 0.4 + 0.6 * left
	queue_redraw()

func _draw() -> void:
	super._draw()
	if leaving:
		return
	# the sword, held up beside her, point up, a glint running along the blade
	var u: float = body_height
	var grip: Vector2 = Vector2(u * 0.46, -u * 0.05)
	var up: Vector2 = Vector2(0.18, -1.0).normalized()
	var side: Vector2 = Vector2(-up.y, up.x)
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.0)
	var tip: Vector2 = grip + up * u * 0.95
	var guard: Vector2 = grip + up * u * 0.16
	for k in 5:
		var f: float = 1.0 - float(k) / 5.0
		draw_circle(grip + up * u * 0.55, u * (0.30 + 0.08 * pulse) * f, Color(0.75, 0.85, 1.0, 0.05))
	var blade: PackedVector2Array = PackedVector2Array([guard + side * u * 0.05, guard - side * u * 0.05,
		tip - up * u * 0.10 - side * u * 0.04, tip, tip - up * u * 0.10 + side * u * 0.04])
	draw_colored_polygon(blade, Color(0.82, 0.85, 0.90))
	draw_line(guard, tip - up * u * 0.06, Color(0.55, 0.58, 0.65), maxf(1.0, u * 0.015))
	draw_line(guard + side * u * 0.025, tip - up * u * 0.12 + side * u * 0.02, Color(1, 1, 1, 0.8), maxf(1.0, u * 0.012))
	var gl: Vector2 = guard + up * u * (0.1 + 0.6 * fmod(_age * 0.6, 1.0))
	draw_circle(gl, u * 0.035, Color(1, 1, 1, 0.8))
	draw_line(guard + side * u * 0.17, guard - side * u * 0.17, Color(0.85, 0.66, 0.22), u * 0.05)
	draw_line(grip, guard, Color(0.36, 0.22, 0.12), u * 0.06)
	draw_circle(grip - up * u * 0.02, u * 0.045, Color(0.85, 0.66, 0.22))

func visual_half() -> Vector2:
	return Vector2(body_height * 0.75, body_height * 0.6)
