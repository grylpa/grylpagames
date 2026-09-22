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
# The plate is the counter's own yellow, and it is PASSED IN rather than matched by hand: a plate
# that is almost the number's color reads as a mistake, and a hand-copied constant is exactly what
# drifts into almost. The default below is only what the icon bakes as if nobody says otherwise.
# It goes to the HUD with Color.WHITE so the strip's yellow tint does not repaint the ant with it.
const ICON_PX: int = 64
const ICON_BODY: Color = AntsArt.ANT_BODY                  # the ant, in the game's own color
const ICON_DISC: Color = Color(1.0, 1.0, 0.0, 1.0)         # the plate it stands on
const ICON_R: float = 0.455                                # disc radius, in icon-box units
const ICON_MARGIN: float = 0.085                           # clear ground between ant and rim
var _ant_icon: Texture2D = null
var _ant_icon_plate: Color = ICON_DISC

func ant_icon(plate: Color = ICON_DISC) -> Texture2D:
	if _ant_icon == null or not _ant_icon_plate.is_equal_approx(plate):
		_ant_icon_plate = plate
		_ant_icon = _bake_icon(plate)
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
func _bake_icon(plate: Color) -> Texture2D:
	var img: Image = Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var aa: float = 1.0 / float(ICON_PX)
	var fit: Dictionary = _ant_fit()
	var _mid: Vector2 = fit["mid"]
	var _k: float = (ICON_R - ICON_MARGIN) / float(fit["rad"])
	for y in ICON_PX:
		for x in ICON_PX:
			var p: Vector2 = Vector2((float(x) + 0.5) / float(ICON_PX) - 0.5,
				(float(y) + 0.5) / float(ICON_PX) - 0.5)
			var disc: float = p.length() - ICON_R
			if disc > aa:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# _shape_dist works in its own units, so scale in and the distance back out.
			var q: Vector2 = p / _k + _mid
			var ink: float = clampf(0.5 - (_shape_dist(q) * _k) / (2.0 * aa), 0.0, 1.0)
			img.set_pixel(x, y, Color(plate.lerp(ICON_BODY, ink),
				clampf(0.5 - disc / (2.0 * aa), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

# THE ICON'S ANT IS THE GAME'S ANT, off the same constants AntsArt.draw_ant uses: the same
# gaster/thorax/head proportions, the same splayed coxae, and above all the same ELBOWED legs. The
# first version drew six straight spokes instead, and it did not read as an ant -- which is the
# exact mistake ants_art.gd calls out and fixed once already for the real ones ("drawn as three
# parallel oars... an ant reads like a woodlouse"). Copying the numbers here rather than importing
# them is how the two would drift apart again, so they are read from AntsArt.
#
# Body-length units with the ant pointing UP, so fwd = (0,-1) and side = (1,0), and the gait frozen
# mid-stride (no swing term): a still picture of a walking ant, not of a standing one.
func _shape_dist(p: Vector2) -> float:
	var gaster: Vector2 = Vector2(0.0, 0.34)
	var thorax: Vector2 = Vector2(0.0, -0.04)
	var head: Vector2 = Vector2(0.0, -0.36)
	var best: float = minf(minf(p.distance_to(gaster) - 0.235, p.distance_to(thorax) - 0.150),
		p.distance_to(head) - 0.175)
	# AntsArt draws with draw_line, whose width is the FULL width; a distance field wants the half.
	var half_w: float = 0.075 * 0.5
	for i in 3:
		var base: Vector2 = thorax + Vector2(0.0, -float(AntsArt.COXA[i]))
		var ka: float = float(AntsArt.KNEE_SPLAY[i])
		var fa: float = float(AntsArt.FOOT_SPLAY[i])
		for s in [-1.0, 1.0]:
			# The knee splays less than the foot, which is what gives a leg its elbow.
			var knee: Vector2 = base + Vector2(s * cos(ka), -sin(ka)) * 0.34
			var foot: Vector2 = base + Vector2(s * cos(fa), -sin(fa)) * 0.60
			best = minf(best, _seg_dist(p, base, knee) - half_w)
			best = minf(best, _seg_dist(p, knee, foot) - half_w * 0.85)
	for s2 in [-1.0, 1.0]:
		best = minf(best, _seg_dist(p, head + Vector2(0.0, -0.10),
			head + Vector2(s2 * 0.30, -0.42)) - half_w * 0.8)
	return best

# Where the ant is and how big, MEASURED off the shape rather than authored. Two hand-set numbers
# used to do this -- a scale and a vertical offset -- and both were silently wrong the moment the
# art changed, which is what happened when the ant was rebuilt from AntsArt: it is a different size
# and it sits at a different height. Sampled once per bake, which happens once per run.
func _ant_fit() -> Dictionary:
	const N: int = 96
	const SPAN: float = 2.4
	var inside: Array[Vector2] = []
	var lo: Vector2 = Vector2(9.0, 9.0)
	var hi: Vector2 = Vector2(-9.0, -9.0)
	for iy in N:
		for ix in N:
			var q: Vector2 = Vector2(float(ix), float(iy)) / float(N - 1) * SPAN \
				- Vector2(SPAN, SPAN) * 0.5
			if _shape_dist(q) <= 0.0:
				inside.append(q)
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if inside.is_empty():
		return {"mid": Vector2.ZERO, "rad": 1.0}
	# The center of the BOX, so the ant looks centered; the radius that actually contains the ink,
	# rather than the box's corner, which no part of an ant ever reaches.
	var mid: Vector2 = (lo + hi) * 0.5
	var rad: float = 0.001
	for q2 in inside:
		rad = maxf(rad, (q2 - mid).length())
	return {"mid": mid, "rad": rad}

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
