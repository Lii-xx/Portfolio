extends Node
class_name IconHelper
## 图标纹理统一加载/缓存
## SVG 图标位于 res://assets/icons/，所有平台（含Web）显示一致

static var _cache: Dictionary = {}

## 中文图标名 → SVG 文件名映射
## 兼容 campfire.json / delayed rewards 的 "icon" 字段（如 "血""力"）
const ICON_NAME_MAP := {
	"盾": "shield",
	"力": "strength",
	"火": "fire",
	"刺": "thorn",
	"能": "energy",
	"毒": "poison",
	"血": "heart",
	"攻": "attack",
	"咒": "curse",
}

## 获取图标纹理（带缓存）
static func get_texture(icon_name: String) -> Texture2D:
	var svg_name = ICON_NAME_MAP.get(icon_name, icon_name)
	if _cache.has(svg_name):
		return _cache[svg_name]
	var path = "res://assets/icons/%s.svg" % svg_name
	if not ResourceLoader.exists(path):
		push_warning("[IconHelper] 图标未找到: " + path)
		return null
	var tex = load(path)
	_cache[svg_name] = tex
	return tex

## 创建图标 TextureRect（指定尺寸，默认16x16）
static func create_icon(icon_name: String, size: int = 16) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = get_texture(icon_name)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

## 创建"图标+数值"的 HBoxContainer
## 例: create_icon_value("盾", "5") → [🛡 5]
static func create_icon_value(icon_name: String, value_text: String, icon_size: int = 14, font_size: int = 11, color: Color = Color(0.94, 0.92, 1, 1)) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	var icon = create_icon(icon_name, icon_size)
	hbox.add_child(icon)
	var label = Label.new()
	label.text = value_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)
	return hbox
