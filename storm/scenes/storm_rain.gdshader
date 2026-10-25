shader_type canvas_item;

// THE WEATHER, over the lawn only. It sits in the lawn's own layer (BgLayer), just above the grass,
// so the house -- drawn in the level's layer, in front -- covers it: rain falls on the lawn and
// stops at the walls by construction, with no mask. Three things, all procedural:
//   the light: the lawn darkened and cooled, wet under a storm sky;
//   the rain: thin slanted streaks falling, each on its own phase, driven by a wind that slowly
//   swings from one side to the other and back (level.gd `_wind_at`);
//   the splashes: small rings opening and fading where drops land.
// `t` is the game's clock in seconds, so the weather stops when the game does.

uniform float t = 0.0;
// the rain's slant (x per y), set by level.gd from a slow wind that swings from side to side
uniform float wind = 0.28;
uniform vec4 shade : source_color = vec4(0.04, 0.07, 0.13, 0.46);

varying vec2 px;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	px = VERTEX;
}

// Streaks: the plane is sheared by the wind, cut into columns, and each column carries a drop
// falling at its own speed and phase.
float streaks(vec2 p, float cell_w, float speed, float len) {
	vec2 q = vec2(p.x + p.y * wind, p.y);           // the wind's slant
	float col = floor(q.x / cell_w);
	float h = hash(vec2(col, 3.7));
	if (h < 0.35) {
		return 0.0;
	}
	float x_in = fract(q.x / cell_w) - 0.5;
	float lane = 1.0 - smoothstep(0.02, 0.09, abs(x_in - (h - 0.5) * 0.5));
	float period = 260.0;
	float y = fract((q.y - t * speed - h * period * 7.0) / period);
	float drop = smoothstep(0.0, 0.02, y) * (1.0 - smoothstep(len / period * 0.6, len / period, y));
	return lane * drop;
}

// Splashes: one chance per cell, a ring opening on its own beat.
float splash(vec2 p, float cell) {
	vec2 c = floor(p / cell);
	float h = hash(c);
	float beat = 1.1 + h * 0.9;
	float ph = fract(t / beat + h * 5.0);
	float age = ph / 0.35;
	if (age > 1.0) {
		return 0.0;
	}
	vec2 at = (c + vec2(hash(c + 1.3), hash(c + 7.1)) * 0.8 + 0.1) * cell + vec2(0.0, floor(t / beat + h * 5.0) * 13.0);
	at = (c + fract(at / cell)) * cell;
	float r = 1.0 + age * 7.0;
	float d = abs(length((p - at) * vec2(1.0, 1.6)) - r);
	return (1.0 - smoothstep(0.4, 1.4, d)) * (1.0 - age);
}

void fragment() {
	float rain = streaks(px, 9.0, 620.0, 26.0) * 0.42 + streaks(px + 40.0, 14.0, 480.0, 18.0) * 0.26;
	float sp = splash(px, 52.0) * 0.45;
	vec3 light = vec3(0.78, 0.84, 0.95);
	float a = shade.a + (rain + sp) * (1.0 - shade.a);
	vec3 col = mix(shade.rgb, light, clamp((rain + sp) / max(a, 0.001), 0.0, 1.0));
	COLOR = vec4(col, a);
}
