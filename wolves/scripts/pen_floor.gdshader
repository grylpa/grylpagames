shader_type canvas_item;

// THE SHEEP PEN'S FLOOR (2026-11-12), on every compound tile's floor sprite (pipe.gd gives each its own
// material and tells it its cell): TRAMPLED EARTH with STRAW scattered over it -- warm brown soil,
// hoof-pocked, darker in damp patches, with short pale straw stalks lying every which way, thicker in
// drifts. It was a flat square in a color per level (purple, blue...), which said nothing about sheep.
// Laid from the cell, not MODEL_MATRIX; ignores the sprite's tint.

uniform vec2 cell = vec2(0.0);

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
	vec4 tex = texture(TEXTURE, UV);
	vec2 w = cell * 40.0 + UV * 40.0;
	// the earth: warm, uneven, darker where it is damp, pocked by hooves
	vec3 soil = mix(vec3(0.36, 0.26, 0.16), vec3(0.46, 0.34, 0.21), noise(w / 18.0));
	soil *= 0.90 + 0.14 * noise(w / 4.0);
	soil *= 1.0 - 0.18 * smoothstep(0.6, 0.85, noise(w / 45.0 + 3.0));
	vec2 g = w / 9.0;
	vec2 gi = floor(g);
	vec2 hp = (gi + 0.2 + 0.6 * vec2(hash(gi), hash(gi + 4.0))) * 9.0;
	float pock = 1.0 - smoothstep(1.2, 2.2, length(w - hp));
	soil *= 1.0 - 0.22 * pock * step(0.45, hash(gi + 2.0));
	// the cells as faint seams, like the pasture's (2026-11-13), fainter on the bedding
	vec2 dd = min(UV, 1.0 - UV) * 40.0;
	vec2 px = fwidth(w);
	float seam = max(1.0 - smoothstep(0.0, 0.6 + px.x, dd.x), 1.0 - smoothstep(0.0, 0.6 + px.y, dd.y));
	soil *= 1.0 - 0.10 * seam;
	vec3 col = soil;
	// straw: short stalks at random angles, in drifts
	float drift = smoothstep(0.35, 0.75, noise(w / 30.0 + 7.0));
	for (int k = 0; k < 3; k++) {
		float S = 6.0 + float(k) * 2.0;
		float off = float(k) * 13.1;
		vec2 sg = w / S + off;
		vec2 si = floor(sg);
		if (hash(si + 1.3) > 0.10 + 0.30 * drift) {           // sparse: the earth shows (dense, it was noise)
			continue;
		}
		vec2 c = (si + 0.5 - off) * S;
		float a = hash(si + 8.7) * 3.1416;
		vec2 d = vec2(cos(a), sin(a));
		vec2 rel = w - c;
		float along = dot(rel, d);
		float across = abs(dot(rel, vec2(-d.y, d.x)));
		float slen = 3.5 + 3.5 * hash(si + 2.9);
		float stalk = (1.0 - smoothstep(0.5, 1.0, across)) * (1.0 - smoothstep(slen - 1.0, slen, abs(along)));
		vec3 straw = mix(vec3(0.80, 0.68, 0.38), vec3(0.92, 0.82, 0.52), hash(si + 5.1));
		col = mix(col, straw, stalk * 0.75);
	}
	COLOR = vec4(col, tex.a);
}
