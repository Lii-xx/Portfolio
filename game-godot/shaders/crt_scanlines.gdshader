shader_type canvas_item;

// CRT扫描线+径向暗角效果（叠加暗化模式）
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float scanline_density = 3.0;

void fragment() {
	// 扫描线暗化量
	float scanline = sin(UV.y * SCREEN_PIXEL_SIZE.y * scanline_density * 3.14159) * 0.5 + 0.5;
	scanline = pow(scanline, 1.5);
	float scanline_dark = (1.0 - scanline) * scanline_strength;
	
	// 径向暗角暗化量
	vec2 uv_center = UV - vec2(0.5);
	float vignette = 1.0 - dot(uv_center, uv_center) * 2.0;
	vignette = clamp(vignette, 0.0, 1.0);
	vignette = pow(vignette, 0.8);
	float vignette_dark = (1.0 - vignette) * vignette_strength;
	
	// 输出半透明黑色叠加层：仅在暗化区域可见
	float darkness = clamp(scanline_dark + vignette_dark, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
