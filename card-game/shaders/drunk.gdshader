shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.6, 0.2, 1.0);

void fragment() {
	float amount = strength * 0.0025 + pulse * 0.004;
	vec2 offset = vec2(sin(TIME * 1.3 + SCREEN_UV.y * 9.0), cos(TIME * 1.1 + SCREEN_UV.x * 7.0)) * amount;
	vec3 color = texture(screen_texture, SCREEN_UV + offset).rgb;
	vec3 ghost = texture(screen_texture, SCREEN_UV - offset * 2.0).rgb;
	color = mix(color, ghost, clamp(strength * 0.25 + pulse * 0.3, 0.0, 0.5));
	vec2 centered = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.85, length(centered));
	color = mix(color, color * tint.rgb, vignette * clamp(strength * 0.5 + pulse * 0.4, 0.0, 0.7));
	COLOR = vec4(color, 1.0);
}
