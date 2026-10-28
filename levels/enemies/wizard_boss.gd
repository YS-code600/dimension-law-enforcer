extends Node2D
## 火雨房间的 Boss「衍月」:独立的蓝帽法师精灵,与同行者互不影响。
## 由 fire_room 的入场演出激活,负责施法、受击、倒地和复活。

signal health_changed(current: int, maximum: int)
signal defeated
signal revived

const BULLET := preload("res://levels/enemies/enemy_bullet.tscn")
const BLUE_ORB := preload("res://levels/npc/blue_orb.tscn")
const WIZARD_DIR := "res://levels/npc/wizard/"
const FRAME_SIZE := Vector2(64, 64)
const ANIMS := {
	&"idle": {"file": "idle.png", "frames": 6, "fps": 8.0, "loop": true},
	&"run": {"file": "run.png", "frames": 8, "fps": 12.0, "loop": true},
	&"attack1": {"file": "attack1.png", "frames": 10, "fps": 16.0, "loop": false},
	&"attack2": {"file": "attack2.png", "frames": 11, "fps": 14.0, "loop": false},
	&"hurt": {"file": "hurt.png", "frames": 6, "fps": 16.0, "loop": false},
	&"death": {"file": "death.png", "frames": 7, "fps": 11.0, "loop": false},
}

@export var max_health := 300
@export var fire_interval := 2.2
@export var attack_range := 900.0
@export var burst_idle_time := 7.0
@export var burst_volleys := 3
@export var burst_interval := 0.45
@export var burst_orbs := 10
@export var revive_delay := 1.4

var _active := false
var _dead := false
var _health := 300
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

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _glow: Sprite2D = $Glow
var _hurtbox: Area2D


func _ready() -> void:
	_health = max_health
	_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox == null:
		_hurtbox = _make_hurtbox()
	_build_animations()
	_play(&"idle", true)
	_last_pos = global_position
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")


func is_hostile() -> bool:
	return _active


func health_now() -> int:
	return _health


## 入场演出结束后由 fire_room 调用。
func become_hostile() -> void:
	if _dead:
		return
	_active = true
	add_to_group("enemy")
	_health = max_health
	_burst_idle = 3.5
	_fire_cooldown = 1.2
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 4)
	health_changed.emit(_health, max_health)
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
	if not _active:
		return
	_update_animation(delta)
	_tick_hostile(delta)


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
		for i in int(cfg["frames"]):
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


func _update_animation(delta: float) -> void:
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if _anim_lock > 0.0 or _cast_kind != &"":
		return
	var moved := global_position.distance_to(_last_pos) > 0.6
	_last_pos = global_position
	_play(&"run" if moved else &"idle")


func _on_animation_finished() -> void:
	_anim_lock = 0.0
	if _dead or _cast_kind != &"":
		return
	_play(&"idle", true)


## 瞬移:淡出 → 换位 → 淡入。
func blink_to(pos: Vector2) -> void:
	if _dead:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void: global_position = pos)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)


# ---------------------------------------------------------------- 法术

func _tick_hostile(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var to_player := _player.global_position - global_position
	_sprite.flip_h = to_player.x < 0.0

	if _burst_left > 0:
		_burst_next -= delta
		if _burst_next <= 0.0:
			_burst_left -= 1
			_fire_burst()
			_burst_next = burst_interval

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

	if absf(to_player.x) > attack_range or _burst_left > 0:
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


func _shoot(target: Vector2) -> void:
	var origin := global_position + Vector2(0, -58)
	var aim := (target + Vector2(0, -30) - origin).normalized()
	for angle_offset in [-0.12, 0.0, 0.12]:
		var bullet := BULLET.instantiate()
		bullet.global_position = origin
		get_parent().add_child(bullet)
		bullet.call("setup", aim.rotated(angle_offset))
	_muzzle_flash = 0.16


# ---------------------------------------------------------------- 受伤 / 倒地

func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if not _active or _dead:
		return
	_health = maxi(0, _health - damage)
	health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.9, 0.75, 0.75)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.16)
	_sprite.position.x = direction * 4.0
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "position:x", 0.0, 0.14)
	_anim_lock = 0.35
	_play(&"hurt", true)
	_fire_cooldown = maxf(_fire_cooldown, 0.4)
	if _health <= 0:
		_defeat()


func _defeat() -> void:
	if _dead:
		return
	_dead = true
	_active = false
	_cast_kind = &""
	_burst_left = 0
	remove_from_group("enemy")
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 0)
	_play(&"death", true)
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(_begin_revive)
	defeated.emit()


func _begin_revive() -> void:
	await get_tree().create_timer(revive_delay).timeout
	revive()


func revive() -> void:
	if not _dead:
		return
	_dead = false
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	become_hostile()
	health_changed.emit(_health, max_health)
	revived.emit()


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
