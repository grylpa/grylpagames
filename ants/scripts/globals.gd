extends Node

# AntsG autoload. Owns the GenericGameUtil instance and the settings.

var starting_level_id: int = 1

# How many times larger an ANT is drawn than on a desktop -- and nothing else.
#
# It is not resolution. The canvas is 680 units wide on both, so an ant is the same fraction of the
# screen on either -- but that fraction is 4.85 mm on a desktop window and 1.13 mm on a phone, about
# 2.1x smaller to the eye at normal viewing distances.
#
# The first attempt scaled the whole picture, by shrinking the world in units and zooming the
# camera. That is the same photograph enlarged: the nest and the food pile grew with the ants, and
# because an ant's speed is in units per second it crossed a smaller world far quicker -- journeys
# fell from 11.7 s to 3.9 s and the colony played a different, much easier game. The world, the
# nest, the piles, the obstacles and every journey time now stay exactly as they are on a desktop.
# Only the ant grows, along with the two things that are genuinely about its body: how much room it
# takes from its neighbours, and how far its own bulk keeps it off the wall.
const CREATURE_SCALE_MOBILE: float = 2.0
var creature_scale: float = 1.0
# The second argument is file_names_prefix and names every file this game keeps under user://.
# It must stay "ants" through any rename of the display name.
var game: GenericGameUtil = GenericGameUtil.new("Ants", "ants", 0, 5, 0)

# --- top-strip pictogram -----------------------------------------------------
# Drawn rather than imported, like everything else in this game: a dark ant standing on an opaque
# light disc.
#
# The disc is not decoration. The counters sit inside the HUD's BkLabel, a band of flat dark grey,
# where the ant's own body color measures 1.9:1 against the background -- invisible. The first two
# attempts gave the ant a light HALO instead, and both were wrong for the same reason: the legs are
# 0.030 wide, so an outline thick enough to read at 32 px was thicker than the thing it outlined,
# and the glow between the legs merged into a blob. A solid plate is one shape rather than seven
# glowing slivers, and it puts every part of the ant on the same background.
#
# Yellow, because the number beside it is yellow -- the two read as one counter. It is passed to
# the HUD with Color.WHITE so the strip's own yellow tint does not repaint the ant along with it.
const ICON_PX: int = 64
const ICON_BODY: Color = Color(0.070, 0.050, 0.040, 1.0)   # the ant
const ICON_DISC: Color = Color(0.980, 0.920, 0.450, 1.0)   # the plate it stands on
const ICON_R: float = 0.455                                # disc radius, in icon-box units
const ICON_ANT: float = 0.82                               # the ant, shrunk to sit inside the disc
# The shape below is not centered on its own origin: the gaster reaches y +0.335 and an antenna tip
# y -0.424, so drawing it about (0,0) would sit it low on the plate. This is the middle of its
# bounding box, and the plate is drawn about it.
const ICON_ANT_Y: float = -0.0445
var _ant_icon: Texture2D = null

func ant_icon() -> Texture2D:
	if _ant_icon == null:
		_ant_icon = _bake_icon()
	return _ant_icon

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# One pass over the pixels, off two signed distances: the disc's, which decides the alpha, and the
# ant's, which decides the color. Both edges come out antialiased over one pixel for free, which
# matters because this is baked at 64 and shown at 32.
func _bake_icon() -> Texture2D:
	var img: Image = Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var aa: float = 1.0 / float(ICON_PX)
	for y in ICON_PX:
		for x in ICON_PX:
			var p: Vector2 = Vector2((float(x) + 0.5) / float(ICON_PX) - 0.5,
				(float(y) + 0.5) / float(ICON_PX) - 0.5)
			var disc: float = p.length() - ICON_R
			if disc > aa:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# _shape_dist works in its own units, so scale in and the distance back out.
			var q: Vector2 = p / ICON_ANT + Vector2(0.0, ICON_ANT_Y)
			var ink: float = clampf(0.5 - (_shape_dist(q) * ICON_ANT) / (2.0 * aa), 0.0, 1.0)
			img.set_pixel(x, y, Color(ICON_DISC.lerp(ICON_BODY, ink),
				clampf(0.5 - disc / (2.0 * aa), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

# Signed distance to the pictogram: negative inside. An ant seen from above -- gaster, thorax, head,
# six legs in the X a real one makes, two antennae.
func _shape_dist(p: Vector2) -> float:
	var best: float = 9.0
	for ball in [[Vector2(0.0, 0.21), 0.125], [Vector2(0.0, 0.02), 0.085], [Vector2(0.0, -0.17), 0.10]]:
		best = minf(best, p.distance_to(ball[0] as Vector2) - float(ball[1]))
	var lw: float = 0.030
	# Front pair reaching forward, middle pair straight out, hind pair swept back.
	for leg in [[Vector2(0.03, -0.05), Vector2(0.30, -0.22)], [Vector2(0.03, 0.02), Vector2(0.33, 0.02)],
			[Vector2(0.03, 0.09), Vector2(0.29, 0.26)]]:
		best = minf(best, _seg_dist(p, leg[0] as Vector2, leg[1] as Vector2) - lw)
		best = minf(best, _seg_dist(p, Vector2(-(leg[0] as Vector2).x, (leg[0] as Vector2).y),
			Vector2(-(leg[1] as Vector2).x, (leg[1] as Vector2).y)) - lw)
	for ant in [[Vector2(0.04, -0.23), Vector2(0.16, -0.40)]]:
		best = minf(best, _seg_dist(p, ant[0] as Vector2, ant[1] as Vector2) - lw * 0.8)
		best = minf(best, _seg_dist(p, Vector2(-(ant[0] as Vector2).x, (ant[0] as Vector2).y),
			Vector2(-(ant[1] as Vector2).x, (ant[1] as Vector2).y)) - lw * 0.8)
	return best

func init_globals() -> void:
	creature_scale = CREATURE_SCALE_MOBILE if MainGlobals.is_mobile() else 1.0
	game.init_sizes()
	game.reset(true)

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]
