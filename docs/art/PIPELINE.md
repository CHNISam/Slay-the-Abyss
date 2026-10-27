# 首发美术流水线：候选流程与实机门槛

2026-10-27 Owner已确认精修重绘的视觉质量基线；原创设计须连同实际重绘和完整卡面交审，见 [卡牌插画标准](CARD_ILLUSTRATION_STANDARD.md)。这不自动放行75张扩产或替代平台验收。

2026-10-26按用户要求迁移原版的资源索引/共享卡面装配结构，已接入战斗、奖励、牌库和节点的原生生产路径，见[卡牌装配移植](CARD_RUNTIME_PORT.md)。图片仍只使用平台允许的原生资源；占位与未完成插图分开登记，不重造导出器。

用户两张 AI 样图的最新独立实验见 [AI_ART_SAMPLES.md](AI_ART_SAMPLES.md)：整图 A、裁切编辑 B、角色面部 B2 与星陨剑完整卡面均已导出；测试副本静态通过，官方导入/本次实机显示待验，尚未放行量产。此结果不替代下文已通过的原生单卡 UI 门槛。

关联 TASK-10.1，2026-10-23。电脑单卡原生 Lua 路线已实机通过，范围与可复用参数见 [CARD_PRODUCTION.md](CARD_PRODUCTION.md)（TASK-10.1.1）。仅放行少量通用卡牌资产制作；十张手牌、长文案、多设备、肖像与场景仍分别验收，完整卡池尚未放行批产。

| 资产 | 复用路线 | 本轮证据与决定 |
|---|---|---|
| 卡牌 UI | Image Editor JSON → 原生图片/文字 Lua；GIA 备用 | v2 卡面 15 控件（11 图、4 字）；用户已导入并试玩，标题/类型/图形/费用/说明与点击更新通过；10秒客户端dt均值33.3/P95 34.0ms，无基线或多卡结论 |
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

v2 已写工作区副本并通过静态检查（0错误/0警告），用户官方试玩截图确认缺字修复与点击更新。准备脚本默认已切到此版本。它另加一行高度40的 `Metrics` 探针，将10秒客户端回调dt均值/p95直接显示；本轮为33.3/34.0ms，非GPU耗时。原版与v2比较必须记录探针的额外控件，不能把同屏整套UI成本推成一张卡的成本。

## 实机验证与切换规则

1. 导入候选为**新测试存档**，保留原始存档。单建筑和 7 件景片用不同干净副本，按场景报告中的现成 JSON 构建/安装/导入；随后读回真实 GUID。导入会新增实体，不能重复导入同包。
2. 卡牌试玩 15 秒，在第 3/10/14 秒截图，第 6 秒点击下方“点击检查”。确认中文、费用/说明、层序和点击后的“点击通过”，日志有 `ART_PROBE_START`、`ART_CLICK_OK`；检查运行时错误。
3. v2 的 `art/spikes/platform/probe.lua` 将10秒客户端回调dt均值/p95显示在 `Metrics` 并打印；原版只打印。它不是GPU帧时间，也不是手机性能。先测相同底图基线，再测小样与计划同屏数量；记录首次可见耗时、卡顿、控件数、连续进入/退出3次后的清理情况。没有实测数字不填“性能合格”。
4. 电脑/手机/主机画布分别截图。手机安全区按 1280×720，电脑 1600×900，主机 1920×1080；编辑器画布预览不能代替目标设备性能。场景另验镜头、门洞朝向、脚高、遮挡与碰撞。
5. 任一路出现坐标/裁切/画质/成本不合格，停止扩大数量，换已通过的小样或明确的原生占位。肖像本轮已按此切换，不继续增加拟合预算。占位缺口必须留在首发清单中。

## 当前阻塞与证据

[结构化证据](evidence/2026-10-23.json)。此前两轮自动导入均在文件框前失败；**用户现已手动完成导入**。已从新测试存档读回 `ART_Spike`、`ART_Card`、`ART_Probe`、五个静态宿主/探针控件；外部两个 Lua 源文件与候选逐字匹配（仅统一换行），读回后的静态检查仍为 0 错误/0 警告。整份 GIL 经编辑器重写元数据后哈希不同，因此用结构和脚本内容确认导入，不要求原始文件哈希不变。

原版试玩可见卡框、费用1、岩晶和“造成6点伤害”，但“打击”和“攻击”缺失；点击后的上方文字为“点击通过”。随后用户导入v2并给出两张实机截图，标题、类型均出现，费用/说明/图形保持完整；第二张同时记录“点击通过”及10秒客户端dt均值33.3/P95 34.0ms。截图SHA及本机证据目录见结构化记录。电脑单卡门槛通过；无基线、多卡、目标设备或重复进入/退出的验收结论。

自动操作的前台切换仍有问题：两轮 `playtest_start` 报“无法把窗口切到前台：sandbox”（run `8fd0a901`、`f891c7e9`），逐步工具后续也返回 `FOCUS_FAILED`，故后续采用用户操作+截图取证，没有重复盲点、修改系统设置或绕过输入限制。

当前配方默认候选为 `build/art-platform/workspace/scenes/saves/abyss-art-card-text-v2.gil`；旧 `abyss-art-card-candidate.gil` 保留用于缺字对照。首次准备时原始 GIL 与复制时 SHA-256 一致。会话收口后，本轮截图、存档副本、运行记录及分支恢复包统一保存在主工作区 `build/art-closeout-20261023/`；集成工作树原build对应其下 `art-pipeline/build/`。包含账号信息，留本机，不推仓库。

## Agent 分工与集成

三个干净 Session 已分别交付独立 draft PR：[场景 #25](https://github.com/CHNISam/Slay-the-Abyss/pull/25)、[肖像 #26](https://github.com/CHNISam/Slay-the-Abyss/pull/26)、[卡牌 #27](https://github.com/CHNISam/Slay-the-Abyss/pull/27)。主 Agent 只做候选绑定、实机验收与集成；独立复核已发现并修正肖像 Y 偏移，320 个位置契约通过，裁切限制仍未解除。

TASK-10.1.1 单卡门槛与TASK-25.1首轮共享资产制作已完成。TASK-10.1.2只余实际多卡/长文/设备验收，回到To Do；TASK-25.2（肖像/卡图）、TASK-2.1（原生场景）仍等待各自路线实机门槛。父 TASK-10.1 遵循最新里程碑安排为 M4 / To Do，已完成切片另记；其余美术探针不阻塞M1基础C档，不追加可选研究。各 Agent 在独立 worktree/feat 分支交付，主 Agent 已统一复审并集成；后续正式组装仍需复核来源、预算、输入输出哈希、三层证据和同屏结果。

验证后的两位干净 Agent 已交付 [共享资产 PR #42](https://github.com/CHNISam/Slay-the-Abyss/pull/42) 和 [容量验收 PR #43](https://github.com/CHNISam/Slay-the-Abyss/pull/43)，主 Agent 复审后纳入本集成分支。共享套为4框/1背/3类型徽记，见 [CARD_SHARED_ASSETS.md](CARD_SHARED_ASSETS.md)；容量样本为0/1/5/10卡与42字长文，见 [CARD_CAPACITY.md](CARD_CAPACITY.md)。容量准备脚本失败清单问题已修正；主 Agent 实际生成五份副本，MCP静态检查均0错误/0警告，原始底图SHA保持一致。官方导入、运行时与目标设备表仍待测，不因文件生成而放行容量。

本轮交付统一由[集成PR #30](https://github.com/CHNISam/Slay-the-Abyss/pull/30)进入develop；内容已包含的子PR关闭，原分支通过本地Git bundle保留后清理工作树。用户已要求结束本轮，不再追加人工测试。已完成交付的合并与清理不以待办的实机验收作为阻塞，亦不把待办标为通过。
