shader_type canvas_item;

// 死亡溶解着色器
// 用法：设置 dissolve_amount 0→1，怪物从噪点边缘逐渐消散
// 使用着色器内程序化噪声，无需外部纹理，gl_compatibility 兼容
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.08;
uniform float noise_scale = 28.0;

// 二维 hash
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 平滑值噪声
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// 透明像素直接丢弃，避免溶解到背景
	if (color.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		float n = value_noise(UV * noise_scale);
		float threshold = dissolve_amount;
		if (n < threshold) {
			// 已溶解部分：完全透明
			COLOR = vec4(0.0);
		} else if (n < threshold + edge_width) {
			// 边缘：发光消散色
			float edge = (n - threshold) / edge_width;
			COLOR = mix(edge_color, color, edge);
		} else {
			COLOR = color;
		}
	}
}
