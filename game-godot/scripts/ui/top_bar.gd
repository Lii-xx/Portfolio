extends HBoxContainer
## TopBar - 顶部状态栏
## 子节点由代码动态创建，因为场景中不直接定义子节点

var hp_bar: ProgressBar
var hp_text: Label
var block_val: Label
var strength_val: Label
var debuff_container: HBoxContainer
var buff_container: HBoxContainer
var floor_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build_ui()

func _build_ui() -> void:
	# HP组
	var hp_group = HBoxContainer.new()
	hp_group.add_theme_constant_override("separation", 5)
	
	var hp_label = Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_font_size_override("font_size", 9)
	hp_label.add_theme_color_override("font_color", Color(0.61, 0.56, 0.78, 1))
	hp_group.add_child(hp_label)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(130, 9)
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(1, 0.18, 0.53, 1)
	bar_fg.corner_radius_top_left = 0
	bar_fg.corner_radius_top_right = 0
	bar_fg.corner_radius_bottom_left = 0
	bar_fg.corner_radius_bottom_right = 0
	hp_bar.add_theme_stylebox_override("fill", bar_fg)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 0.18, 0.53, 0.15)
	bar_bg.border_color = Color(1, 0.18, 0.53, 1)
	bar_bg.border_width_bottom = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_left = 1
	bar_bg.border_width_right = 1
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_group.add_child(hp_bar)
	
	hp_text = Label.new()
	hp_text.add_theme_font_size_override("font_size", 18)
	hp_text.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	hp_group.add_child(hp_text)
	
	add_child(hp_group)
	
	# 格挡组
	var block_group = HBoxContainer.new()
	block_group.add_theme_constant_override("separation", 5)
	var block_label = Label.new()
	block_label.text = "🛡"
	block_label.add_theme_font_size_override("font_size", 9)
	block_group.add_child(block_label)
	block_val = Label.new()
	block_val.add_theme_font_size_override("font_size", 18)
	block_val.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	block_group.add_child(block_val)
	add_child(block_group)
	
	# 力量组
	var str_group = HBoxContainer.new()
	str_group.add_theme_constant_override("separation", 5)
	var str_label = Label.new()
	str_label.text = "💪"
	str_label.add_theme_font_size_override("font_size", 9)
	str_group.add_child(str_label)
	strength_val = Label.new()
	strength_val.add_theme_font_size_override("font_size", 18)
	strength_val.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	str_group.add_child(strength_val)
	add_child(str_group)
	
	# 减益容器
	debuff_container = HBoxContainer.new()
	debuff_container.add_theme_constant_override("separation", 4)
	add_child(debuff_container)
	
	# 增益容器
	buff_container = HBoxContainer.new()
	buff_container.add_theme_constant_override("separation", 4)
	add_child(buff_container)
	
	# 楼层（右对齐）
	floor_label = Label.new()
	floor_label.add_theme_font_size_override("font_size", 11)
	floor_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	floor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(floor_label)

func update_display() -> void:
	if GameManager.state.is_empty():
		return
	var p = GameManager.state["player"]
	
	var hp_pct = float(p["hp"]) / float(p["max_hp"]) * 100.0
	if hp_bar:
		TweenHelpers.hp_bar_smooth(hp_bar, hp_pct)
	if hp_text:
		hp_text.text = str(p["hp"]) + "/" + str(p["max_hp"])
	if block_val:
		block_val.text = str(p.get("block", 0))
	if strength_val:
		strength_val.text = str(GameManager.get_strength())
	if floor_label:
		floor_label.text = "第 " + str(GameManager.state.get("floor", 1)) + " 层"
	
	# 减益
	if debuff_container:
		for child in debuff_container.get_children():
			child.queue_free()
		for debuff in p.get("debuffs", []):
			var tag = _create_debuff_tag(debuff)
			debuff_container.add_child(tag)
	
	# 增益
	if buff_container:
		for child in buff_container.get_children():
			child.queue_free()
		if p.get("campfire_str_buff", 0) > 0:
			var tag = _create_buff_tag("🔥力量 +" + str(p["campfire_str_buff"]) + "场")
			buff_container.add_child(tag)

func _create_debuff_tag(debuff: String) -> Label:
	var label = Label.new()
	if debuff == "no_attack":
		label.text = "禁攻"
		label.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
	else:
		label.text = "禁防"
		label.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	label.add_theme_font_size_override("font_size", 10)
	return label

func _create_buff_tag(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	label.add_theme_font_size_override("font_size", 10)
	return label

func flash_hit() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
