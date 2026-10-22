---
name: miliastra-wonderland
description: 原神「千星奇域」(Miliastra Wonderland) UGC 关卡开发。涉及千星沙箱编辑器、节点图、客户端 Lua、自动试玩、参赛提交时使用。说明本机官方工具与已装好的 miliastra MCP 工具的位置、调用顺序和硬性限制。
---

# 千星奇域开发（本机环境）

## 先读这个

工具链的完整路径、版本、环境变量：`docs/TOOLCHAIN.md`（仓库内）。

## 本机已装好的东西

- 原神客户端 7.1.0：`G:\Genshin\Genshin Impact Game\YuanShen.exe`
- 外置辅助工具 千星沙箱：`G:\Genshin\Genshin Impact Game\BeyondAssets\BeyondAssistEditor\BeyondEditor.exe`
- 局内编辑器：游戏内 派蒙菜单 → 我的奇域 → 新建存档（超限模式）
- miliastra MCP：`D:\MiliastraTools\genshin-miliastra-mcp`（stdio，已在 CodeBuddy 用户级 MCP 配置里，重启客户端生效）
- Python 必须用 3.12：`C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe`（系统默认 3.13 装不了 rapidocr-onnxruntime）

## 硬性规则

1. 动手前先读 MCP 资源 `miliastra://workflow` 和 `miliastra://platform-rules`。
2. `MILIASTRA_ALLOW_LIVE_WRITE` 保持 `0`：只写存档副本，不动正式存档。
3. 顺序不能乱：导入场景 → `scene_list_entities` 取回真实编号 → `write_graphs` → `playtest_start` → `playtest_status`。
4. 三件事分开报告：**编译通过** / **写进存档** / **游戏里真的验证过**。不要拿编译成功冒充可玩。
5. 发布只能由人在游戏里点，工具不点。
6. 试玩期间占用键鼠，显示器要开着，窗口 16:9 全屏。

## 玩法实现选择

- 3D 场景 + 服务端规则 → 节点图（TypeScript / Genshin-TS）。
- 界面动效、整局 2D 小游戏 → 客户端 Lua（游戏 7.1 能力），可用 `scene_import_simulator` 从模拟器工程导入真机。
- 需要快迭代的界面：先跑模拟器（几秒一轮），定稿再用 MCP 上真机（约一分钟一轮）。

## 验收清单（提交前）

- [ ] 试玩日志打印符合预期，赢/输两条路径都走过
- [ ] 截图确认画面、UI 不出屏（手机/主机画布各看一眼）
- [ ] 单人关卡玩家数设为 1 到 1
- [ ] 阵营：多数玩法只让玩家与造物敌对（`hostilePairs: [[1,3]]`）
- [ ] 出生点 / 复苏点 / 镜头锁死（fixedView）已设
- [ ] `publish_kit` 出封面、四张图、标题、简介、标签
