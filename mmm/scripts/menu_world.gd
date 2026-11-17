extends "res://scripts/menu_poster.gd"

# MIND PALACE'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a palace of the mind
# floating in the game's night sky (palace_sky.gdshader) on an island of rock, with two small islets
# beside it, each with a turret, and glowing stepping stones floating up to its gate; its windows light
# one after another, each in a room's color -- remembered one by one -- until the whole palace glows,
# then they go dark and it begins again.
#
# STILL WHERE IT IS HARD-EDGED (the user: "jitter and flicker in the movement"): the palace, the rock and
# the islets are drawn ONCE on a layer that is never redrawn, and nothing with a hard edge moves -- only
# soft things do (mist, slow twinkles, the windows' light, the flags). Made up, never the board.

const SKY: Shader = preload("res://mmm/scripts/palace_sky.gdshader")
const ROOM_COLORS: Array = [Color(0.95, 0.32, 0.32), Color(0.32, 0.64, 0.98), Color(0.42, 0.88, 0.46),
	Color(0.99, 0.80, 0.30), Color(0.78, 0.48, 0.98), Color(0.32, 0.88, 0.88), Color(1.0, 0.58, 0.26)]
const STONE: Color = Color(0.33, 0.31, 0.45)
const STONE_LIT: Color = Color(0.47, 0.45, 0.62)
const STONE_DARK: Color = Color(0.22, 0.20, 0.31)
const ROOF: Color = Color(0.22, 0.17, 0.36)
const ROOF_LIT: Color = Color(0.34, 0.27, 0.52)
const ROCK: Color = Color(0.17, 0.14, 0.23)
const CYCLE: float = 11.0

var _sky: ColorRect = null
var _still: Control = null      # the palace, drawn once
var _live: Control = null       # the lights and the mist, every frame
var _windows: Array = []        # Rect2 in screen px, filled when the still layer is drawn
var _flags: Array = []          # Vector2: the top of each flagpole
var _stones: Array = []         # Vector2: the stepping stones' centers
var _laid_for: Vector2 = Vector2.ZERO

func _setup() -> void:
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SKY
	_sky.material = m
	add_child(_sky)
	var back: Control = Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.draw.connect(func() -> void: _draw_back(back))
	add_child(back)
	_still = Control.new()
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_still.draw.connect(_draw_still)
	add_child(_still)
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.set_anchors_preset(Control.PRESET_FULL_RECT)
	_live.draw.connect(_draw_live)
	add_child(_live)
	set_meta("back", back)

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var key: Vector2 = Vector2(full.x, scene_bottom)
	if key != _laid_for:
		_laid_for = key
		_sky.position = Vector2.ZERO
		_sky.size = full
		_still.queue_redraw()
	(get_meta("back") as Control).queue_redraw()
	_live.queue_redraw()

func _box() -> Rect2:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 250.0 if mobile else 160.0
	var h: float = maxf(120.0, bottom - top - 110.0)
	var w: float = minf(full.x * 0.70, h * 1.05)
	return Rect2((full.x - w) * 0.5, top, w, h)

func _p(b: Rect2, x: float, y: float) -> Vector2:
	return (b.position + Vector2(b.size.x * x, b.size.y * y)).round()

# --- behind the palace: stars (slow twinkle), the moon, a violet glow ----------------------------------

func _draw_back(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var b: Rect2 = _box()
	for k in 110:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * full.y * 0.80)
		var tw: float = 0.5 + 0.5 * sin(t * (0.25 + 0.5 * h01(k + 9)) + float(k) * 1.7)
		d.draw_circle(sp, 0.8 + 1.3 * h01(k * 5 + 3), Color(0.92, 0.90, 1.0, 0.30 + 0.45 * tw * h01(k * 5 + 4)))
	var moon: Vector2 = Vector2(full.x * 0.83, b.position.y - 40.0)
	for g in 7:
		d.draw_circle(moon, 90.0 - float(g) * 11.0, Color(0.85, 0.82, 1.0, 0.035))
	d.draw_circle(moon, 28.0, Color(0.96, 0.94, 1.0))
	d.draw_circle(moon + Vector2(10.0, -6.0), 24.0, Color(0.09, 0.07, 0.17, 0.94))
	for g in 9:
		_ell(d, b.get_center() + Vector2(0.0, b.size.y * 0.05), b.size.x * (0.95 - 0.08 * float(g)), b.size.y * (0.70 - 0.06 * float(g)),
			Color(0.55, 0.40, 0.95, 0.032))

# --- the palace, once ---------------------------------------------------------------------------------

func _draw_still() -> void:
	var b: Rect2 = _box()
	var d: Control = _still
	_windows.clear()
	_flags.clear()
	_stones.clear()
	# two islets, each with a turret and roots hanging under it
	for side in [-1.0, 1.0]:
		var c: Vector2 = Vector2(b.get_center().x + side * b.size.x * 0.60, b.position.y + b.size.y * (0.66 if side < 0.0 else 0.52))
		var iw: float = b.size.x * 0.13
		_rock(d, c, iw, iw * 0.55)
		var turret: Rect2 = Rect2((c + Vector2(-iw * 0.18, -iw * 0.62)).round(), Vector2(iw * 0.36, iw * 0.62).round())
		_tower(d, turret, iw * 0.30, 1)
	# the main rock
	_rock(d, _p(b, 0.5, 0.88), b.size.x * 0.56, b.size.y * 0.34)
	# the towers, back to front: two outer, two inner, the keep, the spire
	_tower(d, Rect2(_p(b, 0.02, 0.36), Vector2(b.size.x * 0.15, b.size.y * 0.52)), b.size.x * 0.20, 2)
	_tower(d, Rect2(_p(b, 0.83, 0.36), Vector2(b.size.x * 0.15, b.size.y * 0.52)), b.size.x * 0.20, 2)
	_tower(d, Rect2(_p(b, 0.16, 0.24), Vector2(b.size.x * 0.13, b.size.y * 0.64)), b.size.x * 0.17, 3)
	_tower(d, Rect2(_p(b, 0.71, 0.24), Vector2(b.size.x * 0.13, b.size.y * 0.64)), b.size.x * 0.17, 3)
	var keep: Rect2 = Rect2(_p(b, 0.27, 0.42), Vector2(b.size.x * 0.46, b.size.y * 0.46))
	_wall(d, keep)
	_battlements(d, keep)
	for r in 2:
		for c in 4:
			_window(d, Rect2(_p(b, 0.315 + 0.11 * float(c), 0.50 + 0.15 * float(r)), Vector2(b.size.x * 0.045, b.size.y * 0.085)))
	_tower(d, Rect2(_p(b, 0.42, 0.06), Vector2(b.size.x * 0.16, b.size.y * 0.38)), b.size.x * 0.22, 2)
	# the gate, and the stepping stones floating down from it
	var g: Rect2 = Rect2(_p(b, 0.45, 0.74), Vector2(b.size.x * 0.10, b.size.y * 0.14))
	d.draw_rect(g, Color(0.08, 0.06, 0.13))
	d.draw_circle(Vector2(g.get_center().x, g.position.y), g.size.x * 0.5, Color(0.08, 0.06, 0.13))
	for k in 6:
		var u: float = float(k) / 5.0
		_stones.append((_p(b, 0.5, 0.90) + Vector2(sin(u * 3.2) * b.size.x * 0.22, u * b.size.y * 0.42)).round())

func _rock(d: Control, c: Vector2, w: float, h: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(c + Vector2(-w, 0.0))
	pts.append(c + Vector2(w, 0.0))
	var n: int = 9
	for k in n:
		var u: float = 1.0 - float(k) / float(n - 1)
		var x: float = lerpf(-w, w, u) * (1.0 - 0.15 * float(k % 2))
		var y: float = h * sin(u * PI) * (0.75 + 0.35 * h01(int(c.x) + k))
		pts.append(c + Vector2(x * (0.92 - 0.25 * sin(u * PI)), y))
	d.draw_colored_polygon(pts, ROCK)
	d.draw_line(c + Vector2(-w, 0.0), c + Vector2(w, 0.0), Color(0.42, 0.37, 0.56), 3.0)
	# strata, and roots hanging
	for k in 3:
		var yy: float = h * (0.18 + 0.2 * float(k))
		d.draw_line(c + Vector2(-w * (0.8 - 0.2 * float(k)), yy), c + Vector2(w * (0.7 - 0.2 * float(k)), yy + 4.0), Color(0.10, 0.08, 0.15), 2.0)
	for k in 5:
		var x0: float = lerpf(-w * 0.5, w * 0.5, float(k) / 4.0)
		var y0: float = h * 0.6 * sin((x0 / w * 0.5 + 0.5) * PI)
		d.draw_polyline(PackedVector2Array([c + Vector2(x0, y0), c + Vector2(x0 + 6.0, y0 + 16.0), c + Vector2(x0 - 3.0, y0 + 30.0)]), Color(0.13, 0.11, 0.18), 2.0)

func _wall(d: Control, r: Rect2) -> void:
	d.draw_rect(r, STONE)
	d.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.30, r.size.y)), STONE_LIT)
	d.draw_rect(Rect2(r.end.x - r.size.x * 0.18, r.position.y, r.size.x * 0.18, r.size.y), STONE_DARK)
	# stone courses
	var y: float = r.position.y + 12.0
	var row: int = 0
	while y < r.end.y:
		d.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.12, 0.10, 0.18, 0.35), 1.0)
		var x: float = r.position.x + (9.0 if row % 2 == 0 else 0.0)
		while x < r.end.x:
			d.draw_line(Vector2(x, y), Vector2(x, y - 12.0), Color(0.12, 0.10, 0.18, 0.25), 1.0)
			x += 18.0
		y += 12.0
		row += 1

func _battlements(d: Control, r: Rect2) -> void:
	var n: int = maxi(3, int(r.size.x / 14.0)) | 1
	for k in n:
		if k % 2 == 0:
			d.draw_rect(Rect2(r.position.x + r.size.x * float(k) / float(n), r.position.y - 8.0, r.size.x / float(n), 8.0),
				STONE_LIT if k < n / 3 else STONE)

func _tower(d: Control, r: Rect2, roof_w: float, windows: int) -> void:
	r = Rect2(r.position.round(), r.size.round())
	_wall(d, r)
	# a conical roof, lit on its left
	var cx: float = r.get_center().x
	var base_y: float = r.position.y + 2.0
	var tip: Vector2 = Vector2(cx, r.position.y - roof_w * 1.15).round()
	d.draw_colored_polygon(PackedVector2Array([Vector2(cx - roof_w * 0.5, base_y), Vector2(cx + roof_w * 0.5, base_y), tip]), ROOF)
	d.draw_colored_polygon(PackedVector2Array([Vector2(cx - roof_w * 0.5, base_y), Vector2(cx - roof_w * 0.1, base_y), tip]), ROOF_LIT)
	d.draw_line(Vector2(cx - roof_w * 0.5, base_y), Vector2(cx + roof_w * 0.5, base_y), Color(0.10, 0.08, 0.16), 3.0)
	d.draw_line(tip, tip + Vector2(0.0, -16.0), Color(0.85, 0.80, 0.95), 2.0)
	_flags.append(tip + Vector2(0.0, -16.0))
	for k in windows:
		var wh: float = minf(r.size.y * 0.14, r.size.x * 0.55)
		var ww: float = wh * 0.55
		_window(d, Rect2(Vector2(cx - ww * 0.5, r.position.y + r.size.y * (0.16 + 0.28 * float(k))), Vector2(ww, wh)))

func _window(d: Control, r: Rect2) -> void:
	r = Rect2(r.position.round(), r.size.round())
	d.draw_rect(r.grow(2.0), STONE_DARK)
	d.draw_rect(r, Color(0.07, 0.06, 0.12))
	d.draw_circle(Vector2(r.get_center().x, r.position.y), r.size.x * 0.5, Color(0.07, 0.06, 0.12))
	_windows.append(r)

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- what moves: the windows' light, the stones' glow, the flags, the mist ------------------------------

func _draw_live() -> void:
	var d: Control = _live
	var b: Rect2 = _box()
	var u: float = fmod(t, CYCLE) / CYCLE
	var n: int = _windows.size()
	var fade: float = 1.0 - smoothstep(0.86, 0.98, u)
	for k in n:
		# each window eases on over half a second, in its turn
		var on_at: float = 0.04 + 0.70 * float(k) / float(maxi(1, n))
		var a: float = smoothstep(on_at, on_at + 0.04, u) * fade
		if a <= 0.0:
			continue
		var r: Rect2 = _windows[(k * 7) % n]
		var c: Color = ROOM_COLORS[k % ROOM_COLORS.size()]
		for g in 5:
			d.draw_rect(r.grow(12.0 - float(g) * 2.5), Color(c, 0.05 * a))
		d.draw_rect(r, Color(c, a))
		d.draw_circle(Vector2(r.get_center().x, r.position.y), r.size.x * 0.5, Color(c, a))
		d.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.22 * a))
	# the stepping stones, glowing softly in turn up to the gate
	for k in _stones.size():
		var sp: Vector2 = _stones[_stones.size() - 1 - k]
		var glow: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 1.2 - float(k) * 0.7))
		for g in 4:
			_ell(d, sp, 30.0 - float(g) * 6.0, 10.0 - float(g) * 2.0, Color(0.70, 0.60, 1.0, 0.07 * glow))
		_ell(d, sp, 18.0, 6.0, Color(0.82, 0.76, 1.0, 0.55 + 0.35 * glow))
	# the flags
	for k in _flags.size():
		var top: Vector2 = _flags[k]
		var w1: float = sin(t * 2.2 + float(k)) * 3.0
		d.draw_colored_polygon(PackedVector2Array([top, top + Vector2(18.0, 4.0 + w1), top + Vector2(0.0, 9.0)]), ROOM_COLORS[k % ROOM_COLORS.size()])
	# mist drifting under the island
	for k in 6:
		var mx: float = fmod(t * (8.0 + float(k) * 3.0) + float(k) * 110.0, b.size.x * 1.8) - b.size.x * 0.4
		_ell(d, Vector2(b.position.x + mx, b.end.y + 20.0 + float(k) * 12.0), 110.0, 14.0, Color(0.72, 0.68, 0.92, 0.07))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Mind Palace", "Explore and remember the room colors", Color(0.90, 0.84, 1.0), Color(0.10, 0.06, 0.20),
		Color(0.60, 0.45, 1.0, 0.30))
