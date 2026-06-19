shader_type canvas_item;

// 受击闪白着色器（参考美术开发大纲 5.4 节）
// 用法：设置 flash_intensity 0→1→0 实现闪白脉冲
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// 闪白：将原色向 flash_color 混合，保留原 alpha
	COLOR = vec4(mix(color.rgb, flash_color.rgb, flash_intensity), color.a);
}
