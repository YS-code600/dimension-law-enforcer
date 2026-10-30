extends Node2D
## 手雷爆炸:播放 BOOMPREW 五帧爆炸、BangMid 音效,并对范围内敌人/木箱造成伤害。

const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")
const DAMAGE_MASK := 4 | 16
const MAX_TARGETS := 24

@export var damage := 32
@export var blast_radius := 135.0
@export var knockback := 430.0
@export var launch := -280.0

var _hit_ids := {}
var _boom_finished := false

@onready var _boom: AnimatedSprite2D = $Boom
@onready var _glow: Sprite2D = $Glow
@onready var _bang: AudioStreamPlayer2D = $Bang


func _ready() -> void:
	_boom.play()
	_boom.animation_finished.connect(_on_boom_finished)
	_bang.pitch_scale = randf_range(0.96, 1.04)
	_bang.play()
	_animate_glow()
	_apply_blast.call_deferred()
	_apply_camera_shake.call_deferred()
	_spawn_embers()
	# 音效比爆炸画面长,等 BangMid 播完再销毁节点,避免尾音被截断。
	var life := 0.85
	if _bang.stream != null:
		life = maxf(life, _bang.stream.get_length() + 0.08)
	get_tree().create_timer(life).timeout.connect(queue_free)


func _apply_blast() -> void:
	var shape := CircleShape2D.new()
	shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = DAMAGE_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(query, MAX_TARGETS)
	for hit in results:
		var area := hit.get("collider") as Area2D
		if area == null:
			continue
		var target = area.get_parent()
		if target == null or target.is_queued_for_deletion():
			continue
		if target is CanvasItem and not (target as CanvasItem).is_visible_in_tree():
			continue
		var target_id: int = target.get_instance_id()
		if _hit_ids.has(target_id):
			continue
		_hit_ids[target_id] = true

		var push_dir := signi(target.global_position.x - global_position.x)
		if push_dir == 0:
			push_dir = 1
		if target.is_in_group("projectile"):
			target.call("pop")
			continue
		if not target.has_method("take_hit"):
			continue

		var distance: float = target.global_position.distance_to(global_position)
		var falloff := clampf(1.0 - distance / (blast_radius * 1.6), 0.45, 1.0)
		target.call(
			"take_hit",
			PlayerStats.hit(maxi(1, int(round(float(damage) * falloff)))),
			push_dir,
			knockback * falloff,
			launch
		)
		_spawn_hit_spark(Vector2(target.global_position.x, target.global_position.y - 48.0), 1.6)


func _apply_camera_shake() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_camera_shake"):
		player.call("add_camera_shake", 1.15)


func _animate_glow() -> void:
	_glow.scale = Vector2(0.3, 0.3)
	_glow.modulate.a = 0.0
	var grow := create_tween().set_parallel(true)
	grow.tween_property(_glow, "scale", Vector2(3.4, 3.4), 0.46) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_property(_glow, "modulate:a", 0.8, 0.05)
	var fade := create_tween()
	fade.tween_interval(0.1)
	fade.tween_property(_glow, "modulate:a", 0.0, 0.38)


func _spawn_embers() -> void:
	for i in 4:
		var angle := randf_range(-PI, 0.0)
		var distance := randf_range(12.0, 62.0)
		_spawn_hit_spark(Vector2(cos(angle), sin(angle) * 0.55) * distance + Vector2(0, -24), randf_range(0.9, 1.7))


func _spawn_hit_spark(pos: Vector2, spark_scale: float) -> void:
	var spark := HIT_SPARK.instantiate()
	get_parent().add_child(spark)
	spark.global_position = global_position + pos
	spark.scale = Vector2.ONE * spark_scale
	spark.rotation = randf_range(-0.4, 0.4)


func _on_boom_finished() -> void:
	_boom_finished = true
	_boom.visible = false
