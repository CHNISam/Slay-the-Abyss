---
id: TASK-56
title: 验收猎人完整卡池、来源与自然构筑
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:59'
updated_date: '2026-10-28 01:36'
labels:
  - required
  - sts1
  - builds
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies: []
references:
  - data/SOURCES.md
  - docs/SCOPE.md
  - docs/backlog-details/DRAFT-1.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/CLASS_CARD_HANDOFF.md
  - docs/M3-STATUS-20261028.md
priority: medium
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
猎人75张职业牌已接入当前运行时，基本版和升级版均被效果系统接受；奖励、生成和商店来源各71项均有对应定义。继续核对实际效果、来源随机链及合法组合，并补自然构筑、正式平台和四幕通关证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 职业选择控制器、初始生命/牌组/遗物和普通职业池隔离已接入并有本地回归。
- [x] #2 当前61/75张实验牌的基本/升级与毒、小刀、弃牌机制已合入并有对应真实Combat回归。
- [x] #3 已有代码、覆盖账本与离线界面证据已留档，实验入口和正式平台未验状态分开记录。
- [ ] #4 补齐剩余14张以及状态、衍生、复制和合法生成依赖，完整75张基本版和升级版均可按原版执行。
- [ ] #5 接齐完整职业常规池与合法跨色来源，逐项验证获取、稀有度、概率和随机消费。
- [ ] #6 各类构筑及合法混合组合经自然奖励/商店取得、升级、连续战斗和跨节点继承验证；不能用预设牌组替代。
- [ ] #7 全池卡牌、遗物、药水与职业机制交互覆盖边界和触发顺序；未实现项不得据现有子集测试放行。
- [ ] #8 正式平台开放职业入口，同一候选逐职业通过全部已开放章节，保留本轮日志与截图。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮用户明确授权隔离开发暂免远端认领，保持全局paused，不提交、推送或合入。先固定公开规则来源，独立实现职业基础模块及定向测试，再由主执行者复核共享Combat入口与后续接入；完整卡池、平台和实机验收保持未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25：用户明确授权本轮隔离开发暂免远端认领；全局paused未解除。基线877c4af，未提交/推送/合入。综合可审查目录 /workspace/sts-integration，说明 docs/rules/CLASS_FOUNDATION_INTEGRATION.md；各独立树 /workspace/sts-silent、/workspace/sts-defect、/workspace/sts-watcher 保留。隔离首片：毒牌/Shiv/BladeDance经真实Combat.play执行；基础/升级BladeDance生成3/4张未升级飞刀，真实UID、满手溢出、费用和消耗。10组模块测试及7组跨职业集成测试通过。手动弃牌、职业选择、自然获取与完整卡池仍未实现。 Sub-Agent交付已检查实际文件和运行结果；源研究与实现为免费与否未知的本平台subagent，不声称额度节省。

后续开发检查点：/workspace/sts-integration冻结版本完整npm run check exit0，JS1347项、Lua228顶层文件全执行、Python22项，Node/Python无跳过；新增14个Lua文件共198组。源/测试SHA256验证未改变，原始日志build/classes-full-check.log。三实验职业原始初始牌组通过seed42首间真实普通房间胜利并进入第二间验证重建；普通发布入口仍默认战士。已接扩展牌、战术大师/本能队列、Focus正数、姿态能力循环。完整卡池/概率/平台UI/实机仍未完成。下一阶段隔离树/workspace/sts-next继续毒流、集中生命周期和占卜，新阶段不计入本冻结检查点。未提交推送合入，全局认领仍paused，用户本轮豁免仍适用。

2026-10-25 四职业构筑与界面冻结检查点 /workspace/sts-ui，feat/experimental-class-ui，基线877c4af。完整 npm run check exit0：JS1349/no skips、Lua247顶层全部执行、Python22；73个源/测试hash复核未变。包含毒流、Focus/Bias/球位、占卜队列、战士七牌、Accuracy、Mantra、职业菜单与mandatory choices及故障回归。独立review修复SharpHide致死使用牌处置、Devotion构造计数时点；旧失败/中断日志保留。当前92/300职业牌，208缺失；完整账本docs/rules/CLASS_CARD_COVERAGE.md，集成边界docs/rules/ARCHETYPE_INTEGRATION.md。原生参数注册/平台/实机未验。后续 /workspace/sts-builds 正接腐化消耗、弃牌减费、Loop/Electro与保留成长，不计入此冻结check。保持全局paused，沿用用户本轮隔离开发豁免；未提交/推送/合入。

本轮猎人实验Profile41/75，仍缺34。14攻击/延迟收益牌、AfterImage/ThousandCuts/Envenom接线；silent_attack_build.lua39真实case通过，包括真实Bane首击Envenom施毒后第二击、Artifact与全挡阻止额外攻击。41牌池自然构筑重跑中，旧seed65的24牌池证据不套用。原版完整稀有度/随机概率和平台仍缺。/workspace/sts-triggers，未完成或提交推送。

2026-10-25 最新165冻结检查点 /workspace/sts-checked（feat/verified-card-triggers）完整npm run check exit0：JS1349/no skips，Lua262顶层全执行无失败，Python22；597输入SHA256复核未变，build/card-triggers-code-hashes.json/full-check.log留证。仅4旧死亡处置fixture按源修正，165源码与原sts-triggers字节相同，旧两树失败日志保持。后续/workspace/sts-flow正在接下一69张牌（warrior状态29、defect engine63、silent tactics60、watcher flow27、展示21/512变体已定向绿），未将后续树算入本完整check或所有300完成。仍未提交推送合入，平台未验。

2026-10-26状态整理：PR206保留实验猎人61张，不是完整75张。当前毒/小刀/弃牌三个子任务已有本轮真实Combat复验，前3项验收已补勾；自然获取连续战斗和未证故障/交互继续保留。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26逐项AC拆分：职业基础/现有卡池/留档已完成，剩余卡、完整获取与跨色/全交互/自然各幕验收继续未勾；完整M3范围不变，原标准见AC快照。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。
<!-- SECTION:NOTES:END -->
