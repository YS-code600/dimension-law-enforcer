extends Control
## 主菜单：开始游戏（先进开场简报）或退出。

const INTRO_SCENE := "res://intro.tscn"

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
