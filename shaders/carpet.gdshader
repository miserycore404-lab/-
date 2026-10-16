shader_type spatial;
// The Soviet wall carpet: burgundy field, central medallions, navy and
// cream ornament borders. UV in metres from MeshKit.

#include "res://shaders/common.gdshaderinc"

uniform vec2 size = vec2(2.0, 1.4);

float diamond(vec2 p, float r) {
	return abs(p.x) + abs(p.y) - r;
}

void fragment() {
	vec2 uv = UV / size;
	vec2 p = uv - 0.5;
	vec3 burgundy = vec3(0.38, 0.06, 0.07);
	vec3 crimson = vec3(0.62, 0.12, 0.1);
	vec3 navy = vec3(0.08, 0.1, 0.22);
	vec3 cream = vec3(0.85, 0.77, 0.6);
	vec3 ochre = vec3(0.7, 0.48, 0.18);
	vec3 col = burgundy;
	// border bands
	vec2 e = min(uv, 1.0 - uv) * size;
	float edge = min(e.x, e.y);
	if (edge < 0.04) col = navy;
	else if (edge < 0.055) col = cream;
	else if (edge < 0.16) {
		// running ornament: little stepped diamonds
		vec2 bp = (e.x < e.y ? vec2(uv.y * size.y, e.x) : vec2(uv.x * size.x, e.y));
		vec2 q = vec2(fract(bp.x * 8.0) - 0.5, (bp.y - 0.105) * 8.0);
		float d = diamond(q, 0.38);
		col = d < 0.0 ? (d < -0.18 ? ochre : cream) : navy;
	} else if (edge < 0.175) col = cream;
	else {
		// field: repeating medallions
		vec2 q = p * size;
		vec2 cell = vec2(0.5, 0.5);
		vec2 g = mod(q + cell * 0.5, cell) - cell * 0.5;
		float d1 = diamond(g * vec2(1.0, 1.25), 0.2);
		float d2 = diamond(g * vec2(1.0, 1.25), 0.13);
		float d3 = diamond(g * vec2(1.0, 1.25), 0.05);
		if (d1 < 0.0) col = navy;
		if (d1 < -0.015) col = crimson;
		if (d2 < 0.0) col = cream;
		if (d2 < -0.02) col = navy;
		if (d3 < 0.0) col = ochre;
		// central big medallion
		float dm = diamond(q * vec2(0.8, 1.1), 0.36);
		if (dm < 0.0 && dm > -0.03) col = cream;
		else if (dm < -0.03 && d1 > 0.0) col = mix(burgundy, crimson, 0.6);
	}
	// pile texture
	float pile = vnoise(UV * 220.0) * 0.12 + vnoise(UV * 40.0) * 0.06;
	col *= 0.88 + pile;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
