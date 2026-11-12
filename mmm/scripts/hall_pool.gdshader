shader_type canvas_item;

// A REFLECTING POOL in the great hall (hall_decor.gd puts it on a ColorRect the pool's size): a raised
// rim of veined marble, beveled and lit from the top left, and WATER inside -- deep and dark, darker
// still in the shade under the rim on the light's side, its surface moving in two sets of slow small
// waves whose slopes catch the hall's light as soft glints, the reflection of the room's warm light
// lying along it, and water lilies floating, a few in flower. Seen from straight above like the board.
// In the rect's OWN space (UV), never MODEL_MATRIX (it moves with the camera in this game).

uniform vec2 size = vec2(160.0, 80.0);       // px
uniform float rim = 9.0;                       // px
uniform float seed = 0.0;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

float height(vec2 p, float t) {
	return fbm(p / 18.0 + vec2(t * 0.20, t * 0.12)) + 0.7 * fbm(p / 11.0 - vec2(t * 0.16, -t * 0.19) + 5.0);
}

void fragment() {
	vec2 p = UV * size;
	float t = TIME + seed * 40.0;
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	vec3 col;
	if (edge < rim) {
		// the marble rim: veined ivory; its outer edge lit on the top and left, shaded on the bottom and
		// right; a dark line where it meets the water
		vec3 m = vec3(0.80, 0.77, 0.70) * (0.94 + 0.08 * fbm(p / 9.0 + seed));
		float v = abs(fbm(p / 14.0 + seed * 3.0) - 0.5);
		m = mix(m, vec3(0.58, 0.55, 0.52), (1.0 - smoothstep(0.0, 0.025, v)) * 0.5);
		float lit = 0.0;
		lit += (1.0 - smoothstep(0.0, 2.5, p.y)) * 0.20 + (1.0 - smoothstep(0.0, 2.5, p.x)) * 0.12;
		lit -= (1.0 - smoothstep(0.0, 2.5, size.y - p.y)) * 0.28 + (1.0 - smoothstep(0.0, 2.5, size.x - p.x)) * 0.20;
		m *= 1.0 + lit;
		m *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 1.6, rim - edge));
		col = m;
	} else {
		vec2 w = p - vec2(rim);
		vec2 ws = size - vec2(rim) * 2.0;
		// the surface: its slope from two sets of moving waves
		float h = height(p, t);
		float hx = height(p + vec2(0.6, 0.0), t);
		float hy = height(p + vec2(0.0, 0.6), t);
		vec2 slope = vec2(hx - h, hy - h) / 0.6;
		float facing = dot(slope, normalize(vec2(-0.45, -0.9)));
		// deep water, lighter where the surface tilts toward the light, darkest under the rim it is in the
		// shade of (the top and left)
		vec3 deep = vec3(0.03, 0.11, 0.15);
		vec3 lit = vec3(0.10, 0.27, 0.33);
		col = mix(deep, lit, clamp(0.45 + facing * 6.0, 0.0, 1.0));
		float shade = (1.0 - smoothstep(0.0, 7.0, w.y)) * 0.55 + (1.0 - smoothstep(0.0, 6.0, w.x)) * 0.35;
		col *= 1.0 - clamp(shade, 0.0, 0.7);
		// the warm light of the hall lying along the water, broken by the waves
		float band = exp(-pow((w.y - ws.y * 0.35 - (w.x - ws.x * 0.5) * 0.25) / (ws.y * 0.22), 2.0));
		col += vec3(0.30, 0.22, 0.12) * band * clamp(0.3 + facing * 9.0, 0.0, 1.0) * 0.55;
		// glints
		col += vec3(0.95, 0.90, 0.80) * pow(clamp(facing * 9.0, 0.0, 1.0), 6.0) * 0.6;
		// water lilies: at most one in each cell of a loose grid, a round pad with a notch, a lighter
		// rim and veins; a few in flower
		float cell = 24.0;
		vec2 gi = floor(w / cell);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = gi + vec2(float(x), float(y));
				float hh = hash(c + seed * 13.0);
				if (hh < 0.55) {
					continue;
				}
				vec2 at = (c + 0.25 + 0.5 * vec2(hash(c + 1.7 + seed), hash(c + 3.1 + seed))) * cell;
				float r = 6.5 + 4.0 * hash(c + 5.3);
				vec2 q = w - at;
				// keep the pads inside the water
				if (at.x < r || at.y < r || at.x > ws.x - r || at.y > ws.y - r) {
					continue;
				}
				float a = atan(q.y, q.x);
				float notch_a = hash(c + 9.9) * 6.2832;
				float notch = 1.0 - smoothstep(0.10, 0.22, abs(mod(a - notch_a + 3.1416, 6.2832) - 3.1416));
				float d = length(q);
				float pad = (1.0 - smoothstep(r - 0.8, r + 0.4, d)) * (1.0 - notch * step(d, r) * step(r * 0.15, d));
				// the pad's shadow on the water, a little down and right
				float psh = 1.0 - smoothstep(r - 1.0, r + 1.5, length(q - vec2(1.6, 2.2)));
				col *= 1.0 - psh * 0.35 * (1.0 - pad);
				vec3 green = mix(vec3(0.14, 0.36, 0.16), vec3(0.34, 0.60, 0.28), clamp(0.5 - dot(q / r, vec2(-0.45, -0.9)) * 0.5, 0.0, 1.0));
				green *= 0.92 + 0.12 * abs(sin(a * 9.0 + hh * 20.0));                 // veins
				green = mix(green, vec3(0.40, 0.66, 0.34), 1.0 - smoothstep(0.0, 1.2, r - d));   // rim
				col = mix(col, green, pad);
				if (hh > 0.85) {
					float fl = 1.0 - smoothstep(r * 0.42 - 0.6, r * 0.42 + 0.6, length(q) * (0.75 + 0.25 * abs(cos(a * 4.0))));
					col = mix(col, vec3(0.96, 0.74, 0.84), fl);
					col = mix(col, vec3(1.0, 0.86, 0.45), 1.0 - smoothstep(0.8, 1.6, d));
				}
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
