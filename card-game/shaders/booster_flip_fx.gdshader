shader_type canvas_item;
render_mode blend_add;

uniform float flash = 0.0;

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(vec3(flash) * mask, mask * flash);
}
