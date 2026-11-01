# PR196 独立评审：费用、目标与选牌接口

## 冻结身份与结论

- 仓库：CHNISam/Slay-the-Abyss；Draft PR196，作者 CHNISam，冻结 head `529c8af1c2fd0bc6d501260824b04eb6f18821ee`。
- 开始前读取 develop `9ae1aec` 的 AGENTS/HANDOFF/SCOPE、Backlog overview；核对 TASK-16/16.1 的完整75卡要求与当前owner。此报告只覆盖费用、目标和选择接口，不认领任务，不重复消耗顺序审查。
- **发现一个 P2 可执行规则缺陷：战斗中新生成的 Blood for Blood 丢失生成前的受伤减费，下一回合本应可出的牌会错误地因能量不足被拒绝。**
- 独立最小候选已真实红→绿，只改 `abyss_card_actions.lua` 四行。没有写生产源码、远端、Backlog，也没有运行 full npm、安装软件或平台实机。
- 第二项“战斗选牌面板显示印刷费还是当前费”只记录非阻塞展示歧义，不作为第二个确定bug或合并阻塞。

## P2：新生成的 Blood for Blood 必须带上此前受伤计数

建议行内位置：`src/lua/abyss_card_actions.lua:44-45`。

当前 `fresh()` 用 `{cardId=id,upgraded=false}` 创建新牌，没有把已经存在的 `state.player.damagedThisCombat` 写入 Blood for Blood 的 `costReduction`。`generateAttack` 随后只加本回合0费覆盖，因此当场看不出差异；`Combat.startPlayerTurn:546` 清掉临时覆盖后，错误基础费用立即暴露。

### 预期来源

仓库 `docs/evidence/warrior75/sources.json` 指定的固定镜像提交为 `fc379c875c11e008e9c10548ac8e394c301c532f`。本次重新读取以下源并核hash；它仍是未获正版PC二进制认证的反编译镜像，不冒称原游戏实测。

1. [BloodForBlood.makeCopy，第56–61行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/%E6%9D%80%E6%88%AE%E5%B0%96%E5%A1%94%E5%8E%9F%E7%A0%81/cards/red/BloodForBlood.java#L56-L61)：新牌按整场此前 `damagedThisCombat` 降低基础费用。
   - SHA256：`00bce85e14d4ac122726ea09e3bb02ebec4af23314626b7b669d093b65390b01`
   - Git blob：`258da481d1aca68052cb9610cc23173478f8ae91`，与仓库来源表相符。
2. [InfernalBlade.use，第26–30行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/%E6%9D%80%E6%88%AE%E5%B0%96%E5%A1%94%E5%8E%9F%E7%A0%81/cards/red/InfernalBlade.java#L26-L30)：随机攻击调用 `makeCopy` 后，设置本回合0费。
   - SHA256：`44e39d9db205754e92f4343d52463a671080dac066e065f5ad9c21210fda9a45`
   - Git blob：`446d68ee4633cb16f2e5ad463711733f2c703bc2`，与仓库来源表相符。
3. [AbstractCard.setCostForTurn，第2499–2507行；resetAttributes，第2533–2543行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/%E6%9D%80%E6%88%AE%E5%B0%96%E5%A1%94%E5%8E%9F%E7%A0%81/cards/AbstractCard.java#L2499-L2507)：临时费用不覆盖基础费用，重置时恢复基础费用并清掉修改标记；第931–940行升级会保留已为0的临时费用。
   - SHA256：`f11601db66e8df3699481076763b858672ce83d4a6eea6c1abf0715f254b5c5c`。
   - 来源表此前该文件为403，本次固定URL返回全文，与本地副本逐段相符；没有把旧错误当作本次认证。

### 实际复现与红绿

`generated-cost-regression.lua` 使用重建的正式控件树、GameUI/BattleUI、Run.play/Run.endTurn和真实卡牌随机流：

1. seed30，Run创建 Cultist 战斗；夹具布置 Bloodletting + Infernal Blade 两张手牌及空抽弃牌堆。
2. 从生成控件点击卡牌和出牌区，Bloodletting实际损血，`damagedThisCombat=1`。
3. 再经控件打 Infernal Blade，真实随机生成 UID103 Blood for Blood；当回合费用0。
4. 点击生成的结束回合控件；Cultist第一轮只上仪式，没有新增损血。
5. 下一回合自然恢复3能量，临时费用解除。本应基础4−此前1次损血＝3，实际卡面和核心均为4，`canPlay=false/insufficient_energy`。

这是受控夹具中的真实生成与控件事件，不是自然获得两张前置牌、完整通关或平台输入证据。

- 冻结head：`expectedCost=3 actualCost=4 uiCost=4 energy=3 playable=false`；真正期望断言失败，**exit1**。
- 最小候选：`expectedCost=3 actualCost=3 uiCost=3 energy=3 playable=true`；**exit0**。
- 诊断脚本 `generated-cost-ui-probe.lua` 断言的是错误签名，退出0只表示复现成功，不是正确性通过。交接与后续回归优先使用 `generated-cost-regression.lua`。

### 最小候选

`minimal-cost.patch` 仅在无prototype的新 Blood for Blood 上，按 `damagedThisCombat` 初始化减费；stat-equivalent复制保留自己的已有费用/升级/临时覆盖，不重新套用全局计数。

- 原文件 blob：`a73d264d6c2e540d9fc2c9c5809e373b89c8c4cb`
- 候选文件 blob：`9af11292f86da00c9f148ab2cf19ff2c8eb54ea3`
- patch SHA256：`cf589cffd13aff85dc440ae40fe55340f5a1b3b919547c3bf3e27617630a2649`

## 有限验证结果

- `generated-cost-boundaries.lua`：11组，旧head 5败/6过 → 候选11过。覆盖初始牌、新生成牌、未受伤、1/3/5次损血、升级、当回合免费、真实结束回合复原、已有prototype保真及不影响其他生成攻击。
- `choice-contract-probe.lua`：7种真实生成控件选牌入口通过：Armaments、True Grit+、Burning Pact、Headbutt、Warcry、Dual Wield、Exhume。49次缺参数/错误token/错误UID调用均拒绝，整个combat状态深比较不变，包含资源、UID、RNG与队列；选择后恢复战斗输入。
- `cost-target-contract-probe.lua`：6种目标牌共48次非法目标，以及6次非法UID，共54次原子拒绝；4组普通/升级Whirlwind 0/2能量，2组临时费用+升级，1组能量不足拒绝通过。正向目标均可执行。
- 原有 `warrior75_choice_ui.lua` 通过；原有 `warrior75_edges.lua` 39组在head/候选均通过。只作既有专项保护，不冒称新的独立39项发现。
- `verify-frozen.py` 核验75个相关源/构建依赖文件逐Git blob等于冻结head；重建data/UI。候选与冻结源在这些文件中只有上述4行差异。75是文件数，不是逐卡验收数。

## 非阻塞：新战斗选牌面板的费用展示约定尚不明确

真实Corruption→Armaments打开的选择面板，Defend卡面显示1，但同一战斗实例核心执行费用为0。原因是 `abyss_deck_ui.lua:14` 仍以仅包含catalog的永久牌库上下文渲染。

现有 `docs/design/BATTLE_IMPLEMENTATION.md` 明确永久牌组视图显示印刷数值；本次没有找到新战斗选择模式单独规定当前费用的约定。该面板已改为手牌/弃牌/消耗堆的具体战斗UID，但是否仍意图显示印刷费需作者明确。故只记录差异，不把永久牌库本来应显示印刷费当bug，也不提交费用面板补丁。

旧callback重开调查未形成足够真实输入证据，不列发现，不进入发布材料。

## 边界与交接

未执行完整75卡扫描、全量npm、官方导入、客户端/手机实测；没有依据把这些缺证写成代码bug。PR195主线两行输入保护的集成差异由root单独处理，不纳入本评审。PR仍是Draft；本修复不能替代严格来源认证、当前SHA全量CI或75张平台验收。

复跑见 `REPRODUCE.md`；允许发布的最小交接文件见 `DELIVERABLES.json`。本地完整第三方方法体、纯诊断与未证实调查不应提交到产品仓库。
