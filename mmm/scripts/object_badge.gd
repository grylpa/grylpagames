extends RefCounted

# How every Mind Palace OBJECT looks wherever it is shown -- over the player's head, on an open pedestal,
# in the announcements and the cards at the top (2026-11-15, "much more in-your-face"): a disc in the
# object's own color with a white ring and its symbol in white, so the same object is recognized at a
# glance in all of them.

static func draw(ci: CanvasItem, c: Vector2, r: float, sym: String, col: Color, alpha: float = 1.0) -> void:
	ci.draw_circle(c + Vector2(r * 0.06, r * 0.10), r * 1.04, Color(0, 0, 0, 0.40 * alpha))
	ci.draw_circle(c, r, Color(1, 1, 1, alpha))
	ci.draw_circle(c, r * 0.86, Color(col.r, col.g, col.b, alpha))
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.30), r * 0.38, Color(1, 1, 1, 0.16 * alpha))
	var f: Font = MainGlobals.get_system_sans_font()
	var fs: int = maxi(8, int(r * 1.15))
	var sz: Vector2 = f.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base: float = c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - fs * 0.04
	ci.draw_string_outline(f, Vector2(c.x - sz.x * 0.5, base), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		maxi(2, int(r * 0.10)), Color(0, 0, 0, 0.35 * alpha))
	ci.draw_string(f, Vector2(c.x - sz.x * 0.5, base), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
