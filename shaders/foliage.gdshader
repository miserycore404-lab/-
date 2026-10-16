shader_type spatial;
render_mode cull_disabled;
// Conifer needles with snow load. Vertex colour = needle tint,
// colour alpha = exposure (outer/upper surfaces catch more snow).

#include "res://shaders/common.gdshaderinc"

uniform float snow_amount : hint_range(0.0, 1.0) = 0.6;
uniform float wind_strength = 0.06;
uniform vec3 snow_color : source_color = vec3(0.88, 0.92, 0.98);

varying vec3 wpos;
varying vec3 wnorm;
varying float sway;

void vertex() {
	vec3 obj = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height = VERTEX.y;
	float t = TIME * 0.7 + obj.x * 0.13 + obj.z * 0.07;
	float s = (sin(t) + 0.5 * sin(t * 2.3 + 1.0)) * wind_strength * height * 0.02;
	sway = s;
	VERTEX.x += s * (1.0 - COLOR.a * 0.3);
	VERTEX.z += s * 0.6;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	float noise = vnoise(wpos.xz * 2.2 + wpos.y * 0.7);
	float clumps = vnoise(wpos.xz * 0.9 + vec2(wpos.y * 1.3));
	float up = smoothstep(0.1, 0.75, n.y);
	float s = smoothstep(0.45, 0.62, up * COLOR.a * snow_amount * 1.6 * (0.55 + 0.45 * noise) + clumps * 0.15);
	vec3 needle = COLOR.rgb * (0.75 + 0.5 * vnoise(wpos.xz * 9.0 + wpos.y * 4.0));
	ALBEDO = mix(needle, snow_color, s);
	ROUGHNESS = mix(0.9, 0.6, s);
	SPECULAR = mix(0.2, 0.35, s);
	BACKLIGHT = mix(vec3(0.05, 0.08, 0.05), vec3(0.25, 0.3, 0.38), s);
}
