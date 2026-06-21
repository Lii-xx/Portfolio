extends VBoxContainer
## MonsterSlot - 怪物槽位脚本
## 处理怪物显示、受击动效、伤害飘字

signal monster_clicked(slot_idx: int)

var monster_data: Dictionary = {}
var slot_idx: int = 0

var sprite: TextureRect
# sprite 包装层：sprite 在 wrap 内浮动，shadow 锚定 wrap 底部
# 这样 sprite 上下浮动时 shadow 不跟着飘，实现"飘起影子缩小"的阴影联动
var sprite_wrap: Control
var name_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var block_label: HBoxContainer  # 盾图标+数值容器
var _block_text: Label
var poison_label: HBoxContainer  # 毒图标+数值容器
var _poison_text: Label
var intent_label: HBoxContainer  # 意图图标+数值容器
var _intent_text: Label
var boss_tag: Label
var group_tag: Label

# 着色器材质（T5：受击闪白/死亡溶解/中毒变绿）
var _hit_flash_mat: ShaderMaterial
var _dissolve_mat: ShaderMaterial
var _poison_mat: ShaderMaterial
# 去黑底基础材质：无特效时挂这个（替代原来的 material = null），
# 让待机怪物也有去黑底效果，材质切换时不闪烁
var _base_mat: ShaderMaterial
# 悬浮阴影节点（在怪物脚下，给"站立感"）
# 用 TextureRect + GradientTexture2D 做椭圆，纯 Control 体系，跟 sprite 布局兼容
var _shadow_rect: TextureRect
var _is_dying: bool = false  # 死亡动画进行中，避免被 resting 覆盖
# 待机呼吸 Tween（循环），死亡时 kill 避免与 dissolve 冲突
var _breath_tween: Tween

func _ready() -> void:
	_build_ui()
	_init_shader_materials()

## 初始化着色器材质（T5 + 去黑底）
func _init_shader_materials() -> void:
	# 去黑底通用参数（所有材质统一，切换时不闪烁）
	var cutout_params = {
		"cutout_amount": 0.85,
		"threshold": 0.12,
		"feather": 0.08,
	}

	# 基础材质：仅去黑底（无特效时挂这个）
	var base_shader = load("res://shaders/monster_base.gdshader")
	if base_shader:
		_base_mat = ShaderMaterial.new()
		_base_mat.shader = base_shader
		for k in cutout_params:
			_base_mat.set_shader_parameter(k, cutout_params[k])

	var hit_flash_shader = load("res://shaders/hit_flash.gdshader")
	if hit_flash_shader:
		_hit_flash_mat = ShaderMaterial.new()
		_hit_flash_mat.shader = hit_flash_shader
		_hit_flash_mat.set_shader_parameter("flash_intensity", 0.0)
		for k in cutout_params:
			_hit_flash_mat.set_shader_parameter(k, cutout_params[k])

	var dissolve_shader = load("res://shaders/dissolve.gdshader")
	if dissolve_shader:
		_dissolve_mat = ShaderMaterial.new()
		_dissolve_mat.shader = dissolve_shader
		_dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
		for k in cutout_params:
			_dissolve_mat.set_shader_parameter(k, cutout_params[k])

	var poison_shader = load("res://shaders/poison.gdshader")
	if poison_shader:
		_poison_mat = ShaderMaterial.new()
		_poison_mat.shader = poison_shader
		_poison_mat.set_shader_parameter("poison_amount", 0.0)
		for k in cutout_params:
			_poison_mat.set_shader_parameter(k, cutout_params[k])

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)
	
	# Boss/群怪标签行
	var tag_row = HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 4)
	boss_tag = Label.new()
	boss_tag.name = "BossTag"
	boss_tag.text = "BOSS"
	boss_tag.add_theme_font_size_override("font_size", 10)
	boss_tag.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	boss_tag.visible = false
	tag_row.add_child(boss_tag)
	group_tag = Label.new()
	group_tag.name = "GroupTag"
	group_tag.text = "群"
	group_tag.add_theme_font_size_override("font_size", 10)
	group_tag.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	group_tag.visible = false
	tag_row.add_child(group_tag)
	add_child(tag_row)
	
	# 怪物精灵包装层（固定 170x200 显示区，VBox 居中）
	sprite_wrap = Control.new()
	sprite_wrap.name = "SpriteWrap"
	sprite_wrap.custom_minimum_size = Vector2(170, 200)
	sprite_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(sprite_wrap)

	# 怪物精灵（填满 wrap，呼吸时在 wrap 内 Y 轴浮动）
	sprite = TextureRect.new()
	sprite.name = "MonsterSprite"
	# STRETCH_KEEP_ASPECT：纹理按比例缩放填满控件，不变形（多余边留透明）
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_wrap.add_child(sprite)
	# 怪物脚下加椭圆阴影（杀戮尖塔同款"站立感"）
	_create_shadow()
	
	# 怪物名字
	name_label = Label.new()
	name_label.name = "MonsterName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.92, 1, 1))
	add_child(name_label)
	
	# HP容器
	var hp_container = HBoxContainer.new()
	hp_container.name = "HpContainer"
	hp_container.add_theme_constant_override("separation", 4)
	hp_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	hp_bar = ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.custom_minimum_size = Vector2(80, 8)
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(1, 0.18, 0.53, 1)
	hp_bar.add_theme_stylebox_override("fill", bar_fg)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 0.18, 0.53, 0.15)
	bar_bg.border_color = Color(1, 0.18, 0.53, 1)
	bar_bg.border_width_bottom = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_left = 1
	bar_bg.border_width_right = 1
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_container.add_child(hp_bar)
	
	hp_text = Label.new()
	hp_text.name = "HpText"
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	hp_container.add_child(hp_text)
	add_child(hp_container)
	
	# 格挡（图标+数值）
	block_label = HBoxContainer.new()
	block_label.name = "BlockLabel"
	block_label.alignment = BoxContainer.ALIGNMENT_CENTER
	block_label.add_theme_constant_override("separation", 2)
	var block_icon = IconHelper.create_icon("shield", 12)
	block_label.add_child(block_icon)
	_block_text = Label.new()
	_block_text.add_theme_font_size_override("font_size", 11)
	_block_text.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	_block_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	block_label.add_child(_block_text)
	add_child(block_label)

	# 中毒描述（图标+数值，紫色）
	poison_label = HBoxContainer.new()
	poison_label.name = "PoisonLabel"
	poison_label.alignment = BoxContainer.ALIGNMENT_CENTER
	poison_label.add_theme_constant_override("separation", 2)
	var poison_icon = IconHelper.create_icon("poison", 12)
	poison_label.add_child(poison_icon)
	_poison_text = Label.new()
	_poison_text.add_theme_font_size_override("font_size", 11)
	_poison_text.add_theme_color_override("font_color", Color(0.706, 0.29, 1.0, 1))
	_poison_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	poison_label.add_child(_poison_text)
	poison_label.visible = false
	add_child(poison_label)
	
	# 意图（图标+数值，setup时动态填充）
	intent_label = HBoxContainer.new()
	intent_label.name = "IntentLabel"
	intent_label.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_label.add_theme_constant_override("separation", 2)
	add_child(intent_label)

## 创建怪物脚下椭圆阴影（杀戮尖塔同款"站立感"）
## 纯代码生成 GradientTexture2D 径向渐变，无外部资源
## 阴影作为 sprite 子节点，用 anchors 锚定在 sprite 底部中央
func _create_shadow() -> void:
	_shadow_rect = TextureRect.new()
	_shadow_rect.name = "MonsterShadow"
	_shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 不让 texture 控制大小，用 anchors+offsets 固定椭圆尺寸
	_shadow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow_rect.stretch_mode = TextureRect.STRETCH_SCALE

	# 径向渐变椭圆：中心半透明黑 → 边缘透明
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)  # 圆心在中心
	tex.fill_to = Vector2(1.0, 0.5)    # 半径到右边缘
	var grad = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.45))  # 中心 45% 黑
	grad.set_color(1, Color(0, 0, 0, 0))     # 边缘透明
	tex.gradient = grad
	_shadow_rect.texture = tex

	# 锚点：wrap 底部中央。offsets 决定椭圆尺寸（90x18）
	# 阴影挂在 wrap（非 sprite）上，sprite 浮动时 shadow 不跟着飘 → 阴影联动基础
	# 阴影大部分露出在 sprite 下方，小部分被怪物遮住（自然过渡）
	_shadow_rect.anchor_left = 0.5
	_shadow_rect.anchor_top = 1.0
	_shadow_rect.anchor_right = 0.5
	_shadow_rect.anchor_bottom = 1.0
	_shadow_rect.offset_left = -45
	_shadow_rect.offset_top = -4
	_shadow_rect.offset_right = 45
	_shadow_rect.offset_bottom = 14
	# 从中心缩放（呼吸时影子缩小用），offsets 固定 90x18 → 中心 (45, 9)
	_shadow_rect.pivot_offset = Vector2(45, 9)

	sprite_wrap.add_child(_shadow_rect)

func setup(data: Dictionary, idx: int, is_group: bool) -> void:
	monster_data = data
	slot_idx = idx
	
	name_label.text = data.get("name", "???")
	
	# 精灵图
	var sprite_idx = data.get("sprite_idx", 0)
	sprite.texture = SpriteHelper.get_monster_texture(sprite_idx)
	# 深色怪物（暗影巨龙、深渊领主）启用饱和度抠像，避免本体被误擦；其他怪物用原版亮度抠像
	var use_sat = 1.0 if sprite_idx in [8, 9] else 0.0
	if _base_mat: _base_mat.set_shader_parameter("use_sat_key", use_sat)
	if _hit_flash_mat: _hit_flash_mat.set_shader_parameter("use_sat_key", use_sat)
	if _dissolve_mat: _dissolve_mat.set_shader_parameter("use_sat_key", use_sat)
	if _poison_mat: _poison_mat.set_shader_parameter("use_sat_key", use_sat)
	
	# HP
	_update_hp()
	
	# 格挡
	block_label.visible = data.get("block", 0) > 0
	_block_text.text = str(data.get("block", 0))

	# 中毒描述
	var poison_stacks = data.get("poison", 0)
	poison_label.visible = poison_stacks > 0
	_poison_text.text = str(poison_stacks) + "/回合"

	# 意图（图标+数值，每次setup重建子节点）
	for child in intent_label.get_children():
		child.queue_free()
	var intent = IntentSystem.get_current_intent(data)
	var intent_icon_name = IntentSystem.get_intent_icon(intent)
	if intent_icon_name != "":
		var intent_icon = IconHelper.create_icon(intent_icon_name, 14)
		intent_label.add_child(intent_icon)
	_intent_text = Label.new()
	_intent_text.text = IntentSystem.get_intent_value_text(intent)
	_intent_text.add_theme_font_size_override("font_size", 13)
	_intent_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match IntentSystem.get_intent_color_name(intent):
		"atk":
			_intent_text.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
		"def":
			_intent_text.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
		"debuff":
			_intent_text.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	intent_label.add_child(_intent_text)
	
	# Boss/群怪标签（群怪标签已移除，不再显示"群"字）
	boss_tag.visible = data.get("is_boss", false)
	group_tag.visible = false
	
	# 死亡状态：直接隐藏整个槽位（避免 HP/意图消失但模型残留的显示异常）
	if data.get("current_hp", 0) <= 0:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		visible = true
		modulate = Color(1, 1, 1, 1)
		mouse_filter = Control.MOUSE_FILTER_STOP

	# 重置死亡标记，应用 resting 材质（T5：中毒变绿）
	_is_dying = false
	_apply_resting_material()
	# 待机呼吸：活体怪物启动悬浮动画，死亡怪物停止
	if data.get("current_hp", 0) > 0:
		_start_idle_breath()
	else:
		_stop_idle_breath()

func _update_hp() -> void:
	var current = monster_data.get("current_hp", 0)
	var max_hp = monster_data.get("hp", 1)
	hp_bar.value = float(current) / float(max_hp) * 100.0
	hp_text.text = str(current) + "/" + str(max_hp)

## 播放受击动画
func play_hit_animation(damage: int) -> void:
	TweenHelpers.monster_hit_shake(self)
	TweenHelpers.damage_popup(self, damage, false)
	_update_hp()
	_play_hit_flash()  # T5：受击闪白着色器

## 播放治疗动画
func play_heal_animation(amount: int) -> void:
	TweenHelpers.damage_popup(self, amount, true)
	_update_hp()

## 播放死亡动画
func play_death_animation() -> void:
	_is_dying = true
	_stop_idle_breath()  # 停止呼吸，避免与 dissolve 冲突
	_play_dissolve()  # T5：死亡溶解着色器
	TweenHelpers.monster_death(self)

## 应用 resting 材质：中毒时用 poison 着色器，否则挂 base（去黑底）（T5 + 去黑底）
func _apply_resting_material() -> void:
	if _is_dying:
		return  # 死亡动画进行中，不覆盖 dissolve 材质
	if not sprite:
		return
	var poison_stacks = monster_data.get("poison", 0)
	if poison_stacks > 0 and _poison_mat:
		sprite.material = _poison_mat
		# 中毒层数越高，绿色越深（0.4~0.8）
		var amount = clampf(float(poison_stacks) / 10.0, 0.4, 0.8)
		_poison_mat.set_shader_parameter("poison_amount", amount)
	else:
		# 待机状态挂去黑底基础材质（替代原来的 material = null）
		sprite.material = _base_mat

## 受击闪白：临时切到 hit_flash 材质，脉冲后恢复 resting（T5）
func _play_hit_flash() -> void:
	if not _hit_flash_mat or not sprite:
		return
	# 死亡中不再触发闪白
	if _is_dying:
		return
	sprite.material = _hit_flash_mat
	_hit_flash_mat.set_shader_parameter("flash_intensity", 0.0)
	var tween = create_tween()
	# 峰值 0.7，避免与 monster_hit_shake 的 modulate 闪白叠加过曝
	tween.tween_property(_hit_flash_mat, "shader_parameter/flash_intensity", 0.7, 0.05)
	tween.tween_property(_hit_flash_mat, "shader_parameter/flash_intensity", 0.0, 0.12)
	# 闪白结束后恢复 resting 材质
	tween.tween_callback(_apply_resting_material)

## 死亡溶解：切到 dissolve 材质，dissolve_amount 0→1（T5）
func _play_dissolve() -> void:
	if not _dissolve_mat or not sprite:
		return
	sprite.material = _dissolve_mat
	_dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
	var tween = create_tween()
	tween.tween_property(_dissolve_mat, "shader_parameter/dissolve_amount", 1.0, 0.4)

## 启动待机悬浮呼吸（活体怪物）
func _start_idle_breath() -> void:
	_stop_idle_breath()
	if not sprite or not _shadow_rect:
		return
	_breath_tween = TweenHelpers.monster_idle_breath(sprite, _shadow_rect)

## 停止待机呼吸，重置 sprite 位置与 shadow 缩放
func _stop_idle_breath() -> void:
	if _breath_tween:
		_breath_tween.kill()
		_breath_tween = null
	if sprite:
		sprite.position = Vector2.ZERO
	if _shadow_rect:
		_shadow_rect.scale = Vector2.ONE

## 点击怪物 → 设为目标
func _gui_input(event: InputEvent) -> void:
	if monster_data.get("current_hp", 0) <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		monster_clicked.emit(slot_idx)

## 拖拽悬停高亮（被DragSystem调用）
func set_drop_hover(enabled: bool) -> void:
	if enabled:
		modulate = Color(1.2, 1.2, 1.2, 1)  # 变亮
	else:
		modulate = Color(1, 1, 1, 1)

## 显示伤害预览（被DragSystem调用）
func show_damage_preview(dmg: int, is_aoe: bool) -> void:
	var preview = get_node_or_null("DamagePreview")
	if not preview:
		preview = Label.new()
		preview.name = "DamagePreview"
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.add_theme_font_size_override("font_size", 16)
		preview.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
		preview.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		preview.add_theme_constant_override("shadow_offset_x", 1)
		preview.add_theme_constant_override("shadow_offset_y", 1)
		preview.z_index = 10
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(preview)
	preview.text = ("全体 -" if is_aoe else "-") + str(dmg)
	preview.visible = true

## 显示格挡预览（被DragSystem调用）
func show_block_preview(block: int) -> void:
	var preview = get_node_or_null("DamagePreview")
	if not preview:
		preview = Label.new()
		preview.name = "DamagePreview"
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.add_theme_font_size_override("font_size", 16)
		preview.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		preview.add_theme_constant_override("shadow_offset_x", 1)
		preview.add_theme_constant_override("shadow_offset_y", 1)
		preview.z_index = 10
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(preview)
	preview.text = "+" + str(block) + "盾"
	preview.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	preview.visible = true

## 清除预览
func clear_preview() -> void:
	var preview = get_node_or_null("DamagePreview")
	if preview:
		preview.visible = false
