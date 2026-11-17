extends "res://scripts/menu_poster.gd"

# POLKA DOTS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): FIREFLIES IN A MEADOW AT NIGHT.
# A deep blue sky with a few stars and a low moon's glow, a dark tree line, the meadow falling away under it, tall
# grass and seed heads black against it at the foot. The fireflies drift and blink, each round its own place; every
# few seconds they gather -- a scatter of dots that turns out to be the outline of a LETTER (or a digit), held a
# moment, glowing steadily, then they drift apart again and the next one forms somewhere else. Dots that make a
# character, which is the game. The meadow is a still layer (baked: menu_still_0_<m|d>.webp); the fireflies are
# live, each a small glow picture. Made up, never the board.

# the characters, as strokes in a box 1 wide and 1.4 tall (y down)
const GLYPHS: Dictionary = {
	"A": [[Vector2(0.0, 1.4), Vector2(0.5, 0.0), Vector2(1.0, 1.4)], [Vector2(0.22, 0.86), Vector2(0.78, 0.86)]],
	"K": [[Vector2(0.1, 0.0), Vector2(0.1, 1.4)], [Vector2(0.9, 0.0), Vector2(0.1, 0.82)], [Vector2(0.36, 0.6), Vector2(0.95, 1.4)]],
	"7": [[Vector2(0.05, 0.0), Vector2(0.95, 0.0), Vector2(0.38, 1.4)]],
	"4": [[Vector2(0.72, 1.4), Vector2(0.72, 0.0), Vector2(0.02, 0.95), Vector2(0.98, 0.95)]],
	"E": [[Vector2(0.9, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 1.4), Vector2(0.9, 1.4)], [Vector2(0.1, 0.7), Vector2(0.72, 0.7)]],
	"R": [[Vector2(0.1, 1.4), Vector2(0.1, 0.0), Vector2(0.58, 0.0), Vector2(0.84, 0.1), Vector2(0.92, 0.35), Vector2(0.84, 0.6), Vector2(0.58, 0.7), Vector2(0.1, 0.7)], [Vector2(0.48, 0.7), Vector2(0.95, 1.4)]],
	"Z": [[Vector2(0.08, 0.0), Vector2(0.92, 0.0), Vector2(0.08, 1.4), Vector2(0.92, 1.4)]],
}
const ORDER: Array = ["A", "7", "K", "4", "R", "E", "Z"]
const N: int = 44
const CYCLE: float = 8.0
const FLY: Color = Color(0.85, 1.0, 0.45)

var _glow: Texture2D = null
var _flies: Control = null
var _home: Array = []          # each firefly's place (0..1 in the meadow box)
var _phase: Array = []
var _letter_pts: Dictionary = {}   # glyph -> its N points, in the unit box, matched to the fireflies

func _setup() -> void:
	add_still(func(d: Control) -> void: _draw_meadow(d))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.18, Color(1, 1, 1, 0.85))
	g.add_point(0.45, Color(1, 1, 1, 0.22))
	gt.gradient = g
	_glow = gt
	for i in N:
		_home.append(Vector2(h01(i * 3 + 1), h01(i * 3 + 2)))
		_phase.append(h01(i * 3 + 3) * TAU)
	for key in GLYPHS.keys():
		_letter_pts[key] = _sample(GLYPHS[key])
	_flies = Control.new()
	_flies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flies.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flies.draw.connect(func() -> void: _draw_flies(_flies))
	add_child(_flies)

# N points spread evenly along a glyph's strokes, a little irregular (a scatter, not a font), each matched to the
# firefly whose own place is nearest the same side, so they cross as little as possible on the way in
func _sample(strokes: Array) -> Array:
	var segs: Array = []
	var total: float = 0.0
	for st in strokes:
		var pts: Array = st
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			segs.append([a, b, total])
			total += a.distance_to(b)
	var out: Array = []
	for i in N:
		var s: float = (float(i) + 0.5) / float(N) * total
		var p: Vector2 = Vector2.ZERO
		for sg in segs:
			var a2: Vector2 = sg[0]
			var b2: Vector2 = sg[1]
			var l0: float = float(sg[2])
			var ln: float = a2.distance_to(b2)
			if s >= l0 and s <= l0 + ln + 0.0001:
				p = a2.lerp(b2, (s - l0) / maxf(ln, 0.0001))
				break
		p += Vector2(h01(i * 7 + 5) - 0.5, h01(i * 7 + 6) - 0.5) * 0.07
		out.append(p)
	# match: both sorted left to right
	var order_f: Array = range(N)
	order_f.sort_custom(func(x: int, y: int) -> bool: return (_home[x] as Vector2).x < (_home[y] as Vector2).x)
	var order_p: Array = range(N)
	order_p.sort_custom(func(x: int, y: int) -> bool: return (out[x] as Vector2).x < (out[y] as Vector2).x)
	var matched: Array = []
	matched.resize(N)
	for k in N:
		matched[order_f[k]] = out[order_p[k]]
	return matched

# the meadow's box on screen: under the name, above the panel
func _box(full: Vector2, bottom: float) -> Rect2:
	var top: float = 230.0 if mobile else 140.0
	return Rect2(Vector2(0.0, top), Vector2(full.x, bottom - top))

func _tick(_delta: float) -> void:
	_flies.queue_redraw()

func _draw_flies(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var box: Rect2 = _box(full, bottom)
	var cyc: int = int(floor(t / CYCLE))
	var u: float = fmod(t, CYCLE)
	var glyph: String = ORDER[posmod(cyc, ORDER.size())]
	var pts: Array = _letter_pts[glyph]
	# the letter's place: its own spot each time, inside the meadow box
	var lh: float = minf(box.size.y * 0.62, 300.0)
	var lw: float = lh / 1.4
	var cx: float = box.position.x + box.size.x * (0.30 + 0.40 * h01(cyc * 5 + 1))
	var cy: float = box.position.y + box.size.y * (0.42 + 0.10 * h01(cyc * 5 + 2))
	var origin: Vector2 = Vector2(cx - lw * 0.5, cy - lh * 0.5)
	var gather: float = smoothstep(1.6, 3.6, u) * (1.0 - smoothstep(6.0, 7.8, u))
	for i in N:
		var hm: Vector2 = _home[i]
		var ph: float = float(_phase[i])
		# drifting round its place: slow loops, a little lift
		var wander: Vector2 = box.position + Vector2(hm.x * box.size.x, (0.12 + hm.y * 0.80) * box.size.y)
		wander += Vector2(sin(t * 0.37 + ph) * 26.0 + sin(t * 0.91 + ph * 2.0) * 9.0, cos(t * 0.29 + ph) * 18.0 + sin(t * 1.3 + ph) * 6.0)
		var target: Vector2 = origin + (pts[i] as Vector2) * lw + Vector2(sin(t * 1.7 + ph) * 1.5, cos(t * 1.4 + ph) * 1.5)
		# each comes in at its own pace, so the shape gathers rather than snaps
		var own: float = clampf(gather * 1.25 - 0.25 * h01(i + 90), 0.0, 1.0)
		own = own * own * (3.0 - 2.0 * own)
		var p: Vector2 = wander.lerp(target, own)
		# the blink: wandering, each glows and dims on its own rhythm; in the letter, they glow together
		var blink: float = 0.35 + 0.65 * maxf(0.0, sin(t * (1.1 + 0.5 * h01(i + 40)) + ph)) ** 2
		var a: float = lerpf(blink, 0.95, own)
		var r: float = (11.0 if mobile else 9.0) * (0.8 + 0.4 * a)
		d.draw_texture_rect(_glow, Rect2(p - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(FLY, 0.55 * a))
		d.draw_circle(p, 2.2 if mobile else 1.8, Color(1.0, 1.0, 0.85, a))

# --- the meadow (a still layer) -------------------------------------------------------------------------------------

func _draw_meadow(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var box: Rect2 = _box(full, bottom)
	var horizon: float = box.position.y + box.size.y * 0.30
	# the sky: deep blue to a faint green-blue glow at the horizon, a few stars, the moon's halo low at the right
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(full.x, 0.0), Vector2(full.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([Color(0.02, 0.03, 0.08), Color(0.02, 0.03, 0.08), Color(0.08, 0.13, 0.20), Color(0.08, 0.13, 0.20)]))
	for k in 70:
		var sp: Vector2 = Vector2(h01(k + 300) * full.x, h01(k + 400) * horizon * 0.95)
		d.draw_circle(sp, 0.6 + 1.0 * h01(k + 500), Color(1, 1, 1, 0.25 + 0.5 * h01(k + 600)))
	var moon: Vector2 = Vector2(full.x * 0.80, horizon - box.size.y * 0.12)
	for k in 12:
		d.draw_circle(moon, 90.0 - float(k) * 6.5, Color(0.70, 0.80, 1.0, 0.025))
	d.draw_circle(moon, 22.0, Color(0.92, 0.94, 0.88))
	d.draw_circle(moon + Vector2(-6, -5), 5.0, Color(0.82, 0.84, 0.80))
	d.draw_circle(moon + Vector2(7, 6), 3.5, Color(0.84, 0.86, 0.82))
	# the meadow under it, falling away from the tree line into the dark at the foot
	d.draw_polygon(PackedVector2Array([Vector2(0.0, horizon), Vector2(full.x, horizon), Vector2(full.x, full.y), Vector2(0.0, full.y)]),
		PackedColorArray([Color(0.09, 0.16, 0.14), Color(0.09, 0.16, 0.14), Color(0.01, 0.03, 0.02), Color(0.01, 0.03, 0.02)]))
	# moonlight lying on the meadow below the moon, soft
	for k in 10:
		d.draw_set_transform(Vector2(moon.x - 40.0, horizon + box.size.y * 0.30), 0.0, Vector2(1.0, 0.30))
		d.draw_circle(Vector2.ZERO, 300.0 - float(k) * 26.0, Color(0.55, 0.70, 0.75, 0.018))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the tree line: crowns of different sizes, a far row hazed and a near one black
	for row in 2:
		var col: Color = Color(0.05, 0.09, 0.11) if row == 0 else Color(0.015, 0.03, 0.03)
		var base_y: float = horizon + (6.0 if row == 0 else 20.0)
		var x: float = -30.0
		var k: int = row * 100
		while x < full.x + 40.0:
			var r: float = (26.0 if row == 0 else 34.0) * (0.7 + 0.6 * h01(k + 700))
			var cyy: float = base_y - r * (0.8 + 0.8 * h01(k + 800))
			d.draw_circle(Vector2(x, cyy), r, col)
			d.draw_rect(Rect2(x - r, cyy, r * 2.0, base_y - cyy + 4.0), col)
			x += r * 1.1
			k += 1
	# MIST lying along the foot of the trees, so the meadow runs into them without an edge
	for k in 26:
		var mx: float = h01(k + 900) * full.x
		var my: float = horizon + 22.0 + 18.0 * h01(k + 950)
		d.draw_set_transform(Vector2(mx, my), 0.0, Vector2(1.0, 0.22))
		for j in 5:
			d.draw_circle(Vector2.ZERO, (120.0 + 80.0 * h01(k + 980)) * (1.0 - float(j) * 0.18), Color(0.45, 0.58, 0.62, 0.024))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# far grass texture: faint strokes over the meadow
	for k in 500:
		var gx: float = h01(k + 1000) * full.x
		var gy: float = horizon + 24.0 + h01(k + 1100) * (full.y - horizon - 24.0)
		var depth: float = (gy - horizon) / maxf(1.0, full.y - horizon)
		var hgt: float = 3.0 + 14.0 * depth
		d.draw_line(Vector2(gx, gy), Vector2(gx + 2.0 * (h01(k + 1200) - 0.5) * hgt, gy - hgt), Color(0.16, 0.28, 0.20, 0.45 * (1.0 - depth * 0.5)), 1.0)
	# THE NEAR GRASS at the foot: tall curving blades and seed heads, black against the meadow
	var foot: float = bottom + 10.0
	for k in 160:
		var bx: float = h01(k + 1300) * full.x
		var hgt2: float = 50.0 + 140.0 * h01(k + 1400)
		var lean: float = (h01(k + 1500) - 0.5) * hgt2 * 0.5
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 7:
			var v: float = float(j) / 6.0
			pts.append(Vector2(bx + lean * v * v, foot - hgt2 * v))
		d.draw_polyline(pts, Color(0.0, 0.015, 0.01), 2.6 - 1.4 * h01(k + 1600), true)
		if k % 9 == 0:
			d.draw_set_transform(pts[6], atan2(lean, hgt2), Vector2(1.0, 2.4))
			d.draw_circle(Vector2.ZERO, 3.2, Color(0.0, 0.015, 0.01))
			d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	d.draw_rect(Rect2(0.0, foot, full.x, full.y - foot), Color(0.0, 0.015, 0.01))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Polka Dots", "Identify the scatter of dots", Color(0.90, 1.0, 0.60), Color(0.04, 0.08, 0.06),
		Color(0.85, 1.0, 0.45, 0.25))
