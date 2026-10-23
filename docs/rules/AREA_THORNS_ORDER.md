# 区域伤害与荆棘排队边界

## 范围

TASK-16/16.1 独立候选，最初核查基线 develop `0fb6dc2fc7eeacea2751209a6e4bfad17f79fa4a`；最终五文件增量以 PR82 `0efbb7afc2c50a90476e39b908c6fc2d3e43b9f6` 为基线，保留力量/敏捷封顶与既有测试夹具修正。不改卡牌数值、可玩池、状态封顶、随机数、地图、UI 或任务状态。

实际复现：玩家 1 HP，两个各 100 HP 的敌人，第一个有 3 荆棘，打出 Thunderclap。旧实现第一个敌人变 96 HP（升级 93），玩家立即被反伤杀死，第二个敌人仍是 100 HP。资料所描述的单个区域伤害 action 应先伤害两个敌人，再执行排队的反伤。因此两个敌人应均为 96 / 93 HP。Cleave 同样受影响。

夹具是合法核心状态入口与真实出牌 API 的受控边界，不证明首发自然遭遇会产生敌方荆棘，也不是原版客户端观察。

## 固定资料及限制

2026-10-23 只读以下固定反编译镜像的方法体；没有安装、下载执行或复制其实现。此非 MegaCrit 官方发布的原作构建，镜像声称的版本未经过官方 JAR 认证；仅认定本切片符合已读资料，不把资料一致当作原作游戏实测。

固定前缀：https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/

- [ThunderClap.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/ThunderClap.java)：费用 1，伤害 4，升级增加 3；先一个 DamageAllEnemiesAction，随后每个敌人 ApplyPowerAction，易伤 1 不随升级改变。
- [DamageAllEnemiesAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAllEnemiesAction.java)：在同一个 update 中遍历所有存活敌人并伤害，最后才清理战后 action。
- [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java)：被普通攻击时 addToTop 一个 THORNS 类型 DamageAction，不立即扣攻击者生命；不会递归触发荆棘。
- [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java)：addToTop 插到队列首位，因此一次 AoE 多个反伤按命中目标的逆序执行；clearPostCombatActions 保留 DAMAGE 类型。
- [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java)：THORNS 不因来源正在死亡而取消。
- [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java)：已死亡目标跳过状态添加，已有同名 power 叠加。
- [VulnerablePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/VulnerablePower.java)：无相关遗物时普通伤害乘 1.5。资料中的特殊遗物交互不属于本切片。

## 最小实现

Actor.damage 可接受一个局部反伤收集表；只有区域伤害传入它。Actor.retaliate 共用原有格挡吸收、无攻击修正、无递归的反伤逻辑，允许已死敌人作为反伤来源。Combat.retaliate 保留目标实际 HP 损失的 EnemyAI hook，包括 Guardian Mode Shift；Effects 对每个 damageAll hit 单独收集，并在全部目标受伤后逆序执行反伤，随后才继续该卡下一效果。没有持久队列、状态字段或一般引擎 action 改造。单体伤害仍即时调用相同反伤 helper。

已死的反伤目标不再产生扣血事件；这延续本核心死亡目标无伤害的约束，不宣称复刻原版死亡后动画/无效 action 的每一帧。复活药水、Lizard Tail、其他未支持 power/relic、完整游戏 action 队列和原版构建认证均未验。

## 验证

新增 `tests/lua/thunderclap_order.lua` 27 组，含独立复审追加的四组；签名封顶基线失败 7 组，候选全部通过。覆盖基本/升级伤害后易伤、已有易伤、满格挡、零伤、已死/本次死亡目标、多个反伤逆序与逐帧事件、1HP/双方全部死亡、Cleave 共享边界、失败原子回滚、无递归和修正豁免、Guardian HP 损失与转形/死亡。Guardian 作为 damageAll 来源的用例仅为解释器受控夹具，不宣称其原版 AI 有该招式。

系统 Lua 5.4 最终实跑：39 个既有 Lua 套件及新增套件（27 组）共 40/40 通过；保留封顶、原子出牌/超限夹具、Guardian、全卡池、UI、库存及地图回归。追加四组保护逐次 AoE 反伤排队、致命反伤阻止后续次数/能量/格挡/状态、单体即时反伤不变，以及组合后双方 Strength/Dexterity 封顶仍正确。多次区域伤害仅为解释器受控夹具，不声称当前卡池已有该多次招式。五种负向变异全部检出：取消延迟、改成正序、死来源取消、去掉 Guardian hook、反伤绕格挡。

最初隔离快照 `npm run check` 未完成：build:ui 缺少 tools/render_traveler_cards.py，停止在 Lua 聚合之前。最终组合使用固定 PR82 的完整 Lua 测试/生成数据及 UI 夹具，实际独立运行全 40 个 Lua 套件；未将这些结果冒充 npm/Fengari 聚合。Fengari、当前提交 CI、完整聚合、千星平台编译/导入/实机尚未通过。发布前需完整当前主线重测并独立复审，不能关闭 TASK-16/16.1 的整体 AC。
