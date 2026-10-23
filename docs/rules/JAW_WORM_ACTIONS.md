# 石颚兽：首幕 A0 动作内容与生命范围切片

2026-10-23。此数值回归已适配 PR91 固定提交 `408ea1b5b9816bdf853ce2fb4497b6660f8c0bfe` 的生产 AI 与动作映射；保留 PR86 的迟缓小魔及 hpRange 遭遇回归。TASK-15 仍归 @Codex，所有全池与平台 AC 保持未完成。生产 Jaw AI 与配置由 PR91 实现，本切片不重复接管或覆盖。

## 固定只读来源

- [aeubanks/sts@319009d / JawWorm](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/JawWorm.java)，blob `033b26ba08b7dea04d2cff62cd50da868ff887b9`。
- [purewhitelove/ButterflyGame@fc379c8 / JawWorm](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/JawWorm.java)，blob `b42fa54e26d092f6026f801ea85d11ed10f3f198`。
- [同一固定版本 AbstractMonster.setHp](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)，blob `4784e38e7afff5980736e2b5c718e62a0c838c47`。
- [Random.random(int,int)](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java)，blob `c4b71d5645688f6e764c46c593223eb91a5249bc`。

构造/takeTurn 的 A0 普通首幕分支一致：生命 40–44（setHp 到 random 的闭区间，maxHealth 等于样本），开局没有 hardMode 的预加力量/格挡；首动 Chomp 基础伤害11；Bellow 先力量3后格挡6；Thrash 先伤害7后格挡5。镜像不是认证官方 PC 二进制，两份一致也不能证明独立来源；没有执行或复制上游程序、分发其素材或声称原客户端观察。

## 最小修正

PR91 已包含全部 A0 数值修正和后续行动选择。集成时完整保留其 jaw_worm 定义、AI 配置及运行时：hp42 静态代表值、实际生命40–44；_1 为 Chomp、_2 为 Thrash、_3 为 Bellow。原 PR86 的 _2/_3 语义与其相反，已撤去重复 Jaw 数据改动。测试通过 ai.chompIntent / ai.thrashIntent / ai.bellowIntent 选择语义动作，不修改其他敌人的 AI、Actor、Combat、Effects、EnemyAI、schema 或地图。

沿用当前粗粒度意图类型：Bellow 为 buff，Thrash 为 attack，具体效果在有序 effects 中；不声称已实现原版 DEFEND_BUFF / ATTACK_DEFEND 图标展示。HP 新增一次项目 LCG 调用，会改变该遭遇后续洗牌/随机状态，不是原版 monsterHpRng、RandomXS128、独立随机流或种子映射认证。

## 明确保留的行为缺口

PR91 已接入 getMove 的后续权重分支、历史动作限制和条件随机数；生产 Jaw 不再使用旧固定循环。其来源、边界与独立策略测试见 PR91 的 docs/reviews/TASK-15-jaw-worm-ai.md。动作内容回归仍强制选择动作，包括重复 Bellow，以隔离数值和事件顺序；这些测试不证明强制轨迹在自然 AI 下合法，也不认证原版随机流。

未实现后续章节 hardMode、全局行动/死亡队列或所有遭遇编组规则。反伤致死后剩余格挡/力量动作的调度没有在本切片认证；现有核心行为不等于上游队列已严格一致。

## 验证

原 PR86 的 tests/lua/jaw_worm.lua 共15组，独立固定数值与事件顺序，不从配置反推期望。原数据11组失败，候选全通过；覆盖首动、两个复合动作、预览副本、全格挡/零伤害、状态修正、强制连续动作、128种子闭区间及重复性、多实例隔离、毒致死、真实出牌和 Run 首幕入口。9种数据错误变异均被检出。

集成保留 PR91 的 combat.lua 原样：显式项目种子选择 Thrash，验证预览副本不改原始11伤害、随后7伤害和5格挡；不恢复 PR86 的固定循环断言。15组动作内容回归继续覆盖力量3、格挡6等独立数值。hpRange 遭遇回归仅为非 AI 敌人放宽至其声明区间，固定 HP 与行动前后 HP 不变检查保留。

验证层级：系统 Lua5.4 全40套件通过，数据校验通过，Python16项通过。完整 npm run check 已尝试但缺少既有 Fengari 依赖，不能冒充正式 CI 或通过；没有安装依赖、访问用户 Codex、平台编译、导入或实机。当前 SHA 的正式 runner 验证与独立复审由交付流程另行核对。



兼容性复验：上述旧数据红测和9种变异为原 PR86 历史证据。当前集成候选重新执行全部离线测试，结果以交付报告为准；不把历史40套件计数冒充当前 PR91 组合结果。
