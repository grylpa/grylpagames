shader_type canvas_item;

// THE TUBES, on every tube tile's sprite (pipe.gd, one shared material). The tile art is shared with
// the road games -- asphalt gray with a dashed yellow center line -- so here the dashes are painted
// out and the gray becomes the inside of a glass tube: a cool, faintly blue-gray, slightly mottled.
// The tube's WALLS are drawn by pipe.gd on each side with no tube beyond it.

varying vec2 world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 inside = vec3(0.30, 0.34, 0.38);
	inside *= 1.0 + (hash(floor(world / 3.0)) - 0.5) * 0.04;
	COLOR = vec4(inside, tex.a);
}
