extends Node2D
## 主角的主动技能(挂在 Player 下作为子节点,不动玩家主脚本):
##   U = 回复:立刻恢复 80% 血量
##   I = 混沌爆炎:2 秒内朝面向散射 20 发火焰弹,每发 80 伤害
## 能不能按取决于 PlayerStats 里的「解锁 + 装配」状态。

const FIREBALL := preload("res://player/skills/chaos_fireball.tscn")
const TORNADO := preload("res://player/skills/tornado.tscn")
const UI_FONT := preload("res://levels/ui/ui_font.gd")

const HEAL_PERCENT := 0.8
const HEAL_COOLDOWN := 25.0
const BLAZE_DAMAGE := 5
const BLAZE_SHOTS := 20
const BLAZE_DURATION := 2.0
const BLAZE_COOLDOWN := 30.0
## 散射角度:以面向为中心左右各摊开这么多弧度
const BLAZE_SPREAD := 0.5
## 每发再随机抖一点角度
const BLAZE_JITTER := 0.06

## 龙卷风:锁动作 2 秒(期间无敌),冷却 30 秒
const TORNADO_LOCK := 2.0
const TORNADO_DAMAGE := 250
const TORNADO_COOLDOWN := 30.0

## 假死:Q 键,冷却 8 秒;倒地姿态、免疫伤害,按任意攻击键起身
const FEIGN_LINE := "啊，我死啦"
const FEIGN_COOLDOWN := 8.0

## 闪现:向面向瞬移火雨房间宽度的一半,空中也能用,不会穿过场地两侧;
## 每次消耗 10 token,瞬移期间无敌,无冷却
const BLINK_ROOM_WIDTH := 1152.0
const BLINK_FRACTION := 0.5
## 贴边留的余量,免得卡进墙里
const BLINK_MARGIN := 44.0
## 每次闪现消耗的 token
const BLINK_COST := 10
## 闪现后的无敌时长
const BLINK_INVULN := 0.6
## 闪现掠过敌人的伤害 / 判定盒高度与两端余量
const BLINK_DAMAGE := 10
const BLINK_HIT_HEIGHT := 96.0
const BLINK_HIT_PAD := 90.0

var _heal_cd := 0.0
var _blaze_cd := 0.0
var _tornado_cd := 0.0
var _feign_cd := 0.0
var _blazing := false


func _physics_process(delta: float) -> void:
	_heal_cd = maxf(0.0, _heal_cd - delta)
	_blaze_cd = maxf(0.0, _blaze_cd - delta)
	_tornado_cd = maxf(0.0, _tornado_cd - delta)
	_feign_cd = maxf(0.0, _feign_cd - delta)
	var player := get_parent() as Node2D
	if player == null:
		return
	if bool(player.get("_won")) or bool(player.get("_walk_in_active")):
		return
	if int(player.get("health")) <= 0:
		return
	if Input.is_action_just_pressed("skill_1"):
		_cast_slot(0, player)
	if Input.is_action_just_pressed("skill_2"):
		_cast_slot(1, player)
	if Input.is_action_just_pressed("skill_3"):
		_cast_feign(player)


## 技能基础数值按「加强技能」倍率放大。
func _scaled(base: int) -> int:
	return maxi(1, int(round(float(base) * PlayerStats.skill_scale())))


## 冷却按「技能冷却-20%」倍率缩短。
func _cd(base: float) -> float:
	return base * PlayerStats.cd_scale()


## 释放某个框(0 = 框一 / U,1 = 框二 / I)里装的技能。
func _cast_slot(index: int, player: Node2D) -> void:
	var key := PlayerStats.slot_skill(index)
	if key == "":
		return
	match key:
		"heal":
			_cast_heal(player)
		"blaze":
			_cast_blaze(player)
		"tornado":
			_cast_tornado(player)
		"blink":
			_cast_blink(player)
		_:
			pass


# ---------------------------------------------------------------- 回复(U)

## 立刻回复 80% 血量;血量满了就不浪费冷却。
func _cast_heal(player: Node2D) -> void:
	if _heal_cd > 0.0:
		return
	var max_hp := int(player.get("max_health"))
	var hp := int(player.get("health"))
	if hp >= max_hp:
		return
	_heal_cd = _cd(HEAL_COOLDOWN)
	var amount := int(round(float(max_hp) * HEAL_PERCENT * PlayerStats.skill_scale()))
	var target := mini(max_hp, hp + amount)
	player.set("health", target)
	player.emit_signal("health_changed", target, max_hp)
	_pop_text(player.global_position + Vector2(0.0, -118.0),
		"+%d HP" % (target - hp), Color(0.55, 1.0, 0.72), 26)


# ---------------------------------------------------------------- 混沌爆炎(I)

## 2 秒内朝面向散射 20 发火焰弹。
func _cast_blaze(player: Node2D) -> void:
	if _blaze_cd > 0.0 or _blazing:
		return
	var host := player.get_parent()
	if host == null:
		return
	_blaze_cd = _cd(BLAZE_COOLDOWN)
	_blazing = true
	var facing := 1.0 if float(player.get("_facing")) >= 0.0 else -1.0
	var gap := BLAZE_DURATION / float(BLAZE_SHOTS)
	for i in BLAZE_SHOTS:
		if not is_inside_tree() or not is_instance_valid(player):
			break
		var t := float(i) / float(maxi(1, BLAZE_SHOTS - 1))
		var angle := lerpf(-BLAZE_SPREAD * 0.5, BLAZE_SPREAD * 0.5, t) \
			+ randf_range(-BLAZE_JITTER, BLAZE_JITTER)
		var dir := Vector2(facing, 0.0).rotated(angle)
		var ball := FIREBALL.instantiate()
		host.add_child(ball)
		ball.global_position = player.global_position + Vector2(facing * 34.0, -58.0)
		ball.call("setup", dir, _scaled(BLAZE_DAMAGE))
		await get_tree().create_timer(gap).timeout
	_blazing = false


# ---------------------------------------------------------------- 龙卷风

## 锁 K 攻击动画 2 秒(期间无敌),在主角处放出龙卷风,朝面向推进 Boss 房间 3/4。
func _cast_tornado(player: Node2D) -> void:
	if _tornado_cd > 0.0:
		return
	var host := player.get_parent()
	if host == null:
		return
	_tornado_cd = _cd(TORNADO_COOLDOWN)
	var facing := 1.0 if float(player.get("_facing")) >= 0.0 else -1.0
	if player.has_method("play_pose"):
		player.call("play_pose", &"attack2", TORNADO_LOCK)
	var tornado := TORNADO.instantiate()
	host.add_child(tornado)
	tornado.global_position = player.global_position + Vector2(facing * 26.0, 0.0)
	tornado.call("setup", Vector2(facing, 0.0), _scaled(TORNADO_DAMAGE))


# ---------------------------------------------------------------- 闪现

## 朝面向瞬移火雨房间宽度的一半(576px);空中也能用;
## 场地两侧(相机 limit = 房间边界)和墙都不会穿过去。
func _cast_blink(player: Node2D) -> void:
	var facing := 1.0 if float(player.get("_facing")) >= 0.0 else -1.0
	var from := player.global_position
	var target := from + Vector2(facing * BLINK_ROOM_WIDTH * BLINK_FRACTION, 0.0)

	# 1) 场地左右边界
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null and cam.limit_right > cam.limit_left:
		target.x = clampf(target.x,
			float(cam.limit_left) + BLINK_MARGIN, float(cam.limit_right) - BLINK_MARGIN)

	# 2) 墙:沿路径打一条射线,撞到就停在墙前
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		from + Vector2(0.0, -40.0), target + Vector2(0.0, -40.0), 1)
	if player is CollisionObject2D:
		query.exclude = [(player as CollisionObject2D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var wall_x := float((hit.get("position") as Vector2).x)
		target.x = wall_x - facing * 34.0

	if is_equal_approx(target.x, from.x):
		return
	# 每次闪现消耗 token;不够就闪不了
	var tokens := get_node_or_null("/root/Tokens")
	if tokens == null or int(tokens.get("total")) < BLINK_COST:
		return
	tokens.call("add", -BLINK_COST)
	player.set("velocity", Vector2.ZERO)
	player.global_position = target
	# 瞬移期间无敌
	var now := float(player.call("_now"))
	player.set("_invuln_until", maxf(float(player.get("_invuln_until")), now + BLINK_INVULN))
	# 掠过路径上的敌人:每个 10 点伤害
	_blink_strike(player, from, target)
	_blink_fx(player, from, target)


## 闪现路径上的敌人各吃一次 10 点伤害。
func _blink_strike(player: Node2D, from: Vector2, to: Vector2) -> void:
	var dmg := PlayerStats.hit(_scaled(BLINK_DAMAGE))
	var rect := RectangleShape2D.new()
	rect.size = Vector2(absf(to.x - from.x) + BLINK_HIT_PAD, BLINK_HIT_HEIGHT)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, Vector2(
		(from.x + to.x) * 0.5, player.global_position.y - 48.0))
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen := {}
	var dir := int(signf(to.x - from.x))
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var area := hit.get("collider") as Area2D
		if area == null:
			continue
		var target = area.get_parent()
		if target == null or not is_instance_valid(target):
			continue
		if not target.is_in_group("enemy") or not target.has_method("take_hit"):
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		# 延迟一帧结算:命中发生在物理查询刷新期间,直接改场景会报错
		target.call_deferred("take_hit", dmg, dir, 240.0, -60.0)


func _blink_fx(player: Node2D, from: Vector2, to: Vector2) -> void:
	var sprite := player.get_node_or_null("Sprite") as CanvasItem
	if sprite != null:
		sprite.modulate = Color(0.6, 0.95, 1.0, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	var host := get_tree().current_scene
	if host == null:
		host = player.get_parent()
	if host == null:
		return
	var line := Line2D.new()
	line.width = 7.0
	line.default_color = Color(0.55, 0.95, 1.0, 0.7)
	line.z_index = 20
	line.points = PackedVector2Array([
		from + Vector2(0.0, -50.0), to + Vector2(0.0, -50.0),
	])
	host.add_child(line)
	var tw2 := create_tween()
	tw2.tween_property(line, "modulate:a", 0.0, 0.3)
	tw2.tween_callback(line.queue_free)


# ---------------------------------------------------------------- 假死(Q)

## 倒地并上字幕「啊，我死啦」,保持死亡姿势且免疫伤害,直到使用任意攻击键。
func _cast_feign(player: Node2D) -> void:
	if _feign_cd > 0.0 or bool(player.get("_feigning")):
		return
	# 火雨房间解锁手枪后 Q 是「举枪自尽」的剧情键,不和假死抢
	var scene := get_tree().current_scene
	if scene != null:
		var pistol: Variant = scene.get("_pistol_unlocked")
		if pistol != null and bool(pistol):
			return
	_feign_cd = _cd(FEIGN_COOLDOWN)
	player.call("feign_death")
	_show_subtitle(player.global_position + Vector2(0.0, -152.0), FEIGN_LINE)


## 主角上方的台词字幕。
func _show_subtitle(pos: Vector2, text: String) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 40
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(240.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT.make(false))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 7)
	host.add_child(label)
	label.global_position = pos + Vector2(-120.0, 0.0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


# ---------------------------------------------------------------- 飘字

func _pop_text(pos: Vector2, text: String, color: Color, size: int) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 30
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	host.add_child(label)
	label.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", pos.y - 54.0, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
