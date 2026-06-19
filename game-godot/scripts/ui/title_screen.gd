extends Control
## TitleScreen - 标题画面

func _ready() -> void:
	print("[TitleScreen] _ready called")
	_update_high_score()
	# 标题页BGM
	EventBus.bgm_requested.emit("title")
	EventBus.title_requested.connect(_on_title_requested)
	EventBus.game_started.connect(_on_game_started)
	EventBus.screen_requested.connect(_on_screen_requested)
	
	# 连接按钮信号
	var start_btn = get_node_or_null("StartButton")
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	var help_btn = get_node_or_null("HelpButton")
	if help_btn:
		help_btn.pressed.connect(_on_help_pressed)

func _on_start_pressed() -> void:
	EventBus.sfx_requested.emit("ui_click")
	GameManager.start_game()
	EventBus.game_started.emit()
	visible = false

func _on_help_pressed() -> void:
	EventBus.sfx_requested.emit("ui_click")
	# 显示简短玩法说明
	var help_btn = get_node_or_null("HelpButton")
	if help_btn:
		help_btn.text = "拖牌→怪 | 回车确认 | 空格跳过"
		get_tree().create_timer(3.0).timeout.connect(func():
			if help_btn: help_btn.text = "玩法说明"
		)

func _update_high_score() -> void:
	var label = get_node_or_null("HighScoreLabel")
	if label:
		var hs = GameManager.get_high_score()
		label.text = "最高通关层数: " + str(hs) if hs > 0 else ""

func _on_game_started() -> void:
	visible = false

func _on_title_requested() -> void:
	visible = true
	_update_high_score()
	# 返回标题页BGM
	EventBus.bgm_requested.emit("title")

func _on_screen_requested(screen_name: String) -> void:
	match screen_name:
		"title":
			visible = true
			_update_high_score()
		_:
			visible = false
