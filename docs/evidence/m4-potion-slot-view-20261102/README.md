# TASK-4.21：药水菜单 fresh 单槽查询

基线 `6aa3cf90f0a0734514e8a7dbc29988e628a5c74d`；Node `v24.22.1`。不使用缓存，不改药水规则、布局、动效或操作语义。TASK-4.21备注待前序465合入后通过CLI协调追加；本切片先保留私有计划。

## 为什么不是缓存

同一render的frame药水视图和popup之间有约20个渲染/native调用。合成重入测试在真实Host的mock `SetSizeDelta` 中执行公开 `Run.play(burning_pact)`，旧run/battle/药水inventory身份、场景/战斗代次、回合及输入代次不变，药水可用性仍改变。因此不能把早先fresh数据当成稍后仍fresh，更不能跨hover缓存。`potion_popup_slot_view.lua`保留这一边界回归。这里不声称官方客户端曾发生该重入。

## 实施边界

- `abyss_run_potions.lua` 将原有逐槽row构造抽成共用private helper；完整 `Run.potionView` 仍按原槽位顺序构造，空槽保留空。
- 新增 `Run.potionSlotView(run, slot)`：非法/越界/空槽返回nil，合法槽每次重新执行原候选模拟，保留全敌人合法目标搜索、规则、拒绝原因与脱离源数据的effects。
- `abyss_battle_ui.lua` 仅popup的 `actions.item` 改为查询当前槽；独立open、render、act均fresh。实际 `BattleActions.usePotion` 原完整重验不动。busy原显示缓存不当fresh、不开放popup。
- 精确API合同仅追加 `potionSlotView:['run','slot']`，不修改原expected。TASK81的输入路径显式化由另一切片负责，集成时保留双方。

## 证据

`node scripts/test-lua.mjs tests/lua/potion_slot_view.lua`：34个注册定义逐槽与完整view深等、完整run/RNG图不变；非法slot（nil/bool/string/0/负数/小数/越界/NaN/±Inf/table）、空槽、五槽容量、outside、unknown、automatic、事件限制、effects副本、原地状态变更及首active目标失败后继续后目标，约15秒，原30秒预算不变。

`node scripts/test-lua.mjs tests/lua/potion_popup_slot_view.lua`：真实Host三药水单次render候选模拟 **6→4**，完整run/RNG不变；busy不查询且关闭popup；无refresh状态改变后的旧Use拒绝、恢复后真实使用正确；同render中途命令后popup仍fresh禁用。最终约6.7秒。

三项临时生产变异均被指定断言杀死并恢复源码：完整库存委派（Host计数6，拒绝）、跨调用缓存（全定义row不等，拒绝）、仅首敌人（后合法目标丢失，拒绝）。不降低断言、时限或原门槛。

原相邻Lua `potion_slots`、`potion_target_rejection`、`approved_main_host_potions`、`potion_popup_readability`全部通过。精确Run API、JavaScript语法、质量测量/架构/固定hash Luacheck通过；四关键变异与四原生合同结果见对应日志。独立reviewer额外验证真实Potion Belt第五槽、跳过dead/首active失败继续、outside六类row与完整run纯度，并独立重跑Host通过。

`slot-initial-fixture-error.log`保留初次测试假定nodeFlow存在的夹具错误；改为明确构造测试事件上下文后全部通过，未改生产规则。

## 尚未证明

这里仅证明避免模拟未选中的药水；不是手机FPS、冷载/P95或官方LuaHost结果。未运行GUI、官方导入、设备测试、发布/master/Tag或完整托管CI；局部检查不替代精确PR SHA的完整CI。没有撤销跨hover缓存风险结论。

## 与奖励尺寸缓存组合后的注入点修正

在组合基线 `653151ba306b831cf11239e3bbc6ca28936952c2` 上，独审诊断旧fixture为 `injected=false / fresh.canUse=true / use.interactable=true`：465已正确跳过稳定尺寸提交，故旧 `rewardList.SetSizeDelta` 钩子没有执行，并非fresh查询生产回归。

只把测试钩子移到同阶段、同节点仍实际执行的 `SetAnchoredPosition`，先单独断言 `injected==true`，保留公开Run.play、全部身份/代次以及模型与popup fresh断言。组合Host通过，三药水候选仍为4，非法旧Use拒绝与恢复真实Use仍通过（`combined-host-green.log`）。

临时负控仅在render阶段向popup传早先 `frame.potions`，不改变open/act的fresh查询：被原重入断言 `popup reused a pre-reentry view` 杀死（`combined-old-frame-cache-mutation.log`），证明注入不只是计数成功。全部临时生产变异已逐字节恢复，摘要与组合基线见 `combined-reentry-sha256.json`；未修改465生产缓存或任何规则。

## PR465合入后的精确集成身份

- 当前集成base：`de5607ba8edc0701c2545a587c85aefd499281b4`（PR465已合develop）。原独立基线6aa及中间653/827证据保留为历史，不用其CI资格代替新PR。
- 在线性新base上依次组合TASK81显式输入、fresh单槽查询及注入点修复后，内容提交为 `ad7820030efc78ae2ae5c64e3d2b087a3466621c`，树 `37a9ce61e28d24af3418bb106a51d88599a13819`。
- 注入点修复历史提交 `827ca090ab653a432666d44f498f4d8f79d22ad4` 在线性组合对应 `ad7820030efc78ae2ae5c64e3d2b087a3466621c`。本次核验de5607确为ancestor，且 `git diff 827ca09 ad78200 -- src tests` 为空：源码和测试逐字一致，TASK81的显式路径与精确新增API断言均保留。
- 已有组合定向结果：Host候选数4、合法使用与无refresh拒绝/重入fresh通过（`combined-host-green.log`，6336ms）；旧frame-cache临时变异被原重入断言杀死（`combined-old-frame-cache-mutation.log`，6193ms），生产恢复hash见 `combined-reentry-sha256.json`。上述是当时实跑证据，未声称本次重新跑Lua。

本轮仅通过Backlog CLI追加TASK-4.21计划/备注并更新本说明；保留465记录、In Progress状态和未勾AC3。仅重验Backlog/diff，不重复Lua。下一份组合PR仍须其精确SHA的独立审查绑定及完整托管CI，手机与官方客户端性能仍未验。
