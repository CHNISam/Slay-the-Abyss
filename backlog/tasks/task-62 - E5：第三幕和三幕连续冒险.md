---
id: TASK-62
title: 接齐第三幕敌人、事件和结局流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:02'
updated_date: '2026-10-28 08:22'
labels:
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
  - post-release
  - competition-deferred
dependencies:
  - TASK-61
references:
  - docs/backlog-details/DRAFT-6.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
  - docs/M3-STATUS-20261028.md
priority: low
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第三幕全部常规遭遇、精英、三种首领，以及心灵绽放、神秘球体、事件战斗奖励和绽放印记已随PR252/259合入develop；PR262继续接通终幕。旧PR238冲突与待合状态仅属历史。四职业自然连续通关、完整事件资格及同候选平台证据仍缺，保持未完成；第三幕没有Boss宝箱。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第三幕35至51层按原版生成，三种Boss完整执行，Donu和Deca只结算一次
- [ ] #2 七普通事件及共享神龛、一次性事件按资格出现并能执行，第三幕没有Boss宝箱
- [ ] #3 第51层缺钥匙走普通结局，满足资格与三钥匙才进入终幕，四职业分别三幕正常通关并保留证据
- [x] #4 第三幕35至51层地图、来源队列及普通结局/三钥匙门边界基础已合入PR213并有对应回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27用户试玩期间持续离线冲刺：按固定319009d5来源独立补MindBloom和MysteriousSphere；子线程各实现事件阶段和源规则，主线程接事件战斗构造/房间奖励桥、完整事务、原生显示及机器清单。保留普通怪物/Boss队列和原预算，先单项红绿再串行共享全链回归；当前可玩测试包b12beab2保持冻结。

2026-10-27 PR259独立复审：在f3faff19隔离树最小修正EndingHistory的历史预装职业身份；只用Profile.prepare同时写入且一致的experimentalCharacter/characterId回退，保留默认旅者和三原职业规则、拒绝Watcher/原创/冲突/不完整身份。添加真实Run.new回归，原种子与模式门禁不变；等待串行A窗口后运行专属历史、Host与静态邻接，原AC/状态/负责人不变。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第三幕地图/队列和普通结局边界，实际怪物AI/事件体与正式Host尚未接，仍To Do。第三幕不存在Boss宝箱；按现有核心接内容再连续通关。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-27接续状态：第三幕新增敌人/事件切片仍由PR238整合集成，远端head a4dac772为OPEN/DRAFT且CONFLICTING，未合并。同步fc51f198后Transient、Shapes、Shapes Defect、Orb Walker、Maw Growth定向通过仅为本地证据；最终整合仍有库存恢复/道具来源回归失败。先完成同一PR当前SHA验收，再补正式入口及四职业自然连续通关，不把独立切片计整幕完成。

2026-10-27优先级重排：High：第三幕敌人/事件/结局仍在PR238，当前先完成该集成再开放完整四幕验收。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27 独立源码增量候选补Awakened One两阶段、Writhing Mass、Giant Head：真实0HP半死/复活与非目标选择连续性、源AI/RNG/Reactive与永久Parasite取得、Slow实际卡实例afterUse时点及Java浮点次序均有固定319009d5来源和独立审查。补通用Run.play完整事务边界，晚期奖励抛错或拒绝恢复原始对象/RNG/永久牌并可重试。五叶合并保留现有三职业内容、Ghosts和源码公告，87项Node与177组既有Lua回归通过；178模块/1050边、Luacheck89历史警告0新增、构建/数据/UI主题门禁通过。此候选未包含下一批Time Eater/Nemesis/Reptomancer/Darklings，不宣称全第三幕/全M3/自然四职业四幕或原生验收；整项AC不关闭，当前新PR完整Quality待证。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。

2026-10-28主线与独立组件分层：PR252已合入develop 0c07e3dc，第三幕源敌人和三种Boss生产接线已齐，旧待合说明仅属历史。MindBloom与Mysterious Sphere各自离线组件已通过定向回归；共享事件战斗桥、生产绽放印记与完整治疗链、正常事件入口及自然/平台流程仍待整合验收。技术事实见docs/backlog-details/BACKLOG-UPDATE-20261027.md的10月28日节；组件通过不当整幕或全M3通过，原状态和全部AC保持。

本轮Codex并行分工：MindBloom模块、MysteriousSphere模块、终幕资格审计/历史owner独立树推进；共享Run/Nodes/Act3Events/EventPool/遗物配置由主线程集成，任务库串行CLI更新。用户正在自行试玩，全部执行者禁用桌面输入。事件战斗仍是EventRoom：源金币与稀有遗物在选择时准备，通用药水和卡牌在战后按原顺序执行；不冒用Boss终局或缩池。

2026-10-28 真实第三幕事件桥已接MindBloom/Sphere、预构造敌人、EventRoom固定金币/RARE与药水→卡牌奖励、烟雾弹结束结算、Mark共享及Run/Nodes治疗。独立审查发现跨房间旧owner残留、永久牌同步晚失败泄露和逃跑nil未发布，均有真实RED→GREEN；扩展桥12.350秒通过，来源桥7/7及相邻印记/历史/第三幕12/12通过，198模块1148边、84历史零新增/358度量。详细证据见docs/reviews/M3-EVENT-COMBAT-INTEGRATION-20261028.md。组件已挑入当前独立集成树；完整当前SHA CI和PR尚待收口，未新导入/实机/自然四职业通过，不关闭AC或M3。

2026-10-27 PR259独立复审修正：真实Profile.prepare→Run.new的silent/defect/watcher旧入口缺run.character时被误记为Ironclad，三类均在原f3faff19复现。新增真实四职业与五种冲突/部分/未知元数据回归，原8组先通过、第9组真实RED；最小canonical metadata pair回退后9组GREEN，Watcher不产生WIN或写入。整合独立已审d18fee14原生层级四文件原样；组合专属历史/Host/事件UI/原生Cursor六项Node全过0skip，架构198/1148、Luacheck1.2.0原84历史0新增及358职责度量通过。仅本地修正与受控边界证据，不认证自然通关、原生导入或持久平台历史；当前新HEAD完整Quality和交付仍由主线程核验。原状态/Furinya/全部AC不变。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
<!-- SECTION:NOTES:END -->
