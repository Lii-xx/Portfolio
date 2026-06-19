extends Control
## Main - 根节点脚本
## 处理全局快捷键（如 F11 切换全屏）

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F11:
				_toggle_fullscreen()
			KEY_ALT:
				# Alt+Enter 也切换全屏（常见快捷键）
				pass

## 切换窗口/全屏模式
func _toggle_fullscreen() -> void:
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("[Main] Switched to windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[Main] Switched to fullscreen mode")
