shader_type canvas_item;

uniform float interval = 3.4;
uniform float sweep_time = 0.7;
uniform float band_width = 0.14;
uniform float strength = 0.45;
uniform float time_offset = 0.0;
uniform vec4 shine_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 p = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
	float diag = p.x + p.y * 0.5;
	float progress = clamp(mod(TIME + time_offset, interval) / sweep_time, 0.0, 1.0);
	float center = mix(-band_width * 2.0, 1.5 + band_width * 2.0, progress);
	float d = abs(diag - center);
	float b = step(d, band_width) * 0.7 + step(d, band_width * 0.4) * 0.3;
	float trail = step(abs(diag - (center - band_width * 1.8)), band_width * 0.25) * 0.5;
	float a = clamp(b + trail, 0.0, 1.0) * strength * base.a * COLOR.a;
	COLOR = vec4(shine_color.rgb, a);
}
