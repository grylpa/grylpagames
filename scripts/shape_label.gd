extends Label
class_name ShapeLabel

# A drawn object in place of a tinted font glyph.
#
# It is a LABEL and not a plain Control on purpose. The sorting games lay their belt items out by
# measuring both objects and sharing the row's width in proportion to how wide each one actually
# is (`_share_pair_widths`), and that pass is typed to Label and works off text metrics. Keeping
# the Label means the shape sits exactly where the glyph would have, at the size the glyph would
# have been, with no layout code touched at all.
#
# The text is still set — it is what the layout measures — but drawn fully transparent, and the
# shape is drawn over it. `_draw()` on a Label adds to the built-in text drawing rather than
# replacing it, so making the text invisible is the way to stand it down.
#
# Why not keep the glyph: it is one flat silhouette at whatever weight the font has, it changes
# between fonts and platforms, and "★" renders as a blank box wherever the font lacks it — the same
# failure the tutorial's pointing hand is drawn as a polygon to avoid.

var base_color: Color = Color.WHITE:
	set(v):
		base_color = v
		queue_redraw()

# How much of the control the shape fills; the remainder is room for the drop shadow and the rim
# light, which would otherwise be clipped at the edge.
var fill_frac: float = 0.82:
	set(v):
		fill_frac = v
		queue_redraw()

func _ready() -> void:
	# Invisible text, kept for its metrics.
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	# The same card the text objects sit on, so a shape and a "7" look like the same kind of thing.
	add_theme_stylebox_override("normal", Sleek.tile())
	resized.connect(queue_redraw)

func _draw() -> void:
	var side: float = minf(size.x, size.y) * fill_frac
	if side <= 2.0:
		return
	var box: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	Sleek.draw_shape(self, text, box, base_color)

# `shape` is one of Sleek.FILLED / Sleek.HOLLOW.
static func make(shape: String, color: Color, font_size: int) -> ShapeLabel:
	var l: ShapeLabel = ShapeLabel.new()
	l.text = shape
	l.base_color = color
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
