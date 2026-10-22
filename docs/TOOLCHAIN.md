# Slay the Abyss · 原神千星奇域工具链

参赛：Miliastra Wonderland「Amongst the Thousand Stars: Wonderlands Creator Contest」
官方截止 2026-11-02，本项目内部提交硬线 **2026-10-30**。

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
