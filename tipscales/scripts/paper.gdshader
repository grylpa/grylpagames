shader_type canvas_item;

// THE CLUE PAPER, rendered once (level.gd _bake) and drawn under each scale's engraving: an old ledger
// slip -- warm off-white laid paper with fibers and chain lines, a few foxing spots, the edges browned and
// deckled (torn, not cut: the alpha follows a ragged line), a soft fold across the middle.

uniform vec2 size = vec2(320.0, 150.0);
uniform float seed = 3.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.31);
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
		p = p * 2.07 + 7.3;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec3 base = vec3(0.95, 0.91, 0.81);
	float cloud = fbm(px * 0.012);
	vec3 col = base * (0.93 + 0.09 * cloud);
	// fibers and the laid lines of the mould
	col *= 1.0 - 0.035 * smoothstep(0.6, 0.9, fbm(vec2(px.x * 0.4, px.y * 0.05)));
	col *= 1.0 - 0.025 * (0.5 + 0.5 * sin(px.y * 1.3));
	col *= 1.0 - 0.04 * smoothstep(0.75, 0.95, sin(px.x * 0.11) * 0.5 + 0.5);
	// foxing
	float fox = smoothstep(0.80, 0.86, fbm(px * 0.05 + 21.0));
	col = mix(col, vec3(0.78, 0.62, 0.42), fox * 0.35);
	// the edges: browned, and torn
	float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	float rag = 2.2 + 2.0 * fbm(vec2(px.x + px.y, px.y - px.x) * 0.25);
	float alpha = smoothstep(rag - 1.0, rag + 0.6, e);
	col = mix(vec3(0.70, 0.52, 0.32), col, smoothstep(0.0, 14.0 + 10.0 * cloud, e));
	// a soft fold, slightly off center
	float fold = abs(px.x - size.x * 0.52);
	col *= 1.0 - 0.05 * (1.0 - smoothstep(0.0, 6.0, fold)) + 0.025 * (1.0 - smoothstep(0.0, 14.0, fold - 4.0));
	COLOR = vec4(col, alpha);
}
