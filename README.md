<div align="center">

# 「小明」校园网加速工具箱

**Windows 校园网 / 游戏网络一键优化 · 改前自动备份、可一键还原 · 延迟前后对比 · 纯本地运行**

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
![Version](https://img.shields.io/badge/version-v0.1.5-orange)
![Last commit](https://img.shields.io/github/last-commit/xm2284/XiaomingCampusNetToolkit)
[![Hits](https://hits.sh/github.com/xm2284/XiaomingCampusNetToolkit.svg)](https://hits.sh/github.com/xm2284/XiaomingCampusNetToolkit)

[功能特性](#功能特性) · [快速开始](#快速开始) · [功能菜单](#功能菜单) · [效果对比](#优化前后对比) · [隐私说明](#隐私与安全) · [在线看板](http://47.98.204.220/)

</div>

---

## 这是什么

一个专为**校园网（如 i-Star =-= ）**和**校园环境下打游戏**设计的 Windows 网络优化工具箱。
它解决两个最常见的痛点：

**淦，学校校园网也太卡了o(╥﹏╥)o，能快一点是一点吧qwq**
1. **开了梯子 / 代理后重启电脑，网页打不开** —— 一键清掉系统里残留的代理设置；
2. **校园网 Wi-Fi 又卡又跳** —— 一键应用跨网卡自适应的优化，并**自动备份、随时还原**，优化前后用真实 ping 对比效果。

> 没有捆绑、没有常驻后台、没有安装过程。一个 PowerShell 脚本 + 一个双击启动的 bat，所有改动都在本地、可逆。

## 功能特性

- ⚡ **快速 / 完整双模式（v0.1.1）** —— 选优化后问一句 `要测速对比吗？`：**赶时间输 N，约 10 秒完事**（只备份+改设置+重启网卡）；想看真实效果输 **Y**，跑完整的优化前后 20 包延迟对比。
- ⏱️ **实时进度条（v0.1.1）** —— 延迟测试逐包显示进度 `[███░░] n/N 预计剩余 X 秒`，不再黑屏干等。
- 🚀 **启动即提权（v0.1.1）** —— 双击 exe 立刻弹管理员权限，不用等选功能。
- 🤖 **首启自动探测（v0.1.1）** —— 第一次打开自动识别你网卡型号和可优化项，只问一次同意，之后不再重复探测。
- 🧹 **一键清理代理残留** —— 关闭系统代理、重置 WinHTTP、清理 `HTTP(S)_PROXY` 环境变量、通知系统刷新、刷新 DNS。重启后打不开网页时，点一下就好。
- 📶 **跨网卡自适应** —— 按网卡驱动实际支持的高级属性动态匹配（不硬编码厂商值），Intel / Realtek / MediaTek 等都能识别，找不到就自动跳过，绝不瞎改。
- 🎓 **校园网模式** —— 优先 5GHz 频段、关闭 MIMO 节能、关闭 U-APSD 省电、关闭数据包合并、关闭 Nagle 算法降低小包延迟。
- 🎮 **游戏模式** —— 在校园网模式基础上再开启吞吐增强（Throughput Booster），**保守、安全**：不动 MTU、不动拥塞算法、不动 LSO / QoS / 中断亲和。
- 🛟 **自动备份 + 一键还原** —— 每次优化前自动备份网卡高级属性 / TCP 全局参数 / 代理 / Nagle 注册表，保留最近 10 个快照，随时回到原状。备份存在 `%LOCALAPPDATA%\XiaomingToolkit\backups`，**不会往桌面乱扔文件**。
- 📊 **优化前后延迟对比** —— 自动选最快公共 DNS、ping 网关与 DNS，输出 min / avg / max / 抖动 / 丢包，并算改善百分比。
- 🔍 **网络状态体检** —— 一键看 SSID、频段、信号、协商速率、网关、DNS、当前代理状态。
- 🤫 **默认匿名、不打扰** —— 首次运行展示免责声明；遥测默认自动上报，但**完全匿名**，可在菜单设置里关闭。

## 快速开始

> 需要 Windows 10 / 11。首次运行会请求管理员权限（改网卡 / 注册表必须）。

**方式一（推荐）：下载单个 exe**

1. 到 [Releases](../../releases) 下载最新的 `XiaomingCampusNetToolkit.exe`；
2. 直接双击运行（会自动弹 UAC 提权）；
3. 首次运行阅读免责声明，按菜单数字选择功能即可。

> 若被 SmartScreen / 杀软拦截：点"更多信息 → 仍要运行"。这是 PowerShell 打包成 exe 的常见误报，脚本完全开源可逐行审查。

**方式二：源码 / 脚本运行**

必须**整个仓库下载**（不能只下单个 bat / ps1，它们要在同目录）：仓库页绿色 `<> Code` → `Download ZIP`，解压后双击 `Start-Xiaoming-Toolkit.bat`；或 git clone 后运行：

```powershell
git clone https://github.com/xm2284/XiaomingCampusNetToolkit.git
cd XiaomingCampusNetToolkit
powershell -ExecutionPolicy Bypass -File "src\XiaomingToolkit.ps1"
```

## 功能菜单

| 数字 | 功能 | 说明 |
|------|------|------|
| `1` | 一键修代理 | 开了梯子重启后打不开网页，点一下就好 |
| `2` | 校园网优化 | 问 `Y/N`：**N=快速约10秒**（赶时间用），**Y=完整前后延迟对比** |
| `3` | 游戏优化 | 在校园网基础上开吞吐增强，保守安全 |
| `4` | 测延迟 / 看状态 | 逐包进度条 + SSID/信号/速率/代理状态 |
| `5` | 备份与恢复 | 新建快照，或选最近快照一键还原 |
| `6` | 设置 / 关于 | 开关匿名统计、打开数据目录、作者 QQ |
| `0` | 退出 | |

> slogan：「**我与我周旋久，宁做我**」

## 优化前后对比

工具会在每次优化后自动对比网关延迟。真实测试示例（某校园网 Wi-Fi）：

![延迟对比](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dlatency)

![每日调用趋势](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dusage)

> 延迟受网络波动影响，结果仅供参考；如不满意，菜单选 `[7]` 立即还原。

## 隐私与安全

- **所有修改前自动备份**，且全部改动都有对应还原路径；没有任何删除性操作。
- **匿名遥测**只上报：工具版本、Windows 版本、网卡厂商、使用模式、成功与否、优化项数、前后延迟 / 丢包。
- **绝不记录** IP、主机名、MAC 地址、账号、位置。可在菜单 `[6] 设置` 里随时关闭。
- 数据存放在你自己的 `%LOCALAPPDATA%\XiaomingToolkit\`，备份 / 日志 / 报告都在本地。

## 更新日志

### v0.1.3
- 🎨 新增软件图标（青蓝 WiFi + 闪电），exe 自带图标
- 🖥️ 首次运行自动在桌面创建「小明校园网加速工具箱」快捷方式，之后不再重复

### v0.1.2
- 🔗 重启网卡后**确认真正 ping 通网关**（连续 2 包成功）才开始复测，不再把"刚重连的抖动"误报成延迟上升
- ❓ 测速询问只认 `Y/N`，乱输入会重新问，不再闷头执行
- 🎨 菜单更简洁（去掉括号说明），副标题改为「我与我周旋久，宁做我」
- 📦 单文件改名为 `XiaomingCampusNetToolkit.exe`

### v0.1.1
- ⚡ 新增**快速 / 完整双模式**：赶时间输 N 约 10 秒，看效果输 Y 完整前后对比
- ⏱️ 延迟测试加**实时进度条 + 预计剩余秒数**，不再黑屏干等
- 🚀 **启动即提权**，双击就弹管理员
- 🤖 首次**自动探测本机网卡**，只问一次，之后不再重复
- 🎨 控制台美化：ASCII banner、圆角框线菜单
- 简化菜单为 6 项；删去底部匿名统计信息
- 📞 作者 小明 QQ 2284517861
- 🐛 修复重启后 Wi-Fi 信息显示空、重复执行入口

### v0.1.0
- 首个公开版本：代理清理 / 校园网优化 / 游戏优化 / 自动备份还原 / 延迟对比 / 匿名看板

## 常见问题

**Q：改完会不会把网改坏？**
不会。每次优化前都自动备份（`backups\` 目录），菜单 `[5]` 一键还原；游戏模式保守，不动 MTU / 拥塞算法。优化过程中 Wi-Fi 会自动重连约 5–10 秒，属正常现象。

**Q：开了梯子 / VPN，重启后浏览器打不开网页？**
这就是 `[1] 一键修代理` 解决的。它会把残留的系统代理、WinHTTP 代理、环境变量代理全部清掉，再刷新 DNS。

**Q：在别的电脑 / 别的网卡上能用吗？**
可以。它会先探测本机网卡支持哪些高级属性，再按语义匹配目标值（如"禁用""启用""含 5G"），匹配不到就跳过，不依赖特定型号。

**Q：杀毒软件 / Windows SmartScreen 报风险？**
这是 PowerShell 脚本常见误报。脚本开源、可逐行审查；如担心，可右键 exe → 属性 → 解除锁定，或自行阅读 `src\XiaomingToolkit.ps1`。

**Q：赶时间打游戏，不想等测速？**
选 `[2] 校园网优化` 后，提示 `要测速对比吗？` 时直接输 `N`，约 10 秒完成；想看真实提速效果再输 `Y`。

## 在线统计看板

本项目自带一个匿名统计后端（Flask + SQLite + Docker）。

**📊 完整实时看板：<http://47.98.204.220/>**

<div align="center">

| 每日调用 | 网卡厂商 |
|:---:|:---:|
| ![每日调用](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dusage) | ![网卡厂商](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dvendor) |

| 使用模式 | 系统版本 |
|:---:|:---:|
| ![使用模式](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dmode) | ![系统版本](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dos) |

| 延迟前后对比 |
|:---:|
| ![延迟前后对比](https://images.weserv.nl/?url=47.98.204.220/chart%3Ftype%3Dlatency) |

</div>

> 上图通过 https 代理实时拉取（约 5 分钟缓存）；点上方链接看完整交互看板。

自部署方法见 [`stats-server/README.md`](stats-server/README.md)。

## 目录结构

```
XiaomingCampusNetToolkit/
├─ src/
│  └─ XiaomingToolkit.ps1          # 主程序（全部功能 + 测试模式）
├─ XiaomingCampusNetToolkit.exe    # 单文件版（Release 提供，双击即用）
├─ Start-Xiaoming-Toolkit.bat      # 脚本启动器（需连同 src 一起）
├─ stats-server/                  # 可选的匿名统计后端（Docker）
├─ README.md
├─ LICENSE
└─ .gitignore
```

## License

[MIT](LICENSE) © xm2284

> 仅供学习交流。按自身网络环境使用，作者不对任何网络配置改动负责（工具已提供自动备份与还原）。
