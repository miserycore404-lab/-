shader_type spatial;
// Tree bark. mode 0 = spruce (dark, scaly), 1 = birch (white with black
// lenticels and dark cracked base), 2 = pine (grey base, orange upper).
// UV.x = height along branch in metres, UV.y = around circumference in metres.

#include "res://shaders/common.gdshaderinc"

uniform int mode = 0;
uniform float snow_amount = 0.6;

varying vec3 wnorm;
varying vec3 wpos;
varying vec3 opos;

void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = VERTEX;
}

void fragment() {
	vec2 uv = UV;
	vec3 col;
	float rough = 0.9;
	if (mode == 1) {
		// birch
		float lent = smoothstep(0.62, 0.7, vnoise(vec2(uv.x * 9.0, uv.y * 1.6)) * vnoise(vec2(uv.x * 2.0, uv.y * 0.5) + 3.0) * 1.8);
		float marks = smoothstep(0.7, 0.78, vnoise(vec2(uv.x * 1.3, uv.y * 3.5)));
		float base_dark = smoothstep(1.6, 0.2, opos.y) * smoothstep(0.35, 0.6, vnoise(vec2(uv.x * 2.5, uv.y * 6.0)) + 0.3);
		col = vec3(0.86, 0.85, 0.8) * (0.92 + 0.08 * vnoise(uv * vec2(4.0, 30.0)));
		col = mix(col, vec3(0.09, 0.08, 0.08), max(max(lent * 0.9, marks), base_dark));
		col = mix(col, vec3(0.78, 0.72, 0.62), vnoise(uv * 3.0) * 0.12);
		rough = 0.7;
	} else if (mode == 2) {
		float upper = smoothstep(4.0, 9.0, opos.y);
		float plates = vnoise(vec2(uv.x * 3.0, uv.y * 7.0));
		vec3 lower = vec3(0.25, 0.21, 0.18) * (0.6 + 0.6 * plates);
		vec3 top = vec3(0.72, 0.42, 0.24) * (0.85 + 0.25 * vnoise(vec2(uv.x * 10.0, uv.y * 20.0)));
		col = mix(lower, top, upper);
	} else {
		float scales = vnoise(vec2(uv.x * 7.0, uv.y * 11.0));
		col = vec3(0.22, 0.17, 0.14) * (0.55 + 0.7 * scales);
		col = mix(col, vec3(0.32, 0.33, 0.28), smoothstep(0.6, 0.8, vnoise(uv * 4.0)) * 0.5);
	}
	col *= COLOR.rgb;
	float up = smoothstep(0.3, 0.9, wnorm.y);
	float s = smoothstep(0.4, 0.6, up * snow_amount * (0.5 + vnoise(wpos.xz * 5.0)));
	col = mix(col, vec3(0.88, 0.92, 0.98), s);
	ALBEDO = col;
	ROUGHNESS = rough;
}
