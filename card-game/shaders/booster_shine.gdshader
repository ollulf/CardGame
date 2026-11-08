shader_type canvas_item;

uniform float interval = 2.6;
uniform float sweep_time = 0.9;
uniform float band_width = 0.16;
uniform float strength = 0.7;
uniform float time_offset = 0.0;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float band(float diag, float center, float half_width) {
	return 1.0 - smoothstep(0.0, half_width, abs(diag - center));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
	float diag = pixel_uv.x + pixel_uv.y * 0.5;
	float progress = clamp(mod(TIME + time_offset, interval) / sweep_time, 0.0, 1.0);
	float center = mix(-band_width * 2.0, 1.5 + band_width * 2.0, progress);
	float shine = band(diag, center, band_width) + band(diag, center - band_width * 1.6, band_width * 0.35) * 0.6;
	shine = clamp(shine, 0.0, 1.0) * strength;
	COLOR = vec4(mix(base.rgb, shine_color.rgb, shine), base.a);
}
