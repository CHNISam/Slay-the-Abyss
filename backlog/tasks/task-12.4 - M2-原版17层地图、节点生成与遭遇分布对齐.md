---
id: TASK-12.4
title: 把第一幕地图规则对准原版
status: In Progress
assignee:
  - '@codex-m3-map'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-24 12:57'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-12
references:
  - data/SOURCES.md
  - data/rules.json
  - src/lua/abyss_map.lua
  - docs/backlog-details/TASK-12.4.md
  - docs/reviews/TASK-12.4-fresh-run-seed-and-encounters.md
parent_task_id: TASK-12
priority: high
type: enhancement
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对第一幕地图怎么生成、哪里能走、会遇到什么敌人，按初代《杀戮尖塔》的规则修正。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每条规则有可信的原版依据；不清楚的地方标出来，不猜。
- [ ] #2 确认15层地图、16层Boss、17层独立Boss宝箱，以及必出房间和路线连接规则。
- [ ] #3 敌人出现范围、重复限制和随机抽取方式符合原版，地图显示和保存也正确。
- [ ] #4 用多组测试检查路线、房间和出现概率；实际游戏里的结果另行确认。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3独立切片：先核对固定RoomTypeAssigner/Exordium/AbstractDungeon及Java浮点/洗牌行为；保留12原golden与已有拓扑候选接口，先写完整房型golden失败及独立配额/父兄弟/洗牌边界测试，再补同状态房型候选，跑严格完整12图与专项结构回归。生产迁移另需raw seed/restore/七列UI容量，不在本片猜接；不勾广义AC、不Done、不游戏/MCP/full。

2026-10-24 @codex-fresh-run-rng：独立feat/fresh-run-rng从5afd8a4处理正常Host固定seed根因。先写真实Host入口红例，核实原生种子来源后最小接线，覆盖初始化/宿主重建/同会话重开/显式seed复现及部署清单。只读核对固定Exordium/AbstractDungeon弱敌池、权重、重复限制和流隔离，明确生产缺口，不重复地图隔离候选、不操作游戏/MCP导入、不勾广义AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 @codex-m3-map：新增隔离完整房型候选（未接生产）。固定源RoomTypeAssigner/AbstractDungeon/Exordium与Java洗牌行为独立转译；路径结束snapshot恢复同一mapRng原语，再raw倒序洗牌，wrapper counter不增。新15项真实缺模块红0/15后绿15/15，12未改golden完整坐标/边/房型全匹配，含2780424839485660359；配额0..105 binary32边界、父/兄弟/行限制、独立raw状态向量和fallback通过。旧拓扑/RNG专项40/40；候选0..127结构128/128/0执行错误。生产另实际FAIL0/12（11diff/1unsafe64），未改src/Run/Combat/UI。账本、源码hash和逐seed双state见docs/reviews/TASK-12.4-map-room-candidate.md及docs/rules/evidence/w1-map-room-candidate.json；原始红绿/全差分在根.artifacts/m3-map-room-6e8714f。具体Map v3/rawRunSeed/四模块部署/7列92节点与1011地图控件的下一迁移gate已列清单；目标PC认证、生产接线、遭遇队列、平台实机均缺，所有整体AC不勾，不Done，无full/MCP/游戏。

2026-10-24迁移清单更正：基线已有生产abyss_randomxs128/abyss_sts_random，原语实际仅首行注释不同、wrapper保留基础方法并扩展事件API。下一片应复用两现有模块，仅新增map_topology/map_rooms；不得用旧候选覆盖生产模块，也不得误用事件shuffle（randomLong播种Java Random）作为地图raw同原语洗牌。更正和TASK15/47两遭遇只读审计均在本次文档补充提交，未改src。

2026-10-24 @codex-fresh-run-rng：已先红后绿修复Host重建固定seed=1。正常Start读取os.time/os.clock与模块序号混合的16位种子，同次样本供Run/Map；显式platform.seed/ui.seed复现及原重开递增保留，菜单预览不消费熵。6组真实Host/OnStart/原子性/范围回归、正常候选依赖清单4项及旧Host/序章/卡牌归属/BGM专项通过；完整check正在跑。两固定Exordium镜像及AbstractDungeon/MonsterInfo审计确认前三普通弱敌等权、普通最近两项/精英最近一项拒重、队列消费与流隔离；生产按floor均匀预抽仍不符，完整地图隔离候选未生产接线。来源hash与缺口见新增附件。免费DeepSeek Max已核零价和有效锁定配置，但90秒无事件/产物后中止，Codex接管，费用事件与节省额度未知。未构建副本/导入/实机，整体AC不勾。
<!-- SECTION:NOTES:END -->
