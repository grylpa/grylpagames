class_name PrepCard
extends CanvasLayer
# THE FIRST OPENING OF A GAME (2026-11-19): the first time a game is tapped on this device (after an install or an update;
# on the web, once a visit), its menu poster's shaders are compiled before the menu opens (ShaderWarmer). A compile
# stops the whole screen, so the user asked for a small card for THAT GAME ONLY while it is prepared -- never a wait for
# games not being played -- and nothing that could look like a freeze. So:
#   - behind the card the chooser is a STILL, dimmed picture of itself (its stars and turning tiles would visibly stop);
#   - the card is the game's tile in a ring of dots, its name, "Getting it ready";
#   - the dots light as the work goes: smoothly while the game's scene loads on a thread (the screen is free then), then
#     ONE STEP AT A TIME while the shaders compile -- each step waits until its dots are on screen, and between steps
#     nothing moves, so a long compile reads as the next dot being worked on.

const GOLD: Color = Color(0.96, 0.78, 0.36)
const DOTS: int = 24
const LOAD_SHARE: float = 0.3            # of the ring, for loading the scene; the rest for the shaders
const ROUND: String = """shader_type canvas_item;
uniform vec2 size_px = vec2(100.0);
uniform float radius_px = 12.0;
void fragment() {
	vec2 p = UV * size_px;
	vec2 q = abs(p - size_px * 0.5) - (size_px * 0.5 - vec2(radius_px));
	float d = length(max(q, vec2(0.0))) - radius_px;
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= clamp(0.5 - d, 0.0, 1.0);
}
"""

var _folder: String = ""
var _root: Control = null
var _ring: Control = null
var _center: Vector2 = Vector2.ZERO
var _tile_r: float = 60.0
var _progress: float = 0.0
var _load_t: float = 0.0

# put the card up for the game in `folder` (a still picture of the chooser behind it)
static func open(host: Node, folder: String) -> PrepCard:
	var c: PrepCard = PrepCard.new()
	c._folder = folder
	var snap: Image = host.get_viewport().get_texture().get_image()
	host.get_tree().root.add_child(c)
	c._build(snap)
	return c

func _build(snap: Image) -> void:
	layer = 140
	var full: Vector2 = get_viewport().get_visible_rect().size
	var mob: bool = MainGlobals.is_mobile()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	if snap != null:
		var still: TextureRect = TextureRect.new()
		still.texture = ImageTexture.create_from_image(snap)
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_SCALE
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		still.modulate = Color(0.42, 0.44, 0.52)
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(still)
	# the card
	var w: float = minf(full.x * 0.78, 520.0)
	var h: float = 470.0 if mob else 350.0
	var card: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.065, 0.085, 0.17, 0.97)
	sb.border_color = Color(GOLD, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0.0, 8.0)
	sb.anti_aliasing = true
	card.add_theme_stylebox_override("panel", sb)
	card.position = (full - Vector2(w, h)) * 0.5
	card.size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	var tile_s: float = 150.0 if mob else 112.0
	_tile_r = tile_s * 0.5
	_center = card.position + Vector2(w * 0.5, (36.0 if mob else 26.0) + _tile_r + 22.0)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_root.add_child(_ring)
	var tile: TextureRect = TextureRect.new()
	var path: String = "res://%s/art/game_screen_200.png" % _folder
	if ResourceLoader.exists(path):
		tile.texture = load(path)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tile.position = _center - Vector2(_tile_r, _tile_r)
	tile.size = Vector2(tile_s, tile_s)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = ROUND
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("size_px", Vector2(tile_s, tile_s))
	m.set_shader_parameter("radius_px", tile_s * 0.14)
	tile.material = m
	_root.add_child(tile)
	var frame: Panel = Panel.new()
	var fb: StyleBoxFlat = StyleBoxFlat.new()
	fb.draw_center = false
	fb.border_color = Color(GOLD, 0.9)
	fb.set_border_width_all(2)
	fb.set_corner_radius_all(int(tile_s * 0.14))
	fb.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", fb)
	frame.position = tile.position
	frame.size = tile.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	var y: float = _center.y + _tile_r + (58.0 if mob else 42.0)
	var nm: Label = _label(_display_name(), 46 if mob else 32, GOLD, card.position.x, y, w)
	nm.add_theme_color_override("font_shadow_color", Color(1.0, 0.70, 0.30, 0.30))
	nm.add_theme_constant_override("shadow_outline_size", 12)
	nm.add_theme_constant_override("shadow_offset_y", 0)
	y += (64.0 if mob else 44.0)
	var l2: Label = _label("Getting it ready", 28 if mob else 19, Color(0.93, 0.90, 0.84), card.position.x, y, w)
	l2.add_theme_font_override("font", MainGlobals.get_text_font())
	y += (40.0 if mob else 28.0)
	var l3: Label = _label("Only the first time", 21 if mob else 15, Color(0.70, 0.74, 0.86, 0.85), card.position.x, y, w)
	l3.add_theme_font_override("font", MainGlobals.get_text_font())

func _display_name() -> String:
	for g in MainCfg.games:
		if str(g[0]) == _folder:
			return str(g[1])
	return _folder

func _label(text: String, fs: int, col: Color, x: float, y: float, w: float) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(x, y)
	l.size = Vector2(w, 10.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

# a warm glow behind the tile, and the ring of dots: lit ones gold with a halo, the rest faint
func _draw_ring() -> void:
	for k in 10:
		var f: float = 1.0 - float(k) / 10.0
		_ring.draw_circle(_center, _tile_r * (1.0 + 0.9 * f), Color(1.0, 0.78, 0.40, 0.022))
	var lit: int = int(floor(_progress * float(DOTS) + 0.001))
	var rr: float = _tile_r * 1.414 + 20.0
	for d in DOTS:
		var a: float = -PI * 0.5 + TAU * float(d) / float(DOTS)
		var p: Vector2 = _center + Vector2(cos(a), sin(a)) * rr
		if d < lit:
			for k2 in 3:
				_ring.draw_circle(p, 5.0 + 4.0 * float(3 - k2), Color(1.0, 0.80, 0.40, 0.06))
			_ring.draw_circle(p, 4.6, GOLD)
			_ring.draw_circle(p - Vector2(1.2, 1.2), 1.6, Color(1.0, 0.97, 0.88))
		else:
			_ring.draw_circle(p, 3.4, Color(GOLD, 0.18))

func _set_progress(p: float) -> void:
	var before: int = int(floor(_progress * float(DOTS) + 0.001))
	_progress = clampf(maxf(p, _progress), 0.0, 1.0)
	if int(floor(_progress * float(DOTS) + 0.001)) != before:
		_ring.queue_redraw()

# while the game's scene loads on a thread: the first part of the ring fills with time, easing toward its share
func loading_tick(delta: float) -> void:
	_load_t += delta
	_set_progress(LOAD_SHARE * (1.0 - exp(-_load_t * 2.5)))

# compile the poster's shaders, a step at a time, the ring following; returns when done
func warm() -> void:
	_set_progress(LOAD_SHARE)
	var w: ShaderWarmer = ShaderWarmer.new()
	w.folder = _folder
	w.step_done.connect(func(step: int, steps: int) -> void:
		_set_progress(LOAD_SHARE + (1.0 - LOAD_SHARE) * float(step) / float(maxi(steps, 1)))
		_proceed_after_draw(w))
	add_child(w)
	if not w.done:
		await w.finished
	_set_progress(1.0)
	w.queue_free()

# the next compile waits until the dots this step lit are on the screen
func _proceed_after_draw(w: ShaderWarmer) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(w):
		w.proceed()

# gone once the game's menu is up (a couple of frames after it was added)
func close_soon() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
