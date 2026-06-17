extends Control
## CampfireScreen - 火堆选择画面

var _choices: Array = []

func _ready() -> void:
	EventBus.campfire_entered.connect(_on_campfire_entered)
	EventBus.screen_requested.connect(_on_screen_requested)
	visible = false

func _on_campfire_entered() -> void:
	visible = true
	_load_choices()
	_build_ui()

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
		btn.text = choice["icon"] + " " + choice["name"] + "\n" + choice["desc"]
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
