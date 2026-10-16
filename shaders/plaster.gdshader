shader_type spatial;
// Whitewashed lime plaster of the Russian stove: uneven, brush strokes,
// soot near the mouth (vertex colour darkens it).

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float strokes = vnoise(vec2(wpos.x * 3.0 + wpos.z * 3.0, wpos.y * 18.0));
	float blotch = fbm3(wpos * 2.5);
	vec3 c = vec3(0.9, 0.89, 0.85) * (0.9 + 0.08 * strokes + 0.08 * blotch);
	c = mix(c, vec3(0.78, 0.74, 0.68), smoothstep(0.55, 0.75, blotch) * 0.4);
	c *= COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.96;
}
