extends AnimatedSprite2D
## 命中火花:播放一次后自毁。


func _ready() -> void:
	animation_finished.connect(queue_free)
	play(&"hit_fx")
