---
id: TASK-14.1
title: 补齐遗物药水剩余效果和正常获取
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-28 22:27'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
  - docs/backlog-details/TASK-14.1.md
  - docs/reviews/TASK-14.1-m3-inventory-audit.md
  - docs/reviews/M3-PACK-POTION-20261025.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
  - docs/M3-STATUS-20261028.md
  - docs/rules/LIZARD_TAIL_FATAL_INTEGRATION.md
  - docs/rules/MAX_HP_RELICS.md
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
基础库存、药水操作和大批道具效果已交付；旧库存恢复与钨合金棍回归阻塞已随主线整合解决。当前四职业各33瓶药水来源均有生产定义。继续逐件验收完整遗物药水效果、正常获取、触发顺序和跨域组合，并补同候选自然取得及平台证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已实现道具的固定来源、规则和已知差异已留档，未实现项单列。
- [x] #2 药水使用、选牌、丢弃、扩槽及永久库存事务已接入；105项药水专项和13份遗物/诅咒专项已通过。
- [x] #3 已实现用例覆盖背包命令、跨房间、战后、重复操作与失败回滚，39项输入/原子性回归已有记录。
- [x] #4 本地、候选读回和已有实机记录已分层保存；未导入或未实测的项目明确标记。
- [ ] #5 补齐完整原版道具池中尚缺的遗物/药水效果，并逐件核对数值、对象、持续时间、限制和触发顺序。
- [ ] #6 接通21瓶待获取药水及完整33项采样器的正常奖励/商店来源，保持原版概率，不靠去掉门禁或重抽放行。
- [ ] #7 全池逐件验证叠加、跨房间、战后和重复使用；尚未实现的组合不能沿用已有子集测试判通过。
- [ ] #8 同一候选逐件自然取得、使用和触发，保留对应平台日志与截图。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3复核：以当前13遗物和7药水清单重新审计来源、效果与正常获取入口；优先补真实库存入口的状态边界和奖励后使用验证。仅当固定来源及红例证明当前差异才改生产代码，不重做已合固定槽或开战顺序。更新专项账本，平台和正版PC证据继续独立保留。

原版PotionPopUp与AbstractPotion.canDiscard明确支持主动丢弃，当前缺入口。追加离线切片：先写Run.discardPotion真实槽位和无效输入原子性红例，再最小新增库存命令；UI接线由主线程随后处理。本树不碰UI。

2026-10-24 用户确认原神已开并授权任意必要验收：从develop31a8f37固定源构建新副本并独立读回；确认窗口/同级权限，clientScriptLog=true导入新存档，取本轮ready/日志/截图。正常资源下验证战后发瓶、跨节点用瓶、丢弃后换瓶与资源账本；明确自动命令驱动和物理UI输入的证据边界，不外推全件实玩或M3整体通过。

2026-10-25 用户批准完整原版内容池：分别固定Ironclad A0第一幕遗物和药水完整来源/顺序/消费目录、实际可达渠道与机制依赖，再按效果钩子分组补齐。13遗物/6可获药水只是历史基线，不能通过受限桶或缺项重抽保持自报概率；跨色等合法依赖必须明确，不静默删池。目录、实现、平台与自然实玩仍分层验收。

2026-10-25 资料包接入M3：复用生产Run/UI，补状态变化但尚未重绘时旧选敌确认、同ID换瓶和取消的全状态原子性回归；证红后才修复。代际冲突待用户明确，不改数值、卡池和版本。分开记录候选、官方导入和同候选试玩。

2026-10-26本轮M3并行：inventory独立工作树审计剩余效果后接完整33药水采样及奖励/商店正常渠道，不能只撤acquisitionPending、删池或重抽；父线程统一验证集成与Backlog写入。

2026-10-27 库存回归独立小片：保留 merchant seed21、真实购买 Iron Wave/石头和全部恢复/拒绝快照断言，只补测试账本漏记的聚财罐进房间12金币（含失效/Ectoplasm条件）。先在精确 c91 与仅加入 PR238 四项遗物定义的组合复现，再验证移除真实发金币的负例仍被原断言捕获。不改游戏效果、概率或商店池，不覆盖 PR238 本机未提交合并；Tungsten 来源与完整源池问题另留。

2026-10-27宝箱与渠道切片：原AbstractChest/ShopScreen/MonsterRoomElite真实调用链→共同遗物队列front/tail→create/open/take/leave与商店Courier/精英公开领取接线。69独立连续RNG向量与源边界/生成UI定向通过；缺效果保留sourceId并不可领取，不缩池重抽。当前PR238完整Quality收口中，整体AC不勾。

2026-10-28接续实际遗留成果：将16e9dfa7蜥蜴尾巴/黑星组合与原树三文件未提交药水计数修正接到最新b7dffdeb；保留双方原生轨迹测试、专用数据输入负例和全部旧断言。定向回归与完整当前SHA CI通过后合并，完整自然/平台AC仍不勾。

2026-10-28冲刺：按固定319009d5的MoltenEgg2.java补熔火之蛋，复用既有获得牌与Toxic Egg owner；覆盖攻击牌preview/obtain、只追溯当前战斗奖励、回滚、正常来源与48层边界。保持旧牌组/旧商店不追改；先红后绿并复验Toxic；完整道具池、自然和平台AC继续保留未完成。

2026-10-28 PR286收口：修复三处EOF空行与Darklings状态说明惰性依赖；逐项消解develop冲突并保留PR267和campaign入口，等待PR290合入后最终同步；补定向回归与当前HEAD完整Quality，全绿后squash，关闭被吸收PR285并保留可恢复历史再清理。来源锁、RNG顺序、回滚、测试预算及未验收AC保持。

2026-10-28 最大生命切片重迁：从实际已接受 develop432eebb1 独立开树，只移植原0391ea73已审查的Pear+10、Mango+14、SHOP Waffle+7后按新上限治疗和Strawberry活动owner修复。先用真实战斗损血重现旧Strawberry stale Run HP，再保留现有Run/Nodes/UI、Mark/MagicFlower、Fairy/Tail及源队列；仅补本片模块/定义/逐件目录/固定来源与测试。串行专项验证并记录当前base的守恒证据；不并入关闭未合PR300/301内容，不改历史金样或竞赛范围，不勾平台/自然验收，不推送/开PR/合并。

2026-10-28 发布前追加当前比赛身份定向冒烟：复用现有MaxHP夹具与真实CharacterSelect/Run入口，用当前冻结V4雷电和岩旅行者验证四件定义/钩子保留、战外取得后的实际数值及下一真实战斗继承、岩活动stale-owner成功；既有Original V4活动上下文安全拒绝另验完整owner/熵原子回滚，不伪称雷电活动取得已支持。只增独立小夹具/Node封装，原15份审查新增文件与生产代码不动，不扩框架，不跑宽套。

2026-10-28 当前真实底座更新：MaxHP独立线性分支rebase到已接受PR313的cec690c1，保留已批准UI/历史链且不并入待接受315/317。对真实Full CI暴露的PR238完整体守卫，只增认证c9seed70修复的精确外层逆变换，先恢复原字节再走原hash/12例/30秒证明。当前新主题/架构仅逆回MaxHP三图标+一个core分类，旧历史证据不改；当前专项、独立审查及精确SHA全量CI分层记录。

2026-10-28 接受PR319后，只将当前五个已审查MaxHP线性提交rebase到48cb48ce；完整保留其冻结药水registrar逆变换、分片与交付合同，若严格source层相交则仅做精确组合。旧金样/hash与原MaxHP生产/数据不改；纯合同、固定来源、静态及逐字节守恒后冻结本地审查，不推送且不写PR元数据。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 M3当前清单复核：13遗物/7药水定义、27份固定镜像blob及限制见docs/reviews/TASK-14.1-m3-inventory-audit.md与source-identity.json。未重复改固定槽/开战顺序/已修力量上限。补原版主动丢弃：Run命令4红→4绿，三槽选择确认接通活动局顶栏，奖励/商店满槽可丢旧瓶后原槽领取/购买，保留短按用药。UI9绿含run/phase/换瓶/同ID真实补回/resize/关闭重开/终局旧确认和用药手势，旧指针问题先红后换背包身份修绿。6种自然战后瓶用原始牌组实际击败Cultist后领取、跨map相位下一战生效6绿。既有专项及JS host/layout13全过，独立子代理复审UI9+布局2通过。没有平台构建/导入/实机，Boss3件终局后无自然后续触发、Poison无战士自然入口、正版来源认证和完整队列仍保留，四项全量AC不勾。

2026-10-24 固定31a8f37新候选官方导入1845，47模块/2298控件读回一致。正常114金币商店购火瓶50→64，三槽确认丢弃不扣费，再购同ID火瓶50→14；携至第3层使用，12血赤甲虫死亡、另敌15/15、能量3/3、库存1→0，空槽重按不变。新27号日志106打印含本轮ready、药水命中12/致死、ABYSS_SETTLEMENT_DEFEAT；真实离开后落盘。首战与开局有人协助，不归因全自动输入；20点基础伤害在12血目标截断，本轮不认证精确20。满槽替换/余下瓶/全件触发和全UI门禁仍缺，AC不勾。官方图严格字段审计失败保留（布局/省略默认值），未放宽审计。证据见docs/M3-LIVE-INVENTORY-20261024.md及docs/evidence/m3-live-31a8f37/receipt.json。

2026-10-25 五瓶Swift/Weak/Fear/Ancient/LiquidBronze真实Run库存效果已实现，12组Lua/3项JS及相关门禁通过。五瓶暂acquisitionPending并列明清单排除，两个旧selector保原6瓶获取轨迹；不能把此隔离误当原版概率。完整33统一接入时必须移除此排除，不跳过unsupported。SacredBark/onUsePotion等依赖保留。见docs/reviews/TASK-14.1-potion-basic-five.md。

用户明确把资料包接入作为M3冲刺一环。最新develop3ed8bf4已批准完整内容池，旧30张仅为接线盘点；资料包记录STS2方向，而当前SCOPE仍STS1，已向用户请求锁定代际和构建。免费委派限额未有恢复依据，本片由Codex直接执行。

资料包药水目标事务验证切片：新增tests/lua/potion_target_rejection.lua，生产host监听器7/7通过（无render旧目标死亡/替换/换序/同ID换瓶/turn/phase与取消重选）。现有targeting5、commit4、input ownership7、discard UI10通过；launch-content13项及verify:backlog通过。独立子代理复跑7/7且无确认P1/P2。未复现需改生产代码的缺陷，保留现有实现；平台/自然获取不计通过。候选构建另记。源码规则代际待用户明确，不改数值或范围。

本片候选离线构建与独立读回通过：运行时固定源3ed8bf4，61/61模块逐字节匹配，UI2824/max60，结算22节点，0error/33warning原样保留。候选SHA256 f2808674cca47de5aade4871fc0da82fdd9d25c801e6cc7d31ec4cd0400bdf68，位置及图审计有限范围见docs/reviews/M3-PACK-POTION-20261025.md。官方导入、同候选真实试玩、自然获取未验证；父任务AC不勾，M3未验收。

2026-10-25 本轮M3生产切片在独立树完成串行集成：四事件/永久事务/十种诅咒清除，战士药水效果与五槽原生UI，33common+3special遗物触发。详见docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md。事件69项、药水20份105项、遗物13份及inventory11项本地通过；全部72非基础合法胜利领奖分片保留通过，旧160卡面断言经真实RED修为178版本GREEN。完整含BGM候选cf77beea4ef77dbda269b344a4c972ac6aac7dff0621fa5acc807a0f364ab728，71模块与bd93be7逐字节一致，静态0错误36警告；归档.artifacts/m3-events-inventory-20261025，最终提交还须再次audit及当前PR完整CI。官方导入、同候选真实试玩、BGM听测、UI总门禁未验证。完整25自然事件池、剩余遗物效果、33药水自然渠道及6种效果、Spirit Poop生产总分仍缺，父任务/M3不标完成。

2026-10-25 最终候选更新：领奖事务保留独立RewardItem owner且完整异常回滚，旧奖励UI断言保持并通过；permanent_transactions13项、178卡面、25项来源契约及十组旧流程回归完成。生产源ded810f0f7b403b564bee64df06117587957500f重建含BGM候选4d9f3d0a0e21e9ea4f7e96eca7adf8ae1eaede4c117ec02aa6022f5e4d8c7f8c，71模块逐字节独立读回，静态0错误36警告。稳定证据.artifacts/m3-events-inventory-20261025，最终PR头完整CI/合并仍待实际结果。按用户最新要求，任何鼠标键盘/抢焦点/实机输入先约本轮窗口；本轮未获桌面窗口，官方导入、同候选真实试玩、BGM听测与UI总门禁未验证。全池/自然渠道/总分及平台缺口继续保留，父任务与M3不标Done。

2026-10-25 RC2：保留develop已合入PR207布局，源3e9873220cf5aa055799992c906ade0daf167f63重建含BGM候选8c8f04612f6c1858b5146fb2355eda020e3fcf342f897d1e187d88f0a2097ce0，71模块逐字节审计，静态0错误/36警告。旧e1全CI首轮药水预算超时、仅一次重跑后Node全过但Lua旧oracle失败，日志均保留；七份旧oracle按当前契约校准，失败身份/RNG/完整75/UID及下战断言和原时限不降，17个Lua入口+12个Node本地通过。最终头完整CI及合并以本PR实际记录为准，父任务/M3保持In Progress。没有桌面输入窗口，不操作鼠标键盘或抢焦点，官方导入/同候选试玩未验证。

2026-10-25 CI环境校准：1647330完整Node1268pass/119既有skip/0fail、数据通过；本机Node22三份Lua超时，GitHub45分钟取消，仅完成到potion_status_rules，未合并。官方校验便携Node24在同机原预算下living_wall18267ms/card_help_release20229ms/battle_ui48674ms全部通过。Quality仅固定Node24.18.0，源码/候选/系统MCP Node及全部断言、45分钟与单测预算不变。最终头完整CI仍待真实结果，平台未验证且无桌面窗口，父任务保持In Progress。

2026-10-26状态整理：PR197/200/206已整合库存与事件道具推进，旧1647330的Node环境/CI等待不能作为当前阻塞。按当前完整目录逐件核效果、获取和随机消费，保留尚未证明的组合与平台记录。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26测试状态澄清：现有自动化覆盖的是已实现内容和明确边界；生产abyss_potion_rewards仍按acquisitionPending排除新瓶，并从受限池选择，故剩余不仅是实机缺测。依据M3-EVENTS-INVENTORY-INTEGRATION及当前生产代码；本轮无新增测试或玩法修改。

2026-10-26逐项AC校准：将混合的已实现/已有自动回归与完整池/平台待验拆成独立条款；依据既有合并及验证记录勾选，不新增通过结论。原验收快照保留docs/evidence/backlog-ac-before-20261026.json，全部原范围要求由拆分后条款继续承接。

父线程Node24独立组合复验全部33瓶两渠道13分片0失败；无色依赖已合成后真实78双版本执行通过。独立审查发现匕首增长逃跑丢失，已修到所有成功命令/药水事务边界并实跑Smoke/Chaos/选牌/失败回滚。没有新GIL/导入/实机。

2026-10-27独立复审确认鲜血药水与魔法花重复倍率，已在集成树按固定源改为原量入队、实际治疗一次修正；21旧项及新增Toy排队项合计22通过。另核实黏液/转轮事件致死绕过瓶中精灵，m3-event-fairy独立树修战外自动复活与回滚，不冒充完整遗物自然获取或平台通过。

2026-10-27事件Fairy8组已在集成树独立复验，含Bark/Bloom、物理槽、陈旧战斗隔离、后续缺遗物导致的HP/瓶/RNG/owner完整回滚；鲜血治疗22组与实际缺牌/升级奖励2组通过。当前PR234完整门禁仍待新SHA结果，不将专项当全池组合或实机。

2026-10-27最新合并回归核对：PR238远端仍a4dac772、草稿且冲突，未合并；fc51f198同步尚未提交。最后定向结果inventory_restore失败13.626秒（750 ~= 738），tungsten_rod_channels失败1.045秒（smiling_mask ~= tungsten_rod）；toxic_egg_profiles通过1.996秒、relic_top_bridge通过2.890秒。先按真实恢复/自然获取路径诊断，不删断言、缩池或升预算。证据根build/pr238-resume-20261027-091929/fc51-final-focused.json及同目录fc51-final-*.log。不得沿用同步前成功认证本次合并，全池与平台AC继续未勾。

2026-10-27优先级重排：High：当前PR238库存恢复与道具正常来源回归失败，直接阻塞整合收口。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27 库存测试账本定位：精确 c91 加 PR238 四项遗物定义后，f9_l2 宝箱正常获得聚财罐，f10_l1 精英房入口实际金币 738→750；旧 expectedGold 未计该进房间奖励。只补独立原版 MawBank 12 金币/失效-2/Ectoplasm 预期，完整保留 seed21、购买 Iron Wave/石头及每个原断言和8份非法快照。原 c91 与四遗物组合均5组通过；移除真实 Maw 发金币的负例被原第4组断言拦下（738≠750），父线程再次跑真实夹具通过。原版依据 aeubanks/sts@319009d5 的 MawBank.java、AbstractPlayer loseGold/gainGold；不是认证PC二进制。未重放 PR238 本机 STOP 快照，不能据此声称其完整合并已修复；Tungsten seed91 受遗物池增长影响及普通宝箱/商店尚非完整原版队列的问题仍单列。

2026-10-27当前develop已合入PR244的MawBank独立金币预期与PR245实际损血Puzzle回调；本轮共享source队列/宝箱迁移继续保留这两项，原31组fatal回归及同SHA组合检查继续执行。

主整合复核补正四职业遗物来源：Run按真实STS职业使用shared+对应色完整队列，5次relicRng randomLong洗牌；商店尾取，宝箱/精英首取。40组Java全队列/随机向量、starter资格及Shop/Treasure/Elite正式API定向通过，旧红池/向量不改。缺定义保持原sourceId并unavailable，未缩池重抽。ToxicEgg购买后刷新未售货架技能预览、不改永久deck或RNG，reward owner追加/删除长度拒绝也已通过。当前PR238@4c24aa0完整Quality在跑，后续必要回归迁移和独立P1修复仍需整合；原全效果与自然平台AC不勾。

2026-10-27 独立源码增量候选新增Snake Skull/DataDisk/Damaru三件真实效果与正式取得渠道。Poison奖励在ApplyPower构造时捕获而非执行时追认；DataDisk按持有顺序入TOP开战Focus；Damaru按原版null来源入BOTTOM回合Mantra，复用真实Divinity/Devotion。相关来源、生命周期/交易回滚、四职业渠道和独立审查通过；集成补齐三件在既有主题的显式占位图标，不冒充专用美术/实机验收。87项组合Node与177组既有Lua回归通过，源池和RNG不改。本批仅补三件，不宣称整个遗物池或所有死亡遗物回调完成；当前新PR完整Quality待证。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28四幕PR262与用户试玩并行的独立遗物切片：BlackStar已按全22件Boss池固定来源真实抽到、经Boss宝箱领取，再真实精英双遗物/独立绿钥匙及晚失败回滚验证；launch gate读取实际传入数据，28项回归通过，尚未合并或进入当前GIL。LizardTail零依赖回调、生产rare定义与获得/致命协调在独立23c50ef6 checkpoint接通，真实Run8组、组件/数据5项、原Fairy战斗6组与事件8组通过，架构209模块1221边、固定Luacheck84历史诊断零新增。源RedSkull血量回调先于复活并走既有TOP动作，Mark外门、最左Fairy优先、Tail永久-2与晚失败回滚保留。独立动作顺序、暂停选择/跨幕存续、旧事件夹具迁移、获得渠道与只读详情仍在复核，详见docs/rules/LIZARD_TAIL_FATAL_INTEGRATION.md；不改AC5-8/状态，不将受控获得与离线测试冒充自然取得、完整CI、候选或实机通过。免费路径受限窗口未知，未探测或回退收费模型，native Codex独立叶并行，费用节省未知。

2026-10-28最新b7dffdeb组合已接入16e9dfa7的蜥蜴尾巴组件/共享复活/永久counter、战斗详情及黑星正式来源；原树三文件未提交奖励计数修正已复制到独立集成树，原树保留。两处冲突保留PR261原生样卡身份投影和遗物主题精确逆投影全部断言。209模块/1223边架构通过，Luacheck1.2.0固定84历史诊断零新增、370项职责度量通过，构建与数据校验通过。专项与当前SHA完整CI仍在验，不勾完整道具/自然/平台AC。

2026-10-28接续验证：42项专用/内容/原生合同第一轮41过、清单聚合单进程1项超时。保留失败，改为inventory/black_star/lizard_tail_run/lizard_tail_persistence四个完整独立验证进程，每份原30秒及实际传入data保持；原22项完整清单回归通过。4个原语义变异全部killed_by_assertion。最终集成和状态统一收口PR266，不将受控证明当全池或实机完成。

PR266精确8746d5c2完整CI的rules8检出两处相邻遗漏：来源账本仍把Black Star/Tail标缺失，旧绿钥匙UI夹具要求满四项后仍掉瓶。现账本按实际54定义补两映射（source注册/顺序不变）；生产夹具明确断言无瓶，另通过真实三项采样器构造独立容量offer，完整保留六行布局、点击/手柄、领取、重复与旧owner断言。移除重复占位BlackStar定义，改验真实生产定义。11项相邻回归全过；本轮原失败日志保留build/m3-status/rules-8.log，最新SHA完整CI另验，AC保持未变。

2026-10-28熔火之蛋切片（PR286）：按固定319009d5的MoltenEgg2及7成员独立源锁实现真实攻击牌获得/预览/装备奖励追溯、48/49层正常资格、Library/Sensory和Nest组合。23份新旧Egg/事件Lua原预算通过，19项来源/历史主题契约通过；213模块/1235边架构、固定84历史静态诊断零新增、4项变异和2项原生契约通过。独立复核源码与队列/RNG/UID/回滚无阻断。同步267后Nest真实获得、Fairy/Tail、下战同UID和晚失败回滚通过。最新组合完整CI仍待，不把定义或受控获得当逐件自然/平台验收；AC5至8及状态保持未完成。Node22本地全量测试有原30秒超时且未完成，失败记录保留，不报告全量绿。

PR286主线程收口：保留远端5556fef1的Searing Blow复制语义，原固定zip四个相关Java成员hash均独立核对。23份Molten/Toxic原预算夹具全过；角色入口组合28项、正式入口账本/诊断/旧UI合同31项全过；工程四变异均被原断言检出。一次本地历史回放与工程同时运行触及原30秒，失败保留，单独串行复验7/7绿（两旧回放26.670/22.230秒）。本地已组合PR290至300a96a8，正式入口与其逐字一致；当前等待其当前头Quality合入后最终同步并验证最终SHA，不认证平台/自然通关，不勾AC。

紧急收口：用户本轮明确授权先合并、CI合后继续，替代原CI全绿前置。最终同步保留PR290及主线PR295/296界面，不创建版本。已知合后CI工作：Silent同实例双四房夹具原30秒超时，以及新角色/共享卡框/非战斗界面的严格历史证明组合；不删断言、不放宽预算，不认证实机。

最终UI紧急合流保留#286完整规则交付及最新范围，双方原始任务快照见docs/reviews/ui-merge-task-history-20261028.json.gz。未把源码合并或紧急CI授权冒充道具平台验收。

2026-10-28 最大生命独立重迁：从实际已接受develop432eebb1只迁原0391ea73的Pear/Mango/Waffle和Strawberry活动owner修复，未纳入关闭未合PR300/301源层。真实战斗stale-owner断言先RED后GREEN；当前94项Node、5个相邻Lua入口、9固定源成员/160生命/28完整渠道金样通过；架构231模块/1294边，固定Luacheck无新增诊断/60历史/625度量。851份已接受Lua/冻结夹具/历史审查/源池文件逐字节保留，15原审查新增文件与hook精确保留。只追加3项定义至59项，不表示完整遗物/Boss覆盖；历史完整身份RED后以两文件精确MaxHP测试逆映射恢复432e原始字节，旧金样/hash/trace与#310逆映射保留。四职业夹具只证通用遗物同源兼容，不扩大岩旅行者+既有冻结V4雷电及前两幕比赛范围。独立证据m3-max-hp-accepted-432e-evidence；完整Quality/远端交付/候选/官方导入/自然取得/平台实机未验，AC和In Progress/Furinya保持。

2026-10-28 追加比赛实际身份小冒烟：真实CharacterSelect/Run的岩旅行者与当前冻结V4雷电分别通过四件战外取得→真实Cultist战斗hp/maxHp继承；实际RD身份/冻结初始牌顺序/新战healUsed=0核对。岩活动stale-owner四件成功，雷电活动四件仍按原模块transaction_failed原子拒绝，完整图/熵/治疗账本保留；不宣称全角色活动支持。两身份原30秒预算分别2.88s/4.82s，2项通过；首轮夹具误期待内部错误文本的失败单独保留。常规商店/宝箱phase=node、胜利遗物领取phase=reward源码路径复核未见活动取得入口；不是自然游玩证据。只增独立小夹具/测试，原15审查新增与生产代码不动。原全量/平台/自然AC继续未勾。

2026-10-28 真实c9 Quality40756971580在Windows rules1与POSIX1同一PR238守卫报1!=2，根因旧完整体inverse缺c9授权seed70差量，非玩法/RNG或超时。精确RED复现，旧PR238来源/hash/全case与预算保留；新精确source inverse及漂移/往返证明后21项纯合同GREEN。接受底座已更新cec690c1；原MaxHP模块/hook/15文件字节不变，当前接受UI/静态基线/历史金样保留。实际Geo/雷电及活动owner3项封装、inventory_budget_6两例在原预算通过；固定源/构建/数据/语法/架构232-1300/固定静态0新增60历史625度量通过。未重跑旧94作完整CI替代；当前独立review/新精确head全量Quality仍待。本任务In Progress/Furinya及完整AC不改，V4活动取得仍原子拒绝，自然/平台/实机不冒称通过。

2026-10-28 接受PR319实际48cb48ce后，本片五个提交线性rebase无冲突，未新增helper组合改动。接受319全部20路径、冻结registrar与原预算分片/交付合同逐字节保留；28项纯来源/漂移/分片合同、9固定源/160生命/28渠道、构建/数据/语法/架构232-1300/固定静态0新增60历史625度量通过。932份接受Lua/冻结夹具/审查/目录/静态基线、原15新增+hook、seed70 c9运行夹具精确保留。MaxHP生产/数据无新增改动，无重型Lua重复回放；当前精确head独立review与新Full待验，不推送且不写被拒绝的PR元数据。原In Progress/Furinya/全部AC及V4活动原子拒绝限制不变。
<!-- SECTION:NOTES:END -->
