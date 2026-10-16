shader_type spatial;
// Kitchen-table oilcloth (клеёнка): faded checks with little flowers.

#include "res://shaders/common.gdshaderinc"

void fragment() {
	vec2 uv = UV * 9.0;
	vec2 c = floor(uv);
	float check = mod(c.x + c.y, 2.0);
	vec3 col = mix(vec3(0.86, 0.84, 0.76), vec3(0.62, 0.72, 0.68), check * 0.6);
	vec2 f = fract(uv) - 0.5;
	float flower = smoothstep(0.17, 0.12, length(f + vec2(sin(atan(f.y, f.x) * 5.0) * 0.04)));
	col = mix(col, vec3(0.72, 0.22, 0.18), flower * (1.0 - check) * 0.8);
	col *= 0.92 + 0.08 * vnoise(UV * 30.0);
	ALBEDO = col;
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
}
