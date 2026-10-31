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
	
	// Abyssal Cyber Void (subtle top-down grid fading into deep space)
	vec2 grid_uv = uv * 32.0;
	vec2 grid_line = abs(fract(grid_uv - 0.5) - 0.5) / fwidth(grid_uv);
	float grid_val = 1.0 - min(min(grid_line.x, grid_line.y), 1.0);
	float grid_fade = smoothstep(0.05, 0.75, uv.y) * 0.12;
	base += vec3(0.35, 0.15, 0.65) * grid_val * grid_fade;
	
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
