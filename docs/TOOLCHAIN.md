# 杀戮原塔2 · 原神千星奇域工具链

参赛：原神千星奇域「**千星之约·奇域创作大赛**」（首届全体创作者创作赛）。
制作投稿：7.1 版更后 ~ **2026-11-02 11:59**；评审 11-02 12:00 ~ 12-04；公示 12-05 ~ 12-12。
本项目内部提交硬线 **2026-10-30**（留两天缓冲）。

### 参赛规则要点（任何 agent 动发布前必读）

**详细人工发布 SOP / 入口取证 / 物料验收：[`docs/PUBLISHING.md`](PUBLISHING.md)**（不要把「上传成功」「可发布」当成已报名）。
- 报名入口：千星沙箱**上传界面**里的「赛事报名」，勾选「千星之约·奇域创作大赛」后再发布奇域，才算参赛（不是在游戏里随便发）。
- **投稿次数上限 2 次，一经投稿不可更换。** 没打磨完绝对不要点发布/投稿。
- 不限玩法品类与题材；**奇匠 Lv.2 已由用户确认于 2026-10-22 达成**（先前截图 Lv.1 是升级前；旧文档 Lv.15 不再作为事实）。Lv.2 已满足自定义外显文本的等级门槛，仍需在本人的创作账号中实际试玩验证卡牌名称、效果说明是否正确显示。
- 「新锐之星奖」限**投稿时奇匠等级 ≤3**；目前用户反馈为 Lv.2，是否符合全部参赛条件仍须以报名时平台实际状态和本届赛事规则为准。其他奖项依当期公告核验。
- 票券提现属「奇匠激励计划」，需年满 18 周岁 + 实名认证 + 在创作者中心完成入驻并**开通收益功能**——这条要在提交前确认，否则拿不到票券。
- 规则以官方活动页为准（微博公告入口 http://t.cn/AXO1GiB3 ）。

## 工具任务索引

所有 AI 从此按问题选工具；以下命令均在仓库根目录执行。先确认当前分支、依赖和工具是否可用，再运行最小相关验证；缺能力报告阻塞，不重复安装、猜接口或把旧证据当作本轮结果。下文 Windows 路径是已记录的用户机器配置，不是云环境默认值；不要复制硬编码到新脚本。规则入口见 [AGENTS](../AGENTS.md)，不另建工具清单。

| 问题 / 目的 | 已有工具与调用入口 | 可复用示例 / 验证边界 |
| --- | --- | --- |
| 不知道改动该跑什么 | `npm run test:related -- --base <基线SHA> --plan`；需要快速反馈用 `test:fast` 同参数，再去掉 `--plan` 执行 | [CI-FAST](CI-FAST.md)、[ENGINEERING](ENGINEERING.md)；计划、部分反馈不等于完整回归，未知输入依现有规则处理 |
| 战斗状态、Host 输入或 UI 生命周期回归 | Fengari：先 `npm run build:data`、`npm run build:ui`；定向运行 `node scripts/test-lua.mjs tests/lua/grid_lifecycle_contract.lua`；原生 UI 合同用 `npm run check:native-ui-contract` | [Lua 入口](../scripts/test-lua.mjs)、[共享 UI 夹具](../tests/lua/support/game_ui_fixture.lua)、[生命周期用例](../tests/lua/grid_lifecycle_contract.lua)；执行真实 Lua + mock 原生 API，不是官方 LuaHost/客户端实测 |
| 美术/UI 快速运行、点击与截图 | BeyondSimulator：已验证包 `beyond-simulator-mcp@0.5.2`；复用已有安装，必要时设置 `ART_LAB_MCP_ENTRY` 指向其 `dist/index.js`；`node experiments/art-tech-lab/rpc.mjs list` 查询实际工具；随后按需运行同目录 `build.mjs` → `run.mjs` → `verify.mjs` | [实验说明与复现](../experiments/art-tech-lab/README.md)、[RPC 适配](../experiments/art-tech-lab/rpc.mjs)、[运行示例](../experiments/art-tech-lab/run.mjs)；`qxqy_studio_play` / `qxqy_studio_play_screenshot` 已有调用。生成会覆盖该实验的样品、截图及回执，须在独立副本运行；list 写根目录 tools.json |
| 分清截图证明什么 | 模拟器上述 `run.mjs` 生成 Host PNG；仅核查保存证据用 `node experiments/art-tech-lab/verify.mjs`；官方截图验收用 `npm run verify:ui -- <候选.gil>` | [批准稿](design/UI_DESIGN.md)、[UI 验收合同](ENGINEERING.md#日志与ui迁移)；模拟器软件光栅、mock 断言、官方当前候选截图分别报告。mobile.png 只是画布模拟；PNG 时长不是 GPU FPS，保存证据检查不是重新运行 |
| 构建原生 GIL、官方导入与新 ready | 先读下文 MCP 上手顺序及 [千星技能](../.codebuddy/skills/miliastra-wonderland/SKILL.md)；`node scripts/build-native-candidate.mjs <base.gil> [build/candidates]`；只有客户端可用且获本轮输入窗口才加 `--playtest` | [候选与启动证据](ENGINEERING.md#候选身份)、[官方客户端操作](../.codebuddy/skills/miliastra-wonderland/references/official-client.md)；先读 `miliastra://workflow` 与 `miliastra://platform-rules`，保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`。静态构建/写入/官方导入/ready/设备体验分别验收 |
| 查看、编辑节点图 | [WebMiliastraNodesEditor 在线入口](https://miliastra.columbina.dev/)；实际能力先在该站核实，自动化优先查已有 MCP 实际工具列表与资源 | 这是网页编辑器入口，不声明已有无人值守导入/API 集成；已有节点图流程见下文 MCP `write_graphs`，不能将网页可编辑当作官方导入成功 |
| 维护模型指引或任务 | `npm run check:guidance`；`node --test tests/agent-guidance.test.mjs`；任务先 `backlog instructions overview` | [指引维护](AGENT_GUIDANCE.md)；Backlog 缺失时报告，不手改任务文件、不另建任务系统 |

**环境与交付边界：** 云隔离副本可在依赖齐全时跑 Node/Fengari 及模拟器无桌面接口；这不代表已接入用户 Windows MCP、官方编辑器或游戏。任何打开应用、抢焦点、鼠标键盘操作仍须 AGENTS 的本轮授权。先复用本机实际安装；安装条件与完整复现只链接现有说明，不在索引复制配置。实验尚非正式战斗装配/发布候选，缺官方导入、挂载、新 ready、容量或设备证据保持未验收；优先推进当前交付，不因工具探索扩大范围。

## 1. 官方工具（已安装，无需再装）

| 组件 | 路径 | 版本 |
|---|---|---|
| 米哈游启动器 | `D:\miHoYo Launcher\launcher.exe` | 1.18.0.380 |
| 原神客户端（国服中文） | `G:\Genshin\Genshin Impact Game\YuanShen.exe` | **7.1.0** |
| 外置辅助工具「千星沙箱」 | `G:\Genshin\Genshin Impact Game\BeyondAssets\BeyondAssistEditor\BeyondEditor.exe` | 随客户端下发 |
| 局内编辑器 | 游戏内：派蒙菜单 → 我的奇域 → 新建存档（超限模式） | — |
| 创作者中心（网页） | https://ys.mihoyo.com/miliastra_wonderland/ | — |

要点：
- 千星沙箱**没有独立安装包**，它随客户端下载到 `BeyondAssets\BeyondAssistEditor\`。官方只要求「PC 端安装米哈游启动器 + 原神客户端」。
- 编辑器**仅支持 PC 端**；账号需推进到开启祈愿功能，并注册成为创作者（奇匠）。
- 自定义外显文本在奇匠 Lv.2 解锁；**用户已报告升至 Lv.2，但游戏内文字显示尚未实测通过**。先用卡牌名和说明文本做一次实机验证，特别注意旧已发布内容是否需要更新上传。
- 存档默认位置：`%LOCALAPPDATA%Low\miHoYo\原神\BeyondLocal`（账号目录下的 `Beyond_Local_Save_Level`）。
- **局内存档 ≠ 编辑器存档 ≠ 一局内跨节点保持**：官方 Lv.4「局内存档」保存玩家离开关卡后、下一次再进入仍要恢复的数据（结构体/玩家变量读写）；当前 M2 / TASK-14 只需在**同一次游玩**的 15 层节点之间维持血量、金币、卡组、遗物和药水，不依赖 Lv.4。退出后续玩是额外功能，**不阻塞 10/30 首投，不为此升级账号**。官方指南：https://act.mihoyo.com/ys/ugc/tutorial/detail/mhzcw29qjjma ；等级来源：https://www.sina.cn/news/detail/5227779438151916.html 。

## 2. 千星奇域 MCP（AI 搭关卡 / 写节点图 / 自动试玩）— 已装好

- 仓库：`D:\MiliastraTools\genshin-miliastra-mcp`（非官方社区项目，MIT，Windows + 国服中文客户端验证）
- 入口：`D:\MiliastraTools\genshin-miliastra-mcp\src\server.mjs`（stdio MCP，不需要 API Key）
- 工作区：`D:\MiliastraTools\genshin-miliastra-mcp\workspace`
- 依赖：Node `v22.22.1`、Python `3.12.10`（`C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe`，Pillow + rapidocr-onnxruntime 已装）
  - 注意：系统默认 Python 是 3.13，装不了 `rapidocr-onnxruntime`，所以单独装了 3.12，**必须用 3.12 这个路径**。
- 完整 Quality CI 单独固定 Node `24.18.0`，由 `actions/setup-node` 只设置该作业的运行时；上述 MCP/系统 Node 不替换。两台现有 Windows 运行器全局版本不同，Node22 曾使三份 Lua 用例超时及整套45分钟取消；本机官方校验后的便携 Node24 在原30/60秒预算内全部通过。版本与校验来自 [Node 官方发布页](https://nodejs.org/en/blog/release/v24.18.0)，测量及原始失败记录见 [M3集成记录](reviews/M3-EVENTS-INVENTORY-INTEGRATION.md)。全部用例、断言和原时限保留，CI不启动客户端或抢占桌面。
- 已接入：用户级 MCP 配置 `C:\Users\Administrator\.codebuddy\mcp.json`（及 `.mcp.json`）中的 `miliastra` 项。客户端需重启才生效。

```json
{
  "mcpServers": {
    "miliastra": {
      "type": "stdio",
      "command": "node",
      "args": ["D:\\MiliastraTools\\genshin-miliastra-mcp\\src\\server.mjs"],
      "env": {
        "MILIASTRA_WORKSPACE": "D:\\MiliastraTools\\genshin-miliastra-mcp\\workspace",
        "MILIASTRA_ALLOW_LIVE_WRITE": "0",
        "MILIASTRA_PYTHON": "C:\\Users\\Administrator\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
        "MILIASTRA_PLAYTEST_PYTHON": "C:\\Users\\Administrator\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
      }
    }
  }
}
```

- `MILIASTRA_ALLOW_LIVE_WRITE=0`：只写存档副本，不动正式存档（保持 0，除非明确要改正式存档）。
- 自检命令：
  ```powershell
  cd D:\MiliastraTools\genshin-miliastra-mcp
  $env:MILIASTRA_PYTHON='C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe'
  $env:MILIASTRA_PLAYTEST_PYTHON=$env:MILIASTRA_PYTHON
  npm run doctor
  ```

### 上手顺序（AI 必须按这个走）
1. 读 MCP 资源 `miliastra://workflow` 与 `miliastra://platform-rules`（平台实测的坑）。
2. 游戏里「我的奇域 → 新建存档（超限模式）」，保存一次，记下存档名。
3. 搭场景：`scene_build_blocks` → `scene_import_assets` → `scene_list_entities` 取回实体编号。
4. 写逻辑：节点图用 TypeScript（Genshin-TS），`write_graphs` 编译写进存档副本。
5. 验证：`playtest_start` → `playtest_status`（自动按键/截图/读日志）。编译通过 ≠ 写进存档 ≠ 游戏里验证过，三件事分开报告。
6. 出图：`publish_kit` 出封面/截图/标题/简介；**真正的发布由人在游戏里点**。

试玩前提：显示器开着、16:9 全屏、运行期间不要碰键鼠；游戏若以管理员运行，MCP 所在客户端也要管理员。

2026-10-24已实证权限预检：游戏/沙箱为High（已提升）、MCP helper为Medium时，`editor_input`即使报告`inputSent`且窗口前台，Q和鼠标操作也可能无画面变化。宿主提升至同级后，同一Q输入立即切页。开始GUI前先核对权限，失败后看新截图确认实际效果；不要把发送计数当作成功，也不要反复置前或增加holdMs代替权限修正。本轮原始token诊断与A/B截图在根`.artifacts/m1-live-5165a78/diagnostics/`，测试后隐藏helper已退出。

## 3. 项目管理

- backlog.md CLI（v1.53.0）：`backlog board` / `backlog task create` / `backlog browser`，任务目录 `backlog/`。
- 分支：`master`（生产，只接 release/hotfix 并打 tag）、`develop`（开发基线，日常在这）、`feat/*` → develop。见仓库根目录 `AGENTS.md`。

## 4. 其他可选社区工具（未安装，按需）

- WebMiliastraNodesEditor：网页节点图编辑器，在线版 https://miliastra.columbina.dev/
- 千星奇域节点图工具集（GIA 读写 / DSL）：https://github.com/ayayasx/Genshin-Impact-Miliastra-Wonderland-Code-Node-Editor-Pack
- BeyondSimulator 已有 0.5.2 实验与可复现入口，见上方工具任务索引；不是本节“未安装”的统一结论，当前机器安装状态须另查。`scene_import_simulator` 仍须核实当前 MCP 能力，不能将实验 GIA 导出当作完整 GIL 或真机通过。
