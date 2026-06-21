extends Control
## BattleScreen - 战斗画面主控脚本
## 出牌交互（对齐HTML）：
##   - utility/power/AOE 牌：点击选中（自动选第一个活着的怪）
##   - 单体攻击牌：拖拽到怪物上才能选中
##   - 选中后点"确认出牌"执行

var _monster_slots: Array = []
var _card_uis: Array = []
var top_bar: HBoxContainer
var monster_area: CenterContainer
var card_hand: HBoxContainer
var action_bar: HBoxContainer
var turn_hint: Label
var _drag_system: Control  # DragSystem 节点
var _prev_energy: int = -1  # 记录上一次能量值，用于检测能量减少触发跳动

func _ready() -> void:
	print("[BattleScreen] _ready called")
	# 获取节点引用
	top_bar = get_node_or_null("TopBar")
	monster_area = get_node_or_null("MonsterArea")
	card_hand = get_node_or_null("CardArea/CardHand")
	action_bar = get_node_or_null("CardArea/ActionBar")
	turn_hint = get_node_or_null("CardArea/TurnHint")

	# 给卡牌区域添加深色不透明背景 + 顶部青色横线（对齐HTML .card-area 样式）
	_add_card_area_background()

	# 把 CardHand 包到 ScrollContainer 中，实现水平滚动（对齐HTML）
	# 卡牌数量多时可以左右滑动查看，不会挤压下方按钮
	if card_hand and card_hand.get_parent():
		var card_area = card_hand.get_parent()
		var scroll = ScrollContainer.new()
		scroll.name = "CardScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 150)
		var hand_idx = card_hand.get_index()
		card_area.remove_child(card_hand)
		scroll.add_child(card_hand)
		card_area.add_child(scroll)
		card_area.move_child(scroll, hand_idx)
		# CardHand 在 ScrollContainer 内不扩展，保持卡牌原始尺寸
		card_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# 方案B：顶部对齐 + 关闭 ScrollContainer 裁剪，让卡牌选中上抬时可超出框线
		card_hand.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		scroll.clip_contents = false

	# 创建DragSystem子节点（拖拽系统）
	_drag_system = Control.new()
	_drag_system.set_script(load("res://scripts/ui/drag_system.gd"))
	_drag_system.name = "DragSystem"
	add_child(_drag_system)
	_drag_system.drag_completed.connect(_on_drag_completed)

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
		action_bar.restart_pressed.connect(_on_restart_pressed)

	# 左上角返回标题按钮
	_add_title_button()

## 右上角返回标题按钮（楼层显示下方）
func _add_title_button() -> void:
	if has_node("TitleButton"):
		return
	var btn = Button.new()
	btn.name = "TitleButton"
	btn.text = "主菜单"
	btn.add_theme_font_size_override("font_size", 11)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -78
	btn.offset_top = 36
	btn.offset_right = -8
	btn.offset_bottom = 58
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_return_to_title)
	add_child(btn)

func _on_return_to_title() -> void:
	EventBus.sfx_requested.emit("ui_click")
	visible = false
	EventBus.title_requested.emit()

func _on_game_started() -> void:
	print("[BattleScreen] _on_game_started called, state empty: %s" % GameManager.state.is_empty())
	visible = true
	# 进入战斗BGM（refresh_all会根据是否BOSS切换为boss BGM）
	EventBus.bgm_requested.emit("battle")
	refresh_all()

## 给卡牌区域添加深色不透明背景 + 顶部青色横线（对齐HTML .card-area 样式）
## 背景插入到 CardArea 之前，不阻挡鼠标事件
func _add_card_area_background() -> void:
	var card_area = get_node_or_null("CardArea")
	if not card_area:
		return
	# 避免重复添加
	if has_node("CardAreaBg"):
		return

	# 深色不透明背景
	var bg = ColorRect.new()
	bg.name = "CardAreaBg"
	bg.color = Color(0.05, 0.01, 0.13, 1)  # #0d0221 深紫黑色，完全不透明
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.anchor_top = 1.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = -230.0
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 插入到 CardArea 之前（这样 CardArea 显示在背景之上）
	var card_area_idx = card_area.get_index()
	add_child(bg)
	move_child(bg, card_area_idx)

	# 顶部青色横线（2px）
	var line = ColorRect.new()
	line.name = "CardAreaLine"
	line.color = Color(0, 0.94, 1, 1)  # #00f0ff 青色
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.anchor_right = 1.0
	line.offset_bottom = 2.0
	line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(line)

func refresh_all() -> void:
	if GameManager.state.is_empty():
		push_warning("[BattleScreen] refresh_all called but state is empty!")
		return
	print("[BattleScreen] refresh_all: monsters=%d, deck=%d" % [GameManager.state.get("monsters", []).size(), GameManager.state["player"]["deck"].size()])
	print("[BattleScreen] nodes: top_bar=%s monster_area=%s card_hand=%s action_bar=%s turn_hint=%s" % [top_bar != null, monster_area != null, card_hand != null, action_bar != null, turn_hint != null])
	# BGM切换：有BOSS时播放boss BGM，否则播放battle BGM（SoundManager会跳过相同BGM）
	var has_boss = false
	for m in GameManager.state.get("monsters", []):
		if m.get("is_boss", false):
			has_boss = true
			break
	EventBus.bgm_requested.emit("boss" if has_boss else "battle")
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

	# 当前选中的卡牌ID（用于重建后恢复选中态）
	var sel = GameManager.state.get("selection")
	var selected_card_id = -1
	if sel and sel is Dictionary:
		selected_card_id = sel.get("card_id", -1)

	for card in deck:
		var can_play = GameManager.can_play_card(card) if phase == "battle" else true
		if phase == "sacrifice":
			can_play = GameManager.is_sacrifice_eligible(card)
		var card_ui = _create_card_ui(card, can_play)
		card_hand.add_child(card_ui)
		# setup必须在add_child后，因为需要theme
		card_ui.setup(card_ui.get_meta("card_data"), card_ui.get_meta("can_play"))
		# 选中态：根据 selection 恢复选中卡牌的上抬效果
		if card.get("id", -1) == selected_card_id:
			card_ui.set_selected(true)
		_card_uis.append(card_ui)
	print("[BattleScreen] _refresh_cards done: %d card_uis created" % _card_uis.size())

func _create_card_ui(data: Dictionary, can_play: bool) -> Panel:
	var card = Panel.new()
	card.set_script(load("res://scripts/ui/card_ui.gd"))
	card.custom_minimum_size = Vector2(96, 140)

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
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.92, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 让 desc 占据中间空间，把 uses 推到底部
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	var uses_label = Label.new()
	uses_label.name = "UsesLabel"
	uses_label.add_theme_font_size_override("font_size", 10)
	uses_label.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
	uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(uses_label)

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
	action_bar.update_for_selection(has_selection, phase)

	if turn_hint:
		if phase == "sacrifice":
			var count = GameManager.state.get("sacrifice_selected", []).size()
			turn_hint.text = "选择献祭卡牌 (%d/2)" % count
		else:
			# 显示能量（对齐HTML：能energy/maxEnergy）
			var p = GameManager.state["player"]
			var energy = p.get("energy", 0)
			var max_energy = p.get("max_energy", 2)
			turn_hint.text = "出牌 (能量 %d/%d)" % [energy, max_energy]
			# 能量减少时触发跳动
			if _prev_energy >= 0 and energy < _prev_energy:
				TweenHelpers.energy_spend(turn_hint)
			_prev_energy = energy

# === 交互回调 ===

## 点击卡牌（仅 utility/power/AOE 牌会触发）
func _on_card_clicked(card_id: int) -> void:
	if GameManager.state.get("animating", false):
		return
	if _drag_system and _drag_system.is_dragging():
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

	# 点击选中：切换选中状态，自动选第一个活着的怪作为目标
	if GameManager.state.get("selection") and GameManager.state["selection"]["card_id"] == card_id:
		GameManager.state["selection"] = null
	else:
		var target_idx = _find_first_alive_monster()
		if target_idx >= 0:
			GameManager.state["selection"] = {"card_id": card_id, "target_idx": target_idx}
	refresh_all()

## 拖拽开始（单体攻击牌拖拽到怪物）
func _on_card_drag_started(card_id: int) -> void:
	if GameManager.state.get("animating", false):
		return
	var card = GameManager._find_card(card_id)
	if card.is_empty() or not GameManager.can_play_card(card):
		return
	# 启动DragSystem（不调用refresh_all，避免销毁怪物槽位导致拖拽命中检测失效）
	_drag_system.start_drag(card_id, card, _monster_slots)

## 拖拽完成（DragSystem回调）
func _on_drag_completed(card_id: int, target_idx: int) -> void:
	if target_idx >= 0:
		# 拖到怪物上 → 设置selection
		GameManager.state["selection"] = {"card_id": card_id, "target_idx": target_idx}
	else:
		# 没拖到怪物 → 取消selection
		GameManager.state["selection"] = null
	refresh_all()

## 点击怪物（保留：可切换攻击牌目标，辅助操作）
func _on_monster_clicked(slot_idx: int) -> void:
	var sel = GameManager.state.get("selection")
	if sel == null:
		return
	var card = GameManager._find_card(sel["card_id"])
	if card.is_empty():
		return
	# 攻击牌可以切换目标
	if card.get("type") == "attack" and not card.get("aoe", false):
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
	# ui_click音效已在ActionBar确认按钮中触发
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
	
	# 出牌飞行动画：找到对应 card_ui，飞向目标怪物槽位
	var played_animation = false
	for card_ui in _card_uis:
		if card_ui.card_data.get("id") == card_id:
			if target_idx >= 0 and target_idx < _monster_slots.size():
				var target_pos = _monster_slots[target_idx].global_position + Vector2(60, 90)
				card_ui.play_card_animation(target_pos)
				played_animation = true
			break
	
	# 等待飞行动画播完再播放战斗事件（避免 refresh_all 重建打断动画）
	if played_animation:
		await get_tree().create_timer(0.4).timeout
	
	_play_card_events(events, card)
	# 出牌音效已在 GameManager.play_card 中触发（card_play）
	# 攻击命中/格挡等音效在 _play_card_events 中按事件触发

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

## "重新开始本关"按钮：读档回到关卡初始状态
func _on_restart_pressed() -> void:
	if GameManager.state.get("animating", false):
		return
	# 取消正在进行的拖拽
	if _drag_system and _drag_system.has_method("cancel_drag"):
		_drag_system.cancel_drag()
	# 读档：将快照深拷贝回 state
	if not GameManager.load_snapshot():
		return
	print("[BattleScreen] 重新开始本关，读档成功")
	refresh_all()

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

## "?" 按钮：显示完整玩法说明弹窗（对齐HTML helpModal）
func _on_help_pressed() -> void:
	# ui_click音效已在ActionBar按钮中触发
	_show_help_modal()

## 玩法说明弹窗（对齐HTML helpModal内容）
func _show_help_modal() -> void:
	# 避免重复打开
	if has_node("HelpModalOverlay"):
		return

	# 半透明背景遮罩
	var overlay = ColorRect.new()
	overlay.name = "HelpModalOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 弹窗面板
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 480)
	panel.position = -panel.custom_minimum_size / 2
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.04, 0.18, 0.96)
	panel_style.border_color = Color(0, 0.94, 1, 1)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	# 内容 VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "玩法说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	vbox.add_child(title)

	# 滚动内容区
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# 玩法说明内容（对齐HTML）
	var sections = [
		["基础规则", "每回合2点能量，拖动卡牌到怪物身上出牌，确认后自动结束回合。"],
		["卡牌类型", "攻击 — 造成伤害（含AOE、吸血等）\n防御 — 获得格挡\n能力 — 永久效果（打出后移除）\n特殊 — 空白牌"],
		["能量", "每回合恢复2点能量，每张牌消耗对应能量（卡牌左上角能数字）"],
		["群怪", "每第3场战斗为群怪，AOE对全体生效"],
		["出牌", "拖动卡牌到怪物 → 显示预览伤害 → 点击确认 → 自动结束回合\n重新拖动另一张牌取消上次选择"],
		["火堆", "每3层后出现：恢复20HP / 3场战斗+3力量"],
		["献祭", "选2张剩余次数≥3的牌献祭，3选1新牌"],
		["特殊牌", "空白牌 — 2张兑换2次卡牌奖励，额外+1永久力量"],
		["延迟奖励", "战斗胜利后可选择代替卡牌：每回合开始+2格挡 或 +1永久力量"],
		["能力牌", "每张牌每关使用一次，可抓多张叠加效果\n盾反 — 回合结束对随机敌人造成格挡一半的伤害\n露出獠牙 — 每次造成伤害获得1点力量\n吸欧气 — 骰子1-3概率降低，4-6概率增加(多张叠加)"],
		["X费牌", "旋斩 — 消耗全部能量，对全体造成4×X伤害(X=消耗能量)"],
		["骰子牌", "骰子 — 1费，掷骰子1-6：\n①力量+1 ②每回合+2防御（当回合也加） ③对随机敌人造成4点伤害2次 ④随机敌人中毒6/回合 ⑤+6格挡+6荆棘 ⑥对全体造成6×2伤害+6防御"],
		["特殊攻击", "渴血 — 2费，造成10伤害，力量≥5时回复实际造成的伤害"],
		["新增技能牌", "播毒 — 1费，对所有敌人造成3/回合中毒，5次\n荆棘护甲 — 1费，获得4格挡，本关受击反伤4（可叠加），5次\n命运轮盘 — 1费，掷骰：奇数对随机敌人造成3×点数伤害；偶数获得点数×2格挡，5次（不受吸欧气影响）"],
	]

	for section in sections:
		var header = Label.new()
		header.text = section[0]
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0, 1, 0.25, 1))
		content.add_child(header)

		var body = Label.new()
		body.text = section[1]
		body.add_theme_font_size_override("font_size", 11)
		body.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85, 1))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(body)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0.94, 1, 0.15)
	btn_style.border_color = Color(0, 0.94, 1, 1)
	btn_style.border_width_bottom = 2
	btn_style.border_width_top = 2
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	close_btn.pressed.connect(_close_help_modal.bind(overlay))
	vbox.add_child(close_btn)

## 关闭玩法说明弹窗
func _close_help_modal(overlay: ColorRect) -> void:
	overlay.queue_free()

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
	# AOE/重击 → 屏幕震动
	if card.get("aoe", false):
		TweenHelpers.screen_shake(self, 10.0, 0.3)
	var delay = 0.0
	# AOE卡牌用重击音效，单体用命中音效
	var hit_sfx = "attack_heavy" if card.get("aoe", false) else "attack_hit"
	for e in events:
		match e.get("type"):
			"dmg":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_hit_animation(e["value"])
					EventBus.sfx_requested.emit(hit_sfx)
				)
				delay += 0.15
			"kill":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_death_animation()
					EventBus.sfx_requested.emit("monster_die")
				)
				delay += 0.1
			"heal":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("heal")
				)
				delay += 0.1
			"block":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("block")
				)
				delay += 0.1
			"self_dmg":
				_delayed_action(delay, func():
					if top_bar and top_bar.has_method("flash_hit"):
						top_bar.flash_hit()
				)
				delay += 0.1
			"buff":
				# 增益音效已在各效果脚本中触发（如 strength_effect.gd）
				delay += 0.1
			"double_hit":
				# 连劈标记，仅视觉反馈
				delay += 0.05
			"dice":
				# 骰子/命运轮盘：播放滚动动画（对齐HTML _playDiceAnimation）
				var roll_val = e["value"]
				var card_special = card.get("special", "")
				_delayed_action(delay, func():
					_play_dice_animation(roll_val, card_special)
				)
				delay += 3.7  # 骰子动画总时长（滚动约2.5秒 + 停留1.2秒）
	
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

		# 回合只能由玩家点击"结束回合"按钮手动结束
		# （无论能量是否用完，都不自动进入怪物回合）
	)

## 骰子滚动动画（对齐HTML _playDiceAnimation）
## 全屏遮罩 + 骰子框 + 18步滚动（逐渐变慢）+ 显示点数和效果说明
func _play_dice_animation(roll: int, card_special: String) -> void:
	# 创建全屏遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0.05, 0.01, 0.13, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 垂直居中容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	overlay.add_child(vbox)

	# 骰子框（120x120，显示数字）
	var dice_box = Panel.new()
	dice_box.custom_minimum_size = Vector2(120, 120)
	dice_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.12, 0.06, 0.29, 1)
	box_style.border_color = Color(1, 0.82, 0.25, 1)
	box_style.border_width_bottom = 3
	box_style.border_width_top = 3
	box_style.border_width_left = 3
	box_style.border_width_right = 3
	box_style.corner_radius_top_left = 8
	box_style.corner_radius_top_right = 8
	box_style.corner_radius_bottom_left = 8
	box_style.corner_radius_bottom_right = 8
	dice_box.add_theme_stylebox_override("panel", box_style)
	vbox.add_child(dice_box)

	# 骰子数字标签
	var dice_label = Label.new()
	dice_label.text = "?"
	dice_label.add_theme_font_size_override("font_size", 48)
	dice_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	dice_box.add_child(dice_label)

	# 结果说明标签
	var result_label = Label.new()
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_label)

	# 播放滚动动画：25步，从快到慢（刺激感），总时长约2.5秒
	var tween = create_tween()
	var total_steps = 25
	for i in range(total_steps):
		var step_delay = 0.035 + (i + 1) * 0.005
		tween.tween_interval(step_delay)
		tween.tween_callback(func(): dice_label.text = str(randi() % 6 + 1))

	# 显示最终点数和效果说明
	var desc = _get_dice_desc(roll, card_special)
	tween.tween_callback(func():
		dice_label.text = str(roll)
		result_label.text = "掷出 %d：%s" % [roll, desc]
	)

	# 停留1.2秒后消失
	tween.tween_interval(1.2)
	tween.tween_callback(overlay.queue_free)

## 获取骰子点数对应的效果说明
func _get_dice_desc(roll: int, card_special: String) -> String:
	if card_special == "fate_wheel":
		if roll % 2 == 1:
			return "对随机敌人造成%d伤害" % (3 * roll)
		else:
			return "获得%d格挡" % (roll * 2)
	match roll:
		1: return "力量+1"
		2: return "每回合+2防御（当回合+2格挡）"
		3: return "对随机敌人4点×2连击"
		4: return "中毒6/回合"
		5: return "+6格挡，+6荆棘"
		6: return "对全体造成6×2伤害+6防御"
		_: return ""

func _do_monster_turn() -> void:
	GameManager.state["animating"] = true
	# 流程对齐HTML：1.end_turn(恢复能量+盾反) → 2.monster_turn → 3.start_turn(清格挡)
	var shield_events = GameManager.end_turn()
	var events = GameManager.monster_turn()

	var delay = 0.0
	# 播放盾反事件
	for e in shield_events:
		match e.get("type"):
			"dmg":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_hit_animation(e["value"])
					EventBus.sfx_requested.emit("attack_hit")
				)
				delay += 0.15
			"kill":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_death_animation()
					EventBus.sfx_requested.emit("monster_die")
				)
				delay += 0.1

	# 播放怪物行动事件
	for e in events:
		match e.get("type"):
			"monster_atk":
				_delayed_action(delay, func():
					if top_bar and top_bar.has_method("flash_hit"):
						top_bar.flash_hit()
					TweenHelpers.screen_shake(self, 6.0, 0.2)
					EventBus.sfx_requested.emit("player_hurt")
				)
				delay += 0.15
			"thorn_dmg":
				var idx = e["idx"]
				var val = e["value"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_hit_animation(val)
					EventBus.sfx_requested.emit("attack_hit")
				)
				delay += 0.15
			"poison_dmg":
				var idx = e["idx"]
				var val = e["value"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_hit_animation(val)
					EventBus.sfx_requested.emit("poison")
				)
				delay += 0.15
			"kill":
				var idx = e["idx"]
				_delayed_action(delay, func():
					if idx < _monster_slots.size():
						_monster_slots[idx].play_death_animation()
					EventBus.sfx_requested.emit("monster_die")
				)
				delay += 0.1
			"debuff":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("debuff")
				)
				delay += 0.1
			"monster_def":
				_delayed_action(delay, func():
					EventBus.sfx_requested.emit("block")
				)
				delay += 0.1

	_delayed_action(delay + 0.2, func():
		GameManager.start_turn()  # 清格挡、应用延迟奖励
		GameManager.state["animating"] = false
		refresh_all()
		if GameManager.state["player"]["hp"] <= 0:
			GameManager.save_high_score()
			EventBus.combat_lost.emit(GameManager.state["floor"])
			return
		if GameManager.check_combat_win():
			EventBus.combat_won.emit()
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
	print("[BattleScreen] _on_campfire_entered CALLED, setting visible=false")
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
		elif event.keycode == KEY_K:
			# 调试：秒杀所有活着的怪物（方便测试）
			_debug_kill_all_monsters()

## 调试：秒杀所有活着的怪物
func _debug_kill_all_monsters() -> void:
	if GameManager.state.get("phase") != "battle":
		return
	for m in GameManager.state.get("monsters", []):
		m["current_hp"] = 0
	print("[BattleScreen] DEBUG: killed all monsters")
	refresh_all()
	if GameManager.check_combat_win():
		EventBus.combat_won.emit()
