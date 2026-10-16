shader_type spatial;
// Old red brick chimney with lime mortar, triplanar in world space.

#include "res://shaders/common.gdshaderinc"

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 bricks(vec2 p) {
	vec2 s = vec2(0.25, 0.065);
	vec2 q = p / s;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 f = fract(q);
	vec2 id = floor(q);
	float mortar = step(f.x, 0.04) + step(f.y, 0.12);
	vec3 brick = vec3(0.48, 0.2, 0.14) * (0.75 + 0.45 * hash12(id)) * (0.85 + 0.2 * vnoise(p * 40.0));
	return mix(brick, vec3(0.7, 0.68, 0.64), clamp(mortar, 0.0, 1.0));
}

void fragment() {
	vec3 n = abs(wnorm);
	vec3 c = n.x > n.z ? bricks(wpos.zy) : bricks(wpos.xy);
	if (n.y > 0.7) c = vec3(0.3, 0.27, 0.25);
	float snow = smoothstep(0.6, 0.9, wnorm.y);
	c = mix(c, vec3(0.88, 0.91, 0.97), snow);
	// soot at the top
	c *= mix(1.0, 0.45, smoothstep(0.5, 0.0, COLOR.r));
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
