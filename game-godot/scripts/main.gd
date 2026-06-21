extends Control
## Main - 根节点脚本
## 处理全局快捷键（如 F11 切换全屏）

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				_toggle_fullscreen()

## 切换窗口/全屏模式
func _toggle_fullscreen() -> void:
	# Godot 4 DisplayServer 无 FEATURE_FULLSCREEN 枚举，直接尝试切换
	# 内嵌窗口会静默忽略全屏请求，靠下方 actual_mode 验证判断是否成功
	var current_mode = DisplayServer.window_get_mode()
	var target_mode = DisplayServer.WINDOW_MODE_WINDOWED if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN

	DisplayServer.window_set_mode(target_mode)

	# 验证是否真的切换成功（嵌入式窗口会静默忽略全屏请求）
	var actual_mode = DisplayServer.window_get_mode()
	if actual_mode == target_mode:
		if actual_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			print("[Main] Switched to fullscreen mode")
		else:
			print("[Main] Switched to windowed mode")
	else:
		print("[Main] 全屏切换失败（嵌入式窗口不支持），请以独立窗口运行或导出后使用 F11")
