shader_type canvas_item;

// THE WEIGH-HOUSE (Tip the Scales), the whole backdrop in one pass:
//   above `counter_y`: a back wall of old warm plaster with a lamp's pool of light, and the RACK the crates
//     stand in -- two walnut posts either side of the board and a shelf under every row (`board`, `rows`,
//     `pitch`, `cell_h`: the shelves sit exactly under the crates level.gd lays out), each shelf's front
//     edge lit on top and casting a soft shadow on the wall;
//   below it: the COUNTER, dark oak boards with a rounded front lip, where the workbench and the clue
//     papers lie.
// Static (no TIME): a backdrop to read crates and papers on.

uniform vec2 size = vec2(680.0, 1200.0);
uniform vec4 board = vec4(14.0, 86.0, 652.0, 300.0);     // x, y, w, h of the crates
uniform float rows = 3.0;
uniform float pitch = 90.0;       // one row of crates to the next
uniform float cell_h = 80.0;
uniform float counter_y = 420.0;
uniform vec2 lamp = vec2(340.0, 60.0);

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + 13.3;
		a *= 0.5;
	}
	return v;
}

vec3 walnut(vec2 p, float tone) {
	float g = fbm(vec2(p.x * 0.02, p.y * 0.35));
	float rings = sin((p.y + g * 30.0) * 0.4) * 0.5 + 0.5;
	return mix(vec3(0.14, 0.075, 0.04), vec3(0.36, 0.20, 0.10), 0.3 + 0.5 * g + 0.2 * rings) * tone;
}

vec3 oak(vec2 px) {
	float board_h = 64.0;
	float row = floor(px.y / board_h);
	float y_in = px.y - row * board_h;
	float off = hash(vec2(row, 3.1)) * 500.0;
	float tone = 0.85 + 0.25 * hash(vec2(row, 9.7));
	vec2 g = vec2((px.x + off) / 220.0, y_in / 9.0 + row * 7.0);
	float grain = fbm(vec2(g.x, g.y + 0.6 * fbm(g * 0.7)));
	float streak = sin((y_in + 6.0 * fbm(vec2(px.x / 90.0, row))) * 0.9) * 0.5 + 0.5;
	vec3 col = mix(vec3(0.17, 0.10, 0.055), vec3(0.37, 0.22, 0.12), grain * 0.75 + streak * 0.12) * tone;
	float seam = smoothstep(1.6, 0.0, y_in) + smoothstep(board_h - 1.2, board_h, y_in) * 0.6;
	return col * (1.0 - 0.5 * seam);
}

void fragment() {
	vec2 px = UV * size;
	vec3 col;
	if (px.y < counter_y) {
		// THE WALL: warm plaster, uneven, a few cracks of shade
		float pl = fbm(px * 0.008) * 0.6 + fbm(px * 0.04) * 0.4;
		col = mix(vec3(0.20, 0.14, 0.10), vec3(0.34, 0.25, 0.18), pl);
		col *= 1.0 - 0.10 * smoothstep(0.72, 0.80, fbm(px * 0.02 + 5.0));
		// THE RACK: posts either side of the board
		float post_w = 12.0;
		float lx = board.x - post_w - 4.0;
		float rx = board.x + board.z + 4.0;
		float top = board.y - 30.0;
		float bottom = board.y + board.w + 14.0;
		bool in_rows = px.y > top && px.y < bottom;
		if (in_rows && ((px.x > lx && px.x < lx + post_w) || (px.x > rx && px.x < rx + post_w))) {
			float u = (px.x > rx) ? (px.x - rx) / post_w : (px.x - lx) / post_w;
			col = walnut(px.yx, 1.0) * (0.65 + 0.6 * sin(u * 3.1416));
		} else if (in_rows && px.x > lx && px.x < rx + post_w) {
			// the back of the rack: darker boards, vertical
			col = walnut(px.yx * vec2(1.0, 0.6), 0.55);
			col *= 1.0 - 0.35 * smoothstep(2.0, 0.0, mod(px.x - lx, 58.0));
		}
		// THE SHELVES: under every row
		for (float r = 0.0; r < 6.0; r += 1.0) {
			if (r >= rows) break;
			float sy = board.y + r * pitch + cell_h + 1.0;
			float sh = 9.0;
			if (px.x > lx && px.x < rx + post_w) {
				if (px.y > sy && px.y < sy + sh) {
					float v = (px.y - sy) / sh;
					col = walnut(px, 1.15) * (1.25 - 0.55 * v);
					col += vec3(0.20, 0.14, 0.08) * (1.0 - smoothstep(0.0, 0.25, v));
				} else if (px.y >= sy + sh && px.y < sy + sh + 14.0) {
					col *= 0.45 + 0.55 * smoothstep(0.0, 14.0, px.y - sy - sh);   // the shelf's shadow
				}
			}
		}
		// the lamp
		float d = length((px - lamp) / vec2(size.x * 0.75, counter_y * 1.1));
		col *= mix(1.45, 0.45, smoothstep(0.0, 1.0, d));
		col += vec3(0.08, 0.05, 0.01) * (1.0 - smoothstep(0.0, 0.6, d));
	} else {
		// THE COUNTER
		col = oak(px);
		float lip = px.y - counter_y;
		col *= 1.0 + 0.55 * (1.0 - smoothstep(0.0, 3.0, lip)) - 0.30 * (smoothstep(3.0, 6.0, lip) * (1.0 - smoothstep(6.0, 16.0, lip)));
		float d = length((px - vec2(size.x * 0.5, counter_y + 120.0)) / vec2(size.x * 0.9, size.y * 0.7));
		col *= mix(1.25, 0.40, smoothstep(0.0, 1.0, d));
	}
	COLOR = vec4(col, 1.0);
}
