shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Old window glass with frost ferns growing from the corners.
// UV in metres; frame_size is the pane size.

#include "res://shaders/common.gdshaderinc"

uniform vec2 pane = vec2(0.5, 0.6);
uniform float frost = 0.75;

void fragment() {
	vec2 uv = UV / pane;
	vec2 e = min(uv, 1.0 - uv);
	float edge = min(e.x, e.y);
	float corner = length(min(uv, 1.0 - uv) * vec2(1.0, 0.8));
	// fern-like crystal growth: domain-warped ridged noise
	vec2 q = UV * 14.0;
	vec2 w = vec2(fbm2(q * 0.5), fbm2(q * 0.5 + 4.2)) * 3.0;
	float ridge = 1.0 - abs(vnoise(q + w) * 2.0 - 1.0);
	ridge = pow(ridge, 3.0);
	float growth = smoothstep(0.32 * frost, 0.02, edge + (fbm2(q * 0.3) - 0.5) * 0.15);
	float fr = clamp(growth * (0.4 + ridge * 0.9), 0.0, 1.0);
	ALBEDO = mix(vec3(0.6, 0.7, 0.75), vec3(0.88, 0.93, 1.0), fr);
	ALPHA = mix(0.12, 0.88, fr);
	ROUGHNESS = mix(0.04, 0.6, fr);
	SPECULAR = 0.8;
	BACKLIGHT = vec3(0.6, 0.62, 0.65) * fr;
}
