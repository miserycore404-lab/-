shader_type spatial;
render_mode cull_disabled;
// Bare birch crown: a cloud of hair-thin twigs approximated by alpha-cut
// streaks. Reads as the purple-brown haze of birches in winter.

#include "res://shaders/common.gdshaderinc"

varying vec3 opos;
varying vec3 wpos;

void vertex() {
	opos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 0.9 + wpos.z * 0.3) * 0.04 * VERTEX.y * 0.1;
}

void fragment() {
	vec3 p = opos * 6.0;
	// long thin streaks pointing mostly downward/outward
	float a = vnoise(vec2(p.x * 3.0 + p.z * 2.0, p.y * 0.35));
	float b = vnoise(vec2(p.z * 3.0 - p.x * 1.5, p.y * 0.4) + 7.0);
	float lines = max(smoothstep(0.92, 0.97, 1.0 - abs(a * 2.0 - 1.0)), smoothstep(0.93, 0.98, 1.0 - abs(b * 2.0 - 1.0)));
	float edge = vnoise3(opos * 2.0) * 0.6 + 0.4;
	ALPHA = lines * edge;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	vec3 c = COLOR.rgb;
	float snow = step(0.6, vnoise(p.xz * 0.5 + p.y)) * 0.0;
	ALBEDO = mix(c, vec3(0.9), snow);
	ROUGHNESS = 0.9;
}
