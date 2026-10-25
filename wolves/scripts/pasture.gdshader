shader_type canvas_item;

// THE FIELD inside the farm fence, on every field tile's sprite (pipe.gd): a MOWN PASTURE -- a lighter,
// yellower green than the lawn outside the fence (so the farm still reads as its own place), soft
// broad patches of lighter and darker grass, fine blade grain and a few darker tufts. (It had mowing
// stripes, which read as horizontal bands across the board.) In world coordinates, so it runs across
// tiles. It replaced a gray stone tile that read as asphalt. Kept mid-light: the sheep are white with
// light rims and the wolves dark, and both must stand out on it.

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
	vec3 grass = vec3(0.36, 0.52, 0.24);
	float blades = (hash(floor(world / vec2(1.2, 3.0))) - 0.5) * 0.10;
	float patches = (noise(world / 40.0) - 0.5) * 0.10 + (noise(world / 140.0 + 3.0) - 0.5) * 0.10;
	float tuft = smoothstep(0.82, 0.9, noise(world / 9.0 + 5.0)) * -0.12;
	COLOR = vec4(grass * (1.0 + blades + patches + tuft), tex.a);
}
