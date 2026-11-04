shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float red_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus_uv = vec2(0.5, 0.5);
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.0;
uniform float shockwave_radius : hint_range(0.0, 2.0) = 0.0;
uniform float shockwave_width : hint_range(0.0, 0.5) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	
	// Shockwave UV distortion
	vec2 diff = uv - focus_uv;
	float dist = length(diff);
	if (shockwave_radius > 0.001) {
		float wave_dist = abs(dist - shockwave_radius);
		if (wave_dist < shockwave_width) {
			float wave_factor = (1.0 - wave_dist / shockwave_width);
			vec2 dir = normalize(diff + vec2(0.0001));
			uv += dir * wave_factor * 0.04 * (1.0 - smoothstep(0.0, 1.5, shockwave_radius));
		}
	}
	
	// TV Static / Glitch noise
	float n = hash(uv * 400.0 + vec2(TIME * 60.0));
	
	// Vignette from death focus point
	float dist_from_focus = distance(uv, focus_uv);
	float vignette = smoothstep(0.12, 0.85, dist_from_focus);
	
	// Screen flash & darkness composition
	vec3 night_color = vec3(0.02, 0.005, 0.025);
	vec3 impact_color = vec3(0.85, 0.04, 0.12);
	vec3 tint = mix(night_color, impact_color, red_flash);
	
	// Chromatic Aberration channel offset
	float ca_offset = chromatic_aberration * 0.035 * (1.0 + vignette);
	vec3 ca_color = tint;
	ca_color.r += ca_offset * 1.5;
	ca_color.b -= ca_offset * 1.0;
	
	// Shockwave edge highlight
	float shock_ring = 0.0;
	if (shockwave_radius > 0.001) {
		float sw = abs(dist - shockwave_radius);
		if (sw < shockwave_width * 0.5) {
			shock_ring = (1.0 - sw / (shockwave_width * 0.5)) * 0.6 * (1.0 - smoothstep(0.0, 1.2, shockwave_radius));
		}
	}
	
	float alpha = clamp(darkness * (0.4 + vignette * 0.75) + red_flash * 0.45 + n * noise_strength * 0.22 + shock_ring * 0.35, 0.0, 0.98);
	COLOR = vec4(ca_color + vec3(shock_ring * 0.8, shock_ring * 0.2, shock_ring * 0.3), alpha);
}
