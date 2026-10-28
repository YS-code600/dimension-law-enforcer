extends Node2D
## 火雨房间 Boss「豆包」的飞行真身。
## 悬浮在场地右侧，按「火柱 → 雷击 → 潮汐」循环施放技能。

signal health_changed(current: int, maximum: int)
signal defeated
signal revived

const FIRE_PILLAR := preload("res://levels/boss/fire_pillar.tscn")
const LIGHTNING_STRIKE := preload("res://levels/boss/lightning_strike.tscn")
const WATER_WAVE := preload("res://levels/boss/water_wave.tscn")
const FRAME_DIR := "res://picture/boss/"
const FRAME_SIZE := Vector2(64.0, 64.0)
const BODY_SCALE := Vector2(6.0, 6.0)
const ANIMS := {
	&"idle": {"file": "boss_idle.png", "frames": 7, "fps": 8.0, "loop": true},
	&"fly": {"file": "boss_fly.png", "frames": 6, "fps": 10.0, "loop": true},
	&"attack": {"file": "boss_attack.png", "frames": 8, "fps": 14.0, "loop": false},
	&"hurt": {"file": "boss_hurt.png", "frames": 6, "fps": 14.0, "loop": false},
	&"death": {"file": "boss_death.png", "frames": 8, "fps": 10.0, "loop": false},
}
const GROUND_Y := 600.0
const ROOM_MIN_X := 80.0
const ROOM_MAX_X := 1072.0
const ROOM_CENTER_X := 576.0

@export var max_health := 300
@export var hover_y := 440.0
@export var hover_amp := 26.0
@export var hover_speed := 1.35
@export var skill_interval := 3.8
@export var revive_delay := 1.4

var _active := false
var _dead := false
var _revive_locked := false
var _health := 300
var _player: Node2D
var _time := 0.0
var _skill_cd := 0.0
var _skill_step := 0

@onready var _body: AnimatedSprite2D = $Body
@onready var _glow: Sprite2D = $Glow
@onready var _shadow: Sprite2D = $Shadow
var _hurtbox: Area2D


func _ready() -> void:
	process_priority = 1000
	_health = max_health
	_build_frames()
	_play(&"fly", true)
	_body.scale = BODY_SCALE
	_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox == null:
		_hurtbox = _make_hurtbox()
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")
	_shadow.position.y = GROUND_Y - global_position.y


func is_hostile() -> bool:
	return _active


func health_now() -> int:
	return _health


func become_hostile() -> void:
	if _dead:
		return
	_active = true
	_health = max_health
	_skill_cd = 1.4
	_skill_step = 0
	add_to_group("enemy")
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 4)
	_health_changed()
	_body.modulate = Color.WHITE
	_body.scale = BODY_SCALE
	_play(&"fly", true)
	modulate.a = 1.0


## 玩家脚本会把 Boss 的位置拉回地面；这里用更晚的处理顺序覆盖 Y，实现悬浮飞行。
func _process(delta: float) -> void:
	_time += delta
	if _active and not _dead:
		global_position.y = hover_y + sin(_time * hover_speed) * hover_amp
		_body.position.y = sin(_time * 3.0) * 3.0
		_glow.modulate.a = 0.24 + sin(_time * 2.2) * 0.05
		_shadow.position.y = GROUND_Y - global_position.y
		if _player != null and is_instance_valid(_player):
			_body.flip_h = _player.global_position.x < global_position.x
	elif not _dead:
		_shadow.position.y = GROUND_Y - global_position.y
	queue_redraw()


## 脚下悬浮法阵：强化「飞行 Boss」的视觉锚点。
func _draw() -> void:
	if not _active or _dead:
		return
	var ground_y := GROUND_Y - global_position.y
	draw_set_transform(Vector2(0.0, ground_y), 0.0, Vector2(1.0, 0.3))
	var pulse := 0.28 + 0.12 * sin(_time * 2.6)
	draw_arc(Vector2.ZERO, 100.0, 0.0, TAU, 48, Color(0.35, 0.85, 1.0, pulse), 3.0)
	draw_arc(Vector2.ZERO, 72.0, 0.0, TAU, 36, Color(0.62, 0.48, 1.0, pulse * 0.8), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _physics_process(delta: float) -> void:
	if _dead or not _active:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_skill_cd -= delta
	if _skill_cd <= 0.0:
		_skill_cd = skill_interval
		_cast_next_skill()


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for key in ANIMS:
		var cfg: Dictionary = ANIMS[key]
		var tex := _load_texture(FRAME_DIR + String(cfg["file"]))
		if tex == null:
			continue
		frames.add_animation(key)
		frames.set_animation_speed(key, float(cfg["fps"]))
		frames.set_animation_loop(key, bool(cfg["loop"]))
		for i in int(cfg["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(FRAME_SIZE.x * float(i), 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(key, atlas)
	_body.sprite_frames = frames
	if not _body.animation_finished.is_connected(_on_animation_finished):
		_body.animation_finished.connect(_on_animation_finished)


func _play(anim: StringName, force := false) -> void:
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _body.animation == anim and _body.is_playing() and not force:
		return
	_body.play(anim)


func _on_animation_finished() -> void:
	if _dead:
		return
	_play(&"fly", true)


func _cast_next_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_play(&"attack", true)
	match _skill_step % 3:
		0:
			_cast_fire()
		1:
			_cast_lightning()
		_:
			_cast_water()
	_skill_step += 1


func _cast_fire() -> void:
	_flash_body(Color(1.0, 0.7, 0.5))
	var px := _player.global_position.x
	for i in 3:
		var x := clampf(px + float(i - 1) * 150.0, ROOM_MIN_X, ROOM_MAX_X)
		var pillar := FIRE_PILLAR.instantiate()
		get_parent().add_child(pillar)
		pillar.global_position = Vector2(x, GROUND_Y)
		pillar.call("setup", 0.55 + float(i) * 0.12)


func _cast_lightning() -> void:
	_flash_body(Color(0.62, 0.82, 1.0))
	var vx := 0.0
	var vel: Variant = _player.get("velocity")
	if vel is Vector2:
		vx = (vel as Vector2).x
	var px := _player.global_position.x + vx * 0.2
	for i in 2:
		var x := clampf(px + float(i * 2 - 1) * 110.0, ROOM_MIN_X, ROOM_MAX_X)
		var lightning := LIGHTNING_STRIKE.instantiate()
		get_parent().add_child(lightning)
		lightning.global_position = Vector2(x, GROUND_Y)
		lightning.call("setup", 0.5 + float(i) * 0.25)


func _cast_water() -> void:
	_flash_body(Color(0.5, 0.9, 1.0))
	var from_left := _player.global_position.x > ROOM_CENTER_X
	var wave := WATER_WAVE.instantiate()
	get_parent().add_child(wave)
	wave.global_position = Vector2(-180.0 if from_left else 1332.0, GROUND_Y)
	wave.call("setup", 1.0 if from_left else -1.0)


func _flash_body(color: Color) -> void:
	_body.modulate = color
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.32)


func _health_changed() -> void:
	health_changed.emit(_health, max_health)


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if not _active or _dead:
		return
	_health = maxi(0, _health - damage)
	_health_changed()
	_body.modulate = Color(1.8, 0.7, 0.8)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.18)
	_body.position.x = float(direction) * 5.0
	var tw2 := create_tween()
	tw2.tween_property(_body, "position:x", 0.0, 0.16)
	_play(&"hurt", true)
	if _health <= 0:
		_defeat()


func _defeat() -> void:
	if _dead:
		return
	_dead = true
	_active = false
	remove_from_group("enemy")
	_play(&"death", true)
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "scale", Vector2(5.4, 5.4), 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished
	_begin_revive()
	defeated.emit()


func _begin_revive() -> void:
	await get_tree().create_timer(revive_delay).timeout
	if _revive_locked or not is_inside_tree():
		return
	revive()


## 真结局：锁住复活并隐藏 Boss。
func stop_revive() -> void:
	_revive_locked = true
	_dead = true
	_active = false
	hide()
	set_process(false)
	set_physics_process(false)
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 0)


func revive() -> void:
	if _revive_locked or not _dead:
		return
	_dead = false
	modulate.a = 0.0
	_body.scale = BODY_SCALE
	_body.modulate = Color.WHITE
	_play(&"fly", true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	become_hostile()
	revived.emit()


func blink_to(pos: Vector2) -> void:
	if _dead:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void: global_position = Vector2(pos.x, global_position.y))
	tw.tween_property(self, "modulate:a", 1.0, 0.14)


func _make_hurtbox() -> Area2D:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160.0, 300.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 10.0)
	area.add_child(shape)
	add_child(area)
	return area


func _load_texture(path: String) -> Texture2D:
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null
