extends Control
## BattleScreen - 战斗画面主控脚本

var _monster_slots: Array = []
var _card_uis: Array = []
var top_bar: HBoxContainer
var monster_area: CenterContainer
var card_hand: HBoxContainer
var action_bar: HBoxContainer
var turn_hint: Label

func _ready() -> void:
	print("[BattleScreen] _ready called")
	# 获取节点引用
	top_bar = get_node_or_null("TopBar")
	monster_area = get_node_or_null("MonsterArea")
	card_hand = get_node_or_null("CardArea/CardHand")
	action_bar = get_node_or_null("CardArea/ActionBar")
	turn_hint = get_node_or_null("CardArea/TurnHint")
	
	# 连接EventBus
	EventBus.combat_won.connect(_on_combat_won)
	EventBus.combat_lost.connect(_on_combat_lost)
	EventBus.game_started.connect(_on_game_started)
	EventBus.screen_requested.connect(_on_screen_requested)
	EventBus.campfire_choice_made.connect(_on_campfire_choice_made)
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.delayed_reward_picked.connect(_on_delayed_reward_picked)
	EventBus.campfire_entered.connect(_on_campfire_entered)
	EventBus.sacrifice_entered.connect(_on_sacrifice_entered)
	EventBus.victory.connect(_on_victory)
	
	# 连接ActionBar信号
	if action_bar:
		action_bar.confirm_pressed.connect(_on_confirm_pressed)
		action_bar.cancel_pressed.connect(_on_cancel_pressed)
		action_bar.skip_turn_pressed.connect(_on_skip_turn)
		action_bar.sacrifice_pressed.connect(_on_sacrifice_pressed)
		action_bar.blank_convert_pressed.connect(_on_blank_convert_pressed)
		action_bar.help_pressed.connect(_on_help_pressed)

func _on_game_started() -> void:
	print("[BattleScreen] _on_game_started called, state empty: %s" % GameManager.state.is_empty())
	visible = true
	refresh_all()

func refresh_all() -> void:
	if GameManager.state.is_empty():
		push_warning("[BattleScreen] refresh_all called but state is empty!")
		return
	print("[BattleScreen] refresh_all: monsters=%d, deck=%d" % [GameManager.state.get("monsters", []).size(), GameManager.state["player"]["deck"].size()])
	print("[BattleScreen] nodes: top_bar=%s monster_area=%s card_hand=%s action_bar=%s turn_hint=%s" % [top_bar != null, monster_area != null, card_hand != null, action_bar != null, turn_hint != null])
	_refresh_top_bar()
	_refresh_monsters()
	_refresh_cards()
	_refresh_actions()

func _refresh_top_bar() -> void:
	if top_bar and top_bar.has_method("update_display"):
		top_bar.update_display()

func _refresh_monsters() -> void:
	if not monster_area:
		push_warning("[BattleScreen] monster_area is null!")
		return
	for child in monster_area.get_children():
		child.queue_free()
	_monster_slots.clear()
	
	var monsters = GameManager.state.get("monsters", [])
	var is_group = GameManager.state.get("is_group", false)
	print("[BattleScreen] _refresh_monsters: %d monsters, is_group=%s" % [monsters.size(), is_group])
	
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	monster_area.add_child(container)
	
	for i in range(monsters.size()):
		print("[BattleScreen] Creating monster slot %d: %s" % [i, monsters[i].get("name", "?")])
		var slot = _create_monster_slot(monsters[i], i, is_group)
		container.add_child(slot)
		_monster_slots.append(slot)

func _create_monster_slot(data: Dictionary, idx: int, is_group: bool) -> VBoxContainer:
	var slot = VBoxContainer.new()
	slot.set_script(load("res://scripts/ui/monster_slot.gd"))
	slot.custom_minimum_size = Vector2(120, 180)
	# 等待ready后setup（确保_build_ui已执行，子节点已创建）
	slot.ready.connect(func(): slot.setup(data, idx, is_group), CONNECT_ONE_SHOT)
	# 连接怪物点击信号
	if slot.has_signal("monster_clicked"):
		slot.monster_clicked.connect(_on_monster_clicked)
	else:
		push_warning("[BattleScreen] monster_clicked signal not found on slot!")
	return slot

func _refresh_cards() -> void:
	if not card_hand:
		push_warning("[BattleScreen] card_hand is null!")
		return
	for child in card_hand.get_children():
		child.queue_free()
	_card_uis.clear()
	
	var deck = GameManager.state["player"]["deck"]
	var phase = GameManager.state.get("phase", "battle")
	print("[BattleScreen] _refresh_cards: %d cards, phase=%s" % [deck.size(), phase])
	
	for card in deck:
		var can_play = GameManager.can_play_card(card) if phase == "battle" else true
		if phase == "sacrifice":
			can_play = GameManager.is_sacrifice_eligible(card)
		var card_ui = _create_card_ui(card, can_play)
		card_hand.add_child(card_ui)
		# setup必须在add_child后，因为需要theme
		card_ui.setup(card_ui.get_meta("card_data"), card_ui.get_meta("can_play"))
		_card_uis.append(card_ui)
	print("[BattleScreen] _refresh_cards done: %d card_uis created" % _card_uis.size())

func _create_card_ui(data: Dictionary, can_play: bool) -> Panel:
	var card = Panel.new()
	card.set_script(load("res://scripts/ui/card_ui.gd"))
	card.custom_minimum_size = Vector2(112, 150)

	# 用 VBoxContainer 布局，避免标签全部堆在左上角
	var vbox = VBoxContainer.new()
	vbox.name = "Layout"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(type_label)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.92, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 让 desc 占据中间空间，把 uses 推到底部
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	var uses_label = Label.new()
	uses_label.name = "UsesLabel"
	uses_label.add_theme_font_size_override("font_size", 11)
	uses_label.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(uses_label)

	# AOE 角标（绝对定位在卡牌右上角），不参与布局也不阻挡点击
	var aoe_badge = Label.new()
	aoe_badge.name = "AoeBadge"
	aoe_badge.add_theme_font_size_override("font_size", 8)
	aoe_badge.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	aoe_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	aoe_badge.offset_left = 70
	aoe_badge.offset_top = -2
	aoe_badge.visible = false
	aoe_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aoe_badge.z_index = 5
	card.add_child(aoe_badge)

	# 先存数据，setup在add_child后执行（需要theme可用）
	card.set_meta("card_data", data)
	card.set_meta("can_play", can_play)

	if card.has_signal("card_clicked"):
		card.card_clicked.connect(_on_card_clicked)
	else:
		push_warning("[BattleScreen] card_clicked signal not found on card!")
	if card.has_signal("card_drag_started"):
		card.card_drag_started.connect(_on_card_drag_started)
	else:
		push_warning("[BattleScreen] card_drag_started signal not found on card!")

	return card

func _refresh_actions() -> void:
	if not action_bar or not action_bar.has_method("update_for_selection"):
		push_warning("[BattleScreen] action_bar issue: %s" % action_bar)
		return
	
	var phase = GameManager.state.get("phase", "battle")
	var has_selection = GameManager.state.get("selection") != null
	print("[BattleScreen] _refresh_actions: phase=%s, has_selection=%s" % [phase, has_selection])
	action_bar.update_for_selection(has_selection, phase)
	
	if turn_hint:
		if phase == "sacrifice":
			var count = GameManager.state.get("sacrifice_selected", []).size()
			turn_hint.text = "选择献祭卡牌 (%d/2)" % count
		else:
			var s = GameManager.state
			var played = s["player"].get("played_count", 0)
			var max_plays = 1 + s["player"].get("extra_plays", 0)
			turn_hint.text = "出牌 (%d/%d)" % [played, max_plays]

# === 交互回调 ===

func _on_card_clicked(card_id: int) -> void:
	if GameManager.state.get("animating", false):
		return
	
	var phase = GameManager.state.get("phase", "battle")
	var card = GameManager._find_card(card_id)
	if card.is_empty():
		return
	
	# 献祭模式
	if phase == "sacrifice":
		_toggle_sacrifice_card(card_id)
		return
	
	if not GameManager.can_play_card(card):
		return
	
	# 点击攻击牌 → 选择第一个活着的怪
	var card_type = card.get("type", "")
	if card_type == "attack" and not card.get("aoe", false):
		# 攻击牌需要指定目标，如果已有选中且目标相同则取消
		if GameManager.state.get("selection") and GameManager.state["selection"]["card_id"] == card_id:
			GameManager.state["selection"] = null
		else:
			var target_idx = _find_first_alive_monster()
			if target_idx >= 0:
				GameManager.state["selection"] = {"card_id": card_id, "target_idx": target_idx}
	elif card_type in ["utility", "power"] or card.get("aoe", false):
		# 非攻击/AOE牌自动选第一个怪
		if GameManager.state.get("selection") and GameManager.state["selection"]["card_id"] == card_id:
			GameManager.state["selection"] = null
		else:
			var target_idx = _find_first_alive_monster()
			if target_idx >= 0:
				GameManager.state["selection"] = {"card_id": card_id, "target_idx": target_idx}
	refresh_all()

func _on_card_drag_started(card_id: int, _event: InputEvent) -> void:
	var card = GameManager._find_card(card_id)
	if card.is_empty() or not GameManager.can_play_card(card):
		return
	var target_idx = _find_first_alive_monster()
	if target_idx >= 0:
		GameManager.state["selection"] = {"card_id": card_id, "target_idx": target_idx}
	refresh_all()

func _on_monster_clicked(slot_idx: int) -> void:
	# 点击怪物 → 如果已有选中的攻击牌，更新目标
	var sel = GameManager.state.get("selection")
	if sel == null:
		return
	var card = GameManager._find_card(sel["card_id"])
	if card.is_empty():
		return
	var card_type = card.get("type", "")
	# 攻击牌可以切换目标
	if card_type == "attack" and not card.get("aoe", false):
		sel["target_idx"] = slot_idx
		refresh_all()

func _find_first_alive_monster() -> int:
	for i in range(GameManager.state.get("monsters", []).size()):
		if GameManager.state["monsters"][i]["current_hp"] > 0:
			return i
	return -1

# === 献祭模式 ===

func _toggle_sacrifice_card(card_id: int) -> void:
	var selected = GameManager.state.get("sacrifice_selected", [])
	if card_id in selected:
		selected.erase(card_id)
	else:
		if selected.size() < 2:
			selected.append(card_id)
	GameManager.state["sacrifice_selected"] = selected
	
	# 更新卡牌UI的献祭选中状态
	for card_ui in _card_uis:
		if card_ui.card_data.get("id") in selected:
			card_ui.set_sacrifice_selected(true)
		else:
			card_ui.set_sacrifice_selected(false)
	
	_refresh_actions()

func _on_sacrifice_entered() -> void:
	visible = true
	refresh_all()

func _confirm_sacrifice() -> void:
	var selected = GameManager.state.get("sacrifice_selected", [])
	if selected.size() < 2:
		return
	GameManager.perform_sacrifice(selected)
	EventBus.sfx_requested.emit("ui_click")
	EventBus.reward_shown.emit(true, false)

func _cancel_sacrifice() -> void:
	GameManager.state["phase"] = "battle"
	GameManager.state["sacrifice_selected"] = []
	refresh_all()

# === 操作按钮回调 ===

func _on_confirm_pressed() -> void:
	var phase = GameManager.state.get("phase", "battle")
	
	if phase == "sacrifice":
		_confirm_sacrifice()
		return
	
	var sel = GameManager.state.get("selection")
	if sel == null:
		return
	var card_id = sel["card_id"]
	var target_idx = sel["target_idx"]
	GameManager.state["selection"] = null
	GameManager.state["animating"] = true
	
	var card = GameManager._find_card(card_id)
	var events = GameManager.play_card(card_id, target_idx)
	if events.is_empty():
		GameManager.state["animating"] = false
		refresh_all()
		return
	
	_play_card_events(events, card)
	EventBus.sfx_requested.emit("attack" if card.get("damage", 0) > 0 else "defend")

func _on_cancel_pressed() -> void:
	var phase = GameManager.state.get("phase", "battle")
	if phase == "sacrifice":
		_cancel_sacrifice()
		return
	GameManager.state["selection"] = null
	refresh_all()

func _on_skip_turn() -> void:
	if GameManager.state.get("animating", false):
		return
	if GameManager.state.get("phase") == "sacrifice":
		_cancel_sacrifice()
		return
	GameManager.state["selection"] = null
	_do_monster_turn()

func _on_sacrifice_pressed() -> void:
	if GameManager.state.get("animating", false):
		return
	GameManager.state["phase"] = "sacrifice"
	GameManager.state["sacrifice_selected"] = []
	GameManager.state["selection"] = null
	refresh_all()

func _on_blank_convert_pressed() -> void:
	if not GameManager.perform_blank_convert():
		return
	EventBus.reward_shown.emit(false, true)

## "?" 按钮：在画面顶部弹出一段简短玩法提示，3 秒后自动消失。
func _on_help_pressed() -> void:
	EventBus.sfx_requested.emit("ui_click")
	_show_hint("点击卡牌选中 → 点怪物改目标 → 回车/确认出牌 → 空格结束回合", 3.0)

## 顶部临时提示（不依赖 turn_hint，避免被 refresh 覆盖）。
func _show_hint(text: String, duration: float = 2.5) -> void:
	var label = Label.new()
	label.name = "HintLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 8.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	add_child(label)
	var tween = label.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

func _play_card_events(events: Array, card: Dictionary) -> void:
	var delay = 0.0
	for e in events:
		match e.get("type"):
			"dmg":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_hit_animation(e["value"])
				)
				delay += 0.15
			"kill":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_death_animation()
					EventBus.sfx_requested.emit("kill")
				)
				delay += 0.1
			"heal":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("heal")
				)
				delay += 0.1
			"block":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("defend")
				)
				delay += 0.1
			"self_dmg":
				_delayed_action(delay, func():
					if top_bar and top_bar.has_method("flash_hit"):
						top_bar.flash_hit()
				)
				delay += 0.1
			"buff":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("heal")
				)
				delay += 0.1
			"double_hit":
				# 连劈标记，仅视觉反馈
				delay += 0.05
	
	_delayed_action(delay + 0.25, func():
		GameManager.state["animating"] = false
		refresh_all()
		
		if GameManager.state["player"]["hp"] <= 0:
			GameManager.save_high_score()
			EventBus.combat_lost.emit(GameManager.state["floor"])
			return
		
		if GameManager.check_combat_win():
			EventBus.combat_won.emit()
			return
		
		var max_plays = 1 + GameManager.state["player"].get("extra_plays", 0)
		if GameManager.state["player"]["played_count"] >= max_plays:
			_do_monster_turn()
	)

func _do_monster_turn() -> void:
	GameManager.state["animating"] = true
	var events = GameManager.monster_turn()
	GameManager.end_turn()
	
	var delay = 0.0
	for e in events:
		match e.get("type"):
			"monster_atk":
				_delayed_action(delay, func():
					if top_bar and top_bar.has_method("flash_hit"):
						top_bar.flash_hit()
					EventBus.sfx_requested.emit("hit")
				)
				delay += 0.15
			"debuff":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("debuff")
				)
				delay += 0.1
			"monster_def":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("defend")
				)
				delay += 0.1
	
	_delayed_action(delay + 0.2, func():
		GameManager.state["animating"] = false
		refresh_all()
		if GameManager.state["player"]["hp"] <= 0:
			GameManager.save_high_score()
			EventBus.combat_lost.emit(GameManager.state["floor"])
	)

func _delayed_action(delay: float, action: Callable) -> void:
	get_tree().create_timer(delay).timeout.connect(action)

# === EventBus 回调 ===

func _on_combat_won() -> void:
	if GameManager.state["player"].get("campfire_str_buff", 0) > 0:
		GameManager.state["player"]["campfire_str_buff"] -= 1
	GameManager.state["phase"] = "reward"
	EventBus.reward_shown.emit(false, false)

func _on_combat_lost(_floor: int) -> void:
	visible = false
	EventBus.screen_requested.emit("game_over")

func _on_victory() -> void:
	visible = false

func _on_campfire_entered() -> void:
	visible = false

func _on_campfire_choice_made(_choice_id: String) -> void:
	visible = true
	refresh_all()

func _on_reward_picked(_card_key: String, _is_sacrifice: bool, _is_blank: bool) -> void:
	visible = true
	refresh_all()

func _on_delayed_reward_picked(_reward_id: String) -> void:
	visible = true
	refresh_all()

func _on_screen_requested(screen_name: String) -> void:
	match screen_name:
		"battle":
			visible = true
			refresh_all()
		_:
			visible = false

func _input(event: InputEvent) -> void:
	if not visible or GameManager.state.is_empty():
		return
	if GameManager.state.get("animating", false):
		return
	
	# 键盘快捷键
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if GameManager.state.get("phase") == "sacrifice":
				if GameManager.state.get("sacrifice_selected", []).size() >= 2:
					_confirm_sacrifice()
			elif GameManager.state.get("selection"):
				_on_confirm_pressed()
			else:
				_on_skip_turn()
		elif event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
		elif event.keycode == KEY_SPACE:
			_on_skip_turn()
