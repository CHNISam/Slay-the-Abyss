# Slay the Abyss · 原神千星奇域工具链

参赛：原神千星奇域「**千星之约·奇域创作大赛**」（首届全体创作者创作赛）。
制作投稿：7.1 版更后 ~ **2026-11-02 11:59**；评审 11-02 12:00 ~ 12-04；公示 12-05 ~ 12-12。
本项目内部提交硬线 **2026-10-30**（留两天缓冲）。

### 参赛规则要点（任何 agent 动发布前必读）

**详细人工发布 SOP / 入口取证 / 物料验收：[`docs/PUBLISHING.md`](PUBLISHING.md)**（不要把「上传成功」「可发布」当成已报名）。
- 报名入口：千星沙箱**上传界面**里的「赛事报名」，勾选「千星之约·奇域创作大赛」后再发布奇域，才算参赛（不是在游戏里随便发）。
- **投稿次数上限 2 次，一经投稿不可更换。** 没打磨完绝对不要点发布/投稿。
- 不限玩法品类与题材；**账号奇匠等级待核实**：2026-10-22 用户游戏截图显示 Lv.1，与此前此处记载的 Lv.15 不一致。Lv.2 才解锁自定义外显文本，务必先在同一创作账号实测，不能默认文字可用。
- 「新锐之星奖」限奇匠等级 ≤3，本项目不适用；可争璀璨/闪耀/星辉/流光/千星启航/绘梦视觉。
- 票券提现属「奇匠激励计划」，需年满 18 周岁 + 实名认证 + 在创作者中心完成入驻并**开通收益功能**——这条要在提交前确认，否则拿不到票券。
- 规则以官方活动页为准（微博公告入口 http://t.cn/AXO1GiB3 ）。

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
- 奇匠 Lv.1 账号自定义文字不显示（文本框空白、选项卡无字），Lv.2 起正常；拿不准就先放一个文本框试玩验证。
- 存档默认位置：`%LOCALAPPDATA%Low\miHoYo\原神\BeyondLocal`（账号目录下的 `Beyond_Local_Save_Level`）。

## 2. 千星奇域 MCP（AI 搭关卡 / 写节点图 / 自动试玩）— 已装好

- 仓库：`D:\MiliastraTools\genshin-miliastra-mcp`（非官方社区项目，MIT，Windows + 国服中文客户端验证）
- 入口：`D:\MiliastraTools\genshin-miliastra-mcp\src\server.mjs`（stdio MCP，不需要 API Key）
- 工作区：`D:\MiliastraTools\genshin-miliastra-mcp\workspace`
- 依赖：Node `v22.22.1`、Python `3.12.10`（`C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe`，Pillow + rapidocr-onnxruntime 已装）
  - 注意：系统默认 Python 是 3.13，装不了 `rapidocr-onnxruntime`，所以单独装了 3.12，**必须用 3.12 这个路径**。
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

## 3. 项目管理

- backlog.md CLI（v1.53.0）：`backlog board` / `backlog task create` / `backlog browser`，任务目录 `backlog/`。
- 分支：`master`（生产，只接 release/hotfix 并打 tag）、`develop`（开发基线，日常在这）、`feat/*` → develop。见仓库根目录 `AGENTS.md`。

## 4. 其他可选社区工具（未安装，按需）

- WebMiliastraNodesEditor：网页节点图编辑器，在线版 https://miliastra.columbina.dev/
- 千星奇域节点图工具集（GIA 读写 / DSL）：https://github.com/ayayasx/Genshin-Impact-Miliastra-Wonderland-Code-Node-Editor-Pack
- 千星沙箱模拟器：游戏外几秒一轮跑 Lua，与本项目 `scene_import_simulator` 配合上真机
