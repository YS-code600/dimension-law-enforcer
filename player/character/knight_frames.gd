extends RefCounted
## 从 Knight 素材条切帧,构建主角「骑士剑技」形态的 SpriteFrames。
## 缺失的跳跃/落地/受击等动作复用现有帧,保证动画名与原形态完全一致。

const FRAME := 64

const SHEET_IDLE := preload("res://player/character/knight/knight_idle.png")
const SHEET_RUN := preload("res://player/character/knight/knight_run.png")
const SHEET_ATTACK1 := preload("res://player/character/knight/knight_attack01.png")
const SHEET_ATTACK2 := preload("res://player/character/knight/knight_attack02.png")
const SHEET_HURT := preload("res://player/character/knight/knight_hurt.png")
const SHEET_DEATH := preload("res://player/character/knight/knight_death.png")

const SLASH_LIGHT := preload("res://player/character/knight/knight_effect_attack01.png")
const SLASH_HEAVY := preload("res://player/character/knight/knight_effect_attack02.png")


static func build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	_strip(sf, &"idle", SHEET_IDLE, 6, 8.0, true)
	_strip(sf, &"walk", SHEET_RUN, 8, 8.0, true)
	_strip(sf, &"run", SHEET_RUN, 8, 13.0, true)
	_strip(sf, &"run_jump", SHEET_RUN, 8, 10.0, true)
	_still(sf, &"jump", SHEET_IDLE, 0)
	_still(sf, &"fall", SHEET_IDLE, 0)
	_still(sf, &"land", SHEET_IDLE, 0)
	_still(sf, &"stop", SHEET_IDLE, 0)
	_strip(sf, &"attack1", SHEET_ATTACK1, 9, 13.0, false)
	_strip(sf, &"attack2", SHEET_ATTACK2, 7, 12.0, false)
	_strip(sf, &"hit", SHEET_HURT, 6, 10.0, false)
	_strip(sf, &"hit_back", SHEET_HURT, 6, 10.0, false)
	_strip(sf, &"death", SHEET_DEATH, 7, 10.0, false)
	_strip(sf, &"win", SHEET_IDLE, 6, 8.0, true)
	return sf


static func _strip(sf: SpriteFrames, anim: StringName, sheet: Texture2D, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		sf.add_frame(anim, frame)


static func _still(sf: SpriteFrames, anim: StringName, sheet: Texture2D, index: int) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, 1.0)
	sf.set_animation_loop(anim, false)
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(index * FRAME, 0, FRAME, FRAME)
	sf.add_frame(anim, frame)
