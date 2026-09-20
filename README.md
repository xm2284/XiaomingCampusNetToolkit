<div align="center">

# 「小明」校园网加速工具箱

**Windows 校园网 / 游戏网络一键优化 · 改前自动备份、可一键还原 · 延迟前后对比 · 纯本地运行**

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
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

1. 到 [Releases](../../releases) 下载最新的 `启动「小明」校园网加速工具箱.bat`；
2. **右键 → 以管理员身份运行**（或直接双击，脚本会自动弹 UAC 提权）；
3. 首次运行阅读免责声明，之后按菜单数字选择功能即可。

也可以直接克隆运行：

```powershell
git clone https://github.com/xm2284/XiaomingCampusNetToolkit.git
cd XiaomingCampusNetToolkit
# 双击根目录的「启动…bat」，或：
powershell -ExecutionPolicy Bypass -File "src\XiaomingToolkit.ps1"
```

> 提示：PowerShell 脚本文件为 UTF-8 (带 BOM)，bat 为 GBK 编码，**请勿用编辑器另存为其它编码**，否则中文菜单会乱码。

## 功能菜单

| 数字 | 功能 | 说明 |
|------|------|------|
| `1` | 硬件探测 | 识别网卡型号 / 驱动 / SSID / 信号 / 频段，确认本机可优化项 |
| `2` | 清理代理残留 | 解决开梯子重启后打不开网页 |
| `3` | 延迟测试 | ping 网关 + 自动选最快公共 DNS，输出详细统计 |
| `4` | 校园网优化 | 自动备份 → 优化 → 重启网卡 → 复测对比 |
| `5` | 游戏优化 | 在 4 的基础上开启吞吐增强 |
| `6` | 立即备份 | 手动创建一个还原快照 |
| `7` | 从备份恢复 | 选择最近快照一键还原全部改动 |
| `8` | 网络状态 | 查看当前代理 / DNS / 网卡 / Wi-Fi 状态 |
| `9` | 设置 | 开关匿名统计、查看数据目录 |
| `0` | 退出 | |

## 优化前后对比

工具会在每次优化后自动对比网关延迟。真实测试示例（某校园网 Wi-Fi）：

![延迟对比](http://47.98.204.220/chart?type=latency)

![每日调用趋势](http://47.98.204.220/chart?type=usage)

> 延迟受网络波动影响，结果仅供参考；如不满意，菜单选 `[7]` 立即还原。

## 隐私与安全

- **所有修改前自动备份**，且全部改动都有对应还原路径；没有任何删除性操作。
- **匿名遥测**只上报：工具版本、Windows 版本、网卡厂商、使用模式、成功与否、优化项数、前后延迟 / 丢包。
- **绝不记录** IP、主机名、MAC 地址、账号、位置。可在菜单 `[9]` 里随时关闭。
- 数据存放在你自己的 `%LOCALAPPDATA%\XiaomingToolkit\`，备份 / 日志 / 报告都在本地。

## 常见问题

**Q：改完会不会把网改坏？**
不会。每次优化前都自动备份（`backups\` 目录），菜单 `[7]` 一键还原；游戏模式保守，不动 MTU / 拥塞算法。优化过程中 Wi-Fi 会自动重连约 5–10 秒，属正常现象。

**Q：开了梯子 / VPN，重启后浏览器打不开网页？**
这就是 `[2] 清理代理残留` 解决的。它会把残留的系统代理、WinHTTP 代理、环境变量代理全部清掉，再刷新 DNS。

**Q：在别的电脑 / 别的网卡上能用吗？**
可以。它会先探测本机网卡支持哪些高级属性，再按语义匹配目标值（如"禁用""启用""含 5G"），匹配不到就跳过，不依赖特定型号。

**Q：杀毒软件 / Windows SmartScreen 报风险？**
这是 PowerShell 脚本常见误报。脚本开源、可逐行审查；如担心，可右键 bat → 属性 → 解除锁定，或自行阅读 `src\XiaomingToolkit.ps1`。

## 在线统计看板

本项目自带一个极简匿名统计后端（Flask + SQLite + Docker），在线看板：<http://47.98.204.220/>

静态图（供本 README 嵌入 / 其它项目引用）：

- `http://47.98.204.220/chart?type=usage` 每日调用
- `http://47.98.204.220/chart?type=vendor` 网卡厂商
- `http://47.98.204.220/chart?type=mode` 使用模式
- `http://47.98.204.220/chart?type=os` 系统版本
- `http://47.98.204.220/chart?type=latency` 延迟前后

自部署方法见 [`stats-server/README.md`](stats-server/README.md)。

## 目录结构

```
XiaomingCampusNetToolkit/
├─ src/
│  └─ XiaomingToolkit.ps1      # 主程序（全部功能 + 测试模式）
├─ 启动「小明」校园网加速工具箱.bat   # 双击启动器（自动提权）
├─ stats-server/              # 可选的匿名统计后端（Docker）
├─ README.md
├─ LICENSE
└─ .gitignore
```

## License

[MIT](LICENSE) © xm2284

> 仅供学习交流。按自身网络环境使用，作者不对任何网络配置改动负责（工具已提供自动备份与还原）。
