extends "res://scripts/menu_poster.gd"

# WOLVES' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own clearing
# seen from above (forest.gdshader's woods closing in round a lawn) with its own animals (beast_art.gd):
# a flock grazing in the middle, drifting a little; the border collie circling it, tail wagging; and two
# wolves creeping out of the trees toward it -- until the dog swings round at them and they slink back
# into the shade, and come again. Made up, never the board: the menu also opens mid-game.

const BEAST: Script = preload("res://wolves/scripts/beast_art.gd")
const FOREST: Shader = preload("res://wolves/scripts/forest.gdshader")
const SHEEP_N: int = 9
const CYCLE: float = 9.0
const ZOOM: float = 2.2         # the animals are drawn in board units (a cell is 40); this many px each

var _woods: ColorRect = null
var _field: Node2D = null
var _sheep: Array = []
var _dog: Node2D = null
var _wolves: Array = []
var _center: Vector2 = Vector2.ZERO
var _laid_for: Vector2 = Vector2.ZERO

func _setup() -> void:
	var lawn: Control = Control.new()
	lawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lawn.set_anchors_preset(Control.PRESET_FULL_RECT)
	lawn.draw.connect(func() -> void: _draw_lawn(lawn))
	add_child(lawn)
	_woods = ColorRect.new()
	_woods.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = FOREST
	_woods.material = m
	add_child(_woods)
	_field = Node2D.new()
	_field.scale = Vector2(ZOOM, ZOOM)
	add_child(_field)
	for k in SHEEP_N:
		_sheep.append(_animal("sheep"))
	_dog = _animal("dog")
	for k in 2:
		_wolves.append(_animal("wolf"))

# the animals' pictures are rendered into atlases a frame or two in; drawn as shapes until then
func _is_ready() -> bool:
	return BEAST._atlases.has("sheep") and BEAST._atlases.has("dog") and BEAST._atlases.has("wolf")

func _animal(kind: String) -> Node2D:
	var head: Node2D = Node2D.new()
	_field.add_child(head)
	var art: Node2D = BEAST.new()
	art.set("kind", kind)
	head.add_child(art)
	return head

func _lay(full: Vector2, bottom: float) -> void:
	var key: Vector2 = Vector2(full.x, bottom)
	if key == _laid_for:
		return
	_laid_for = key
	_woods.position = Vector2.ZERO
	_woods.size = full
	# the clearing: the middle of the scene, under the name and above the panel
	var top: float = 230.0 if mobile else 150.0
	var clearing: Rect2 = Rect2(full.x * 0.17, top + 20.0, full.x * 0.66, maxf(120.0, bottom - top - 90.0))
	var mat: ShaderMaterial = _woods.material as ShaderMaterial
	mat.set_shader_parameter("area_size", full)
	mat.set_shader_parameter("farm", Vector4(clearing.position.x, clearing.position.y, clearing.size.x, clearing.size.y))
	# the woods close in within about five tiles of the clearing: small tiles, so they do on screen
	mat.set_shader_parameter("tile", 15.0)
	_center = clearing.get_center() / ZOOM

# EVERY TURN IS EASED (the user: the animals turned abruptly -- nothing visible changes in one frame):
# an animal turns toward where it is heading at most TURN_RATE radians a second, smoothly.
const TURN_RATE: float = 2.6

func _turn(n: Node2D, want: float, delta: float) -> void:
	var diff: float = angle_difference(n.rotation, want)
	var step: float = TURN_RATE * delta
	n.rotation += clampf(diff * minf(1.0, delta * 5.0), -step, step)

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_lay(full, bottom)
	var spread: float = minf(full.x, bottom) / ZOOM * 0.16
	# the flock, grazing: each sheep wanders a little round its place, facing where it goes
	for k in _sheep.size():
		var a0: float = TAU * float(k) / float(_sheep.size()) + h01(k) * 0.8
		var rad: float = spread * (0.35 + 0.65 * h01(k + 20))
		var home: Vector2 = _center + Vector2(cos(a0), sin(a0)) * rad
		var w: float = t * (0.25 + 0.15 * h01(k + 40)) + float(k)
		var off: Vector2 = Vector2(sin(w), cos(w * 0.8)) * 6.0
		var vel: Vector2 = Vector2(cos(w), -0.8 * sin(w * 0.8))
		_sheep[k].position = home + off
		_turn(_sheep[k], vel.angle(), delta)
	# the wolves: out of the woods toward the flock, then back when the dog turns on them
	var u: float = fmod(t, CYCLE) / CYCLE
	var creep: float = smoothstep(0.0, 0.55, u) * (1.0 - smoothstep(0.62, 0.80, u))
	var sides: Array = [Vector2(-1.0, -0.35), Vector2(1.0, 0.45)]
	for k in 2:
		var from: Vector2 = _center + sides[k] * Vector2(full.x / ZOOM * 0.44, spread * 2.2)
		var to: Vector2 = _center + sides[k] * Vector2(spread * 1.9, spread * 0.8)
		var p: Vector2 = from.lerp(to, creep)
		var retreating: bool = u > 0.62 and u < 0.80
		_wolves[k].position = p + Vector2(0.0, sin(t * 3.0 + float(k)) * 1.5)
		_turn(_wolves[k], ((from - to) if retreating else (to - from)).angle(), delta)
	# the dog circles the flock, and in the middle of the cycle dashes at the nearer wolf
	var ring: float = spread * 1.45
	var ang: float = t * 0.9
	var circling: Vector2 = _center + Vector2(cos(ang), sin(ang)) * ring
	var dash: float = smoothstep(0.50, 0.62, u) * (1.0 - smoothstep(0.70, 0.86, u))
	var target: Vector2 = _wolves[0].position.lerp(_center, 0.35)
	var dp: Vector2 = circling.lerp(target, dash)
	var prev: Vector2 = _dog.position
	_dog.position = dp
	if prev.distance_to(dp) > 0.01:
		_turn(_dog, (dp - prev).angle(), delta)

# THE LAWN, drawn ONCE on its own layer under the woods (the user: "improve the grass under the sheep"):
# the pasture's yellow-green, lit from the top left, broad soft patches of lighter and darker grass, and
# thousands of fine blades in three greens, with clover and a few small flowers -- static, so the many
# strokes cost nothing after the first frame.
func _draw_lawn(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.38, 0.54, 0.24))
	# light from the top left across the field
	for k in 10:
		var c: Vector2 = Vector2(full.x * 0.30, full.y * 0.30)
		_ell_on(d, c, full.x * (1.1 - 0.09 * float(k)), full.y * (0.7 - 0.055 * float(k)), Color(0.80, 0.85, 0.45, 0.022))
	for k in 90:
		var c: Vector2 = Vector2(h01(k * 3) * full.x, h01(k * 3 + 1) * full.y)
		var lighter: bool = h01(k * 3 + 2) > 0.45
		_ell_on(d, c, 30.0 + 70.0 * h01(k + 300), 18.0 + 36.0 * h01(k + 400),
			Color(0.55, 0.68, 0.30, 0.13) if lighter else Color(0.22, 0.36, 0.14, 0.15))
	var greens: Array = [Color(0.24, 0.40, 0.15, 0.70), Color(0.47, 0.62, 0.27, 0.65), Color(0.62, 0.74, 0.36, 0.55)]
	for k in 4200:
		var p: Vector2 = Vector2(h01(k * 7 + 5) * full.x, h01(k * 7 + 6) * full.y)
		var lean: float = (h01(k * 7 + 2) - 0.5) * 5.0
		var hgt: float = 4.0 + 5.0 * h01(k * 7 + 3)
		d.draw_line(p, p + Vector2(lean, -hgt), greens[k % 3], 1.2)
	for k in 60:
		var p: Vector2 = Vector2(h01(k * 11 + 1) * full.x, h01(k * 11 + 2) * full.y)
		for j in 3:
			d.draw_circle(p + Vector2(cos(float(j) * 2.1), sin(float(j) * 2.1)) * 3.0, 2.6, Color(0.28, 0.48, 0.18, 0.8))
	for k in 45:
		var p: Vector2 = Vector2(h01(k * 13 + 4) * full.x, h01(k * 13 + 5) * full.y)
		var fc: Color = [Color(0.98, 0.97, 0.90), Color(0.98, 0.86, 0.30), Color(0.85, 0.70, 0.95)][k % 3]
		d.draw_circle(p, 2.2, fc)
		d.draw_circle(p, 0.9, Color(0.95, 0.75, 0.25))

func _ell_on(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Wolves", "Guard your flock from the wolves", Color(0.96, 0.93, 0.84), Color(0.05, 0.08, 0.04),
		Color(0.0, 0.0, 0.0, 0.45))
