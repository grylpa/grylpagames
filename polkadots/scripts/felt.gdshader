shader_type canvas_item;

// The card-table felt behind everything in Polka Dots: the table's green, a fine fiber texture (two
// scales of noise, a few percent either way), a soft overhead light pooled toward the top center and
// a darker edge all round. It replaced a flat clear color.

uniform vec3 felt : source_color = vec3(0.235, 0.365, 0.243);   // the old clear color, 0x3C5D3E
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

void fragment() {
	float fiber = (hash(floor(px / 1.2)) - 0.5) * 0.07 + (noise(px / 3.0) - 0.5) * 0.06
		+ (noise(px / 23.0) - 0.5) * 0.05;
	vec2 uv = px / size;
	float light = 1.0 + 0.16 * (1.0 - smoothstep(0.0, 0.75, length((uv - vec2(0.5, 0.38)) * vec2(1.0, 1.15))));
	vec2 e = min(uv, 1.0 - uv);
	float vig = mix(0.70, 1.0, smoothstep(0.0, 0.22, min(e.x, e.y)));
	COLOR = vec4(felt * (1.0 + fiber) * light * vig, 1.0);
}
