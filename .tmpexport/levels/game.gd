extends Node2D
## 维度切换世界:主线世界与平行世界同时加载。
## 主角按 Q 在两者间切换,保持 X 坐标并落到目标世界对应地面的上方,冷却 5 秒。

const COOLDOWN := 5.0
const STAND_OFFSET := 45.0  # 胶囊底部半高 43px,再留 2px 让物理自行落稳

@onready var worlds: Array[Node2D] = [$WorldMain, $WorldParallel]
@onready var player: CharacterBody2D = $Player
@onready var dim_label: Label = $DimLabel
@onready var flash: ColorRect = $Flash

var _active := 0
var _cooldown_left := 0.0
var _limits: Dictionary = {}
var _switching := false


func _ready() -> void:
	for i in worlds.size():
		var w := worlds[i]
		var w_player := w.get_node_or_null("Player")
		if w_player:
			var cam := w_player.get_node_or_null("Camera2D")
			if cam:
				cam.enabled = false
				_limits[i] = Rect2(
					cam.limit_left, cam.limit_top,
					cam.limit_right - cam.limit_left,
					cam.limit_bottom - cam.limit_top
				)
			w_player.collision_layer = 0
			w_player.collision_mask = 0
			w_player.queue_free()
		var w_hud := w.get_node_or_null("HUD")
		if w_hud:
			w_hud.queue_free()
	_set_world_active(0, true)
	_set_world_active(1, false)
	player.global_position = worlds[0].get_node("PlayerSpawn").position
	_apply_limits(0)
	if player.has_signal("dimension_shot_finished"):
		player.connect("dimension_shot_finished", _on_dimension_shot_finished)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_dimension") and _cooldown_left <= 0.0 and not _switching:
		_begin_switch()


func _begin_switch() -> void:
	if _switching or _cooldown_left > 0.0:
		return
	_switching = true
	var started: bool = player.call("play_dimension_shot")
	if not started:
		_switching = false


func _on_dimension_shot_finished() -> void:
	_switching = false
	_switch()


func _switch() -> void:
	if _cooldown_left > 0.0:
		return
	var target := 1 - _active
	var x := player.global_position.x
	var ground_y := _ground_y_at(worlds[target], x)
	_set_world_active(_active, false)
	_set_world_active(target, true)
	_active = target
	player.velocity = Vector2.ZERO
	if ground_y != INF:
		player.global_position = Vector2(x, ground_y - STAND_OFFSET)
	_apply_limits(target)
	_cooldown_left = COOLDOWN
	_play_flash()


## 目标世界里 x 处最高的可站立表面 y(越小越高)。
func _ground_y_at(world: Node2D, x: float) -> float:
	var best := INF
	for child in world.get_node("Terrain").get_children():
		if not (child is StaticBody2D):
			continue
		var pos: Vector2 = child.position
		if child.has_method("_points"):  # 斜坡
			var run: float = child.get("run")
			var rise: float = child.get("rise")
			var kind: String = child.get("kind")
			if x < pos.x or x > pos.x + run:
				continue
			var lx := clampf(x - pos.x, 0.0, run)
			var surface: float = pos.y
			if kind == "down":
				surface = pos.y - rise + (lx / run) * rise
			else:
				surface = pos.y - (lx / run) * rise
			best = minf(best, surface)
		else:  # 平台
			var sz = child.get("size")
			if sz == null:
				continue
			var half_w: float = sz.x * 0.5
			if x < pos.x - half_w or x > pos.x + half_w:
				continue
			var top: float = pos.y - sz.y * 0.5
			best = minf(best, top)
	return best


func _set_world_active(idx: int, on: bool) -> void:
	var w := worlds[idx]
	w.visible = on
	# CanvasLayer(背景层)不受父 Node2D 可见性影响,需单独跟随世界开关
	for child in w.get_children():
		if child is CanvasLayer:
			child.visible = on
	w.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	var layer := 1 if on else 0
	for child in w.get_node("Terrain").get_children():
		child.set_deferred("collision_layer", layer)
		child.set_deferred("collision_mask", layer)


## 切换世界时同步根玩家的相机边界。
func _apply_limits(idx: int) -> void:
	if not _limits.has(idx):
		return
	var r: Rect2 = _limits[idx]
	var cam := player.get_node("Camera2D") as Camera2D
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.position.x + r.size.x)
	cam.limit_bottom = int(r.position.y + r.size.y)
	cam.reset_smoothing()


func _update_label() -> void:
	if _switching:
		dim_label.text = "维度跃迁..."
		dim_label.modulate.a = 0.95
	elif _cooldown_left > 0.0:
		dim_label.text = "维度冷却: %.1fs" % _cooldown_left
		dim_label.modulate.a = 0.95
	else:
		dim_label.text = "[Q] 进入平行世界"
		dim_label.modulate.a = 0.55


func _play_flash() -> void:
	flash.modulate.a = 0.35
	flash.visible = true
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: flash.visible = false)
