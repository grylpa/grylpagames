shader_type canvas_item;

// The night sea. Lit only by the game's two lights (the beam and the boat's lamp), so the dark hides
// it exactly as it hides the rocks. What the light finds is WATER: a moving surface whose normals come
// from a few wind waves plus fine chop, so the beam shades the swells and throws glints off the crests
// that face it. Drifts with the wind to the right, as the old drawn crests did.
//
// `t` is the game's own clock (seconds), not TIME: the sea stands still while the game is paused or a
// tutorial caption is up, like everything else in it.

uniform float t = 0.0;
uniform float k = 1.0;                       // sea width / 680: wave sizes follow the sea
uniform vec3 deep : source_color = vec3(0.07, 0.20, 0.34);
uniform vec3 shallow : source_color = vec3(0.16, 0.36, 0.52);
uniform float glint = 1.6;

varying vec2 world;

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

// The surface's height: three long swells from slightly different directions, all running with the
// wind, and two octaves of chop on top.
float height(vec2 p) {
	vec2 q = p / k;
	float h = 0.0;
	h += 0.50 * sin(dot(q, vec2(0.060, 0.018)) - t * 1.30);
	h += 0.35 * sin(dot(q, vec2(0.045, -0.035)) - t * 1.05 + 1.7);
	h += 0.25 * sin(dot(q, vec2(0.085, 0.050)) - t * 1.75 + 4.1);
	vec2 drift = vec2(t * 20.0, 0.0);
	h += 0.45 * noise((q - drift) * 0.09);
	h += 0.22 * noise((q - drift * 1.3) * 0.21 + 7.3);
	return h;
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	float e = 1.5 * k;
	float hx = height(world + vec2(e, 0.0)) - height(world - vec2(e, 0.0));
	float hy = height(world + vec2(0.0, e)) - height(world - vec2(0.0, e));
	NORMAL = normalize(vec3(-hx * 1.1, -hy * 1.1, 1.0));
	// broad patches of darker and lighter water
	float patch = noise(world / k * 0.012 + vec2(t * 0.03, 0.0));
	COLOR = vec4(mix(deep, shallow, 0.35 + 0.5 * patch), 1.0);
}

void light() {
	vec3 to_light = normalize(LIGHT_POSITION - LIGHT_VERTEX);
	float diff = 0.60 + 0.70 * max(dot(NORMAL, to_light), 0.0);
	vec3 half_v = normalize(to_light + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(NORMAL, half_v), 0.0), 90.0) * glint;
	vec3 lc = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	LIGHT = vec4(COLOR.rgb * lc * diff + lc * spec, LIGHT_COLOR.a);
}
