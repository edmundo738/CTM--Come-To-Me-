shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float red_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus_uv = vec2(0.5, 0.5);

void fragment() {
	float distance_from_focus = distance(UV, focus_uv);
	float vignette = smoothstep(0.18, 0.88, distance_from_focus);
	float alpha = clamp(darkness * (0.55 + vignette * 0.62), 0.0, 0.94);
	vec3 night_color = vec3(0.012, 0.006, 0.019);
	vec3 impact_color = vec3(0.64, 0.018, 0.09);
	vec3 color = mix(night_color, impact_color, red_flash);
	COLOR = vec4(color, clamp(alpha + red_flash * 0.34, 0.0, 0.97));
}
