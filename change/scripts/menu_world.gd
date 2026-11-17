extends "res://scripts/menu_poster.gd"

# CHANGE'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own coins in
# a slow-motion SHOWER through a pool of lamplight over the green felt -- three depths of them: small and
# dim far back, mid, and a few big and sharp up front -- each spinning on its edge as it falls (its width
# following the spin), and a large price tag hanging in the foreground: $2.85. A picture, not a counter
# (the user: a tray with coins dropping into it looked "too much like something that is playable").
# Made up, never the board.

const COIN = preload("res://change/scripts/coin.gd")
const FELT: Shader = preload("res://change/scripts/felt.gdshader")
const VALUES: Array = [1.0, 0.25, 0.5, 0.10, 0.05, 1.0, 0.01, 0.25, 0.5, 0.10, 1.0, 0.05, 0.25, 0.5]
const COUNT: int = 21

var _felt: ColorRect = null
var _light: Control = null
var _layer: Node2D = null
var _coins: Array = []          # [node, depth 0..2, x frac, speed, phase, spin]

func _setup() -> void:
	_felt = ColorRect.new()
	_felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = FELT
	_felt.material = m
	add_child(_felt)
	_light = Control.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light.draw.connect(func() -> void: _draw_light(_light))
	add_child(_light)
	_layer = Node2D.new()
	add_child(_layer)
	# far coins first, so the near ones are drawn over them
	var order: Array = []
	for k in COUNT:
		order.append([k % 3, k])
	order.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for e in order:
		var depth: int = int(e[0])
		var k: int = int(e[1])
		var c: Node2D = COIN.new()
		_layer.add_child(c)
		c.call("setup", float(VALUES[k % VALUES.size()]), [22.0, 36.0, 60.0][depth])
		c.modulate = [Color(0.55, 0.55, 0.52), Color(0.82, 0.82, 0.80), Color(1, 1, 1)][depth]
		_coins.append([c, depth, h01(k * 3 + 1), [40.0, 70.0, 110.0][depth] * (0.8 + 0.4 * h01(k + 50)), h01(k * 3 + 2), 0.6 + 1.4 * h01(k + 80)])

func _draw_light(d: Control) -> void:
	var f: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else f.y * 0.62
	# a pool of warm lamplight from above, the corners in shadow
	for k in 12:
		d.draw_set_transform(Vector2(f.x * 0.5, bottom * 0.55), 0.0, Vector2(1.0, 1.25))
		d.draw_circle(Vector2.ZERO, f.x * (0.85 - 0.06 * float(k)), Color(1.0, 0.88, 0.60, 0.028))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(f.x, 0), Vector2(f.x, f.y * 0.30), Vector2(0, f.y * 0.30)]),
		PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_felt.position = Vector2.ZERO
	_felt.size = full
	(_felt.material as ShaderMaterial).set_shader_parameter("size", full)
	_felt.modulate = Color(0.72, 0.72, 0.72)
	var top: float = 250.0 if mobile else 160.0     # the shower starts under the name
	var span: float = bottom - top + 120.0
	for e in _coins:
		var c: Node2D = e[0]
		var depth: int = int(e[1])
		var y: float = fmod(float(e[4]) * span + t * float(e[3]), span) + top - 60.0
		var sway: float = sin(t * 0.7 + float(e[4]) * 9.0) * (8.0 + 8.0 * float(depth))
		c.position = Vector2(full.x * (0.06 + 0.88 * float(e[2])) + sway, y)
		# spinning on its edge: the coin's width follows the spin, never quite to nothing
		var spin: float = cos(t * float(e[5]) * 0.5 + float(e[4]) * 6.0)
		c.scale = Vector2(0.55 + 0.45 * absf(spin), 1.0)     # turning, never edge-on (thin coins read as slivers)
		c.rotation = sin(t * 0.5 + float(e[4]) * 4.0) * 0.4
		# fade in at the top, out into the panel
		var a: float = clampf((y - top + 60.0) / 80.0, 0.0, 1.0) * clampf((bottom - y) / 60.0, 0.0, 1.0)
		var base: Color = [Color(0.55, 0.55, 0.52), Color(0.82, 0.82, 0.80), Color(1, 1, 1)][depth]
		c.modulate = Color(base, a)
	_light.queue_redraw()

func _paint_top(full: Vector2, bottom: float) -> void:
	title("Change", "Pay the exact amount", Color(0.97, 0.80, 0.38), Color(0.12, 0.08, 0.02), Color(1.0, 0.85, 0.4, 0.25))
	# THE PRICE TAG, large, hanging into the foreground on its string, swaying
	var pin: Vector2 = Vector2(full.x * 0.30, (190.0 if mobile else 128.0))
	var sway: float = deg_to_rad(5.0) * sin(t * 0.9)
	var tw: float = 250.0 if mobile else 180.0
	var th: float = 124.0 if mobile else 90.0
	var hang: float = clampf((bottom - pin.y) * 0.42, 60.0, 300.0)
	cv.draw_set_transform(pin, sway - 0.10, Vector2.ONE)
	cv.draw_line(Vector2.ZERO, Vector2(0.0, hang), Color(0.92, 0.88, 0.78), 2.0)
	var y0: float = hang
	cv.draw_colored_polygon(PackedVector2Array([Vector2(-tw * 0.5 + 26.0, y0 + 6), Vector2(tw * 0.5 + 6, y0 + 6), Vector2(tw * 0.5 + 6, y0 + th + 10),
		Vector2(-tw * 0.5 + 6, y0 + th + 10), Vector2(-tw * 0.5 + 6, y0 + 32)]), Color(0, 0, 0, 0.35))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(-tw * 0.5 + 26.0, y0), Vector2(tw * 0.5, y0), Vector2(tw * 0.5, y0 + th),
		Vector2(-tw * 0.5, y0 + th), Vector2(-tw * 0.5, y0 + 26.0)]), Color(0.97, 0.94, 0.84))
	cv.draw_circle(Vector2(-tw * 0.5 + 22.0, y0 + 22.0), 7.0, Color(0.55, 0.50, 0.42))
	cv.draw_circle(Vector2(-tw * 0.5 + 22.0, y0 + 22.0), 4.0, Color(0.97, 0.94, 0.84))
	var f: Font = MainGlobals.get_text_font()
	var fs: int = 66 if mobile else 48
	var price: String = "$2.85"
	var pw: float = f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	cv.draw_string(f, Vector2(-pw * 0.5 + 12.0, y0 + th * 0.5 + float(fs) * 0.36), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.20, 0.14, 0.08))
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
