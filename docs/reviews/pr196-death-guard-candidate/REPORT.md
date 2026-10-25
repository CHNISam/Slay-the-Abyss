# 死亡反伤最小候选：只供独立复核与owner接续

基线：PR196 `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`。整个候选仅在本目录candidate/中，未修改上级冻结快照、原作者目录、远端、PR、Backlog或任何任务状态。

## 最小改动

`candidate.patch` 只有一个生产文件、3行新增（2注释+1 guard）。在 `Actor.resolveDamageReactions` 每次取下一项之前检查玩家是否已死亡；存在state/player且HP为数值时才判断死亡。

这区分了两件事：玩家死亡会停止动作管理器；敌方来源死亡本身不取消其已排队THORNS伤害。每一项都检查，而非只在函数入口检查，才能中断由前一项反应造成的玩家死亡。

没有改卡牌数据、排序、TOP方向、伤害公式、HP通知、敌方源存活条件、Sharp Hide逻辑或Run奖励判定；没有额外规则/抽象重构。

## 真实TDD结果

先在未改9a4副本上执行，保存原始红：

- 原始Flame Barrier负例：exit1，期望Guardian204HP/1次反伤，实际200HP/2次。
- 新增6个guard边界：4过2败。两败分别为开始排队反伤时玩家已死、反向TOP第一项致死后仍继续下一项。
- 原7组主范围：7/7通过。

随后只添加最小guard，原始7+1探针仍逐字不改：

- 原始负例转绿，Guardian204HP/1次反伤，Run仍defeat、无奖励。
- 原7组7/7通过，包含末敌死亡后Sharp Hide仍可致死的边界。
- 新6组6/6通过：玩家先死停止；队列中途死亡停止；末敌死源伤害保留；nil state的既有callback分支；无player state的callback分支；nil/无player的空批次。

缺state/player两组只认证现有注入retaliate回调接口，不声称完整Combat支持缺少玩家状态。实际游戏伤害断言使用真实Combat/Actor；回调边界保留原接口参数和逆序派送。

## 真实负控

隔离mutation模块，不改候选：

1. 删除guard：原始Flame Barrier反例重新红，新增边界重新2败。
2. 改为无state/player保护的直接解引用：nil state、无player两组均真实失败，其余四组通过。
3. 只在函数入口检查：队列中途死亡那组真实失败，另外五组通过。

日志、实际退出码与变异sourcehash在negative-controls.json和evidence/。未通过弱化断言、改测试生命值或改敌方行动制造通过。

## 版本与范围

开始与收口时PR196仍为9a4；冻结前另直接读取远端 `feat/warrior75` 的Actor，仍为原blob `4b5124b0d476a1b8a12cb0ddd3c8935771220c1b`，不存在本候选guard。身份观察见remote-check.json；这不是对未来head的保证，交给作者前应再核。

固定规则依据沿用fc379c8的FlameBarrierPower TOP排队、AbstractPlayer致死、DeathScreen/AbstractRoom停止动作管理器链，完整blob和链接在fixed-source-review.json及上级原REPORT。该来源是固定反编译镜像，不是认证PC二进制；不复制第三方源码正文。

本候选只覆盖目前HP<=0即defeat的模型。没有把尚未实现的复活遗物/药水、全遗物/全队列纳入认证。纯native定向15个场景通过；按本次明确限制未运行full npm、全75泛扫、Windows全量或平台。当前CI、合并、官方导入与实机均未由此候选认证。

这不是任务认领、已推送、已合并、已接入作者分支或平台完成。root可用diff与全部原始测试独立复核后交给owner，不应直接覆盖他人工作。root已完成的能力guard16/16没有重做。

## 交付文件

- candidate.patch：生产最小diff。
- candidate/src/lua/abyss_actor.lua：完整候选文件。
- lethal-incoming-probe.lua、reactive-order-probe.lua：原始未改7+1。
- death-guard-boundaries.lua：6个针对guard的边界。
- evidence/：原始红、候选绿和真实负控。
- RESULT.json、candidate-source.json、FROZEN.json：source/probehash、结果与完整冻结清单。
- REPRODUCE.md：可复制执行的有限复跑命令。

## v2：补齐player存在但hp缺失的callback兼容性

独立reviewer发现v1在state={player={}}时新增了nil比较错误。先新增同一未修改probe：9a4基线正常回调1次（exit0），v1候选报attempt to compare nil with number（exit1）；随后只在guard中加type(state.player.hp)=="number"，v2该例exit0。原14场景保持全绿，总计15个场景。额外真实负控移除type检查后再次出现同一错误。

v1的Actor、patch、报告、结果、日志与变异模块保留在history/v1/，不作为当前候选。当前RESULT.json、candidate-source.json和FROZEN.json均指向v2。缺HP仅是已存在的注入回调API兼容性，不声称完整Combat可接受不完整player。
