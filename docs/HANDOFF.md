# 交接说明（给接手的 Agent / 结对编程伙伴）

> Owner 2026-10-22 角色澄清：本次参赛主角是荧（Lumine）·风元素，不是泛称旅行者或其他战士。其他元素延后。TASK-7.3 修订已合入 PR6 的通用行旅表现，数值基准不变；角色范围见 `SCOPE.md`，表现接入见 `design/TRAVELER.md`。

> **2026-10-22 晚人工反馈（本轮更新）：** 创作者奇匠等级已升到 **Lv.2**，自定义外显文本的等级前置**已达成**；卡牌名称/效果文本**尚未实机验证**。此前截图的 Lv.1 为升级前，旧记录 Lv.15 无可信证据。上一个截图显示「已上传」列表已有 GUID `24312086863`，但它是否对应本机超限模式存档、MCP `list_maps` 能否列出仍待测试。**Lv.4「局内存档」仅用于离开关卡后保留玩家数据**，首发 15 层同局跨节点状态不依赖它，不应作为 TASK-14 的阻塞。具体见 `docs/TOOLCHAIN.md` 和 `docs/PUBLISHING.md`。

> Sprint Lead 整合更新（2026-10-22，TASK-7 / PR #2）：下文保留上一会话的交接快照。完整75卡原表已原样移至 `data/reference/warrior75.json`（含待核对费用，不代表75张可玩）；`data/cards.json` 为首轮37张战士运行契约。现已补齐19普通变体/14普通遭遇/3精英/1Boss、7遗物、7药水、规则表，详见 `data/README.md`。轻量门禁在TASK-22/PR #1，48项测试已本地复验。游戏窗口运行，但MCP仍列不出存档；未平台编译、未导入、未真机试玩。主Agent领取TASK-7，执行身份在Backlog notes、分支与PR追踪，负责人仍Furinya；其余依赖按实际完成状态解锁。

更新时间：2026-10-22。目标：2026-10-30 前完成第一件参赛作品并由**人**正式投稿（官方截止 2026-11-02 11:59 UTC+8）。

## 0. 先读这四份

| 文件 | 作用 |
|---|---|
| `AGENTS.md` | CLI 工作流 + 分支规范 + 工具链指针（Codex/Claude/Cursor 都读） |
| `docs/SCOPE.md` | 产品范围、削减优先级、报告纪律 |
| `docs/TOOLCHAIN.md` | 工具链唯一事实来源（路径、版本、环境变量、MCP 配置） |
| `docs/HANDOFF.md` | 本文件：当前进度、阻塞、上手步骤 |

## 1. 仓库与分支

- 远端：`https://github.com/CHNISam/Slay-the-Abyss.git`
- `master` = 生产（只收 release/hotfix + tag）；`develop` = 开发基线，**日常工作在 develop 或 `feat/<slug>` 短分支**
- 当前工作分支：develop，已推送
- Conventional Commits；共享分支禁止改写历史

## 2. 当前进度（真实状态，未虚报）

**已完成**
- backlog.md 项目骨架、6 个里程碑（M0–M5）、21 个任务与依赖，`backlog doctor` 通过
- 分支规范 + PR 模板 + `.gitignore`
- `docs/TOOLCHAIN.md`（含官方客户端/千星沙箱路径、MCP 配置、赛事规则要点）
- 项目级 skill：`.codebuddy/skills/miliastra-wonderland/SKILL.md`，另有 `CLAUDE.md`、`.cursor/rules/miliastra.mdc` 指针
- `data/cards.json`：**战士 75 张全卡池**（3 基础 + 20 普通 + 36 罕见 + 16 稀有 + 3 状态牌），费用/数值/类型/稀有度**照抄官方 wiki**，只换中文名并保留 `sts_name` 溯源；`cost_verify` 列出 6 张费用待二次核对
- `data/statuses.json`：9 种状态效果定义
- `data/README.md`：表驱动约定（改数值不改代码）
- TASK-1 部分核验：MCP 连通（v0.1.0，workspace/Python 3.12 路径正确，`liveWriteEnabled=false` 确认只写副本）

**未开始 / 未完成**
- TASK-1 剩余：千星沙箱新建超限模式存档（**需人**在游戏内完成）；赛事报名入口与创作者中心收益功能是否开通（**需人**确认）
- TASK-7 剩余：敌人清单（14 组 / 19 变体 / 3 精英 / 1 Boss）、遗物与药水数值表
- M1 及之后全部开发工作：战斗核心、卡牌系统、战斗界面、状态框架 → 地图/节点 → Boss/结算 → 物料/验收 → 投稿

## 3. 阻塞（必须由人处理）

1. **游戏内新建千星奇域存档（超限模式）**并保存一次，记录存档名 → 之后 `list_maps` 才能列出，MCP 才有操作对象。
2. **确认创作者中心「收益功能」已开通**（未满 18/未实名/未开通则票券无法提现，原石不影响）。
3. 发布与赛事报名只能由人点（投稿上限 2 次且不可更换）。

## 4. 上手命令

```bash
git checkout develop && git pull
backlog board                 # 看板
backlog task list --plain     # 任务清单
backlog task view TASK-7      # 数值基准任务
backlog browser --port 6420   # Web UI（127.0.0.1:6420）
```

环境（MCP 已写入用户级配置，重启客户端生效）：
- 原神：`G:\Genshin\Genshin Impact Game\YuanShen.exe`（7.1.0）
- 千星沙箱：`...\BeyondAssets\BeyondAssistEditor\BeyondEditor.exe`
- MCP：`D:\MiliastraTools\genshin-miliastra-mcp\src\server.mjs`，`MILIASTRA_ALLOW_LIVE_WRITE=0`
- Python 3.12：`C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe`

## 5. 纪律（务必遵守）

- 用 miliastra MCP 前先读资源 `miliastra://workflow`、`miliastra://platform-rules`
- `MILIASTRA_ALLOW_LIVE_WRITE` 保持 `0`，只写存档副本
- **编译通过 / 写入存档 / 游戏内验证三件事分开报告**，不得互相冒充
- 内容缺口如实报告，不得把未完成功能宣布为通过
- 投稿成功与否由人确认，Agent 不得虚报
- 数值一律走 `data/*.json`，禁止在代码里硬编码数值；改数值不动代码
- 卡牌/敌人数值照抄有公开来源的原版数值，只改名不改数（`cost_verify` 里的 6 张落地前要再核对一次）
