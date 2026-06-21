shader_type canvas_item;

// 中毒变绿着色器
// 用法：怪物中毒时 poison_amount 设为 0.6 左右，呈现绿色病态
uniform float poison_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 poison_color : source_color = vec4(0.4, 1.0, 0.2, 1.0);

// 去黑底（与 monster_base.gdshader 同款 亮度+饱和度 key，保证材质切换时不闪烁）
uniform float cutout_amount : hint_range(0.0, 1.0) = 0.85;
uniform float threshold : hint_range(0.0, 0.5) = 0.12;
uniform float feather : hint_range(0.0, 0.3) = 0.08;
uniform float sat_threshold : hint_range(0.0, 0.5) = 0.1;
uniform float use_sat_key : hint_range(0.0, 1.0) = 0.0;  // 0=原版纯亮度抠像, 1=双判定(深色怪物)

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

	if (color.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		// 向毒色混合（最多 60%，保留原色识别度）
		vec3 poisoned = mix(color.rgb, poison_color.rgb, poison_amount * 0.6);
		COLOR = vec4(poisoned, color.a);
	}
}
