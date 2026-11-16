shader_type canvas_item;

// A CRATE'S FRONT, rendered ONCE per color and size into a texture (level.gd _bake): pine planks under a
// coat of the set's paint, worn through at the edges and where hands and other crates rub; a frame of
// darker boards with a bevel lit from the lamp above; iron corner brackets with rivets; a nail head at
// each plank end. Everything on it that changes (the slate, the chalk, the plate) is drawn over it.

uniform vec2 size = vec2(100.0, 80.0);
uniform vec4 paint : source_color = vec4(0.8, 0.3, 0.25, 1.0);
uniform float seed = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
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
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

vec3 pine(vec2 p, float tone) {
	// long grain along x, rings bent by a slow warp
	float w = fbm(vec2(p.x * 0.012, p.y * 0.09));
	float rings = sin((p.y + w * 26.0) * 0.55) * 0.5 + 0.5;
	float fine = fbm(vec2(p.x * 0.05, p.y * 0.8));
	vec3 light = vec3(0.80, 0.60, 0.36);
	vec3 dark = vec3(0.50, 0.32, 0.17);
	return mix(dark, light, 0.35 + 0.45 * rings * fine + 0.2 * w) * tone;
}

void fragment() {
	vec2 px = UV * size;
	float s = min(size.x, size.y);
	float fw = s * 0.10;                       // the frame boards
	float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	vec3 col;
	if (edge < fw) {
		// THE FRAME: darker boards, grain along each board, bevel lit from above-left
		bool horiz = min(px.y, size.y - px.y) < min(px.x, size.x - px.x);
		vec2 gp = horiz ? px : px.yx;
		col = pine(gp + vec2(37.0, 0.0), 0.62);
		// the paint on the frame is thinner and worn more
		float wear = fbm(px * 0.06 + 3.0);
		col = mix(col, paint.rgb * (0.45 + 0.4 * dot(col, vec3(0.33))), (1.0 - smoothstep(0.55, 0.75, wear)) * 0.85);
		float inset = edge / fw;
		col *= 0.80 + 0.32 * smoothstep(0.0, 0.4, inset) * (1.0 - smoothstep(0.6, 1.0, inset));
		if (px.y < fw && px.y < px.x && px.y < size.x - px.x) col *= 1.16;        // the top board, lit
		if (size.y - px.y < fw && size.y - px.y < px.x && size.y - px.y < size.x - px.x) col *= 0.72;
	} else {
		// THE PLANKS: three, each its own tone, painted over, worn through
		vec2 ip = px - vec2(fw);
		vec2 isz = size - vec2(fw * 2.0);
		float ph = isz.y / 3.0;
		float k = floor(ip.y / ph);
		float yin = ip.y - k * ph;
		float tone = 0.88 + 0.22 * hash(vec2(k, 2.0));
		col = pine(vec2(ip.x + k * 113.0, ip.y), tone);
		// a good coat of paint, the grain showing through it, rubbed back to the wood only along the plank
		// edges and in a scuff or two
		float lum = dot(col, vec3(0.33));
		vec3 pc = paint.rgb * (0.70 + 0.62 * lum) * (0.94 + 0.10 * fbm(px * 0.015 + k));
		float edge_wear = 1.0 - smoothstep(0.0, ph * 0.16, min(yin, ph - yin));
		float wear = fbm(vec2(px.x * 0.05, px.y * 0.12) + k * 5.1);
		float scuff = smoothstep(0.70, 0.82, fbm(px * 0.03 + 9.0));
		float cover = 1.0 - smoothstep(0.62, 0.80, wear * 0.7 + edge_wear * 0.45 + scuff * 0.35);
		col = mix(col, pc, cover);
		// the gap between planks, and each plank's rounded edge
		float gap = 1.0 - smoothstep(0.0, 1.6, min(yin, ph - yin));
		col *= 1.0 - 0.75 * gap * step(0.5, k + (yin > ph * 0.5 ? 1.0 : 0.0));
		col *= 1.0 + 0.10 * (1.0 - smoothstep(0.0, ph * 0.18, yin)) - 0.12 * (1.0 - smoothstep(0.0, ph * 0.18, ph - yin));
		// the inside of the frame casts a shadow onto the planks
		float ao = smoothstep(0.0, fw * 0.9, edge - fw);
		col *= 0.62 + 0.38 * ao;
		// nail heads at each plank's ends
		vec2 nl = vec2(fw * 0.55, ph * 0.5);
		for (int side = 0; side < 2; side++) {
			vec2 nc = vec2(side == 0 ? fw + nl.x : size.x - fw - nl.x, fw + k * ph + nl.y);
			float nd = length(px - nc);
			col = mix(col, vec3(0.22, 0.21, 0.22), 1.0 - smoothstep(s * 0.022, s * 0.032, nd));
			col += vec3(0.25) * (1.0 - smoothstep(0.0, s * 0.014, length(px - nc + vec2(s * 0.008))));
		}
	}
	// IRON CORNER BRACKETS: an L at each corner, with a rivet
	vec2 cp = min(px, size - px);
	float arm = s * 0.26;
	float th = s * 0.075;
	float bracket = step(cp.x, arm) * step(cp.y, th) + step(cp.y, arm) * step(cp.x, th);
	if (bracket > 0.0) {
		vec3 iron = vec3(0.17, 0.17, 0.19) * (0.85 + 0.3 * fbm(px * 0.3));
		iron += vec3(0.10) * (1.0 - smoothstep(0.0, th * 0.5, min(cp.x, cp.y)));
		col = iron;
		float rv = length(cp - vec2(th * 0.5 + s * 0.03, th * 0.5 + s * 0.03));
		col = mix(col, vec3(0.55, 0.54, 0.52), 1.0 - smoothstep(s * 0.016, s * 0.026, rv));
	}
	// the lamp: lighter at the top, a soft falloff to the bottom
	col *= 1.06 - 0.20 * UV.y;
	COLOR = vec4(col, 1.0);
}
