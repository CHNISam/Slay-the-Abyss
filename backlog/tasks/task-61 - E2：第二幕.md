---
id: TASK-61
title: 接齐第二幕敌人、事件和正式游玩流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:59'
updated_date: '2026-10-26 15:35'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-63
  - TASK-59
references:
  - docs/SCOPE.md
  - docs/backlog-details/DRAFT-2.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: high
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已通过PR213合入第二幕18至34层地图、遭遇权重/队列、Boss选择基础和换幕资源迁移，复用TASK-63，不重写地图。M3剩余：实际怪物与三Boss AI、13普通事件及共享事件交易/战斗、正式Host和章节UI，随后四职业连续通关。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，接上第35层
- [ ] #2 13普通事件及神龛、一次性事件资格、内部交易和事件战斗真实执行
- [ ] #3 四职业分别正常连续通关且资源继承正确，保留同源本地、集成和平台证据
- [x] #4 第二幕18至34层地图、来源队列与跨幕资源迁移基础已合入PR213并有独立向量和事务回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26 bounded source-first slice: independently implement Spheric Guardian A0 and explicit solo / ordered Sentry-and-Sphere definitions; reuse Actor Barricade/Artifact/Frail, register AI dispatch and queued rolls, add pinned source facts, strict data validation and actual Combat API regressions. Preserve act_content_unavailable, full campaign/native acceptance and all current task metadata/AC.

父执行者本轮追加授权：只补首发账本exclusions.enemies的REQUIRED-M3未正式接线记录，保持正式敌人非空渠道与真实绑定等式不变；补第二幕目录本地及规范路径的构建输出别名保护，并用伪造完成/准入/证据与链接别名反例检验。

2026-10-26 Beggar 独立切片（当前 d8a2622）：仅接第二幕 Beggar 的来源映射、事件状态与 Nodes 命令。按固定 319009d5 来源，Intro 支付75一次进入 GAVE_MONEY，再确认进入不可取消的一张非瓶装可清除永久牌选择；复用 LivingWall/Run.removeCard 事务。移除失败保留已支付中间态，空组保留待处理且不编造退款、零选完成或额外支付门槛。新增定向来源/实际 Lua 回归，完整池和正式章节门禁不变。原生 NodeUI 等 PR228 集成，不在此切片声称平台或完整 AC2 验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第二幕地图/队列/转场共享基础，但第二幕怪物AI与事件体尚未实现，正式Host未接，不能当内容齐备。仍To Do；内容实现从现有核心继续，勿重写地图。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26 Spheric Guardian 有界离线切片：新增PC A0 AI和固定HP20，开战按Barricade→Artifact3→Block40，Block25→10伤害及Frail5→10×2与Block15后10伤害交替；保留开局及每次行动末0..99选招消耗。第二幕定义仅按既有来源ID映射单体和Sentry先/Sphere后的编组，不改第一幕18项池、权重、地图或正式章节开关。20组真实Combat命令回归、189项相关Node、9份既有Lua、语法/架构/固定Luacheck通过；两个隔离语义退化均被新回归检出，独立只读复审未发现阻断。首次夹具断言失败原日志保留并已修正。MonsterHelper检索文本与旧来源锁摘要不一致，旧锁未改、明确保留字节来源不确定，未将其称为PC二进制认证。完整check尚未宣称通过：新增定义引发旧首发清单精确数量门禁，等待父执行者统一处理未正式接线内容账本。第二幕敌人/事件/Boss完整内容、Host、四职业连续自然通关和平台验收均继续开放，AC与任务状态不变。

2026-10-26补充：新增定义的账本数量门禁已按父执行者追加授权修复，不把第二幕内容改为非首发或伪造合法渠道。exclusions.enemies明确REQUIRED-M3 / OFFLINE_SLICE_ONLY / UNWIRED及平台、自然通关NOT_RUN；正式与暂存ID全集精确覆盖、互斥唯一，实际第一幕正式绑定不得被排除。72项账本/数据构建/原首发回归通过，最终30项来源/数据/输入别名测试通过；真实首发Lua支持门禁、build:data、Backlog与最新JS语法通过。新增链接反例覆盖本地目录及从另一输入目录构建时实际读取的规范目录；父独立复审未见阻断。仍未运行最终一次完整npm run check、当前SHA远端Quality、官方构建导入或实机验收，不据此关闭TASK-61或勾其开放AC。

2026-10-26 Beggar 有界核心切片（独立 d8a2622 源码副本，待 ROOT 集成）：新增 abyss_act2_events 与 Nodes/池映射，支付75与下一次确认/强制一张非瓶装可清除牌分开事务；永久移除只走 Run.removeCard。移除钩子异常或过期数据拒绝不退还此前已支付金币；空组保留待处理和来源未证实边界，不发明零选完成、退款、取消或额外施舍门槛。新15组实际 Lua /2项 Node 来源合同通过；相关10份 Lua 与9项 Node 通过；三项隔离变异（费用、可取消、绕过永久移除钩子）均触发原断言失败，产品源码未改。JavaScript语法、仅临时添加新模块core分类后的架构、固定hash Luacheck1.2.0通过，分类文件已恢复供ROOT统一合并。只证明公开核心命令，不是原生NodeUI、独立RNG真值、完整第二幕或AC2全部验收。来源为固定319009d5反编译镜像，本地提取文本摘要不作正版二进制/规范字节认证；未复制Java原文。独立只读审查无阻塞发现。没有改AC、状态、Assignee或正式章节门禁。

2026-10-26 两个离线内容切片统一集成：以当前 develop 06d2f5bcbe412a161c1883c23c4c9dc45884049c 的真实文本和完整 Git 树为基线，保留全部既有文件、115项架构分类及政策，将 Spheric Guardian 与 Beggar 的计划、备注和 core 注册合并，未覆盖任何作者记录或 TASK-61 的状态、Assignee、描述与 AC。真实新回归为20组 Guardian Combat 与15组 Beggar Nodes；18份相关既有 Lua、6项相关 Node 加1项 Living Wall完整来源矩阵均已有本轮通过记录，68项账本/数据构建/输入别名测试通过，语法、Backlog、架构与固定 Luacheck 无新增诊断。集成首次 build:ui 因新增定义缺图标/动作音效失败，并使既有永久移除原生夹具缺 abyss_theme；保留原失败，只在主题中明确暂复用既有 Sentry 的112027/50421，并标记非新美术批准及非原生验收，不削弱逐定义覆盖门禁。真实 build:theme/build:ui、87项主题与 Guardian 边界测试及失败夹具7组随后通过。当前相关层计划因任务/配置/数据改动保守回退完整检查；本轮未把这些定向结果冒充完整 npm run check 或当前 SHA 远端 Quality。MonsterHelper 旧字节锁差异、Beggar 空组强制待处理及先付款不退款边界保留。未引入 TASK-63/MapUI、原生 Beggar picker、章节解锁、全局池改写或新机制，官方导入、四职业自然连续通关及所有开放 AC 继续待验。

验收措辞补充：上述永久移除的“原生夹具”仅指本地离线 NodeUI 模拟回归，不是客户端原生平台实测；平台与自然游玩仍为 NOT_RUN。
<!-- SECTION:NOTES:END -->
