extends Area2D

# ONE PERSON IN THE SQUARE, three-quarter view (2026-11-15, the third try -- see plaza.gdshader).
# Seen steeply from above and a little in front:
#   UMBRELLA   someone under an umbrella: the courier at the fountain, and the people at the eight
#              spots to choose from. The CANOPY is seen almost from above -- a round umbrella of
#              eight panels, foreshortened a little -- so its PRINT (`texture_idx`, one of PRINTS) and
#              colors read whole, as in the top view; below its front edge the person's coat and legs.
#              The person is random and means nothing.
#   LOOKOUT    the one glimpsed at a spot in the lightning: a yellow raincoat under a SEE-THROUGH
#              umbrella -- the same size and drawing as every umbrella, the only clear one. (Tried and
#              dropped the same day: a yellow figure from straight above read as an eye; a whole
#              person, raised torch and all, was too big and too dull beside the umbrellas.)
#   PASSERBY   clutter on the later levels: a person under a plain black umbrella.
# The origin is at the FEET. The level scales the whole.

signal need_to_remove_agent(agent)
signal agent_pressed(agent)

enum Kind { UMBRELLA, LOOKOUT, PASSERBY }

# The seven canopy prints (the top view's, which read best): nothing on it, alternate panels, a dot
# in each panel, a band round the rim, a disc at the top, one half, the ribs picked out.
const PRINTS: Array = ["plain", "stripes", "dots", "rim", "cap", "half", "ribs"]
const R: float = 46.0                     # canopy radius
const SQUASH: float = 0.80                # the canopy seen not quite from straight above
const CANOPY_C: Vector2 = Vector2(0.0, -58.0)
const LOOKOUT_COAT: Color = Color(0.98, 0.80, 0.12)
const COATS: Array = [Color(0.20, 0.26, 0.38), Color(0.36, 0.20, 0.18), Color(0.22, 0.30, 0.24),
	Color(0.32, 0.30, 0.34), Color(0.40, 0.33, 0.22), Color(0.16, 0.16, 0.20), Color(0.42, 0.40, 0.36)]

var board_pos: Vector2i = Vector2i.ZERO
var time_created_ms: float = 0.0
var color: Array = [Color(1, 1, 1, 1), Color(1, 1, 1, 1)]
var time_to_hide_ms: float = 2000.0
var is_correct: bool = false
var is_correct_shape: bool = false
var is_correct_direction: bool = false
var is_model: bool = false
var id: int = 0
var timed_out: bool = false
var texture_idx: int = 0                  # the PRINT (the name is kept from the sprite days)
var kind: int = Kind.UMBRELLA
var spin: float = 0.0                     # the canopy's turn (the level matches the courier's)
var mark: int = 0                         # 0 none, 1 right, 2 wrong, 3 "it was here"
var light: Color = Color(1, 1, 1)         # the light on the figure (strong cold flash, warm lamps)
var coat: Color = COATS[0]
# WALKING FEET, from outside (the menu poster, menu_world.gd): when >= 0, the legs scissor with this phase
# along `step_dir` and the foot coming forward lifts; in the game (-1) the figure stands, as it always has
var step_phase: float = -1.0
var step_dir: float = 1.0

var game: GenericGameUtil = null

static var next_agent_texture_idx: int = 0

func _ready() -> void:
	game = DidiG.game
	time_created_ms = game.game_time
	var spr: Node = get_node_or_null("%SpriteLR")
	if spr != null:
		spr.visible = false               # the old flat sprite; everything is drawn now
	spin = randf() * TAU
	coat = COATS[randi() % COATS.size()]
	# the tap area: the umbrella and the person under it
	var cs: CollisionShape2D = get_node_or_null("AgentShape") as CollisionShape2D
	if cs != null:
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(2.0 * R, 100.0)
		cs.shape = rect
		cs.position = Vector2(0.0, -50.0)
	queue_redraw()

func set_rand_texture(index_to_avoid: int = -1) -> int:
	while true:
		texture_idx = next_agent_texture_idx
		next_agent_texture_idx = (next_agent_texture_idx + 1) % PRINTS.size()
		if texture_idx != index_to_avoid:
			queue_redraw()
			return texture_idx
	return 0

func set_texture(idx: int) -> void:
	texture_idx = idx % PRINTS.size()
	queue_redraw()

func set_colors(_color: Array) -> void:
	color = _color.duplicate(true)
	queue_redraw()

func set_kind(k: int) -> void:
	kind = k
	queue_redraw()

func set_mark(m: int) -> void:
	mark = m
	queue_redraw()

func set_light(c: Color) -> void:
	if not c.is_equal_approx(light):
		light = c
		queue_redraw()

func set_pos(p: Vector2, _dir: int) -> void:
	position = p

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(self)

func _process(_delta: float) -> void:
	var tm: float = game.game_time
	if tm - time_created_ms >= time_to_hide_ms and not timed_out:
		visible = false
		timed_out = true
		need_to_remove_agent.emit(self)

func _l(c: Color) -> Color:
	return Color(minf(1.0, c.r * light.r), minf(1.0, c.g * light.g), minf(1.0, c.b * light.b), c.a)

func _draw() -> void:
	draw_colored_polygon(_ellipse(Vector2(5.0, 2.0), 30.0, 9.0), Color(0, 0, 0, 0.38))   # on the wet stones
	match kind:
		Kind.UMBRELLA:
			_draw_legs()
			_draw_coat(coat, -34.0)
			_draw_canopy(color[0], str(PRINTS[texture_idx]), false)
		Kind.LOOKOUT:
			# under a SEE-THROUGH umbrella: the yellow raincoat shows through the clear canopy. The
			# same size and drawing as every other umbrella (a bigger, plainer figure "did not
			# match the umbrellas' feel"), and the only clear one in the square.
			_draw_legs()
			_draw_coat(LOOKOUT_COAT, -34.0)
			draw_set_transform(CANOPY_C, 0.0, Vector2(1.0, SQUASH))
			draw_colored_polygon(_ellipse(Vector2(0.0, 8.0), R * 0.62, R * 0.40), _l(LOOKOUT_COAT))       # shoulders
			draw_circle(Vector2(0.0, -2.0), R * 0.30, _l(LOOKOUT_COAT.darkened(0.08)))                    # the hood
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_canopy(Color(0.85, 0.92, 1.0), "plain", true)
		Kind.PASSERBY:
			# clutter: a plain BLACK umbrella, the same size and drawing
			_draw_legs()
			_draw_coat(coat, -34.0)
			_draw_canopy(Color(0.14, 0.14, 0.16), "plain", false)
	if mark != 0:
		var mc: Color = Color(0.35, 1.0, 0.45)
		if mark == 2:
			mc = Color(1.0, 0.40, 0.32)
		elif mark == 3:
			mc = Color(1.0, 0.85, 0.30)
		draw_arc(Vector2(0.0, -46.0), 64.0, 0.0, TAU, 48, mc, 7.0, true)

func _draw_legs() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 7.0
		var foot_dx: float = 0.0
		var lift: float = 0.0
		if step_phase >= 0.0:
			var ph: float = step_phase + (0.0 if side < 0.0 else PI)
			foot_dx = step_dir * 8.0 * sin(ph)
			lift = maxf(0.0, cos(ph)) * 3.0          # the foot swinging forward is off the ground
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, -18.0), Vector2(x + 5.0, -18.0),
			Vector2(x + foot_dx + 4.5, -3.0 - lift), Vector2(x + foot_dx - 4.5, -3.0 - lift)]), _l(Color(0.13, 0.14, 0.18)))
		draw_colored_polygon(_ellipse(Vector2(x + foot_dx, -2.0 - lift), 6.0, 3.5), _l(Color(0.08, 0.08, 0.09)))

# The coat from the shoulders (`top`) down to the hem, seen from above and in front: wider at the
# shoulders, lit on its upper side.
func _draw_coat(c: Color, top: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-18.0, top), Vector2(18.0, top), Vector2(16.0, -14.0), Vector2(-16.0, -14.0)])
	draw_colored_polygon(pts, _l(c))
	draw_colored_polygon(PackedVector2Array([Vector2(-18.0, top), Vector2(18.0, top),
		Vector2(17.0, top + 8.0), Vector2(-17.0, top + 8.0)]), _l(c.lightened(0.12)))
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, _l(c.darkened(0.5)), 1.5, true)

# The canopy, almost from above: eight panels lit from the top left, a scalloped edge between the rib
# tips, the ribs and the tip -- drawn round, then foreshortened (SQUASH) about its center.
func _draw_canopy(base: Color, p_name: String, clear: bool) -> void:
	draw_set_transform(CANOPY_C, 0.0, Vector2(1.0, SQUASH))
	var two: bool = not color[0].is_equal_approx(color[1])
	# dark on a light canopy, light on a dark one: the print must stand out when small
	var print_col: Color = color[1] if two else (base.darkened(0.62) if base.get_luminance() > 0.45 else base.lerp(Color(1, 1, 1), 0.85))
	var rim: PackedVector2Array = PackedVector2Array()
	for i in 8:
		var a: float = spin + TAU * float(i) / 8.0
		rim.append(Vector2(cos(a), sin(a)) * R)
	for i in 8:
		var a0: Vector2 = rim[i]
		var a1: Vector2 = rim[(i + 1) % 8]
		var mid: Vector2 = (a0 + a1) * 0.5 * 0.90
		var facing: float = (a0 + a1).normalized().dot(Vector2(-0.6, -0.8))
		var c: Color = base
		if (p_name == "stripes" and i % 2 == 0) or (p_name == "half" and i < 4):
			c = print_col
		c = c.lightened(0.08 * maxf(0.0, facing)).darkened(0.16 * maxf(0.0, -facing))
		if clear:
			c.a = 0.28 + 0.10 * maxf(0.0, facing)          # see-through, a sheen on the lit side
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, a0, mid, a1]), _l(c))
	match p_name:
		"dots":
			for i in 8:
				var a: float = spin + TAU * (float(i) + 0.5) / 8.0
				draw_circle(Vector2(cos(a), sin(a)) * R * 0.56, R * 0.12, _l(print_col))
		"rim":
			var band: PackedVector2Array = _canopy_outline(rim)
			band.append(band[0])
			draw_polyline(band, _l(print_col), R * 0.22, true)
		"cap":
			draw_circle(Vector2.ZERO, R * 0.40, _l(print_col))
		"ribs":
			for i in 8:
				draw_line(Vector2.ZERO, rim[i] * 0.97, _l(print_col), R * 0.13, true)
	var edge: Color = _l(base.darkened(0.45)) if not clear else _l(Color(0.92, 0.96, 1.0, 0.85))
	for i in 8:
		draw_line(Vector2.ZERO, rim[i], Color(edge.r, edge.g, edge.b, 0.55), 2.0, true)
	var outline: PackedVector2Array = _canopy_outline(rim)
	outline.append(outline[0])
	draw_polyline(outline, edge, 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, _l(Color(0.85, 0.85, 0.80)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _canopy_outline(rim: PackedVector2Array) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 8:
		var a0: Vector2 = rim[i]
		var a1: Vector2 = rim[(i + 1) % 8]
		pts.append(a0)
		pts.append((a0 + a1) * 0.5 * 0.90)
	return pts

func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
