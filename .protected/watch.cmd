@echo off
rem 常驻守护：每 5 秒检查一次受保护文件，被改动/删除就自动还原并重新设为只读。
rem 关掉这个黑窗口即可停止守护。
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0guard.ps1" watch -IntervalSeconds 5
pause
