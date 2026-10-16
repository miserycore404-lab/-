shader_type canvas_item;
// Frost-creep transition: darkness grows in from the edges along a
// crystalline noise field, with a pale rime line at the advancing edge.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.035, 0.043, 0.06, 1.0);
uniform vec4 rime : source_color = vec4(0.72, 0.8, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 c = (uv - 0.5) * aspect;
	float edge = length(c) * 1.25;
	// crystalline: sharpen the noise into facets
	float n = fbm(uv * aspect * 6.0);
	float facets = abs(fract(n * 4.0) - 0.5) * 0.25;
	float field = 1.0 - edge * 0.6 + (n - 0.5) * 0.55 + facets;
	float p = progress * 1.65 - 0.25;
	float cover = smoothstep(field - 0.04, field + 0.02, p + 0.0);
	float rim = smoothstep(0.06, 0.0, abs(p - field + 0.03)) * (1.0 - cover) * step(0.001, progress) * step(progress, 0.999);
	vec4 col = tint;
	col.rgb = mix(col.rgb, rime.rgb, rim * 0.55);
	col.a = clamp(cover + rim * 0.6, 0.0, 1.0);
	if (progress >= 0.999) col.a = 1.0;
	COLOR = col;
}
