extends Node
class_name TileLife

# The game chooser's tiles, alive (2026-11-10, after the website's frame): every game's picture turns
# slowly to and fro about its OWN axis -- any direction in the picture's plane, through its center --
# at its own pace, and sits a little off the upright and off the size, always about its own center. Pointing at one
# (desktop) turns it to face the player and puts it back exactly as the plain chooser had it -- flat,
# upright, its own size; leaving, it eases back into its sway from where it stopped.
#
# All of it is drawn by scripts/tile_life.gdshader: the controls never move, so a tap, a drag-to-scroll
# and the hover highlight all work on the tile's steady rectangle exactly as before.
#
# Each game's look is seeded from its folder, so the screen is the same every time it opens and a game
# can still be found by where it sits. No flips: on the website a flip shows another game, which is
# decoration; here every tile IS its game.

const SHADER: Shader = preload("res://scripts/tile_life.gdshader")
# The picture rounds its own corners. The tile's clipper cannot do it any more: a clip_children
# parent composites its children THROUGH ITS OWN MATERIAL, so with this shader on it the pictures
# came out as the clipper's flat grey. So the clipper is switched off and hidden, and the picture
# gets this second shader -- the same motion plus the rounded mask.
#
# The FRAME is drawn here too, not by the tile's frame panel. The panel's border is smoothed in its own
# flat space, before the turn: squeezed by the perspective, its 2-unit line fell under a pixel at some
# angles and came out jagged. Here both edges are smoothed by fwidth -- per SCREEN pixel, after the
# turn -- so the frame is clean at every angle. Its color and width are read from the panel every frame
# (the panel itself is hidden), so the chooser's own hover highlight still shows.
const ROUND_FRAGMENT: String = """
uniform vec2 rect_size = vec2(100.0);
uniform float radius = 8.0;
uniform vec4 border_color = vec4(0.0);
uniform float border_width = 2.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float aa = max(fwidth(d), 0.0001);
	float ring = clamp((d + border_width) / aa + 0.5, 0.0, 1.0);
	COLOR.rgb = mix(COLOR.rgb, border_color.rgb, ring * border_color.a);
	COLOR.a *= clamp(0.5 - d / aa, 0.0, 1.0);
}
"""
const CORNER_RADIUS: float = 8.0   # the chooser's tile frame (scenes/game_select_button.tscn)
static var _round_shader: Shader = null

# The swing, per view. The GRID's big tiles fill the screen, so the website's 24-34 degrees every
# 6-10 s was far too much there ("too big and too fast"): it swings gently and slowly. A list row's
# small picture keeps the livelier swing.
const GRID_SWING: Dictionary = {"min_deg": 10.0, "max_deg": 16.0, "lean_deg": 3.0, "min_s": 10.0, "max_s": 16.0}
const LIST_SWING: Dictionary = {"min_deg": 24.0, "max_deg": 34.0, "lean_deg": 5.0, "min_s": 6.0, "max_s": 10.0}
const EYE_DIST: float = 4.6            # the perspective's eye, in tile sizes (the web's 420px at ~90px)
const HOVER_RATE: float = 5.0          # per second, the ease into and out of a hover

# untidiness, as a share of the tile's size: the grid has room for it, a list row less
# No offset: a tile's CENTER never moves (the user's rule) -- the turn, the tilt and the size all
# happen about the plain tile's own center, in every view.
# Never above 1: a tile at rest must not be bigger than the plain one it returns to under the pointer.
const GRID_UNTIDY: Dictionary = {"tilt_deg": 4.0, "s_min": 0.88, "s_max": 0.98}
const LIST_UNTIDY: Dictionary = {"tilt_deg": 3.0, "s_min": 0.92, "s_max": 0.99}

var _tiles: Array = []   # of Dictionary, one per registered tile

# `tile` is the chooser's GameSelectButton (a Control whose children draw the tile); `key` seeds its look.
# `also_hover`: other controls whose hover counts as pointing at this game (a list row's text).
func add(tile: Control, key: String, list_mode: bool, also_hover: Array = []) -> void:
	if tile == null or not is_instance_valid(tile):
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("tile_life:" + key)
	var untidy: Dictionary = LIST_UNTIDY if list_mode else GRID_UNTIDY
	var swing: Dictionary = LIST_SWING if list_mode else GRID_SWING
	var th: float = rng.randf_range(0.0, TAU)
	var entry: Dictionary = {
		"tile": tile,
		"mat": ShaderMaterial.new(),
		"mat_pic": ShaderMaterial.new(),
		"pic": null,
		"frame": null,
		"axis": Vector2(cos(th), sin(th)),
		"swing": deg_to_rad(rng.randf_range(float(swing["min_deg"]), float(swing["max_deg"]))),
		"lean": deg_to_rad(rng.randf_range(-float(swing["lean_deg"]), float(swing["lean_deg"]))),
		"period": rng.randf_range(float(swing["min_s"]), float(swing["max_s"])),
		"clock": rng.randf_range(0.0, 2.0 * float(swing["max_s"])),
		"tilt": deg_to_rad(rng.randf_range(-1.0, 1.0) * float(untidy["tilt_deg"])),
		"scale": rng.randf_range(float(untidy["s_min"]), float(untidy["s_max"])),
		"hover": 0.0,
		"hover_to": 0.0,
	}
	var mat: ShaderMaterial = entry["mat"] as ShaderMaterial
	mat.shader = SHADER
	if _round_shader == null:
		_round_shader = Shader.new()
		_round_shader.code = SHADER.code + ROUND_FRAGMENT
	var mat_pic: ShaderMaterial = entry["mat_pic"] as ShaderMaterial
	mat_pic.shader = _round_shader
	mat_pic.set_shader_parameter("radius", CORNER_RADIUS)
	var clipper: CanvasItem = tile.get_node_or_null("%PanelClipper") as CanvasItem
	if clipper != null:
		clipper.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		clipper.self_modulate = Color(1, 1, 1, 0)
	_add_shadow(tile, list_mode)
	_dress(tile, mat)
	var pic: Control = tile.get_node_or_null("%Texture") as Control
	if pic != null:
		pic.material = mat_pic
		entry["pic"] = pic
	var frame: Control = tile.get_node_or_null("%PanelFrame") as Control
	if frame != null:
		frame.self_modulate = Color(1, 1, 1, 0)
		entry["frame"] = frame
	# the tile's own button reports the pointer (on a touchscreen it never hovers)
	var hovers: Array = [tile.get_node_or_null("%Texture")]
	hovers.append_array(also_hover)
	for h: Variant in hovers:
		var ctl: Control = h as Control
		if ctl == null:
			continue
		ctl.mouse_entered.connect(func() -> void: entry["hover_to"] = 1.0)
		ctl.mouse_exited.connect(func() -> void: entry["hover_to"] = 0.0)
	_tiles.append(entry)
	_update(entry, 0.0)

# A soft shadow under the tile, first in its drawing order. It takes the tile's material like every
# other layer, so it turns, tilts and grows with the picture: the tiles stand OFF the background.
# The grid's shadows are deeper, wider and lower than a list row's: there the tiles stand on the cloth
# with room around them, and a faint shadow barely parted them from it ("more contrast").
func _add_shadow(tile: Control, list_mode: bool) -> void:
	var shadow: Panel = Panel.new()
	shadow.name = "LifeShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.35 if list_mode else 0.6)
	sb.set_corner_radius_all(int(CORNER_RADIUS))
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55 if list_mode else 0.85)
	sb.shadow_size = maxi(6, int(tile.size.x * (0.07 if list_mode else 0.09)))
	sb.shadow_offset = Vector2(0.0, tile.size.x * (0.035 if list_mode else 0.05))
	shadow.add_theme_stylebox_override("panel", sb)
	tile.add_child(shadow)
	tile.move_child(shadow, 0)

# every canvas item of the tile shares the one material, so the layers stay together
func _dress(node: Node, mat: ShaderMaterial) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null:
		item.material = mat
	for child: Node in node.get_children():
		_dress(child, mat)

func _process(delta: float) -> void:
	if _tiles.is_empty():
		return
	# the chooser is hidden while a game is up: nothing to animate
	var first: Variant = (_tiles[0] as Dictionary)["tile"]
	if is_instance_valid(first) and not (first as Control).is_visible_in_tree():
		return
	var kept: Array = []
	for entry: Dictionary in _tiles:
		# a freed tile cannot even be cast: test the raw value first
		if not is_instance_valid(entry["tile"]):
			continue   # the grid was rebuilt (a view change); its new tiles registered themselves
		kept.append(entry)
		_update(entry, delta)
	_tiles = kept

func _update(entry: Dictionary, delta: float) -> void:
	var tile: Control = entry["tile"] as Control
	if not tile.is_inside_tree():
		return
	var hover: float = move_toward(float(entry["hover"]), float(entry["hover_to"]), delta * HOVER_RATE)
	entry["hover"] = hover
	# the clock slows to a stop under the pointer, so the tile halts where it is
	entry["clock"] = float(entry["clock"]) + delta * (1.0 - hover)
	var rect: Rect2 = tile.get_global_rect()
	if rect.size.x <= 0.0:
		return
	# off screen: nothing to draw (it is updated again the frame it scrolls into view)
	if not tile.get_viewport_rect().grow(rect.size.x).intersects(rect):
		return
	var side: float = maxf(rect.size.x, rect.size.y)
	var period: float = float(entry["period"])
	# under the pointer the tile turns to FACE the player (its sway eases to flat, its tilt upright)
	var ang: float = (float(entry["lean"]) + float(entry["swing"]) * sin(float(entry["clock"]) * PI / period)) * (1.0 - hover)
	# under the pointer every bit of untidiness eases away: the tile is exactly where, how big and how
	# upright it was before any of this (its own control's rectangle)
	var tilt: float = float(entry["tilt"]) * (1.0 - hover)
	var grow: float = lerpf(float(entry["scale"]), 1.0, hover)
	# the perspective enlarges a turned tile's near edge (to dist / (dist - half * sin)); shrink by the
	# same, so no part of a swaying tile ever reaches past its plain outline
	var dist: float = side * EYE_DIST
	grow *= (dist - side * 0.5 * absf(sin(ang))) / dist
	for key: String in ["mat", "mat_pic"]:
		var mat: ShaderMaterial = entry[key] as ShaderMaterial
		mat.set_shader_parameter("center", rect.get_center())
		mat.set_shader_parameter("axis", entry["axis"])
		mat.set_shader_parameter("angle", ang)
		mat.set_shader_parameter("dist", dist)
		mat.set_shader_parameter("tilt", tilt)
		mat.set_shader_parameter("size_scale", grow)
	var pic_mat: ShaderMaterial = entry["mat_pic"] as ShaderMaterial
	var pic: Variant = entry["pic"]
	if is_instance_valid(pic):
		pic_mat.set_shader_parameter("rect_size", (pic as Control).size)
	var frame: Variant = entry["frame"]
	if is_instance_valid(frame):
		var sb: StyleBoxFlat = (frame as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			pic_mat.set_shader_parameter("border_color", sb.border_color)
			pic_mat.set_shader_parameter("border_width", float(sb.border_width_left))
