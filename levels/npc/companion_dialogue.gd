extends Node2D
## 同行缔结后的系统播报:在衍月头顶弹出打字机效果的文字气泡。
## 独立成组件,不改 violet_companion.gd(那份脚本会被 Team Create 覆盖)。

@export_multiline var message := "防火墙故障，有不明人员尝试访问系统内核"
## 每秒打出的字数。
@export var type_speed := 26.0
## 打完字后停留的秒数。
@export var hold_time := 3.2
@export var bubble_width := 340.0
## 气泡相对角色脚底的偏移。
@export var head_offset := Vector2(0.0, -178.0)

var _companion: Node
var _was_following := false
var _fired := false


func _ready() -> void:
	_companion = get_parent()
	if _companion != null and _companion.has_method("is_following"):
		_was_following = bool(_companion.call("is_following"))
	set_process(_companion != null)


func _process(_delta: float) -> void:
	if _fired or _companion == null or not is_instance_valid(_companion):
		return
	if not _companion.has_method("is_following"):
		return
	var following := bool(_companion.call("is_following"))
	if following and not _was_following:
		_say()
	_was_following = following


## 手动触发一次(方便调试或其他剧情节点调用)。
func say_once() -> void:
	_say()


func _say() -> void:
	if _fired:
		return
	_fired = true
	# 关卡内不显示文字(仅保留控制台记录)
	print(message)

