extends Node2D
## 关卡占位场景：显示视差背景，按 Esc 返回主菜单。

const MAIN_MENU := "res://main.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MAIN_MENU)
