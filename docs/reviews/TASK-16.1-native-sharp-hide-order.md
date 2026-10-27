# 原生牌的尖刺甲壳伤害与抽牌顺序

本片基于 `34009f1067b1f49c9aee0f9c55ef9b4ce4cc6df3`（业务基线 `f3a43bc0`），仅修复原生牌遇到 Guardian Sharp Hide 时，把物理牌提前放入弃牌堆的问题。

## 固定来源与实际缺陷

来源为本地归档 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`；完整归档 SHA256、十个 raw Java 成员路径与逐字节 SHA256 登记在 `tests/fixtures/native-sharp-hide-order-source.json`。原 Guardian/Rod 锁不变，没有将 Java 原文入库。

- `SharpHidePower.onUseCard`（39–42）：每张 ATTACK 加入独立 BOTTOM THORNS DamageAction。
- `CentennialPuzzle.wasHPLost`（35–40）：实际失血后一次性加入 TOP DrawCardAction(3)，先于既有底部动作。
- `UseCardAction.update`（71–128）：物理牌随后才离开出牌区并进入弃牌/消耗。
- `DrawCardAction.update`（73–85）：抽牌堆、弃牌堆都为空时结束，不能抽取仍在出牌区的牌；`CardGroup`/`EmptyDeckShuffleAction` 锁定实际洗牌消费边界。
- `DamageAction.update` 的 dead-owner 取消分支对 THORNS 例外；`GameActionManager.clearPostCombatActions` 保留 DAMAGE。最后一只 Guardian 已死仍结算捕获的伤害，玩家同时死亡以 defeat 优先。

真实公开入口：Run seed42，公开移除初始牌、取得 Searing Blow+2、Puzzle、Rod，然后显式 boss floor/startCombat。第一击21、Charging Up给9格挡，第二击实际造成12并进入防守，Close Up实际获得Sharp Hide3。第三击前手牌1、抽牌堆0、弃牌堆0；牌定义真实 `runNativeABI=true`、`target=ENEMY`。这是受控战斗组件，不是自然获得/自然通关证明。

修复前第三击扣2 HP后把同UID的出牌提前丢入弃牌堆，Puzzle再洗回并抽回它，手牌变1、shuffle counter增加2。首次只读审查对照：Guardian修复头 `42d17f1c2ab771b63c4f9f5f546fda0face656ac` 1730ms复现；其前基线 `1b6c22902339f8a11543e107d197f6120144cc82` 1658ms为HP−3且Puzzle未触发（旧HP通知路径缺陷），不能把旧行为称作正确原版oracle。

本树先最小RED再生产修改。收口另以精确34009f10原Combat/CardActions预加载、其余依赖不变，1286ms重新得到 `native_sharp_hide_top_draw.lua:18: 1 ~= 0`。当前同一用例GREEN：HP−2、Puzzle已用、手牌0、弃牌1同UID、cardInUse清空，shuffle counter不变。此顺序期望来自上述raw来源；耗时与HP等运行观察向量是项目证据，不是独立PC实测。

## 最窄改动

`queueNativePlay` 将已捕获Sharp Hide数组项逐项放在原生处置前，使用现有 `capturedSharpHide` handler；CardActions只补该内部桥接及这一种DAMAGE动作的胜利保留。抽牌仍使用现有TOP队列，不加入通用drain。原reactions表的Hex等非数组字段仍留给原处置路径。旧ActionQueue也调用同一窄handler，Actors.retaliate及其四参/受限第五参语义不变。

没有新增生产模块或依赖边；architecture无需新增登记项。实际工程检查157模块/914边，固定Luacheck1.2.0检查无新增诊断，105条既有warning，所有受限呈现函数≤15；未编辑baseline。

## 原预算验证

所有Lua使用仓库默认30秒；没有改运行器、阈值或旧测试。Node24/Fengari真实运行结果：

| 检查 | 结果与耗时 |
|---|---|
| 最小原生TOP抽牌 | GREEN，1230ms |
| 新边界六组 | 全绿，7861ms |
| 新raw10来源锁JS | 全绿，20ms |
| 既有Guardian Rod / modifiers / death rollback | 3/8/7组全绿，1960/1180/2327ms |
| 既有真实原生combat / choices | 全绿，2106/1917ms |
| 既有Puzzle / ActionQueue / defeat queue | 1/7/8组全绿，322/112/706ms |

六组保留无Rod的3伤害与TOP观察；四参事件标签兼容、非法第五参原子拒绝；真实出牌击杀最终owner后保留伤害；玩家0HP停止处置、同时死、Fairy复活；实际TOP抽牌后的Core晚throw恢复全图/原引用/同UID重试；公开外层 `Run.transaction` 晚validator拒绝已完成暂存出牌（不是声称Run.play或retaliate内部有false ABI）；非法UID提前拒绝；真实Chosen Hex对原生Armaments的Dazed元数据路径不变。

死亡矩阵公开取得Searing Blow+20作为终结牌，显式设置入场前HP2/3，明示组件边界；没有直接改敌人HP、玩家能量、战斗牌堆或Sharp Hide状态。日志在本树 `build/native-sharp-hide-{final,old-regressions,baseline-red,static}.log`。新Lua自动纳入现有发现器，额外JS wrapper保留默认时限。

未运行完整npm check/全职业矩阵，未进行平台导入、前台输入或实机验收；不据此宣称自然路线、完整RC或UI门禁通过。后续统一组合由主线程验收。
