# TASK-8.5：恢复最终格挡999上限

## 规则来源与范围

用户要求复用初代《杀戮尖塔》的有来源规则，不另创平衡数值。两份标注V2.3.4的第三方反编译镜像均在AbstractCreature.addBlock最终写入后把超过999的格挡置为999，适用于玩家和敌人：

- [镜像A，固定提交319009d：AbstractCreature.java 412–438](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L412-L438)
- [镜像B，固定提交462da73：AbstractCreature.java 507–508](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/core/AbstractCreature.java#L507-L508)

这不是MegaCrit官方源码发布，未取得官方JAR认证；两个仓库也不证明独立获取原始构建。只读核对规则，没有复制或执行镜像实现。999不是本项目新设计数值。

## 最小实现

仅Actor.block最终写入取min(999, 原浮点累加结果)。blockAmount不封顶：敏捷、脆弱、最终取整顺序和浮点精度不变；fixed只跳过修饰，不跳过最终状态上限。旧十亿级最终格挡断言是错误契约，改为计算函数保留跨32位结果3221225470，最终状态为999。

主线生产入口：Combat.block直接导出Actor.block；卡牌与敌人意图通过Effects.apply进入Combat.block；药水及遗物通过Inventory.apply的fixed入口进入。没有另一个直接增加格挡的生产写入。其余block写入只有玩家/敌人初始化0、普通伤害和荆棘扣挡、无壁垒时回合开始清0。Inventory既有32位非法/溢出拒绝保留，不改变其它上限。

不修改生产JSON、基础表、伤害逻辑、荆棘修复PR48、平台/UI/导出工具。PR37 deferred候选的multiply_block不在本次范围，由原候选后续衔接。

## 验证

基线develop 1eaba2c75109f0bc1eef50f5f6a349883c333c02，包含PR47与PR48。运行所需现有文件按Git blob核对；非运行美术二进制未获取。

- 红：旧Actor下5组状态测试失败，分别覆盖超大计算最终状态、双方普通/fixed边界、先修饰后封顶、壁垒、实际defend出牌；库存原版block_potion在988+12时得到1000而非999。
- 绿：状态35组，库存11组。defend、jaw_worm防御意图、block_potion使用未改动原数据，通过真实生产API到达同一增挡入口；高格挡和敌人壁垒是明确的单测种子，不声称自然游玩已到999。
- 全套系统Lua5.4：11文件175组通过，已含原子出牌14组，不重复相加。包含PR48的荆棘回归。实际框架生成的控件树用于UI替身测试。
- Python13通过；JS语法、数据验证、build:data、build:ui、build:theme及git diff --check通过。
- 实际npm run check退出1：JS139项132通过，7项因缺fengari-node-cli失败：UTF8往返、六表Lua加载、Lua runner失败/超时、Lua套件发现/失败中止、主题Lua加载、真实game入口、map控制器导航。后续aggregate阶段因此未运行，已单独补跑上述本地检查，不将替代运行说成正式check通过。

未安装依赖，未调用用户电脑/Codex，未推远端。正式Fengari CI、独立评审及集成待父级处理。本任务没有官方导入、真实屏幕或游戏实测通过声明，不改变既有平台证据或关口状态。

独立评审通过：复跑状态35/库存11组及独立1622字段断言全绿；原基线负对照在预期999实1190时失败，三份代码/测试文件hash一致。覆盖双方999格挡受普通攻击/荆棘消耗后再增、fixed、敏捷/脆弱、壁垒/重置及真实卡/意图/药水入口。AC已按本地证据勾选，仍In Progress；正式CI和集成待父级在最新develop b4c552cf保留PR46及其他成果后处理。
