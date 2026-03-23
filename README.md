```
 ██╗    ██╗ ███████╗ ███████╗  ██████╗ ██╗     ██████╗
 ██║    ██║ ██╔════╝ ╚══███╔╝ ██╔════╝ ██║     ██╔══██╗
 ██║ █╗ ██║ █████╗     ███╔╝  ██║      ██║     ██║  ██║
 ██║███╗██║ ██╔══╝    ███╔╝   ██║      ██║     ██║  ██║
 ╚███╔███╔╝ ███████╗ ███████╗ ╚██████╗ ███████╗██████╔╝
  ╚══╝╚══╝ ╚══════╝ ╚══════╝  ╚═════╝ ╚══════╝╚═════╝
```

[![Release](https://img.shields.io/github/v/release/afewyards/wezcld)](https://github.com/afewyards/wezcld/releases/latest)

> 本项目参考 [afewyards/wezcld](https://github.com/afewyards/wezcld) 的 Linux 版本，通过 Vibe Coding 方式移植实现的 **Windows 原生 PowerShell 版本**。

**WezTerm × Claude Code 多 Agent 分屏工具**

![wezcld demo](docs/demo.gif)

## 这是什么

Claude Code 在启动多 Agent 协作时，会通过 `it2` 命令（iTerm2 专属 CLI）来管理分屏窗格。  
`wezcld` 拦截这些 `it2` 命令，将其翻译为 `wezterm cli` 调用，让你在 **Windows + WezTerm** 环境下也能享受 Claude Code 的多 Agent 分屏能力。

## 平台支持

| 平台 | 脚本文件 | Shell |
|------|---------|-------|
| **Windows** | `bin/wezcld.ps1`、`bin/it2.ps1` | PowerShell 5.1+ / pwsh 7+ |
| **macOS / Linux** | `bin/wezcld`、`bin/it2` | POSIX sh（bash/zsh/dash） |

---

## Windows 安装

> **前置要求：** WezTerm、Claude Code（`claude` 在 PATH 中可用）、PowerShell 5.1+（Windows 10 起内置）

```powershell
# 一键安装（在 PowerShell 中运行）
irm https://raw.githubusercontent.com/Smallqqqq/wezcld-win/main/install.ps1 | iex
```

或者克隆仓库后本地安装：

```powershell
git clone https://github.com/Smallqqqq/wezcld-win.git
cd wezcld-win
.\install.ps1
```

**卸载：**

```powershell
.\install.ps1 -Uninstall
```

### 安装程序做了什么

1. 将 `wezcld.ps1` 和 `it2.ps1` 下载到 `%USERPROFILE%\.local\share\wezcld\bin\`
2. 在 `%USERPROFILE%\.local\bin\` 创建 `wezcld.cmd` / `it2.cmd` 包装器（使你可以直接输入 `wezcld` / `it2` 运行）
3. 将 `%USERPROFILE%\.local\bin` 永久写入用户 `PATH`（注册表级别）
4. 在 PowerShell Profile 中追加 PATH 设置，新窗口即时生效

---

## macOS / Linux 安装

```sh
curl -fsSL https://github.com/afewyards/wezcld/releases/latest/download/install.sh | sh
```

**卸载：**

```sh
curl -fsSL https://github.com/afewyards/wezcld/releases/latest/download/install.sh | sh -s -- --uninstall
```

---

## 使用方法

启动带 WezTerm 分屏集成的 Claude Code，/config下的Teammate mode调整为tmux：

```powershell
# Windows（PowerShell）—— 在 WezTerm 内运行
wezcld

# 恢复上次会话
wezcld --resume

# 或直接调用脚本
powershell -ExecutionPolicy Bypass -File bin\wezcld.ps1
```

```sh
# macOS / Linux
wezcld
```

> ⚠️ 在 WezTerm 外部运行时，`wezcld` 会自动降级为普通的 `claude` 命令。

---

## 工作原理

**架构：**

- **`wezcld` / `wezcld.ps1` 启动器**：设置 `TERM_PROGRAM=iTerm.app`（让 Claude Code 以为在 iTerm2 中运行），将 `bin/` 目录插入 PATH 最前，然后以 `--teammate-mode tmux` 启动 Claude
- **`bin/it2` / `bin/it2.ps1` 拦截器**：拦截 `it2` CLI 命令，翻译为真实的 `wezterm cli` 调用
- **网格布局**：Agent 窗格按 3 列网格排列，Leader 窗格始终保持在底部
- **Watchdog 守护进程**：后台进程监控主进程 PID，退出时自动清理所有 Agent 窗格

### Windows 特有说明

- 使用 **FileStream 文件锁**（`FileShare.None` + 重试循环）实现并发安全，替代 Linux 的 `mkdir` 原子锁
- 使用 **`cmd /c ... >nul 2>&1`** 完全屏蔽 wezterm 的错误输出，避免 PowerShell 干扰
- Watchdog 以隐藏窗口的 `Start-Process` 方式运行，而非后台 Shell Job
- 状态文件存储于 `%USERPROFILE%\.local\state\wezcld\`

---

## 支持的命令

| 命令 | WezTerm 操作 |
|------|-------------|
| `--version` / `app version` | 返回 `it2 0.2.3` |
| `session split [-v]` | `wezterm cli split-pane`（自动网格布局） |
| `session run -s <id> <cmd>` | `wezterm cli send-text --pane-id <id>` |
| `session close -s <id>` | `wezterm cli kill-pane --pane-id <id>` |
| `session list` | 返回最简 session 表 |
| 其他所有命令 | 静默成功（exit 0） |

---

## 环境要求

- **wezterm CLI**（随 WezTerm 一起安装）
- **Claude Code**（Anthropic 提供的 CLI 工具）
- **Windows**：PowerShell 5.1+（Windows 10/11 内置）或 PowerShell 7+
- **macOS/Linux**：POSIX 兼容 Shell（bash、zsh、dash、ash）

---

## 开发 / 测试

**运行测试（Windows）：**

```powershell
powershell -ExecutionPolicy Bypass -File tests\integration-test.ps1
```

**运行测试（macOS/Linux）：**

```sh
./tests/integration-test.sh
```
