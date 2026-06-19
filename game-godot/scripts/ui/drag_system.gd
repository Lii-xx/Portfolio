extends Control
## DragSystem - 拖拽系统（独立模块）
## 对齐HTML的Drag对象（line 918-1058）
## 职责：
##   - 创建跟随鼠标的卡牌ghost
##   - 检测鼠标悬停在哪个怪物上（hitTest）
##   - 悬停高亮 + 伤害预览
##   - 拖拽结束时通知调用方（target_idx=-1 表示没拖到怪物）
##
## 用法：
##   drag_system.start_drag(card_id, card_data, monster_slots)
##   drag_system.drag_completed.connect(_on_drag_completed)

signal drag_completed(card_id: int, target_idx: int)

var _is_dragging: bool = false
var _card_id: int = -1
var _card_data: Dictionary = {}
var _monster_slots: Array = []  # MonsterSlot 节点数组
var _ghost: Panel = null
var _current_hover_idx: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100  # 确保ghost在最上层

## 开始拖拽
func start_drag(card_id: int, card_data: Dictionary, monster_slots: Array) -> void:
	_is_dragging = true
	_card_id = card_id
	_card_data = card_data
	_monster_slots = monster_slots
	_current_hover_idx = -1
	_create_ghost()
	# 取消之前的选择
	GameManager.state["selection"] = null

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return

	if event is InputEventMouseMotion:
		_update_ghost_position(event.global_position)
		_update_hover(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.global_position)

## 更新ghost位置
func _update_ghost_pos(pos: Vector2) -> void:
	if _ghost:
		_ghost.global_position = pos - Vector2(39, 52)  # 居中（ghost尺寸78x104的一半）

func _update_ghost_position(pos: Vector2) -> void:
	_update_ghost_pos(pos)

## 检测鼠标悬停在哪个怪物上
func _hit_test(pos: Vector2) -> int:
	for i in range(_monster_slots.size()):
		var slot = _monster_slots[i]
		if not is_instance_valid(slot):
			continue
		# 跳过死亡怪物
		if slot.monster_data.get("current_hp", 0) <= 0:
			continue
		var rect = slot.get_global_rect()
		if rect.has_point(pos):
			return i
	return -1

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	var new_idx = _hit_test(pos)
	if new_idx == _current_hover_idx:
		return
	# 清除旧悬停
	_clear_hover()
	_current_hover_idx = new_idx
	if new_idx >= 0:
		var slot = _monster_slots[new_idx]
		if is_instance_valid(slot):
			slot.set_drop_hover(true)
			_show_preview(new_idx)

## 清除悬停高亮
func _clear_hover() -> void:
	if _current_hover_idx >= 0 and _current_hover_idx < _monster_slots.size():
		var slot = _monster_slots[_current_hover_idx]
		if is_instance_valid(slot):
			slot.set_drop_hover(false)
	_current_hover_idx = -1

## 显示伤害预览
func _show_preview(idx: int) -> void:
	# 阶段1：简单实现，在怪物slot上显示伤害预览
	# 后续可扩展为独立的预览UI
	var slot = _monster_slots[idx]
	if not is_instance_valid(slot):
		return
	var card = _card_data
	var dmg = 0
	if card.get("special") == "spin":
		dmg = card.get("damage", 0) * GameManager.state["player"].get("energy", 0) + GameManager.get_strength()
	elif card.get("damage", 0) > 0:
		dmg = card.get("damage", 0) + GameManager.get_strength()
	if dmg > 0:
		slot.show_damage_preview(dmg, card.get("aoe", false))
	elif card.get("block", 0) > 0:
		slot.show_block_preview(card.get("block", 0))

## 结束拖拽
func _end_drag(pos: Vector2) -> void:
	var target_idx = _hit_test(pos)
	_clear_hover()
	_remove_ghost()
	_is_dragging = false
	var card_id = _card_id
	_card_id = -1
	_card_data = {}
	_monster_slots = []
	drag_completed.emit(card_id, target_idx)

## 创建ghost（跟随鼠标的卡牌幻影）
func _create_ghost() -> void:
	_remove_ghost()
	_ghost = Panel.new()
	_ghost.custom_minimum_size = Vector2(78, 104)  # 缩小到约70%，避免比怪物还大
	_ghost.modulate.a = 0.75
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 101

	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
	var border_color = _type_color(_card_data.get("type", "attack"))
	style.border_color = border_color
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_ghost.add_theme_stylebox_override("panel", style)

	# 内容
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.add_child(vbox)

	var type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost = _card_data.get("cost", 0)
	var cost_prefix = ""
	if _card_data.get("special") == "spin":
		cost_prefix = "⚡X "
	elif cost > 0:
		cost_prefix = "⚡" + str(cost) + " "
	type_label.text = cost_prefix + _card_data.get("type", "attack").to_upper()
	vbox.add_child(type_label)

	var name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.text = _card_data.get("name", "???")
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.92, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = _card_data.get("desc", "")
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	add_child(_ghost)
	_update_ghost_pos(get_global_mouse_position())

## 移除ghost
func _remove_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _type_color(type: String) -> Color:
	match type:
		"attack": return Color(1, 0.18, 0.53, 1)
		"utility": return Color(0, 0.94, 1, 1)
		"power": return Color(0.9, 0.72, 0, 1)
		"special": return Color(0.94, 0.92, 1, 1)
		_: return Color(0, 1, 0.25, 0.25)

## 是否正在拖拽
func is_dragging() -> bool:
	return _is_dragging
