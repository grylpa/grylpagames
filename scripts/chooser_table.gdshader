// The game chooser's background (2026-11-10): a lit table. The untidy, swaying tiles read as cards
// scattered on a table, so the ground is one, under a soft pool of warm light from above the center,
// falling off to darker edges.
//
// `style` (set per view by game_chooser.gd): 3 the LIST (since 2026-11-11) -- a night sky, see
// starfield(); 0 the list's earlier look, kept as its fallback -- plain cloth under a LIVING light (the
// pool drifts and breathes, and specks of dust float through it); 1 the GRID -- the woven art-deco
// fans, static. (The fans were tried under the list too, faint and large: they fought the rows and the
// hover patch. And the first living light was too slow and small to be seen at all.) Tried and turned down: a gold inlay round the cloth, and dark walnut planks
// ("doesn't speak with the game"). `strong_light` is the stronger pool of light from the inlay trial,
// the one part of it the user liked.
shader_type canvas_item;

uniform int style = 0;
uniform bool strong_light = true;
uniform vec2 px_size = vec2(680.0, 788.0);   // the rect's size, so the weave is in screen units
uniform vec3 cloth = vec3(0.115, 0.150, 0.260);   // the navy cloth, unlit
uniform vec3 warm = vec3(0.976, 0.792, 0.353);    // the app's gold, as the lamp's color
uniform float weave_px = 3.2;                      // one thread, in units
uniform float fan_px = 64.0;                       // one fan of the pattern, across

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The card-table pattern (2026-11-10): art-deco fans in rows, each overlapping the row above -- a
// woven-in figure a shade darker than the cloth, its rim a faint gold thread. Returns
// (dark lines 0..1, gold rim 0..1).
vec2 fan_pattern(vec2 p, float w) {
	float h = w * 0.5;
	float r0 = w * 0.5;
	vec2 best = vec2(0.0);
	// a point belongs to the fan of its own row if it lies inside it, else to the row above's
	for (int k = 0; k < 2; k++) {
		float row = floor(p.y / h) - float(k);
		float shift = mod(row, 2.0) * 0.5 * w;
		float cx = (floor((p.x + shift) / w) + 0.5) * w - shift;
		vec2 c = vec2(cx, (row + 1.0) * h);
		vec2 v = p - c;
		float d = length(v);
		if (d < r0 && v.y <= 0.0) {
			float r = d / r0;
			float aa = fwidth(r) * 1.2;
			// concentric arcs
			float arcs = 1.0 - smoothstep(0.0, aa * 4.0, abs(fract(r * 4.0) - 0.5) - 0.5 + 0.06);
			// the ribs, fanning out from the base
			float ang = atan(v.x, -v.y);
			float ra = ang * 9.0 / 3.14159;
			float ribs = (1.0 - smoothstep(0.0, fwidth(ra) * 1.5, abs(fract(ra) - 0.5) - 0.5 + 0.05)) * smoothstep(0.25, 0.45, r);
			float rim = 1.0 - smoothstep(0.0, aa * 2.0, abs(r - 0.97) - 0.02);
			best = vec2(max(arcs, ribs) * (1.0 - rim), rim);
			break;
		}
	}
	return best;
}

// (style 2, slow aurora ribbons in gold and teal over a night sky, was tried for the list on
// 2026-11-10 and turned down.)

// Style 3, the LIST's background (chosen 2026-11-11): a deep night sky -- stars at three depths drifting slowly
// at different speeds, so they pass each other, a soft glow from above, and now and then a shooting
// star.
float star_layer(vec2 p, float cell, float dens, float rmax) {
	vec2 cid = floor(p / cell);
	float s = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = cid + vec2(float(i), float(j));
			float hs = hash(id);
			if (hs > dens) {
				continue;
			}
			vec2 sp = (id + vec2(hash(id + 1.3), hash(id + 4.1))) * cell;
			float r = 0.6 + rmax * hash(id + 8.2);
			float tw = 0.65 + 0.35 * sin(TIME * (1.0 + hs * 3.0) + hs * 50.0);
			float d = length(p - sp);
			s += exp(-d * d / (r * r)) * tw * (0.5 + 0.5 * hash(id + 2.6));
		}
	}
	return s;
}

vec3 starfield(vec2 uv, vec2 p) {
	vec3 top = vec3(0.030, 0.040, 0.110);
	vec3 bottom = vec3(0.012, 0.016, 0.050);
	vec3 col = mix(top, bottom, smoothstep(0.0, 1.0, uv.y));
	// the glow from above, a little off center
	vec2 g = (p - vec2(0.62, -0.05) * px_size) / px_size.x;
	col += vec3(0.10, 0.12, 0.22) * exp(-dot(g, g) * 3.0) + warm * 0.035 * exp(-dot(g, g) * 9.0);
	// a faint band of haze across the sky, like a far galaxy
	float band = exp(-pow((uv.y - 0.35 - 0.3 * (uv.x - 0.5)) * 4.0, 2.0));
	col += vec3(0.06, 0.07, 0.12) * band * (0.5 + 0.8 * noise(p / 60.0));
	vec2 dir = normalize(vec2(1.0, -0.35));
	float far = star_layer(p + dir * TIME * 3.0, 34.0, 0.55, 0.6);
	float mid = star_layer(p + dir * TIME * 8.0 + 500.0, 70.0, 0.45, 1.0);
	float near = star_layer(p + dir * TIME * 16.0 + 900.0, 130.0, 0.40, 1.6);
	col += vec3(0.70, 0.75, 0.95) * far * 0.45 + vec3(0.85, 0.88, 1.0) * mid * 0.75 + mix(vec3(1.0), warm, 0.35) * near;
	// a shooting star: one per 7-second slot, in some slots only, for under a second
	float slot = floor(TIME / 7.0);
	float ts = fract(TIME / 7.0) * 7.0;
	if (hash(vec2(slot, 3.0)) < 0.7 && ts < 0.9) {
		vec2 a = vec2(0.1 + 0.6 * hash(vec2(slot, 1.0)), 0.05 + 0.35 * hash(vec2(slot, 2.0))) * px_size;
		vec2 v = normalize(vec2(1.0, 0.45)) * px_size.x * 0.55;
		vec2 head = a + v * ts;
		vec2 rel = p - head;
		vec2 vd = normalize(v);
		float along = dot(rel, vd);
		float across = length(rel - vd * along);
		float tail = smoothstep(-140.0, 0.0, along) * step(along, 1.5);
		float life = smoothstep(0.0, 0.15, ts) * smoothstep(0.9, 0.6, ts);
		col += vec3(1.0, 0.95, 0.85) * tail * exp(-across * across / 1.6) * life * 0.9;
	}
	return col;
}

// the lit table (styles 0 and 1)
vec3 table(vec2 uv, vec2 p) {
	// the light: an ellipse centered above the middle, wider than tall
	// the list's light LIVES: its pool wanders a little and breathes, each on its own slow beat
	float live = style == 0 ? 1.0 : 0.0;
	vec2 drift = live * vec2(0.16 * sin(TIME * 0.31) + 0.05 * sin(TIME * 0.73 + 2.0),
	                         0.08 * sin(TIME * 0.23 + 1.3));
	vec2 c = (vec2(0.5, 0.18) + drift) * px_size;
	vec2 d = (p - c) / vec2(px_size.x * 0.85, px_size.y * 0.75);
	float light = exp(-dot(d, d) * 1.3) * (1.0 + live * 0.20 * sin(TIME * 0.55));
	// the weave: threads over and under, each thread a little uneven
	vec2 t = p / weave_px;
	float warp = 0.5 + 0.5 * sin(t.x * 3.14159) * sign(sin(t.y * 1.5708));
	float weft = 0.5 + 0.5 * sin(t.y * 3.14159) * sign(sin(t.x * 1.5708 + 1.5708));
	float threads = mix(warp, weft, 0.5);
	float fiber = noise(t * vec2(0.35, 2.2)) * 0.6 + noise(t * vec2(2.2, 0.35)) * 0.4;
	float cloth_tex = 0.92 + 0.07 * threads + 0.05 * (fiber - 0.5);
	// broad, faint unevenness, so the ground is not a perfect flat field
	float mottle = 0.94 + 0.12 * noise(p / 140.0);
	vec3 base = cloth;
	vec3 col = mix(base * 0.30, base, clamp(0.25 + light * 1.05, 0.0, 1.0));
	col += warm * light * light * 0.10;
	if (style == 1) {
		// the woven figure: brought out by the light, fading toward the edges
		vec2 fan = fan_pattern(p, fan_px);
		float show = 0.35 + 0.65 * light;
		col *= 1.0 - 0.26 * fan.x * show;
		col = mix(col, warm * 0.6, fan.y * 0.30 * show);
	}
	if (strong_light) {
		col += base * light * 0.35 + warm * light * light * 0.06;
	}
	col *= cloth_tex * mottle;
	if (style == 0) {
		// DUST in the lamp's light: one speck per cell at most, each drifting slowly up and sideways
		// with a wobble, fading in and out at its cell's edges and as it twinkles; seen only where
		// the light falls
		float cell = 52.0;
		vec2 cid = floor(p / cell);
		float speck = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 id = cid + vec2(float(i), float(j));
				float hseed = hash(id);
				if (hseed > 0.60) {
					continue;
				}
				vec2 vel = vec2(hash(id + 3.1) - 0.5, -0.35 - hash(id + 7.7) * 0.4) * 0.12;
				vec2 at = fract(vec2(hash(id + 1.7), hash(id + 5.3)) + vel * TIME);
				at += 0.04 * vec2(sin(TIME * 0.7 + hseed * 30.0), cos(TIME * 0.5 + hseed * 17.0));
				vec2 sp = (id + at) * cell;
				float edge = smoothstep(0.0, 0.18, at.x) * smoothstep(1.0, 0.82, at.x)
					* smoothstep(0.0, 0.18, at.y) * smoothstep(1.0, 0.82, at.y);
				float tw = 0.55 + 0.45 * sin(TIME * (0.8 + hseed * 2.0) + hseed * 40.0);
				float r = 1.4 + 1.8 * hash(id + 9.9);
				speck += smoothstep(r, r * 0.25, length(p - sp)) * edge * tw;
			}
		}
		col += warm * speck * 0.60 * smoothstep(0.08, 0.5, light);
	}
	// darker toward the edges
	vec2 e = uv - 0.5;
	col *= 1.0 - 0.45 * smoothstep(0.25, 0.75, length(e * vec2(1.1, 0.9)));
	return col;
}

void fragment() {
	vec2 p = UV * px_size;
	vec3 col;
	if (style == 3) {
		col = starfield(UV, p);
		vec2 se = UV - 0.5;
		col *= 1.0 - 0.35 * smoothstep(0.30, 0.80, length(se * vec2(1.1, 0.9)));
	} else {
		col = table(UV, p);
	}
	COLOR = vec4(col, 1.0);
}
