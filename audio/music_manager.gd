extends Node
## 全局背景音乐:主菜单与关卡共用,场景切换不中断。

const TRACK := preload("res://audio/music/underwater.ogg")
const TARGET_DB := -14.0
const FADE_TIME := 2.5

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Underwater"
	_player.stream = TRACK
	_player.volume_db = -40.0
	add_child(_player)

	var ogg := TRACK as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true

	_player.play()
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", TARGET_DB, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
