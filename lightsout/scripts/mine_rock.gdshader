shader_type canvas_item;

// THE ROCK OF THE COAL MINE (LightsoutLevelConfig.LOOK 1): what the tunnels are cut through, in place of
// the garden's lawn (level.gd _fit_ground_to_board puts this on a rect where the lawn was). Dark rough
// rock in broad blocky masses with cracks between them, a seam of coal running through here and there
// (near-black, with a faint sheen), and now and then a fleck of mineral catching the light. In WORLD
// coordinates, like the floor.

varying vec2 world;
varying vec4 tint;      // the node's tint (modulate): dimmed with the tunnels when the lanterns go out

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.3));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	// blocky masses: the nearest of a coarse jittered grid; cracks where two masses meet
	vec2 g = world / 34.0;
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = gi + vec2(float(x), float(y));
			vec2 pt = c + 0.1 + 0.8 * hash2(c);
			float d = length(g - pt);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float crack = 1.0 - smoothstep(0.0, 0.05, d2 - d1);
	vec3 rock = mix(vec3(0.085, 0.078, 0.072), vec3(0.125, 0.112, 0.10), hash(id + 2.0));     // darker: see the floor
	rock *= 0.80 + 0.35 * noise(world / 7.0) + 0.10 * (noise(world / 2.0) - 0.5);
	// facets: each mass a little lighter on one side
	rock *= 0.92 + 0.12 * clamp(dot(normalize(g - (id + 0.5)), vec2(-0.6, -0.8)), -1.0, 1.0);
	vec3 col = mix(rock, vec3(0.03, 0.03, 0.03), crack * 0.8);
	// coal seams: broad, nearly level STRATA, gently warped, near-black with a faint bluish sheen, only
	// in some stretches (thin wiggly bands read as scribbles)
	float strata = (world.y + 26.0 * noise(world / 160.0) + 6.0 * noise(world / 40.0)) / 120.0;
	float band = abs(fract(strata) - 0.5) * 2.0;                     // 0 at a seam's middle
	float seam = (1.0 - smoothstep(0.10, 0.20, band)) * smoothstep(0.45, 0.65, noise(world / 200.0 + 5.0));
	vec3 coal = vec3(0.04, 0.04, 0.05) + vec3(0.05, 0.06, 0.08) * step(0.82, noise(world / 3.0));
	col = mix(col, coal, seam);
	// a rare mineral fleck
	float fleck = step(0.996, hash(floor(world / 1.5))) * step(0.6, noise(world / 50.0));
	col += vec3(0.30, 0.26, 0.16) * fleck * 0.45;
	COLOR = vec4(col, 1.0) * tint;
}
