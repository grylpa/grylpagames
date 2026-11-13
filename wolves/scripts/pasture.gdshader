shader_type canvas_item;

// THE FIELD inside the farm fence, on every field tile's sprite (pipe.gd): a MOWN PASTURE -- a lighter,
// yellower green than the lawn outside the fence (so the farm still reads as its own place), soft
// broad patches of lighter and darker grass, fine blade grain and a few darker tufts. (It had mowing
// stripes, which read as horizontal bands across the board; the cells are now faint LINES, below.) In world coordinates, so it runs across
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

// THE CELLS AS FAINT LINES (2026-11-13): a thin soft seam, a little darker, between every two cells --
// BROKEN, so it blends: wobbling, uneven, with gaps. The
// animals move cell to cell, and with no grid to be seen their square turns looked arbitrary. (A mown
// checkerboard was tried first; long before, mowing stripes read as bands across the board.) Anti-aliased
// to about one screen pixel whatever the zoom.
uniform vec2 origin = vec2(0.0);       // the board's top-left corner, in the same space as `world`
uniform float tile = 40.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 grass = vec3(0.36, 0.52, 0.24);
	vec2 g = (world - origin) / tile;
	vec2 ci = floor(g + 0.5);                            // which line, per axis
	// BROKEN: each line wobbles a little, varies in strength along its length and fades out in gaps,
	// like a seam worn into the grass rather than a ruled line
	vec2 wob = vec2(noise(vec2(world.y / 7.0, ci.x * 3.7)), noise(vec2(world.x / 7.0, ci.y * 5.3 + 40.0))) - 0.5;
	vec2 d = abs(fract(g + 0.5) - 0.5) * tile + wob * 1.4; // units to the nearest cell edge, per axis
	d = abs(d);
	vec2 px = fwidth(world);
	vec2 keep = vec2(smoothstep(0.30, 0.62, noise(vec2(world.y / 13.0, ci.x * 7.1 + 9.0))),
		smoothstep(0.30, 0.62, noise(vec2(world.x / 13.0, ci.y * 6.3 + 21.0))));
	float lx = (1.0 - smoothstep(0.0, 0.9 + px.x, d.x)) * keep.x;
	float ly = (1.0 - smoothstep(0.0, 0.9 + px.y, d.y)) * keep.y;
	grass *= 1.0 - 0.22 * max(lx, ly);
	float blades = (hash(floor(world / vec2(1.2, 3.0))) - 0.5) * 0.10;
	float patches = (noise(world / 40.0) - 0.5) * 0.10 + (noise(world / 140.0 + 3.0) - 0.5) * 0.10;
	float tuft = smoothstep(0.82, 0.9, noise(world / 9.0 + 5.0)) * -0.12;
	COLOR = vec4(grass * (1.0 + blades + patches + tuft), tex.a);
}
