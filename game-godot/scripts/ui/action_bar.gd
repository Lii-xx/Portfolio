extends HBoxContainer
## ActionBar - 操作按钮栏
## 按钮由代码动态创建

signal confirm_pressed
signal cancel_pressed
signal skip_turn_pressed
signal sacrifice_pressed
signal blank_convert_pressed
signal help_pressed

var confirm_btn: Button
var cancel_btn: Button
var skip_btn: Button
var sacrifice_btn: Button
var blank_btn: Button
var help_btn: Button

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_init_buttons()

func _init_buttons() -> void:
	confirm_btn = _make_btn("确认出牌", "accent")
	cancel_btn = _make_btn("取消", "normal")
	skip_btn = _make_btn("结束回合", "normal")
	sacrifice_btn = _make_btn("献祭", "small")
	blank_btn = _make_btn("兑换空白牌", "small")
	help_btn = _make_btn("?", "small")
	
	confirm_btn.pressed.connect(func(): confirm_pressed.emit())
	cancel_btn.pressed.connect(func(): cancel_pressed.emit())
	skip_btn.pressed.connect(func(): skip_turn_pressed.emit())
	sacrifice_btn.pressed.connect(func(): sacrifice_pressed.emit())
	blank_btn.pressed.connect(func(): blank_convert_pressed.emit())
	help_btn.pressed.connect(func(): help_pressed.emit())

func update_for_selection(has_selection: bool, phase: String = "battle") -> void:
	for child in get_children():
		remove_child(child)
	
	if phase == "sacrifice":
		var sacrifice_count = GameManager.state.get("sacrifice_selected", []).size()
		confirm_btn.text = "确认献祭 (%d/2)" % sacrifice_count
		confirm_btn.disabled = sacrifice_count < 2
		add_child(confirm_btn)
		add_child(cancel_btn)
		return
	
	if has_selection:
		add_child(confirm_btn)
		add_child(cancel_btn)
	else:
		add_child(skip_btn)
		
		var eligible = 0
		for card in GameManager.state["player"]["deck"]:
			if GameManager.is_sacrifice_eligible(card):
				eligible += 1
		sacrifice_btn.disabled = eligible < 2
		add_child(sacrifice_btn)
		
		var blank_count = 0
		for card in GameManager.state["player"]["deck"]:
			if card.get("special") == "blank":
				blank_count += 1
		if blank_count >= 2:
			add_child(blank_btn)
		
		add_child(help_btn)

func _make_btn(text: String, style: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 32) if style != "small" else Vector2(60, 28)
	
	var is_accent = style == "accent"
	var border_color = Color(1, 0.18, 0.53, 1) if is_accent else Color(0, 1, 0.25, 1)
	var bg_color = Color(1, 0.18, 0.53, 0.15) if is_accent else Color(0, 1, 0.25, 0.08)
	var font_color = Color(1, 0.18, 0.53, 1) if is_accent else Color(0, 1, 0.25, 1)
	
	var s = StyleBoxFlat.new()
	s.border_color = border_color
	s.bg_color = bg_color
	s.border_width_bottom = 2
	s.border_width_top = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_font_size_override("font_size", 13 if style != "small" else 11)
	
	return btn
