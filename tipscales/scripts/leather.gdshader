shader_type canvas_item;

// THE WORKBENCH, rendered once (level.gd _bake): a desk's inset of green leather, its grain pebbled and
// worn paler where hands rest, a gold-tooled double rule round it. No walnut frame any more (it was 9 wide
// all round): the room went to the crates (the user); the leather's edge just darkens a little.

uniform vec2 size = vec2(650.0, 110.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.11 + 3.7;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	// pebbled grain: small cells, each a touch raised
	float pebble = noise(px * 0.55) * 0.6 + noise(px * 1.3) * 0.4;
	float wear = fbm(px * 0.008);
	vec3 green = vec3(0.10, 0.24, 0.17);
	vec3 col = green * (0.80 + 0.35 * pebble) * (0.85 + 0.35 * wear);
	// paler in the middle, where the work is done
	vec2 c = (px - size * 0.5) / (size * 0.5);
	col += vec3(0.05, 0.06, 0.04) * (1.0 - smoothstep(0.0, 1.0, length(c * vec2(0.8, 1.2))));
	// the gold tooling: a double rule round the edge
	float r1 = 1.0 - smoothstep(0.4, 1.2, abs(e - 4.0));
	float r2 = 1.0 - smoothstep(0.3, 0.9, abs(e - 7.5));
	float gold_wear = 0.6 + 0.4 * fbm(px * 0.2);
	col = mix(col, vec3(0.78, 0.60, 0.28) * gold_wear, max(r1, r2 * 0.8) * 0.9);
	// the leather's edge, turned down over the counter: a little darker
	col *= 0.70 + 0.30 * smoothstep(0.0, 3.0, e);
	COLOR = vec4(col, 1.0);
}
