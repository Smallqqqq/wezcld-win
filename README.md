```
 ██╗    ██╗ ███████╗ ███████╗  ██████╗ ██╗     ██████╗
 ██║    ██║ ██╔════╝ ╚══███╔╝ ██╔════╝ ██║     ██╔══██╗
 ██║ █╗ ██║ █████╗     ███╔╝  ██║      ██║     ██║  ██║
 ██║███╗██║ ██╔══╝    ███╔╝   ██║      ██║     ██║  ██║
 ╚███╔███╔╝ ███████╗ ███████╗ ╚██████╗ ███████╗██████╔╝
  ╚══╝╚══╝ ╚══════╝ ╚══════╝  ╚═════╝ ╚══════╝╚═════╝
```

> 本项目参考 [afewyards/wezcld](https://github.com/afewyards/wezcld) 的 Linux 版本，通过 Vibe Coding 方式移植实现的 **Windows 原生 PowerShell 版本**。

**WezTerm × Claude Code 多 Agent 分屏工具（Windows 版）**

---

## 这是什么

Claude Code 在启动多 Agent 协作时，会通过 `it2` 命令（iTerm2 专属 CLI）来管理分屏窗格。  
`wezcld` 拦截这些 `it2` 命令，将其翻译为 `wezterm cli` 调用，让你在 **Windows + WezTerm** 环境下也能享受 Claude Code 的多 Agent 分屏能力。

---

## 安装

### 前置要求

- [WezTerm](https://wezfurlong.org/wezterm/installation.html) 已安装，`wezterm` 在 PATH 中可用
- [Claude Code](https://docs.anthropic.com/claude/docs/claude-code) 已安装，`claude` 在 PATH 中可用
- PowerShell 5.1+（Windows 10/11 内置）或 PowerShell 7+

### 一键安装

在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/Smallqqqq/wezcld-win/main/install.ps1 | iex
```

### 本地安装（克隆仓库后）

```powershell
git clone https://github.com/Smallqqqq/wezcld-win.git
cd wezcld-win
.\install.ps1
```

### 安装程序做了什么

1. 将 `wezcld.ps1` 和 `it2.ps1` 下载到 `%USERPROFILE%\.local\share\wezcld\bin\`
2. 在 `%USERPROFILE%\.local\bin\` 创建 `wezcld.cmd` / `it2.cmd` 包装器，使你可以直接输入 `wezcld` 运行
3. 将 `%USERPROFILE%\.local\bin` 永久写入用户 `PATH`（注册表级别）
4. 在 PowerShell Profile 中追加 PATH 设置，新窗口即时生效

### 卸载

```powershell
# 克隆仓库后执行
.\install.ps1 -Uninstall
```

---

## 使用方法

安装完成后，**重新打开终端**（或在当前窗口执行 `. $PROFILE`），然后：

```powershell
# 在 WezTerm 内启动，自动开启多 Agent 分屏模式
wezcld

# 恢复上次会话
wezcld --resume
```

> ⚠️ 请在 **WezTerm** 内运行 `wezcld`，在其他终端中运行会自动降级为普通 `claude` 命令。

---

## 工作原理

```
wezcld.ps1 启动
    │
    ├─ 设置 TERM_PROGRAM=iTerm.app（欺骗 Claude Code 以为在 iTerm2 中）
    ├─ 将 bin/ 目录插入 PATH 最前（拦截 it2 命令）
    ├─ 启动后台 Watchdog 进程（监控主进程，退出时自动清理所有分屏）
    └─ 执行 claude --teammate-mode tmux
           │
           └─ Claude Code 调用 it2 命令
                    │
                    └─ it2.ps1 拦截并翻译为 wezterm cli 调用
                             │
                             ├─ session split  →  wezterm cli split-pane（3列网格布局）
                             ├─ session run    →  wezterm cli send-text
                             └─ session close  →  wezterm cli kill-pane
```

---

## 支持的命令

| `it2` 命令 | 对应的 WezTerm 操作 |
|-----------|-------------------|
| `--version` / `app version` | 返回 `it2 0.2.3` |
| `session split [-v]` | `wezterm cli split-pane`（自动网格布局） |
| `session run -s <id> <cmd>` | `wezterm cli send-text --pane-id <id>` |
| `session close -s <id>` | `wezterm cli kill-pane --pane-id <id>` |
| `session list` | 返回最简 session 表 |
| 其他命令 | 静默成功（exit 0） |

---

## 运行测试

```powershell
powershell -ExecutionPolicy Bypass -File tests\integration-test.ps1
```