shader_type canvas_item;
render_mode blend_add, unshaded;

// Two things seen WITHOUT the game's lights, drawn above the dark, added to it:
//   mode 0, the moonlit sheen: a faint shimmer of the sea everywhere, so the dark reads as water at
//     night rather than a void. It is the same everywhere it is drawn and knows nothing of the rocks,
//     so it gives none of them away.
//   mode 1, mist in the beam: the beam's own texture, faint, broken by slowly drifting haze.
// `t` is the game's clock in seconds (it stops when the game does).

uniform float t = 0.0;
uniform float k = 1.0;
uniform int mode = 0;
uniform float strength = 1.0;
uniform vec4 clip = vec4(-1e6, -1e6, 1e6, 1e6);   // the sea: x0, y0, x1, y1

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

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec2 q = world / k;
	if (mode == 0) {
		// sparse glints of moonlight, stretched along the wave crests (across the screen), drifting
		// with the wind and blinking as the swell lifts them
		float n = noise(q * vec2(0.035, 0.22) - vec2(t * 0.8, 0.0));
		float m = noise(q * vec2(0.020, 0.12) + vec2(t * 0.35, 1.3));
		float glint = smoothstep(0.70, 0.92, n * 0.65 + m * 0.35);
		float broad = 0.4 + 0.6 * noise(q * 0.008 + vec2(t * 0.02, 0.0));
		COLOR = vec4(vec3(0.55, 0.68, 0.85) * (0.012 + 0.11 * glint * broad) * strength, 1.0);
	} else {
		if (world.x < clip.x || world.y < clip.y || world.x > clip.z || world.y > clip.w) {
			discard;
		}
		vec4 tex = texture(TEXTURE, UV);
		float haze = noise(q * 0.018 - vec2(t * 0.25, t * 0.08)) * 0.6
			+ noise(q * 0.045 + vec2(t * 0.15, 0.0)) * 0.4;
		COLOR = vec4(tex.rgb * tex.a * (0.05 + 0.13 * haze) * strength, 1.0);
	}
}
