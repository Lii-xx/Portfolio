shader_type canvas_item;

// 护盾光环着色器（应用到格挡数值标签）
// 用法：玩家获得格挡时，shield_intensity 脉冲 0→1→0.3，呈现青色光环
uniform float shield_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shield_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		// 向护盾色混合（轻度染色，避免完全变色）
		vec3 shielded = mix(color.rgb, shield_color.rgb, shield_intensity * 0.45);
		// 发光增强：在原亮度上叠加护盾光
		float glow = shield_intensity * 0.4;
		COLOR = vec4(shielded + glow, color.a);
	}
}
