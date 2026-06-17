class_name TweenHelpers
## Tween动效工具函数

## 卡牌悬停放大
static func card_hover(card: Control, is_hover: bool) -> void:
	var target_scale = Vector2(1.1, 1.1) if is_hover else Vector2(1.0, 1.0)
	var tween = card.create_tween()
	tween.tween_property(card, "scale", target_scale, 0.1).set_ease(Tween.EASE_OUT)

## 卡牌选中效果
static func card_selected(card: Control, is_selected: bool) -> void:
	var target_scale = Vector2(1.12, 1.12) if is_selected else Vector2(1.0, 1.0)
	var target_y = -8.0 if is_selected else 0.0
	var tween = card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", target_scale, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:y", card.position.y + target_y, 0.12).set_ease(Tween.EASE_OUT)

## 怪物受击抖动
static func monster_hit_shake(node: Control) -> void:
	var orig_x = node.position.x
	var tween = node.create_tween()
	tween.tween_property(node, "position:x", orig_x + 8, 0.04).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(node, "position:x", orig_x - 8, 0.04).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(node, "position:x", orig_x + 4, 0.04).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(node, "position:x", orig_x, 0.04).set_trans(Tween.TRANS_LINEAR)
	# 闪白
	var tween2 = node.create_tween()
	tween2.tween_property(node, "modulate", Color(2, 2, 2, 1), 0.06)
	tween2.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.09)

## 伤害飘字
static func damage_popup(parent: Control, value: int, is_heal: bool = false) -> void:
	var label = Label.new()
	label.text = ("+" if is_heal else "-") + str(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.position = Vector2(parent.size.x / 2 - 20, 15)
	label.z_index = 20
	if is_heal:
		label.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	else:
		label.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -20, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

## HP条平滑过渡
static func hp_bar_smooth(bar: ProgressBar, target_value: float, duration: float = 0.3) -> void:
	var tween = bar.create_tween()
	tween.tween_property(bar, "value", target_value, duration).set_ease(Tween.EASE_OUT)

## 怪物死亡淡出
static func monster_death(node: Control) -> void:
	var tween = node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate", Color(0.3, 0.3, 0.3, 0.25), 0.3)
	tween.tween_property(node, "modulate:a", 0.25, 0.3)

## 按钮步进hover(模拟CSS steps(4))
static func button_step_hover(btn: Button, is_hover: bool) -> void:
	var offset = Vector2(-2, -2) if is_hover else Vector2(0, 0)
	var tween = btn.create_tween()
	tween.tween_property(btn, "position", btn.position + offset, 0.05).set_trans(Tween.TRANS_LINEAR)
