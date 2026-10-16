shader_type sky;
render_mode use_quarter_res_pass;
// Russian winter sky: deep blue zenith, a low band of pink-amber where the
// sun went down, frost haze at the horizon, stars and a hazy moon.

uniform vec3 zenith : source_color = vec3(0.1, 0.16, 0.32);
uniform vec3 horizon : source_color = vec3(0.62, 0.52, 0.58);
uniform vec3 ground_col : source_color = vec3(0.3, 0.33, 0.4);
uniform vec3 glow_col : source_color = vec3(1.0, 0.55, 0.32);
uniform vec3 sun_dir = vec3(-0.7, -0.05, -0.7);
uniform float sun_disc = 0.0;
uniform vec3 moon_dir = vec3(0.4, 0.3, 0.8);
uniform float moon_amount = 1.0;
uniform float stars = 0.0;
uniform float clouds = 0.35;
uniform vec3 cloud_col : source_color = vec3(0.35, 0.36, 0.45);
uniform float horizon_haze = 1.0;
// Advanced from script in coarse steps instead of TIME, so the sky radiance
// is not recomputed every frame.
uniform float sky_time = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n2(p);
		p = p * 2.02 + vec2(1.3, 7.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sd = normalize(sun_dir);
	vec3 col;
	if (h >= 0.0) {
		float t = pow(h, 0.42);
		col = mix(horizon, zenith, t);
		// glow band toward the sun, hugging the horizon
		float s = max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(sd.x, 0.0, sd.z))), 0.0);
		float band = pow(s, 3.0) * exp(-h * 9.0);
		col += glow_col * band * 0.9;
		col += glow_col * pow(max(dot(d, sd), 0.0), 64.0) * 0.6;
		// pale frost haze just above the horizon
		col = mix(col, horizon * 1.08, exp(-h * 30.0) * 0.5 * horizon_haze);
	} else {
		col = mix(horizon * 0.9, ground_col, smoothstep(0.0, -0.15, h));
	}
	// sun disc
	if (sun_disc > 0.0) {
		float sdot = dot(d, sd);
		col += glow_col * 6.0 * smoothstep(0.9993, 0.9997, sdot) * sun_disc;
	}
	// stars (skip in the low-res radiance passes)
	if (stars > 0.0 && h > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 sp = d * 380.0;
		vec3 cell = floor(sp);
		float r = hash(cell);
		float star = step(0.9975, r);
		vec3 f = fract(sp) - 0.5;
		float shape = smoothstep(0.35, 0.0, length(f));
		float tw = 0.6 + 0.4 * sin(sky_time * (2.0 + r * 5.0) + r * 60.0);
		float mag = pow(hash(cell + 3.1), 3.0);
		col += vec3(0.85, 0.9, 1.0) * star * shape * tw * (0.6 + 2.5 * mag) * stars * smoothstep(0.0, 0.25, h);
		// Milky Way haze
		float mw = fbm(vec2(atan(d.x, d.z) * 3.0, d.y * 6.0)) * smoothstep(0.6, 0.0, abs(dot(d, normalize(vec3(0.3, 0.6, -0.7)))));
		col += vec3(0.08, 0.09, 0.12) * mw * stars;
	}
	// moon with halo
	if (moon_amount > 0.0) {
		vec3 md = normalize(moon_dir);
		float m = dot(d, md);
		float disc = smoothstep(0.99955, 0.99965, m);
		// craters / maria
		vec3 tangent = normalize(cross(md, vec3(0, 1, 0)));
		vec3 bit = cross(tangent, md);
		vec2 mp = vec2(dot(d - md, tangent), dot(d - md, bit)) * 600.0;
		float maria = n2(mp * 0.8) * 0.5 + n2(mp * 2.0) * 0.25;
		col += vec3(0.95, 0.93, 0.85) * disc * (0.9 - maria * 0.45) * 2.4 * moon_amount;
		col += vec3(0.55, 0.62, 0.8) * pow(max(m, 0.0), 300.0) * 0.4 * moon_amount;
		col += vec3(0.3, 0.36, 0.5) * pow(max(m, 0.0), 18.0) * 0.12 * moon_amount;
	}
	// clouds: thin stratus drifting
	if (clouds > 0.0 && h > 0.0) {
		vec2 cp = d.xz / (h + 0.12) * 1.4 + vec2(sky_time * 0.004, sky_time * 0.002);
		float c = fbm(cp);
		float cov = smoothstep(1.0 - clouds, 1.0 - clouds + 0.35, c);
		vec3 cc = cloud_col;
		float lit = pow(max(dot(d, sd), 0.0), 4.0);
		cc += glow_col * lit * 0.35;
		col = mix(col, cc, cov * smoothstep(0.0, 0.15, h) * 0.85);
	}
	COLOR = col;
}
