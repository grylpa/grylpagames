extends "res://scripts/menu_poster.gd"

# WERIS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): A WALL OF PORTRAITS AND A MAGNIFYING
# GLASS. A museum wall in deep green damask, hung edge to edge with small portraits in gilt frames -- the game's own
# people -- under a gallery light; a brass-rimmed magnifying glass glides over them, the faces under it truly
# enlarged (the wall drawn again inside the lens, clipped to the glass), searching, and comes to rest on ONE face:
# the person on the card pinned at the corner ("Find"), and a green ring shows it found. Then the card changes and
# the search goes on. The wall is a still layer (baked: menu_still_0_<m|d>.webp); the lens and the card are live,
# their photos loaded on threads (the lens fades in when they are). Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const CYCLE: float = 7.0
const ZOOM: float = 1.9
const ASPECT: float = 288.0 / 224.0

var _people: Array = []
var _tex: Dictionary = {}                 # person -> Texture2D (the lens and the card; loaded on threads)
var _lens: Control = null                 # clips to the glass
var _inner: Control = null                # the wall again, enlarged, inside it
var _rim: Control = null
var _find: Node2D = null
var _find_for: int = -1
var _lens_a: float = 0.0

func _setup() -> void:
	var dir: DirAccess = DirAccess.open("res://art/people")
	if dir != null:
		for f in dir.get_files():
			var fn: String = f.trim_suffix(".import")
			if fn.ends_with(".jpg") and not _people.has(fn.get_basename()):
				_people.append(fn.get_basename())
	_people.sort()
	add_still(func(d: Control) -> void: _draw_wall(d, Vector2.ZERO, 1.0, Rect2(), false))
	_lens = Control.new()
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_lens.draw.connect(func() -> void:
		var r: float = _lens.size.x * 0.5
		_lens.draw_circle(Vector2(r, r), r, Color.WHITE))
	add_child(_lens)
	_inner = Control.new()
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.draw.connect(func() -> void: _draw_inner(_inner))
	_lens.add_child(_inner)
	_rim = Control.new()
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rim.draw.connect(func() -> void: _draw_rim(_rim))
	add_child(_rim)
	_find = CARD.new()
	add_child(_find)
	_find.call("set_photo", true)
	_find.visible = false
	for k in _cells_n():
		_request(_who(k))

func _request(person: String) -> void:
	var path: String = "res://art/people/%s.jpg" % person
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and not _tex.has(person):
		ResourceLoader.load_threaded_request(path)

func _photo(person: String) -> Texture2D:
	if _tex.has(person):
		return _tex[person]
	var path: String = "res://art/people/%s.jpg" % person
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		_tex[person] = ResourceLoader.load_threaded_get(path)
		return _tex[person]
	return null

# --- the wall's layout ------------------------------------------------------------------------------------------

func _cols() -> int:
	return 5 if mobile else 7

func _box(full: Vector2, bottom: float) -> Rect2:
	var top: float = 220.0 if mobile else 132.0
	return Rect2(Vector2(14.0, top), Vector2(full.x - 28.0, bottom - top + 30.0))

func _cell_size(full: Vector2, bottom: float) -> Vector2:
	var cw: float = _box(full, bottom).size.x / float(_cols())
	return Vector2(cw, cw * ASPECT)

func _rows(full: Vector2, bottom: float) -> int:
	return int(ceil(_box(full, bottom).size.y / _cell_size(full, bottom).y)) + 1

func _cells_n() -> int:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	return _cols() * _rows(full, bottom)

func _who(k: int) -> String:
	return _people[posmod(k * 11 + 4, _people.size())] if not _people.is_empty() else ""

# a portrait's frame: its cell, a little smaller, a little offset (hung by hand)
func _frame_rect(k: int, full: Vector2, bottom: float) -> Rect2:
	var box: Rect2 = _box(full, bottom)
	var cs: Vector2 = _cell_size(full, bottom)
	var col: int = k % _cols()
	var row: int = k / _cols()
	# SALON HANGING (a regular grid of faces read like the game's board): sizes from small to large, every other
	# row shifted half a frame, each hung a little off its place
	var shrink: float = 0.62 + 0.30 * h01(k + 20)
	var sz: Vector2 = cs * shrink
	var c: Vector2 = box.position + Vector2((float(col) + 0.5 + (0.5 if row % 2 == 1 else 0.0) - 0.25) * cs.x, (float(row) + 0.5) * cs.y)
	c += Vector2(h01(k + 40) - 0.5, h01(k + 60) - 0.5) * cs * (1.0 - shrink) * 0.9
	return Rect2(c - sz * 0.5, sz)

# the frame's kind: 0 gilt, 1 walnut, 2 black; and whether the portrait is an oval
func _frame_kind(k: int) -> int:
	return int(h01(k + 80) * 3.0) % 3

func _oval(k: int) -> bool:
	return h01(k + 90) < 0.34

# THE WALL: the damask, a gallery light, and every portrait in its gilt frame. Drawn once as the still layer, and
# again inside the lens -- enlarged about the lens's center, and only the frames the lens can see
func _draw_wall(d: Control, lens_c: Vector2, zoom: float, view: Rect2, in_lens: bool) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	if not in_lens:
		d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.05, 0.11, 0.09))
		# the damask: a soft repeating medallion, a shade lighter
		var step: float = 64.0
		var yy: float = 0.0
		var row_i: int = 0
		while yy < full.y + step:
			var xx: float = (step * 0.5 if row_i % 2 == 1 else 0.0)
			while xx < full.x + step:
				d.draw_set_transform(Vector2(xx, yy), 0.0, Vector2(1.0, 1.5))
				d.draw_circle(Vector2.ZERO, 12.0, Color(0.10, 0.20, 0.16, 0.6))
				d.draw_circle(Vector2.ZERO, 6.0, Color(0.05, 0.11, 0.09, 0.8))
				xx += step
			yy += step * 0.75
			row_i += 1
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the gallery light: a warm wash from above
		for k in 14:
			d.draw_set_transform(Vector2(full.x * 0.5, _box(full, bottom).position.y), 0.0, Vector2(1.6, 1.0))
			d.draw_circle(Vector2.ZERO, full.y * 0.6 * (1.0 - float(k) / 14.0), Color(1.0, 0.85, 0.60, 0.02))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		d.draw_set_transform(-lens_c * zoom + view.size * 0.5, 0.0, Vector2(zoom, zoom))
		var seen: Rect2 = Rect2(lens_c - view.size * 0.5 / zoom, view.size / zoom)
		d.draw_rect(seen, Color(0.06, 0.12, 0.10))
		var st: float = 64.0
		for ry in range(int(floor(seen.position.y / (st * 0.75))) - 1, int(ceil(seen.end.y / (st * 0.75))) + 1):
			var off: float = st * 0.5 if posmod(ry, 2) == 1 else 0.0
			for rx in range(int(floor((seen.position.x - off) / st)) - 1, int(ceil((seen.end.x - off) / st)) + 1):
				var mc: Vector2 = Vector2(float(rx) * st + off, float(ry) * st * 0.75)
				var m_pts: PackedVector2Array = PackedVector2Array()
				for j2 in 16:
					var an2: float = TAU * float(j2) / 16.0
					m_pts.append(mc + Vector2(cos(an2) * 12.0, sin(an2) * 18.0))
				d.draw_colored_polygon(m_pts, Color(0.10, 0.20, 0.16, 0.6))
	var reach: Rect2 = Rect2(lens_c - view.size * 0.5 / zoom, view.size / zoom).grow(10.0)
	for k in _cells_n():
		var fr: Rect2 = _frame_rect(k, full, bottom)
		if in_lens and not reach.intersects(fr):
			continue
		var person: String = _who(k)
		var tex: Texture2D = null
		if in_lens:
			tex = _tex.get(person)
		else:
			var path: String = "res://art/people/%s.jpg" % person
			tex = load(path) if ResourceLoader.exists(path) else null
		# shadow, the frame (its own wood or gilt, a lit edge, a dark edge), a cream mat, the portrait -- some oval
		var kind: int = _frame_kind(k)
		var base: Color = [Color(0.62, 0.46, 0.18), Color(0.30, 0.17, 0.08), Color(0.08, 0.07, 0.07)][kind]
		var lit: Color = [Color(0.95, 0.80, 0.45), Color(0.52, 0.32, 0.16), Color(0.30, 0.28, 0.26)][kind]
		d.draw_rect(Rect2(fr.position + Vector2(4, 6), fr.size), Color(0, 0, 0, 0.45))
		d.draw_rect(fr, base)
		d.draw_rect(Rect2(fr.position, Vector2(fr.size.x, 3.0)), lit)
		d.draw_rect(Rect2(fr.position, Vector2(3.0, fr.size.y)), lit.darkened(0.08))
		d.draw_rect(Rect2(fr.position + Vector2(0, fr.size.y - 3.0), Vector2(fr.size.x, 3.0)), base.darkened(0.5))
		var mat: Rect2 = fr.grow(-fr.size.x * 0.07)
		d.draw_rect(mat, Color(0.88, 0.84, 0.74) if kind != 2 else Color(0.80, 0.76, 0.68))
		var inner: Rect2 = mat.grow(-fr.size.x * 0.06)
		if _oval(k):
			var pts: PackedVector2Array = PackedVector2Array()
			var uvs: PackedVector2Array = PackedVector2Array()
			for j in 40:
				var an: float = TAU * float(j) / 40.0
				var uv: Vector2 = Vector2(0.5 + 0.5 * cos(an), 0.5 + 0.5 * sin(an))
				pts.append(inner.position + uv * inner.size)
				uvs.append(uv)
			d.draw_colored_polygon(pts, Color(0.30, 0.20, 0.08))
			var pts2: PackedVector2Array = PackedVector2Array()
			for pp in pts:
				pts2.append(inner.get_center() + (pp - inner.get_center()) * 0.96)
			if tex != null:
				d.draw_polygon(pts2, PackedColorArray([Color(0.92, 0.90, 0.86)]), uvs, tex)
			else:
				d.draw_colored_polygon(pts2, Color(0.30, 0.28, 0.26))
		else:
			d.draw_rect(inner.grow(1.0), Color(0.30, 0.20, 0.08))
			if tex != null:
				d.draw_texture_rect(tex, inner, false, Color(0.92, 0.90, 0.86))
			else:
				d.draw_rect(inner, Color(0.30, 0.28, 0.26))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the search ---------------------------------------------------------------------------------------------------

# the face searched for in cycle `cyc` -- NEVER THE PERSON OF THE CYCLE BEFORE (the user, 2026-11-19; the wall hangs
# some people twice, so two different cells could be the same face): worked out cycle by cycle from the first, kept
var _targets: Array = []
var _targets_n: int = -1                 # the wall's cell count they were worked out for (it changes once the menu lays out)

func _target(cyc: int) -> int:
	if cyc < 0:
		return _target_raw(cyc)          # (the lens glides in from "the cycle before the first")
	if _cells_n() != _targets_n:
		_targets_n = _cells_n()
		_targets.clear()
	while _targets.size() <= cyc:
		var c: int = _targets.size()
		var k: int = _target_raw(c)
		if c > 0:
			var prev: String = _who(int(_targets[c - 1]))
			var tries: int = 0
			while _who(k) == prev and tries < 40:
				k = _target_raw(c * 131 + 7 + tries * 17)
				tries += 1
		_targets.append(k)
	return int(_targets[cyc])

func _target_raw(cyc: int) -> int:
	# a face well inside the wall (not under the pinned card, not at the very edge)
	var n: int = _cells_n()
	var cols: int = _cols()
	var k: int = int(h01(cyc * 17 + 3) * float(n))
	for _i in n:
		var col: int = k % cols
		var row: int = k / cols
		var rows: int = n / cols
		if col >= 1 and col <= cols - 2 and row >= 1 and row <= rows - 3:
			return k
		k = (k + 7) % n
	return k

func _lens_r() -> float:
	return 92.0 if mobile else 70.0

func _lens_at(full: Vector2, bottom: float) -> Vector2:
	var cyc: int = int(floor(t / CYCLE))
	var u: float = fmod(t, CYCLE)
	var a: Vector2 = _frame_rect(_target(cyc - 1), full, bottom).get_center()
	var b: Vector2 = _frame_rect(_target(cyc), full, bottom).get_center()
	var box: Rect2 = _box(full, bottom)
	# by way of somewhere else on the wall: the search, not a straight line
	var via: Vector2 = box.position + box.size * Vector2(0.2 + 0.6 * h01(cyc * 5 + 1), 0.15 + 0.6 * h01(cyc * 5 + 2))
	var s: float = smoothstep(0.3, 4.2, u)
	var p: Vector2 = a.lerp(via, s).lerp(via.lerp(b, s), s)
	return p + Vector2(sin(t * 0.9), cos(t * 0.7)) * 3.0 * (1.0 - smoothstep(3.8, 4.4, u))

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var ready: bool = true
	for k in _cells_n():
		if _photo(_who(k)) == null:
			ready = false
			# (asked for HERE too: the cells are counted again once the menu says where its panel is -- on a phone
			# the wall grew rows whose photos _setup never asked for, and the lens waited for them forever)
			_request(_who(k))
	_lens_a = fade_in(ready, _lens_a, delta)
	var r: float = _lens_r()
	var c: Vector2 = _lens_at(full, bottom)
	_lens.position = c - Vector2(r, r)
	_lens.size = Vector2(r, r) * 2.0
	_inner.size = _lens.size
	_lens.modulate.a = _lens_a
	_lens.visible = _lens_a > 0.0
	_lens.queue_redraw()
	_inner.queue_redraw()
	_rim.queue_redraw()
	# THE CARD pinned at the corner: who to find; it changes while it is faded out between searches
	var cyc: int = int(floor(t / CYCLE))
	var u: float = fmod(t, CYCLE)
	var who: String = _who(_target(cyc))
	var tex: Texture2D = _photo(who)
	if tex != null and _find_for != cyc and u < 0.35:
		_find_for = cyc
		_find.call("setup", tex, Color(1, 1, 1))
		_find.call("set_label", who.replace("_", " ").split(" ")[0])
	_find.visible = _find_for >= 0
	var fade: float = minf(smoothstep(0.0, 0.35, u) if _find_for == cyc else 0.0, 1.0 - smoothstep(6.6, 7.0, u))
	_find.modulate.a = fade * _lens_a
	var w: float = 128.0 if mobile else 96.0
	_find.call("set_width", w)
	var h: float = float(_find.call("card_height"))
	_find.rotation = deg_to_rad(5.0)
	_find.position = Vector2(full.x - w * 0.5 - 22.0, bottom - h - 16.0)

func _draw_inner(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_draw_wall(d, _lens_at(full, bottom), ZOOM, Rect2(Vector2.ZERO, _inner.size), true)

# the brass rim, the handle, a glint on the glass; the green ring round the face found
func _draw_rim(d: Control) -> void:
	if _lens_a <= 0.0:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var c: Vector2 = _lens_at(full, bottom)
	var r: float = _lens_r()
	var a: float = _lens_a
	var u: float = fmod(t, CYCLE)
	var found: float = smoothstep(4.2, 4.6, u) * (1.0 - smoothstep(6.4, 6.9, u))
	var pulse: float = 0.75 + 0.25 * sin(t * 6.0)
	# the handle, out to the lower right
	var hd: Vector2 = Vector2(0.70, 0.72).normalized()
	var h0: Vector2 = c + hd * (r + 6.0)
	var h1: Vector2 = c + hd * (r + r * 1.25)
	d.draw_line(h0 + Vector2(3, 5), h1 + Vector2(3, 5), Color(0, 0, 0, 0.35 * a), 22.0)
	d.draw_line(h0, h0 + hd * 16.0, Color(0.80, 0.62, 0.28, a), 14.0)
	d.draw_line(h0 + hd * 16.0, h1, Color(0.22, 0.10, 0.05, a), 18.0)
	d.draw_line(h0 + hd * 18.0 + Vector2(-3, -3), h1 + Vector2(-3, -3), Color(0.45, 0.25, 0.12, a), 5.0)
	# the rim: a dark outer edge, brass, a lit upper-left arc
	d.draw_arc(c, r + 5.0, 0.0, TAU, 72, Color(0.20, 0.13, 0.04, a), 6.0, true)
	d.draw_arc(c, r + 2.0, 0.0, TAU, 72, Color(0.82, 0.64, 0.30, a), 7.0, true)
	# found: a green glow round the rim, pulsing
	if found > 0.0:
		for j in 4:
			d.draw_arc(c, r + 8.0 + float(j) * 3.0, 0.0, TAU, 72, Color(0.35, 1.0, 0.45, 0.30 * found * pulse * a * (1.0 - float(j) * 0.22)), 4.0, true)
		d.draw_arc(c, r + 2.0, 0.0, TAU, 72, Color(0.35, 1.0, 0.45, 0.85 * found * a), 4.0, true)
	d.draw_arc(c, r + 3.0, PI * 1.05, PI * 1.55, 24, Color(1.0, 0.92, 0.65, a), 2.5, true)
	# the glass: a soft glint
	d.draw_arc(c, r * 0.78, PI * 1.12, PI * 1.38, 18, Color(1, 1, 1, 0.30 * a), 6.0, true)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# a pin through the card
	if _find != null and _find.visible and _find.modulate.a > 0.0:
		var pin: Vector2 = _find.position + Vector2(0.0, 8.0)
		cv.draw_circle(pin + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.35 * _find.modulate.a))
		cv.draw_circle(pin, 7.0, Color(0.80, 0.12, 0.10, _find.modulate.a))
		cv.draw_circle(pin + Vector2(-2, -2), 2.5, Color(1, 0.7, 0.6, _find.modulate.a))
		var f: Font = MainGlobals.get_text_font()
		var fsz: int = 26 if mobile else 20
		var tw: float = f.get_string_size("FIND", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var tp: Vector2 = _find.position + Vector2(-tw * 0.5, -10.0)
		cv.draw_string_outline(f, tp, "FIND", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 6, Color(0.05, 0.08, 0.06, _find.modulate.a))
		cv.draw_string(f, tp, "FIND", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1.0, 0.86, 0.50, _find.modulate.a))
	title("Weris", "Find people in a crowd", Color(1.0, 0.88, 0.60), Color(0.06, 0.12, 0.08),
		Color(1.0, 0.85, 0.5, 0.22))
