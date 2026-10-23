# TASK-15：祈火徒运行时仪式接线

日期2026-10-23，基线`7d809f3`。承接已合并的[隔离候选与固定来源账本](TASK-15-cultist-ai-candidate.md)。本切片实现实际Combat/Run可达行为，不宣称整个遭遇池或原版随机已经完成。

## 来源与确定预期

本轮重新读取固定镜像`purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`的[Cultist](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/Cultist.java)、[RitualPower](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/RitualPower.java)、[GameActionManager](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java)与[MonsterGroup](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/MonsterGroup.java)方法体。web读取器失败后通过只读HTTP取得原文件，未运行、复制或提交原程序。

镜像版本字段自称V2.3.4/2022-12-18，真实性未与正版PC二进制核验。此限制与候选账本一致，不能把资料读取写成原作观察。

- A0生命48–54，攻击基础6，首动仅施加仪式3，此后一直攻击。
- 敌方仪式跳过施加当轮，之后每个整组敌方回合结束增加等量力量。所有敌人行动及其轮末效果完成，才处理该增长；死亡敌人不增长。
- 无修正五轮伤害预期为0/6/9/12/15，累计力量为0/3/6/9/12；预期来自方法体推导，并非原作录像。

## 接线与边界

新增`ritual_then_attack`决策，使用真实`gainStatus ritual`意图；`EnemyAI.endRound`由Combat在全部敌人处理完成后调用。首轮标记为扁平布尔字段，沿用已有出牌异常回滚机制。新仪式状态提供中文说明、状态栏与增益图标；图标复用批准主题的力量图标，未新增美术方向。原生控件测试通过真实首战检验仪式意图3→仪式状态3/攻击意图6，玩家生命未受首动伤害。

HP沿用项目现有LCG闭区间采样，验证48与54可达、同种子可重复；这不是原作RandomXS128、种子映射、独立流或抽样顺序验收。仪式当前仅接入已纳入的敌方祈火徒，未声称支持玩家仪式能力。现有其他状态的全局轮末次序仍归TASK16.1。

原反馈/药水测试中人为替换意图的fixture显式关闭该敌人的AI并重置索引，使测试继续隔离其原有目标。真实Cultist行为由独立数值轨迹与原生首战UI测试覆盖；未通过隐藏生产AI来修改验收。

## 验证记录

实现前新测试实际失败：首动期望buff，现有代码返回attack。实现后运行时9组通过：首动、五轮轨迹、队友时序、多实例、毒致死、荆棘致死、弱易伤/格挡、HP端点和异常回滚。另有严格schema拒绝用例，保留睡眠AI校验；完整检查结果以本分支最终日志和当前SHA Quality为准。

未执行本切片的平台编译、存档副本导出、官方导入或游戏试玩。TASK15全池与平台AC全部保留未勾。
