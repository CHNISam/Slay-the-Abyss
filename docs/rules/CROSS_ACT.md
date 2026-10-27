# M3四职业与完整章节实现账本

## 2026-10-28 当前实现与证据边界

第三幕常规战斗现已接齐3弱、8强、3精英与3 Boss来源编组，17类怪物在机器账本逐项关联既有本地回归。七个普通事件映射均已接入，MindBloom与Mysterious Sphere的生产事件战斗桥接、既有控件UI及Mark禁疗也已离线接线。集成工作树的`tests/lua/event_combat_bridge.lua`记录12.35秒GREEN；最终组合提交回归、完整普通/神龛/一次性事件自然路线及平台验收仍待完成。

独立[EndingHistory](ENDING_HISTORY.md)已接Host：地图生成前读资格，只有真实标准且非固定种子、非每日/试炼的原前三职业完整三幕胜利才记入。默认旅行者可按原铁甲战士规则包计入；原创V4角色、失败、弃局和旧第一幕胜利不计。会话记录与可注入持久provider已有本地owner/Host证据；未接真实平台持久provider，不能声称账号历史已保存或终幕资格已实机解锁。

红钥匙营地回想、蓝钥匙宝箱取舍已有局部生产命令，完整三钥匙自然链仍缺绿钥匙。第四幕战斗、同候选跨幕自然通关、持久provider和平台/实机证据保持未通过。`m3-campaign.json`继续为`INCOMPLETE`，不将局部接线升为整幕或M3完成。

下列2026-10-26接线及PR213段落保留为历史基线；旧“第三幕战斗未实现”“历史资格未接”仅描述当时版本。当前缺口以本节与机器账本为准。

2026-10-26用户明确：第二、第三和隐藏第四幕均纳入M3，与四职业完整卡池、第一幕及首发内容共同验收。旧第二/三幕可选和投稿后窗口已经撤销。DRAFT-2/6经Backlog CLI原生提升为TASK-61/62，TASK-63负责跨幕核心，TASK-64负责钥匙和终幕；TASK-47继续负责整体验收。

本轮从develop `45ba918e5719614f36b6a92aeb511e76a1311608`（PR206已合入）开始。用户明确允许本轮独立工作树的离线开发和Backlog更新暂免远端认领；全局paused、其他会话、旧工作树和历史证据保持。没有本轮提交/推送/合并、官方导入或桌面操作。

## 2026-10-26后续离线接线

本轮在`feat/m3-sprint-integration`补齐Host显式开发campaign选项、宝箱后换幕和章节内地图坐标。第二幕5弱、8强、3精英、3Boss共19个来源编组已有生产构造/AI/特殊能力及34组本地回归；固定源40文件身份及具体缺口见[第二幕敌人](ACT2_ENEMIES.md)。Stasis真实原UID、源ID排序及归还、召唤、Flight/Hex/Confusion、偷金与阶段能力分别留证，不能据此宣称自然通关或正版二进制对照通过。

第二幕事件专属Bear/Pointy/Romeo、13普通事件和三四幕战斗仍缺；三钥匙、历史资格与真实结局仍按原任务验收。默认发布入口未开放完整campaign。机器账本保留`INCOMPLETE`及平台`NOT_RUN`，本轮没有新候选或实机输入。

## PR213历史基线

- 共享核心已实现：章节/全局楼层/局部地图行；前三幕独立地图种子；终幕52–55固定链；第二/三幕原始权重、队列拒重和Boss历史顺序；沿用上一幕monsterRng；cardRng真实布尔抽样推进；保留卡UID、升级、金币、遗物及计数、药水；A0治疗并尊重禁止治疗；普通/神龛池重置、一次性事件及Tiny Chest计数保留；第三幕普通结局/三钥匙门的边界事务。
- `Run.new(data,seed,{experimental=true,campaign=true})`是显式开发入口。普通生产入口仍为原第一幕，不能将新地图或队列计为完整章节可玩。第二至第四幕战斗入口目前明确返回`act_content_unavailable`，不会偷用第一幕敌人、降池或重抽。全部内容接齐及验收前不开放新章节的正式菜单。
- 本轮12组跨幕Lua边界用例已通过，另有14条连续章节/完整解锁Boss向量、11条卡牌随机计数向量通过。向量是独立整数/Java洗牌解释模型，不是运行原作PC。第一幕原独立队列9种种子、完整每次抽样和补队列向量通过；第一幕地图10组回归通过。
- 观者现有实验入口会因生产Akabeko已注册的Vigor状态报重复，本轮复现并修复：仅复用同身份/类型/叠层/持续规则的共享状态，保留已有显示名；冲突仍拒绝。
- 正式Host/章节地图UI转场尚未接入。本轮未实现第二/三/四幕40类怪物AI及各幕事件内部内容；320项怪物检查均不能算通过。三钥匙的真实获取、历史资格持久存储、全部职业完整卡池及同候选自然通关仍缺。M3保持未完成，不勾整体验收。

机器账本：`data/release/m3-campaign.json`；输入规格索引：`data/catalogs/sts1-acts234.json`。原`launch-content.json`继续盘点第一幕当前生产接线，`requiredScope`明确指向新增M3全量范围，不能以旧接线数量缩减新目标。

## 固定来源与语义边界

行为来源为第三方反编译镜像`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方开放源码或正版二进制认证。独立Lua实现，不将Java原文或游戏素材复制进产品。资料包只是输入要求，不自动授予执行权或覆盖本轮用户指令。

| 来源方法 | 本轮对应实现 | 关键行为 |
| --- | --- | --- |
| `TheCity/TheBeyond`章节初始化 | `abyss_acts`、`abyss_map_topology`、`abyss_map_rooms`、`abyss_map` | 全局18–34/35–51，15行局部随机图，种子分别raw+200/raw+600；Java有符号64位溢出保持 |
| `TheEnding.generateSpecialMap` | `abyss_map` | 52营地→53商店→54双精英→55心脏；结算节点不是可玩56层；固定图不消费随机拓扑抽样 |
| `AbstractDungeon.dungeonTransitionSetup`、`Random.setCounter` | `Run.advanceAct`、`Nodes.advanceAct` | 仅开区间(0,250)/(250,500)/(500,750)真实消耗randomBoolean；整点和0不推进；不直接赋counter或重置seed |
| `TheCity/TheBeyond.generateMonsters`、`AbstractDungeon.populate*` | `abyss_encounter_queue` | 先2弱，再首强与12强、10精英；首强使用专属排除、后续禁前两场，精英禁上一场 |
| `TheCity/TheBeyond.initializeBoss` | `EncounterQueue.initializeBoss` | 未见Boss按各幕固定历史优先级；全见时共享monsterRng的randomLong驱动Java洗牌；返回私有下一状态 |
| `initializeEventList/initializeShrineList` | `abyss_event_pool` | 第二幕13、第三幕7普通池；各幕神龛保留源码顺序；全局一次性消耗不重建；不代表事件体已实现 |
| `TreasureRoomBoss`、第三幕终局 | `abyss_nodes` | 17/34才是Boss宝箱；51无Boss宝箱；只有历史资格和本局三钥匙全有才产生终幕转场 |

读取过的固定来源内容摘要见`tests/fixtures/cross-act-source-lock.json`，上游原文只留在工作区只读审计目录，不进入仓库。独立向量生成器`tools/oracles/sts1_chapter_queues.py`读取固定源事实，不导入产品Lua；生成器及输入摘要都由定向测试核验。

## 事务与验证

`Nodes.claimBossTreasure`先通过原公开领奖事务完成选择；显式campaign进入`act_transition`，随后`Nodes.advanceAct`在一个事务中准备Run和新地图。卡牌、遗物、事件、队列或地图准备抛错均不提交资源；新图失败保留原map根、路径和Run。重复转场、错章节/seed/签名、缺少合法终点均拒绝。每幕的全局节点ID不同，旧章节手势不能变成新节点。

定向命令：

```sh
npm run build:data
node --test --test-concurrency=1 tests/cross-act.test.mjs tests/encounter-queue.test.mjs
node scripts/test-lua.mjs tests/lua/map.lua
npm run check:architecture
npm run verify:backlog
```

边界夹具构造已结束的房间，仅证明生产命令/事务行为，不作为正常数值通关或真实获取证据。完整check、平台/实机、逐怪物源核对、AI/Power/事件及完整职业内容仍须分别完成。10/28 M3、10/29 RC和10/30投稿日期存在新增范围带来的风险，不能靠删内容、改概率、低HP或降低验收制造准时完成。

## 本轮完整检查与恢复

结构化证据见[本轮记录](../evidence/m3-cross-act-20261026.json)。原始完整检查与恢复日志保留在本执行树build/m3-*，不删失败记录。

- 初次npm run check：1470项JS全部执行，1469通过；唯一失败为环境缺少pwsh（已单独确认spawnSync ENOENT），没有跳过或放宽CI下载回归。
- 后续串行补完398份Lua、数据、主题、工程和Python呈现。398份Lua全部执行，11文件暴露两个既有整合根因：九份职业呈现/启动文件不识别新增诅咒，另两份Louse全状态期望未登记Run新增加的combatGeneration。其他步骤通过，2388个输入前后不变。
- 诅咒说明仅接受既有Curses.isImplemented的严格元数据；保留批准的名称和已有文字，补四职业实际渲染及错误生命周期拒绝用例。Louse诊断逐字段只差combatGeneration；独立期望断言每个fresh Run首次战斗必须为1，完整状态比较不删字段、不弱化。全部11份失败文件及共享Vigor、跨幕核心共13份定向文件复跑通过。
- 第三幕首强例外已用固定源独立整数解释器的原始seed10复现。终幕固定普通/精英/Boss队列各3槽由TheEnding方法事实独立抽取；不抽样或重置monsterRng。最终6项Node独立向量/第一幕回归与架构、固定Luacheck、diff和Backlog检查通过。
- 没有把上述分批恢复写成“最终一次完整check全绿”，没有同SHA远端CI、官方候选、导入或平台试玩；M3整体和TASK-63均不转Done。

## Falling 独立切片

第三幕 Falling 的公开节点事务、原生选择界面和完整来源池抽取已接入。固定源规则、独立 RNG 向量及专用命令见 [ACT3_FALLING.md](ACT3_FALLING.md)。这是一项本地事件证据；其余第三幕事件、完整 campaign 与平台验收仍按原任务保留缺口。

## Moai Head 独立切片

Moai Head 已接直接减生命上限后治疗、canonical Golden Idol 献祭/333金、原生 UI 和公开事务回滚。固定源与专用证据见 [ACT3_MOAI.md](ACT3_MOAI.md)。后续 [Golden Idol 独立切片](GOLDEN_IDOL.md) 已接第一幕实际取得与战斗 GOLD 加成，并验证同一持有者的真实战斗→献祭链；完整跨幕路线、整幕和平台验收仍未完成。

## Winding Halls 独立切片

Winding Halls的三选择、真实获得/诅咒阻止、NORMAL null-owner伤害与致死后两Madness事务、原生UI及完整池选择已接。详情与四个未实现遗物hook的明确拒绝边界见 [ACT3_WINDING.md](ACT3_WINDING.md)；两条基线已有Effects静态告警尚待父组合治理，本片不报完整工程/整幕/平台通过。

## Sensory Stone 独立切片

Sensory Stone 已接完整35普通无色的1/2/3组冻结奖励、组内去重/持久cardRng、可重开Skip、Proceed后LEAVE、HP_LOSS先奖后伤、真实永久UID与原生UI。规则与依赖见 [ACT3_SENSORY_STONE.md](ACT3_SENSORY_STONE.md)。这是当前RC之后的独立内容，复用真实Rod共享接口；未接奖励遗物/Lizard明确拒绝。默认全事件、第三幕全部内容、自然连续通关与平台仍未完成。
