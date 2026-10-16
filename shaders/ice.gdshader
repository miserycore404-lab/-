shader_type spatial;
// Frozen pond: black ice under drifting snow, with white crack lines and
// trapped air bubbles.

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.0));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 p = wpos.xz;
	float drift = fbm2(p * 0.12 + vec2(fbm2(p * 0.05) * 2.0));
	float snow = smoothstep(0.42, 0.62, drift);
	float c = smoothstep(0.05, 0.0, cracks(p * 0.35)) * 0.6 + smoothstep(0.03, 0.0, cracks(p * 1.1)) * 0.3;
	float bubbles = step(0.985, hash12(floor(p * 18.0))) * 0.5;
	vec3 ice = mix(vec3(0.05, 0.09, 0.12), vec3(0.18, 0.26, 0.32), vnoise(p * 0.4));
	ice += vec3(0.55, 0.65, 0.72) * (c + bubbles) * (1.0 - snow);
	// edge of the pond fades into snow
	float edge = smoothstep(0.75, 1.0, length(UV - 0.5) * 2.0);
	vec3 col = mix(ice, vec3(0.88, 0.91, 0.97), clamp(snow + edge, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.7, clamp(snow + edge, 0.0, 1.0));
	SPECULAR = 0.7;
}
