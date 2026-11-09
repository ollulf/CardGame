shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float vignette_strength : hint_range(0.0, 1.5) = 0.0;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.85;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.6;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.02, 0.01, 1.0);

uniform float grade_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grade_shadows : source_color = vec3(0.52, 0.38, 0.30);
uniform vec3 grade_highlights : source_color = vec3(1.0, 0.86, 0.62);
uniform float grade_contrast : hint_range(0.5, 1.6) = 1.08;
uniform float grade_saturation : hint_range(0.0, 1.6) = 0.85;

uniform float grain_strength : hint_range(0.0, 0.3) = 0.0;
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;

uniform float bloom_strength : hint_range(0.0, 2.0) = 0.0;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float bloom_radius : hint_range(1.0, 12.0) = 6.0;
uniform vec3 bloom_tint : source_color = vec3(1.0, 0.85, 0.65);

uniform float haze_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 haze_color : source_color = vec3(0.62, 0.58, 0.55);
uniform float haze_scale : hint_range(0.5, 8.0) = 2.5;
uniform float haze_speed : hint_range(0.0, 0.2) = 0.03;

uniform float aberration_strength : hint_range(0.0, 6.0) = 0.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count : hint_range(100.0, 800.0) = 270.0;
uniform float crt_curve : hint_range(0.0, 0.3) = 0.0;

uniform float flicker_strength : hint_range(0.0, 0.5) = 0.0;
uniform vec2 lamp_center = vec2(0.5, 0.4);
uniform float lamp_radius : hint_range(0.1, 1.5) = 0.75;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.8, 0.55);

uniform float wobble_strength : hint_range(0.0, 1.0) = 0.0;
uniform float wobble_speed : hint_range(0.1, 4.0) = 1.1;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 sample_screen(vec2 uv) {
	if (aberration_strength <= 0.0) {
		return texture(screen_tex, uv).rgb;
	}
	vec2 dir = (uv - 0.5) * aberration_strength * 0.004;
	float r = texture(screen_tex, uv + dir).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - dir).b;
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float aspect = px.y / px.x;

	if (crt_curve > 0.0) {
		vec2 c = uv * 2.0 - 1.0;
		c *= 1.0 + crt_curve * vec2(c.y * c.y, c.x * c.x);
		uv = c * 0.5 + 0.5;
	}

	if (wobble_strength > 0.0) {
		float t = TIME * wobble_speed;
		vec2 w = vec2(sin(uv.y * 6.0 + t * 1.3) + sin(uv.y * 13.0 - t * 0.7) * 0.4, cos(uv.x * 5.0 + t) + cos(uv.x * 11.0 + t * 1.7) * 0.4);
		vec2 edge = smoothstep(0.0, 0.05, uv) * smoothstep(1.0, 0.95, uv);
		uv += w * wobble_strength * 0.004 * edge.x * edge.y;
	}

	vec3 col = sample_screen(uv);

	if (wobble_strength > 0.0) {
		vec2 ghost = vec2(sin(TIME * wobble_speed * 0.8), cos(TIME * wobble_speed * 0.6)) * wobble_strength * 0.008;
		col = mix(col, texture(screen_tex, uv + ghost).rgb, 0.35 * wobble_strength);
	}

	if (bloom_strength > 0.0) {
		vec3 acc = vec3(0.0);
		float total = 0.0;
		for (int ring = 1; ring <= 3; ring++) {
			float rr = float(ring) / 3.0 * bloom_radius;
			for (int k = 0; k < 8; k++) {
				float ang = float(k) * 0.785398 + float(ring) * 0.4;
				vec3 s = texture(screen_tex, uv + vec2(cos(ang), sin(ang)) * rr * 0.0025).rgb;
				float wgt = 1.0 / float(ring);
				acc += max(s - bloom_threshold, vec3(0.0)) * wgt;
				total += wgt;
			}
		}
		col += acc / total * bloom_strength * bloom_tint * 2.5;
	}

	if (grade_strength > 0.0) {
		vec3 g = (col - 0.5) * grade_contrast + 0.5;
		float l = clamp(luma(g), 0.0, 1.0);
		g = mix(vec3(l), g, grade_saturation);
		vec3 split = mix(grade_shadows * 2.0, grade_highlights * 1.1, smoothstep(0.0, 1.0, l));
		g *= mix(vec3(1.0), split, 0.6);
		col = mix(col, g, grade_strength);
	}

	if (haze_strength > 0.0) {
		vec2 hp = vec2(uv.x * aspect, uv.y) * haze_scale;
		float t = TIME * haze_speed;
		float n = fbm(hp + vec2(t, -t * 0.6));
		n = fbm(hp * 0.7 + vec2(n * 1.5, n) + vec2(-t * 0.5, t * 0.3));
		float rise = mix(1.0, 0.6, uv.y);
		float h = smoothstep(0.3, 0.8, n) * haze_strength * rise;
		col = mix(col, haze_color, h * 0.55);
		col += haze_color * h * 0.08;
	}

	if (flicker_strength > 0.0) {
		float t = TIME;
		float f = 0.6 * sin(t * 2.1) + 0.3 * sin(t * 5.3 + 1.0) + 0.1 * sin(t * 13.7);
		float dip = step(0.92, value_noise(vec2(t * 3.0, 0.0)));
		float d = length((uv - lamp_center) * vec2(aspect, 1.0));
		float pool = 1.0 - smoothstep(0.0, lamp_radius, d);
		float lit = 1.0 + (f * 0.25 - dip * 0.6) * flicker_strength * (0.4 + pool) + (pool - 0.5) * flicker_strength * 0.9;
		col *= lit * mix(vec3(1.0), lamp_color, pool * flicker_strength * 2.0);
	}

	if (vignette_strength > 0.0) {
		float d = length((uv - 0.5) * vec2(aspect, 1.0)) / sqrt(aspect * aspect + 1.0) * 2.0;
		float v = smoothstep(vignette_radius + vignette_softness * 0.5, vignette_radius - vignette_softness * 0.5, d);
		col = mix(col, vignette_color.rgb, clamp((1.0 - v) * vignette_strength, 0.0, 1.0));
	}

	if (scanline_strength > 0.0) {
		float s = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * (1.0 - s) * 0.5;
		float m = mod(FRAGCOORD.x, 3.0);
		vec3 mask = vec3(m < 1.0 ? 1.0 : 0.85, (m >= 1.0 && m < 2.0) ? 1.0 : 0.85, m >= 2.0 ? 1.0 : 0.85);
		col *= mix(vec3(1.0), mask, scanline_strength);
		col *= 1.0 + scanline_strength * 0.15;
	}

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.0);
	}

	if (grain_strength > 0.0) {
		vec2 gp = floor(FRAGCOORD.xy / grain_size);
		float n = hash(gp + fract(TIME * 7.13) * 91.7) - 0.5;
		float l = luma(col);
		col += n * grain_strength * (1.0 - l * 0.6);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
