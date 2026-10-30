extends Node
## Boss 战进度:在火雨房间死掉后记住打到第几阶段。
## 回到第一房间、再从传送门进 Boss 房间时,直接从那一阶段继续。

signal changed

const MAX_PHASE := 5

## 下次进入 Boss 房间从第几阶段开始(1 = 从头打)
var phase := 1
## 是否刚从 Boss 房间退回来(第一房间据此把主角放到传送门前)
var returning := false


## 记录死亡时打到第几阶段。
func remember_phase(value: int) -> void:
	phase = clampi(value, 1, MAX_PHASE)
	returning = true
	changed.emit()


## 取一次「刚退回来」标记(取完即清)。
func take_returning() -> bool:
	var was := returning
	returning = false
	return was


## 打完之后清空进度。
func clear() -> void:
	phase = 1
	returning = false
	changed.emit()
