extends Node2D
## 火雨房间 Boss「豆包」的飞行真身。
## 悬浮在场地右侧，按「火柱 → 雷击 → 潮汐」循环施放技能。

signal health_changed(current: int, maximum: int)
signal defeated
signal revived

const FIRE_PILLAR := preload("res://levels/boss/fire_pillar.tscn")
const LIGHTNING_STRIKE := preload("res://levels/boss/lightning_strike.tscn")
const WATER_WAVE := preload("res://levels/boss/water_wave.tscn")
const BLUE_ORB := preload("res://levels/npc/blue_orb.tscn")
const MUSHROOM := preload("res://levels/enemies/mushroom.tscn")
const SPACE_EXPLOSION := preload("res://levels/boss/space_explosion.tscn")
const FIREBALL := preload("res://levels/boss/fireball.tscn")
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
## 阶段成长:每次复活后,血量相对上一阶段翻倍、全部技能伤害 +2。
const PHASE_HP_FACTOR := 2
const PHASE_DAMAGE_STEP := 2
## 第 2 阶段起:地面波浪换成「向四周连发 3 轮蓝色火球」。
const ORB_VOLLEYS := 3
const ORB_PER_VOLLEY := 12
const ORB_VOLLEY_GAP := 0.45
const ORB_DAMAGE := 5
## 第 3 阶段起:每 30 秒召唤 4 只蘑菇小兵(近战,4 点伤害)。
const MUSHROOM_SUMMON_PHASE := 2
const MUSHROOM_SUMMON_INTERVAL := 30.0
const MUSHROOM_SUMMON_COUNT := 4
const MUSHROOM_MAX_ALIVE := 12
## 第 4 阶段起:每 3 秒在场地随机位置引爆一次空间爆炸(4 点伤害)。
const EXPLOSION_MIN_PHASE := 3
const EXPLOSION_INTERVAL := 3.0
## 引爆炸点离房间两侧至少留这么宽,爆炸圈才不会跑到墙外
const EXPLOSION_MARGIN := 90.0
## 第 5 阶段:连续 5 发火焰弹射向主角当前位置(基础 8 点伤害)。
const FIREBALL_MIN_PHASE := 4
const FIREBALL_SHOTS := 5
const FIREBALL_GAP := 0.35
const FIREBALL_DAMAGE := 8
## 第 5 阶段:阶段开始时召唤 1 个分身,之后每 60 秒再召唤 1 个,最多 3 个。
## 分身的血量倍率(1.0 = 和本体完全一样)
const CLONE_MIN_PHASE := 4
const CLONE_INTERVAL := 60.0
const CLONE_MAX := 3
const CLONE_HP_FACTOR := 0.3
const CLONE_SCENE_PATH := "res://levels/enemies/wizard_boss.tscn"
## 第 3 阶段起:阶段开始时召唤 1 个骑士,之后每 20 秒 1 个(场上最多 6 个)
const KNIGHT := preload("res://levels/enemies/knight.tscn")
const KNIGHT_MIN_PHASE := 2
const KNIGHT_INTERVAL := 20.0
const KNIGHT_MAX_ALIVE := 6
## 第 4 阶段起:阶段开始时召唤 1 个飞行法师,之后每 40 秒 1 个(场上最多 4 个)
const FLYING_WIZARD := preload("res://levels/enemies/wizard_minion.tscn")
const WIZARD_MIN_PHASE := 3
const WIZARD_INTERVAL := 40.0
const WIZARD_MAX_ALIVE := 4

## 第 1 阶段的血量(之后每阶段 ×PHASE_HP_FACTOR)。
@export var base_health := 300
@export var hover_y := 440.0
@export var hover_amp := 26.0
@export var hover_speed := 1.35
@export var skill_interval := 3.8
@export var revive_delay := 1.4

var _active := false
var _dead := false
var _revive_locked := false
var _health := 300
## 是否是本体召唤出来的分身(分身不再召唤分身、死亡不复活)
var is_clone := false
## 分身召唤倒计时 / 已召唤数量
var _clone_cd := CLONE_INTERVAL
var _clones_made := 0
## 骑士召唤倒计时
var _knight_cd := KNIGHT_INTERVAL
## 飞行法师召唤倒计时
var _wizard_cd := WIZARD_INTERVAL
## 当前阶段的最大血量(_apply_phase_stats 刷新,boss_bar 读这个值)。
var max_health := 300
## 0 = 第 1 阶段。
var _phase := 0
## 当前阶段额外附加的技能伤害。
var _damage_bonus := 0
## 蘑菇召唤倒计时
var _summon_cd := MUSHROOM_SUMMON_INTERVAL
## 空间爆炸倒计时
var _explosion_cd := EXPLOSION_INTERVAL
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


## 当前阶段(从 1 开始),方便别处查进度。
func phase_now() -> int:
	return _phase + 1


## 按当前阶段套用血量与伤害成长:第 1 阶段保持原样,之后每阶段血量翻倍、伤害 +2。
func _apply_phase_stats() -> void:
	var mult := 1
	for i in _phase:
		mult *= PHASE_HP_FACTOR
	max_health = base_health * mult
	_health = max_health
	_damage_bonus = PHASE_DAMAGE_STEP * _phase
	_summon_cd = MUSHROOM_SUMMON_INTERVAL
	_explosion_cd = EXPLOSION_INTERVAL


func become_hostile() -> void:
	if _dead:
		return
	_active = true
	_apply_phase_stats()
	_skill_cd = 1.4
	_skill_step = 0
	add_to_group("enemy")
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 4)
	_health_changed()
	_body.modulate = Color.WHITE
	_body.scale = BODY_SCALE
	_play(&"fly", true)
	# 第 5 阶段开始:先立刻来一个分身,之后每 60 秒一个
	if _can_clone():
		_clone_cd = CLONE_INTERVAL
		_spawn_clone()
	# 第 3 阶段开始:先立刻来一个骑士,之后每 20 秒一个
	if _can_summon_knight():
		_knight_cd = KNIGHT_INTERVAL
		_summon_knight()
	# 第 4 阶段开始:先立刻来一个飞行法师,之后每 40 秒一个
	if _can_summon_wizard():
		_wizard_cd = WIZARD_INTERVAL
		_summon_wizard()


## 只有本体在第 5 阶段及以后才召唤分身,且最多 CLONE_MAX 个。
func _can_clone() -> bool:
	return not is_clone and _phase >= CLONE_MIN_PHASE and _clones_made < CLONE_MAX


## 召唤一个和自己一样(外观 / 招式 / 阶段)的分身。
func _spawn_clone() -> void:
	if not _can_clone():
		return
	var packed := load(CLONE_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var host := get_parent()
	if host == null:
		return
	var clone := packed.instantiate()
	if clone == null:
		return
	_clones_made += 1
	clone.set("is_clone", true)
	clone.set("base_health", maxi(1, int(round(float(base_health) * CLONE_HP_FACTOR))))
	clone.set("_phase", _phase)
	clone.set("hover_y", hover_y)
	host.add_child(clone)
	# 三个分身分别站在场地左 / 中 / 右,不会叠在一起
	var anchors := [0.28, 0.5, 0.72]
	var index := clampi(_clones_made - 1, 0, anchors.size() - 1)
	var x := lerpf(ROOM_MIN_X + 60.0, ROOM_MAX_X - 60.0, float(anchors[index]))
	clone.global_position = Vector2(x, global_position.y)
	clone.call("become_hostile")
	clone.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(clone, "modulate:a", 1.0, 0.4)
	_flash_body(Color(0.6, 0.9, 1.0))
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
	# 第 3 阶段起:每 30 秒召唤 4 只蘑菇小兵
	if _phase >= MUSHROOM_SUMMON_PHASE:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = MUSHROOM_SUMMON_INTERVAL
			_summon_mushrooms()
	# 第 4 阶段起:每 3 秒在随机位置引爆一次空间爆炸
	if _phase >= EXPLOSION_MIN_PHASE:
		_explosion_cd -= delta
		if _explosion_cd <= 0.0:
			_explosion_cd = EXPLOSION_INTERVAL
			_cast_space_explosion()
	# 第 5 阶段起:每 60 秒召唤一个分身(开局那一个在 become_hostile 里放)
	if _can_clone():
		_clone_cd -= delta
		if _clone_cd <= 0.0:
			_clone_cd = CLONE_INTERVAL
			_spawn_clone()
	# 第 3 阶段起:每 20 秒召唤一个骑士
	if _can_summon_knight():
		_knight_cd -= delta
		if _knight_cd <= 0.0:
			_knight_cd = KNIGHT_INTERVAL
			_summon_knight()
	# 第 4 阶段起:每 40 秒召唤一个飞行法师
	if _can_summon_wizard():
		_wizard_cd -= delta
		if _wizard_cd <= 0.0:
			_wizard_cd = WIZARD_INTERVAL
			_summon_wizard()


## 只有本体在第 3 阶段及以后才召唤骑士。
func _can_summon_knight() -> bool:
	return not is_clone and _phase >= KNIGHT_MIN_PHASE


## 从远离主角的一侧放一个骑士进场。
func _summon_knight() -> void:
	if _knights_alive() >= KNIGHT_MAX_ALIVE:
		return
	var host := get_parent()
	if host == null:
		return
	var knight := KNIGHT.instantiate()
	if knight == null:
		return
	host.add_child(knight)
	var from_left := true
	if _player != null and is_instance_valid(_player):
		from_left = _player.global_position.x > ROOM_CENTER_X
	var x := ROOM_MIN_X + 40.0 if from_left else ROOM_MAX_X - 40.0
	knight.global_position = Vector2(x, GROUND_Y)
	if knight.has_method("set_move_dir"):
		knight.call("set_move_dir", 1.0 if from_left else -1.0)
	knight.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(knight, "modulate:a", 1.0, 0.35)
	_flash_body(Color(0.9, 0.8, 0.6))


func _knights_alive() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("knight"):
		if is_instance_valid(node):
			n += 1
	return n


## 只有本体在第 4 阶段及以后才召唤飞行法师。
func _can_summon_wizard() -> bool:
	return not is_clone and _phase >= WIZARD_MIN_PHASE


## 在场地空中随机位置放一个飞行法师。
func _summon_wizard() -> void:
	if _wizards_alive() >= WIZARD_MAX_ALIVE:
		return
	var host := get_parent()
	if host == null:
		return
	var wizard := FLYING_WIZARD.instantiate()
	if wizard == null:
		return
	host.add_child(wizard)
	var x := randf_range(ROOM_MIN_X + 120.0, ROOM_MAX_X - 120.0)
	var y := randf_range(240.0, 420.0)
	wizard.global_position = Vector2(x, y)
	wizard.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(wizard, "modulate:a", 1.0, 0.4)
	_flash_body(Color(0.7, 0.8, 1.0))


func _wizards_alive() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("flying_wizard"):
		if is_instance_valid(node):
			n += 1
	return n


## 场地随机位置引爆一颗空间爆炸(先预警,炸开时碰到掉 4 点血)。
func _cast_space_explosion() -> void:
	var host := get_parent()
	if host == null:
		return
	var x := randf_range(ROOM_MIN_X + EXPLOSION_MARGIN, ROOM_MAX_X - EXPLOSION_MARGIN)
	var boom := SPACE_EXPLOSION.instantiate()
	host.add_child(boom)
	boom.global_position = Vector2(x, GROUND_Y)
	if boom.has_method("setup"):
		boom.call("setup", 0.05)


## 从场地左右两侧各走进 2 只蘑菇(场上超过上限就先不招)。
func _summon_mushrooms() -> void:
	var host := get_parent()
	if host == null:
		return
	var alive := get_tree().get_nodes_in_group("mushroom").size()
	var budget := mini(MUSHROOM_SUMMON_COUNT, MUSHROOM_MAX_ALIVE - alive)
	if budget <= 0:
		return
	_flash_body(Color(1.0, 0.78, 0.45))
	for i in budget:
		var from_left := i % 2 == 0
		var mush := MUSHROOM.instantiate()
		host.add_child(mush)
		mush.global_position = Vector2(
			ROOM_MIN_X - 46.0 if from_left else ROOM_MAX_X + 46.0,
			GROUND_Y - 6.0)
		if mush.has_method("set_move_dir"):
			mush.call("set_move_dir", 1.0 if from_left else -1.0)


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
	# 第 5 阶段起技能循环多一个「火焰弹连射」槽位
	var slots := 4 if _phase >= FIREBALL_MIN_PHASE else 3
	match _skill_step % slots:
		0:
			_cast_fire()
		1:
			_cast_lightning()
		2:
			# 第 1 阶段仍是地面波浪;第 2 阶段起换成蓝色火球四散
			if _phase == 0:
				_cast_water()
			else:
				_cast_orb_burst()
		_:
			_cast_fireball_volley()
	_skill_step += 1


func _cast_fire() -> void:
	_flash_body(Color(1.0, 0.7, 0.5))
	var px := _player.global_position.x
	for i in 3:
		var x := clampf(px + float(i - 1) * 150.0, ROOM_MIN_X, ROOM_MAX_X)
		var pillar := FIRE_PILLAR.instantiate()
		get_parent().add_child(pillar)
		pillar.global_position = Vector2(x, GROUND_Y)
		pillar.call("setup", 0.55 + float(i) * 0.12, _damage_bonus)


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
		lightning.call("setup", 0.5 + float(i) * 0.25, _damage_bonus)


func _cast_water() -> void:
	_flash_body(Color(0.5, 0.9, 1.0))
	var from_left := _player.global_position.x > ROOM_CENTER_X
	var wave := WATER_WAVE.instantiate()
	get_parent().add_child(wave)
	wave.global_position = Vector2(-180.0 if from_left else 1332.0, GROUND_Y)
	wave.call("setup", 1.0 if from_left else -1.0, _damage_bonus)


## 第 2 阶段起替代水墙:以 Boss 为圆心,向四周连发 3 轮蓝色火球。
func _cast_orb_burst() -> void:
	_flash_body(Color(0.5, 0.8, 1.0))
	for volley in ORB_VOLLEYS:
		_fire_orb_ring(volley)
		if volley >= ORB_VOLLEYS - 1:
			return
		await get_tree().create_timer(ORB_VOLLEY_GAP).timeout
		if not is_inside_tree() or _dead:
			return


## 一圈均匀铺开的蓝色火球,每轮错开一点角度。
func _fire_orb_ring(volley: int) -> void:
	var step := TAU / float(ORB_PER_VOLLEY)
	var offset := step * float(volley) / float(ORB_VOLLEYS)
	var origin := global_position + Vector2(0.0, -12.0)
	for i in ORB_PER_VOLLEY:
		var orb := BLUE_ORB.instantiate()
		get_parent().add_child(orb)
		orb.global_position = origin
		orb.call("setup", Vector2.RIGHT.rotated(step * float(i) + offset), ORB_DAMAGE + _damage_bonus)


## 第 5 阶段:连续 5 发火焰弹,每一发都瞄准主角当时的位置。
func _cast_fireball_volley() -> void:
	_flash_body(Color(1.0, 0.6, 0.25))
	for shot in FIREBALL_SHOTS:
		if not is_inside_tree() or _dead:
			return
		_fire_one_fireball()
		_body.position.y = -7.0
		var kick := create_tween()
		kick.tween_property(_body, "position:y", 0.0, 0.12)
		if shot >= FIREBALL_SHOTS - 1:
			return
		await get_tree().create_timer(FIREBALL_GAP).timeout


func _fire_one_fireball() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var host := get_parent()
	if host == null:
		return
	var origin := global_position + Vector2(0.0, -48.0)
	var aim := (_player.global_position + Vector2(0.0, -34.0) - origin).normalized()
	var ball := FIREBALL.instantiate()
	host.add_child(ball)
	ball.global_position = origin
	if ball.has_method("setup"):
		ball.call("setup", aim, FIREBALL_DAMAGE + _damage_bonus)


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
	if is_clone:
		# 分身不复活,打完就消失
		defeated.emit()
		queue_free()
		return
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
	# 进入下一阶段:血量翻倍、技能伤害 +2
	_phase += 1
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
