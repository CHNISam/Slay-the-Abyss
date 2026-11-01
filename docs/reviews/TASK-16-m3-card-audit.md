# 首发30卡固定来源核对

2026-10-24，TASK-16 / TASK-16.1；基线 `ecade28`（生产继承 `6e8714f`）。**费用及基本/升级数值没有发现需要修改的差异；严格一致性仍未通过。** 本片保留两项已复现的顺序/反馈差异，不改生产数据、Combat或Effects。

结构化逐卡账本：[card-ledger.json](../evidence/card-audit-m3/card-ledger.json)。30张各自的构造/use/upgrade来源URL、行段、Git blob及SHA256见[来源身份](../evidence/card-audit-m3/source-identity.json)。本轮30个原字节均重新下载，与固定提交GitHub目录API返回的blob逐个匹配；另核对AbstractCard、Ironclad、EntanglePower和版本声明4件。第三方源码仅保留在本树 `.artifacts/card-audit-source`，不提交或执行。

## 证据边界

固定镜像为 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`。其CardCrawlGame声明V2.3.4/2022-12-18，但**没有正版PC二进制hash或本轮原作观察日期**，不是官方开源或正版构建认证。Strike/Defend/Bash中的调试150伤害/50格挡/全体攻击分支明确不作为正常规则；核对的是非debug分支。没有复制原作代码/图像/音频/长文进交付物。

各牌同名profile与自然获取渠道沿用[首发内容清单](../LAUNCH_CONTENT.md)。所有逐项平台与实机记录仍待补，不因本片通过本地夹具关闭AC。

## 逐卡原版预期

下表是固定镜像的普通分支机械事实，数字顺序按基本/升级列出；不是把项目data重新抄作来源。卡牌目标、消耗/虚无/能力去向与使用条件、具体覆盖文件另在JSON逐项登记。所有卡都还受正常回合、能量、目标和Entangled等共享门槛约束；30张均无卡类自身canUse覆盖，Dropkick的易伤是收益条件，不是可使用前提。

| ID | 费用 基本/升级 | 源目标 | 基本效果 | 升级效果 |
| --- | --- | --- | --- | --- |
| strike | 1/1 | ENEMY | 伤害6 | 伤害9 |
| defend | 1/1 | SELF | 格挡5 | 格挡8 |
| bash | 2/2 | ENEMY | 伤害8 → 易伤2 | 伤害10 → 易伤3 |
| cleave | 1/1 | ALL_ENEMY | 全体伤害8 | 全体伤害11 |
| clothesline | 2/2 | ENEMY | 伤害12 → 虚弱2 | 伤害14 → 虚弱3 |
| iron_wave | 1/1 | ENEMY | 格挡5 → 伤害5 | 格挡7 → 伤害7 |
| anger | 0/0 | ENEMY | 伤害6 → 弃牌堆加入同状态副本 | 伤害8 → 弃牌堆加入升级副本 |
| body_slam | 1/0 | ENEMY | 以当前格挡为基础计算普通伤害 | 效果相同、费用0 |
| flex | 0/0 | SELF | 力量+2 → 回合末移除2 | 力量+4 → 回合末移除4 |
| twin_strike | 1/1 | ENEMY | 5伤害两次 | 7伤害两次 |
| pommel_strike | 1/1 | ENEMY | 伤害9 → 抽1 | 伤害10 → 抽2 |
| shrug_it_off | 1/1 | SELF | 格挡8 → 抽1 | 格挡11 → 抽1 |
| thunderclap | 1/1 | ALL_ENEMY | 全体伤害4 → 全体易伤1 | 全体伤害7 → 全体易伤1 |
| uppercut | 2/2 | ENEMY | 伤害13 → 虚弱1 → 易伤1 | 伤害13 → 虚弱2 → 易伤2 |
| inflame | 1/1 | SELF | 力量+2 | 力量+3 |
| battle_trance | 0/0 | NONE | 抽3 → 本回合禁止抽牌 | 抽4 → 本回合禁止抽牌 |
| bloodletting | 0/0 | SELF | 失去3HP → 能量+2 | 失去3HP → 能量+3 |
| barricade | 3/2 | SELF | 未持有时获得壁垒 | 同效果、费用2 |
| carnage | 2/2 | ENEMY | 伤害20 | 伤害28 |
| disarm | 1/1 | ENEMY | 目标力量-2 | 目标力量-3 |
| dropkick | 1/1 | ENEMY | 伤害5；易伤时能量+1 → 抽1 | 伤害8；易伤时能量+1 → 抽1 |
| entrench | 2/1 | SELF | 当前格挡翻倍 | 同效果、费用1 |
| ghostly_armor | 1/1 | SELF | 格挡10 | 格挡13 |
| hemokinesis | 1/1 | ENEMY | 失去2HP → 伤害15 | 失去2HP → 伤害20 |
| rampage | 1/1 | ENEMY | 伤害8 → 本实例本战伤害+5 | 伤害8 → 本实例本战伤害+8 |
| seeing_red | 1/0 | NONE | 能量+2 | 能量+2，费用0 |
| shockwave | 2/2 | ALL_ENEMY | 逐敌：虚弱3 → 易伤3 | 逐敌：虚弱5 → 易伤5 |
| offering | 0/0 | SELF | 失去6HP → 能量+2 → 抽3 | 失去6HP → 能量+2 → 抽5 |
| impervious | 2/2 | SELF | 格挡30 | 格挡40 |
| bludgeon | 3/3 | ENEMY | 伤害32 | 伤害42 |

Ironclad初始为5 Strike、4 Defend、1 Bash、Burning Blood、80最大生命和99金币；当前数据吻合。能力牌去向、Iron Wave先格挡、Twin Strike逐段、末敌死亡清尾等复用既有专项账本，不重造实现。

## 两项严格差异（尚未修复）

1. **Shockwave双敌顺序。** 输入：种子42，Cultist和Jaw Worm，两者无Artifact，基本/升级各打一次。固定源use循环每敌先Weak后Vulnerable，应为 `Weak(A) → Vulnerable(A) → Weak(B) → Vulnerable(B)`；生产两条applyStatusAll实际为 `Weak(A) → Weak(B) → Vulnerable(A) → Vulnerable(B)`。基础层数3、升级5，最终状态总量相同不能替代事件顺序一致。
2. **重复Barricade。** 输入：同场两张基本Barricade，隔离夹具提供6能量，第一张正常生效后再打第二张。源use检查已有能力后不排ApplyPower；生产多发一个 `player:barricade:0` 状态事件。壁垒仍只有1且留格挡效果正确，反馈多帧仍是差异。

[实际诊断](../evidence/card-audit-m3/sequence-diagnostics.json)三条 `strictExpectedMatch=false`，不包装为通过。脚本 `scripts/diagnose-card-sequences.lua` 可复跑；它是诊断而非放入默认测试的必败断言。后续最小修复由TASK-16/16.1承接，需要独立红绿及共享Effects兼容验证，本片按主代理协调保留，不在组合检查前修改共享协议。

## 本轮本地验证

- `node scripts/build-lua-data.mjs`通过。
- 既有 `card_pool.lua` **93/93通过**，含基本/升级效果及节点获取/升级、27牌原始初始牌组真实胜利奖励覆盖。商店/营地部分含足额金币等隔离设置，不是同一局自然构筑证明。
- 新增 `card_use_requirements.lua` **60/60通过**，30张基本/升级逐一验证目标、恰好能量/少1能量、Entangled只挡攻击，Dropkick无易伤仍可出。它检查正式命令边界，不添加牌或改数值，默认Lua发现入口自动纳入。
- 双敌Shockwave基本/升级及重复Barricade三条诊断明确保持strict fail。

本地153组通过不消除上面三条严格诊断失败。其他专项测试本轮只关联未全部重跑；最终同组合全量check由主代理执行。没有平台编译、写存档、官方导入或千星实机；自然力量/格挡/自损/消耗构筑路径、完整共享钩子/随机流/动画时序仍未补证。TASK-16保持In Progress，AC全部未勾。
