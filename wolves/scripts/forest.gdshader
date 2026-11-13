shader_type canvas_item;

// THE WOODS ROUND THE FARM (2026-11-13), on a rect over the lawn (level._plant_forest): the lawn goes on
// past the farm fence and DARKENS gradually into the shade of the trees, and the canopy closes in further
// out as soft irregular masses of dark green -- no single trees. Round crowns, each with its highlight,
// read as a children's playground, and the lawn stopping at a band of them looked cut off.

uniform vec2 area_size = vec2(680.0, 788.0);
uniform vec4 farm = vec4(0.0);          // the farm's rect in this rect's own units: x, y, w, h
uniform float tile = 40.0;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

float canopy_at(vec2 p, float d) {
	float n = fbm(p / 70.0) * 0.75 + fbm(p / 22.0) * 0.25;
	// coverage grows with the distance from the fence: none within 1.5 tiles, closed by about 5
	float reach = (d - 1.5 * tile) / (3.5 * tile);
	return smoothstep(0.52, 0.60, n + reach * 0.45 - 0.12);
}

void fragment() {
	vec2 p = UV * area_size;
	vec2 c = farm.xy + farm.zw * 0.5;
	vec2 q = abs(p - c) - farm.zw * 0.5;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);      // outside the farm: > 0
	// the shade on the lawn, deepening outward
	float shade = 0.62 * smoothstep(0.3 * tile, 4.0 * tile, d);
	float cov = d > 0.0 ? canopy_at(p, d) : 0.0;
	// the canopy's own shadow on the lawn below and to the right of it
	float csh = d > 0.0 ? canopy_at(p - vec2(5.0, 7.0), d) : 0.0;
	shade = max(shade, 0.45 * csh);
	// the leaves: deep greens in clumps, faintly lit where the canopy rises toward the top left
	float tone = fbm(p / 14.0 + 3.0);
	vec3 leaf = mix(vec3(0.035, 0.10, 0.05), vec3(0.08, 0.18, 0.08), tone);
	float rise = canopy_at(p + vec2(4.0, 5.0), d) - cov;
	leaf *= 1.0 - 0.25 * clamp(rise, 0.0, 1.0);
	float a = shade + (1.0 - shade) * cov;
	vec3 rgb = leaf * cov / max(a, 0.001);
	COLOR = vec4(rgb, a);
}
