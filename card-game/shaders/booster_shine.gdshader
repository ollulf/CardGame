shader_type canvas_item;

uniform sampler2D shading_map : filter_nearest;
uniform float time_offset = 0.0;
uniform float hue_speed = 0.12;
uniform float hue_spread = 0.9;
uniform float fold_influence = 0.55;
uniform float hue_steps = 10.0;
uniform float saturation = 0.55;
uniform float holo_strength = 0.6;
uniform float light_speed = 0.9;
uniform float interval = 2.6;
uniform float sweep_time = 0.9;
uniform float band_width = 0.16;
uniform float glint_strength = 0.55;

vec3 hsv_to_rgb(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

float band(float diag, float center, float half_width) {
	return 1.0 - smoothstep(0.0, half_width, abs(diag - center));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
	vec4 shading = texture(shading_map, pixel_uv);
	vec2 normal = shading.rg * 2.0 - 1.0;
	float height = shading.b;
	float t = TIME + time_offset;

	float hue = (pixel_uv.x * 0.5 + pixel_uv.y) * hue_spread;
	hue += dot(normal, vec2(0.8, 0.6)) * fold_influence + height * fold_influence;
	hue -= t * hue_speed;
	hue = floor(fract(hue) * hue_steps) / hue_steps;
	vec3 rainbow = hsv_to_rgb(hue, saturation, 1.0);

	vec2 light = vec2(cos(t * light_speed), sin(t * light_speed));
	float facing = clamp(0.55 + dot(normal, light) * 1.5, 0.0, 1.0);
	float holo = holo_strength * facing;
	vec3 color = mix(base.rgb, base.rgb * rainbow * 1.35, holo);
	color += rainbow * holo * 0.12 * height;

	float diag = pixel_uv.x + pixel_uv.y * 0.5;
	float progress = clamp(mod(t, interval) / sweep_time, 0.0, 1.0);
	float center = mix(-band_width * 2.0, 1.5 + band_width * 2.0, progress);
	float glint = band(diag, center, band_width) + band(diag, center - band_width * 1.6, band_width * 0.35) * 0.6;
	glint = clamp(glint, 0.0, 1.0) * glint_strength;
	color = mix(color, mix(vec3(1.0), rainbow, 0.5), glint);

	COLOR = vec4(clamp(color, 0.0, 1.0), base.a);
}
