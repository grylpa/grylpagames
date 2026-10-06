extends Node

# LighthouseG autoload: Lighthouse's state between sessions, and the HUD's lives icon.
#
# The HUD's lives slot holds the round's LIFEBUOYS: each round starts with the level's
# `max_crashes`, a collision costs one, and losing the last one loses the round.
# The icon for it is a lifebuoy, baked here once.

var starting_level_id: int = 1

# The lives argument only switches the HUD's lives counter on; each round sets the real number.
var game: GenericGameUtil = GenericGameUtil.new("Lighthouse", "lighthouse", 0, 5, 0, 3)

const ICON_PX: int = 64
var _buoy_icon: Texture2D = null

func init_globals() -> void:
	# No session clock: each round has its own time limit (LighthouseLevelConfig round_sec), run by
	# the level.
	game.uses_session_clock = false

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])

# A lifebuoy seen from above: a white ring with four red bands, a dark rim and a soft highlight.
# One pass over the pixels, with antialiased edges, because it is baked at 64 and shown at 32.
func buoy_icon() -> Texture2D:
	if _buoy_icon != null:
		return _buoy_icon
	var img: Image = Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var c: float = float(ICON_PX) * 0.5
	var r_out: float = c - 2.0
	var r_in: float = r_out * 0.52
	var white: Color = Color(0.97, 0.97, 0.95)
	var red: Color = Color(0.90, 0.20, 0.18)
	var rim: Color = Color(0.25, 0.08, 0.08)
	for y in ICON_PX:
		for x in ICON_PX:
			var p: Vector2 = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c)
			var d: float = p.length()
			var a_out: float = clampf(r_out - d + 0.5, 0.0, 1.0)
			var a_in: float = clampf(d - r_in + 0.5, 0.0, 1.0)
			var alpha: float = minf(a_out, a_in)
			if alpha <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# four bands, each a quarter of the way round, centred on the diagonals
			var ang: float = fposmod(atan2(p.y, p.x) + PI * 0.25, PI * 0.5)
			var band: bool = absf(ang - PI * 0.25) < PI * 0.11
			var col: Color = red if band else white
			# round profile across the ring: lit toward the upper left, darker at both edges
			var u: float = (d - r_in) / (r_out - r_in) * 2.0 - 1.0
			var shade: float = 1.0 - 0.35 * u * u
			var lit: float = clampf(0.5 - (p.x + p.y) / (2.0 * r_out), 0.0, 1.0)
			col = col.darkened(0.30 * (1.0 - shade)).lightened(0.18 * lit * shade)
			# a thin dark rim at both edges
			if d > r_out - 2.0 or d < r_in + 1.5:
				col = col.lerp(rim, 0.55)
			col.a = alpha
			img.set_pixel(x, y, col)
	_buoy_icon = ImageTexture.create_from_image(img)
	return _buoy_icon
