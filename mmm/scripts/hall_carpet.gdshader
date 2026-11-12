shader_type canvas_item;

// A PALACE CARPET on the great hall's floor (hall_decor.gd puts it on a ColorRect the carpet's size, the
// fringe included). Laid out the way such rugs are: an outer guard stripe, a broad navy border of gold
// rosettes, an inner guard, and a red field with a fine lattice of small flowers, a round medallion in the
// middle (petals, rings) and quarter medallions in the corners; fringe at the two short ends. Wool: a pile
// of fine fibers and a faint weave, the color a little uneven, slightly darker at the edge where the pile
// turns down. Flat on the floor, so seen from straight above like the board. In the rect's OWN space
// (UV), never MODEL_MATRIX (it moves with the camera in this game).

uniform vec2 size = vec2(200.0, 40.0);      // the rect, px
uniform float fringe = 7.0;                  // px of fringe past each short end
uniform float seed = 0.0;

const vec3 RED = vec3(0.50, 0.08, 0.10);
const vec3 RED_D = vec3(0.36, 0.05, 0.08);
const vec3 NAVY = vec3(0.09, 0.11, 0.26);
const vec3 GOLD = vec3(0.86, 0.66, 0.30);
const vec3 CREAM = vec3(0.92, 0.86, 0.70);

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

// a rosette: `petals` round petals about a center, radius r; 1 inside
float rosette(vec2 q, float r, float petals) {
	float a = atan(q.y, q.x);
	float rr = r * (0.72 + 0.28 * abs(cos(a * petals * 0.5)));
	return 1.0 - smoothstep(rr - 0.8, rr + 0.8, length(q));
}

float ring(vec2 q, float r, float w) {
	return 1.0 - smoothstep(w * 0.5 - 0.7, w * 0.5 + 0.7, abs(length(q) - r));
}

void fragment() {
	vec2 p = UV * size;
	bool long_x = size.x >= size.y;
	// the woven body is the rect less the fringe at the short ends
	vec2 body0 = long_x ? vec2(fringe, 0.0) : vec2(0.0, fringe);
	vec2 body1 = size - body0;
	vec2 b = p - body0;
	vec2 bs = body1 - body0;
	vec4 outc = vec4(0.0);
	if (b.x < 0.0 || b.y < 0.0 || b.x > bs.x || b.y > bs.y) {
		// the fringe: cream threads along the long axis, ragged at their ends
		float across = long_x ? p.y : p.x;
		float along = long_x ? min(p.x, size.x - p.x) : min(p.y, size.y - p.y);
		float thread = step(0.45, fract(across / 3.2));
		float len = fringe * (0.65 + 0.35 * hash(vec2(floor(across / 3.2), seed)));
		float on = thread * step(fringe - len, along) * step(2.0, across) * step(across, (long_x ? size.y : size.x) - 2.0);
		outc = vec4(CREAM * (0.85 + 0.15 * hash(vec2(floor(across / 3.2), 7.0))), on);
	} else {
		float shortside = min(bs.x, bs.y);
		float bw = shortside * 0.20;                       // the main border's width
		float gw = max(2.0, shortside * 0.035);            // a guard stripe's width
		float edge = min(min(b.x, bs.x - b.x), min(b.y, bs.y - b.y));
		vec3 col;
		if (edge < gw) {
			col = GOLD * 0.9;                                 // outer guard
		} else if (edge < gw + bw) {
			// the border: navy, gold rosettes along it with small cream dots between, spaced so a whole
			// number of them fits each side; a larger rosette in each CORNER (the side rows used to run into
			// the corners and meet there cut in half)
			col = NAVY;
			float band0 = gw;
			float band1 = gw + bw;
			bool in_x = b.x < band1 || b.x > bs.x - band1;
			bool in_y = b.y < band1 || b.y > bs.y - band1;
			if (in_x && in_y) {
				vec2 cc = vec2(b.x < band1 ? band0 + bw * 0.5 : bs.x - band0 - bw * 0.5,
					b.y < band1 ? band0 + bw * 0.5 : bs.y - band0 - bw * 0.5);
				vec2 q = b - cc;
				col = mix(col, GOLD, rosette(q, bw * 0.42, 8.0));
				col = mix(col, NAVY, rosette(q, bw * 0.24, 8.0));
				col = mix(col, RED, 1.0 - smoothstep(bw * 0.10, bw * 0.10 + 1.0, length(q)));
			} else {
				bool top_bot = !in_x;                                // a top or bottom side
				float along = top_bot ? b.x - band1 : b.y - band1;
				float span = top_bot ? bs.x - band1 * 2.0 : bs.y - band1 * 2.0;
				float n = max(1.0, floor(span / (bw * 1.15) + 0.5));
				float pitch = span / n;
				float t = edge - gw - bw * 0.5;                      // across the band, 0 at its middle
				vec2 q = vec2((fract(along / pitch) - 0.5) * pitch, t);
				col = mix(col, GOLD, rosette(q, bw * 0.34, 8.0));
				col = mix(col, RED, rosette(q, bw * 0.15, 8.0));
				vec2 q2 = vec2((fract(along / pitch + 0.5) - 0.5) * pitch, t);
				col = mix(col, CREAM, 1.0 - smoothstep(1.0, 1.8, length(q2)));
			}
			float t2 = edge - gw - bw * 0.5;
			col = mix(col, GOLD * 0.8, (1.0 - smoothstep(0.4, 1.0, abs(abs(t2) - bw * 0.46))) * float(!(in_x && in_y)));
		} else if (edge < gw * 2.0 + bw) {
			col = GOLD * 0.75;                                // inner guard
		} else {
			// the field: red, a staggered lattice of small flowers, a round medallion, corner quarters
			col = RED;
			vec2 f = b - vec2(gw * 2.0 + bw);
			vec2 fs = bs - vec2(gw * 2.0 + bw) * 2.0;
			float cell = max(8.0, min(fs.x, fs.y) * 0.34);
			vec2 g = f / cell;
			g.x += 0.5 * mod(floor(g.y), 2.0);
			vec2 gq = (fract(g) - 0.5) * cell;
			col = mix(col, RED_D, rosette(gq, cell * 0.30, 4.0) * 0.8);
			col = mix(col, GOLD * 0.75, rosette(gq, cell * 0.12, 4.0));
			// the medallion: navy round, gold rings, a cream-and-gold rosette, a red heart
			vec2 mc = fs * 0.5;
			vec2 mq = f - mc;
			float mr = min(fs.x, fs.y) * 0.46;
			float in_med = 1.0 - smoothstep(mr - 0.8, mr + 0.8, length(mq));
			col = mix(col, NAVY, in_med);
			col = mix(col, GOLD, ring(mq, mr - 1.0, 2.2));
			col = mix(col, GOLD, rosette(mq, mr * 0.78, 8.0) * in_med);
			col = mix(col, CREAM, rosette(mq, mr * 0.52, 8.0));
			col = mix(col, RED, rosette(mq, mr * 0.30, 6.0));
			col = mix(col, GOLD, 1.0 - smoothstep(mr * 0.10, mr * 0.10 + 1.0, length(mq)));
			// pendants on the long axis, and the four corner quarters
			vec2 ax = long_x ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
			for (int s = -1; s <= 1; s += 2) {
				vec2 pq = mq - ax * float(s) * (mr + mr * 0.42);
				col = mix(col, GOLD, rosette(pq, mr * 0.30, 6.0));
				col = mix(col, NAVY, rosette(pq, mr * 0.15, 6.0));
			}
			vec2 cq = vec2(min(f.x, fs.x - f.x), min(f.y, fs.y - f.y));
			float cr = min(fs.x, fs.y) * 0.34;
			float corner = 1.0 - smoothstep(cr - 0.8, cr + 0.8, length(cq));
			col = mix(col, NAVY, corner);
			col = mix(col, GOLD, ring(cq, cr - 1.0, 2.0));
			col = mix(col, GOLD * 0.85, ring(cq, cr * 0.55, 1.6) * corner);
		}
		// wool: fine fibers, a faint weave, uneven dye, darker at the very edge where the pile turns down
		float fiber = hash(floor(p * 1.6) + seed);
		col *= 0.90 + 0.14 * fiber;
		col *= 0.96 + 0.05 * sin(p.x * 2.4) * sin(p.y * 2.4);
		col *= 0.93 + 0.10 * noise(p / 23.0 + seed * 10.0);
		col *= 0.80 + 0.20 * smoothstep(0.0, 2.5, edge);
		outc = vec4(col, 1.0);
	}
	COLOR = outc;
}
