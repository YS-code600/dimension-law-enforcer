# 进度同步 / SYNC NOTES

更新时间：2026-10-24 15:25（Asia/Shanghai）
本侧工作区：`D:/Godot project/dimension-law-enforcer`

---

## 一、本侧已完成的内容（全部已在本机验证）

| # | 功能 | 主要文件 |
|---|------|----------|
| 1 | 火雨房间 Boss（衍月）会自由游走 | `player/player.tscn`（内嵌脚本 `_tick_roam`） |
| 2 | **S 弹反**：蓝色圆环、反弹 120px 内弹幕、3 秒冷却、弹幕变青色光弹反打 | `player/player.tscn`、`player/character/effect/reflect_ring.*`、`reflected_shot.*` |
| 3 | 世界主线（world_main）与衍月交互后播报「防火墙故障，有不明人员尝试访问系统内核」 | `levels/npc/companion_dialogue.gd`、`levels/world_main.tscn` |
| 4 | 火雨房间第二阶段：击倒衍月立刻开进 1 辆坦克，之后每 30 秒 1 辆，150 血、会开炮、会爆炸 | `player/player.tscn`、`levels/enemies/tank.*`、`levels/combat/tank_boom.*`、`levels/enemies/tank_body.png`、`levels/combat/boom_strip.png` |
| 5 | 顶部增援提示：倒计时「敌方装甲增援：N 秒」/ 警告「警告：敌方坦克进入战场」 | `player/player.tscn` |
| 6 | HUD 按键提示补充「S 弹反(3s冷却)」 | `levels/hud.tscn` |

> 说明：火雨房间的 Boss 游走与坦克逻辑都放在**主角内嵌脚本**里（`player.tscn`），因为这些内容放在 `fire_room.tscn` 的内嵌脚本里时曾被同步清空过一次。

## 二、需要对面注意（避免互相覆盖）

1. `levels/fire_room.tscn` 已重建为干净版本（62 行，无内嵌脚本、无 BossRoam / TankRaid 节点）。**请不要用旧版本覆盖它**，否则 Boss 游走和坦克会失效。
2. `player/player.tscn`、`player/player.gd` 是同一份脚本（内嵌 + 外部副本），改动请两边同步，或只改 `player.tscn` 后告诉我。
3. 历史冲突（供参考）：
   - `player.gd`、`enemy_bullet.gd`、`blue_orb.gd`、`violet_companion.gd`、`fire_room.gd` 曾被同步回旧版；
   - `fire_room.tscn` 的内嵌 `GDScript_raid` 被清空过；
   - `boss_roam.gd` 被替换成 4 行占位脚本。
4. 目前**已取消所有只读保护**，文件都可写。为了不互相打断，建议：动上面这些文件前先在聊天里说一声。

## 三、本侧没有动过的东西

- `levels/enemies/enemy_bullet.gd`、`levels/npc/blue_orb.gd`、`levels/npc/violet_companion.gd`、`levels/fire_room.gd`：保持你们最后一次同步的版本。
- 所有美术资源（除新增的 `tank_body.png`、`boom_strip.png`）。

## 四、需要对面回复

1. 你们侧最近改过哪些文件？（尤其 `levels/fire_room.gd`、`violet_companion.gd`、`hud.tscn`）
2. 是否有需要合并的改动？如果你们有新版 `fire_room.tscn`，请先发给我，我来合并，避免直接覆盖。
3. 如果还要继续实时同步，能否约定文件归属：本侧负责 `player.tscn`、火雨房间相关；你们负责其余关卡？
