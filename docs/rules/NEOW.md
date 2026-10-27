# 高塔开局恩赐

依据固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 `NeowEvent.miniBlessing/blessing`、`NeowReward.getRewardOptions/activate/update/getRewardCards/getColorlessRewardCards`，沿 `AbstractDungeon`、`CardGroup`、`CardLibrary`、`PotionHelper`、永久获得效果、生命和遗物方法核对。十五份方法文件的实际 Git blob、字节 SHA256 和长度见 `tests/fixtures/neow-source-contract.json`。只独立实现行为，不分发第三方源码和素材；这些证据不等于认证 PC 二进制运行或平台实玩。

新增 `abyss_neow`，保留19种奖励和4种代价。此前正式游戏没有 Neow 执行器。完整恩赐使用独立 `NeowEvent.rng(seed)`，按类别0、类别1、类别2代价、类别2奖励、类别3的源顺序生成四项，单项 Boss 类别也消耗一次整数调用，共五次。类别2的排除仅为原版的诅咒/删二、失金/250金、降上限/双倍生命互斥，不按本地可实现内容删池。

没有前一局完整恩赐资格时保留前三战敌人1生命和增加10%最大生命两项，且不创建或消耗 Neow 随机流。上游字段虽然叫 `bossCount`，实际读取角色 `<chosenClass>_SPIRITS`：`DeathScreen` 和 `ConfirmPopup.abandonRunFromMainMenu` 按上一局的真实楼层是否至少16，覆盖为1或0；`VictoryScreen` 覆盖为1。这不是历史击杀Boss累计，也不是达到一次就永久解锁；到16层后输给首领仍有资格，下一局早死则重新变0。模块要求调用者明确提供这个真实角色历史；未知返回 `neow_history_unavailable`。测试显式给定的历史只用于验证分支，不代表自然解锁，模块不实现或伪造跨局持久化。同session可在真实结局/主动结束时记录该角色本次结果，不能从首次加载默认0声称已经读取历史。

代价先于即时奖励。10%生命先按 Java binary32 运算截断，20%奖励是这个已截断值的两倍；百分比伤害按整数 `currentHealth / 10 * 3`。卡牌奖励不使用战后稀有度偏移或升级概率。普通三选一和强制稀有三选一都先消耗每张牌的 `.33f` 稀有度掷点，强制稀有再覆盖结果；职业牌身份来自 Neow 流，无色牌身份来自全局 cardRng。合法重复拒绝保留源规则和额外随机调用，不因缺定义重抽。诅咒在即时奖励设置后从 `CardLibrary.getCurse()` 的源库顺序消费 cardRng。三瓶药水使用完整职业池均匀抽样与独立 potionRng，分别领取/放弃，不替换成稀有度拒绝抽样。

删牌、升级、变换使用原永久实体 UID 和获取/移除钩子。两张牌可以逐次选定，第一次只记录选择，不移除；第二次验证全部身份后，依源序先移除两张，再进行两次变换和获得。单张变换先选定替代，再移除、获得。新诅咒不会混入激活时已经打开的可选组。瓶装牌可升级，不能用于清除和变换。共享 Run/Nodes 事务负责失败时连代价、已选 UID、全部随机流和永久库存一并回滚；不重抽恩赐。

正式入口接口：`prepare(run,event,{bossCount=<真实历史>})` 建立欢迎页；`choose(...,'continue')` 显示原奖励。奖励命令为 `reward_1..4`；永久牌为 `select,uid`；奖励卡为 `claim_1..3/skip`；药水为 `potion_1..3/skip`；最后 `leave` 返回 `complete`。`options/view` 供现有节点组件使用，选择列表为分离的副本。主session负责在正常选角/开局后接 `beginNeow`、正式 NodeUI 选牌器和 Lament 数据/战斗钩子，不改变既有直接 `Run.new` 测试及重建入口。

已验证：128份独立 Python 整数 oracle 的19种候选/4代价及完整 Neow 流状态；mini顺序和无随机消耗；缺历史拒绝；金币/生命/诅咒、职业与无色三选一、随机稀有、瓶装/升级、双删和单双变换、三瓶独立领奖、全部状态故障回滚。每份夹具沿用30秒预算。来源目录、模块执行不替代正式入口验收；真实跨局历史、客户端、同候选四职业自然开局及正式音画仍须另外留证。
