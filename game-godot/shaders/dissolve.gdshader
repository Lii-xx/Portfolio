shader_type canvas_item;

// 死亡溶解着色器
// 用法：设置 dissolve_amount 0→1，怪物从噪点边缘逐渐消散
// 使用着色器内程序化噪声，无需外部纹理，gl_compatibility 兼容
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.08;
uniform float noise_scale = 28.0;

// 去黑底（与 monster_base.gdshader 同款 亮度+饱和度 key，保证材质切换时不闪烁）
uniform float cutout_amount : hint_range(0.0, 1.0) = 0.85;
uniform float threshold : hint_range(0.0, 0.5) = 0.12;
uniform float feather : hint_range(0.0, 0.3) = 0.08;
uniform float sat_threshold : hint_range(0.0, 0.5) = 0.1;
uniform float use_sat_key : hint_range(0.0, 1.0) = 0.0;  // 0=原版纯亮度抠像, 1=双判定(深色怪物)

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
	// 抠像：use_sat_key=0 原版；=1 双判定+硬黑下限(深色怪物)
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float alpha_mask;
	if (use_sat_key > 0.5) {
		float max_c = max(max(color.r, color.g), color.b);
		float min_c = min(min(color.r, color.g), color.b);
		float sat = (max_c - min_c) / max(max_c, 0.001);
		float luma_bg = 1.0 - smoothstep(threshold, threshold + feather, luma);
		float sat_bg = 1.0 - smoothstep(sat_threshold, sat_threshold + 0.05, sat);
		float bg_score = luma_bg * sat_bg;
		bg_score = max(bg_score, 1.0 - smoothstep(0.0, 0.04, luma));
		alpha_mask = 1.0 - bg_score;
	} else {
		alpha_mask = smoothstep(threshold, threshold + feather, luma);
	}
	color.a *= mix(1.0, alpha_mask, cutout_amount);
	// 透明像素直接丢弃，避免溶解到背景
	if (color.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		float n = value_noise(UV * noise_scale);
		float dissolve_threshold = dissolve_amount;
		if (n < dissolve_threshold) {
			// 已溶解部分：完全透明
			COLOR = vec4(0.0);
		} else if (n < dissolve_threshold + edge_width) {
			// 边缘：发光消散色
			float edge = (n - dissolve_threshold) / edge_width;
			COLOR = mix(edge_color, color, edge);
		} else {
			COLOR = color;
		}
	}
}
