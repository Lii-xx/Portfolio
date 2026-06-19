extends VBoxContainer
## MonsterSlot - 怪物槽位脚本
## 处理怪物显示、受击动效、伤害飘字

signal monster_clicked(slot_idx: int)

var monster_data: Dictionary = {}
var slot_idx: int = 0

var sprite: TextureRect
var name_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var block_label: Label
var intent_label: Label
var boss_tag: Label
var group_tag: Label

# 着色器材质（T5：受击闪白/死亡溶解/中毒变绿）
var _hit_flash_mat: ShaderMaterial
var _dissolve_mat: ShaderMaterial
var _poison_mat: ShaderMaterial
var _is_dying: bool = false  # 死亡动画进行中，避免被 resting 覆盖

func _ready() -> void:
	_build_ui()
	_init_shader_materials()

## 初始化着色器材质（T5）
func _init_shader_materials() -> void:
	var hit_flash_shader = load("res://shaders/hit_flash.gdshader")
	if hit_flash_shader:
		_hit_flash_mat = ShaderMaterial.new()
		_hit_flash_mat.shader = hit_flash_shader
		_hit_flash_mat.set_shader_parameter("flash_intensity", 0.0)

	var dissolve_shader = load("res://shaders/dissolve.gdshader")
	if dissolve_shader:
		_dissolve_mat = ShaderMaterial.new()
		_dissolve_mat.shader = dissolve_shader
		_dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)

	var poison_shader = load("res://shaders/poison.gdshader")
	if poison_shader:
		_poison_mat = ShaderMaterial.new()
		_poison_mat.shader = poison_shader
		_poison_mat.set_shader_parameter("poison_amount", 0.0)

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
	
	# 怪物精灵
	sprite = TextureRect.new()
	sprite.name = "MonsterSprite"
	# 固定一个显示区，纹理缩放进此区域
	sprite.custom_minimum_size = Vector2(120, 140)
	# STRETCH_KEEP_ASPECT：纹理按比例缩放填满控件，不变形（多余边留透明）
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(sprite)
	
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
	
	# 格挡
	block_label = Label.new()
	block_label.name = "BlockLabel"
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", 11)
	block_label.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	add_child(block_label)
	
	# 意图
	intent_label = Label.new()
	intent_label.name = "IntentLabel"
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.add_theme_font_size_override("font_size", 13)
	add_child(intent_label)

func setup(data: Dictionary, idx: int, is_group: bool) -> void:
	monster_data = data
	slot_idx = idx
	
	name_label.text = data.get("name", "???")
	
	# 精灵图
	var sprite_idx = data.get("sprite_idx", 0)
	sprite.texture = SpriteHelper.get_monster_texture(sprite_idx)
	
	# HP
	_update_hp()
	
	# 格挡
	block_label.visible = data.get("block", 0) > 0
	block_label.text = "🛡 " + str(data.get("block", 0))
	
	# 意图
	var intent = IntentSystem.get_current_intent(data)
	intent_label.text = IntentSystem.get_intent_text(intent)
	match IntentSystem.get_intent_color_name(intent):
		"atk":
			intent_label.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
		"def":
			intent_label.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
		"debuff":
			intent_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	
	# Boss/群怪标签
	boss_tag.visible = data.get("is_boss", false)
	group_tag.visible = is_group and not data.get("is_boss", false)
	
	# 死亡状态
	if data.get("current_hp", 0) <= 0:
		modulate = Color(0.3, 0.3, 0.3, 0.25)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		modulate = Color(1, 1, 1, 1)
		mouse_filter = Control.MOUSE_FILTER_STOP

	# 重置死亡标记，应用 resting 材质（T5：中毒变绿）
	_is_dying = false
	_apply_resting_material()

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
	_play_dissolve()  # T5：死亡溶解着色器
	TweenHelpers.monster_death(self)

## 应用 resting 材质：中毒时用 poison 着色器，否则清除（T5）
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
		sprite.material = null

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
	preview.text = "+" + str(block) + "🛡"
	preview.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	preview.visible = true

## 清除预览
func clear_preview() -> void:
	var preview = get_node_or_null("DamagePreview")
	if preview:
		preview.visible = false
