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
	# The BASE of a ball: white, so a per-ball modulate tints it to any color, shaded as a sphere
	# lit from the top left. The light in the arena comes from the inlet up there (see
	# PtbitsArt.backdrop), so every object shades the same way and the scene holds together.
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: float = (d - 1) * 0.5
	var rad: float = c - 1.0
	var light: Vector2 = Vector2(-0.35, -0.42)
	for y in d:
		for x in d:
			var off: Vector2 = Vector2(float(x) - c, float(y) - c)
			var dist: float = off.length()
			var a: float = clampf(rad - dist + 1.0, 0.0, 1.0)  # 1px anti-aliased edge
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Distance from the lit point rather than from the center: a flat radial falloff makes
			# a disc with a dark ring, not a ball.
			var lit: float = clampf(1.06 - 0.62 * ((off / rad) - light).length(), 0.42, 1.0)
			img.set_pixel(x, y, Color(lit, lit, lit, a))
	return ImageTexture.create_from_image(img)

# Highlight and rim light, kept OUT of the base texture and drawn over it untinted. They have to be
# white, and `modulate` multiplies — white times a saturated red is red, so a specular baked into
# the tinted texture is not a specular at all, just a paler patch of the ball's own color.
var _sheen_tex: Texture2D = null

func ball_sheen_texture() -> Texture2D:
	if _sheen_tex == null:
		_sheen_tex = _make_sheen_texture(96)
	return _sheen_tex

func _make_sheen_texture(d: int) -> Texture2D:
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: float = (d - 1) * 0.5
	var rad: float = c - 1.0
	var spec_at: Vector2 = Vector2(-0.34, -0.40)
	for y in d:
		for x in d:
			var off: Vector2 = Vector2(float(x) - c, float(y) - c)
			var dist: float = off.length()
			var edge_a: float = clampf(rad - dist + 1.0, 0.0, 1.0)
			if edge_a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var nrm: Vector2 = off / rad
			var spec: float = clampf(1.0 - (nrm - spec_at).length() / 0.40, 0.0, 1.0)
			spec = spec * spec * 0.80
			# A crescent of bounced light on the shadow side is what stops a shaded ball from
			# looking like it is fading out into the background.
			var near_edge: float = clampf(1.0 - (rad - dist) / (rad * 0.17), 0.0, 1.0)
			var facing: float = clampf(nrm.normalized().dot(Vector2(0.60, 0.78)), 0.0, 1.0)
			var rim: float = near_edge * facing * facing * 0.55
			img.set_pixel(x, y, Color(1, 1, 1, clampf(spec + rim, 0.0, 1.0) * edge_a))
	return ImageTexture.create_from_image(img)

# One soft radial falloff, tinted at the draw site. Used for the inlet light, the halo around each
# basket, a ball's colored glow and the flash when a bumper is struck.
var _glow_tex: Texture2D = null

func glow_texture() -> Texture2D:
	if _glow_tex == null:
		_glow_tex = _make_glow_texture(128)
	return _glow_tex

func _make_glow_texture(d: int) -> Texture2D:
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: float = (d - 1) * 0.5
	for y in d:
		for x in d:
			var t: float = clampf(1.0 - Vector2(float(x) - c, float(y) - c).length() / c, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, t * t * t))
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
