shader_type canvas_item;

// 中毒变绿着色器
// 用法：怪物中毒时 poison_amount 设为 0.6 左右，呈现绿色病态
uniform float poison_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 poison_color : source_color = vec4(0.4, 1.0, 0.2, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		// 向毒色混合（最多 60%，保留原色识别度）
		vec3 poisoned = mix(color.rgb, poison_color.rgb, poison_amount * 0.6);
		COLOR = vec4(poisoned, color.a);
	}
}
