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
	var target_y = -24.0 if is_selected else 0.0
	var tween = card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", target_scale, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:y", card.position.y + target_y, 0.12).set_ease(Tween.EASE_OUT)

## 怪物受击位移（被打退 → 缓动回位，杀戮尖塔同款重量感）
## Y 轴向上弹起 20px + 轻微 X 抖动（冲击感），再缓动回位
static func monster_hit_shake(node: Control) -> void:
	var orig_x = node.position.x
	var orig_y = node.position.y
	var tween = node.create_tween()
	# 第一阶段：弹起 + 水平抖动（并行）
	tween.set_parallel(true)
	tween.tween_property(node, "position:y", orig_y - 20, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:x", orig_x + randf_range(-6, 6), 0.04).set_trans(Tween.TRANS_LINEAR)
	# 第二阶段：缓动回位（并行）
	tween.chain()
	tween.tween_property(node, "position:y", orig_y, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:x", orig_x, 0.2).set_ease(Tween.EASE_OUT)

## 怪物待机悬浮呼吸（循环）
## sprite Y 轴上下浮动，阴影联动缩小（飘起时影子变小，立体感翻倍）
## 返回 Tween 引用，调用方在死亡时 kill 避免与 dissolve 冲突
static func monster_idle_breath(sprite: Control, shadow: Control) -> Tween:
	var orig_y = sprite.position.y
	# 阴影从中心缩放（offsets 固定 90x18，pivot 设中心）
	shadow.pivot_offset = Vector2(45, 9)
	var tween = sprite.create_tween().set_loops()
	# 第一拍：上浮 + 影子缩小（并行）
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", orig_y - 4.0, 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shadow, "scale", Vector2(0.82, 0.7), 1.2).set_ease(Tween.EASE_IN_OUT)
	# 第二拍：回落 + 影子恢复（并行）
	tween.chain()
	tween.tween_property(sprite, "position:y", orig_y, 1.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shadow, "scale", Vector2(1.0, 1.0), 1.2).set_ease(Tween.EASE_IN_OUT)
	return tween

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

## 卡牌出场（从手牌飞向目标后缩小消失）
static func card_play_to_target(card: Control, target_pos: Vector2) -> void:
	var tween = card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "global_position", target_pos, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "scale", Vector2(1.2, 1.2), 0.25)
	tween.chain().tween_property(card, "scale", Vector2(0, 0), 0.15)
	# 动画末尾隐藏，避免 refresh_all 重建前的闪烁
	tween.tween_callback(func(): card.visible = false)

## 屏幕震动（重击/AOE/玩家受伤）
static func screen_shake(node: Control, intensity: float = 8.0, duration: float = 0.3) -> void:
	var orig_pos = node.position
	var tween = node.create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(node, "position", orig_pos + offset, duration / 4)
	tween.tween_property(node, "position", orig_pos, 0.05)

## 能量消耗动画（能量数字跳动）
static func energy_spend(label: Label) -> void:
	# 设置中心锚点，避免从左上角缩放
	label.pivot_offset = label.size / 2
	var tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
