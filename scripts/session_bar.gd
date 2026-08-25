extends RefCounted
class_name SessionBar

# The thin session-progress bar along the top edge of the breathing games.
#
# udbr, breathe, crack and mother all run a fixed-length session with nothing to score against a
# clock, so none of them wants a digital countdown: a number counting down is something to read and
# do arithmetic on, which is the opposite of what these games want the player doing. A bar is
# glanceable and needs no attention at all.
#
# It lived as four near-identical copies. They had already drifted — udbr had no mobile boost at
# all while breathe did — which is the usual way this ends.
#
# Colors are the CALLER's, because they are not a detail: the cyan udbr and breathe use belongs to
# their cool backgrounds and reads as a foreign object on mother's dunes, where the bar is drawn in
# the mother snake's own amber so it belongs to the scene rather than sitting on top of it. Only
# the geometry and the alpha policy are shared.

const PAD_X: float = 24.0
const Y: float = 18.0
const H_MOBILE: float = 7.0
const H_DESKTOP: float = 5.0

# Alpha is quoted for DESKTOP and boosted on mobile. Desktop values are tuned faint for a calm
# look and wash out on a bright phone screen — the same reason breathe boosts its whole foreground.
const TRACK_ALPHA: float = 0.12
const FILL_ALPHA: float = 0.28
const MOBILE_BOOST: float = 2.5

# The bar as data: `[{"rect": Rect2, "color": Color}, ...]`, track first, fill second (absent at
# zero progress). Split out from the drawing so the geometry and the alpha policy can be asserted
# directly — the alternative was a probe that intercepted draw_rect, which means shadowing a native
# method, and that is never worth it.
#
# `track_rgb` / `fill_rgb` are used for their RGB only; their alpha is ignored, so a caller can pass
# a palette color straight in. `alpha_scale` lifts both, for a game whose background is light enough
# that the standard values disappear into it.
static func rects(width: float, progress: float, track_rgb: Color, fill_rgb: Color,
		alpha_scale: float = 1.0, mobile: bool = false) -> Array:
	if width <= PAD_X * 2.0:
		return []
	var boost: float = alpha_scale * (MOBILE_BOOST if mobile else 1.0)
	var bar_h: float = H_MOBILE if mobile else H_DESKTOP
	var bar_w: float = width - PAD_X * 2.0
	var out: Array = [{
		"rect": Rect2(PAD_X, Y, bar_w, bar_h),
		"color": Color(track_rgb.r, track_rgb.g, track_rgb.b, minf(TRACK_ALPHA * boost, 1.0)),
	}]
	var p: float = clampf(progress, 0.0, 1.0)
	if p > 0.0:
		out.append({
			"rect": Rect2(PAD_X, Y, bar_w * p, bar_h),
			"color": Color(fill_rgb.r, fill_rgb.g, fill_rgb.b, minf(FILL_ALPHA * boost, 1.0)),
		})
	return out

static func draw(canvas: CanvasItem, width: float, progress: float,
		track_rgb: Color, fill_rgb: Color, alpha_scale: float = 1.0) -> void:
	if canvas == null:
		return
	for part in rects(width, progress, track_rgb, fill_rgb, alpha_scale, MainGlobals.is_mobile()):
		canvas.draw_rect(part["rect"], part["color"], true)

# What udbr, breathe and crack all use: cyan on a dark, cool background.
const COOL_TRACK: Color = Color(0.3, 0.55, 0.65)
const COOL_FILL: Color = Color(0.4, 0.82, 0.92)

static func draw_cool(canvas: CanvasItem, width: float, progress: float) -> void:
	draw(canvas, width, progress, COOL_TRACK, COOL_FILL)
