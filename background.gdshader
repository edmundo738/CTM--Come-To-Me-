shader_type canvas_item;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float top_glow = exp(-distance(uv, vec2(0.18, 0.08)) * 2.6);
	float side_glow = exp(-distance(uv, vec2(0.96, 0.76)) * 3.0);
	vec3 base = mix(vec3(0.018, 0.025, 0.061), vec3(0.045, 0.052, 0.115), uv.y);
	base += vec3(0.055, 0.018, 0.105) * top_glow;
	base += vec3(0.005, 0.045, 0.073) * side_glow;
	vec2 cell = floor(uv * vec2(145.0, 95.0));
	float star = step(0.997, hash21(cell));
	float twinkle = 0.45 + 0.55 * sin(TIME * 1.4 + hash21(cell + 5.0) * 6.28);
	base += vec3(0.24, 0.48, 0.72) * star * twinkle * 0.25;
	COLOR = vec4(base, 1.0);
}
