# Pear、Mango、Lee's Waffle：原版取得时生命结算

## 固定来源与实际范围

`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，社区反编译镜像（声明 V2.3.4），**不是经正版 PC 二进制认证的源码**。这批只补 Pear、Mango、Lee's Waffle 三件，并把 Strawberry 的同类取得生命效果移入同一源方法 owner。没有改共享/职业源池、洗牌顺序、概率、canSpawn 或抽取重试。

逐文件字节数、SHA256、Git blob 和独立预期在 `tests/fixtures/max-hp-relics-source.json`；`tools/oracles/sts1_max_hp_relics.py --source-root <已缓存固定源码目录> --check` 只验证本地成员，不下载、编译或执行原作。

| 源身份 / 本地身份 | 原稀有度 | 原 onEquip 顺序 |
|---|---|---|
| Strawberry / `strawberry` | COMMON | `increaseMaxHp(7, true)` |
| Pear / `pear` | UNCOMMON | `increaseMaxHp(10, true)` |
| Mango / `mango` | RARE | `increaseMaxHp(14, true)` |
| Lee's Waffle / `lees_waffle` | SHOP | `increaseMaxHp(7, false)`，再 `heal(player.maxHealth)` |

三件新增遗物都没有 canSpawn override，继承普通允许规则。Waffle 保留 SHOP 身份，只从现有商店 SHOP 队列取得；不放进普通宝箱/精英队列。它不是只加 7，也不是在旧生命上限下先回复。

## 生命与事务 owner

`AbstractCreature.increaseMaxHp` 先增加最大生命，再调用普通 `heal(amount,true)`；Waffle 虽传 `false`，这个源方法仍对增加部分调用普通治疗。普通治疗按持有顺序调用 `onPlayerHeal`，再执行能力治疗回调和上限夹取；非 Endless A0 中 Magic Flower 只在 COMBAT 乘 1.5 并做源 binary32 rounding，Mark of the Bloom 把治疗变成 0，均不撤销已经增加的最大生命。死亡角色不因治疗复活；即使当前HP仍大于0，源 `isDying` 标记也在治疗修正之前直接阻止治疗。

生产 `abyss_max_hp_relics.equip` 在现有 `Run.obtainRelic` 的私有事务内执行，复用 `abyss_potion_health.modifyHealing` 而不自行改倍率。活动战斗使用真实 `combat.player` 并同步永久 `hp/maxHp`，治疗越过阈值时复用 Red Skull 的既有回调；非活动战斗取得只修改永久生命，不改写历史胜利/待重开战斗。一次取得后不会在下战再次加上限。

公开基线 Strawberry 的旧取得路径直接更新永久 `run.maxHp/hp`，不能处理已有实际损血但尚未同步的活动战斗玩家。现在复用已复审同源模块，活动取得读真正的 `combat.player`，再同步永久生命；取得时治疗仍服从 Bloom/Magic Flower 既有修正。公开 Mark of the Bloom 定义与事件来源保持原样；Magic Flower 只在受控夹具中作为已有治疗修正器依赖，不新增定义或自然来源，也不宣称所有治疗路径已统一。

现有运行时 `2147483647` 容量和合法整数健康状态保持不变：溢出或非法状态整笔拒绝，无部分加血、加上限或发布持有权。该安全拒绝不宣称复现原 Java 非正常超大数值的整数溢出。自创 Original V4 活动战斗不冒充 STS A0 健康语义，原子拒绝；Endless/FullBelly 不在本片范围。

## 可重复离线证据

- `tests/lua/max_hp_relics_health.lua`：160 个独立数值/持有顺序预期、两步 Waffle 请求、公开取得与重复拒绝、跨真战斗、上限/非法输入、后置失败/熵/owner 回滚、历史战斗隔离、Red Skull、Waffle两张不可变帧与死亡不复活。
- `tests/lua/max_hp_current_owners.lua`：公开底座逐件通过实际战斗损血形成 stale Run HP，保留完整对象图与外部熵的后置抛错回滚/成功重试和未消费 Tail counter；保持当前 Molten Egg owner。
- `tests/lua/max_hp_relics_{ironclad,silent,defect,watcher}.lua`：各 7 项原完整队列输入，共 28 项真实 Run/Shop/Chest/elite 奖励 API；比较全部队列和 RNG owner，不通过移动目标到队首/队尾取得。
- 独立 Python 只复用既有固定源 RNG/Java shuffle 的独立算术模型。所有五队列、五个原始 shuffle long、完整价格与宝箱/精英随机向量都冻结在 JSON/Lua 金样，不从生产效果反推预期。
- 移除目标定义的控制仍选择同一 sourceId、同价、同队列与 RNG，标 unavailable；不回抽或去掉门禁。公开历史 offer/token 与失败时所有 owner 保持不变。
- 目录 `projectId` 只从未实现改为 `existing-local-effect-not-full-pool-parity`：新增 3 项，当前 develop432eebb1 基线的 Ironclad 队列缺效果 86→83；完整自然获取/PC/平台/实机证据仍 pending。

专项通过情况与精确源码 freeze 由独立交付证据记录，不以本文代替实际测试日志。商店受控金币、强制地图节点与终局伤害夹具不是自然牌组胜利或完整四职业前两幕通关；没有新候选、官方导入、实机截图、专用美术或整套 M3 验收结论。图标沿用批准主题现有生命占位 `102005`，未冒充原版专用图。


## 当前主线集成边界

本片从已接受的 develop `432eebb1d51a7ad37cfbc19f0e846bc00f1f4ba7` 独立开树，仅迁入原审查提交 `0391ea7301894f39b05a64e1e9bfa4d436925ed4` 的最大生命差量，56项定义逐字段保留，仅追加三项后为59项；注册映射52→55、原队列缺效果86→83、第一幕范围缺效果91→88。保留 Molten Egg、Odd Mushroom、Black Star、Lizard Tail 和全部当前架构/主题/独立预期，不迁入其余未公开遗物，也不覆盖 HP-loss→Fairy→Tail owner、counter发布器、Run/history/Prayer Wheel 或奖励计数语义。`src/lua/abyss_run.lua`、`abyss_nodes.lua` 和全部UI Lua不改。

Old Coin 与 Eternal Feather 不是本片依赖，不迁入相关room/energy共享owner。沿用已复审的断言抛错原子拒绝，不扩展Run。

## 原始切片历史验证（77c2基线，不代替当前组合）

原始0391ea73组合在 Node v24.22.1 下串行验证：来源/最大生命/四职业渠道/目录/实际活动owner 19项，以及数据构建、主题、launch、Black Star、Tail取得/顺序/跨房、Molten来源与Mushrooms 115项，合计134项Node测试通过，零失败/跳过。另有Molten获得、装备奖励回滚、商店预览，以及Mark36组治疗和事件Fairy8组的5个既有Lua入口通过，全部保留原预算与断言。当前77c2d5e6的旧Strawberry hook用同一活动owner断言先RED，迁入模块后GREEN。固定9成员来源/160数值/28完整源队列金样复验通过。

架构221模块/1260边通过；固定Luacheck1.2.0无新增诊断、73条历史警告、432项职责度量通过，未修改静态基线。56项旧定义逐字段、13份共享owner/源队列/静态基线文件逐字节保留，15份已复审新增代码/测试/金样逐字节迁入；主题、架构和launch对象只增本片必要项。原始日志与守恒清单在原始独立证据目录 `m3-max-hp-current-77c2-evidence`，精确提交另记交付收据。

上述仅为本地专项，不是完整Quality、关键变异集或独立审查。本轮没有候选、官方导入、平台、自然取得或实机通过记录，不作M3验收声明。远端PR、当前SHA CI与合并由主线程统一收口。


## 已接受主线重迁（432e基线）

只读取得已接受主线后重新迁入最大生命小片，不使用关闭未合入的PR300/301源层或混合提交。生产Lua仍仅为45行新模块和既有hook的精确别名/分派接缝；当前Node UI职责拆分、历史回放、Run/Nodes、Boss池及随机owner逐字节保留。59项定义不表示完整遗物池或Boss效果已补齐。四职业源队列夹具只证明同源通用遗物兼容，不扩大本轮用户指定的岩旅行者与既有冻结V4雷电、前两幕比赛范围，也不证明Original V4活动生命语义。

原Strawberry活动owner用真实战斗损血在432e基线证红（玩家上限仍80，永久上限已87），迁入原模块后四件的完整对象图/熵回滚与成功重试通过。新定义和三个占位图标触发历史完整身份守卫后，新增只含这两份数据文件的精确测试逆映射：先绑定当前完整SHA256，再逐字节恢复432e数据；原历史金样、目录、期望hash和原生trace计数全部保留。未知、缺失、重复、换名、换序与无关改动仍由旧守卫拒绝；保留#310 Node UI逆映射组合。

当前重迁专项日志、原始身份恢复/负对照与守恒清单位于独立目录 `m3-max-hp-accepted-432e-evidence`，最终结果和精确源码提交见其交付收据。没有新的候选、官方导入、自然取得、平台或实机记录；完整Quality、独立复审和远端交付仍须另验，不勾TASK-14.1的全量/自然/平台验收。

当前432e组合使用本地Node v24.22.1串行验证：最大生命/源队列/活动owner17项、相邻数据/主题/launch/Black Star/Tail/Molten/Mushrooms与Mark来源61项、历史完整身份/负对照/Node UI组合16项，合计94项Node测试通过，零失败/跳过；另5个相邻Lua入口通过（Molten取得/回滚/预览、Mark36组、事件Fairy8组）。固定9源成员、160生命输入与28完整渠道金样重验通过。架构231模块/1294边；固定Luacheck1.2.0无新增诊断、60条显式历史警告、625项职责度量通过。851份已接受Lua/冻结夹具/历史审查/源池文件逐字节保留，15份原审查新增代码/测试/金样及hook精确保留原0391字节。以上均为专项而非完整Quality或自然/平台验收。
