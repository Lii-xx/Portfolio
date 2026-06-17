extends Panel
## CardUI - 单张卡牌UI脚本
## 处理拖拽、悬停、选中动效

signal card_drag_started(card_id: int, event: InputEvent)
signal card_clicked(card_id: int)
signal card_hover_changed(card_id: int, is_hover: bool)

var card_data: Dictionary = {}
var is_selected: bool = false
var is_disabled: bool = false
var is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_threshold: float = 5.0

var type_label: Label
var name_label: Label
var desc_label: Label
var uses_label: Label
var aoe_badge: Label

var _initialized: bool = false

func _ready() -> void:
	# 创建默认面板样式
	_ensure_stylebox()

	# 确保Panel自身接收鼠标事件（子标签都设置了IGNORE，不会阻挡）
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 获取子节点引用（标签嵌套在 Layout/VBox 下）
	_resolve_labels()

	# 如果setup()之前就被调用了，重新应用
	if _initialized and not card_data.is_empty():
		_apply_visuals()

func _resolve_labels() -> void:
	# 兼容两种结构：直接子节点 / 嵌套在 Layout VBox 下
	type_label = get_node_or_null("TypeLabel")
	if type_label == null:
		type_label = get_node_or_null("Layout/TypeLabel")
	name_label = get_node_or_null("NameLabel")
	if name_label == null:
		name_label = get_node_or_null("Layout/NameLabel")
	desc_label = get_node_or_null("DescLabel")
	if desc_label == null:
		desc_label = get_node_or_null("Layout/DescLabel")
	uses_label = get_node_or_null("UsesLabel")
	if uses_label == null:
		uses_label = get_node_or_null("Layout/UsesLabel")
	aoe_badge = get_node_or_null("AoeBadge")

func _ensure_stylebox() -> void:
	# 确保有一个base stylebox，避免get_theme_stylebox报错
	var current = get_theme_stylebox("panel")
	if current == null or current is StyleBoxEmpty:
		var default_style = StyleBoxFlat.new()
		default_style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
		default_style.border_color = Color(0, 1, 0.25, 0.25)
		default_style.border_width_bottom = 2
		default_style.border_width_top = 2
		default_style.border_width_left = 2
		default_style.border_width_right = 2
		default_style.content_margin_top = 6
		default_style.content_margin_bottom = 6
		default_style.content_margin_left = 8
		default_style.content_margin_right = 8
		default_style.corner_radius_top_left = 4
		default_style.corner_radius_top_right = 4
		default_style.corner_radius_bottom_left = 4
		default_style.corner_radius_bottom_right = 4
		add_theme_stylebox_override("panel", default_style)

func setup(data: Dictionary, can_play: bool) -> void:
	card_data = data
	is_disabled = not can_play
	is_selected = false
	_initialized = true

	# 获取子节点引用（标签可能嵌套在 Layout VBox 下）
	_resolve_labels()

	_apply_visuals()

func _apply_visuals() -> void:
	if name_label:
		name_label.text = card_data.get("name", "???")
	if desc_label:
		desc_label.text = card_data.get("desc", "")
	
	var card_type = card_data.get("type", "attack")
	if type_label:
		type_label.text = _type_label(card_type)
	if card_data.get("aoe", false):
		if aoe_badge:
			aoe_badge.visible = true
			aoe_badge.text = "AOE"
		if type_label:
			type_label.text += " (全体)"
	else:
		if aoe_badge:
			aoe_badge.visible = false
	
	if uses_label:
		if card_data.get("special") != "blank" and card_data.get("max_uses", 0) > 0:
			uses_label.text = str(card_data.get("uses_left", 0)) + "/" + str(card_data.get("max_uses", 0)) + "次"
			uses_label.visible = true
		else:
			uses_label.visible = false
	
	# 颜色
	var border_color = _type_color(card_type)
	if is_selected:
		border_color = Color(0, 0.94, 1, 1)  # cyan
	_set_border_color(border_color)
	modulate.a = 0.3 if is_disabled else 1.0

func _set_border_color(color: Color) -> void:
	var style: StyleBoxFlat
	var current = get_theme_stylebox("panel")
	if current and current is StyleBoxFlat:
		style = current.duplicate()
	else:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
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
	style.border_color = color
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected
	TweenHelpers.card_selected(self, selected)

## 更新为献祭选中样式
func set_sacrifice_selected(selected: bool) -> void:
	var style: StyleBoxFlat
	var current = get_theme_stylebox("panel")
	if current and current is StyleBoxFlat:
		style = current.duplicate()
	else:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
	if selected:
		style.border_color = Color(1, 0.82, 0.25, 1)
		style.bg_color = Color(1, 0.82, 0.25, 0.15)
		modulate.a = 1.0
	else:
		style.border_color = _type_color(card_data.get("type", "attack"))
		style.bg_color = Color(0.12, 0.06, 0.29, 0.92)
		modulate.a = 0.3 if is_disabled else 1.0
	add_theme_stylebox_override("panel", style)

func _type_label(type: String) -> String:
	match type:
		"attack": return "ATK"
		"utility": return "UTIL"
		"power": return "PWR"
		"special": return "SPC"
		_: return type.to_upper()

func _type_color(type: String) -> Color:
	match type:
		"attack": return Color(1, 0.18, 0.53, 1)   # --atk #ff2e88
		"utility": return Color(0, 0.94, 1, 1)      # --def #00f0ff
		"power": return Color(0.9, 0.72, 0, 1)       # #e6b800
		"special": return Color(0.94, 0.92, 1, 1)    # --spc
		_: return Color(0, 1, 0.25, 0.25)            # --border

func _gui_input(event: InputEvent) -> void:
	if is_disabled:
		return
	
	# 献祭模式下点击切换选中
	if GameManager.state.get("phase") == "sacrifice":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			card_clicked.emit(card_data["id"])
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start_pos = event.global_position
			is_dragging = false
		elif not is_dragging:
			card_clicked.emit(card_data["id"])
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var dist = event.global_position.distance_to(_drag_start_pos)
		if dist > _drag_threshold and not is_dragging:
			is_dragging = true
			card_drag_started.emit(card_data["id"], event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		if not is_disabled:
			TweenHelpers.card_hover(self, true)
			card_hover_changed.emit(card_data.get("id", -1), true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		TweenHelpers.card_hover(self, false)
		card_hover_changed.emit(card_data.get("id", -1), false)
