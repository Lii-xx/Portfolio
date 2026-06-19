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
	var aoe = data.get("aoe", false)
	var max_uses = data.get("max_uses", 0)

	# 第一行：能量消耗 + 类型 + (全体)标记（对齐HTML）
	var cost_str = ""
	if special == "spin":
		cost_str = "⚡X "
	elif cost > 0:
		cost_str = "⚡" + str(cost) + " "
	var aoe_str = " (全体)" if aoe else ""
	var type_line = cost_str + _type_label(card_type) + aoe_str

	# 使用次数行（blank不显示，0次显示∞）
	var uses_line = ""
	if special != "blank":
		uses_line = "\n" + ("∞" if max_uses == 0 else str(max_uses) + "次")

	btn.text = "%s\n%s\n%s%s" % [type_line, data.get("name", "???"), data.get("desc", ""), uses_line]
	btn.custom_minimum_size = Vector2(140, 150)
	btn.add_theme_font_size_override("font_size", 11)

	var type_color = Color(0, 0.94, 1, 1)
	match card_type:
		"attack": type_color = Color(1, 0.18, 0.53, 1)
		"utility": type_color = Color(0, 0.94, 1, 1)
		"power": type_color = Color(0.9, 0.72, 0, 1)
		"special": type_color = Color(0.94, 0.92, 1, 1)
	btn.add_theme_color_override("font_color", type_color)

	var style = StyleBoxFlat.new()
	style.border_color = type_color
	style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)

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
	btn.text = reward.get("icon", "") + " " + reward.get("name", "") + "\n" + reward.get("desc", "")
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
	match result:
		"campfire":
			EventBus.campfire_entered.emit()
		"victory":
			GameManager.save_high_score()
			EventBus.victory.emit()
		"battle":
			EventBus.screen_requested.emit("battle")
