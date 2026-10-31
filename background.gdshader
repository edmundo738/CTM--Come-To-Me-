shader_type canvas_item;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	
	// Deep Cyberpunk night gradient
	vec3 sky_top = vec3(0.015, 0.018, 0.045);
	vec3 sky_mid = vec3(0.035, 0.038, 0.085);
	vec3 sky_bottom = vec3(0.08, 0.035, 0.11);
	vec3 base = mix(sky_top, sky_mid, smoothstep(0.0, 0.6, uv.y));
	base = mix(base, sky_bottom, smoothstep(0.6, 1.0, uv.y));
	
	// Distant cyberpunk skyline silhouette
	float building_x = floor(uv.x * 45.0);
	float building_h = hash21(vec2(building_x, 1.0)) * 0.28 + 0.08;
	if (uv.y > (1.0 - building_h)) {
		float b_shade = 0.02 + hash21(vec2(building_x, 3.0)) * 0.025;
		// Windows flickering
		vec2 win_uv = floor(vec2(fract(uv.x * 45.0) * 4.0, (uv.y - (1.0 - building_h)) * 60.0));
		float win_light = step(0.72, hash21(win_uv + vec2(building_x * 7.0, 0.0)));
		float win_flicker = sin(TIME * 3.0 + building_x) > 0.3 ? 1.0 : 0.4;
		vec3 win_col = mix(vec3(0.0, 0.8, 0.9), vec3(1.0, 0.3, 0.6), hash21(vec2(building_x, 5.0)));
		base = mix(base, vec3(b_shade) + win_col * win_light * win_flicker * 0.22, 0.85);
	}
	
	// Ambient neon flares
	float flare_left = exp(-distance(uv, vec2(0.12, 0.88)) * 3.2);
	float flare_right = exp(-distance(uv, vec2(0.88, 0.82)) * 3.5);
	float flare_top = exp(-distance(uv, vec2(0.5, 0.05)) * 2.8);
	base += vec3(0.0, 0.08, 0.14) * flare_left;
	base += vec3(0.12, 0.03, 0.10) * flare_right;
	base += vec3(0.04, 0.02, 0.08) * flare_top;
	
	// Star field & digital dust
	vec2 star_cell = floor(uv * vec2(160.0, 100.0));
	float star = step(0.995, hash21(star_cell));
	float twinkle = 0.4 + 0.6 * sin(TIME * 2.2 + hash21(star_cell + 4.2) * 6.28);
	base += vec3(0.4, 0.75, 1.0) * star * twinkle * 0.35;
	
	// Subtle digital scanline
	float scanline = sin(uv.y * 360.0) * 0.02;
	base -= vec3(scanline);
	
	COLOR = vec4(clamp(base, 0.0, 1.0), 1.0);
}
