// The game chooser's tiles, alive (scripts/tile_life.gd). One material is shared by EVERY canvas item
// of a tile -- the rounded clipper, the picture, the name, the frame -- so the layers move as one and
// the clipper's mask stays on its picture. The work is done in CANVAS space (skip_vertex_transform),
// about the tile's center there, because the layers have different local origins.
//
// Purely visual: the controls do not move, so what a tap hits is the tile's steady rectangle.
shader_type canvas_item;
render_mode skip_vertex_transform;

uniform vec2 center = vec2(0.0);     // the tile's center, canvas space
uniform vec2 axis = vec2(0.0, 1.0);  // the turning axis, a unit vector in the picture's plane
uniform float angle = 0.0;           // radians, about that axis
uniform float dist = 400.0;          // the eye's distance, for the perspective
uniform float tilt = 0.0;            // untidy: off the upright (radians)
uniform float size_scale = 1.0;      // untidy: off the size; also the hover growth

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec3 p = vec3(w - center, 0.0);
	// the 3-D turn about the in-plane axis through the center (Rodrigues), then the perspective
	vec3 k = vec3(axis, 0.0);
	float ca = cos(angle);
	float sa = sin(angle);
	vec3 r = p * ca + cross(k, p) * sa + k * dot(k, p) * (1.0 - ca);
	vec2 q = r.xy * (dist / (dist - r.z));
	// then the tile's own tilt and size, about the same center (a tile's center never moves)
	float ct = cos(tilt);
	float st = sin(tilt);
	q = vec2(ct * q.x - st * q.y, st * q.x + ct * q.y) * size_scale;
	VERTEX = center + q;
}
