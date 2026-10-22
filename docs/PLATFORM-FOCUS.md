# 本机试玩焦点修复（TASK-10.3）

工具基线：`D:/MiliastraTools/genshin-miliastra-mcp`，Git `7091060417fe9bd1231e812db4f798c97a5c63d1`。此前工作区干净。只修改 `src/playtest_runner.py` 的焦点回退，复用同工具 `win_input.py` 已有的前台及目标线程双队列连接策略：限定 DWORD/BOOL 类型，只解绑成功连接，finally 保证释放。最终前台检查和四次上限保持原样，没有模拟 Alt、改全局系统设置或绕过失败。

`tools/patch-local-mcp-focus.py <runner路径> <证据目录>` 使用精确原件 SHA256、结构和语法检查；原件以独占新文件保存，禁止覆盖已有备份。已安装修补保存在 `.worktrees/platform-ui/focus-patch/`，该目录有原文件、unified diff 和前后 hash。回滚时先确认当前 SHA 与 after 一致，再将完整备份恢复；不要覆盖后续工具更新。

原件 SHA256：`8365fea3d3ccb0abfdce035d346323db7a399b6dcd3dbdd6fdc2d9129f410eab`。
修补后 SHA256：`29643287c0781620d0bd2864152401c9879f885394b3205176e1923e93e80cfb`。

非作者 quality_gates 只读复核确认原件匹配工具基线、diff 仅焦点回退、hash 一致且语法通过；抽取实际方法在模拟双队列成功、全拒绝、部分连接和异常四场景检查：无成功连接泄漏，失败退出保留。模拟证据不视为真实桌面通过。

## 实际运行

- `96417ad4-7f09-409d-b741-35a02a86684b`、`10e5aad4-3361-446a-995e-5b49d3a82422`、`8724deb3-b35d-4eff-9106-a9d9fd389275` 均在导入前报“无法把窗口切到前台：game”。最后一轮特地在同一 MCP 会话先调用成功的 `focus_editor_window`，仍失败，停止相同重试。
- 修补后 `7675e481-bcbf-44ee-b85f-e41b2c1ddd80` 已通过焦点步骤，32秒后因“没有弹出导入存档的文件选择框”退出。没有进入游戏试玩，没有玩家截图和游戏日志。
- 随后对实际可见的“导入存档”按钮和 R 快捷键各做一次目标绑定输入，界面未改变。读取 Windows TokenIntegrityLevel：游戏 PID32836 和沙箱 PID34432 为 `0x3000`，自动化 Python PID19772 为 `0x2000`。权限差异是后续输入验证的阻断，已请用户统一权限；不尝试自动提权或重启游戏。
- `capture_editor_window` 的 screen 模式另报 `WINDOW_OCCLUDED`，explorer.exe 1×1 顶角窗口；PrintWindow 图像能观察当前存档页，但不能据此宣称屏幕无覆盖。截图在 `.worktrees/platform-ui/captures/`。

全过程 `MILIASTRA_ALLOW_LIVE_WRITE=0`，候选仅在工作区 `.gil` 副本。未发布、未报名、未勾选 TASK-10 实机验收。当前补丁解决焦点回退，后续输入与游戏验证仍需要权限一致的环境。
