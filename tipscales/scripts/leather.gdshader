shader_type canvas_item;

// THE WORKBENCH, rendered once (level.gd _bake): a desk's inset of green leather, its grain pebbled and
// worn paler where hands rest, a gold-tooled double rule round it, in a frame of polished walnut.

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
	float frame = 9.0;
	float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	vec3 col;
	if (e < frame) {
		// walnut, polished: a bright edge on top, dark below
		float g = fbm(vec2(px.x * 0.03, px.y * 0.4) + px.y * 0.01);
		col = mix(vec3(0.20, 0.11, 0.06), vec3(0.42, 0.25, 0.13), g);
		float t = e / frame;
		col *= 0.7 + 0.5 * sin(t * 3.1416);
		if (px.y < frame && px.y < min(px.x, size.x - px.x)) col *= 1.25;
	} else {
		vec2 lp = px - vec2(frame);
		// pebbled grain: small cells, each a touch raised
		float pebble = noise(lp * 0.55) * 0.6 + noise(lp * 1.3) * 0.4;
		float wear = fbm(lp * 0.008);
		vec3 green = vec3(0.10, 0.24, 0.17);
		col = green * (0.80 + 0.35 * pebble) * (0.85 + 0.35 * wear);
		// paler in the middle, where the work is done
		vec2 c = (px - size * 0.5) / (size * 0.5);
		col += vec3(0.05, 0.06, 0.04) * (1.0 - smoothstep(0.0, 1.0, length(c * vec2(0.8, 1.2))));
		// the gold tooling: a double rule inside the frame
		float ein = e - frame;
		float r1 = 1.0 - smoothstep(0.4, 1.2, abs(ein - 5.0));
		float r2 = 1.0 - smoothstep(0.3, 0.9, abs(ein - 8.5));
		float gold_wear = 0.6 + 0.4 * fbm(px * 0.2);
		col = mix(col, vec3(0.78, 0.60, 0.28) * gold_wear, max(r1, r2 * 0.8) * 0.9);
		// the frame's shadow on the leather
		col *= 0.55 + 0.45 * smoothstep(0.0, 7.0, ein);
	}
	COLOR = vec4(col, 1.0);
}
