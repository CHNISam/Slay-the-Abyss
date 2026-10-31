# M3 道具与随机消费接续验收（2026-10-31）

范围：岩系旅行者、`competition-two-act`；其余职业 full-source 内容未删改。执行基线 `1a38b912`。本片只增加现有消费者之间缺少的组合合同，没有修改玩法、概率、完整来源池或时限。

## 已有证据与本轮差集

当前已有完整33药水的独立源码采样 oracle 与真实奖励/商店入口：`tests/sts1-potion-random.test.mjs`、`tests/potion-production-channels.test.mjs`；不是只做了旧 `potion_reward_effects.lua` 的6瓶。完整130遗物定义/公开获得、11个复杂选择出口分别已有 `tests/lua/relic_catalog_completeness.lua`、`tests/lua/two_act_selection_relics.lua`、`tests/lua/two_act_selection_pending.lua`。153运行定义包括特殊/事件/其他职业遗物，不等于153件都属于旅行者普通奖励池。逐钩子依据继续见 `docs/rules/RELIC_POOL_COMPLETION.md` 及该文件链接的分类账本；本轮没有推翻已交付效果，也没有把“有定义”当成全效果已验。

已有全来源随机向量按 sampler/adapter 分别覆盖。新增的差集是同一 Run 经过多个真实消费与提交边界之后，是否仍逐步符合独立源码流：

1. 正常商店完整3瓶生成；
2. 持有信使、满槽购买全状态原子拒绝；腾槽后同一商店实际购买并补货一次；
3. 普通战准备奖励，核对瓶身份、完整XS128 words/counter和概率修正；
4. 下一场使用熵之酿，核对有限采样的3次生成、持续随机流提交；只读预览不得抽样；
5. 烟雾弹逃离不发奖励、不额外消费该流；
6. 下一商店继续消费同一流；
7. 精英战奖励继续该流及原概率修正。

每步与 `tools/oracles/sts1_potion_channel_chain.py` 组合已有独立 `sts1_potion_pool.py` 的固定来源预期比对。身份映射复用先前独立冻结的 `sts1-potion-production-channels.json`；没有从生产采样器计算预期。源仍为固定反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不声称正版PC二进制认证。

所有战斗终局敌人HP与商店位置是明确受控输入；取得信使、测试金币和起始熵之酿/烟雾弹是fixture setup。购买、补货、库存、战斗开局、用瓶、奖励准备和离开均走生产公开入口。没有自然路线、物理操作或设备结论。

## 本轮结果

- `npm run build:data`、`npm run build:ui`、`node scripts/map-ui-layout.mjs` 完成。
- 标准 `node --test --test-concurrency=1 tests/potion-channel-chain.test.mjs`：正向种子0/42/-1共3条链通过，原30秒每fixture预算不变，单链17.1/15.3/10.8秒。
- 新增精确负变异：在临时模块中仅把熵之酿提交的持续potion owner换回旧owner；链必须在完整状态比对处失败。`--test-name-pattern='lost Entropic'` 通过。源码及全仓配置均未变异。
- `npm run check:syntax`、`npm run validate:data`、Python编译与独立oracle重新生成逐字节比较通过。没有重复全量npm test。
- 初版新fixture误把生成瓶的简化descriptor当作含sourceId的商店descriptor；已修正验收按冻结身份映射比对。它是测试夹具错误，不能记作生产缺陷红绿。
- 现有 `tests/potion-production-channels.test.mjs` 本轮标准runner：13项中7通过（独立oracle及全部33商店来源），6组起始牌实战均在30秒预算超时；并发多个agent运行Fengari时发生。原输入、断言和预算未改，交主控低并发复验，不能把本次写成全部33实战通过，也不能以历史EPERM解释。原始结果位于 `/workspace/cloud-reports/m3-complete-rules-production-channels.log`。

## 当前AC可以支持的结论

| 当前条款 | 本轮支持与边界 |
|---|---|
| TASK-14.1 #5 | 已有130定义和逐分类效果账本保留；本片未发现必须修复的生产差异，不凭新连续链声称所有效果逐件新验。 |
| #6 | 全部33商店实际购买/失败不重抽本轮通过；33起始牌奖励链低并发复验待主控完成。现有完整采样器、概率均保留。 |
| #7 | 新增跨房间消费/原子拒绝/Entropic/逃离组合已验；其余逐瓶、遗物组合沿用各自现有专项证据，不外推未测组合。 |
| #8 | 同候选自然取得、官方平台日志/截图本片未执行，保持未验。 |
| #9 | 普通/Boss完整定义及11复杂选择已有可执行证据入口；本片无新增自然/实机证据。 |
| #10 | 新链实际满槽购买拒绝完整Run不变、合法购买只补货一次；提示/UI条款归对应实现域。 |
| TASK-16.1 #5 | 新增共享库存/商店/战斗/奖励跨域结果和提交边界；完整数值/效果证明以现有各专项为准。 |
| #6 | 新增同源potion流初始化、拒绝、全消费与持久提交组合；card/merchant流在Entropic不被串用。全部随机流及实际游戏记录不能仅凭本片关闭。 |

平台编译、副本导出、官方导入、同候选实机、正版PC与手机均没有本轮新证据；由主控合并候选和平台验收统一处理。
