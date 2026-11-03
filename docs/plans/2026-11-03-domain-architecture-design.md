# 领域架构设计：先定状态归属，再约束依赖

> 设计与定位 PR，非运行时重构完成报告。核查基线：`2f829579672e61a91374a2d8a0281d5cac4ca7fc`（develop，已含 #488）。后续实现读[实施与验收](2026-11-03-domain-architecture-implementation.md)。

## 1. 本次决策

**保留现有工程体系；补齐状态提交责任、公共能力入口和职责依赖约束。** 不恢复 #497 的 Agent 文件白名单，不增加任务锁、调度服务、模型调用或另一套 CI。

方案比较：
- 逐 Agent 限制改哪些文件：已撤回；不能解决代码自身的耦合。
- 只给模块贴领域标签：不足；Actor 与 CardActions 即使同属 Combat，仍有职责反向依赖。
- **采用：领域 × 技术层次 + 少数经过行为验证的职责边界。** 不强制六层，不换目录/加载路径，不为减少边数引入服务定位器、全局事件总线或动态 require。

本 PR 仅交付源码审计、设计裁决和可执行实施计划；`architecture.json`、检查器、玩法、CI、Backlog 均不在本 PR 修改。不能把本设计合入当成领域门禁已经上线。

## 2. 已定位的问题与不能误删的关系

以下链接全部固定到审计 SHA；符号是定位依据，完整 blob 身份见[证据索引](../evidence/domain-architecture-20261103.json)。不是全库动态数据流证明，也没有重跑最新全图 SCC。

| 编号 | 源码事实 | 架构裁决 / 对应动作 |
| --- | --- | --- |
| D1 | [Actor:15–21][actor] 的 enqueue/reaction 调用 CardActions.enqueueReaction；[CardActions:3,18–31][actions] 又导入 Actor。enqueueReaction 在 actionQueue 存在时压入 effect，否则进入 cardActions，均不执行/清空队列。 | **同一 Combat 领域内的反向职责依赖**，不是单靠 domain 字段能解决。提取战斗专用反应入队入口，保留两种队列协议和原公开 API；只删经验证的反向边，不承诺整个 SCC 消失。 |
| D2 | [Run.transaction][run] 克隆可变图并处理嵌套失败；[Run.play/chooseCard/continueCombatChoice/endTurn][run-commands] 在战斗命令后同步永久变化和 RNG，必要时再 finishCombat。 | **Run → Combat 是合理编排**。不能禁止整条依赖，也不能把永久状态发布改成“仅战斗结束时”。Run 公共命令拥有更外层的回滚边界。 |
| D3 | [Run.startEncounter][rooms] 通过 Combat.new 创建战斗并发布 generation/phase；[finishCombat/applyPermanentChanges][settlement] 负责结果、卡组变化、奖励和流状态。 | 将创建/同步/结算视为受控的 Session–Combat 边界。保留已有接口，不增加第二套 battle/run 状态副本或新的提交者。 |
| D4 | [Nodes.enter/advanceAct][nodes] 同时协调 Map 和 Run.transaction；enter 先 stagedMap，再成功提交路径等；[NodesCommon.complete][nodes-common] 实际写 nodeFlow 和 phase。 | Nodes 是**单局流程编排**，不是纯地图算法；Common 也不全是只读工具。不得按文件名把两者都放进无状态 World/Shared。保留地图根/path 身份及失败不发布语义。 |
| D5 | [RelicHooks.gainGold/onEquip][hooks] 修改单局数据；同文件 [enqueuePostDraw/upgradeRandomHand/onUsePotion][hooks-combat] 使用战斗队列和 Actor。 | **一个文件混合两种生命周期**。按 session hooks / combat hooks 拆职责，保留旧 API 兼容；不能把整包遗物代码标成 Shared 或纯数据来合法化反向依赖。 |
| D6 | [CardCapability.isImplemented][capability] 调用 Effects.supported、职业规则，判断“引擎是否实现”，不只查静态定义。 | 它是 Combat 对外的**只读能力查询入口**，允许 Session 获取/升级流程使用。不得搬到纯 Catalog 后一律禁止它依赖执行能力，也不能用固定 true 列表代替。 |
| D7 | [Events.frame/emit][events] 生成战斗表现帧；[ActionQueue][queue] 接受 effect/useCard，管理 paused/current 和选择续动。 | Events 不是地图随机事件；ActionQueue 不是通用 Shared。二者保留 Combat 归属：read-model / queue-runtime。 |
| D8 | [analyzeSources][checker] 已处理层次、平台全局、动态加载及即时循环；reviewedDeferred 只影响加载循环判定。调用者通过参数传入的 Combat/Run API 不等于 require 边。 | 扩展现有 AST/edges，不再扫描一遍。领域规则必须同时看即时/延迟边；**静态 import 检查不能证明状态所有权、注入参数或事务正确**，这些由契约测试和评审负责。 |

### 与在途工作的关系

- #488 已合入：不重做营地/奖励/事件的 Copy 解耦。
- #495 正处理 NodesCommon 的 copy-only Combat 依赖：作为已有实现承接，不另开重复修复。
- #494 处理 UI 生命周期；#487 处理事件文案与来源证明；#496 处理 Auto-merge；均不混入本设计。
- #492 尚在调整里程碑编号；复用 TASK-74 及其既有工程工作，不在此另编阶段号、不手工改 Backlog。

## 3. 目标结构：两个维度，不是七个互不相干的大桶

```text
现有技术层：core / ui / platform（原限制全部保留）
│
└── 业务归属 + 职责
    ├── Session（单局）
    │   ├── Run：公开命令、永久状态提交与跨战斗同步
    │   ├── Run rooms / settlement：战斗创建、结果与奖励
    │   └── Nodes：地图/事件/商店流程编排；不是第二个 Run
    ├── Combat（战斗）
    │   ├── Combat：事务、执行、暂停/续动、胜败策略
    │   ├── CardActions / Effects：效果和选择执行
    │   ├── Actor：实体规则与授权状态修改
    │   ├── Reaction admission：两种队列的入队能力【待提取】
    │   ├── ActionQueue：战斗队列运行时
    │   └── Events / battle UI：读模型 / 表现（分属 core / ui）
    ├── Exploration（探索）
    │   └── 地图拓扑、路线、房间规则；跨流程提交交给 Session
    ├── Catalog（定义）
    │   └── 只读定义及纯查询；不包括所有“卡牌/遗物”执行代码
    └── Foundation（基础算法）
        └── Copy、数值等窄能力；随机算法与“随机流由谁提交”分开

Platform 是技术层；Presentation 是表现职责，均不替代业务归属。
一个混合职责旧文件先标明债务，不靠归入 Shared/Mixed 放宽规则。
```

这不是全库模块已逐项分类的声明。首批核实的模块和混合职责见 D1–D8；其余模块必须由源码/状态用途确认，不能靠前缀批量判定为已审。

## 4. 状态提交责任：一个责任边界，不是只能一个文件写变量

| 状态 / 时机 | 提交责任 | 可委托与不可破坏的合同 |
| --- | --- | --- |
| run.deck、nextDeckUid、局内金币/生命/遗物/药水 | Run 的公开命令及其外层事务 | hooks 可在受控 staged 对象上修改；嵌套失败不得被吞掉后仍提交；不要求每个内部 helper 再开事务。 |
| 战斗实体、手牌/牌堆、能量、待选项 | Combat 命令事务 | Actor/CardActions/规则 handler 是执行者；保留 UID、对象别名、队列顺序、死亡/暂停/重入边界。 |
| run.combat、combatGeneration、phase 的战斗切换 | Run rooms / settlement，经 Session 命令编排 | 代次检查、创建失败不发布；Run.play 等命令可在战斗中同步永久变化，不推迟到结算。 |
| 地图路线 + nodeFlow 的一次进入/换幕 | Nodes 编排 + Run.transaction | 保持当前 stagedMap 成功后发布，原 map/path 引用稳定；不得把地图与 Run 分成两个可独立成功的命令。 |
| misc/card/shop/room 等随机流 | 对应 Session/Combat 命令的提交边界 | 算法可以共享，流身份、消费次数/顺序、回滚由原 owner 保持；不能合成一个全局 RNG。 |
| events 表现帧、UI 焦点/拖动/控件 | Combat 帧生成 / UI 本地生命周期分别负责 | UI 读取批准的视图并发命令；既有快照隔离合同不放宽，不让 UI 直接成为永久状态提交者。 |

## 5. 合法依赖：以调用能力而非“同文件夹”判定

```text
Session core 编排 ──→ Combat 公开命令 / 能力查询
                 ├─→ Exploration 的规则/地图接口
                 └─→ Catalog / Foundation
Combat core      ──→ Combat 内部按职责向下 + Catalog / Foundation
Exploration 规则 ──→ Catalog / Foundation
Catalog          ──→ Foundation（确有需要时）
Foundation       ──X→ 任何具体玩法/界面/平台
Combat UI        ──→ 战斗读模型 + Session 的 Run.play 等外层命令
Platform 入口    ──→ 装配/注入 UI 能力；原 UI→platform 禁止规则不变
```

**不要只对折叠后的 domain 图强制 DAG。** Session.core→Combat.core 与 Combat.ui→Session.core 可以同时合理存在；领域折叠会显出双向，但不等于实际模块形成循环。保留模块全图/即时图分析，按 `(domain, layer, role)` 判边界。

首批职责规则（实现后才启用）：
- Actor 不得导入 CardActions；它只需要 `enqueueReaction(state,effect,top)`。
- 新反应入口不得导入 Actor/CardActions/Combat/UI，也不 drain、不启动另一条队列、不持有全局状态。
- 跨 Session–Combat 的修改走已有公开命令；不得从外域导入 run_settlement 等安装型内部模块来取得提交权。
- Foundation 不依赖业务；Catalog 不把运行时 Effects/Actor 当只读定义。
- 延迟 require 不能豁免上述职责规则；注入整个万能 API 也不能被宣传成“已解耦”。

## 6. 首个重构的准确设计：反应入口下沉

新增 `src/lua/abyss_combat_reactions.lua`（名称为本设计选择，不是现有文件），仅承接现有入队逻辑：

| 接口 | 必须保持 |
| --- | --- |
| `enqueue(state,effect,source,target,instance,top)` | legacy cardActions 的 item 形状、source 默认、effect/instance 引用及顶部/尾部顺序。 |
| `enqueueReaction(state,effect,top)` | 有 actionQueue 时调用原 Queue.pushTop/pushBottom；否则走原 legacy enqueue；返回/抛错与现状一致。 |

CardActions 保留同签名公开委托入口；Actor 的 enqueue/reaction 调用新入口，原 source==player 断言保留。Combat 仍独占 drain、事务与结束策略；ActionQueue 的校验/暂停/续动不改。不一次迁移所有 relic/monster 调用者。

迁移前检查全部调用者、替换/monkey-patch 测试与函数身份依赖。若旧测试/调用方依赖 CardActions 函数替换拦截，须明确保持或报告兼容性差异，不能偷偷绕过。不存在证据时不得宣称完全兼容。

这一切口只承诺移除 Actor→CardActions 的直接边并保护行为。其他规则调用仍可能构成更长的环；不拿模块数、单函数 CC 或单条边下降冒充全局解耦。

## 7. 门禁与迁移，不制造另一套系统

- 在现有 `config/architecture.json` 和 `analyzeSources` 增加**有明确覆盖范围的**结构规则，复用同次 AST/edges 与原 errors 输出；不加独立 CI job/服务/模型调用。
- 先对已经完成重构的边界硬拒绝；其余领域归属/债务报告为未覆盖，不批量冻结全库现有依赖为合法规则。
- 结构规则与 Agent/分支/任务无关：任何代码修改违反已审定依赖方向都失败，不限制谁能编辑哪个文件。
- 既有债务必须列明 from/to、存在原因、承接任务、移除条件；新增违规不得借旧债务获准。删除后的债务不能静默复活。
- `deferredImports` 仅管旧加载语义，不兼任领域豁免；动态加载、全局可变对象/定位器不得用来藏边。
- 检查器必须用真实违反规则的反例证明生效；未知模块、被覆盖范围的缺失分类、过期规则和重复规则失败。尚未覆盖范围不伪称已保护。
- 历史完整源码/配置身份测试可能因正常结构变化失败；保留历史 oracle，只更新经认证的当前组合适配，不能删除旧断言或自动刷新基线。

## 8. 完成标准与非承诺

设计交付：D1–D8 有可追溯源码、状态 owner 明确、合法依赖与反例明确、实施文件/测试/退出条件明确。
实现交付另验：定向 RED→GREEN、旧新轨迹/RNG/回滚/身份一致、已治理反向边消失且新门禁能抓回退、独立复审、精确 HEAD 全部 Required CI 与合后验证。

全图 SCC、影响模块数、CI 时间和返工量均按同基线重测；不把历史 105 模块快照叫当前测量。不承诺纯正收益/零冲突，不以多拆文件作为成功。若只是把调用藏进参数、增加更多公共注册表或造成明显测试维护负担，拒绝该重构。

## 9. 参考与验证范围

借鉴 [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/) 的“架构不变量 + 机械检查”，不照搬其应用层数或合并政策；这里的领域与具体依赖决策来自上述项目源码。

本轮通过 connector 读取固定提交源码；容器不能解析 GitHub 域名，无法克隆/运行完整仓库，且 Backlog CLI 不存在。因此未改 Backlog、未运行 Lua/完整 CI、未取得独立审查；PR 保持 Draft。局部设计一致性校验不等于生产验证。

[actor]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_actor.lua#L1-L90
[actions]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_card_actions.lua#L1-L180
[run]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_run.lua#L1-L210
[run-commands]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_run.lua#L490-L686
[rooms]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_run_rooms.lua#L1-L200
[settlement]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_run_settlement.lua
[nodes]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_nodes.lua#L1-L170
[nodes-common]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_nodes_common.lua
[hooks]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_relic_hooks.lua#L1-L130
[hooks-combat]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_relic_hooks.lua#L130-L220
[capability]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_card_capability.lua
[events]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_events.lua
[queue]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/src/lua/abyss_action_queue.lua
[checker]: https://github.com/CHNISam/Slay-the-Abyss/blob/2f829579672e61a91374a2d8a0281d5cac4ca7fc/scripts/check-architecture.mjs#L83-L152
