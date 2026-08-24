extends Control

# Set by level.gd after instantiation
var level_node: Node = null

# Mirrors level.gd's POP_LIFE_SEC / POP_RISE_PX; the level owns the timing, this owns the drawing.
const _POP_LIFE: float = 0.9
const _POP_RISE: float = 42.0

static var _font: Font = null

static func _pop_font() -> Font:
	if _font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Black", "Open Sans Bold", "DejaVu Sans",
			"sans-serif"])
		sf.font_weight = 800
		_font = sf
	return _font

func _ready() -> void:
	level_node = get_parent()

func _draw() -> void:
	if level_node == null:
		return
	var state: Dictionary = level_node.get_draw_state()
	var targets: Array = state["targets"]
	var flash_color: Color = state["flash_color"]
	var flash_alpha: float = state["flash_alpha"]
	var flash_pos: Vector2 = state["flash_pos"]
	var flash_radius: float = state["target_radius"]

	for t in targets:
		var pos: Vector2 = t["pos"]
		var radius: float = t["radius"]
		var color: Color = t["color"]
		var age: float = t["age"]
		# Outer target circle
		draw_circle(pos, radius, color)
		# Center dot (aiming guide) — omitted for same-color decoys
		if t["draw_dot"]:
			draw_circle(pos, radius * 0.22, Color(1.0, 1.0, 1.0, 0.85))
		# Thin ring outline
		draw_arc(pos, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0)
		# Countdown arc: starts full, depletes clockwise as age approaches 1.0
		var remaining: float = 1.0 - age
		var arc_end: float = -PI * 0.5 + remaining * TAU
		var arc_col: Color = Color(1.0, 1.0, 1.0, 0.85).lerp(Color(1.0, 0.25, 0.0, 1.0), age)
		draw_arc(pos, radius + 9.0, -PI * 0.5, arc_end, 48, arc_col, 4.0)

	# Flash feedback
	if flash_alpha > 0.0:
		var fc: Color = flash_color
		fc.a = flash_alpha * flash_color.a
		draw_circle(flash_pos, flash_radius * 1.3, fc)

	# What the tap was worth. The flash says something happened; the number says what it cost,
	# which is the part a player is actually trying to learn. It rises and fades so it cannot be
	# confused with a target, and it is drawn LAST so a later round never covers it.
	var pops: Array = state.get("pops", [])
	if not pops.is_empty():
		var f: Font = _pop_font()
		var fs: int = 34 if MainGlobals.is_mobile() else 24
		for p in pops:
			var t: float = clampf(float(p["age"]) / _POP_LIFE, 0.0, 1.0)
			var col: Color = p["color"]
			col.a = 1.0 - t * t                       # holds, then drops away
			var txt: String = p["text"]
			var ss: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var at: Vector2 = Vector2(float(p["pos"].x) - ss.x * 0.5,
				float(p["pos"].y) - _POP_RISE * t)
			# A dark backing stroke: these land on the playfield, on top of a target as often as
			# not, and a thin colored glyph on a saturated circle is unreadable.
			var shadow: Color = Color(0.0, 0.0, 0.0, col.a * 0.75)
			for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
				draw_string(f, at + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
			draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
