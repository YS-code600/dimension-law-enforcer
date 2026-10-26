# 改动保护（.protected）

这个工程装了 **Team Create** 插件（`addons/team_create`）。它会把同一个会话里其他人编辑器中的文件
同步过来，本对话期间已多次把 `player.gd`、`enemy_bullet.gd`、`blue_orb.gd`、
`violet_companion.gd`、`fire_room.gd` 覆盖成旧版，还把 `fire_room.tscn` 的内嵌脚本清空过。

## 现在做了什么

1. `snapshot/` 保存了本对话所有改动文件的原始副本（SHA256 比对，见 `guard.ps1 status`）。
2. 这些脚本/场景已设为**只读**；Godot 的 `FileAccess.open(WRITE)` 对只读文件会失败（实测 `err=12`）。
3. 只读挡不住的强制写入，由 **watch 守护**每 5 秒比对一次快照，发现被改/被删就立即还原并重新只读。
4. 注意：**图片资源不设只读**——Team Create 的素材转发遇到只读图片会无限重试
   （日志刷 `Converted temporary file to real asset: ...`，一次能刷出十几 MB）。

## 用法（在工程根目录执行）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 status    # 看漂移 / 锁定状态
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 restore   # 被覆盖后还原
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 unlock    # 自己要改文件时解锁
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 lock      # 改完重新锁定
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 snapshot  # 自己改完后刷新快照
powershell -NoProfile -ExecutionPolicy Bypass -File .protected\guard.ps1 watch     # 常驻守护（5 秒一轮，自动还原并重新只读）
```

也可以直接双击 **`.protected\watch.cmd`** 启动守护（黑窗口关掉即停止）。

自己改文件的流程：**先关掉守护窗口** → `unlock` → 改 → `snapshot` → `lock` → 再开 `watch.cmd`。

## 更彻底的做法

如果眼下不需要实时协作，二选一可以根除覆盖：

- 在 Godot 的 Team Create 面板点 **Disconnect**；或
- Project Settings → Plugins 里取消勾选 **Team Create**（`project.godot` 的 `editor_plugins/enabled` 里有它）。

需要协作时，请约定这些文件只由一方负责，另一方不要保存它们。
