extends Node2D
## 蓝帽法师(衍月):主线里靠近按攻击键缔结同行,之后跟随主角。
## 火雨房间里她会露出真身进入敌对形态:结束跟随、无法再交互,用法术迎战,
## 被打倒后会短暂倒地并重新出现。

signal health_changed(current: int, maximum: int)
signal defeated
signal revived

const BULLET := preload("res://levels/enemies/enemy_bullet.tscn")
const BLUE_ORB := preload("res://levels/npc/blue_orb.tscn")
const WIZARD_DIR := "res://levels/npc/wizard/"
const FRAME_SIZE := Vector2(64, 64)
## 地面移动参数:她不会飞,只能走/跑和跳。
const GRAVITY := 1500.0
const MOVE_SPEED := 250.0
const JUMP_VELOCITY := -560.0
const JUMP_COOLDOWN := 1.3

## 动画表:图集路径 / 帧数 / 帧率 / 是否循环。
const ANIMS := {
	&"idle": {"file": "idle.png", "frames": 6, "fps": 8.0, "loop": true},
	&"run": {"file": "run.png", "frames": 8, "fps": 12.0, "loop": true},
	&"attack1": {"file": "attack1.png", "frames": 10, "fps": 16.0, "loop": false},
	&"attack2": {"file": "attack2.png", "frames": 11, "fps": 14.0, "loop": false},
	&"hurt": {"file": "hurt.png", "frames": 6, "fps": 16.0, "loop": false},
	&"death": {"file": "death.png", "frames": 7, "fps": 11.0, "loop": false},
}

@export var interact_range := 140.0
@export var follow_offset := Vector2(84.0, 74.0)
## 为 true 时不经"按攻击键缔结"直接进入同行状态(用于直接以同行者身份出场的场景)。
@export var start_following := false
@export var max_health := 300
@export var fire_interval := 2.2
@export var attack_range := 760.0
## 全方位爆球:每隔 burst_idle_time 秒连续爆发 burst_volleys 轮,每轮 burst_orbs 个。
@export var burst_idle_time := 7.0
@export var burst_volleys := 3
@export var burst_interval := 0.45
@export var burst_orbs := 10

var _following := false
var _hostile := false
var _dead := false
var _health := 100
var _player: Node2D
var _time := 0.0
var _fire_cooldown := 1.2
var _muzzle_flash := 0.0
var _burst_left := 0
var _burst_next := 0.0
var _burst_idle := 0.0
var _burst_volley := 0
var _cast_kind := &""
var _cast_time := 0.0
var _cast_fire_at := 0.0
var _cast_fired := false
var _anim_lock := 0.0
var _last_pos := Vector2.ZERO
var _moving := false
var _vel_y := 0.0
var _on_floor := false
var _jump_cd := 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _glow: Sprite2D = $Glow
@onready var _prompt: Label = $Prompt
var _hurtbox: Area2D


func _ready() -> void:
	add_to_group("companion")
	_health = max_health
	_prompt.visible = false
	if start_following:
		_following = true
	_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox == null:
		_hurtbox = _make_hurtbox()
	_build_animations()
	_last_pos = global_position
	_play(&"idle", true)
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")


func is_following() -> bool:
	return _following


func is_hostile() -> bool:
	return _hostile


func health_now() -> int:
	return _health


func set_following(value: bool) -> void:
	_following = value
	if not value:
		_prompt.visible = false


## 进入敌对形态:结束跟随、关闭交互、启用受伤盒、开始主动攻击。
func become_hostile() -> void:
	if _hostile or _dead:
		return
	_hostile = true
	_following = false
	_prompt.visible = false
	add_to_group("enemy")
	remove_from_group("companion")
	_health = max_health
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 4)
	health_changed.emit(_health, max_health)
	_fire_cooldown = 1.2
	_burst_idle = 3.5
	_cast_kind = &""
	_anim_lock = 0.0
	modulate = Color.WHITE
	_play(&"idle", true)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_glow.modulate.a = 0.28 + sin(_time * 2.4) * 0.06
	if _muzzle_flash > 0.0:
		_muzzle_flash = maxf(0.0, _muzzle_flash - delta)
		_glow.scale = Vector2.ONE * (0.65 + _muzzle_flash * 2.2)
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_update_moving()
	_update_animation(delta)

	if _hostile:
		_tick_hostile(delta)
	elif _following:
		_follow(delta)
	else:
		_idle()
	_apply_ground(delta)


# ---------------------------------------------------------------- 动画

func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for key in ANIMS:
		var cfg: Dictionary = ANIMS[key]
		var tex := load(WIZARD_DIR + String(cfg["file"])) as Texture2D
		if tex == null:
			continue
		frames.add_animation(key)
		frames.set_animation_speed(key, float(cfg["fps"]))
		frames.set_animation_loop(key, bool(cfg["loop"]))
		var count := int(cfg["frames"])
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(FRAME_SIZE.x * float(i), 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(key, atlas)
	_sprite.sprite_frames = frames
	_sprite.animation_finished.connect(_on_animation_finished)


func _play(anim: StringName, force := false) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation == anim and _sprite.is_playing() and not force:
		return
	_sprite.play(anim)


func _update_moving() -> void:
	_moving = global_position.distance_to(_last_pos) > 0.35
	_last_pos = global_position


func _update_animation(delta: float) -> void:
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if _anim_lock > 0.0 or _cast_kind != &"":
		return
	_play(&"run" if _moving else &"idle")


func _on_animation_finished() -> void:
	_anim_lock = 0.0
	if _dead:
		return
	if _hostile and _cast_kind != &"":
		return
	_play(&"idle", true)


func play_hurt() -> void:
	if _dead:
		return
	_anim_lock = 0.35
	_play(&"hurt", true)


## 瞬移(火雨房间的法师走位):淡出→换位→淡入。
func blink_to(pos: Vector2) -> void:
	if _dead:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void: global_position = pos)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)


# ---------------------------------------------------------------- 敌对

## 敌对状态:面向主角,按节奏施放法术。
func _tick_hostile(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var to_player := _player.global_position - global_position
	_sprite.flip_h = to_player.x < 0.0

	# 爆球连发
	if _burst_left > 0:
		_burst_next -= delta
		if _burst_next <= 0.0:
			_burst_left -= 1
			_fire_burst()
			_burst_next = burst_interval

	# 施法动作:抬手 → 命中帧放法术 → 收招
	if _cast_kind != &"":
		_cast_time -= delta
		if not _cast_fired and _cast_time <= _cast_fire_at:
			_cast_fired = true
			if _cast_kind == &"aimed":
				_shoot(_player.global_position)
			else:
				_muzzle_flash = 0.3
		if _cast_time <= 0.0:
			_cast_kind = &""
			_cast_fired = false
		return

	if absf(to_player.x) > attack_range:
		return
	if _burst_left > 0:
		return

	_burst_idle -= delta
	if _burst_idle <= 0.0:
		_burst_idle = burst_idle_time
		_begin_cast(&"burst")
		_burst_left = burst_volleys
		_burst_next = 0.32
		return

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = fire_interval
		_begin_cast(&"aimed")


func _begin_cast(kind: StringName) -> void:
	_cast_kind = kind
	_cast_fired = false
	_anim_lock = 0.0
	if kind == &"burst":
		_cast_time = 1.05
		_cast_fire_at = 0.42
		_play(&"attack2", true)
	else:
		_cast_time = 0.6
		_cast_fire_at = 0.3
		_play(&"attack1", true)


## 向四周均匀发射一圈蓝色爆球;每轮角度旋转半格,形成扩散的螺旋。
func _fire_burst() -> void:
	var count := maxi(burst_orbs, 1)
	var start := TAU * (float(_burst_volley) / float(count)) * 0.5
	_burst_volley += 1
	var origin := global_position + Vector2(0, -54)
	for i in count:
		var angle := start + TAU * float(i) / float(count)
		var orb := BLUE_ORB.instantiate()
		orb.global_position = origin
		get_parent().add_child(orb)
		orb.call("setup", Vector2(cos(angle), sin(angle)))
	_muzzle_flash = 0.22


## target 是主角的全局坐标(注意不要传相对向量,否则方向会算错)。
func _shoot(target: Vector2) -> void:
	var origin := global_position + Vector2(0, -58)
	var aim := (target + Vector2(0, -30) - origin).normalized()
	for angle_offset in [-0.12, 0.0, 0.12]:
		var bullet := BULLET.instantiate()
		bullet.global_position = origin
		get_parent().add_child(bullet)
		bullet.call("setup", aim.rotated(angle_offset))
	_muzzle_flash = 0.16


## 被主角攻击命中(玩家攻击查询会把伤害转到这里)。
func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if not _hostile or _dead:
		return
	_health = maxi(0, _health - damage)
	health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.9, 0.75, 0.75)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.16)
	_sprite.position.x = direction * 4.0
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "position:x", 0.0, 0.14)
	play_hurt()
	_fire_cooldown = maxf(_fire_cooldown, 0.4)
	if _health <= 0:
		_defeat()


func _defeat() -> void:
	if _dead:
		return
	_dead = true
	_hostile = false
	_cast_kind = &""
	_burst_left = 0
	remove_from_group("enemy")
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 0)
	_prompt.visible = false
	_play(&"death", true)
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(_begin_revive)
	defeated.emit()


## 倒地后稍等片刻再带着满血重新出现(火雨房间里她会无限复活)。
func _begin_revive() -> void:
	await get_tree().create_timer(1.4).timeout
	revive()


func revive() -> void:
	if not _dead:
		return
	_dead = false
	scale = Vector2.ONE
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	become_hostile()
	health_changed.emit(_health, max_health)
	revived.emit()


# ---------------------------------------------------------------- 同行

func _idle() -> void:
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	_prompt.visible = distance < 240.0
	if distance <= interact_range and _attack_pressed():
		_recruit()


func _attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack_light") \
		or Input.is_action_just_pressed("attack_heavy") \
		or Input.is_action_just_pressed("attack_dash")


func _recruit() -> void:
	if _hostile or _dead:
		return
	_following = true
	_prompt.visible = false
	_persist.call_deferred()
	var tween := create_tween()
	tween.tween_property(_glow, "scale", Vector2(1.1, 1.1), 0.16)
	tween.tween_property(_glow, "scale", Vector2(0.9, 0.9), 0.32)


## 离开主线世界节点,保证切换维度后仍跟随主角。
func _persist() -> void:
	var target := get_tree().current_scene
	if target == null:
		target = get_parent()
		while target != null and target.name != "Game":
			target = target.get_parent()
	if target != null and get_parent() != target:
		reparent(target, true)


func _follow(delta: float) -> void:
	if _player == null:
		return
	var facing := int(_player.get("_facing"))
	var target_x := _player.global_position.x - float(facing) * follow_offset.x
	var dx := target_x - global_position.x
	if absf(dx) > 4.0:
		global_position.x = move_toward(global_position.x, target_x, MOVE_SPEED * delta)
	_sprite.flip_h = _player.global_position.x < global_position.x
	# 主角在高处就跳上去(不会飞,只有跳跃)
	if _on_floor and _jump_cd <= 0.0 \
			and _player.global_position.y < global_position.y - 70.0:
		_jump_cd = JUMP_COOLDOWN
		_vel_y = JUMP_VELOCITY
	if absf(_player.global_position.x - global_position.x) > 900.0:
		global_position = Vector2(target_x, _player.global_position.y)
		_vel_y = 0.0


## 重力 + 地面检测:她不会飞,只能贴着地面走/跑/跳。
func _apply_ground(delta: float) -> void:
	if _hostile:
		_vel_y = 0.0
		return
	_vel_y += GRAVITY * delta
	global_position.y += _vel_y * delta
	_on_floor = false
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from := global_position + Vector2(0.0, -8.0)
	var to := global_position + Vector2(0.0, 16.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	if _player is CollisionObject2D:
		query.exclude = [(_player as CollisionObject2D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and _vel_y >= 0.0:
		if hit.position.y - global_position.y <= 18.0:
			global_position.y = hit.position.y
			_vel_y = 0.0
			_on_floor = true
	elif global_position.y > 1400.0:
		global_position = Vector2(global_position.x, 560.0)
		_vel_y = 0.0


## 场景里没有 Hurtbox 时兜底创建一个(避免被外部工具改写场景后直接报错)。
func _make_hurtbox() -> Area2D:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52.0, 92.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -48.0)
	area.add_child(shape)
	add_child(area)
	return area
