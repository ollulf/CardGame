shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform vec2 card_size = vec2(60.0, 90.0);

void fragment() {
	vec2 rect = card_size + vec2(outline_width * 2.0);
	vec2 t = (UV * rect - vec2(outline_width)) / card_size;
	vec2 d = vec2(outline_width) / card_size;
	vec2 c = clamp(t, vec2(0.0), vec2(1.0));
	float a = texture(TEXTURE, c).a * step(c.x, t.x) * step(t.x, c.x) * step(c.y, t.y) * step(t.y, c.y);
	float n = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		vec2 u = t + vec2(cos(ang), sin(ang)) * d;
		vec2 cu = clamp(u, vec2(0.0), vec2(1.0));
		float inside = step(cu.x, u.x) * step(u.x, cu.x) * step(cu.y, u.y) * step(u.y, cu.y);
		n = max(n, texture(TEXTURE, cu).a * inside);
	}
	float edge = n * (1.0 - a);
	COLOR = vec4(outline_color.rgb, outline_color.a * edge);
}
