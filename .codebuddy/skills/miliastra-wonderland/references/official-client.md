# 官方客户端操作

适用本项目的 Windows 原神、千星沙箱和本机 miliastra MCP。路径和版本以 `docs/TOOLCHAIN.md` 为准。技能提供操作办法，不新增发布、覆盖正式存档或挤掉另一设备登录的授权。

## 接管已有状态

- 先列窗口，再截图区分：本地存档列表、文件选择框、编辑器、试玩菜单、正在战斗、官方结算、加载画面。用户已打开的界面直接接着用；不要为了符合自动流程先退出重来。
- 没有游戏进程才启动 TOOLCHAIN 中的 `YuanShen.exe`；游戏需要用户看见和操作，勿后台重复启动。登录验证由用户处理。重复登录涉及其他设备时，沿用本会话已明确的设备选择。
- 同时只让一个执行者操作原神。自动流程仍在运行时，先看其 status，不并行点击菜单。用户帮忙切换后，重新观察，不继续旧坐标序列。
- 比较游戏与实际输入宿主的 Windows token integrity。工具调用的 `require_escalated` 不等于 Windows 管理员权限；High 游戏需要 High 宿主。普通权限的 `inputSent` 不能证明游戏接收了输入。

## 保留同级宿主

优先直接使用可用 MCP 工具。若当前客户端没有注册 miliastra，使用此技能的 `scripts/live-session.mjs`，通过已安装 MCP SDK 连接同一服务，不重写输入后端。

```powershell
$sessionOutput = 'F:\New folder\.artifacts\本轮唯一目录'
$sessionScript = 'F:\New folder\.codebuddy\skills\miliastra-wonderland\scripts\live-session.mjs'
# 下例仅在已确认游戏为 High 时使用；普通游戏直接 node 即可。
Start-Process -FilePath 'C:\Program Files\nodejs\node.exe' -ArgumentList ('"' + $sessionScript + '" "' + $sessionOutput + '"') -Verb RunAs -WindowStyle Hidden
```

脚本读取 workflow/platform-rules，保存 tool-schemas 和 bridge-ready；先读这些文件。它强制 liveWrite=0。每轮用新目录，不复用此前 ready。请求写入 `queue/001-说明.json`，结构：

```json
{"label":"unique-label","name":"list_editor_windows","arguments":{}}
```

实际工具名/参数从本轮 tool-schemas 取。窗口编号必须由本轮发现。辅助操作 `focus-capture` 接受 `{windowId}`，在同一宿主里置前后立刻拍 screen；`focus-input` 接受 `{windowId,kind,...}`，仅供编辑器和文件对话框，置前取得新 captureId 后只输入一次。

**试玩中的额外输入只用绑定本轮会话的 `playtest-input`**，不要用 `focus-input` 或直接 `editor_input` 绕过生命周期检查。`runId` 取本宿主实际启动结果，`windowId` 取本轮真实窗口，坐标取新截图；不可沿用终态运行的旧坐标序列。例如：

```json
{"label":"battle-select-01","name":"playtest-input","arguments":{"runId":"本轮实际runId","windowId":"本轮实际windowId","kind":"click","x":800,"y":740}}
```

该操作先用 `playtest_status {runId,waitSeconds:0,includeScreenshots:false}` 核对返回的 `runId`、本会话 `playtests/<runId>` 的 `runDir`、`state=running`，以及已发生 `playing`、尚无 `left-playtest`/`log-collected`；通过后才置前取新 captureId，紧接输入前再查一次同样状态，只发一次 `editor_input`。不按 elapsedSeconds 或计划时长猜测生命周期；状态获取失败、RPC 报错、身份不符、未开始或已退出都拒绝输入。两次状态与置前证据单独保存；`levelEndedAt` 仅表示官方结果页，仍满足上述条件时可以正常点“离开”。

这不是跨 RPC 的绝对原子锁：第二次检查与实际输入之间仍可能退出或被人工切换。每次操作仍须看新画面；发生错误不重发，先重新观察和核对状态。终态后要操作编辑器必须明确切换到编辑器流程，不能把失败的试玩输入改名重试。现有历史 artifact bridge 不会因仓库脚本更新自动获得此守卫；后续新会话使用技能脚本，不回写旧桥接器。

其余操作直接调用 MCP。结果与图片保存到会话目录；`.done` 只表示请求已处理，须读结果是否报错。结束后创建 `queue/STOP`。先结束仍在运行的试玩，再停宿主。

## 导入与打开

1. 冻结源 SHA 和候选 hash，先做副本静态检查。已有正确副本则不重建。不要重复导入场景资产。
2. **数字夹具切回普通版时，使用 `editor_open_map` 导入为新存档**，不要用 `playtest_start` 的 `replaceSave` 覆盖旧夹具存档。已实证 replaceSave 可更新 `.gil` 内嵌 Lua，却保留同目录 `external_lua_file` 中的旧入口及其他模块；候选 hash、存档名或 `playing` 状态都不能证明客户端执行的是新源码。
3. 流程报“文件选择框没出现”后，先列窗口。若实际已有“导入存档”对话框，直接接管它；不要再点击主窗口。文件名使用 `Alt+N` 定位，输入候选绝对路径，等截图显示完整路径后再 Enter。PrintWindow 紧随输入的第一帧可能只显示部分文字，应复拍确认。
4. 存档列表中核对新候选文件名/时间，再点它的“编辑”。等编辑器工具和画面就绪，不能看到加载画面就调不带 mapPath 的试玩。文件名相同或用户切换过时，读回新官方存档确认模块及外部 Lua；不凭“上次打开”推断源码。
5. 截图返回 WINDOW_NOT_FOREGROUND 或输入后刷新失败时，输入可能已经成功并打开了子弹窗。先列窗口/重新截图，禁止盲目重发。屏幕快照比 PrintWindow 更适合确认 GPU 画面；不用白图或旧帧决定下一次点击。

### 启动前核对实际客户端源码

每次新导入、替换或切换候选后，在启动试玩前执行项目的只读门禁。输入必须是**冻结候选独立读回**的 inventory JSON（`{mapPath,scripts:[{name,file,source}]}`，例如 `audit-native-candidate.mjs` 输出的 `scripts.json`），不能拿外部目录自己生成的清单与自己比较。官方存档绝对路径来自本轮导入结果；账号目录与工具位置以 `docs/TOOLCHAIN.md` 为准。

```powershell
node scripts/verify-official-client.mjs `
  '.artifacts/本轮候选/normal-audit/scripts.json' `
  'C:\Users\Administrator\AppData\LocalLow\miHoYo\原神\BeyondLocal\本轮账号\Beyond_Local_Save_Level\本轮存档\本轮存档.gil' `
  '.artifacts/本轮候选/official-client-source.json'
if ($LASTEXITCODE -ne 0) { throw '官方客户端 Lua 与候选不一致，禁止开始本轮验收试玩' }
```

它只读取 inventory 和官方 `.gil` 同目录的 `external_lua_file/*.lua`；`.gil` 只核对存在的普通文件，不解析/改写它，也不读取其他 sidecar 或凭证。逐模块比较候选内嵌源码与外部 Lua，只容忍首个 UTF-8 BOM 和 CRLF/LF 等价，保存两侧原始/规范 SHA256。缺失、差异、多余模块、重复模块、不安全文件名或缺少 `abyss_ui.lua` 入口均退出 1；检查不会帮忙同步或覆盖外部文件，报告也禁止写进官方存档目录。先建立报告所在的项目证据目录。

源码不一致时保留失败报告，并按上面的新存档流程重新导入，再跑同一冻结候选的门禁；不手改官方外部 Lua 来制造匹配。2026-10-24 的普通候选 `b6d3cbe` 覆盖官方1846后，发现四个旧模块与额外 `abyss_m3_numeric_probe.lua`；新导入1847为48/48匹配。原始红绿报告固定在项目根 `.artifacts/official-client-source-20261024/`，摘要见 `docs/evidence/official-client-source-20261024.json`。

门禁通过只代表这份 inventory 与外部 Lua 源码一致，不等于客户端 ready、画面正确或游戏可玩。之后才运行 `playtest_start`（`clientScriptLog: true`），轮询 `playtest_status`，核对本轮 `ABYSS_UI ready`、新日志、脚本错误和实际截图。加载等待或 `playing` 状态不替代这些证据。

## 日志与验收

- 每次新导入都确认客户端脚本订阅，工具自动负责，不能把反复手动勾选交给用户。正常 ready 为 `ABYSS_UI ready`，不能填错成 `ABYSS_READY`。
- 用户已经手动进入试玩时，先识别当前状态；自动 runner 的“开编辑器菜单→试玩”不能直接用于正在试玩的画面。可完成当前观察，再真实退出到编辑器后订阅并重开；也可使用已经在本轮订阅后启动的新局，但须关联本轮 ready 和日志，不冒用上一局。
- 加载超过一次正常等待范围时复拍并报具体步骤。连续同一失败不重复整套导入；依据现有窗口改走可观察的手动恢复。每分钟告知用户正在加载、正在操作或正在收日志，避免长时间无反馈。
- 主动退出要看到官方结算，再点“离开”，确认实际返回编辑器；日志可能在真正离开后延迟落盘。保留新文件的时间、hash、ready 和脚本错误检查。到时中断不等于正常退出。
- 编译、副本、官方读回、物理操作和命令驱动分别记。官方序列化可能省略 protobuf 默认字段；严格图载荷审计失败保留原结果，另列差异，不能默默放宽审计。
- 只保存已观察事实。例如 20 点药水击杀 12 血敌人证明消耗与致死路径，不单独证明精确 20 点未截断伤害。无本轮日志/ready 不判完整冒烟通过。
