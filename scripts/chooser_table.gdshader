// The game chooser's background (2026-11-10): a lit table. The untidy, swaying tiles read as cards
// scattered on a table, so the ground is one, under a soft pool of warm light from above the center,
// falling off to darker edges. Static (no TIME): nothing here moves.
//
// `style` (set per view by game_chooser.gd): 0 plain navy cloth (the list), 1 the woven art-deco
// fans (the grid). Tried and turned down: a gold inlay round the cloth, and dark walnut planks
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
vec2 fan_pattern(vec2 p) {
	float w = fan_px;
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

void fragment() {
	vec2 p = UV * px_size;
	// the light: an ellipse centered above the middle, wider than tall
	vec2 c = vec2(0.5, 0.18) * px_size;
	vec2 d = (p - c) / vec2(px_size.x * 0.85, px_size.y * 0.75);
	float light = exp(-dot(d, d) * 1.3);
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
		vec2 fan = fan_pattern(p);
		float show = 0.35 + 0.65 * light;
		col *= 1.0 - 0.26 * fan.x * show;
		col = mix(col, warm * 0.6, fan.y * 0.30 * show);
	}
	if (strong_light) {
		col += base * light * 0.35 + warm * light * light * 0.06;
	}
	col *= cloth_tex * mottle;
	// darker toward the edges
	vec2 e = UV - 0.5;
	col *= 1.0 - 0.45 * smoothstep(0.25, 0.75, length(e * vec2(1.1, 0.9)));
	COLOR = vec4(col, 1.0);
}
