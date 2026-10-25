shader_type canvas_item;

// THE BOARD behind Weris: a dark CORKBOARD the photos are pinned to -- cork's fine granules (two
// scales of cell noise and a speckle of darker and lighter grains), a soft pool of light toward the
// top center and a darker edge all round. Dark and low in contrast on purpose: the faces are the game,
// and a busy board would make finding one harder in a way the game does not mean to measure. It
// replaced the shared dark-green backdrop.

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

// distance to the nearest of a jittered grid of points: cork's granules
float cells(vec2 p) {
	vec2 ip = floor(p);
	float d = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = ip + vec2(float(x), float(y));
			vec2 at = c + vec2(hash(c), hash(c + 7.3));
			d = min(d, length(p - at));
		}
	}
	return d;
}

void fragment() {
	vec2 px = UV * size;
	vec3 cork = vec3(0.36, 0.25, 0.16);
	float g = cells(px / 3.2) * 0.55 + cells(px / 7.5) * 0.45;
	float shade = 0.86 + 0.22 * g;
	float speck = hash(floor(px / 1.5));
	shade *= 1.0 + (step(0.93, speck) * 0.18) - (step(speck, 0.06) * 0.22);
	shade *= 0.94 + 0.12 * noise(px / 60.0);
	vec3 col = cork * shade;
	// the room's light: a soft pool toward the top center
	col *= 1.0 + 0.20 * (1.0 - smoothstep(0.0, 0.8, length((UV - vec2(0.5, 0.30)) * vec2(1.0, 1.2))));
	vec2 e = min(UV, 1.0 - UV);
	col *= mix(0.62, 1.0, smoothstep(0.0, 0.22, min(e.x, e.y)));
	COLOR = vec4(col, 1.0);
}
