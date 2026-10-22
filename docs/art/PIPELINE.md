# 首发美术流水线：候选流程与实机门槛

关联 TASK-10.1，2026-10-23。**尚未完成真实游戏验收，不是已验证生产 Skill；禁止批量生产。**

| 资产 | 复用路线 | 本轮证据与决定 |
|---|---|---|
| 卡牌 UI | Image Editor JSON → 原生图片/文字 Lua；GIA 备用 | 卡面 15 控件（11 图、4 字）；用户已导入并试玩，截图确认图形/费用/说明显示、点击事件通过；标题/类型缺失，v2 高度兼容候选待复验 |
| 荧肖像 | 先查原生角色/肖像；没有时审阅手工低图元替代 | 拒绝直接使用 Primitive Lua 拟合：256 图元仍损失五官，64/256 档有 27/72 个越界椭圆；PNG 裁切预览不等于 Lua 显示 |
| 建筑/场景 | 官方原生模型 → MCP scene_build_blocks → GIA | 单建筑/7 件景片可重复构建，碰撞均关闭；未导入、未实机。二维 UI 素材组不承担立体建筑 |

工具固定版本、许可证与小样：[卡牌](CARD_EDITOR_SPIKE.md)、[肖像](../experiments/art-portrait/README.md)、[场景](scene-spike/README.md)。MCP 提交为 `7091060417fe9bd1231e812db4f798c97a5c63d1`，安装路径以 [TOOLCHAIN.md](../TOOLCHAIN.md) 为准，不在项目内重造导出器或游戏框架。

## 卡牌副本准备（已实际复跑）

在本仓库 worktree 根运行：

```powershell
./scripts/art/prepare-card-candidate.ps1 -BaseMap '<已有存档副本或只读原档的绝对路径.gil>'
```

配方仅调用已安装的 MCP CLI：读 workflow/platform-rules → 建图片/文字模板 → 取返回的真实 templateIndex → 绑定上游 Lua → 挂专用空容器 → scene_check_client。输出 `build/art-platform/candidate.json` 和候选 GIL；不会启动 GUI、写原始存档或发布。保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`。

示例模板索引为 `1073741845 / 1073741846`，**只属于本次副本**，其他存档一律从返回结果重取。图库 `100001 / 100002 / 100003` 是矩形/圆/三角图片资产，不能当模板索引。画布 180×240，实际卡框 148×208，原生文字最小 14；上游参数 `BASE_SCALE=1`，图元不越界，不使用蒙版。导出脚本重设宿主尺寸，因此只挂专用容器。

准备成功只证明语法/命名契约与 GIL 写入。官方编辑器是否接受、Lua 是否运行、文字是否显示，仍须另测。上游 GIA 是旧 class15 素材组，不是已证实可直接装配到战斗控制器的组件。

首次实机发现 h22/font17 的标题与 h18/font14 的类型不显示；同模板 h40/font22 的费用与 h92/font15 的说明正常。候选仅将两处**透明文本框**高度提高为40，中心、字号与背景条带均不变；40来自可见对照，不是平台最小高度常数。原始导出保留，候选与回归见 [CARD_TEXT_HEIGHT_COMPAT.md](CARD_TEXT_HEIGHT_COMPAT.md)。选择候选生成 v2：

```powershell
./scripts/art/prepare-card-candidate.ps1 -BaseMap '<干净基底.gil>' -CardLua 'art/spikes/card-editor/text-height-compat/card.lua' -CandidateName 'abyss-art-card-text-v2'
```

v2 已写工作区副本并通过静态检查（0错误/0警告），尚未重新导入或实机确认缺字修复。它另加一行高度40的 `Metrics` 探针，将10秒客户端回调dt均值/p95直接显示，便于截图取证；不是GPU耗时。原版与v2比较必须记录探针的额外控件，不能把同屏整套UI成本推成一张卡的成本。

## 实机验证与切换规则

1. 导入候选为**新测试存档**，保留原始存档。单建筑和 7 件景片用不同干净副本，按场景报告中的现成 JSON 构建/安装/导入；随后读回真实 GUID。导入会新增实体，不能重复导入同包。
2. 卡牌试玩 15 秒，在第 3/10/14 秒截图，第 6 秒点击下方“点击检查”。确认中文、费用/说明、层序和点击后的“点击通过”，日志有 `ART_PROBE_START`、`ART_CLICK_OK`；检查运行时错误。
3. v2 的 `art/spikes/platform/probe.lua` 将10秒客户端回调dt均值/p95显示在 `Metrics` 并打印；原版只打印。它不是GPU帧时间，也不是手机性能。先测相同底图基线，再测小样与计划同屏数量；记录首次可见耗时、卡顿、控件数、连续进入/退出3次后的清理情况。没有实测数字不填“性能合格”。
4. 电脑/手机/主机画布分别截图。手机安全区按 1280×720，电脑 1600×900，主机 1920×1080；编辑器画布预览不能代替目标设备性能。场景另验镜头、门洞朝向、脚高、遮挡与碰撞。
5. 任一路出现坐标/裁切/画质/成本不合格，停止扩大数量，换已通过的小样或明确的原生占位。肖像本轮已按此切换，不继续增加拟合预算。占位缺口必须留在首发清单中。

## 当前阻塞与证据

[结构化证据](evidence/2026-10-23.json)。此前两轮自动导入均在文件框前失败；**用户现已手动完成导入**。已从新测试存档读回 `ART_Spike`、`ART_Card`、`ART_Probe`、五个静态宿主/探针控件；外部两个 Lua 源文件与候选逐字匹配（仅统一换行），读回后的静态检查仍为 0 错误/0 警告。整份 GIL 经编辑器重写元数据后哈希不同，因此用结构和脚本内容确认导入，不要求原始文件哈希不变。

用户随后手动进入试玩并给出两张截图：第一张可见卡框、费用1、岩晶和“造成6点伤害”，但“打击”和“攻击”缺失；第二张点击后的上方文字为“点击通过”，确认原生鼠标事件和文本更新执行成功。截图SHA及本机证据目录见结构化记录。完整卡牌显示未通过，帧间隔、多设备和重复进入/退出仍未验收，v2待人工运行复验。

自动操作的前台切换仍有问题：两轮 `playtest_start` 报“无法把窗口切到前台：sandbox”（run `8fd0a901`、`f891c7e9`），逐步工具后续也返回 `FOCUS_FAILED`，故后续采用用户操作+截图取证，没有重复盲点、修改系统设置或绕过输入限制。

本机候选：`.worktrees/art-pipeline/build/art-platform/workspace/scenes/saves/abyss-art-card-candidate.gil`；此前向用户提供的 `build/miliastra/scenes/saves/abyss-art-card-candidate.gil` 也是本轮测试副本。首次准备时原始 GIL 与复制时 SHA-256 一致；已导入的卡牌测试存档另备份为 `build/art-spike/imported-card.gil`。原始截图/运行记录在该 worktree 的 `build/art-spike/`、`build/miliastra/playtests/`，包含账号信息，留本机，不推仓库。

## Agent 分工与集成

三个干净 Session 已分别交付独立 draft PR：[场景 #25](https://github.com/CHNISam/Slay-the-Abyss/pull/25)、[肖像 #26](https://github.com/CHNISam/Slay-the-Abyss/pull/26)、[卡牌 #27](https://github.com/CHNISam/Slay-the-Abyss/pull/27)。主 Agent 只做候选绑定、实机验收与集成；独立复核已发现并修正肖像 Y 偏移，320 个位置契约通过，裁切限制仍未解除。

后续 TASK-25.1（卡框/图标）、TASK-25.2（肖像/卡图）、TASK-2.1（原生场景）依赖 TASK-10.1，保持 To Do。实机通过后，按各自批准的流程在独立 worktree/feat 分支制作，文件名绑定资产/卡牌 ID，各自验证并提 PR → develop。只有主 Agent 操作 MCP/GUI 与中央 Backlog；集成时复核来源、预算、输入输出哈希、三层证据和同屏结果。正式可用路线通过后再将本页收敛为生产规范或 Skill。
