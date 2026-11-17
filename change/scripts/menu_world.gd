extends "res://scripts/menu_poster.gd"

# CHANGE'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own coins in
# a slow-motion SHOWER through a pool of lamplight over the green felt -- three depths of them: small and
# dim far back, mid, and a few big and sharp up front -- each spinning on its edge as it falls (its width
# following the spin), and a large shop price tag hanging in the foreground, barely stirring: $2.85. A picture, not a counter
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
	# THE PRICE TAG: a shop's manila tag, cut to a point at its eyelet, a brass-ringed hole, a twisted red-and-white
	# string up to its pin, the paper shaded and ruled, the price in deep red ink. It hangs a touch askew and barely
	# stirs (the user: the plain card swinging on a white thread was "a bit ugly")
	var pin: Vector2 = Vector2(full.x * 0.30, (196.0 if mobile else 132.0))
	var stir: float = deg_to_rad(1.4) * sin(t * 0.7)
	var tw: float = 260.0 if mobile else 186.0
	var th: float = 120.0 if mobile else 86.0
	var hang: float = clampf((bottom - pin.y) * 0.36, 50.0, 260.0)
	cv.draw_set_transform(pin, stir - 0.06, Vector2.ONE)
	# the string: two thin twisted strands, red and white
	var n_tw: int = 14
	for strand in 2:
		var pts: PackedVector2Array = PackedVector2Array()
		for k in n_tw + 1:
			var v: float = float(k) / float(n_tw)
			pts.append(Vector2(sin(v * TAU * 5.0 + float(strand) * PI) * 1.4, v * hang))
		cv.draw_polyline(pts, Color(0.80, 0.14, 0.12) if strand == 0 else Color(0.96, 0.94, 0.90), 1.6, true)
	# the tag: point up at the eyelet, then the body; its shadow first
	var e: Vector2 = Vector2(0.0, hang)
	var cut: float = th * 0.42
	var body: PackedVector2Array = PackedVector2Array([e + Vector2(0, -6), e + Vector2(tw * 0.5, cut), e + Vector2(tw * 0.5, cut + th * 1.55),
		e + Vector2(-tw * 0.5, cut + th * 1.55), e + Vector2(-tw * 0.5, cut)])
	var shadow: PackedVector2Array = PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(7, 10))
	cv.draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
	cv.draw_polygon(body, PackedColorArray([Color(0.97, 0.90, 0.72), Color(0.95, 0.87, 0.68), Color(0.86, 0.76, 0.55), Color(0.88, 0.78, 0.57), Color(0.96, 0.89, 0.70)]))
	# a ruled border inset, and a dotted fold line under the eyelet's corner
	var inset: PackedVector2Array = PackedVector2Array()
	var ctr: Vector2 = e + Vector2(0.0, cut + th * 0.70)
	for p2 in body:
		inset.append(ctr + (p2 - ctr) * 0.90)
	inset.append(inset[0])
	cv.draw_polyline(inset, Color(0.62, 0.20, 0.14, 0.55), 1.5, true)
	var fold_y: float = e.y + cut + 6.0
	var dx: float = -tw * 0.40
	while dx < tw * 0.40:
		cv.draw_line(Vector2(dx, fold_y), Vector2(dx + 4.0, fold_y), Color(0.45, 0.35, 0.22, 0.6), 1.2)
		dx += 9.0
	# the eyelet: a brass ring round the hole
	var eye: Vector2 = e + Vector2(0.0, cut * 0.45)
	cv.draw_circle(eye, 9.0, Color(0.62, 0.46, 0.18))
	cv.draw_circle(eye + Vector2(-1, -1), 7.5, Color(0.92, 0.76, 0.40))
	cv.draw_circle(eye, 4.2, Color(0.10, 0.18, 0.12))
	# the words: a small line over the price, the price large
	var f: Font = MainGlobals.get_text_font()
	var fs_small: int = 20 if mobile else 15
	var lead: String = "PAY EXACTLY"
	var lw: float = f.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
	cv.draw_string(f, Vector2(-lw * 0.5, fold_y + 10.0 + float(fs_small)), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, Color(0.42, 0.30, 0.18, 0.9))
	var fs: int = 64 if mobile else 46
	var price: String = "$2.85"
	var pw: float = f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var py: float = fold_y + 14.0 + float(fs_small) + float(fs) * 0.92
	cv.draw_string(f, Vector2(-pw * 0.5 + 1.5, py + 1.5), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.30, 0.06, 0.04, 0.25))
	cv.draw_string(f, Vector2(-pw * 0.5, py), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.58, 0.10, 0.08))
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
