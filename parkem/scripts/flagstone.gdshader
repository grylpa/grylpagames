shader_type canvas_item;

// THE MAZE FLOOR, on every floor tile's sprite (pipe.gd gives them one shared material): worn
// FLAGSTONES -- irregular slabs (the nearest of a jittered grid of points, two to three tiles across),
// each its own shade, with darker mortar between them, faint grain and a little moss in the joints.
// LOW CONTRAST on purpose: the doors drawn over the floor are the player's only control -- a closed
// one is a thin diagonal LINE -- and must stay the clearest lines on it, so the joints are thin and
// faint (a first version's dark, wide mortar ran at every angle and competed with them). In world coordinates, so the slabs run across tiles.

varying vec2 world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.3));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float cell = 46.0;
	vec2 p = world / cell;
	vec2 ip = floor(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = ip + vec2(float(x), float(y));
			vec2 at = c + 0.15 + 0.7 * hash2(c);
			float d = length(p - at);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = d2 - d1;                       // 0 on a joint between two slabs
	float mortar = (1.0 - smoothstep(0.015, 0.045, edge)) * 0.45;
	vec3 stone = vec3(0.255, 0.262, 0.275) * (0.94 + 0.10 * hash(id + 3.1));
	stone *= 1.0 + (hash(floor(world / 1.4)) - 0.5) * 0.08;
	vec3 joint = mix(vec3(0.15, 0.16, 0.16), vec3(0.17, 0.22, 0.15), step(0.7, hash(id + 9.0)));
	vec3 col = mix(stone, joint, mortar);
	// a slab's edge catches a little light on its top-left side
	col += vec3(0.025) * (1.0 - smoothstep(0.07, 0.14, edge)) * (1.0 - mortar);
	COLOR = vec4(col, tex.a);
}
