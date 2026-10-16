shader_type spatial;
render_mode cull_back;
// Procedural wood. Vertex colour = stain; alpha 0 = end grain (growth rings).
// UV.x runs along the grain in metres.

#include "res://shaders/common.gdshaderinc"

uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float weathering : hint_range(0.0, 1.0) = 0.3;
uniform float grain_scale = 1.0;

varying vec3 wnorm;
varying vec3 wpos;

void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float rough = 0.82;
	if (COLOR.a < 0.5) {
		// end grain: growth rings with cracks
		float r = length(UV);
		float wob = vnoise(UV * 18.0) * 0.012;
		float rings = fract((r + wob) * 55.0);
		float ring_line = smoothstep(0.0, 0.25, rings) * smoothstep(1.0, 0.7, rings);
		vec3 heart = base * vec3(1.35, 1.25, 1.05) + vec3(0.06, 0.04, 0.0);
		base = mix(heart * 0.72, heart, ring_line);
		float crack = smoothstep(0.03, 0.0, abs(fract(atan(UV.y, UV.x) * 0.95 + vnoise(UV * 9.0) * 0.4) - 0.5)) * smoothstep(0.02, 0.08, r);
		base *= 1.0 - crack * 0.5;
		rough = 0.9;
	} else {
		vec2 g = vec2(UV.x * 0.9, UV.y * 16.0) * grain_scale;
		float n = fbm2(g + vec2(0.0, fbm2(g * 0.3) * 3.0));
		float fine = vnoise(vec2(UV.x * 3.0, UV.y * 90.0));
		float knots = smoothstep(0.78, 0.92, vnoise(UV * vec2(1.6, 6.0)));
		base *= 0.72 + 0.5 * n + 0.12 * fine;
		base = mix(base, base * 0.45, knots);
		// weathering: silvery-grey on exposed wood
		float w = weathering * (0.6 + 0.4 * vnoise(UV * vec2(0.7, 3.0)));
		vec3 grey = vec3(dot(base, vec3(0.33))) * vec3(0.95, 0.97, 1.02) * 1.15;
		base = mix(base, grey, w * 0.6);
	}
	// snow dusting on upward faces
	if (snow_amount > 0.0) {
		float up = smoothstep(0.7, 0.95, wnorm.y);
		float n2 = vnoise(wpos.xz * 6.0) * 0.5 + vnoise(wpos.xz * 1.3) * 0.5;
		float s = smoothstep(0.35, 0.6, up * snow_amount * (0.6 + n2));
		base = mix(base, vec3(0.86, 0.9, 0.96), s);
		rough = mix(rough, 0.55, s);
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
