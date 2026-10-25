shader_type canvas_item;

// THE EVENING behind Friends: dusk -- deep indigo at the top warming to plum and a low amber glow at
// the bottom -- with soft out-of-focus lights (BOKEH: warm street lamps and windows far off, three
// layers of them, drifting very slowly), thickest toward the bottom like a lit street, and a gentle
// vignette. Kept dark and soft so the photos, which are the game, are the brightest things on screen.
// It matches the evening-stroll ambient. It replaced the shared dark-green backdrop.

uniform vec2 size = vec2(680.0, 788.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 bokeh(vec2 px, float cell, float seed, float drift) {
	vec2 p = px / cell + vec2(TIME * drift, -TIME * drift * 0.6);
	vec2 ip = floor(p);
	vec3 acc = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = ip + vec2(float(x), float(y));
			float h = hash(c + seed);
			if (h > 0.55) {
				continue;
			}
			vec2 at = c + vec2(hash(c + seed + 3.1), hash(c + seed + 7.7));
			float r = 0.18 + 0.30 * hash(c + seed + 11.0);
			float d = length(p - at);
			// a soft disc with a slightly brighter rim, as an out-of-focus light is
			float disc = smoothstep(r, r * 0.80, d);
			float rim = smoothstep(r * 0.70, r * 0.95, d) * disc;
			vec3 tint = mix(vec3(1.0, 0.72, 0.38), vec3(1.0, 0.55, 0.55), hash(c + seed + 5.0));
			tint = mix(tint, vec3(1.0, 0.88, 0.62), step(0.8, hash(c + seed + 9.0)));
			float twinkle = 0.75 + 0.25 * sin(TIME * (0.4 + h) + h * 40.0);
			acc += tint * (disc * 0.65 + rim * 0.35) * (0.35 + 0.65 * h) * twinkle;
		}
	}
	return acc;
}

void fragment() {
	vec2 px = UV * size;
	float v = UV.y;
	vec3 top = vec3(0.075, 0.075, 0.180);
	vec3 mid = vec3(0.185, 0.110, 0.225);
	vec3 low = vec3(0.330, 0.175, 0.150);
	vec3 col = mix(top, mid, smoothstep(0.0, 0.55, v));
	col = mix(col, low, smoothstep(0.50, 1.0, v));
	// the lights: more of them, and brighter, toward the bottom
	float street = smoothstep(0.15, 1.0, v);
	col += bokeh(px, 120.0, 1.0, 0.010) * 0.10 * (0.3 + street);
	col += bokeh(px, 70.0, 7.0, 0.016) * 0.07 * (0.2 + street);
	col += bokeh(px, 38.0, 13.0, 0.024) * 0.05 * street;
	// vignette
	vec2 e = min(UV, 1.0 - UV);
	col *= mix(0.72, 1.0, smoothstep(0.0, 0.25, min(e.x, e.y)));
	COLOR = vec4(col, 1.0);
}
