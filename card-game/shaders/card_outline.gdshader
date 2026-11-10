shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform vec2 card_size = vec2(60.0, 90.0);

float sprite_alpha(sampler2D tex, vec2 t) {
	float inside = step(0.0, t.x) * step(0.0, t.y) * step(t.x, 1.0) * step(t.y, 1.0);
	return texture(tex, clamp(t, vec2(0.0), vec2(1.0))).a * inside;
}

void fragment() {
	vec2 rect = card_size + vec2(outline_width * 2.0);
	vec2 t = (UV * rect - vec2(outline_width)) / card_size;
	vec2 d = vec2(outline_width) / card_size;
	float a = sprite_alpha(TEXTURE, t);
	float n = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		n = max(n, sprite_alpha(TEXTURE, t + vec2(cos(ang), sin(ang)) * d));
	}
	float edge = n * (1.0 - a);
	COLOR = vec4(outline_color.rgb, outline_color.a * edge);
}
