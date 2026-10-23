# 石颚兽行动选择器：离线候选

2026-10-23。TASK-15 继续归 @Codex，状态及全部验收项不变。本切片只有独立选择器、独立测试和本说明；不接生产 EnemyAI，不改敌人数据、HP、伤害、schema、地图或随机流。PR86 已修复的动作内容与生命范围不重复实现。

## 固定来源与边界

只读核对两份反编译镜像的 JawWorm.getMove：
- [aeubanks/sts@319009d](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/JawWorm.java)，blob `033b26ba08b7dea04d2cff62cd50da868ff887b9`。
- [ButterflyGame@fc379c8](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/JawWorm.java)，blob `b42fa54e26d092f6026f801ea85d11ed10f3f198`。
- [AbstractMonster](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)：rollMove 总会先抽 random(99)，包括强制首动；setMove 当即记录已选动作；lastTwoMoves 要求最后两项都相同。
- [Random](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java)：random(99) 返回闭区间0–99，randomBoolean(chance) 比较 nextFloat() < chance。

镜像一致不是官方PC二进制认证，也不证明两份来源独立。未执行上游程序、复制其实现或素材。仅覆盖普通首幕行动选择；hardMode 开局增益、升阶数值、死亡队列与平台展示不在范围内。

## 准确策略

动作编号1＝Chomp，2＝Bellow，3＝Thrash。普通首动必选1。后续：
- roll 0–24：选1；若上一动作是1，则条件布尔真选2、假选3，概率参数为 .5625f。
- roll 25–54：选3；若最后两个动作都是3，则条件布尔真选1、假选2，参数为 .357f。
- roll 55–99：选2；若上一动作是2，则条件布尔真选1、假选3，参数为 .416f。

三个 Java binary32 参数用已有 Python 标准库 struct 和 Node Math.fround 独立核对，候选以精确十进制表示：
- .5625f：`0x3f100000`，0.5625。
- .357f：`0x3eb6c8b4`，0.35699999332427978515625。
- .416f：`0x3ed4fdf4`，0.41600000858306884765625。

不将 .357f/.416f 改成近似分数、普通双精度 .357/.416 或LCG整数阈值。

## 调用契约

`tools/candidates/jaw_worm_policy.lua` 的 select(firstMove, history, roll, choice) 不持有状态、不抽随机、不修改输入。history 是按旧到新排列的最后0–2个已选择动作，仅接受无元表、连续整数索引的普通表；firstMove 必须为布尔，roll 必须是0–99整数。测试允许构造不可达历史以穷举函数边界，不代表这些轨迹合法。

无条件分支返回 `{kind='action', action=编号}`。需要条件布尔而 choice 省略时，返回 `{kind='choice', chance=精确参数}`，没有选定动作。调用者取到严格布尔后以相同输入重试；真假均有效，数字/字符串不代替布尔。无须条件抽样的分支若额外传入布尔则拒绝，避免隐藏多抽一次的错误。每次返回独立表；非法输入在产生结果前拒绝，输入保持原样。

调用者将来负责首动也先取得主roll、仅按请求取得条件布尔、选定后更新实例历史；本候选无法证明调用者实际进行了这些抽样。现有 RandomXS128 原语可供后续接线研究，但这里未接入，也没有认证原版seed、独立aiRng流、消耗顺序或分布。生产仍是旧固定循环。

## 验证与未完成项

固定预期表覆盖13种长度0–2历史×全部100个roll：1300次强制首动、1300次后续选择请求，其中310次条件请求，620次真假结果；另有4000步连招限制、非法输入原子拒绝、返回值/实例隔离检查。先观察缺少选择器的红灯，再在系统liblua5.4通过19044条相等断言；18种边界、条件、精度、真假、输入或变异错误全部检出。

与当前develop及PR82–86的已核对组合隔离副本复验：系统Lua45套件通过，数据校验通过，Python16项通过。完整npm run check已尝试：Node501通过、23项因缺少既有Fengari依赖失败；未安装依赖。第一次系统Lua辅助脚本误覆盖battle_ui布局变量，44/45；仅修正本地测试包装后重新全跑45/45，游戏源文和测试未改。

系统Lua结果不等于Fengari/Windows、原版游戏或千星实机证据。当前SHA正式runner结果仍待完成；本候选不完成TASK-15的全AI/概率/平台一致性验收。
