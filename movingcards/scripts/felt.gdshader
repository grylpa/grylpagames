shader_type canvas_item;

// THE TABLE behind Moving Cards: a deep slate-teal baize -- a fine fiber texture (two scales of noise, a few
// percent either way), a soft overhead light pooled toward the top center, and a darker edge all
// round. Low contrast and with no direction in it: the card backs are patterns (stripes, houndstooth)
// and are part of the stimulus, so nothing here may echo them. It replaced a flat orange image
// (art/bk3.jpg). (A copy of Change's felt, its own file: games do not share scripts.)
// Round it, a TABLE: a polished wooden rail with its grain running along each side, lit on its inner
// edge and casting a shadow onto the felt, and a thin gold inlay line a little way in. The felt alone
// was "still boring"; the rail and the inlay sit at the edges, away from where the cards move, and
// have no repeating pattern in them.

uniform vec3 felt : source_color = vec3(0.090, 0.215, 0.205);
uniform vec2 size = vec2(680.0, 788.0);

varying vec2 px;

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

void vertex() {
	px = VERTEX;
}

uniform float rail = 26.0;
// the part of the rect that is on screen and below the HUD's strip, in the rect's own pixels: the
// rect itself runs past the screen's edges (level.gd _dress_table)
uniform vec4 table = vec4(0.0, 0.0, 680.0, 788.0);

vec3 wood(vec2 p, bool along_x) {
	vec2 q = along_x ? p : p.yx;
	float g = noise(vec2(q.x / 90.0, q.y / 2.2)) * 0.6 + noise(vec2(q.x / 25.0, q.y / 0.9)) * 0.4;
	float ring = 0.5 + 0.5 * sin(q.y * 0.9 + g * 9.0);
	vec3 a = vec3(0.32, 0.17, 0.08);
	vec3 b = vec3(0.47, 0.27, 0.13);
	return mix(a, b, g * 0.7 + ring * 0.3);
}

void fragment() {
	vec2 tp = px - table.xy;
	vec2 ts = table.zw;
	float d_edge = min(min(tp.x, ts.x - tp.x), min(tp.y, ts.y - tp.y));
	float fiber = (hash(floor(px / 1.2)) - 0.5) * 0.07 + (noise(px / 3.0) - 0.5) * 0.06
		+ (noise(px / 23.0) - 0.5) * 0.05;
	vec2 uv = px / size;
	float light = 1.0 + 0.30 * (1.0 - smoothstep(0.0, 0.75, length((uv - vec2(0.5, 0.38)) * vec2(1.0, 1.15))));
	vec2 e = min(uv, 1.0 - uv);
	float vig = mix(0.70, 1.0, smoothstep(0.0, 0.22, min(e.x, e.y)));
	vec3 col = felt * (1.0 + fiber) * light * vig;
	// the rail's shadow on the felt
	float inside = d_edge - rail;
	col *= mix(0.45, 1.0, smoothstep(0.0, 14.0, inside));
	// the gold inlay
	float line = 1.0 - smoothstep(0.6, 1.4, abs(inside - 16.0));
	col = mix(col, vec3(0.80, 0.62, 0.30), line * 0.55);
	if (d_edge < rail) {
		bool along_x = min(tp.y, ts.y - tp.y) < min(tp.x, ts.x - tp.x);
		vec3 w = wood(px, along_x);
		// rounded: dark at the outer edge, a bright bevel near the inner edge
		float u = d_edge / rail;
		w *= 0.55 + 0.55 * smoothstep(0.0, 0.7, u);
		w += vec3(0.30, 0.20, 0.10) * smoothstep(0.72, 0.86, u) * (1.0 - smoothstep(0.86, 1.0, u));
		col = w;
	}
	COLOR = vec4(col, 1.0);
}
