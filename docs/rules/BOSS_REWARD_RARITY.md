# Boss 战后选牌：稀有度边界

## 独立范围

TASK-13.1 的一个离线切片：Boss 战后卡牌奖励只能来自当前已支持的稀有牌。继续提供三个不重复选项，领取一个或跳过。普通/精英奖励池、金币、地图、Boss 宝箱、UI 和战斗内核均不改。

原实现 `abyss_run.rewardCandidates` 不看 encounterTier，故 Boss 会抽出普通/罕见牌。固定输入 seed=1，进入 boss_guardian 后在测试夹具将敌方生命置零，再调用实际 finishCombat，旧代码第一个选项为 uncommon/rampage。此为奖励边界隔离，不是完整 Boss 通关实测。

## 读取的固定来源

2026-10-23，只读以下固定反编译镜像，没有安装、执行或复制第三方实现代码：

- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/MonsterRoomBoss.java ：`getCardRarity` 无条件返回 RARE。
- https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/rooms/MonsterRoomBoss.java ：相同方法 L34–35，无条件返回 RARE。
- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java ：`getRewardCards` 默认三个选项，经当前房间 rollRarity 决定稀有度；按 cardID 排重，再复制卡牌。`getCard` 按稀有度选择对应池。

这些是非官方镜像，不证明独立原始 JAR 或官方 PC 版本认证，不是原作客户端直接观察。仅据此核实无修改器的基础 Boss 稀有度规则；不宣称完整 StS1 PC/A0 奖励算法一致。

## 验证与保留边界

新增 `tests/lua/boss_reward_rarity.lua` 覆盖：128 个输入、每次三个唯一稀有选项；同 seed 重现；现有 RNG 每个选项调用一次并推进三次；四张已支持稀有牌均可到达；三个领取位置、跳过、非法/重复请求及返回值副本不可改内部状态；冻结旧版普通/精英输出；未结束、失败与重复结算不额外发资源。

当前支持稀有牌为 barricade / offering / impervious / bludgeon，共四张，足以提供三选一。demon_form / reaper 尚有不支持效果，不借本切片宣称完整 Ironclad 池；未来扩大池不应改动本规则。奖励生成仍使用既有 LCG 和不放回抽样，并未接入原版 RNG，也没有复制原版“稀有度 roll + 重抽排重”的调用序列。因此固定 seed 对原作不一致，不能由本测试推导原作概率或全池等价。

普通/精英稀有度动态概率、升级率、掉药、随机金币及独立 RNG 流仍未对齐。现有金币自动入账与选牌后的流程保持原样，不代表领取顺序和 Boss17 宝箱已还原。所有相关整体 AC 保留未完成。

本地使用系统 Lua 5.4 实际执行新增与相关回归；不是 Fengari、完整 CI 或千星实机通过。完整 `npm run check` 尝试受限于缺少既有依赖 fengari-node-cli，未安装依赖；正式当前 SHA CI 必须另行验证。
