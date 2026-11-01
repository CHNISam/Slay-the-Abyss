# 四职业92张牌历史检查点

本页保留`sts-ui`冻结版本的历史说明。后续107/165张阶段及最新缺口见[当前集成记录](CARD_TRIGGER_INTEGRATION.md)，不能将本页的完整检查结果套用于新源码。

当前工作树：`/workspace/sts-ui`，分支 `feat/experimental-class-ui`，基于远端develop `877c4af3233b42119bbef7ffa57723d0f241bd84`。本轮用户已授权并行、隔离开发暂免远端认领；协调暂停保持不变，未提交、推送或合入。任务与最新排期保存在 `/workspace/Slay-the-Abyss` 的 Backlog CLI 管理库，责任人 Furinya。

## 实际实现范围

完整源目录为四职业各75张。当前显式实验Profile中，战士37、猎人20、机器人17、观者18，共92张职业牌；另有Shiv/Miracle衍生。**仍缺208张职业牌，不是全部流派交付**。逐SourceID、稀有度和机制依赖见 [完整覆盖账本](CLASS_CARD_COVERAGE.md)。默认发布仍为既有战士30牌，实验Profile只开放已经接入的子集。

| 领域 | 当前已接共享层 | 尚未完成 |
| --- | --- | --- |
| 战士 | 七张原待启用牌：Clash、True Grit、Warcry、Metallicize、Demon Form、Whirlwind、Reaper；X费快照、多目标NORMAL矩阵、实际HP损失治疗、暂停选牌 | Corruption费用生命周期、FNP/DE/哨卫与通用消耗入口；其余38张职业牌 |
| 猎人 | 独立开局、手动弃牌/战术大师/本能、毒雾/催化剂/弹跳药瓶、精准修改四堆既有及新生飞刃 | 无限刀刃模块与先天尚未接共享回合/开局，未进Profile；其他弃牌/小刀/防御收益及其余55张职业牌 |
| 机器人 | 四种球、独立卡牌RNG、集中正负/零、偏差、球位增减、Consume/Reprogram | Loop/Electrodynamics等球能力及其余58张职业牌 |
| 观者 | 姿态与能量队尾、猛虎下山/心灵堡垒、占卜/涅槃、真言/神格/供奉三牌 | 其他生成牌/保留/无限循环与其余57张职业牌 |
| 共享与显示 | 数据动作队列、当前选择阶段原引用回滚、跨战斗代次拒绝、职业菜单、弃牌/占卜/消耗/置顶、中文卡牌/状态、球序与姿态详情、故障后不可交互诊断 | 完整原版能力/遗物动作管理器；选牌期间药水延迟队列；原生导入/参数与同候选手机、电脑实测 |

无限刀刃、先天及通用消耗组件的定向测试与来源已经保存，但它们的模块通过不能当作对应新牌已经入池。尤其腐化的费用持久修改、UseCard构造时捕获消耗，以及回合末随机消耗顺序仍待共享层实现。

## 开发入口与验证边界

```lua
local run = Run.new(data, '1', {experimental=true, character='silent'})
assert(Run.startRoomCombat(run, 'normal'))
```

character还可为ironclad/defect/watcher。职业开局保留原版初始牌组、生命、能量和遗物。普通奖励/商店仍是实现子集；完整源池顺序、稀有度概率和随机轨迹没有完成，不能当作原版seed黄金轨迹。

实验界面布局可单独导出：

```sh
node scripts/build-ui.mjs /tmp/sts-experimental-ui --experimental-characters
```

GameUI宿主需显式`platform.experimentalCharacters=true`；`abyss_ui`只读取显式布尔脚本参数，不自行启用。**原生candidateScriptFiles尚未注册该实验参数**，普通native构建不会因此开放职业。后续必须为实验候选登记参数、读回两处原生记录并核对布局与同源模块；不能将当前导出JSON称为平台验收。

沿用已批准主题、四态按钮和安全区。点击角色可看当前姿态/球位与有序球的被动、唤起值，数字来自核心只读视图。演出帧复制球状态，避免显示未来结果。新增状态图标及中文名称、说明已有真实打牌渲染测试。选牌规则与输入保护见 [选择界面](../testing/CLASS_CHOICES.md)。

猎人自然构筑用当前子集seed1连续四战，正常领取毒雾、弹跳药瓶、毒液、匕首牌，12张永久卡组到16张、70生命到63；毒雾/药瓶/毒液实际打出。机器人seed1连续四战，领取Cold Snap、两张Defragment、Coolheaded，75生命到32；集中冰球格挡与跨战重建验证通过。两者只在房间入口harness中逐层推进，不是地图导航或原版掉落概率证明。

## 检查点与结果

- `/workspace/sts-integration`：较早基础冻结版，完整check通过；JS1347、Lua228顶层文件、Python22。其结论只属于该树，不能代替本树。
- `/workspace/sts-next`：后续机制冻结版，完整check运行到所有Lua；JS1347通过，Lua中两处旧门禁测试失败，Python未继续。失败原因是heal意外进入通用卡牌ABI，记录保留在`build/archetype-full-check.log`。
- `/workspace/sts-ui`：已将治疗限制回Reaper内部队列；不修改原门禁测试，Nodes21、post-combat35、Warrior35均重新通过。新增界面选择、状态显示和故障回归定向通过；当前正在串行完整`npm run check`，原始日志`build/class-ui-full-check.log`，输入SHA256清单`build/class-ui-code-hashes.json`。未结束前不能称全量通过。

所有来源固定为aeubanks/sts社区镜像`319009d5`所声明V2.3.4，逐模块保存原文件哈希。按行为事实独立实现，不复制方法体；这不是正版二进制认证。无本轮官方客户端、候选导入或实机证据。
