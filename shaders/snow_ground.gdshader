shader_type spatial;
render_mode cull_back;
// Fresh snow: blue-tinted subsurface look, wind ripples (sastrugi),
// view-dependent sparkle, and trodden paths from vertex colour R.

#include "res://shaders/common.gdshaderinc"

uniform vec3 snow_color : source_color = vec3(0.9, 0.93, 0.98);
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.66, 0.86);
uniform float sparkle_strength = 2.5;
uniform vec3 path_color : source_color = vec3(0.74, 0.76, 0.8);

varying vec3 wpos;
varying float path;
varying float under_tree;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	path = COLOR.r;
	under_tree = COLOR.g;
}

void fragment() {
	vec2 p = wpos.xz;
	float large = fbm2(p * 0.05);
	float ripple = vnoise(vec2(p.x * 0.9 + p.y * 0.35, p.y * 0.25) * 2.0);
	float fine = vnoise(p * 11.0);
	vec3 col = snow_color * (0.93 + 0.07 * large);
	col = mix(col, col * vec3(0.94, 0.96, 1.0), ripple * 0.4);
	// trodden path: compacted, slightly grey, more texture
	float pth = smoothstep(0.15, 0.7, path) * (0.75 + 0.25 * vnoise(p * 2.5));
	col = mix(col, path_color * (0.9 + 0.2 * fine), pth * 0.55);
	// needles & debris beneath spruces
	float debris = under_tree * smoothstep(0.55, 0.8, vnoise(p * 7.0));
	col = mix(col, vec3(0.42, 0.42, 0.4), debris * 0.25);

	// micro-normal from ripples
	vec2 grad = vec2(vnoise(p * 2.0 + vec2(0.1, 0.0)) - vnoise(p * 2.0 - vec2(0.1, 0.0)), vnoise(p * 2.0 + vec2(0.0, 0.1)) - vnoise(p * 2.0 - vec2(0.0, 0.1)));
	vec3 nw = normalize(vec3(-grad.x * 0.6, 1.0, -grad.y * 0.6));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nw, 0.0)).xyz, 0.35 + pth * 0.3));

	// sparkle: sparse cells that glint when the view direction catches them
	vec3 cell = floor(wpos * 38.0);
	float h = hash13(cell);
	vec3 rnd_n = normalize(vec3(hash13(cell + 1.3) - 0.5, 1.0, hash13(cell + 7.1) - 0.5));
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float glint = pow(max(dot(reflect(-vdir, rnd_n), normalize(vec3(0.3, 0.6, 0.2))), 0.0), 40.0);
	float spark = step(0.965, h) * glint * (1.0 - pth);

	ALBEDO = col;
	ROUGHNESS = mix(0.62, 0.85, pth);
	SPECULAR = 0.3;
	EMISSION = vec3(spark) * sparkle_strength * snow_color;
	BACKLIGHT = shadow_tint * 0.18;
	SSS_STRENGTH = 0.25;
}
