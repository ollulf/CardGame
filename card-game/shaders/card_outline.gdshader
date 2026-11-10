shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 1.0;

float inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

void fragment() {
	float self_a = texture(TEXTURE, UV).a;
	vec2 d = TEXTURE_PIXEL_SIZE * outline_width;
	vec2 u1 = UV + vec2(d.x, 0.0);
	vec2 u2 = UV - vec2(d.x, 0.0);
	vec2 u3 = UV + vec2(0.0, d.y);
	vec2 u4 = UV - vec2(0.0, d.y);
	float n = min(
		min(texture(TEXTURE, u1).a * inside(u1), texture(TEXTURE, u2).a * inside(u2)),
		min(texture(TEXTURE, u3).a * inside(u3), texture(TEXTURE, u4).a * inside(u4)));
	float edge = self_a * (1.0 - n);
	COLOR = vec4(outline_color.rgb, outline_color.a * edge);
}
