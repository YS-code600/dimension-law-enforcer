extends RefCounted
## 小怪死亡时的 token 掉落入口:在尸体位置爆出一把随机颜色的光点。

const SCENE := preload("res://levels/combat/token_dot.tscn")
## 每个小怪掉落的数量(默认值)
const COUNT := 8
## 第一个房间的普通小怪一次掉 24 个
const MOB_COUNT := 24
## 场景中同时存在的上限,防止长期战斗把光点堆爆
const MAX_ALIVE := 320
## 掉落点散布范围
const SPREAD := Vector2(14.0, 12.0)


## 在 center 处爆出一批光点,挂到 host 下(通常是当前关卡根节点)。
static func burst(host: Node, center: Vector2, count := COUNT) -> void:
	if host == null or count <= 0:
		return
	var alive := 0
	var tree := host.get_tree()
	if tree != null:
		alive = tree.get_nodes_in_group("token_dot").size()
	var budget := mini(count, MAX_ALIVE - alive)
	for i in budget:
		var dot := SCENE.instantiate()
		dot.call("setup", Color.from_hsv(randf(), randf_range(0.55, 0.95), 1.0))
		host.add_child(dot)
		dot.global_position = center + Vector2(
			randf_range(-SPREAD.x, SPREAD.x),
			randf_range(-SPREAD.y - 14.0, -SPREAD.y * 0.4)
		)
