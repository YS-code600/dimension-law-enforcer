extends Node
## 主角的成长数值:变强界面买到的强化都记在这里(自动加载,跨关卡保留)。
## 五条强化线:攻击伤害 / 血量上限 / 无敌时间 / 弹反范围 / 技能效果,
## 都是 4 级、价格 24 / 48 / 96 / 192,越买越强。

signal changed

## 每条线:每级倍率、等级上限、逐级价格。
const UPGRADES := {
	"attack": {"step": 1.5, "max": 4, "costs": [24, 48, 96, 192]},
	"health": {"step": 1.5, "max": 4, "costs": [24, 48, 96, 192]},
	"invuln": {"step": 1.3, "max": 4, "costs": [24, 48, 96, 192]},
	"parry": {"step": 1.3, "max": 4, "costs": [24, 48, 96, 192]},
	"skill": {"step": 1.3, "max": 4, "costs": [24, 48, 96, 192]},
	"cd": {"step": 0.8, "max": 4, "costs": [24, 48, 96, 192]},
}

## 每条线已买的等级
var levels := {"attack": 0, "health": 0, "invuln": 0, "parry": 0, "skill": 0, "cd": 0}

## 主动技能:每条 100 token 解锁;最多只能携带 2 个,
## 依次装进框一(按键 U)和框二(按键 I)。
const SKILL_COST := 100
const SKILL_SLOTS := 2
## 技能表:加新技能往这里加一行就行(顺序 = 界面上列出的顺序)。
## cd = 冷却秒数,0 表示无冷却。
const SKILLS := {
	"heal": {"name": "回复", "label": "回复：立刻恢复 80% 血量", "cost": 100, "cd": 25.0},
	"blaze": {"name": "混沌爆炎", "label": "混沌爆炎：2 秒内 20 发火焰弹，每发 5", "cost": 100, "cd": 30.0},
	"tornado": {"name": "龙卷风", "label": "龙卷风：蓄力 2 秒无敌，横扫 3/4 场地（250）", "cost": 100, "cd": 30.0},
	"blink": {"name": "闪现", "label": "闪现：瞬移半场，撞到敌人 10 伤害，10 token/次，期间无敌", "cost": 50, "cd": 0.0},
}
var skill_unlocked := {"heal": false, "blaze": false, "tornado": false, "blink": false}
## 已装配的技能(长度 2,空槽是空字符串)。框一 = U,框二 = I
var skill_slots: Array = ["", ""]


func has_upgrade(key: String) -> bool:
	return UPGRADES.has(key)


func level_of(key: String) -> int:
	return int(levels.get(key, 0))


func max_level_of(key: String) -> int:
	return int((UPGRADES.get(key, {}) as Dictionary).get("max", 0))


func step_of(key: String) -> float:
	return float((UPGRADES.get(key, {}) as Dictionary).get("step", 1.0))


## 当前倍率(1.0 = 未强化),按等级乘法叠加。
func multiplier(key: String) -> float:
	return pow(step_of(key), float(level_of(key)))


## 下一级价格;满级返回 -1。
func next_cost(key: String) -> int:
	var cfg: Dictionary = UPGRADES.get(key, {})
	if cfg.is_empty():
		return -1
	var level := level_of(key)
	var costs: Array = cfg.get("costs", [])
	if level >= int(cfg.get("max", 0)) or level >= costs.size():
		return -1
	return int(costs[level])


## 花 token 买一级;token 不够或已满级返回 false。
func buy(key: String) -> bool:
	var cost := next_cost(key)
	if cost < 0:
		return false
	var tokens := get_node_or_null("/root/Tokens")
	if tokens == null or int(tokens.get("total")) < cost:
		return false
	tokens.call("add", -cost)
	levels[key] = level_of(key) + 1
	changed.emit()
	return true


# ---------------------------------------------------------------- 主动技能

## 技能表里的所有 key(保持表里的顺序)
func skill_keys() -> Array:
	var out: Array = []
	for key in SKILLS.keys():
		out.append(String(key))
	return out


func skill_label(key: String) -> String:
	return String((SKILLS.get(key, {}) as Dictionary).get("label", key))


func skill_name(key: String) -> String:
	return String((SKILLS.get(key, {}) as Dictionary).get("name", key))


## 解锁这个技能要多少 token
func skill_cost(key: String) -> int:
	return int((SKILLS.get(key, {}) as Dictionary).get("cost", SKILL_COST))


## 冷却秒数(0 = 无冷却)
func skill_cd(key: String) -> float:
	return float((SKILLS.get(key, {}) as Dictionary).get("cd", 0.0))


## 某个技能装在哪个框(0 = 框一,1 = 框二,-1 = 没装)
func slot_of(key: String) -> int:
	for i in skill_slots.size():
		if String(skill_slots[i]) == key:
			return i
	return -1


## 框里装的技能 key(空槽返回 "")
func slot_skill(index: int) -> String:
	if index < 0 or index >= skill_slots.size():
		return ""
	return String(skill_slots[index])


## 下一个空槽的下标;满了返回 -1
func next_free_slot() -> int:
	for i in skill_slots.size():
		if String(skill_slots[i]) == "":
			return i
	return -1


## "locked" / "unlocked" / "equipped"
func skill_state(key: String) -> String:
	if slot_of(key) >= 0:
		return "equipped"
	if is_skill_unlocked(key):
		return "unlocked"
	return "locked"


func is_skill_unlocked(key: String) -> bool:
	return bool(skill_unlocked.get(key, false))


func is_skill_equipped(key: String) -> bool:
	return slot_of(key) >= 0


## 花 token 解锁技能。
func unlock_skill(key: String) -> bool:
	if not SKILLS.has(key) or is_skill_unlocked(key):
		return false
	var cost := skill_cost(key)
	var tokens := get_node_or_null("/root/Tokens")
	if tokens == null or int(tokens.get("total")) < cost:
		return false
	tokens.call("add", -cost)
	skill_unlocked[key] = true
	changed.emit()
	return true


## 装进第一个空框;两个框都满了返回 false。
func equip_skill(key: String) -> bool:
	if not is_skill_unlocked(key) or is_skill_equipped(key):
		return false
	var slot := next_free_slot()
	if slot < 0:
		return false
	skill_slots[slot] = key
	changed.emit()
	return true


## 从框里卸下。
func unequip_skill(key: String) -> bool:
	var slot := slot_of(key)
	if slot < 0:
		return false
	skill_slots[slot] = ""
	changed.emit()
	return true


## 点了技能条目:已装 → 卸下;没装 → 装进第一个空框。
func toggle_skill(key: String) -> bool:
	if is_skill_equipped(key):
		return unequip_skill(key)
	return equip_skill(key)


# ---------------------------------------------------------------- 各条线的倍率

## 主角攻击伤害(拳脚 / 飞刀 / 手雷 / 反弹子弹都走这里)
func hit(base_damage: int) -> int:
	var scale := multiplier("attack")
	if scale == 1.0:
		return base_damage
	return maxi(1, int(round(float(base_damage) * scale)))


## 血量上限倍率
func health_scale() -> float:
	return multiplier("health")


## 受伤后无敌时长倍率
func invuln_scale() -> float:
	return multiplier("invuln")


## 弹反半径倍率
func parry_scale() -> float:
	return multiplier("parry")


## 技能效果倍率(回复量 / 火焰弹伤害 / 龙卷风伤害)
func skill_scale() -> float:
	return multiplier("skill")


## 技能冷却倍率(1.0 → 0.8 → 0.64 ...)
func cd_scale() -> float:
	return multiplier("cd")


## 清空成长(重新开档时用)。
func reset() -> void:
	for key in levels.keys():
		levels[key] = 0
	for key in skill_unlocked.keys():
		skill_unlocked[key] = false
	for i in skill_slots.size():
		skill_slots[i] = ""
	changed.emit()
