# Windows 打包与发布（MSIX + 脚本）

本项目的 Windows 版本是 WinUI 3 / Windows App SDK。推荐发布形态为 **MSIX（单项目 MSIX）**，这样 Toast 图标、通知按钮、StartupTask（开机启动）等能力更稳定。

## 先决条件

- Windows 10/11
- Visual Studio 2022（或 Build Tools），并安装：
  - MSBuild
  - Windows 10/11 SDK（含 MSIX 工具链：MakeAppx/SignTool）
  - Windows App SDK/WinUI 3 相关组件
- .NET 8 SDK

## 目录与产物

- 解决方案：`windows/HealthReminder.Windows/HealthReminder.Windows.sln`
- MSIX 输出：`dist/msix/*.msix`
- 开发证书：`certs/HealthReminder.Dev.pfx`（由脚本生成）

## 1) 生成开发签名证书（本机侧载）

在 PowerShell 执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.windows\scripts\new-dev-cert.ps1
```

脚本会输出：
- `PFX` 路径
- `Password`（用于构建 MSIX 时签名）

它会把证书导入 `CurrentUser\TrustedPeople`，确保本机可以直接安装。

## 2) 构建 MSIX（Release / x64）

```powershell
Set-ExecutionPolicy -Scope Process Bypass
$pwd = '把上一步脚本输出的 Password 填在这里'
.windows\scripts\build-msix.ps1 -PfxPassword $pwd
```

输出会打印最新的 `MSIX: ...` 路径。

## 3) 安装 MSIX（本机测试）

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.windows\scripts\install-msix.ps1
```

如果你希望安装指定文件：

```powershell
.windows\scripts\install-msix.ps1 -MsixPath .\dist\msix\HealthReminder.Windows_1.0.0.0_x64.msix
```

## 4) 构建未打包版本（备用）

未打包版本可用于快速分发，但 toast 图标/StartupTask 在未打包环境下通常不如 MSIX 稳定。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.windows\scripts\publish-unpackaged.ps1
```

产物：
- `dist/win-unpackaged/x64/`（可运行目录）
- `dist/HealthReminder-Windows-x64-unpackaged.zip`

## 常见问题

### 安装时报证书不受信任

确认你执行过 `windows/scripts/new-dev-cert.ps1`，并且安装用户与运行脚本用户一致（证书导入的是 `CurrentUser`）。

### 安装时报 Windows App SDK 运行时缺失

若目标机器没有 Windows App SDK framework 包，MSIX 可能无法运行。建议：
- 用 MSIX 分发时同时提供 Windows App SDK runtime 的官方安装方式（企业内网可预装）
- 或使用 Visual Studio 的发布/打包向导生成更完整的依赖策略

