extends Control
## EndScreen - 结算画面（战败/通关共用）

var _is_victory: bool = false

func _ready() -> void:
	visible = false
	EventBus.combat_lost.connect(_on_combat_lost)
	EventBus.victory.connect(_on_victory)
	EventBus.screen_requested.connect(_on_screen_requested)
	
	# 连接按钮信号
	var restart_btn = get_node_or_null("RestartButton")
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	var title_btn = get_node_or_null("TitleButton")
	if title_btn:
		title_btn.pressed.connect(_on_title_pressed)

func _on_combat_lost(floor: int) -> void:
	_is_victory = false
	visible = true
	var title_label = get_node_or_null("TitleLabel")
	if title_label:
		title_label.text = "战败"
		title_label.add_theme_color_override("font_color", Color(1, 0.18, 0.53, 1))
	var info_label = get_node_or_null("InfoLabel")
	if info_label:
		info_label.text = "你倒在了第 %d 层" % floor

func _on_victory() -> void:
	_is_victory = true
	visible = true
	# 通关BGM
	EventBus.bgm_requested.emit("victory")
	var title_label = get_node_or_null("TitleLabel")
	if title_label:
		title_label.text = "通关!"
		title_label.add_theme_color_override("font_color", Color(1, 0.82, 0.25, 1))
	var info_label = get_node_or_null("InfoLabel")
	if info_label:
		info_label.text = "你击败了所有怪物！"

func _on_screen_requested(screen_name: String) -> void:
	match screen_name:
		"game_over":
			visible = true
		"title":
			visible = false
		_:
			if not _is_victory:
				visible = false

func _on_restart_pressed() -> void:
	EventBus.sfx_requested.emit("ui_click")
	visible = false
	GameManager.start_game()
	EventBus.game_started.emit()

func _on_title_pressed() -> void:
	EventBus.sfx_requested.emit("ui_click")
	visible = false
	EventBus.title_requested.emit()
