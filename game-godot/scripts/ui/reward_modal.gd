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

func _generate_rewards() -> void:
	_reward_cards = GameManager.random_rewards(3)
	_delayed_rewards = [] if _is_sacrifice or _is_blank else GameManager.get_delayed_rewards()

func _build_ui() -> void:
	# 标题
	var title = get_node_or_null("Modal/TitleLabel") as Label
	if title:
		if _is_sacrifice:
			title.text = "献祭奖励"
		elif _is_blank:
			title.text = "空白牌兑换 (%d/2)" % [GameManager.state.get("blank_convert_count", 0) + 1]
		else:
			title.text = "选择奖励"
	
	# 卡牌选择
	var cards_container = get_node_or_null("Modal/CardsContainer") as HBoxContainer
	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()
		for reward in _reward_cards:
			var btn = _create_reward_card_btn(reward)
			cards_container.add_child(btn)
	
	# 延迟奖励
	var delayed_container = get_node_or_null("Modal/DelayedContainer") as HBoxContainer
	if delayed_container:
		for child in delayed_container.get_children():
			child.queue_free()
		if not _is_sacrifice and not _is_blank:
			for reward in _delayed_rewards:
				var btn = _create_delayed_reward_btn(reward)
				delayed_container.add_child(btn)

func _create_reward_card_btn(reward: Dictionary) -> Button:
	var btn = Button.new()
	var data = reward.get("data", {})
	btn.text = "%s\n%s\n%s" % [data.get("name", "???"), data.get("desc", ""), str(data.get("max_uses", 0)) + "次" if data.get("max_uses", 0) > 0 else ""]
	btn.custom_minimum_size = Vector2(130, 120)
	btn.add_theme_font_size_override("font_size", 12)
	
	var type_color = Color(0, 0.94, 1, 1)
	match data.get("type", "attack"):
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
