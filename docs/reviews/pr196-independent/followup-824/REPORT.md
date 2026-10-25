# PR196 Blood for Blood 生成减费复核

## 结论：824a5da 仍未修复

- 冻结PR head：`824a5da106525a95e7a0e8cf5c1e8ec0b411123a`；base `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。PR仍为Draft/open，owner仍为CHNISam。
- 只复核上次已报告的P2“新生成Blood for Blood丢失生成前的受伤减费”，未重新扫描75张卡或扩展其他缺陷。
- 从评审归档提交 `ff3d54b83af2636a5f7987d09f6cfe7b21a80c7e` 恢复原 `generated-cost-regression.lua` 与11组 `generated-cost-boundaries.lua`，**脚本内容未改动**。当前85件实际运行/UI构建依赖逐Git blob核对824头后，重新生成data/UI并运行。
- 真正费用回归仍exit1：`expectedCost=3 actualCost=4 uiCost=4 energy=3 playable=false reason=insufficient_energy`。
- 原11组边界仍6过、5败，exit1。未修结果来自真实新头执行，不是静态推测或旧日志重用。

## 精确变化与缺口

529c8af→824a5da比较为ahead 7个提交；完整文件统计保存在 `compare.json`。本缺陷相关代码对比：

1. [CardActions.fresh，第42–48行](https://github.com/CHNISam/Slay-the-Abyss/blob/824a5da106525a95e7a0e8cf5c1e8ec0b411123a/src/lua/abyss_card_actions.lua#L42-L48) **逐字节未变**，文件Git blob仍为 `a73d264d6c2e540d9fc2c9c5809e373b89c8c4cb`。新牌仍只初始化cardId/upgraded，没有继承既往damagedThisCombat。
2. `abyss_actor.lua` 仍为原blob `8fe006cf545c833532adf58eb4921837ef9757c2`：受伤记录damagedThisCombat，同时只降低当时在手/抽/弃牌堆中的Blood for Blood费用，无法追补之后才生成的牌。
3. [Combat.cardDefinition，第261–262行](https://github.com/CHNISam/Slay-the-Abyss/blob/824a5da106525a95e7a0e8cf5c1e8ec0b411123a/src/lua/abyss_combat.lua#L261-L262) 仍只从实例costReduction扣费，并允许costForTurn临时覆盖。没有新增生成减费的补偿逻辑。
4. 当前确有费用生命周期修改：临时费用清理由旧startPlayerTurn移至 [endTurn第593–601行](https://github.com/CHNISam/Slay-the-Abyss/blob/824a5da106525a95e7a0e8cf5c1e8ec0b411123a/src/lua/abyss_combat.lua#L593-L601)，并只清手/抽/弃三堆，排除消耗堆。这个修改没有修复本缺陷。实际Run回归仍在下一回合显示错误4费。
5. Run的房间随机源接线已有变化，但同一个原seed30回归不改动即可真实生成Blood for Blood并触发同一失败。精确Combat/Run差异保存在 `evidence/combat.delta.patch`、`evidence/run.delta.patch`，不代表已审查它们的其他行为。

费用预期仍来自上轮已核hash的固定镜像 `fc379c875c11e008e9c10548ac8e394c301c532f`：BloodForBlood.makeCopy第56–61行先扣damagedThisCombat，InfernalBlade.use第26–30行再设置本回合0费。源hash与来源边界见 `PREVIOUS-REPORT.md`，没有以原版记忆替代来源，也不宣称正版PC二进制认证。

## 本轮执行结果

- 原生成费用回归：exit1。真实生成控件点击Bloodletting→Infernal Blade，受伤计数1，当回合免费；真实结束回合后应3费，实际4费、3能量不能出。
- 原11边界：6过5败。失败为新生成牌继承1/3/5次损血的3组，以及真实Infernal生成后下一回合普通/升级费用的2组。现有初始牌、未受伤生成、prototype复制、其他攻击生成及未受伤普通/升级复原仍通过。
- 当前 `tests/lua/warrior75_choice_ui.lua`：exit0。该必要接口测试使用生成的原生hit游标区域选UID、恢复队列和战斗输入，并已明确断言Corruption选择卡面费用0。只报告该现有测试通过，不扩展为全体选择/输入验收。

卡牌/牌堆布置是原有受控夹具；Run/Combat、卡牌随机生成、结束回合和生成控件事件实际执行。不是自然获取前置牌、完整通关、官方导入或千星实机证据。

## 复跑及边界

执行环境更换后，旧临时目录不存在，原probe从已归档Git提交恢复，运行依赖从本轮新head重新核对，没有使用不明来源的旧编译产物。使用现有原生Lua5.4，不安装依赖；runner SHA256与上轮一致：`e5543c066e49980a3dea2e2c77f85b8c577e6ecb88eaa62d26665d7a1943bcd0`。

复跑步骤见 `REPRODUCE.md`；源与日志身份见 `FROZEN.json`、`verified-source.json`。本轮未修改生产源、远端、任务状态，没有新增候选补丁，没有运行全量npm或全75扫描。此结论仅为该P2尚未修复，不代表对整个PR的全绿/全红判定。
