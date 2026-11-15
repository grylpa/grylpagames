shader_type canvas_item;

// THE TABLECLOTH under Polka Dots' panels (2026-11-15; main.gd puts it on a full-screen rect on its own
// layer behind everything): a dark, cool slate LINEN -- a fine plain weave at very low contrast, the odd
// slub in the thread, a soft light from the top left and a gentle fall-off to the edges. It replaced
// wooden boards, which were "more distracting than beautiful": grain, knots and joints competed with
// the dots. The panels are the stimulus; the ground under them should be all but plain.

uniform vec2 size = vec2(680.0, 788.0);

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

void fragment() {
	vec2 p = UV * size;
	vec3 base = vec3(0.155, 0.180, 0.215);
	// the plain weave: warp and weft threads crossing, each a hair lighter where it rides on top
	vec2 cell = floor(p / 3.0);
	vec2 f = fract(p / 3.0);
	float over = mod(cell.x + cell.y, 2.0);
	float thread = over > 0.5 ? smoothstep(0.0, 0.5, f.y) * smoothstep(1.0, 0.5, f.y)
		: smoothstep(0.0, 0.5, f.x) * smoothstep(1.0, 0.5, f.x);
	float weave = 0.025 * thread;
	// slubs: the odd thicker stretch of thread, very faint
	float slub = smoothstep(0.78, 0.95, noise(vec2(p.x / 40.0, floor(p.y / 3.0) * 0.37))) * 0.025;
	// a soft light from the top left, falling off to the edges
	vec2 q = UV - vec2(0.38, 0.30);
	float light = 1.08 - 0.30 * dot(q, q) * 2.2;
	vec3 col = (base + weave + slub) * light;
	COLOR = vec4(col, 1.0);
}
