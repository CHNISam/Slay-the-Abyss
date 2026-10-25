# PR201 租约执行安全复现

固定2999bc89837ac78ecba5787f6dc8d3521ab99e04。两条P1：合法短TTL下，续租返回时已过期仍启动child；同步续租阻塞event loop时，已过期child不能及时停止。不是生产事故报告，也没有证明默认1800秒或现有TASK55的14400秒租约发生此问题。

独立worker和root分别离线复现。4个测试通过表示成功证明这两种失效及两个控制，不表示协议通过验收。原作者15项测试也通过，并不覆盖这两个缺口。

只运行 node --test --test-concurrency=1 review-offline.test.mjs。它只读取固定源并在VM中替换网络/Git/claim操作，唯一真child是本目录heartbeat-child.mjs、只写测试marker。scripts/remote-task-claim.mjs仅是固定源副本供读取，不要直接执行安装/迁移/claim。

没有启用迁移、改真实claim/Backlog、创建凭证或操作用户电脑。install涉及持久shared hooks/core.hooksPath，需要另行获准；评审与PR正文不是安装许可。评审：https://github.com/CHNISam/Slay-the-Abyss/pull/201#pullrequestreview-5641291851
