# 公开结束回合入口：独立行为验证

基线 `f26aeb30c0995de70cf340af977d3c8579c1a2b5`，完整旧 Combat Git blob `355d40b0e94decec318d9dabc24ca7d2d96c27b8`；固定旧源压缩于 `tests/fixtures/end-turn-admission-before.json`，正常回归不依赖 Git。最终测试绑定源码 SHA256 `84239aa2945d36fdbc0aa46e3ae6cb676bd8d593a915f1c308bd54420327d71f`。实现与复杂度见主附件，本文件只记录测试范围。

固定 Node24.18，十二类边界：

- pendingPotionChoice 第一拒绝：不读取遗物、不建立快照、不消费传入 owner。
- 真正移除 evolve/claw/blur/wallop、空高级状态和基本敌人后，native 与 experimental 两条直达路径不建立快照；成功仅返回一个值。
- catalog 代理完整观察原短路读取次序。首次 advanced=false、第二次=true 时必须进入末尾事务 fallback；首次 evolve 命中则不能再读取 claw/blur/wallop。
- 遗物入口的 nil、false、pause、terminal：普通无遗物、错误阶段、真实 Nilry's Codex 暂停，以及真实 Calendar 在 Codex 前终结。暂停和终局返回单值 true；不把 nil 当 false。
- data-only ownerEndRetain 暂停检查点：pendingChoice 拒绝且图不变；清除该选择后的公开 resume 继续并恢复原选牌对象一次。既有 native/experimental 专项另覆盖真实 Well-Laid Plans 选择续接。
- originalV4 即使 experimentalMechanics=true 也使用 native 协议，Burn 清理仍在敌人之后。
- 快照回调改变 experimentalMechanics 时，resolver 必须在 capture 之后读取该字段；两种协议不同的 turnCost 清理使顺序可被行为断言观察。
- 精确 owner 被消费一次且无需新 capture；错误目标 owner 不能消费、须建立新快照。晚期异常在真实 RNG 消耗、seed、catalog 和别名图变更后，完整恢复原图、事件、费用与对象身份，并保留异常 table 对象。

返回值使用 `table.pack` 核验 `.n`：直达成功一个值、事务成功两个值（第二值 nil）、拒绝 false+reason，以及 pcall 异常二元组均分别验证，不依赖 Lua 的 `#` 判断 nil 槽。

旧/新完整源码分别在独立 VM 运行同一十二场景，最终输出 **2739223 字节**，双方 SHA256 `d05b686fa93c2566ef548a525c262b1597ddd45e611c4015eaa8981ec5967559`。完整图不省略 data/catalog/rules/sourcePools；函数以类型标记表示，owner 的真实身份与单次消费另有显式断言。每 VM 仍用原 30 秒预算，raw 入口只打印十二个摘要。

十二种真实生产错误变异全部由 `[END_ADMISSION]` 行为断言拒绝，覆盖拒绝/暂停、短路/二次读取、owner/回滚、直达与事务 arity、V4 路由和 capture/resolver 读取先后。解析或 runner 错误不算 kill。新专项 2/2 通过、0 skip；原 native/experimental 全图差分和完整职责缺测/超限负例共 18/18 通过。

机器证据：[end-turn-admission-20261104.json](../evidence/end-turn-admission-20261104.json)。重放先 `npm run build:data`，再 `node --test --test-concurrency=1 tests/end-turn-admission.test.mjs`。不冻结合法无关源码 prefix/suffix；完整旧源认证、全图差分及所有行为断言保留。没有官方导入、ready 或设备取证，精确 HEAD Full 与实际合后验收另记。
