extends Node

# PtbitsG autoload. Owns the GenericGameUtil instance, settings, and the
# (swappable) ball texture used by the physics balls.

var starting_level_id: int = 1
# The display name is "Nudge"; the second argument is file_names_prefix, which names every
# scores/settings/ongoing-score file under user:// — it must stay "ptbits" through any rename.
var game: GenericGameUtil = GenericGameUtil.new("Nudge", "ptbits", 0, 1, 0)

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

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]
