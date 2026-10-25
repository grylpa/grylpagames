shader_type canvas_item;

// THE ROAD, on every road tile's sprite (pipe.gd gives them all one material). The tiles' own art is
// flat gray with yellow markings; this keeps the yellow -- dashed lines, center studs -- and turns
// the gray into asphalt: aggregate grain, broad
// worn and patched areas, the odd oil stain. Worked out in WORLD coordinates, so the texture runs on
// across tiles (and whatever a tile's rotation) instead of repeating in each one.

varying vec2 world;

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
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = vec3(0.235, 0.240, 0.250);
	// aggregate: fine grains, light and dark
	float g = hash(floor(world / 1.3));
	float grain = (g - 0.5) * 0.10 + (hash(floor(world / 2.7) + 9.0) > 0.93 ? 0.10 : 0.0);
	// broad wear and patching
	float wear = (noise(world / 60.0) - 0.5) * 0.10 + (noise(world / 17.0) - 0.5) * 0.05;
	float patch = smoothstep(0.66, 0.72, noise(world / 140.0 + 4.0)) * -0.035;
	vec3 col = base * (1.0 + grain + wear + patch);
	// an oil stain here and there: darker, with a faint sheen
	float oil = smoothstep(0.90, 0.97, noise(world / 34.0 + 13.0)) * smoothstep(0.55, 0.7, noise(world / 300.0 + 2.0));
	col = mix(col, col * 0.72 + vec3(0.015, 0.0, 0.03), oil * 0.6);
	// the stud: where the tile's art is yellow, a small raised reflector with a highlight
	float dot_m = clamp((tex.r - tex.b) * 2.0, 0.0, 1.0);
	vec3 stud = vec3(0.96, 0.80, 0.25);
	col = mix(col, stud, dot_m);
	COLOR = vec4(col, tex.a);
}
