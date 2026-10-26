# 机器人剩余牌实际接线

本轮复用归档Final的事实与中文定义，并重新核对固定319009源。采用现有Combat/ActionQueue/HandChoice/Run所有权；不引入归档旧sourceUid、第二套永久牌引用或缩水生成池。固定ZIP SHA256为`3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`，来源为aeubanks/sts commit `319009d5df0a82d9fb0f23cc22322286c6a87ec0`的社区反编译，尚无正版PC二进制认证。

第一片完成7张基础/升级真实入口：Recursion、GeneticAlgorithm、Recycle、Scrape、AllForOne、Fission、Reboot。Profile从56到63张；剩余12张仍未登记为可玩。查阅的源包括各牌constructor/use/upgrade、RedoAction、IncreaseMiscAction、GetAllInBattleInstances、RecycleAction、ScrapeFollowUpAction、FissionAction、ShuffleAllAction、PutOnDeckAction、ShuffleAction。

- 递归唤起后重新生成同一球对象，暗球储能不重置，末敌死亡取消生成尾部。
- 遗传算法在出牌前捕获旧misc格挡，动作增加同uuid所有牌堆/在用/limbo/自动队列实例，永久变化只由deckUid认领。StatEquivalent独立；真实Duplication产生1+3格挡、永久misc5，仅原牌消耗。
- 回收复用真实手牌UID选择与代次/token；空手无动作，单张自动，多张暂停。先排返能TOP，再走真实消耗钩子；X读取当时能量，免费打出标记不改变源costForTurn。
- 刮削只记录本次真实抽入手牌的对象，非零且非免费牌逐张主动弃牌，复用真实discard钩子。
- 万物一心按基础费用/免费标记筛弃牌，回手动作排在当前牌处置后，满手保持原弃牌。
- 裂变按原已填球数给能量/抽牌，升级逐槽唤起，复用末敌死亡后的队列清理。
- 重启使用原shuffleRng先洗弃牌、cardRandomRng逐张随机移手牌（包括单张random0）、再洗抽牌。升级抽牌超过现有牌数会另消耗源EmptyDeckShuffle调用；测试明确保留该第三次shuffle。

`defect_final_actions.lua`先以unknown deck card红，随后7张各基础/升级共14个真实Run场景绿；涵盖原对象、永久Smoke后成长、选择恢复、能量、球及RNG计数。`defect_genetic_copies.lua`覆盖永久/临时真实药水复制、stat-equivalent隔离及purge。宿主owner注入测试不替代牌效果测试。展示通过CharacterPresentation生成已知动作说明，Genetic格挡复用动态block预览。未知Final动作/数值在Capability拒绝。

以上仅离线核心实现，不宣称完整75、正式平台导入、实机UI或原版二进制比对通过。

第二片接入7张生命周期牌（累计14/19，Profile70）：Rebound、ForceField、Equilibrium、Amplify、EchoForm、MachineLearning、SelfRepair。固定源复核ReboundPower.justEvoked、EchoPower.cardsDoubledThisTurn、AmplifyPower、EquilibriumPower、DrawPower、ForceField.configureCostsOnNewCard/triggerOnCardPlayed、SelfRepair的HEALING及RepairPower宿主胜利边界。

普通牌在这些Power/力场存在时进入真实队列以保持相同生命周期。力场仅在hand/draw/discard收到能力牌事件，新构造牌按已发生能力历史减费，排除exhaust中的停留时间；增幅/回响共用既有同UUID purge队列，不重放effects冒充出牌。弹回跳过自身后作用于下一次处置；消耗/purge/能力优先。均衡仅保留非虚无手牌，轮末减层；机器学习只增加正常回合抽牌；自我修复仅一次真实胜利治疗并由Run复制最终HP，Smoke不触发。

`defect_final_powers.lua`先红unknown generated ForceField，随后7张基础/升级真实Combat使用、回合结束/下回合、复制次数和真实Run胜利同步绿（约1.9秒）。旧自动生命周期及Genetic复制回归继续绿。仍缺Buffer、StaticDischarge、HelloWorld、WhiteNoise、CreativeAI及全池执行矩阵，不能据70定义声称完整75已验收。
