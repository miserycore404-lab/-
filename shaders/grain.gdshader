shader_type canvas_item;
// Svema-film look: grain, soft vignette, a faint warm/cold split and the
// occasional dust speck. Pure overlay (no screen read) so it's cheap.

uniform float grain = 0.05;
uniform float vignette = 0.45;
uniform vec4 warmth : source_color = vec4(1.0, 0.6, 0.3, 0.0);
uniform float cold = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 24.0);
	float g = hash(uv * vec2(1920.0, 1080.0) * 0.5 + t * 1.37) - 0.5;
	vec2 c = uv - 0.5;
	float v = smoothstep(0.35, 0.95, length(c * vec2(1.1, 1.25)));
	vec4 col = vec4(0.0, 0.0, 0.0, v * vignette);
	// grain: mix toward white or black
	float ga = abs(g) * grain * 2.0;
	col = mix(col, vec4(vec3(step(0.0, g)), 1.0), ga);
	// warmth flash (drinking coffee, the stove) blooms from the bottom
	float wa = warmth.a * (0.4 + 0.6 * smoothstep(0.2, 1.0, uv.y)) * (0.4 + 0.6 * v);
	col = mix(col, vec4(warmth.rgb, 1.0), wa);
	// cold: frost at the edges
	col = mix(col, vec4(0.75, 0.85, 1.0, 1.0), cold * v * 0.35);
	COLOR = col;
}
