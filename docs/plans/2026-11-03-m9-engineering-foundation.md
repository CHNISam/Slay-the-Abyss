# 旧编号 M9 工程章程（历史）

> **现已重新编号为 M7。** 当前应读 [M7 现行工程章程](2026-11-03-m7-engineering-foundation.md)；以下保留原 #480/#485 命名与来源，不能按此旧编号领取 M9 任务。

# M9｜工程架构与性能强化：独立里程碑执行章程

> **状态：待实施的工程治理章程，不是项目优化已经完成。** 本文件只确立范围、分工、量化验收与独立评审。实现必须由后续独立代码 PR 完成；未满足退出门槛时，M9 和相关任务不得标 Done。

## 0. 为什么是 M9，不是 M4-E

- 2026-11-03 已核对远端：[#479](https://github.com/CHNISam/Slay-the-Abyss/pull/479) 的在途分支已经通过 Backlog 维护 **M7｜产品体验与核心特色**、**M8｜内容建设与扩充**。它目前尚未合并；不能覆盖、抢写其 Backlog 文件，也不能将 M7/M8 的规划冒充已落地 develop。
- 本工程专项正式使用 **M9｜工程架构与性能强化**。编号是逻辑身份，不代表必须在 M7/M8 完成以后才执行；**M9 在工程资源上先行，M7 的必需修复可并行，M8 批量扩张随后**。不能为了工程治理而长期冻结可独立交付的产品质量修复。
- **创建原生 Backlog 里程碑必须等 #479 合入，然后按 AGENTS.md 使用 Backlog CLI**：先查询现有 milestone，核实 M9 未存在，再由 CLI 创建、读回并核对实际内部 ID（预计 m-9，未创建前不视为事实）。不手工添加或移动 backlog 文件，不触碰 #479 的在途 29 文件。
- 本章程整合既有 [#473 工作单](2026-11-02-m4-engineering-throughput-hardening.md) 的未完成工程范围；保留 TASK-74、75、81、74.5、4.21 的任务身份和未勾 AC，必要新增仓库治理/独立评审缺口任务前先查重。已合入 #465、#469、#471、#476、#477、#478 均只作既有成果，不返工、不重复建单。

## 1. 可复现基线（每个执行 Agent 必须重取最新 SHA）

2026-11-03 观察快照：develop `86053d9f80f4243eb39c2c960354d3247d304eb9`。该 commit 的 [Quality](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41563581851) 与 Licenses 已通过，但 Full Quality 耗时约 **38 分 57 秒**，未达到 30 分钟目标。此前 [Full Quality](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41451628176) 完成于约 **42 分 31 秒**，每次比较须记录原始排队、执行和 runner-minutes，不能直接拿不同工作流/机器样本推断因果。

- Lua 源：`src/lua/` 目前 320 个文件，`abyss_combat.lua` 约 2269 行、`abyss_game_ui.lua` 约 1030 行、`abyss_actor.lua` 约 910 行；最近架构检查报告约 1853 条调用依赖边、0 既定门禁错误；配置登记 84 条 deferred-import。**这不等于完整图无 SCC**；每次重新记录唯一依赖对、调用位置、即时加载图、全图 SCC 的可比口径。
- 仓库当前 Git 树约 6701 个 Blob，解压尺寸加总约 216 MB（**不是 Pack/clone 字节，也不是游戏包大小**）。`.gitattributes` 已指定 137 个 PNG LFS 路径；少数未纳管的大 PNG、可生成的 native-art Lua/JSON、历史截图与测试 fixture 需要按用途区分，不按扩展名或 >1MB 简单全迁 LFS。
- 已实现多个有定向测试的局部优化，诸如奖励 owner 独立加载 69→2 模块、敌人意图 300 帧几何重复写入下降；这些均**不自动证明手机 FPS、首启或整局运行时改善**。实体设备、官方导入与容量验收仍由原任务的 AC 负责。
- 在执行 PR 首先出具机器可读的 `baseline.json` 与适量人类摘要：source SHA、分支/tree、工具及规则身份、全部模块/函数（含匿名、嵌套和新 helper）、完整依赖与复杂度分布、CI 原始 runs/jobs、UI 原生调用及生命周期计数、仓库对象/LFS/引用清单、实机 unknown 项。不能改写历史冻结基线以制造下降。

## 2. 范围与交付切片

### A. Core 架构与复杂度（TASK-74 / 74.5）

- 按模块职责和真实依赖边清理循环与反向调用，优先 Combat / Actor / CardActions / Run / UI 边界。减少 copy-only 与不必要全量模块加载；不得将 require 隐藏成动态加载或新建全局 service locator 来伪造低耦合。
- 治理 `Combat.queueNativePlay`、另一条独立出牌协议、`Actor.damage`、`MapUI.render`、`GameUI.new` 等实际热点；保留两种原有出牌协议、回滚/RNG/事件与对象身份语义。全部新增 helper 与匿名函数纳入同一质量报告。职责必须真实聚合，不能仅靠机械切文件/函数把 CC 迁移走。
- 验收报告列出全局最坏复杂度、CC>15 / CC>30 函数数、最长函数/构造器跨度、>1000 行文件、SCC 模块及内部边、反向依赖数量，逐项给基线与最终绝对值。已批准范围可设置新的**可执行收敛门槛**，但不得掩盖旧函数或只拿局部下降作为全局完成。

### B. 运行时与原生 UI 性能（TASK-4.21）

- 复测 GameUI 切页重复 render、静止卡牌几何重复提交、稳定药水拖动重复预演、Grid/Controller 生命周期及奖励/怪物 UI 等热点。每项必须有真实生产 Host 基线、精确数量、有状态改变/销毁/重入/false/throw 负控及同入口前后差分。
- 不牺牲官方画质、保留动画、点击热区、输入无障碍、安全区、原生失败恢复；禁用以 stale cache 掩盖副作用。获得真实同版本设备对照以前，不宣称 FPS/内存/加载验收达标。

### C. CI 完整吞吐与多 Agent 并行（TASK-75 / 81）

- 按当前 GitHub hosted 原始 runs/jobs/步骤和实际完整测试文件集定位排队、耗时最大分片、重复准备/依赖安装/资源下载、取消浪费、文件权重偏差。先做无损去重和稳定排序，再评估重分片或缓存，不增加常驻服务或无界 runner 开销。
- 目标：**Full wall time ≤30 min**（同一已核实的完整工作流及 Required 全覆盖），Fast 自然 PR 样本至少 20 个且 P50≤5 min、P90≤10 min；同时报告 runner-minutes、queue、cancelled 执行量。样本不足不能声称达标。
- 原 `check` / `engineering-posix` / `presentation` / `inventory` 及 GitHub Ruleset、完整 Windows+POSIX 覆盖、测试强度、失败/缺片拒绝、SHA/attempt/delivery 合同全部保留。不得通过少跑、跳过、放宽预算、删断言改善数字。

### D. 仓库体量、LFS 与目录导航

- 审计 Git tree 与**可选**历史 pack/clone、当前 LFS OID/size、CI 精确下载集；按 `手写文本源`、`可再生派生物`、`不可再生二进制素材`、`活跃回归 fixture`、`历史证据` 分类。
- 大型原始 PNG/JPG 评估新增精确 LFS 纳管；Lua/JSON 可审查源数据留普通 Git；可重复生成的中间产物先证实重建/哈希等价才考虑不再跟踪；历史证据/字节认证测试不擅自删除、压缩、改名或迁移。
- **不重写 Git 历史、不强推、不批量 `git lfs migrate --everything`**；迁移前验证 LFS 对象可读/授权/额度/Hash、当前 CI 按需下载与许可证审计、跨平台 checkout、离线构建、候选装配。不能把 Git blob 减少称为已减小游戏安装包。
- 先更新现有 `docs/ARCHITECTURE.md` 的职责/所有权/依赖导航；物理移动 `src/lua` 前必须证明 require、生产候选映射、Fengari、相关回归无回退。

### E. 多 Agent 并行交付管理

- 一个协调者对比最新 develop、Backlog 和在途 PR，维护独占文件/函数列表；独立工作树/短 feature PR，每个共享文件只有一个集成者。不能并行改同一注册表、主题、工作流或历史冻结文件。
- 执行方逐片实现、每片保存 baseline→RED→GREEN、负控、完整行为轨迹与来源；只读审查 Agent 从**全新上下文**出发，接收最少的任务目标、准确 base/head、独立启动方法，不预先接受实现者的口头 PASS。
- 审查方亲自读取 `diff` + 邻接调用者 + 现有合同 + 全部新 helper，独立执行定向及组合测试，主动构造至少一种有意义的错误变异/边界反例；独立提交 `PASS / REQUEST_CHANGES`、未解决清单与可复现证据。原作者不得扮演自己独审；每次修复后须基于**新的精确 SHA** 复审。
- 与 CI 并行进行独立审查，但只有精确 HEAD 的全部 Required Checks、审查、deliver receipt 合格后正常 squash → develop；合后重新验证真实 commit/tree/push CI。不得复用旧 green SHA 或隐式使用豁免。

## 3. M9 结束门槛 / 审计失败条件

- [ ] **Backlog 真落地**：#479 合入后使用 CLI 创建 M9，正确关联既有工程任务，保留原 AC、所有者与其他 M7/M8 内容；每个未达项目明确是残余任务还是范围外项。
- [ ] **全面盘点**：提交当前 SHA 的模块职责/依赖图/SCC/反向边、复杂度分布、运行时热路径、CI 成本、Blob/LFS/证据依赖完整台账；记录所有 P0/P1 结论。
- [ ] **可验证改进**：每项实际更改给绝对前后值、风险/收益、错误变异与旧新业务轨迹；影响范围内无未解决 P0/P1，且没有新增热点、结构反向依赖或隐藏状态退化。
- [ ] **CI 达标**：在样本条件满足时 Full ≤30 min、Fast P50≤5 min/P90≤10 min，覆盖不缩水，runner-minutes 与取消成本明确报告；不满足则任务保持 In Progress，禁止伪称完成。
- [ ] **独立审查**：至少 1 名与实现上下文隔离的 reviewer 对**最终组合树**复核源码、构建/回归、反例与证据，明确 `unresolved=[]`，覆盖单 PR 评审可能遗漏的跨 PR 交互。
- [ ] **精确集成**：所有必需 Quality + Licenses 成功并校验 head/base/attempt 及合并收据；squash 后重新确认 develop commit/tree/push CI。游戏规则、RNG、事件、出牌手感、画质和平台加载预算均不回归。
- [ ] **实机边界**：没有同候选官方客户端/PC/实体手机的证据时，对应性能与品质 AC **UNVERIFIED**，不可自动标 Done；设备验收未满足时 M9 仅能标有条件工程成果，不能标“全维度已完成”。

**阶段交付顺序**：#479 合入 → Backlog CLI 原生建 M9 → A/B/C/D 独立短 PR（优先可量化的 UI 热点与真实反向依赖）→ 清洁上下文组合审查 → 全部计量与 CI → Owner 验收决定是否开放 M7 大规模开发。此文件、PR 及 Google Sheet 均为计划/只读镜像，绝不代替原生任务状态与代码实现。
