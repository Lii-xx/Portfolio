shader_type canvas_item;

// 受击闪白着色器（参考美术开发大纲 5.4 节）
// 用法：设置 flash_intensity 0→1→0 实现闪白脉冲
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

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
	float alpha;
	if (use_sat_key > 0.5) {
		float max_c = max(max(color.r, color.g), color.b);
		float min_c = min(min(color.r, color.g), color.b);
		float sat = (max_c - min_c) / max(max_c, 0.001);
		float luma_bg = 1.0 - smoothstep(threshold, threshold + feather, luma);
		float sat_bg = 1.0 - smoothstep(sat_threshold, sat_threshold + 0.05, sat);
		float bg_score = luma_bg * sat_bg;
		bg_score = max(bg_score, 1.0 - smoothstep(0.0, 0.04, luma));
		alpha = 1.0 - bg_score;
	} else {
		alpha = smoothstep(threshold, threshold + feather, luma);
	}
	color.a *= mix(1.0, alpha, cutout_amount);
	// 闪白：将原色向 flash_color 混合，保留原 alpha
	COLOR = vec4(mix(color.rgb, flash_color.rgb, flash_intensity), color.a);
}
