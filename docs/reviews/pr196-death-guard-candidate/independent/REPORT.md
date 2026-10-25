# PR196 反伤死亡 guard 独立复核

## 结论

v2 候选通过本次有限审查，可交原 PR 执行者接续；没有发现阻止该最小修复交接的缺陷。不代表已集成、提交、推送、合并、CI 或平台验收通过。

仅一个生产文件新增 3 行：2 行注释和每次取项前的死亡 guard。最终审查的是 v2，不是产生缺 HP 回调退化的 v1。

- 固定基线：9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf。
- 基线 Actor git blob：4b5124b0d476a1b8a12cb0ddd3c8935771220c1b。
- v2 Actor git blob：3975ba1c2cbd30aac65f6d228ead9a91eb5d82a0。
- v2 Actor SHA256：47902041ef11643e0dde3a5a0c86aa9023e8de13942ae1c46ac7318960a9a992。
- v2 patch SHA256：d300a88081dcc8961a6653f6058b686cda948a26aafeae835da4267fe6c76dea。
- 2026-10-25 01:17:37 UTC 再读 PR196 仍为上述基线，远端 Actor 仍无此 guard。交接者应在实际集成前重核，不对未来 head 作保证。

## 独立证据

审查材料已隔离复制，没有在作者目录内运行或修改生产源码。首先校验 v1 的 105 项冻结清单，再校验 v2 的 150 项清单。基线 Actor 另从固定远端完整读取，与本地基线逐字一致；两个候选与基线的运行源差异均只有 Actor。v1→v2 唯一生产变化是增加 type(state.player.hp) == "number"。

实际复跑：

1. 原 Flame Barrier 致死负例：基线 exit1，玩家 HP0、Guardian HP200、反伤2次；v2 exit0，玩家 HP0、Guardian HP204、反伤1次，Run defeat、无奖励。
2. 原7组反伤/受伤通知组合：基线和v2均7/7。保留末敌先死后 Sharp Hide 仍杀死玩家、判负且无奖励的真实 Run/Guardian 组合。
3. 原6组 guard 边界：基线4过2败，v2 6/6。涵盖入队前已死、上一项致死、死敌来源伤害、nil state、无 player 和空队列。
4. 新写9组重入/清理：基线6过3败，v2 9/9。涵盖内外层致死停止、取项前死亡检查、嵌套 TOP 顺序、真实 Spore Cloud 递归反应、victory 不误删死源伤害、重复死态调用不泄漏锁、回调错误原样传播、真实 Run 死亡清理和 Sharp Hide 致死时保留 cardInUse。
5. 新写缺 HP 回调探针：基线 exit0 回调1次，v1 exit1 回调0次（nil 比较错误），v2 exit0 回调1次。作者新增的等价脚本也独立跑绿，但不把同一覆盖重复计数。

合计 v2 24 个不同定向场景通过，另有1个等价作者回调脚本通过。所有退出码、stdout/stderr 和具体脚本保存在 run-results.json 与 evidence/，旧红证据未覆盖。

v2 的4种真实负控、5次执行均按预期 exit1：删除 guard 重现原致死负例和两处停止失败；无保护 state/player 读取重现 nil/无 player 错误；入口仅检查一次漏掉中途死亡；移除数值类型保护重现缺 HP 错误。负控在独立进程加载隔离 mutation 模块，不改候选。

## 调用契约与清理判断

当前固定运行源只有5处生产调用：Actor 的 retaliate/damage/tick，以及 Effects 的范围伤害和 CardActions 的 Reaper。外部注入回调均为 Combat.retaliate；这些生产路径都持有完整 Combat state，Combat.new 要求正整数起始 HP 并构造数值 player.hp。

没有发现生产路径或明确公开契约要求 player={}。因此 v1 缺 HP 差异最初列作兼容性风险，而非真实战斗阻断；v2 已以最小类型检查恢复旧注入 callback 行为，风险已实际消除。nil/无 player/缺 HP 的认证仅限注入伤害回调分支，不声称真实 Combat 或 status 分支接受任意缺失上下文。

guard 位于每次读取 reactions[i] 之前，不仅在入口或只在 damage 分支检查。嵌套调用导致玩家死亡时，内层和外层都不会继续读取下一项。只检查玩家死亡，不检查来源存活或整体 victory，因此保留已死最后敌人的有效伤害；Sharp Hide 本身没有被改写。

resolveDamageReactions 原来就是逆序遍历本次 batch，不消费输入数组，也没有持久解析锁；v2 保留该接口语义。生产调用的 batch 为本次伤害/效果局部表，停止后没有新增持久待执行队列。真实 Run 终止后的 cardActions、queuedCards、resolvingCard、resolvingEffects、drainingCardActions 和 curlUpQueue 均符合既有清理；再次 drain 没有事件回放。保留 cardInUse 是已验证的死亡时 limbo 语义，不是漏清理。

## 固定规则依据及范围

独立只读核对固定反编译镜像 fc379c875c11e008e9c10548ac8e394c301c532f 的 FlameBarrierPower.onAttacked、DamageAction.update、AbstractPlayer 致死、DeathScreen 和 AbstractRoom 的动作管理器屏幕门禁。它支持区分“玩家死亡停止后续动作”和“死敌来源不取消 THORNS”。来源链接和 blob 见 author-v2-frozen/fixed-source-review.json；没有复制第三方源码正文。

此规则证据是固定反编译镜像，不是原版 PC 二进制实玩。候选只适用于当前 HP<=0 即 defeat 的模型；未认证未实现的复活遗物/药水。

只用了既有 native Lua5.4 共享库运行器。没有安装、full npm、全75泛扫、Windows全量、平台构建/导入/试玩、用户电脑或用户 Codex。没有写 Backlog、原作者生产树、PR 或远端；AGENTS 已读，backlog instructions overview 实际不可运行（CLI不存在），未绕过它写任务。

## 交接入口

- candidate-v2/src/lua/abyss_actor.lua：最终完整候选。
- v2-candidate.patch：最终最小 diff。
- REPRODUCE.md：复跑命令与预期退出码。
- RESULT.json、FROZEN.json：独立结果与内容身份。
- author-frozen/、candidate/：仅保留被替代的 v1 供红证据复核，不能交作最终修复。
