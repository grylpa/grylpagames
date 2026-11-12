class_name MmmHallDecor
extends Node2D

# THE GREAT HALL'S FURNISHINGS (2026-11-12, third set): COLONNADES of fluted marble columns, two-tier
# FOUNTAINS and clipped TOPIARY are real 3-D, rendered once (hall_art.gd) and seen from a high
# three-quarter angle, each on a soft floor shadow drawn here (the compatibility renderer cannot put a
# 3-D shadow on a see-through floor); REFLECTING POOLS and CARPETS lie flat and are shaders
# (hall_pool.gdshader, hall_carpet.gdshader). Flat code shapes came first: "very very sloppy".
# level._place_hall_decor() puts them on the hall well clear of the rooms; `cells` is the footprint.

enum Kind { COLONNADE, CARPET, FOUNTAIN, POOL, TREE }

var kind: int = Kind.CARPET
var cells: Vector2i = Vector2i.ONE
var seed_v: float = 0.0
var spacing: int = 1                    # a colonnade's columns, this many cells apart

const T: float = 40.0
const SHADOW_DIR: Vector2 = Vector2(0.62, 0.80)        # away from the light (top left)
const PITCH_SIN: float = 0.848                          # sin(MmmHallArt.PITCH_DEG): a circle on the floor, seen
const PITCH_COS: float = 0.530                          # cos: how far up the screen a height rises

var _t: float = 0.0
var _tex: Texture2D = null
static var _blob: GradientTexture2D = null


func _ready() -> void:
	_t = seed_v * 10.0
	if kind == Kind.CARPET or kind == Kind.POOL:
		var r: ColorRect = ColorRect.new()
		var sz: Vector2 = Vector2(cells) * T - Vector2(8, 8)
		var m: ShaderMaterial = ShaderMaterial.new()
		if kind == Kind.CARPET:
			m.shader = preload("res://mmm/scripts/hall_carpet.gdshader")
			m.set_shader_parameter("fringe", 7.0)
		else:
			m.shader = preload("res://mmm/scripts/hall_pool.gdshader")
			m.set_shader_parameter("rim", 9.0)
		m.set_shader_parameter("size", sz)
		m.set_shader_parameter("seed", seed_v)
		r.material = m
		r.size = sz
		r.position = -sz * 0.5
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		queue_redraw()


func _process(delta: float) -> void:
	if kind == Kind.CARPET or kind == Kind.POOL:
		return
	if _tex == null:
		_tex = MmmHallArt.texture(self, _art_kind())
		if _tex != null:
			queue_redraw()
	if kind == Kind.FOUNTAIN:
		_t += delta
		queue_redraw()


func _art_kind() -> int:
	match kind:
		Kind.COLONNADE:
			return MmmHallArt.Kind.COLUMN
		Kind.FOUNTAIN:
			return MmmHallArt.Kind.FOUNTAIN
		_:
			return MmmHallArt.Kind.TOPIARY


# a soft shadow on the floor: a blurred ellipse, stretched away from the light by `cast`
func _shadow(at: Vector2, rx: float, ry: float, cast: float, alpha: float) -> void:
	if _blob == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.55, Color(0, 0, 0, 0.75))
		_blob = GradientTexture2D.new()
		_blob.gradient = g
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	# ONE soft shape: the foot's ellipse drawn out along the light into a long oval (stacked copies along
	# the way showed as stripes)
	var mid: Vector2 = at + SHADOW_DIR * cast * 0.5
	draw_set_transform(mid, SHADOW_DIR.angle(), Vector2.ONE)
	var half: Vector2 = Vector2(cast * 0.5 + rx, ry)
	draw_texture_rect(_blob, Rect2(-half, half * 2.0), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	match kind:
		Kind.CARPET:
			# the carpet's own slight shadow: it lies on the floor with some thickness
			var sz: Vector2 = Vector2(cells) * T - Vector2(8, 8)
			draw_rect(Rect2(-sz * 0.5 + Vector2(2.5, 3.5), sz), Color(0, 0, 0, 0.35))
		Kind.POOL:
			var sz2: Vector2 = Vector2(cells) * T - Vector2(8, 8)
			draw_rect(Rect2(-sz2 * 0.5 + Vector2(4, 6), sz2), Color(0, 0, 0, 0.40))
		Kind.COLONNADE:
			_draw_colonnade()
		Kind.FOUNTAIN:
			_draw_fountain()
		_:
			_draw_piece(Vector2.ZERO, 0.42 * T, 1.4 * T)


# one rendered piece standing at `at`, its shadow first
func _draw_piece(at: Vector2, foot_r: float, cast: float) -> void:
	_shadow(at, foot_r, foot_r * PITCH_SIN, cast, 0.55)
	if _tex == null:
		return
	var sz: Vector2 = MmmHallArt.view_size(_art_kind())
	draw_texture_rect(_tex, Rect2(at - sz * 0.5, sz), false)


func _draw_colonnade() -> void:
	var along: Vector2 = Vector2(1, 0) if cells.x >= cells.y else Vector2(0, 1)
	var span: int = maxi(cells.x, cells.y)
	var n: int = (span - 1) / maxi(1, spacing) + 1
	var step: float = float(spacing) * T
	var first: Vector2 = -along * (float(n - 1) * step * 0.5)
	# back to front, so a nearer column stands in front of the one behind it
	for i in n:
		_shadow(first + along * float(i) * step, 0.30 * T, 0.30 * T * PITCH_SIN, 2.6 * T, 0.55)
	for i in n:
		var c: Vector2 = first + along * float(i) * step
		if _tex != null:
			var sz: Vector2 = MmmHallArt.view_size(MmmHallArt.Kind.COLUMN)
			draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false)


func _draw_fountain() -> void:
	_draw_piece(Vector2.ZERO, 1.42 * T, 1.0 * T)
	if _tex == null:
		return
	# rings spreading on the basin's water, outside the falling sheet: ellipses, as the camera sees a
	# circle on the water (its surface 0.40 cells up)
	var c: Vector2 = Vector2(0.0, -0.40 * PITCH_COS * T)
	for i in 3:
		var ph: float = fmod(_t * 0.35 + float(i) / 3.0, 1.0)
		var r: float = (0.92 + ph * 0.32) * T
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 49:
			var a: float = TAU * float(k) / 48.0
			pts.append(c + Vector2(cos(a) * r, sin(a) * r * PITCH_SIN))
		draw_polyline(pts, Color(0.80, 0.92, 1.0, 0.30 * sin(ph * PI)), 1.6, true)
