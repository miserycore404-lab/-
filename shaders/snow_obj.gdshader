shader_type spatial;
// Snow caps on roofs, fences, logs. Soft, lumpy, slightly blue in shadow.

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// lumpy surface
	float n = vnoise(wpos.xz * 3.0) * 0.5 + vnoise(wpos.xz * 9.0) * 0.2;
	VERTEX += NORMAL * n * 0.025 * COLOR.a;
}

void fragment() {
	float fine = vnoise(wpos.xz * 14.0 + wpos.y * 7.0);
	vec3 cell = floor(wpos * 40.0);
	float h = hash13(cell);
	ALBEDO = vec3(0.9, 0.93, 0.98) * (0.94 + 0.06 * fine) * COLOR.rgb;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
	EMISSION = vec3(step(0.985, h)) * 0.6;
	BACKLIGHT = vec3(0.12, 0.15, 0.2);
	SSS_STRENGTH = 0.2;
}
