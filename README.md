# HealthReminder（macOS 菜单栏健康提醒）

一个原生 macOS 菜单栏健康提醒应用：喝水、站立、放松眼睛（20-20-20）。默认参数参考常见健康最佳实践，并支持自定义间隔、活跃时段、暂停与稍后提醒。

## 功能

- 菜单栏入口：显示三类提醒的下一次时间，支持一键“稍后 10 分钟/暂停 60 分钟/打开设置/退出”。
- 本地通知：系统通知中心弹出提醒（需要用户授权）。
- 活跃时段：仅在指定时段发送提醒，避免夜间打扰。
- 喝水目标：设置每日目标并计算建议每次饮水量。
- 开机启动：使用 `ServiceManagement` 注册为登录启动项（需要以 `.app` 形式运行）。

## 推荐默认（可改）

- 喝水：每 60 分钟一次，按每日 2000ml 目标分配用量。
- 站立：每 50 分钟一次，提示起身活动 2–5 分钟。
- 眼睛：每 20 分钟一次，提示遵循 20-20-20。
- 活跃时段：09:00–21:00。

## 运行与打包

SwiftPM 直接 `swift run` 运行时不是 `.app` 进程，系统通知可能不可用；请按下面方式打包后运行。

应用图标默认使用 `icons/app-icon.png`，打包时会先用 macOS 官方工具 `sips` 规范化为 1024×1024 源图，再用 `iconutil/actool` 生成并写入 `.app`（`AppIcon.icns` + `Assets.car`）。

### 生成 DMG 安装包

- `chmod +x scripts/build-dmg.sh`
- `./scripts/build-dmg.sh`
- 输出：`dist/*.dmg`

### 方式 A：脚本打包（推荐）

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open .build/HealthReminder.app
```

首次运行会弹出通知权限请求。

### 方式 B：用 Xcode 打开并运行

1. 直接用 Xcode 打开本目录的 `Package.swift`。
2. 选择目标 `HealthReminder` 运行。
3. 建议在 Xcode 中以“App”方式运行/归档后导出 `.app`，以保证通知能力。

## 安装到本机

将打包产物拷贝到 `/Applications`：

```bash
./scripts/build-app.sh
cp -R .build/HealthReminder.app /Applications/
open /Applications/HealthReminder.app
```

如遇到系统阻止运行，可在“系统设置 → 隐私与安全性”里允许。
