shader_type canvas_item;

// 怪物基础着色器：亮度抠像去黑底
// 用途：AI 生成的怪物图是纯黑背景，直接贴到紫底游戏上会像"黑补丁"。
// 本 shader 把暗像素变透明（luma key），让怪物本身"站"在背景上。
// 与 hit_flash/dissolve/poison 同样含这段抠像逻辑，保证切换材质时不闪烁。
//
// 参数：
//   cutout_amount : 0=不去黑底（原图），1=最强（连深灰也被擦掉）。默认 0.85
//   threshold     : 亮度低于此值的像素被视为"背景"。默认 0.12（约 RGB 30）
//   feather       : 边缘羽化，避免硬边。默认 0.08
//   sat_threshold : 饱和度低于此值视为"无色背景"。默认 0.1
//                   双判定：亮度低 且 饱和度低 才算黑背景被擦掉，
//                   深色怪物（暗紫/暗红等）因饱和度高而保留。
uniform float cutout_amount : hint_range(0.0, 1.0) = 0.85;
uniform float threshold : hint_range(0.0, 0.5) = 0.12;
uniform float feather : hint_range(0.0, 0.3) = 0.08;
uniform float sat_threshold : hint_range(0.0, 0.5) = 0.1;
uniform float use_sat_key : hint_range(0.0, 1.0) = 0.0;  // 0=原版纯亮度抠像, 1=亮度+饱和度双判定(深色怪物专用)

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// 抠像：use_sat_key=0 原版纯亮度抠像；=1 亮度+饱和度双判定+硬黑下限(深色怪物专用)
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float alpha;
	if (use_sat_key > 0.5) {
		// 深色怪物：亮度低 且 饱和度低才算黑背景；硬黑下限擦掉混色黑边
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
	// 用 cutout_amount 在"原 alpha"和"抠像后 alpha"间插值
	color.a *= mix(1.0, alpha, cutout_amount);
	COLOR = color;
}
