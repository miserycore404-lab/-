shader_type spatial;
// Telogreika (quilted cotton jacket): dark fabric with horizontal stitch lines.

#include "res://shaders/common.gdshaderinc"

void fragment() {
	float rows = fract(UV.y * 9.0);
	float stitch = smoothstep(0.06, 0.0, abs(rows - 0.5) - 0.44);
	float puff = sin(rows * PI);
	vec3 c = COLOR.rgb * (0.7 + 0.35 * puff) * (0.92 + 0.12 * vnoise(UV * 120.0));
	c = mix(c, c * 0.45, stitch);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.2;
}
