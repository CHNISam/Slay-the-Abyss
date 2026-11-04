# 领域架构边界 Implementation Plan

> **For agentic workers:** 使用既有执行流程逐项实施；无独立子代理时不得把自审写成独立复审。以下均为后续实现步骤，本设计 PR 不勾选完成。

**Goal:** 保留状态/事务/随机语义，先移除 Actor→CardActions 的反向入队依赖，并让同类回退被现有架构检查拒绝。

**Architecture:** 领域与技术层次分开；状态提交责任不迁移。先在 Combat 内提取无自有状态的反应入口，再启用覆盖该边界的确定性规则；不以全库标签、动态注入或更多 helper 冒充解耦。

**Tech Stack:** 既有 Lua/Fengari、Node、luaparse、GitHub Quality；不新增依赖或独立 CI job。

**Spec:** [领域架构设计与源码裁决](2026-11-03-domain-architecture-design.md)。

## Global Constraints

- 原 core/ui/platform、动态加载/平台全局限制、即时循环检查、完整图报告、复杂度与全部 Required Checks 保留。
- 玩法、RNG 流身份/消费次数/顺序、对象别名、UID、队列时序、错误/返回值、暂停/续动/胜败及原回滚边界不变。
- 本轮第一实现只覆盖 D1/D7/D8；D2–D6 的所有权约束是不可破坏的保护条件，不据此扩大为全库重写。
- 重新读取最新 develop 和在途 PR。#488/#487/#495/#492 已合入，保留其源码、证明及阶段编号，不重做 Copy 解耦；#494 修复已由 #501 合入，#496 自动合并由独立 PR 接续，本计划不重复变更。Backlog 只经 CLI，复用 TASK-74。
- 实现者拥有 Git/Node/Lua 完整执行环境后才实施。源码连接器读回不能替代构建、单测或独立审查。

## Review Focus

1. 只有 legacy 队列、只有 actionQueue、两者同时存在时的优先路径与 item 身份。
2. source 默认值、top 参数、重复入队顺序、无额外 drain/验证/RNG 消费及原返回值。
3. 下游抛错/choice 暂停、Run 命令之后奖励失败时的整体回滚与重试；不能只验证入队数组相同。
4. CardActions 函数替换/monkey-patch、外部 API 与测试 source-inverse 链，不能以新入口静默绕过旧保障。
5. 结构门禁覆盖延迟 require、注释/字符串/局部 shadowing、未知目标和过期规则；静态成功不自证注入能力的语义独立。

## Task 1：固定现状行为，不先改生产逻辑

**Files:** 新增 `tests/combat-reactions.test.mjs`、`tests/lua/combat_reactions.lua`；读取 `abyss_actor.lua`、`abyss_card_actions.lua`、`abyss_action_queue.lua`、Run 公共命令及邻接调用者。

**Interfaces:** 消费现有 `CardActions.enqueue(state,effect,source,target,instance,top)` / `enqueueReaction(state,effect,top)`；产出旧新共用的输入/结果/身份/错误断言。

- [ ] 运行 `backlog instructions overview` 和对应执行指引；核对最新 base、已有任务、开放 PR。记录源码 SHA 与调用者清单，查找对 CardActions 入队函数的赋值/替换。已知清单包括 `tests/lua/plated_armor_queue.lua:76–81` 对 enqueueReaction 的观察，以及 legacy enqueueReaction 动态调用 CardActions.enqueue 的合同；基线先确认两类替换均可拦截，不能只比较最终队列。
- [ ] 用现有 test-lua/Fengari 包装方式写夹具：覆盖 legacy/typed/同时存在、顶部/尾部、source 默认、引用身份、非法 typed action 的原抛错、暂停与重试；记录原方法返回值而不是自行发明 bool。
- [ ] 在旧生产实现上跑基线；对 top/bottom 对调、忽略 actionQueue、深拷贝 effect、自动 drain 各做临时负控，必须由对应断言失败，不提交负控源码。
- [ ] 锁定旧源码和 oracle 的来源；不允许只把旧新同时替换成同一新 helper 再声称等价。

## Task 2：最小提取 + 真实组合验证

**Files:** 新增 `src/lua/abyss_combat_reactions.lua`；修改 `abyss_actor.lua`、`abyss_card_actions.lua`、`config/architecture.json`（新模块 core 分类及必要的精确旧 deferred 项清理）；扩展 Task 1 测试及 `tests/responsibility-complexity.test.mjs`，修改 `scripts/check-lua-static.mjs` 的职责模块选择规则。不改 ActionQueue 的执行/校验实现。

**Interfaces:** 新模块提供同签名 `enqueue` / `enqueueReaction`；CardActions 保留两个公开入口；Actor 使用新反应入口。所有函数无新的跨调用私有可变状态。

- [ ] 先加失败测试：新模块可独立加载，导入图不含 Actor/CardActions/Combat；恢复 Actor 的旧导入会被结构测试发现。
- [ ] 从现有两个入队函数提取同语义实现。保留 Actor 原 source==player 断言、legacy item 的默认字段/引用、typed Queue 的原校验和错误。
- [ ] 全部调用方与替换测试确认后再接线。分别验证 Actor 改接新入口后 enqueueReaction 观察仍有效、legacy 路径仍保留 CardActions.enqueue 动态分派合同；公开委托不能只保留名称和签名而丢失这些行为。若不能保留现有受支持的拦截合同，停在 Draft 说明差异，不自行扩大兼容性承诺。
- [ ] 运行旧新轨迹、来源证明、伤害/反应/死亡、暂停选择、Run.play/endTurn/choose 之后奖励失败与回滚测试；确认永久变化仍按原命令时机发布。
- [ ] 新模块纳入候选打包和现有复杂度检查：现有 `scripts/check-lua-static.mjs` 的 responsibilityHelper 不匹配 `abyss_combat_reactions.lua`，须显式纳入职责硬门槛；在 `tests/responsibility-complexity.test.mjs` 加新模块超限失败、合法复杂度通过的回归，不能只依赖全量 report-only 测量。验证安装/生成模块列表没有遗漏。此步骤未验不得以离线 import 成功替代候选完整性。

## Task 3：在现有检查器守住已验证边界

**Files:** 修改 `scripts/check-architecture.mjs`、`config/architecture.json`、`tests/architecture.test.mjs`；新增 `tests/architecture-boundaries.test.mjs`；更新 `docs/ARCHITECTURE.md` 的已实施状态。

**Interfaces:** 保持 `analyzeSources(sources,policy,generated)` 和既有 `{schemaVersion,parser,sourceHashes,nodes,edges,errors}` 报告形状；新违规写入原 `errors`，不新增扫描/命令/job。

配置增量使用 `dependencyBoundaries` 数组；每条 `{id,from,forbiddenTargets,reason}`，from/forbiddenTargets 为非空、唯一的精确模块名数组。第一批：Actor 禁止 CardActions；reaction 入口禁止 Actor/CardActions/Combat。这是永久架构依赖规则，不是 Agent 编辑权限。

- [ ] 先写失败测试：重复 id、重复/空成员、未知/已删除模块、空 reason、违规即时和延迟 import 必须失败；注释、字符串、局部 require shadowing 不误报。合法旧层次与生成模块规则保持。
- [ ] 复用解析后的原始 edges 检查所有命中关系，**不能过滤 reviewedDeferred**。当前生产 policy 必须包含已批准边界；纯 analyzer 的历史 fixture 缺少新字段仍可只测原规则，不能据此让生产配置静默丢规则。
- [ ] 加当前生产政策防删除测试（要求规则 id 和语义存在，而非锁整份 JSON 字节/空白）。生产缺规则和改空数组必须 RED；合法重构移动边界需明确评审修改政策。
- [ ] 执行 `node --test --test-concurrency=1 tests/architecture.test.mjs tests/architecture-boundaries.test.mjs tests/combat-reactions.test.mjs`，然后 `npm run check:architecture`、`npm run check:engineering` 与对应 `test:related`。每个命令以实际输出判定，缺工具/缺 fixture 不跳过。
- [ ] 取同环境前后报告：Actor→CardActions 消失、反应入口加载集合受控、完整 SCC/调用位置变化如实记录；保留仍存在的长环，不用新模块数量做 KPI。
- [ ] 当前精确 HEAD 的独立复审、完整 Required CI 和正常合并后验证均通过才收口。历史 source-inverse 对新增注册的失败逐项精确适配，不刷新 oracle 或删除断言。

## 后续范围：不是本轮顺便扩大实施

RelicHooks 的 session/combat 拆分先盘点全部公开函数及调用者，分别保留永久事务和战斗触发顺序；原兼容门面不能被两个新子模块反向导入，否则仍形成环。Run/Nodes 的必要编排关系保留；copy-only 依赖承接已有 PR。

域内职责规则与域间入口规则逐项从“已审定设计”升级为“已测试门禁”。没有完成全量模块源码审阅与明确债务归属前，不宣称全库领域化完成，不一次给所有调用发永久通行证。

**停止条件：** 新旧行为不同、反应入口反向导入业务、只把依赖藏到参数/全局对象、增加重复注册表或造成无收益的验证负担，均保持 Draft 并修正；不为排期放宽原门禁。
