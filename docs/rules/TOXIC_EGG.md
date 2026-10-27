# Toxic Egg 本地单件

基线 `cfba9b0b`，业务基线 `2349400c`。只实现 `Toxic Egg 2` → `toxic_egg`（毒素之卵），没有接其它两个 Egg、Question Card、Busted Crown 或 Singing Bowl。

固定源锁为 [toxic-egg-source.json](../../tests/fixtures/toxic-egg-source.json)。本地 ZIP `319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的七个成员逐字节 SHA256 已核；它是社区反编译镜像，没有认证正版 PC 二进制。独立脚本 `tools/oracles/sts1_toxic_egg.py --source-zip <archive> --check` 只读核验，没有下载或执行原作。

## 规则与所有权

`ToxicEgg2.java:26–49`：仅实际 Skill、`canUpgrade()` 且未升级时升一次；预览调用本遗物的获得逻辑。无抽样、金币、永久 UID 或牌库插入。普通技能与无色、HEALING 技能同样有资格；攻击、能力、状态、诅咒及不可升级技能不升级，已升级技能不重复升级。

普通 `AbstractDungeon.getRewardCards:1449–1457` 先完成原身份选择和升级随机数，成功随机升级的牌直接跳过预览。生产 `CardPool` 没有改动；Run 在其返回后为私有候选标记升级。Dream Catcher 使用同一普通来源生成预览，保留原四号返回的升级标志，领取和原生 UI 均读取该标志。原有生成函数的随机消费保持原样。

`ToxicEgg2.onEquip` 只遍历 `combatRewardScreen.rewards` 里的卡组。适配为当前未解决的战后奖励与 Sensory Stone 尚未领取的 RewardItem 组，包括已经打开的一组。`CampfireSleepEffect:70–72` 直接打开 CardRewardScreen，因此既有休息候选不追溯；领取时获得钩子仍升级。旧牌组、旧商店货架与战斗临时生成牌也不追溯。Watcher 的真实未升级 Miracle 用作临时技能对照。

`RewardItem(CardColor.COLORLESS)` 构造时预览。Sensory 保留完整35牌来源、顺序与双 RNG；只解除 Toxic Egg 门禁，并核验冻结候选的实际身份、稀有度及正确升级标志。原生事件文本读取升级费用，独立既有源 oracle 的 seed3 第一组 Madness 正确显示0费。

`ShopScreen` 对初始商品与 Courier 补货做预览，价格保持原源消费和计算。获得 Egg 不重写当时已有货架；之后购买仍由永久获得钩子升级。升级标志与次数通过商品→购买→永久牌传递，UI 使用真实升级名称、费用及正文。

`ShowCardAndObtainEffect:95–103` 的获得回调位于插入永久牌组之前。继续使用 Run 的既有 staged transaction、唯一永久 UID 和持有顺序；陶瓷鱼仅真正获得时+9金币。Winding 的两个 Madness 各获一次升级和独立 UID，未改伤害/复活路径。抛错或拒绝保留原奖励、货架、牌库、随机流及共享环引用。

## 正常来源与边界

Uncommon 原母池30项及其它四个稀有度队列均未改。源 catalog 原已有非 Endless `floor<=48`；完整 RelicPool 在49层消费不合资格的候选后按源从尾部继续。现有受限普通商店/宝箱新增本件同样资格，初始准备使用目的房间楼层，补货使用当前房间楼层；没有改其它遗物资格。

seed8 的真实 Big Fish `box` 从完整事件遗物队列首候选取得 Toxic Egg、获得真实 Regret，再用初始牌组/原敌人正常命令获胜，核对奖励随机流、预览、领取和下一战同一永久 UID 的升级。此证据使用显式事件房间边界，不是完整自然通关。普通商店和宝箱仍是项目原有的受限已实现候选集，本件不宣称这些渠道已达到完整原版概率。

未扩修的既有缺口：Dream Catcher 的普通生成 context 尚未传入 `act`，所以第二/三幕原有非 Egg 随机升级概率适配仍缺；本件没有改变该升级抽样或随机消费。没有实机、官方导入、完整自然通关、全遗物组合或当前提交完整 Quality 证据。遗物图标明确是已有资源占位；专属美术与设备验收待做。原 Winding/Sensory 源锁中的历史缺项清单未改，以本文件和新增源锁说明当前差异。

## 回归

新增11份生产入口 Lua 短组：永久获得/资格与输入隔离、真实来源→胜利→下战、Dream Catcher、商店与补货、三组无色奖励、两个 Madness、48/49来源资格、商店/休息 UI、0费事件 UI、四职业+V4、onEquip 晚失败回滚。保留旧 Winding/Sensory outcomes 的完整循环与其它遗物负例，只把 Toxic 项换成真实执行断言。

初始公开获得3项均因 `relic_content_unavailable` RED。使用新增真实定义但预载基线真实 hook 后，升级与 onEquip 两项仍 RED（1绿2红），证明不只检查注册。49层资格2红→3绿；真实事件 Madness 费用1→0 的显示红→绿。机器摘要见 [toxic-egg-verification.json](../reviews/toxic-egg-verification.json)。所有结果都是本地离线组件证据。
