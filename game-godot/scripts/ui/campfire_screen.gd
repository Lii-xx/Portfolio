extends Control
## CampfireScreen - 火堆选择画面

var _choices: Array = []

func _ready() -> void:
	print("[CampfireScreen] _ready called, connecting signals")
	EventBus.campfire_entered.connect(_on_campfire_entered)
	EventBus.screen_requested.connect(_on_screen_requested)
	_add_background()
	_add_floor_label()
	_add_title_button()
	visible = false
	print("[CampfireScreen] _ready done, visible=%s" % visible)

## 加不透明背景（对齐HTML .campfire-screen 的 rgba(13,2,33,.88)）
## 避免被下层 BattleScreen/背景图透出盖住
func _add_background() -> void:
	if has_node("Bg"):
		return
	var bg = ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.05, 0.008, 0.13, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 0)

## 右上角楼层显示（对齐 BattleScreen 的 TopBar 样式）
func _add_floor_label() -> void:
	if has_node("FloorLabel"):
		return
	var lbl = Label.new()
	lbl.name = "FloorLabel"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left = -120
	lbl.offset_right = -10
	lbl.offset_top = 8
	lbl.offset_bottom = 24
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

func _on_campfire_entered() -> void:
	print("[CampfireScreen] _on_campfire_entered CALLED, setting visible=true")
	visible = true
	_load_choices()
	_build_ui()
	_update_floor_label()
	print("[CampfireScreen] after build: visible=%s, choices=%d" % [visible, _choices.size()])

func _update_floor_label() -> void:
	var lbl = get_node_or_null("FloorLabel") as Label
	if lbl:
		lbl.text = "第 " + str(GameManager.state.get("floor", 1)) + " 层"

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
	btn.offset_top = 28
	btn.offset_right = -8
	btn.offset_bottom = 50
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_return_to_title)
	add_child(btn)

func _on_return_to_title() -> void:
	EventBus.sfx_requested.emit("ui_click")
	visible = false
	EventBus.title_requested.emit()

func _on_screen_requested(screen_name: String) -> void:
	match screen_name:
		"campfire":
			visible = true
		_:
			visible = false

func _load_choices() -> void:
	var data = JsonLoader.load_json("res://data/campfire.json")
	_choices = data.get("choices", [])

func _build_ui() -> void:
	var container = get_node_or_null("ChoicesContainer") as HBoxContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	
	for choice in _choices:
		var btn = Button.new()
		btn.icon = IconHelper.get_texture(choice["icon"])
		btn.text = choice["name"] + "\n" + choice["desc"]
		btn.custom_minimum_size = Vector2(170, 100)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
		
		var style = StyleBoxFlat.new()
		style.border_color = Color(1, 0.82, 0.25, 1)
		style.bg_color = Color(1, 0.82, 0.25, 0.08)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		
		btn.pressed.connect(_on_choice_selected.bind(choice["id"]))
		container.add_child(btn)
	
	EventBus.bgm_requested.emit("campfire")

func _on_choice_selected(choice_id: String) -> void:
	EventBus.sfx_requested.emit("ui_click")
	visible = false
	var result = GameManager.campfire_choice(choice_id)
	EventBus.campfire_choice_made.emit(choice_id)
	
	if result == "victory":
		GameManager.save_high_score()
		EventBus.victory.emit()
	else:
		EventBus.screen_requested.emit("battle")
