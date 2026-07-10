extends Node

# PtbitsG autoload. Owns the GenericGameUtil instance, level queue, settings,
# and the (swappable) ball texture used by the physics balls.

var starting_level_id: int = 1
var game: GenericGameUtil = GenericGameUtil.new("Ptbits", "ptbits", 0, 1, 0)

var level_queue: Array = []

# --- Ball texture -----------------------------------------------------------
# The ball is drawn with a texture so an artist can swap it later. A texture is
# square/rect by nature, so the alpha channel masks it into a circle and the
# physics body uses a CircleShape2D (see level.gd). To replace with real art,
# drop a square PNG at res://ptbits/art/ball.png and return preload() below.
var _ball_tex: Texture2D = null

func ball_texture() -> Texture2D:
	if _ball_tex == null:
		_ball_tex = _make_ball_texture(96)
	return _ball_tex

func _make_ball_texture(d: int) -> Texture2D:
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: float = (d - 1) * 0.5
	var rad: float = c - 1.0
	for y in d:
		for x in d:
			var dist: float = Vector2(float(x) - c, float(y) - c).length()
			var a: float = clampf(rad - dist + 1.0, 0.0, 1.0)  # 1px anti-aliased edge
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# radial shading: bright center, slightly darker edge -> 3D ball look.
				# White base so per-ball modulate tints it to any color cleanly.
				var shade: float = clampf(1.0 - (dist / rad) * 0.30, 0.62, 1.0)
				img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)

# --- App integration --------------------------------------------------------

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func reset_queue_from(start_id: int) -> void:
	var base: Array = PtbitsLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	var idx: int = base.find(start_id)
	if idx > 0:
		level_queue = base.slice(idx) + base.slice(0, idx)
	else:
		level_queue = base

func pop_next_level_id() -> int:
	if level_queue.is_empty():
		level_queue = PtbitsLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	return level_queue.pop_front()

func record_level_result(level_id: int, pct: int) -> void:
	if pct < 60:
		if level_queue.size() >= 1:
			level_queue.insert(1, level_id)
		else:
			level_queue.append(level_id)

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]
