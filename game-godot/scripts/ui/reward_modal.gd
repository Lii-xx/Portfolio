extends Control
## RewardModal - 奖励弹窗

var _is_sacrifice: bool = false
var _is_blank: bool = false
var _reward_cards: Array = []
var _delayed_rewards: Array = []

func _ready() -> void:
	visible = false
	EventBus.reward_shown.connect(_on_reward_shown)
	EventBus.screen_requested.connect(_on_screen_requested)
	_reorganize_modal_layout()

## 修复布局：PanelContainer 不正确处理多个子节点的垂直布局，
## 会导致 CardsContainer 和 DelayedContainer 重叠。
## 解决：在 Modal 内插入 VBoxContainer 来组织子节点。
func _reorganize_modal_layout() -> void:
	var modal = get_node_or_null("Modal")
	if not modal:
		return
	# 如果已经重组过，跳过
	if modal.has_node("ContentVBox"):
		return
	var title = modal.get_node_or_null("TitleLabel")
	var cards = modal.get_node_or_null("CardsContainer")
	var delayed = modal.get_node_or_null("DelayedContainer")

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 15)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.add_child(vbox)

	# 把原有子节点移到 VBox 内（保持引用路径不变）
	if title:
		modal.remove_child(title)
		vbox.add_child(title)
	if cards:
		modal.remove_child(cards)
		vbox.add_child(cards)
	if delayed:
		modal.remove_child(delayed)
		vbox.add_child(delayed)

func _on_screen_requested(screen_name: String) -> void:
	match screen_name:
		"reward":
			visible = true
		_:
			visible = false

func _on_reward_shown(is_sacrifice: bool, is_blank: bool) -> void:
	_is_sacrifice = is_sacrifice
	_is_blank = is_blank
	visible = true
	_generate_rewards()
	_build_ui()
	print("[RewardModal] shown: sacrifice=%s blank=%s cards=%d delayed=%d" % [is_sacrifice, is_blank, _reward_cards.size(), _delayed_rewards.size()])

func _generate_rewards() -> void:
	_reward_cards = GameManager.random_rewards(3)
	_delayed_rewards = [] if _is_sacrifice or _is_blank else GameManager.get_delayed_rewards()

func _build_ui() -> void:
	# 标题
	var title = get_node_or_null("Modal/ContentVBox/TitleLabel") as Label
	if title:
		if _is_sacrifice:
			title.text = "献祭奖励"
		elif _is_blank:
			title.text = "空白牌兑换 (%d/2)" % [GameManager.state.get("blank_convert_count", 0) + 1]
		else:
			title.text = "选择奖励"

	# 卡牌选择
	var cards_container = get_node_or_null("Modal/ContentVBox/CardsContainer") as HBoxContainer
	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()
		for reward in _reward_cards:
			var btn = _create_reward_card_btn(reward)
			cards_container.add_child(btn)

	# 延迟奖励
	var delayed_container = get_node_or_null("Modal/ContentVBox/DelayedContainer") as HBoxContainer
	if delayed_container:
		for child in delayed_container.get_children():
			child.queue_free()
		if not _is_sacrifice and not _is_blank:
			delayed_container.visible = true
			for reward in _delayed_rewards:
				var btn = _create_delayed_reward_btn(reward)
				delayed_container.add_child(btn)
		else:
			# 献祭/空白牌兑换时不显示延迟奖励
			delayed_container.visible = false

func _create_reward_card_btn(reward: Dictionary) -> Button:
	var btn = Button.new()
	var data = reward.get("data", {})
	var special = data.get("special", "")
	var cost = data.get("cost", 0)
	var card_type = data.get("type", "attack")
	var max_uses = data.get("max_uses", 0)

	# 类型颜色
	var type_color = Color(0, 0.94, 1, 1)
	match card_type:
		"attack": type_color = Color(1, 0.18, 0.53, 1)
		"utility": type_color = Color(0, 0.94, 1, 1)
		"power": type_color = Color(0.9, 0.72, 0, 1)
		"special": type_color = Color(0.94, 0.92, 1, 1)

	# 用空 text，内容交给自定义 VBox（图片在上，文字在下，对齐手牌 CardUI）
	btn.text = ""
	btn.custom_minimum_size = Vector2(140, 190)

	# 样式（与手牌风格一致）
	var style = StyleBoxFlat.new()
	style.border_color = type_color
	style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	# 悬停/按下时边框变青色，提示可点
	var hover_style = style.duplicate()
	hover_style.border_color = Color(0, 0.94, 1, 1)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	# VBox 布局（填满按钮内部）
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 6
	vbox.offset_top = 6
	vbox.offset_right = -6
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# 卡牌图片（与 card_ui.gd 的 art_rect 同设置：88x60，保持比例居中）
	var art_path = data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		var art_rect = TextureRect.new()
		art_rect.custom_minimum_size = Vector2(88, 60)
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_rect.texture = load(art_path)
		vbox.add_child(art_rect)

	# 能量消耗 + 类型（图标+文字）
	var cost_type_row = HBoxContainer.new()
	cost_type_row.add_theme_constant_override("separation", 2)
	cost_type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if special == "spin":
		var energy_icon = IconHelper.create_icon("energy", 10)
		cost_type_row.add_child(energy_icon)
		var x_lbl = Label.new()
		x_lbl.text = "X"
		x_lbl.add_theme_font_size_override("font_size", 9)
		x_lbl.add_theme_color_override("font_color", type_color)
		x_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_type_row.add_child(x_lbl)
	elif cost > 0:
		var energy_icon = IconHelper.create_icon("energy", 10)
		cost_type_row.add_child(energy_icon)
		var cost_lbl = Label.new()
		cost_lbl.text = str(cost)
		cost_lbl.add_theme_font_size_override("font_size", 9)
		cost_lbl.add_theme_color_override("font_color", type_color)
		cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_type_row.add_child(cost_lbl)
	var type_text_label = Label.new()
	type_text_label.text = _type_label(card_type)
	type_text_label.add_theme_font_size_override("font_size", 9)
	type_text_label.add_theme_color_override("font_color", type_color)
	type_text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_type_row.add_child(type_text_label)
	vbox.add_child(cost_type_row)

	# 卡牌名
	var name_label = Label.new()
	name_label.text = data.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = data.get("desc", "")
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.92, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# 使用次数（blank 不显示，0 次显示 ∞）
	if special != "blank":
		var uses_label = Label.new()
		uses_label.text = "∞" if max_uses == 0 else str(max_uses) + "次"
		uses_label.add_theme_font_size_override("font_size", 10)
		uses_label.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
		uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(uses_label)

	btn.pressed.connect(_on_reward_picked.bind(reward["key"]))
	return btn

## 卡牌类型中文标签（对齐HTML typeLabel）
func _type_label(card_type: String) -> String:
	match card_type:
		"attack": return "攻击"
		"utility": return "技能"
		"power": return "能力"
		"special": return "特殊"
		_: return card_type

func _create_delayed_reward_btn(reward: Dictionary) -> Button:
	var btn = Button.new()
	btn.icon = IconHelper.get_texture(reward.get("icon", ""))
	btn.text = reward.get("name", "") + "\n" + reward.get("desc", "")
	btn.custom_minimum_size = Vector2(130, 60)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	btn.pressed.connect(_on_delayed_reward_picked.bind(reward["id"]))
	return btn

func _on_reward_picked(card_key: String) -> void:
	EventBus.sfx_requested.emit("ui_click")
	GameManager.state["player"]["deck"].append(CardRegistry.make_card(card_key))
	visible = false
	EventBus.reward_picked.emit(card_key, _is_sacrifice, _is_blank)
	
	if _is_blank:
		GameManager.state["blank_convert_count"] = GameManager.state.get("blank_convert_count", 0) + 1
		if GameManager.state["blank_convert_count"] < 2:
			_on_reward_shown(false, true)
			return
		GameManager.state["blank_convert_count"] = 0
		GameManager.state["phase"] = "battle"
		EventBus.screen_requested.emit("battle")
		return
	
	if _is_sacrifice:
		GameManager.state["phase"] = "battle"
		EventBus.screen_requested.emit("battle")
		return
	
	# 正常战斗奖励 → 推进
	_advance_after_reward()

func _on_delayed_reward_picked(reward_id: String) -> void:
	EventBus.sfx_requested.emit("ui_click")
	GameManager.apply_delayed_reward(reward_id)
	visible = false
	EventBus.delayed_reward_picked.emit(reward_id)
	_advance_after_reward()

func _advance_after_reward() -> void:
	var result = GameManager.advance_floor()
	print("[RewardModal] _advance_after_reward: result=%s" % result)
	match result:
		"campfire":
			print("[RewardModal] emitting campfire_entered")
			EventBus.campfire_entered.emit()
		"victory":
			GameManager.save_high_score()
			EventBus.victory.emit()
		"battle":
			EventBus.screen_requested.emit("battle")
