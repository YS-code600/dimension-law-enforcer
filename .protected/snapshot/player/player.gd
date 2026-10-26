extends CharacterBody2D
## 维度执法者主角「红」:拳击近战与远程飞刀两套攻击风格。

signal health_changed(current: int, maximum: int)
signal died
signal skill_changed(active: bool, active_left: float, active_total: float, cooldown_left: float, cooldown_total: float)
signal dimension_shot_finished
signal won
signal style_changed(style: int)

enum State { MOVE, ATTACK, DASH, HURT, DEAD }
enum Style { FIST, RANGED }

const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")
const DEATH_FRAMES := preload("res://player/character/death_frames.tres")
const WIN_FRAMES := preload("res://player/character/win_frames.tres")
const BASE_FRAMES := preload("res://player/red_frames.tres")
const KNIFE_SCENE := preload("res://player/combat/knife.tscn")
const HIT_SOUNDS := [
	preload("res://audio/hits/hit_01.ogg"),
	preload("res://audio/hits/hit_02.ogg"),
	preload("res://audio/hits/hit_03.ogg"),
	preload("res://audio/hits/hit_04.ogg"),
	preload("res://audio/hits/hit_05.ogg"),
	preload("res://audio/hits/hit_06.ogg"),
	preload("res://audio/hits/hit_07.ogg"),
	preload("res://audio/hits/hit_08.ogg"),
	preload("res://audio/hits/hit_09.ogg"),
	preload("res://audio/hits/hit_10.ogg"),
	preload("res://audio/hits/hit_11.ogg"),
	preload("res://audio/hits/hit_12.ogg"),
	preload("res://audio/hits/hit_13.ogg"),
	preload("res://audio/hits/hit_14.ogg"),
	preload("res://audio/hits/hit_15.ogg"),
	preload("res://audio/hits/hit_16.ogg"),
	preload("res://audio/hits/hit_17.ogg"),
	preload("res://audio/hits/hit_18.ogg"),
]
const ENEMY_MASK := 4
const PROJECTILE_MASK := 16
const ATTACK_MASK := ENEMY_MASK | PROJECTILE_MASK
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const DASH_SPEED := 760.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const WALK_IN_SPEED := 120.0
const ATTACK_BUFFER := 0.25
const SKILL_DURATION := 9.0
const SKILL_COOLDOWN := 30.0
const SKILL_ATTACK_SPEED := 1.5
const SKILL_RANGE_SCALE := 1.6
const SKILL_CANCEL_FRAME := 5
const SWITCH_SHOT_TIME := 0.8
const KNIFE_THROW_FRAME := 6
const FIST_SCALE := Vector2(2.0, 2.0)
const FIST_OFFSET := Vector2(0.0, -23.0)
const REFLECT_RING := preload("res://player/character/effect/reflect_ring.tscn")
const REFLECTED_SHOT := preload("res://player/character/effect/reflected_shot.tscn")
## 弹反:S 键在身前炸出蓝色圆环,把范围内的敌方弹幕打回去,冷却 3 秒。
const PARRY_RADIUS := 120.0
const PARRY_COOLDOWN := 3.0
const PARRY_CENTER_Y := -50.0

## 每套攻击的判定窗口以动画帧编号标记,保证判定与画面同步。
const ATTACKS := {
	&"light": {
		"anim": &"attack1",
		"damage": 9,
		"knockback": 190.0,
		"launch": -40.0,
		"shape": &"light",
		"windows": [[3, 7]],
		"fx": &"attack1_fx",
		"lunge": 120.0,
		"cancel_from": 8,
		"speed_scale": 1.35,
	},
	&"heavy": {
		"anim": &"attack2",
		"damage": 11,
		"knockback": 300.0,
		"launch": -190.0,
		"shape": &"heavy",
		"windows": [[4, 6], [8, 11]],
		"fx": &"attack2_fx",
		"lunge": 60.0,
		"cancel_from": -1,
		"speed_scale": 1.25,
	},
	&"dash": {
		"anim": &"attack2",
		"damage": 14,
		"knockback": 340.0,
		"launch": -140.0,
		"shape": &"dash",
		"windows": [[2, 10]],
		"fx": &"attack2_fx",
		"lunge": 520.0,
		"cancel_from": -1,
		"speed_scale": 1.45,
	},
	&"air": {
		"anim": &"attack1",
		"damage": 10,
		"knockback": 210.0,
		"launch": 120.0,
		"shape": &"air",
		"windows": [[3, 8]],
		"fx": &"attack1_fx",
		"lunge": 0.0,
		"cancel_from": -1,
		"speed_scale": 1.25,
	},
}

## 第二套攻击系统:远程。只保留 J 攻击,在挥击帧掷出飞刀。
const RANGED_ATTACKS := {
	&"light": {
		"anim": &"attack1",
		"damage": 12,
		"knockback": 170.0,
		"launch": -40.0,
		"shape": &"light",
		"windows": [],
		"fx": &"attack1_fx",
		"lunge": 40.0,
		"cancel_from": 8,
		"speed_scale": 1.4,
	},
	&"air": {
		"anim": &"attack1",
		"damage": 12,
		"knockback": 170.0,
		"launch": 40.0,
		"shape": &"air",
		"windows": [],
		"fx": &"attack1_fx",
		"lunge": 0.0,
		"cancel_from": -1,
		"speed_scale": 1.3,
	},
}

@export var move_speed := 430.0
@export var acceleration := 2100.0
@export var deceleration := 2600.0
@export var air_acceleration := 1500.0
@export var gravity := 1500.0
@export var jump_velocity := -650.0
@export var max_health := 100
@export var camera_limits := Rect2(0, 120, 3600, 600)
@export var death_margin := 72.0

var state: int = State.MOVE
var health := 100
var _facing := 1
var _anim: StringName = &""
var _last_grounded := -99.0
var _jump_queued_at := -99.0
var _was_on_floor := true
var _brake_timer := 0.0
var _land_timer := 0.0
var _air_attack_used := false
var _skill_active := false
var _skill_until := -99.0
var _skill_ready_at := -99.0
var _switch_anim := false
var _switch_t := 0.0
var _switch_fired := false
var _switch_death := false
var _saved_health := 100
var _won := false

var _style := Style.FIST
var _knife_thrown := false

var _walk_in_active := false
var _walk_in_target := 0.0
var _walk_in_speed := 0.0

var _attack_id: StringName = &""
var _hit_window := -1
var _hit_ids := {}
var _buffer_id: StringName = &""
var _buffer_at := -99.0

var _dash_timer := 0.0
var _dash_ready_at := -99.0
var _invuln_until := -99.0
var _hurt_timer := 0.0
var _death_confirmed := false

var _shake := 0.0
var _kill_y := INF
var _shapes := {}
var _skill_shapes := {}
var _hit_players: Array[AudioStreamPlayer] = []
var _hit_voice := 0
var _parry_ready_at := -99.0

@onready var _cam: Camera2D = $Camera2D
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _skill_aura: Sprite2D = $SkillAura
@onready var _gun: Sprite2D = $Gun
@onready var _gun_muzzle: Sprite2D = $GunMuzzle
@onready var _fx: AnimatedSprite2D = $Fx


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_cam.limit_left = int(camera_limits.position.x)
	_cam.limit_top = int(camera_limits.position.y)
	_cam.limit_right = int(camera_limits.position.x + camera_limits.size.x)
	_cam.limit_bottom = int(camera_limits.position.y + camera_limits.size.y)
	_cam.reset_smoothing()
	_kill_y = camera_limits.position.y + camera_limits.size.y + death_margin
	_build_shapes()
	_apply_style_frames()
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_fx.animation_finished.connect(_on_fx_animation_finished)
	_fx.visible = false
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8.0
		add_child(voice)
		_hit_players.append(voice)
	_play(&"idle", true)
	health_changed.emit(health, max_health)
	_ensure_parry_action()
	call_deferred("_setup_fire_room")


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.2)
		var amp := _shake * 7.0
		_cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO
	if _raid_mode:
		_tick_fire_room(delta)


func _physics_process(delta: float) -> void:
	var now := _now()
	if _switch_anim:
		if not _switch_death:
			_update_skill(now)
		_tick_dimension_shot(delta)
		return
	if _won:
		velocity = Vector2.ZERO
		return
	if _walk_in_active:
		_tick_walk_in(delta)
		return
	if Input.is_action_just_pressed("style_1"):
		_set_style(Style.FIST)
	elif Input.is_action_just_pressed("style_2"):
		_set_style(Style.RANGED)
	if Input.is_action_just_pressed("skill"):
		_activate_skill(now)
	_update_skill(now)
	_tick_parry(now)
	_brake_timer = maxf(0.0, _brake_timer - delta)
	_land_timer = maxf(0.0, _land_timer - delta)

	if state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		return

	if state == State.HURT:
		_tick_hurt(delta)
	elif state == State.DASH:
		_tick_dash(delta)
	elif state == State.ATTACK:
		_tick_attack(delta)
	else:
		_tick_move(delta, now)

	_sprite.flip_h = _facing < 0
	_fx.flip_h = _facing < 0
	move_and_slide()
	if global_position.y > _kill_y:
		_die()


# ---------------------------------------------------------------- 移动

func _tick_move(delta: float, now: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if is_on_floor():
		_last_grounded = now
		_air_attack_used = false
		if not _was_on_floor and velocity.y > 460.0:
			_land_timer = 0.12
	_was_on_floor = is_on_floor()

	# 攻击优先于位移
	if Input.is_action_just_pressed("attack_light"):
		_request_attack(&"light")
	elif Input.is_action_just_pressed("attack_heavy"):
		_request_attack(&"heavy")
	elif Input.is_action_just_pressed("attack_dash"):
		_request_attack(&"dash")
	if state != State.MOVE:
		return

	if Input.is_action_just_pressed("dodge") and is_on_floor() and now >= _dash_ready_at:
		_start_dash(now)
		return

	if Input.is_action_just_pressed("jump"):
		_jump_queued_at = now

	if now - _last_grounded <= COYOTE_TIME and now - _jump_queued_at <= JUMP_BUFFER \
			and velocity.y >= -20.0:
		velocity.y = jump_velocity
		_jump_queued_at = -99.0
		_land_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < -170.0:
		velocity.y = -170.0

	if not is_on_floor():
		velocity.y += gravity * delta

	if dir != 0.0:
		_facing = 1 if dir > 0.0 else -1
		var accel := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, dir * move_speed, accel * delta)
		_brake_timer = 0.0
	else:
		if is_on_floor() and absf(velocity.x) > 270.0 and _brake_timer <= 0.0:
			_brake_timer = 0.18
			_play(&"stop", true)
			_play_fx(&"stop_fx")
		var decel := deceleration * (2.0 if _brake_timer > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	_update_move_anim()


## 开场演出:锁定操作,自动走向 target_x,走路动画由速度驱动。
func begin_walk_in(target_x: float, speed := WALK_IN_SPEED) -> void:
	_walk_in_active = true
	_walk_in_target = target_x
	_walk_in_speed = maxf(speed, 1.0)
	state = State.MOVE
	_attack_id = &""
	_hit_window = -1
	_hit_ids.clear()
	_buffer_id = &""
	_brake_timer = 0.0
	_land_timer = 0.0
	_fx.visible = false
	_fx.stop()
	_play(&"walk", true)


func _tick_walk_in(delta: float) -> void:
	var dx := _walk_in_target - global_position.x
	if absf(dx) <= 2.0:
		_walk_in_active = false
		global_position.x = _walk_in_target
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		_update_move_anim()
		_sprite.flip_h = _facing < 0
		_fx.flip_h = _facing < 0
		move_and_slide()
		return
	_facing = 1 if dx > 0.0 else -1
	velocity.x = signf(dx) * _walk_in_speed
	if not is_on_floor():
		velocity.y += gravity * delta
	_play(&"walk")
	_sprite.flip_h = _facing < 0
	_fx.flip_h = _facing < 0
	move_and_slide()


func _update_move_anim() -> void:
	var next: StringName
	if not is_on_floor():
		if absf(velocity.x) > 220.0:
			next = &"run_jump"
		elif velocity.y < 0.0:
			next = &"jump"
		else:
			next = &"fall"
	elif _land_timer > 0.0:
		next = &"land"
	elif _brake_timer > 0.0:
		next = &"stop"
	else:
		var speed := absf(velocity.x)
		if speed > 285.0:
			next = &"run"
		elif speed > 25.0:
			next = &"walk"
		else:
			next = &"idle"
	_play(next)


# ---------------------------------------------------------------- 技能

func _activate_skill(now: float) -> void:
	if state == State.DEAD or _skill_active or now < _skill_ready_at:
		return
	if state == State.HURT:
		state = State.MOVE
		_hurt_timer = 0.0
	_skill_active = true
	_skill_until = now + SKILL_DURATION
	_skill_ready_at = now + SKILL_DURATION + SKILL_COOLDOWN
	_invuln_until = maxf(_invuln_until, _skill_until)
	if state == State.ATTACK:
		_sprite.speed_scale *= SKILL_ATTACK_SPEED
	_skill_aura.visible = true


func _update_skill(now: float) -> void:
	var active := now < _skill_until
	_skill_active = active
	var active_left := maxf(0.0, _skill_until - now) if active else 0.0
	var cooldown_left := maxf(0.0, _skill_ready_at - now)
	_skill_aura.visible = active
	_fx.scale = Vector2(2.8, 2.8) if active else Vector2(2.0, 2.0)
	if active:
		var pulse := 1.0 + 0.04 * sin(now * 7.0)
		_skill_aura.scale = Vector2(1.15, 1.15) * pulse
		_skill_aura.modulate.a = 0.4 + 0.14 * sin(now * 7.0)
	skill_changed.emit(active, active_left, SKILL_DURATION, cooldown_left, SKILL_COOLDOWN)


# ---------------------------------------------------------------- 攻击风格

func current_style() -> int:
	return _style


## 1 = 拳击近战,2 = 远程飞刀。
func _set_style(new_style: int) -> void:
	if new_style == _style or _won or _switch_anim or state == State.DEAD:
		return
	_buffer_id = &""
	if state == State.ATTACK:
		_end_attack()
	_style = new_style
	_apply_style_frames()
	_sprite.speed_scale = 1.0
	_fx.visible = false
	_fx.stop()
	_play(&"idle" if is_on_floor() else &"fall", true)
	var tw := create_tween()
	_sprite.modulate = Color(0.72, 0.95, 1.0, 1.0)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.22)
	style_changed.emit(_style)


func _apply_style_frames() -> void:
	_sprite.sprite_frames = BASE_FRAMES
	_sprite.scale = FIST_SCALE
	_sprite.offset = FIST_OFFSET


func _attack_set() -> Dictionary:
	return RANGED_ATTACKS if _style == Style.RANGED else ATTACKS


func _tick_ranged_attack() -> void:
	if _knife_thrown:
		return
	if _sprite.frame < KNIFE_THROW_FRAME:
		return
	_knife_thrown = true
	_throw_knife()


func _throw_knife() -> void:
	var host := get_parent()
	if host == null:
		return
	var origin := global_position + Vector2(32.0 * _facing, -62.0)
	var knife := KNIFE_SCENE.instantiate()
	host.add_child(knife)
	knife.global_position = origin
	if knife.has_method("setup"):
		knife.call("setup", _facing)
	var flash := HIT_SPARK.instantiate()
	host.add_child(flash)
	flash.global_position = origin
	flash.scale = Vector2(0.45, 0.45)
	flash.rotation = randf_range(-0.3, 0.3)
	_shake = maxf(_shake, 0.1)


func play_dimension_shot() -> bool:
	if _won or state == State.DEAD or _switch_anim:
		return false
	_switch_anim = true
	_switch_t = 0.0
	_switch_fired = false
	state = State.MOVE
	_attack_id = &""
	_hit_window = -1
	_hit_ids.clear()
	_buffer_id = &""
	_hurt_timer = 0.0
	_fx.visible = false
	_fx.stop()
	velocity = Vector2.ZERO
	_sprite.speed_scale = 1.0
	_play(&"idle", true)
	_sprite.modulate = Color.WHITE
	_invuln_until = maxf(_invuln_until, _now() + SWITCH_SHOT_TIME + 0.1)

	_gun.visible = true
	_gun.flip_h = _facing > 0
	_gun.position = Vector2(float(_facing) * 20.0, -80.0)
	_gun.modulate = Color(1, 1, 1, 0)
	_gun.scale = Vector2(1.3, 1.3)
	_gun_muzzle.visible = false

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gun, "position:y", -80.0, 0.16).from(-66.0)
	tw.tween_property(_gun, "modulate:a", 1.0, 0.12)
	return true


func _tick_dimension_shot(delta: float) -> void:
	if _switch_death:
		return
	_switch_t += delta
	if not _switch_fired and _switch_t >= 0.26:
		_switch_fired = true
		_gun_muzzle.visible = true
		_gun_muzzle.position = Vector2(-float(_facing) * 2.0, -80.0)
		_gun_muzzle.modulate = Color(1, 1, 1, 1)
		_shake = maxf(_shake, 0.65)
		_spawn_spark(global_position + Vector2(0.0, -80.0))
		_sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
		var flash := create_tween()
		flash.tween_property(_sprite, "modulate", Color.WHITE, 0.28)
		var base_x := float(_facing) * 20.0
		var kick := create_tween()
		kick.tween_property(_gun, "position:x", base_x + float(_facing) * 4.0, 0.05)
		kick.tween_property(_gun, "position:x", base_x, 0.14)
	if _switch_fired and _switch_t >= 0.40:
		_gun_muzzle.visible = false
	if _switch_t >= 0.62:
		_gun.visible = false
	if _switch_t >= SWITCH_SHOT_TIME:
		_begin_switch_death()


func _begin_switch_death() -> void:
	_switch_death = true
	_gun.visible = false
	_gun_muzzle.visible = false
	_skill_aura.visible = false
	_saved_health = health
	health = 0
	health_changed.emit(0, max_health)
	state = State.DEAD
	_sprite.modulate = Color.WHITE
	_sprite.sprite_frames = DEATH_FRAMES
	_sprite.flip_h = _facing < 0
	_play(&"death", true)


func _finish_switch_death() -> void:
	_switch_death = false
	_switch_anim = false
	_apply_style_frames()
	state = State.MOVE
	_play(&"idle", true)
	_sprite.modulate = Color.WHITE
	health = maxi(1, _saved_health)
	health_changed.emit(health, max_health)
	_invuln_until = maxf(_invuln_until, _now() + 0.4)
	dimension_shot_finished.emit()


func play_win() -> bool:
	if _won or state == State.DEAD or _switch_anim:
		return false
	_won = true
	state = State.MOVE
	velocity = Vector2.ZERO
	_attack_id = &""
	_hit_window = -1
	_hit_ids.clear()
	_buffer_id = &""
	_fx.visible = false
	_fx.stop()
	_skill_aura.visible = false
	_gun.visible = false
	_gun_muzzle.visible = false
	_invuln_until = INF
	_sprite.sprite_frames = WIN_FRAMES
	_sprite.modulate = Color.WHITE
	_sprite.speed_scale = 1.0
	_play(&"win", true)
	won.emit()
	return true


# ---------------------------------------------------------------- 攻击

func _request_attack(id: StringName) -> void:
	if _style == Style.RANGED and id != &"light":
		return
	if state == State.ATTACK:
		if _can_cancel(id):
			_start_attack(id)
		else:
			_buffer_id = id
			_buffer_at = _now()
		return
	if state != State.MOVE:
		return

	if id == &"light" and not is_on_floor():
		if _air_attack_used:
			return
		id = &"air"
	elif id == &"dash" and not is_on_floor():
		return
	_start_attack(id)


func _can_cancel(id: StringName) -> bool:
	if id == &"dash":
		return false
	if _attack_id != &"light":
		return false
	var cancel_frame := SKILL_CANCEL_FRAME if _skill_active else int(_attack_set()[&"light"]["cancel_from"])
	return _sprite.frame >= cancel_frame


func _start_attack(id: StringName) -> void:
	var cfg: Dictionary = _attack_set()[id]
	state = State.ATTACK
	_attack_id = id
	_knife_thrown = false
	_hit_window = -1
	_hit_ids.clear()
	_buffer_id = &""
	_land_timer = 0.0
	_brake_timer = 0.0
	var lunge := float(cfg["lunge"])
	if lunge > 0.0:
		velocity.x = _facing * lunge
	elif is_on_floor():
		velocity.x *= 0.25
	if id == &"air":
		_air_attack_used = true
		velocity.y = minf(velocity.y, 60.0)
	_play(StringName(cfg["anim"]), true)
	var speed_mult := SKILL_ATTACK_SPEED if _skill_active else 1.0
	_sprite.speed_scale = float(cfg["speed_scale"]) * speed_mult
	_fx.visible = false
	_fx.stop()


func _tick_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack_light"):
		_request_attack(&"light")
	elif Input.is_action_just_pressed("attack_heavy"):
		_request_attack(&"heavy")

	var cfg: Dictionary = _attack_set()[_attack_id]

	if not is_on_floor():
		var g := 0.35 if _attack_id == &"air" else 1.0
		velocity.y += gravity * g * delta

	var friction := 1100.0 if _attack_id == &"dash" else 1900.0
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if _style == Style.RANGED:
		_tick_ranged_attack()
		return

	var frame := _sprite.frame
	var window := _window_at(cfg, frame)
	if window != _hit_window:
		_hit_window = window
		_hit_ids.clear()
		if window >= 0:
			_play_fx(StringName(cfg["fx"]))
	if window >= 0:
		_poll_hits(cfg)


func _window_at(cfg: Dictionary, frame: int) -> int:
	var windows: Array = cfg["windows"]
	for i in windows.size():
		var w: Array = windows[i]
		if frame >= int(w[0]) and frame <= int(w[1]):
			return i
	return -1


func _poll_hits(cfg: Dictionary) -> void:
	var kind := StringName(cfg["shape"])
	var boosted := _skill_active
	var shape: Shape2D = _skill_shapes[kind] if boosted else _shapes[kind]
	var offset := _shape_offset(kind, boosted)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(offset.x * _facing, offset.y))
	query.collision_mask = ATTACK_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := get_world_2d().direct_space_state.intersect_shape(query, 24)
	for hit in results:
		var area := hit.get("collider") as Area2D
		if area == null:
			continue
		var target = area.get_parent()
		if target == null:
			continue
		if target is CanvasItem and not (target as CanvasItem).is_visible_in_tree():
			continue
		var target_id := target.get_instance_id()
		if target.is_in_group("projectile"):
			if _hit_ids.has(target_id):
				continue
			_hit_ids[target_id] = true
			target.call("pop")
			_shake = maxf(_shake, 0.1)
			continue
		if not target.has_method("take_hit"):
			continue
		if _hit_ids.has(target_id):
			continue
		_hit_ids[target_id] = true
		target.take_hit(int(cfg["damage"]), _facing, float(cfg["knockback"]), float(cfg["launch"]))
		_play_hit_sound(_attack_id)
		_spawn_spark(Vector2(target.global_position.x, target.global_position.y - 48.0))
		_shake = maxf(_shake, 0.6 if kind == &"heavy" else 0.32)


func _shape_offset(kind: StringName, boosted := false) -> Vector2:
	var offset := Vector2.ZERO
	match kind:
		&"light":
			offset = Vector2(48.0, -48.0)
		&"heavy":
			offset = Vector2(0.0, -48.0)
		&"dash":
			offset = Vector2(20.0, -46.0)
		&"air":
			offset = Vector2(40.0, -40.0)
	return offset * (1.35 if boosted else 1.0)


func _build_shapes() -> void:
	var light := RectangleShape2D.new()
	light.size = Vector2(82.0, 54.0)
	var heavy := CircleShape2D.new()
	heavy.radius = 72.0
	var dash := RectangleShape2D.new()
	dash.size = Vector2(120.0, 58.0)
	var air := RectangleShape2D.new()
	air.size = Vector2(86.0, 60.0)
	_shapes = {&"light": light, &"heavy": heavy, &"dash": dash, &"air": air}

	var light_s := RectangleShape2D.new()
	light_s.size = light.size * SKILL_RANGE_SCALE
	var heavy_s := CircleShape2D.new()
	heavy_s.radius = heavy.radius * SKILL_RANGE_SCALE
	var dash_s := RectangleShape2D.new()
	dash_s.size = dash.size * SKILL_RANGE_SCALE
	var air_s := RectangleShape2D.new()
	air_s.size = air.size * SKILL_RANGE_SCALE
	_skill_shapes = {&"light": light_s, &"heavy": heavy_s, &"dash": dash_s, &"air": air_s}


func _end_attack() -> void:
	_attack_id = &""
	_hit_window = -1
	_hit_ids.clear()
	state = State.MOVE
	_fx.visible = false
	_sprite.speed_scale = 1.0
	if _buffer_id != &"" and _now() - _buffer_at <= ATTACK_BUFFER:
		var id := _buffer_id
		_buffer_id = &""
		if id == &"dash" and not is_on_floor():
			return
		if id == &"light" and not is_on_floor():
			if _air_attack_used:
				return
			id = &"air"
		_start_attack(id)


func _on_sprite_animation_finished() -> void:
	if _switch_death:
		_finish_switch_death()
		return
	if state == State.DEAD:
		if not _death_confirmed:
			_death_confirmed = true
			died.emit()
		return
	if state == State.ATTACK:
		_end_attack()


# ---------------------------------------------------------------- 闪避

func _start_dash(now: float) -> void:
	state = State.DASH
	_dash_timer = DASH_TIME
	_dash_ready_at = now + DASH_COOLDOWN
	_invuln_until = now + 0.24
	var dir := Input.get_axis("move_left", "move_right")
	var dash_dir := signf(dir) if absf(dir) > 0.1 else -float(_facing)
	velocity.x = dash_dir * DASH_SPEED
	if is_on_floor():
		velocity.y = 0.0
	_play(&"stop", true)
	_play_fx(&"stop_fx")
	_land_timer = 0.0
	_brake_timer = 0.0


func _tick_dash(delta: float) -> void:
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		state = State.MOVE
		velocity.x *= 0.25
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * 0.25 * delta


# ---------------------------------------------------------------- 受击 / 死亡

func _tick_hurt(delta: float) -> void:
	_hurt_timer -= delta
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _hurt_timer <= 0.0:
		state = State.MOVE


func take_damage(amount: int, from_global: Vector2) -> void:
	if _won or _walk_in_active or state == State.DEAD or _now() < _invuln_until:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()
		return
	state = State.HURT
	_hurt_timer = 0.26
	_invuln_until = _now() + 0.5
	var away := signf(global_position.x - from_global.x)
	if away == 0.0:
		away = -float(_facing)
	velocity = Vector2(away * 260.0, -240.0)
	var from_front := away == -float(_facing)
	_play(&"hit" if from_front else &"hit_back", true)
	var tween := create_tween()
	_sprite.modulate = Color(1.0, 0.45, 0.5, 1.0)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.22)


func kill_instant() -> void:
	if _won or state == State.DEAD:
		return
	health = 0
	health_changed.emit(0, max_health)
	_die()


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	_skill_active = false
	_skill_aura.visible = false
	_switch_anim = false
	_switch_death = false
	_gun.visible = false
	_gun_muzzle.visible = false
	_fx.visible = false
	_fx.stop()
	_death_confirmed = false
	_sprite.sprite_frames = DEATH_FRAMES
	_sprite.flip_h = _facing < 0
	_play(&"death", true)


# ---------------------------------------------------------------- 表现

func _play(anim: StringName, force := false) -> void:
	if _anim == anim and not force:
		return
	_anim = anim
	_sprite.speed_scale = 1.0
	_sprite.play(anim)


func _play_fx(anim: StringName) -> void:
	_fx.visible = true
	_fx.play(anim)


func _on_fx_animation_finished() -> void:
	_fx.visible = false


func _spawn_spark(pos: Vector2) -> void:
	var spark := HIT_SPARK.instantiate()
	spark.global_position = pos
	spark.rotation = randf_range(-0.35, 0.35)
	spark.scale = Vector2(1.4, 1.4) if _skill_active else Vector2.ONE
	get_parent().add_child.call_deferred(spark)


func _play_hit_sound(attack_id: StringName) -> void:
	if _hit_players.is_empty() or HIT_SOUNDS.is_empty():
		return
	var voice := _hit_players[_hit_voice]
	_hit_voice = (_hit_voice + 1) % _hit_players.size()
	voice.stream = HIT_SOUNDS[randi() % HIT_SOUNDS.size()]
	var weight := 0.0
	match attack_id:
		&"heavy":
			weight = 1.0
		&"dash":
			weight = 0.75
		&"air":
			weight = 0.45
		&"parry":
			weight = 0.5
	voice.pitch_scale = lerpf(1.06, 0.9, weight) * randf_range(0.97, 1.03)
	voice.volume_db = lerpf(-9.0, -5.0, weight)
	voice.play()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func can_throw_grenade() -> bool:
	return not _walk_in_active and state != State.DEAD and not _switch_anim and not _won


# ---------------------------------------------------------------- 弹反(S 键)

## 按下 S:在身前炸出蓝色圆环,把周围 120px 内的敌方弹幕打回去,冷却 3 秒。
func _tick_parry(now: float) -> void:
	if _won or _switch_anim or _walk_in_active or state == State.DEAD:
		return
	if now < _parry_ready_at:
		return
	if not Input.is_action_just_pressed("parry"):
		return
	_parry_ready_at = now + PARRY_COOLDOWN
	_spawn_reflect_ring()
	_play_hit_sound(&"parry")
	var bounced := _reflect_projectiles()
	_shake = maxf(_shake, 0.6 if bounced > 0 else 0.28)


func is_parry_ready() -> bool:
	return _now() >= _parry_ready_at


func parry_cooldown_left() -> float:
	return maxf(0.0, _parry_ready_at - _now())


## 把范围内的敌方弹幕换成弹反弹:原地消失,变成青色光环飞向最近的敌人。
func _reflect_projectiles() -> int:
	var center := global_position + Vector2(0.0, PARRY_CENTER_Y)
	var host := get_parent()
	if host == null:
		return 0
	var enemy := _nearest_enemy(center)
	var bounced := 0
	for node in get_tree().get_nodes_in_group("projectile"):
		var proj := node as Node2D
		if proj == null or not is_instance_valid(proj):
			continue
		if proj.is_queued_for_deletion():
			continue
		if proj.global_position.distance_to(center) > PARRY_RADIUS:
			continue
		var damage := 16
		var raw: Variant = proj.get("damage")
		if raw != null:
			damage = maxi(int(raw), 6) * 2
		var aim := proj.global_position - center
		if enemy != null:
			aim = enemy.global_position + Vector2(0.0, -44.0) - proj.global_position
		var shot := REFLECTED_SHOT.instantiate()
		host.add_child(shot)
		shot.global_position = proj.global_position
		shot.call("setup", aim, damage)
		proj.queue_free()
		bounced += 1
	return bounced


func _nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := from.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _spawn_reflect_ring() -> void:
	var host := get_parent()
	if host == null:
		return
	var ring := REFLECT_RING.instantiate()
	host.add_child(ring)
	ring.global_position = global_position + Vector2(0.0, PARRY_CENTER_Y)


## project.godot 里若没有 parry 动作(被外部工具覆盖时),运行时补上 S 键。
func _ensure_parry_action() -> void:
	if not InputMap.has_action("parry"):
		InputMap.add_action("parry")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_S
	if not InputMap.action_has_event("parry", ev):
		InputMap.action_add_event("parry", ev)


# ---------------------------------------------------------------- 火雨房间(第二阶段增援)

## 第二阶段(衍月第一次被击倒)开始:立刻开进一辆坦克,之后每 30 秒一辆。
## 逻辑放在主角脚本里,因为 fire_room.tscn 会被 Team Create 重写、内嵌脚本会被清空。

const RAID_INTERVAL := 30.0
const RAID_MAX_ALIVE := 6
const RAID_EDGE := 190.0
const RAID_GROUND_Y := 600.0
const RAID_ROOM_WIDTH := 1152.0
const ROAM_AREA := Rect2(90.0, 330.0, 972.0, 210.0)
const ROAM_MARGIN := 70.0
const RAID_WARM := Color(1.0, 0.62, 0.45, 0.92)
const RAID_ALERT := Color(1.0, 0.35, 0.3, 1.0)

var _raid_mode := false
var _raid_boss: Node2D
var _raid_on := false
var _raid_countdown := 0.0
var _raid_side := 1.0
var _raid_warn := 0.0
var _raid_alert := false
var _raid_label: Label
var _roam_target := Vector2.ZERO
var _roam_timer := 0.0
var _roam_vel := Vector2.ZERO


func _setup_fire_room() -> void:
	var room := get_parent()
	if room == null or room.name != "FireRoom":
		return
	var boss := room.get_node_or_null("VioletCompanion") as Node2D
	if boss == null:
		return
	_raid_mode = true
	_raid_boss = boss
	_roam_target = boss.global_position
	if boss.has_signal("defeated") and not boss.is_connected("defeated", _on_raid_boss_defeated):
		boss.connect("defeated", _on_raid_boss_defeated)
	_build_raid_label()


func _tick_fire_room(delta: float) -> void:
	if _raid_boss != null and is_instance_valid(_raid_boss) \
			and bool(_raid_boss.call("is_hostile")):
		_tick_roam(delta)
	if not _raid_on:
		return
	if _raid_warn > 0.0:
		_raid_warn = maxf(0.0, _raid_warn - delta)
	_raid_countdown -= delta
	if _raid_countdown <= 0.0:
		_raid_countdown = RAID_INTERVAL
		_spawn_raid_tank()
	_update_raid_label()


## 被击倒一次 = 第二阶段开始:马上来一辆,再挂上 30 秒循环。
func _on_raid_boss_defeated() -> void:
	if _raid_on:
		return
	_raid_on = true
	_raid_countdown = RAID_INTERVAL
	_spawn_raid_tank()
	_raid_warn = 2.4


func _spawn_raid_tank() -> void:
	var room := get_parent()
	if room == null:
		return
	if _raid_tanks_alive() >= RAID_MAX_ALIVE:
		return
	var packed = load("res://levels/enemies/tank.tscn")
	if packed == null:
		return
	var tank = packed.instantiate()
	if tank == null:
		return
	room.add_child(tank)
	var from_left := _raid_side < 0.0
	if global_position.x > RAID_ROOM_WIDTH * 0.5:
		from_left = false
	_raid_side = -_raid_side
	tank.global_position = Vector2(
		-RAID_EDGE if from_left else RAID_ROOM_WIDTH + RAID_EDGE, RAID_GROUND_Y)
	if tank.has_method("setup"):
		tank.call("setup", 1.0 if from_left else -1.0)


func _raid_tanks_alive() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("raid_tank"):
		if is_instance_valid(node):
			count += 1
	return count


# ---------------------------------------------------------------- Boss 游走

func _tick_roam(delta: float) -> void:
	if not _raid_boss.is_visible_in_tree():
		return
	_roam_timer -= delta
	var to_player := global_position - _raid_boss.global_position
	var distance := Vector2(to_player.x, 0.0).length()
	if distance < 150.0 or _roam_timer <= 0.0 \
			or _raid_boss.global_position.distance_to(_roam_target) < 36.0:
		_pick_roam_target(distance, to_player)
		_roam_timer = randf_range(1.3, 2.6)
	var desired := Vector2.ZERO
	var to_target := _roam_target - _raid_boss.global_position
	if to_target.length() > 4.0:
		desired = to_target.normalized() * 165.0
	_roam_vel = _roam_vel.lerp(desired, 1.0 - exp(-3.6 * delta))
	_raid_boss.global_position += _roam_vel * delta
	_clamp_roam()


func _pick_roam_target(distance: float, to_player: Vector2) -> void:
	var bounds := _roam_bounds()
	var away := 1.0 if to_player.x <= 0.0 else -1.0
	if distance < 240.0 and distance > 0.001:
		_roam_target = _clamp_point(_raid_boss.global_position + Vector2(
			away * randf_range(280.0, 420.0), randf_range(-90.0, 80.0)), bounds)
		return
	if distance > 620.0:
		_roam_target = _clamp_point(_raid_boss.global_position + Vector2(
			signf(to_player.x) * randf_range(240.0, 360.0), randf_range(-80.0, 80.0)), bounds)
		return
	for i in 8:
		var candidate := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y))
		if candidate.distance_to(_raid_boss.global_position) < 200.0:
			continue
		if absf(candidate.x - global_position.x) < 190.0:
			continue
		_roam_target = candidate
		return
	_roam_target = _clamp_point(_raid_boss.global_position + Vector2(
		away * randf_range(240.0, 360.0), randf_range(-100.0, 80.0)), bounds)


func _roam_bounds() -> Rect2:
	return Rect2(ROAM_AREA.position + Vector2(ROAM_MARGIN, 0.0),
		ROAM_AREA.size - Vector2(ROAM_MARGIN * 2.0, 0.0))


func _clamp_point(point: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y))


func _clamp_roam() -> void:
	var bounds := _roam_bounds()
	var clamped := _clamp_point(_raid_boss.global_position, bounds)
	if clamped != _raid_boss.global_position:
		_raid_boss.global_position = clamped
		_roam_timer = 0.0
		_roam_vel *= 0.35


# ---------------------------------------------------------------- 增援提示

func _build_raid_label() -> void:
	if _raid_label != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "RaidHud"
	layer.layer = 4
	add_child(layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC",
		"Noto Sans CJK SC", "PingFang SC", "SimHei",
	])
	_raid_label = Label.new()
	_raid_label.name = "RaidLabel"
	_raid_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raid_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_raid_label.offset_left = -190.0
	_raid_label.offset_right = 190.0
	_raid_label.offset_top = 84.0
	_raid_label.offset_bottom = 110.0
	_raid_label.add_theme_font_override("font", font)
	_raid_label.add_theme_font_size_override("font_size", 15)
	_raid_label.add_theme_color_override("font_color", RAID_WARM)
	_raid_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 0.95))
	_raid_label.add_theme_constant_override("outline_size", 6)
	_raid_label.visible = false
	layer.add_child(_raid_label)


func _update_raid_label() -> void:
	if _raid_label == null:
		return
	_raid_label.visible = true
	var alert := _raid_warn > 0.0
	if alert != _raid_alert:
		_raid_alert = alert
		_raid_label.add_theme_color_override("font_color", RAID_ALERT if alert else RAID_WARM)
	if alert:
		_raid_label.text = "警告：敌方坦克进入战场"
	else:
		_raid_label.text = "敌方装甲增援：%d 秒" % int(ceil(_raid_countdown))
