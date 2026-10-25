shader_type canvas_item;

// The card BACK with rounded corners, the same radius as the front's (card.gd CARD_RADIUS), so the
// card keeps one shape when it is turned over. The back art is a square texture; this only cuts its
// corners, with a one-pixel soft edge.

uniform float radius_px = 9.0;
uniform vec2 size_px = vec2(80.0, 80.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = (UV - 0.5) * size_px;
	vec2 q = abs(p) - (size_px * 0.5 - vec2(radius_px));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius_px;
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	COLOR = c;
}
