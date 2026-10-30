extends Node
## 全局 token 计数:击败小怪掉落的彩色光点被拾取后 +1。
## 作为自动加载单例(Tokens)存在,所以换关卡也不会清零。

signal changed(total: int)

var total := 0


## 拾取 / 获得 token。
func add(amount := 1) -> void:
	if amount == 0:
		return
	total = maxi(0, total + amount)
	changed.emit(total)


## 清零(重新开始一整轮时使用)。
func reset() -> void:
	if total == 0:
		return
	total = 0
	changed.emit(total)
