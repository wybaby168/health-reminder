# HealthReminder Windows 版（WinUI 3）

此目录包含 Windows 原生版本源码（WinUI 3 / Windows App SDK）。目标：在 Windows 上实现与 macOS 版本相同的核心能力：

- 托盘常驻（系统托盘图标 + 菜单）
- 三类提醒：喝水 / 站立 / 护眼（20-20-20）
- 活跃时段、暂停、稍后
- Windows Toast 通知 + 交互按钮（已喝完/开始站立/开始护眼/稍后/打开设置）
- 强制休息模式：全屏遮罩（覆盖全部显示器的虚拟桌面范围），最小/最大持续时间
- 单实例（再次打开会把已运行实例置前并复用）
- 开机自启（优先走 Windows App SDK 的 StartupTask；未打包时提示用户）

## 构建环境

- Windows 10/11
- Visual Studio 2022（安装 **.NET Desktop Development** 与 **Windows App SDK / WinUI 3** 相关组件）
- .NET SDK 8

## 运行

1. 打开 `windows/HealthReminder.Windows/HealthReminder.Windows.sln`
2. 还原 NuGet
3. 选择 `x64`，Debug 运行

## 命令行构建与运行

前提：已安装 Visual Studio 2022（含 Windows App SDK/WinUI 3 相关组件）或 Build Tools，以及 .NET 8 SDK。

### 使用 `dotnet`

在仓库根目录执行：

```powershell
dotnet restore .\windows\HealthReminder.Windows\HealthReminder.Windows\HealthReminder.Windows.csproj
dotnet build   .\windows\HealthReminder.Windows\HealthReminder.Windows\HealthReminder.Windows.csproj -c Debug -p:Platform=x64
dotnet run     --project .\windows\HealthReminder.Windows\HealthReminder.Windows\HealthReminder.Windows.csproj -c Debug -p:Platform=x64
```

### 使用 `msbuild`

如果你使用 VS 的 Developer PowerShell：

```powershell
msbuild .\windows\HealthReminder.Windows\HealthReminder.Windows.sln /restore /t:Build /p:Configuration=Debug /p:Platform=x64
```

运行可直接执行生成的 exe（WinUI 3 桌面应用不会像控制台那样“附带 run”目标）：

```powershell
& .\windows\HealthReminder.Windows\HealthReminder.Windows\bin\x64\Debug\net8.0-windows10.0.19041.0\HealthReminder.Windows.exe
```

### 生成 MSIX（建议，用于 Toast 图标/开机启动更稳定）

WinUI 3 的 Toast 与 StartupTask 在 MSIX 环境下更符合预期。你可以在 VS 中添加/使用 Windows Application Packaging Project 进行打包发布。

推荐使用本仓库提供的 PowerShell 脚本（单项目 MSIX）：

- 打包发布文档：`windows/RELEASE.md`
- 生成开发证书：`windows/scripts/new-dev-cert.ps1`
- 构建 MSIX：`windows/scripts/build-msix.ps1`
- 安装 MSIX：`windows/scripts/install-msix.ps1`

## 说明

- 该项目默认使用 `Assets/AppIcon.png` 作为图标源（请替换为你的 icon）。
- 默认会复用仓库根目录的 `z.png` 作为 `Assets/AppIcon.png`（你也可以自行替换）。
- 托盘图标与 toast 图标在 Windows 上更依赖 MSIX 打包与资源路径。建议使用 VS 的打包/发布流程生成 MSIX。
