shader_type canvas_item;
render_mode blend_add;

uniform float flash = 0.0;
uniform float sweep = -1.0;
uniform float band_width = 0.14;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
	float mask = texture(TEXTURE, UV).a;
	float diag = pixel_uv.x * 0.6 + pixel_uv.y * 0.4;
	float center = mix(-band_width * 2.0, 1.0 + band_width * 2.0, sweep);
	float shine = 1.0 - smoothstep(0.0, band_width, abs(diag - center));
	shine += (1.0 - smoothstep(0.0, band_width * 0.3, abs(diag - center + band_width * 1.7))) * 0.6;
	shine *= step(0.0, sweep) * step(sweep, 1.0);
	float strength = clamp(flash + shine * 0.8, 0.0, 1.0);
	COLOR = vec4(tint.rgb * strength * mask, mask * strength);
}
