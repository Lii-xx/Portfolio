extends HBoxContainer
## TopBar - 顶部状态栏
## 子节点由代码动态创建，因为场景中不直接定义子节点
## 力量？号按钮：点击显示力量来源详情（对齐HTML showStrengthDetail）
## 护甲：鼠标悬停显示护甲来源详情（对齐HTML showBlockDetail）

var hp_bar: ProgressBar
var hp_text: Label
var block_val: Label
var block_group: HBoxContainer  # 护甲组（用于鼠标悬停）
var strength_val: Label
var str_help_btn: Button        # 力量？号按钮
var debuff_container: HBoxContainer
var buff_container: HBoxContainer
var floor_label: Label

var _str_detail_panel: PanelContainer  # 力量详情面板（toggle）
var _block_detail_panel: PanelContainer  # 护甲详情面板（hover）

var _shield_mat: ShaderMaterial  # T5：护盾光环着色器材质
var _prev_block: int = 0  # T5：上一帧格挡值，用于检测增加触发脉冲

func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build_ui()
	_init_shield_material()
	# T5：监听玩家获得格挡信号，触发护盾光环脉冲
	EventBus.player_block_gained.connect(_on_player_block_gained)

## 初始化护盾着色器材质（T5）
func _init_shield_material() -> void:
	var shield_shader = load("res://shaders/shield.gdshader")
	if not shield_shader:
		return
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = shield_shader
	_shield_mat.set_shader_parameter("shield_intensity", 0.0)
	# 应用到格挡数值标签（block_val 在 _build_ui 中创建）
	if block_val:
		block_val.material = _shield_mat

## 玩家获得格挡：触发护盾光环脉冲（T5）
func _on_player_block_gained(_amount: int) -> void:
	_play_shield_pulse()

## 护盾光环脉冲：0→1→0.3（脉冲后保持轻微发光，表示有护盾）
func _play_shield_pulse() -> void:
	if not _shield_mat:
		return
	var tween = create_tween()
	tween.tween_property(_shield_mat, "shader_parameter/shield_intensity", 1.0, 0.1)
	tween.tween_property(_shield_mat, "shader_parameter/shield_intensity", 0.3, 0.3)

func _build_ui() -> void:
	# HP组
	var hp_group = HBoxContainer.new()
	hp_group.add_theme_constant_override("separation", 5)

	var hp_label = Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_font_size_override("font_size", 9)
	hp_label.add_theme_color_override("font_color", Color(0.61, 0.56, 0.78, 1))
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_group.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(130, 9)
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.show_percentage = false
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	hp_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_group.add_child(hp_text)

	add_child(hp_group)

	# 格挡组（鼠标悬停显示详情，对齐HTML）
	block_group = HBoxContainer.new()
	block_group.add_theme_constant_override("separation", 5)
	block_group.mouse_filter = Control.MOUSE_FILTER_STOP
	var block_icon = IconHelper.create_icon("shield", 14)
	block_group.add_child(block_icon)
	block_val = Label.new()
	block_val.add_theme_font_size_override("font_size", 18)
	block_val.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	block_group.add_child(block_val)
	# 鼠标悬停显示护甲来源
	block_group.mouse_entered.connect(_show_block_detail)
	block_group.mouse_exited.connect(_hide_block_detail)
	add_child(block_group)

	# 力量组（带？号按钮，对齐HTML）
	var str_group = HBoxContainer.new()
	str_group.add_theme_constant_override("separation", 5)
	var str_icon = IconHelper.create_icon("strength", 14)
	str_group.add_child(str_icon)
	strength_val = Label.new()
	strength_val.add_theme_font_size_override("font_size", 18)
	strength_val.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	str_group.add_child(strength_val)
	# 力量？号按钮
	str_help_btn = Button.new()
	str_help_btn.text = "?"
	str_help_btn.custom_minimum_size = Vector2(24, 24)
	str_help_btn.add_theme_font_size_override("font_size", 11)
	str_help_btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	# normal 样式：透明背景，只保留"？"文字（去掉圆形/椭圆背景）
	var help_normal = StyleBoxFlat.new()
	help_normal.bg_color = Color(0, 0, 0, 0)
	help_normal.border_width_bottom = 0
	help_normal.border_width_top = 0
	help_normal.border_width_left = 0
	help_normal.border_width_right = 0
	# hover/pressed 样式：青色半透明背景 + 青色边框（悬停反馈）
	var help_hover = StyleBoxFlat.new()
	help_hover.bg_color = Color(0, 0.94, 1, 0.15)
	help_hover.border_color = Color(0, 0.94, 1, 1)
	help_hover.border_width_bottom = 1
	help_hover.border_width_top = 1
	help_hover.border_width_left = 1
	help_hover.border_width_right = 1
	help_hover.corner_radius_top_left = 12
	help_hover.corner_radius_top_right = 12
	help_hover.corner_radius_bottom_left = 12
	help_hover.corner_radius_bottom_right = 12
	str_help_btn.add_theme_stylebox_override("normal", help_normal)
	str_help_btn.add_theme_stylebox_override("hover", help_hover)
	str_help_btn.add_theme_stylebox_override("pressed", help_hover)
	str_help_btn.add_theme_stylebox_override("focus", help_normal)
	str_help_btn.add_theme_stylebox_override("disabled", help_normal)
	str_help_btn.focus_mode = Control.FOCUS_NONE
	str_help_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	str_help_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	str_help_btn.pressed.connect(_toggle_strength_detail)
	str_group.add_child(str_help_btn)
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
		var cur_block: int = p.get("block", 0)
		block_val.text = str(cur_block)
		# T5：格挡增加时触发护盾光环脉冲；格挡归零时关闭发光
		if _shield_mat:
			if cur_block > _prev_block:
				_play_shield_pulse()
			elif cur_block == 0:
				_shield_mat.set_shader_parameter("shield_intensity", 0.0)
		_prev_block = cur_block
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
			var tag = _create_buff_tag_with_icon("fire", "力量 +" + str(p["campfire_str_buff"]) + "场")
			buff_container.add_child(tag)
		# 荆棘反伤显示
		if p.get("thorn_buff", 0) > 0:
			var thorn_tag = _create_buff_tag_with_icon("thorn", "荆棘 +" + str(p["thorn_buff"]))
			buff_container.add_child(thorn_tag)

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

## 创建带图标的增益标签
func _create_buff_tag_with_icon(icon_name: String, text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	var icon = IconHelper.create_icon(icon_name, 12)
	hbox.add_child(icon)
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	label.add_theme_font_size_override("font_size", 10)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(label)
	return hbox

func flash_hit() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

## 力量？号按钮：toggle显示/隐藏力量来源详情（对齐HTML showStrengthDetail）
func _toggle_strength_detail() -> void:
	if _str_detail_panel and is_instance_valid(_str_detail_panel):
		_str_detail_panel.queue_free()
		_str_detail_panel = null
		return
	if GameManager.state.is_empty():
		return
	var p = GameManager.state["player"]
	var perm = p.get("perm_strength", 0)
	var temp = p.get("temp_strength", 0)
	var campfire = GameManager.CAMPFIRE_STR_BONUS if p.get("campfire_str_buff", 0) > 0 else 0
	var total = GameManager.get_strength()

	_str_detail_panel = _create_detail_panel("力量来源", [
		["永久力量", str(perm)],
		["临时力量（本关）", str(temp)],
		["火堆力量（剩余%d场）" % p.get("campfire_str_buff", 0), str(campfire)],
		["合计", str(total)],
	], Color(0, 0.94, 1, 1), "strength")
	_str_detail_panel.set_as_top_level(true)
	# 定位到？号按钮下方
	var btn_rect = str_help_btn.get_global_rect()
	_str_detail_panel.position = Vector2(btn_rect.position.x - 80, btn_rect.end.y + 6)
	add_child(_str_detail_panel)

## 护甲鼠标悬停：显示护甲来源详情（对齐HTML showBlockDetail）
func _show_block_detail() -> void:
	if _block_detail_panel and is_instance_valid(_block_detail_panel):
		return
	if GameManager.state.is_empty():
		return
	var p = GameManager.state["player"]
	var card_block = p.get("card_block_this_turn", 0)
	var delayed_block = p.get("delayed_block_buff", 0)
	var dice_block = p.get("dice_block_buff", 0)
	var current = p.get("block", 0)

	_block_detail_panel = _create_detail_panel("护甲来源", [
		["卡牌格挡", str(card_block)],
		["延迟奖励（每回合）", str(delayed_block)],
		["骰子效果（每回合）", str(dice_block)],
		["当前合计", str(current)],
	], Color(0, 0.94, 1, 1), "shield")
	_block_detail_panel.set_as_top_level(true)
	# 定位到护甲组下方
	var block_rect = block_group.get_global_rect()
	_block_detail_panel.position = Vector2(block_rect.position.x - 40, block_rect.end.y + 6)
	add_child(_block_detail_panel)

## 鼠标离开护甲：隐藏护甲详情
func _hide_block_detail() -> void:
	if _block_detail_panel and is_instance_valid(_block_detail_panel):
		_block_detail_panel.queue_free()
		_block_detail_panel = null

## 创建详情面板（通用）
func _create_detail_panel(title_text: String, rows: Array, accent_color: Color, icon_name: String = "") -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.18, 0.97)
	style.border_color = accent_color
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 标题（支持前置图标）
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	if icon_name != "":
		var title_icon = IconHelper.create_icon(icon_name, 14)
		title_row.add_child(title_icon)
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", accent_color)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title)
	vbox.add_child(title_row)

	# 数据行
	for row in rows:
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 12)
		var label = Label.new()
		label.text = row[0]
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85, 1))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(label)
		var val = Label.new()
		val.text = row[1]
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", accent_color)
		row_hbox.add_child(val)
		vbox.add_child(row_hbox)

	return panel
