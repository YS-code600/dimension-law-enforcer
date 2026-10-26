[gd_scene format=3 uid="uid://bqmtq4qrqpp45"]

[ext_resource type="Script" uid="uid://c7jasfwn3p4wt" path="res://levels/fire_room.gd" id="1_room"]
[ext_resource type="Texture2D" uid="uid://b2aaf3n62pmy5" path="res://levels/hazards/fire_room_ground.png" id="2_ground"]
[ext_resource type="PackedScene" path="res://player/player.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://levels/npc/violet_companion.tscn" id="4_companion"]
[ext_resource type="PackedScene" path="res://levels/hud.tscn" id="5_hud"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_ground"]
size = Vector2(1600, 160)

[sub_resource type="GDScript" id="GDScript_roam"]
script/source = "extends Node2D
## 挂在敌对形态的衍月身上:她变红之后由本组件接管位移,在房间内自由漂浮游走。
## 内嵌在 fire_room.tscn 里,避免外部脚本被 Team Create 覆盖后 Boss 变成站桩。

@export var area := Rect2(90.0, 330.0, 972.0, 210.0)
@export var margin := 70.0
@export var speed := 165.0
@export var smoothing := 3.6
@export var keep_min := 240.0
@export var keep_max := 620.0
@export var roam_interval := Vector2(1.3, 2.6)

var _boss: Node2D
var _player: Node2D
var _velocity := Vector2.ZERO
var _target := Vector2.ZERO
var _timer := 0.0


func _ready() -> void:
	_boss = get_parent() as Node2D
	if _boss == null:
		set_physics_process(false)
		return
	_player = get_tree().get_first_node_in_group(\"player\")
	_target = _boss.global_position


func _physics_process(delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if not bool(_boss.call(\"is_hostile\")):
		return
	if not _boss.is_visible_in_tree():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(\"player\")
		if _player == null:
			return

	_timer -= delta
	var to_player := _player.global_position - _boss.global_position
	var distance := Vector2(to_player.x, 0.0).length()
	if distance < keep_min * 0.6 or _timer <= 0.0 \\
			or _boss.global_position.distance_to(_target) < 36.0:
		_pick_target(distance, to_player)
		_timer = randf_range(roam_interval.x, roam_interval.y)

	var desired := Vector2.ZERO
	var to_target := _target - _boss.global_position
	if to_target.length() > 4.0:
		desired = to_target.normalized() * speed
	_velocity = _velocity.lerp(desired, 1.0 - exp(-smoothing * delta))
	_boss.global_position += _velocity * delta
	_clamp_inside()


func _pick_target(distance: float, to_player: Vector2) -> void:
	var bounds := _bounds()
	var away := 1.0 if to_player.x <= 0.0 else -1.0
	if distance < keep_min and distance > 0.001:
		_target = _clamp_point(_boss.global_position + Vector2(
			away * randf_range(280.0, 420.0), randf_range(-90.0, 80.0)), bounds)
		return
	if distance > keep_max:
		_target = _clamp_point(_boss.global_position + Vector2(
			signf(to_player.x) * randf_range(240.0, 360.0), randf_range(-80.0, 80.0)), bounds)
		return
	for i in 8:
		var candidate := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y))
		if candidate.distance_to(_boss.global_position) < 200.0:
			continue
		if absf(candidate.x - _player.global_position.x) < keep_min * 0.8:
			continue
		_target = candidate
		return
	_target = _clamp_point(_boss.global_position + Vector2(
		away * randf_range(240.0, 360.0), randf_range(-100.0, 80.0)), bounds)


func _bounds() -> Rect2:
	return Rect2(area.position + Vector2(margin, 0.0), area.size - Vector2(margin * 2.0, 0.0))


func _clamp_point(point: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y))


func _clamp_inside() -> void:
	var bounds := _bounds()
	var clamped := _clamp_point(_boss.global_position, bounds)
	if clamped != _boss.global_position:
		_boss.global_position = clamped
		_timer = 0.0
		_velocity *= 0.35
"

[sub_resource type="GDScript" id="GDScript_raid"]

[node name="FireRoom" type="Node2D" unique_id=652201136]
script = ExtResource("1_room")
metadata/_tc_uuid = "5081459290072831179"

[node name="Sky" type="ColorRect" parent="." unique_id=669270213]
offset_left = -400.0
offset_top = -400.0
offset_right = 1552.0
offset_bottom = 760.0
mouse_filter = 2
color = Color(0.0431373, 0.0470588, 0.0784314, 1)
metadata/_tc_uuid = "3901803220105670790"

[node name="GroundTex" type="TextureRect" parent="." unique_id=603344482]
texture_filter = 1
texture_repeat = 2
offset_left = -160.0
offset_top = 600.0
offset_right = 1312.0
offset_bottom = 760.0
mouse_filter = 2
texture = ExtResource("2_ground")
stretch_mode = 2
metadata/_tc_uuid = "44147266741428636"

[node name="Ground" type="StaticBody2D" parent="." unique_id=1470857908]
position = Vector2(576, 680)
metadata/_tc_uuid = "3217379709532897276"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground" unique_id=1165575221]
shape = SubResource("RectangleShape2D_ground")
metadata/_tc_uuid = "6359832170899263257"

[node name="Player" parent="." unique_id=348066979 instance=ExtResource("3_player")]
position = Vector2(420, 600)
metadata/_tc_uuid = "8184970228920027133"

[node name="VioletCompanion" parent="." unique_id=144048309 instance=ExtResource("4_companion")]
position = Vector2(520, 600)
start_following = true
metadata/_tc_uuid = "6812097543759732862"

[node name="BossRoam" type="Node2D" parent="VioletCompanion" unique_id=283677009]
script = SubResource("GDScript_roam")
metadata/_tc_uuid = "5359009104166640825"

[node name="TankRaid" type="Node2D" parent="." unique_id=1810379957]
script = SubResource("GDScript_raid")
metadata/_tc_uuid = "1121772967955104774"

[node name="Flames" type="Node2D" parent="." unique_id=139693845]
z_index = 8
metadata/_tc_uuid = "6250910862830981160"

[node name="HUD" parent="." unique_id=780732372 instance=ExtResource("5_hud")]
metadata/_tc_uuid = "3224579263149548788"

[node name="Fade" type="CanvasLayer" parent="." unique_id=720930345]
layer = 10
metadata/_tc_uuid = "6539800850082899399"

[node name="Rect" type="ColorRect" parent="Fade" unique_id=947346386]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0, 0, 0, 1)
metadata/_tc_uuid = "3037056206700795912"
