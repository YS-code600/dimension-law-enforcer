extends Node2D
## 坦克爆炸特效:把 boom_strip.png 横向切成 5 帧播放一次,播完自毁。

const STRIP := preload("res://levels/combat/boom_strip.png")
const FRAME_COUNT := 5
const FPS := 14.0
@export var scale_mult := 5.0


func _ready() -> void:
	z_index = 9
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Boom"
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("boom")
	frames.set_animation_speed("boom", FPS)
	frames.set_animation_loop("boom", false)

	var strip_width := float(STRIP.get_width())
	var frame_width := strip_width / float(FRAME_COUNT)
	var frame_height := float(STRIP.get_height())
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = STRIP
		atlas.region = Rect2(frame_width * float(i), 0.0, frame_width, frame_height)
		frames.add_frame("boom", atlas)

	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_mult, scale_mult)
	add_child(sprite)
	sprite.play("boom")
	sprite.animation_finished.connect(queue_free)
