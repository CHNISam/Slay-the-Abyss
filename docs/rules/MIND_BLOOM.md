# 心灵绽放：固定来源与接入边界

依据 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 MindBloom、MarkOfTheBloom 及房间、奖励、获得卡牌方法独立实现。逐文件 SHA256 与已验 ZIP 身份见 `tests/fixtures/mind-bloom-source.json`。Java 原文仅在工作区只读来源包，不加入产品。社区反编译镜像不等于认证原版 PC 二进制。

事件构造不消耗规则随机。选项从上到下为挑战第一幕首领、升级全部可升级牌并获得绽放印记、财富或健康。第三项用当前全局楼层 `floor % 50 <= 40` 判断：成立则先直接获得999金币，再依次尝试获得两张 Normality；否则先调用 `heal(maxHealth)`，再尝试获得一张 Doubt。金币与诅咒获得分别走既有钩子；Ectoplasm 阻止金币不取消诅咒，护符分别阻止每次诅咒且不分配永久 UID。

升级按永久牌组原顺序检查 `canUpgrade`，每个物理对象升级一次，包含瓶装牌和可重复升级的灼热攻击；不移除、重排或重新获得牌。全部升级完成后才获得 SPECIAL 绽放印记。只调用共享 Run 永久升级接口，不另建资格算法。源码中的最多20张升级闪光使用 MathUtils，属于视觉随机，不占用 misc/card/其它规则随机流。MarkOfTheBloom 的 `onPlayerHeal` 始终返回0，既有共享治疗路径须完整接入；本模块不另建治疗系统。

战斗选项仅消费 miscRng 的一次 `randomLong`，用 Java Collections.shuffle 打乱 `The Guardian / Hexaghost / Slime Boss`，取第一个。事件模块生成请求并返回 `event_combat`；共享桥按原顺序构造所选遭遇的 HP、清空并预排50金币、消费 RARE 遗物队首，随后执行开战 AI 与既有开战钩子。RARE 空池为 Circlet；不得缩池、换成普通战斗奖励、延迟到领取时重抽或消费正常章节遭遇队列。

该房间仍为 EventRoom，不是 BossRoom。胜利保留预排金币/稀有遗物，并走事件房间的普通药水概率和一组卡牌奖励；Prayer Wheel 的额外卡牌仅适用于普通 MonsterRoom，不适用于此事件。MindBloom 不覆盖 `reopen`，基类为空，EventRoom 战后完成；没有自动返回事件选择页或新增结果页，因此请求不包含 `returnStage`。

接口为 `prepare(run,event)`、`options(run,event)`、`choose(run,flow,choice,uid)`。共享 Nodes 事务是原子提交责任方。战斗请求字段为 `sourceEncounter / roomClass='event' / gold=50 / relicTier='rare' / metric='Mind Bloom Boss Battle'`。模块不直接创建战斗或抢占战后结算责任。

## 验证与未验证

独立 Python 方法解释只复用已有独立整数 RNG，不读取产品 Lua 或数据；24组种子/已消耗计数向量对照一次 Long、Java48位 shuffle 和完整 miscRng 状态，8个楼层边界对照第三项。受控 Lua 测试覆盖选项顺序、只读视图、Fight 请求与不重入、两次诅咒/护符、Ectoplasm、先治疗后 Doubt、原顺序升级/瓶装/重复升级，以及第二次诅咒或最终遗物失败时的整个事件回滚。

本轮实际先执行 `tests/lua/mind_bloom_event.lua`，得到明确的 `MIND_BLOOM_MISSING` 失败；补模块及 Run 永久升级公共接口后，同一脚本9组全部通过（单次约13秒、未提高30秒预算）。来源合同 JS 1/1通过，三个 Lua 文件的静态语法解析与 `git diff --check` 通过。Run 仅在末尾新增独立永久升级区块，复用既有 Combat 的资格和单次升级，在现有 Run 事务内执行。

这批是独立事件模块测试；共享战斗桥、生产 Mark 注册、所有治疗路径和正式事件入口必须集成后再验。测试中的临时 Mark 数据定义只是隔离依赖，不代表生产已可获得。没有原生候选、官方导入、实机截图、自然整局路线或 UI 验收，不关闭 TASK-62 或 M3。
