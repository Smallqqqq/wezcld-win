-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                        WezTerm 配置文件                                    ║
-- ║                        最后更新: 2026-03-19                                ║
-- ╠══════════════════════════════════════════════════════════════════════════════╣
-- ║                                                                            ║
-- ║  【快捷键一览】                                                            ║
-- ║  Ctrl+Alt+O            启动Claude Code                                 ║
-- ║  Ctrl+Alt+P            启动wezcld （需配置wezcld）                                ║
-- ║                                                                            ║
-- ║  ── 标签页管理 ──                                                          ║
-- ║  Ctrl+Shift+T          新建标签页                                          ║
-- ║  Ctrl+Shift+W          关闭当前标签页                                      ║
-- ║  Ctrl+Shift+Tab        切换到上一个标签页                                  ║
-- ║  Ctrl+Shift+1~9        切换到第 1~9 个标签页                               ║
-- ║                                                                            ║
-- ║  ── 窗格(分屏)管理 ──                                                     ║
-- ║  Ctrl+Shift+E          水平分屏(向右)                                      ║
-- ║  Ctrl+Shift+D          垂直分屏(向下)                                      ║
-- ║  Ctrl+Shift+X          关闭当前窗格                                        ║
-- ║  Alt+H/J/K/L           窗格导航(左/下/上/右)                               ║
-- ║  Alt+方向键             窗格导航(左/下/上/右)                               ║
-- ║  Ctrl+Alt+方向键       调整窗格大小                                        ║
-- ║                                                                            ║
-- ║  ── 文本操作 ──                                                            ║
-- ║  Ctrl+Shift+C          有选区则复制             ║
-- ║  Ctrl+Shift+V          粘贴剪贴板                                          ║
-- ║  Ctrl+Shift+F          搜索                                                ║
-- ║  Ctrl+Shift+K          清屏(清除回滚缓冲区)                                ║
-- ║  Shift+PageUp/Dowlsn     翻页滚动                                            ║
-- ║                                                                            ║
-- ║  ── 字体 ──                                                                ║
-- ║  Ctrl+Shift+=          放大字体                                            ║
-- ║  Ctrl+Shift+-          缩小字体                                            ║
-- ║                                                                            ║
-- ║  ── 功能 ──                                                                ║
-- ║  Ctrl+Shift+Q          快速选择模式(QuickSelect)                           ║
-- ║  Ctrl+Shift+M          打开 Launch Menu                                    ║
-- ║  Ctrl+Alt+E            字符选择器(Emoji等)                                 ║
-- ║                                                                            ║
-- ║  ── AI Chat 集成 (需安装 aichat: https://github.com/sigoden/aichat) ──    ║
-- ║  Ctrl+X                将选中文本/当前光标行发送给 aichat，结果粘贴回终端      ║
-- ║  Shift+X               侧边栏切换 aichat 面板(分屏/缩放/聚焦)             ║
-- ║                                                                            ║
-- ║  ── 鼠标 ──                                                                ║
-- ║  左键单击              选中文本自动复制到剪贴板                            ║
-- ║  左键双击/三击         选词/选行并复制                                     ║
-- ║  Ctrl+左键             打开链接                                            ║
-- ║  右键                  有选区则复制，无选区则粘贴                          ║
-- ║                                                                            ║
-- ║  【其他功能】                                                              ║
-- ║  - 会话持久化 (unix_domains: persist)                                      ║
-- ║  - Bell 通知 (窗口标题含 "claude" 时弹窗提醒，需要调整claude code的 /config 的 Notifications为Terminal Bell (\a)) ║
-- ║  - SSH 快速连接 (Launch Menu / ssh_domains)                                ║
-- ║  - Kitty 图形协议支持                                                      ║
-- ║  - WebGpu 高性能渲染                                                       ║
-- ║                                                                            ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action


-- ==================== 插件引入 ====================
------------------------------------------------------

-- ============================================================================
-- Launch Menu
-- ============================================================================

config.launch_menu = {
  { label = "正式环境26(普通SSH)",  args = { "ssh", "prod" } },
  { label = "测试环境28(普通SSH)",  args = { "ssh", "test" } },
  { label = 'CMD',                  args = { 'cmd.exe' } },
  { label = 'PowerShell',           args = { 'powershell.exe' } },
  { label = "ai-chat",              args = { "aichat" } },
  { label = "代码管理",             args = { "powershell.exe", "-NoExit", "-Command", "cd 'D:\\PycharmProjects\\code_platform'; & '.venv\\Scripts\\Activate.ps1'" } },
  { label = "代码管理Worker",       args = { "powershell.exe", "-NoExit", "-Command", "cd 'D:\\PycharmProjects\\code_platform_worker'; & '.venv\\Scripts\\Activate.ps1'" } },
  { label = "商业化排期",           args = { "powershell.exe", "-NoExit", "-Command", "cd 'D:\\Projects\\business-schedule-backend'" } },
  { label = "代码扫描",             args = { "powershell.exe", "-NoExit", "-Command", "cd 'D:\\Projects\\code-analysis-web'" } },
}

-- 匹配你的ssh 窗格title，然后返回对应的启动参数，方便分屏
local domain_map = {
  { pattern = "lhep-webserver11",   args = { "ssh", "prod" } },
  { pattern = "lhep-tools04",   args = { "ssh", "test" } },
}


-- ============================================================================
-- SSH 域，需开启mux server，开启后可将会话保存在远端，支持断连
-- ============================================================================

config.ssh_domains = {
  { name = "正式环境", remote_address = "10.1.5.26", username = "zhangshuai18" },
  { name = "测试环境", remote_address = "10.1.5.28", username = "zhangshuai18" },
}



-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 检测当前窗格的 shell 环境类型
--- 通过前台进程名和窗口标题判断，用于 aichat 提示词前缀
---@return string env_type 环境类型: cmd/powershell/pwsh/ssh/bash/zsh/fish/unknown
---@return string proc     进程路径
local function detect_env(pane)
  local proc = (pane:get_foreground_process_name() or ""):lower()
  local title = (pane:get_title() or ""):lower()
  -- 按进程名匹配
  local proc_map = {
    { pattern = "cmd%.exe",        env = "cmd" },
    { pattern = "powershell%.exe", env = "powershell" },
    { pattern = "pwsh%.exe",       env = "pwsh" },
    { pattern = "ssh",             env = "ssh" },
    { pattern = "bash",            env = "bash" },
    { pattern = "zsh",             env = "zsh" },
    { pattern = "fish",            env = "fish" },
  }
  for _, m in ipairs(proc_map) do
    if proc:find(m.pattern) then return m.env, proc end
  end
  -- 进程名无法判断时回退到标题
  if title:find("powershell") then return "powershell", proc end
  if title:find("cmd")        then return "cmd", proc end
  if title:find("@")          then return "ssh", proc end

  return "unknown", proc
end



--- 兼容不同版本 WezTerm 的光标位置获取
---@return number x, number y
local function get_cursor_xy(pane)
  local a, b = pane:get_cursor_position()
  if type(a) == "table" then return a.x, a.y end
  return a, b
end



--- 根据当前窗格环境，返回新窗格应启动的程序参数
local function get_smart_split_args(pane)
  local title = pane:get_title() or ""
  for _, m in ipairs(domain_map) do
    if title:find(m.pattern, 1, true) then
      return m.args
    end
  end
  -- 各类本地 Shell
  local env, proc = detect_env(pane)
  local env_args_map = {
    cmd        = { "cmd.exe" },
    powershell = { "powershell.exe" },
    pwsh       = { "pwsh.exe" },
    bash       = { "bash" },
    zsh        = { "zsh" },
    fish       = { "fish" },
  }

  if env_args_map[env] then
    return env_args_map[env]
  end
  -- unknown → 使用默认 shell（返回 nil 让 WezTerm 自己决定）
  return nil
end


-- ============================================================================
-- 外观：字体
-- ============================================================================

config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Fira Code',
  'Consolas',
  'Microsoft YaHei UI',
}
config.font_size = 12
config.line_height = 1.2

-- ============================================================================
-- 外观：窗口与标签栏
-- ============================================================================

config.window_decorations = "TITLE|RESIZE"
config.window_background_opacity = 0.5
config.enable_scroll_bar = true

config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32

-- ============================================================================
-- 外观：配色 (Catppuccin Mocha)
-- ============================================================================

config.color_scheme = 'Catppuccin Mocha'
config.colors = {
  tab_bar = {
    background = 'rgba(0, 0, 0, 0.3)',
    active_tab = { bg_color = '#cba6f7', fg_color = '#1e1e2e' },
    inactive_tab = { bg_color = 'rgba(0, 0, 0, 0.3)', fg_color = '#cdd6f4' },
  },
}

-- ============================================================================
-- 外观：光标
-- ============================================================================

config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

-- ============================================================================
-- 性能
-- ============================================================================

config.max_fps = 120
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

-- ============================================================================
-- 协议与功能开关
-- ============================================================================

config.enable_kitty_graphics = true
config.window_close_confirmation = 'NeverPrompt'
config.skip_close_confirmation_for_processes_named = {
  'bash', 'zsh', 'fish', 'pwsh', 'powershell', 'cmd', 'nu',
}

-- ============================================================================
-- 默认启动
-- ============================================================================

config.default_prog = { 'powershell.exe' }
config.initial_cols = 96
config.initial_rows = 24

-- ============================================================================
-- 会话持久化 (unix_domains)
-- ============================================================================

config.default_domain = 'local'

config.unix_domains = {
  {
    name = 'persist',
    local_echo_threshold_ms = 10,
  },
}

-- 启动时自动连接持久化会话
config.default_gui_startup_args = { 'connect', 'persist' }

-- ============================================================================
-- 快捷键
-- ============================================================================

config.keys = {

  -- ── 标签页管理 ──
  { key = 't',   mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w',   mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
  { key = '1',   mods = 'CTRL|SHIFT', action = act.ActivateTab(0) },
  { key = '2',   mods = 'CTRL|SHIFT', action = act.ActivateTab(1) },
  { key = '3',   mods = 'CTRL|SHIFT', action = act.ActivateTab(2) },
  { key = '4',   mods = 'CTRL|SHIFT', action = act.ActivateTab(3) },
  { key = '5',   mods = 'CTRL|SHIFT', action = act.ActivateTab(4) },
  { key = '6',   mods = 'CTRL|SHIFT', action = act.ActivateTab(5) },
  { key = '7',   mods = 'CTRL|SHIFT', action = act.ActivateTab(6) },
  { key = '8',   mods = 'CTRL|SHIFT', action = act.ActivateTab(7) },
  { key = '9',   mods = 'CTRL|SHIFT', action = act.ActivateTab(8) },

  -- ── 窗格(分屏)管理 —— 智能分屏：新窗格继承当前环境 ──
  {
    key = 'e',
    mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local args = get_smart_split_args(pane)
      local cwd = pane:get_current_working_dir().file_path
      wezterm.log_info('cwd path = ' .. tostring(cwd))
      if args then
        pane:split({ direction = 'Right', args = args, cwd = cwd })
      else
        -- args 为 nil 时使用域默认 shell
        window:perform_action(act.SplitPane { direction = 'Right' }, pane)
      end
    end),
  },
  {
    key = 'd',
    mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local args = get_smart_split_args(pane)
      local cwd = pane:get_current_working_dir().file_path
      if args then
        pane:split({ direction = 'Down', args = args, cwd = cwd })
      else
        window:perform_action(act.SplitPane { direction = 'Down' }, pane)
      end
    end),
  },
  { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },

  -- 窗格导航 (Alt + 方向键 / hjkl)
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },

  -- 调整窗格大小 (Ctrl+Alt + 方向键)
  { key = 'LeftArrow',  mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow',    mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow',  mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Down', 5 } },

  -- ── 文本操作（复制/粘贴/搜索/清屏/滚动） ──

  -- Ctrl+Shift+C: 有选区 → 复制
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and #sel > 0 then
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
      end
    end),
  },

  { key = 'v',        mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'f',        mods = 'CTRL|SHIFT', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'k',        mods = 'CTRL|SHIFT', action = act.ClearScrollback 'ScrollbackAndViewport' },
  { key = 'PageUp',   mods = 'SHIFT',      action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT',      action = act.ScrollByPage(1) },

  -- ── 字体大小 ──
  { key = '=', mods = 'CTRL|SHIFT', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL|SHIFT', action = act.DecreaseFontSize },

  -- ── 功能快捷键 ──
  { key = 'q', mods = 'CTRL|SHIFT',  action = act.QuickSelect },
  { key = 'm', mods = 'CTRL|SHIFT',  action = act.ShowLauncher },
  { key = 'e', mods = 'CTRL|ALT',    action = act.CharSelect },

  -- Delete 键：先清除选区再发送
  {
    key = 'Delete',
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and #sel > 0 then
        window:perform_action(act.ClearSelection, pane)
      end
      window:perform_action(act.SendKey { key = 'Delete' }, pane)
    end),
  },

-- ── 自定义快捷输入 ──
  { key = 'O', mods = 'CTRL|SHIFT', action = act.Multiple({
      act.SendString('claude'),
      act.SendKey({ key = 'Enter' }),
  })},

  { key = 'P', mods = 'CTRL|SHIFT', action = act.Multiple({
      act.SendString('wezcld'),
      act.SendKey({ key = 'Enter' }),
  })},

  -- ── AI Chat 集成 (需安装 aichat) ──

  -- Shift+X: 侧边栏 aichat 面板
  --   单窗格 → 右侧分屏打开 aichat
  --   多窗格未缩放 → 缩放主窗格(隐藏 aichat)
  --   已缩放 → 取消缩放并聚焦 aichat 窗格
  {
    key = 'X',
    mods = 'SHIFT',
    action = wezterm.action_callback(function(_, pane)
      local tab = pane:tab()
      local panes = tab:panes_with_info()
      if #panes == 1 then
        pane:split({ direction = 'Right', size = 0.4, args = { 'aichat' } })
      elseif not panes[1].is_zoomed then
        panes[1].pane:activate()
        tab:set_zoomed(true)
      else
        tab:set_zoomed(false)
        panes[2].pane:activate()
      end
    end),
  },

  -- Ctrl+X: 将选中文本(或光标行)发送给 aichat -e，结果粘贴回终端
  --   根据当前 shell 环境自动添加提示词前缀
  {
    key = 'x',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local dims = pane:get_dimensions()
      local _, cy = get_cursor_xy(pane)

      -- 读取视口全部文本，提取光标所在行
      local top = dims.scrollback_top
      local bottom = top + dims.viewport_rows - 1
      local all = (pane:get_text_from_region(0, top, dims.cols - 1, bottom) or "")
                    :gsub("[\r\n]+$", "")

      local rows = {}
      for line in (all .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(rows, line)
      end
      while #rows < dims.viewport_rows do
        table.insert(rows, "")
      end

      -- 优先使用选中内容，否则使用光标所在行
      local input = window:get_selection_text_for_pane(pane)
      if not input or input == "" then
        input = rows[cy + 1] or ""
      end
      if not input or input == "" then return end

      -- 根据 shell 环境添加提示词前缀
      local env = detect_env(pane)
      local prefix_map = {
        powershell = "只输出 PowerShell 命令：\n",
        pwsh       = "只输出 PowerShell 命令：\n",
        cmd        = "只输出 CMD 命令：\n",
        ssh        = "你在 SSH 里，优先输出 Linux bash 命令：\n",
      }
      if prefix_map[env] then
        input = prefix_map[env] .. input
      end

      window:perform_action(act.ClearSelection, pane)

      -- 调用 aichat，将结果粘贴回当前窗格
      local success, stdout, _ = wezterm.run_child_process({ 'aichat', '-e', input })
      if success then
        stdout = (stdout or ""):gsub("[\r\n]+$", "")
        -- 先发 Ctrl+C 清除当前输入行，再粘贴结果
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
        pane:paste(stdout)
      end
    end),
  },
}

-- ============================================================================
-- 鼠标绑定
-- ============================================================================

config.mouse_bindings = {
  -- 右键：有选区 → 复制，无选区 → 粘贴
  {
    event = { Up = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      local text = window:get_selection_text_for_pane(pane)
      if text and #text > 0 then
        window:perform_action(act.CopyTo 'Clipboard', pane)
      else
        window:perform_action(act.PasteFrom 'Clipboard', pane)
      end
    end),
  },

  -- Ctrl+左键打开链接
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },

  -- 左键选中自动复制 (单击/双击/三击)
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection',
  },
}

-- ============================================================================
-- 事件：Bell 通知 (Claude Code完成后进行通知)
-- ============================================================================

-- 检测到终端的bell事件时调用
wezterm.on('bell', function(window, pane)

  -- 设别title是否为claude窗口，仅对claude窗口处理
  local title = (pane:get_title() or ""):lower()
  if not title:find("claude", 1, true) then
    return
  end


  -- 获取当前的工作目录，可以用于通知展示
  local dir = '未知目录'
  local cwd = pane:get_current_working_dir()

  if cwd and cwd.file_path then
    local path = cwd.file_path
    path = path:gsub('^/([A-Za-z]:)', '%1')
    path = path:gsub('[\\/]+$', '')
    dir = path:match('([^/\\]+)$') or dir
  end

  -- 此处进行windows的右下角通知，可以实现自己想要的通知方式，本质就是lua脚本
  window:toast_notification(
    'Claude code任务完成',
    dir .. ' 完成',
    nil,
    5000
  )
end)


-- ============================================================================
-- 事件：启动时窗口居中
-- ============================================================================

wezterm.on('gui-startup', function(cmd)
  -- 窗口居中
  local screen = wezterm.gui.screens().main
  local w, h = 1000, 600
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():set_position(screen.width / 2 - w / 2, screen.height / 2 - h / 2)
  window:gui_window():set_inner_size(w, h)
end)

return config