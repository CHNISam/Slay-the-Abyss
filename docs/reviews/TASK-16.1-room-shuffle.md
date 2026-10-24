# 正式战斗洗牌接入独立随机流

2026-10-25，TASK-16.1，基线 `52a691c0d89c4dcc24f79039cfe727dcf235287e`。本片只改正式战斗初始化/弃牌重洗牌的随机消费和失败出牌回滚；保留显式 ID 旧夹具的 legacy LCG 路径。未改 Run、Nodes、地图、奖励、UI、卡牌数值或支持池。

## 固定来源与准确契约

来源为固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是正版 PC 可执行构建认证或本轮原作观察。原字节只放忽略的 `.artifacts/shuffle-source/`，没有复制游戏方法体、文案或素材进交付。完整 URL、SHA256、计算所得 Git blob 身份见[机器记录](../rules/evidence/sts1-combat-shuffle.json)。Java48/Collections 的独立原语及既有官方来源边界继续沿用 `abyss_sts_random` 与 `tests/event-random.test.mjs`。

| 来源章节 | 本片采用的机械事实 |
| --- | --- |
| [CardGroup:544–550](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L544) | 每次 shuffle 只从给定 STS RNG 消费一个 randomLong，以其种子建立 Java48 RNG，再执行 Collections.shuffle；空/单张也消费该一次调用。 |
| [CardGroup:911–940](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L911)；[复制构造与堆顶](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L438) | masterDeck 按数组序复制、洗牌，普通牌按该序 addToTop=append；getTopCard 取尾，所以抽出序为洗后数组逆序，存储本身不再 reverse。初始牌/已支持30卡没有 Innate 或瓶装置顶条件。 |
| [AbstractPlayer:1546–1584](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1546) | 全敌人 init 后初始化牌堆，再 preBattle，之后开场遗物和正常起手；本片保留该现有顺序。 |
| [DrawCardAction.update](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java#L64) | NoDraw、非正数量、两堆全空、满手先返回；手牌容量先裁请求。请求大于旧 draw 大小时依序执行旧堆抽牌、EmptyDeckShuffleAction、余量 DrawCardAction。不能按 draw+discard 总量提前截断请求。 |
| [EmptyDeckShuffleAction.update](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/EmptyDeckShuffleAction.java#L40)、[Soul.shuffle](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/Soul.java#L91) | 弃牌先 shuffle，按头到尾搬至 draw 的尾；再从 draw 尾抽取。旧 draw 有牌但过量请求且 discard 空时仍洗空堆、消费 randomLong；全空入口则不消费。 |

正式 `state.shuffleRng` 来自 runtime 提供的按 raw signed64+floor 重建状态。Combat 继续克隆调用者状态；只推进该对象，不推进 HP、AI、misc、cardRandom 或 legacy seed。连续重洗牌延续同房状态；新房按既有 Run 接口另建，未改流初始化。

## 生产变化与可执行防线

`abyss_combat` 的 shuffle 以存在 `state.shuffleRng` 选择正式原语；显式历史夹具仍走原 LCG。正式 Draw 依源动作拆分顺序同步结算，正确保留过量请求中的空洗牌，不扩展未支持的 draw/shuffle 钩子或完整 actionManager。

第一轮真实红：新 Node 4 项中身份自检过、三个行为项失败，原因是旧实现不推进 shuffleRng（counter0/双 words 保持原状）。接入后35初始牌序和63重抽向量通过。接着新增出牌失败注入实际检出：牌堆回滚而 shuffleRng 的 counter/primitive 已前进；在现有 savePlayState 仅增加两个原表快照后修复，原 RNG、primitive、两 word 和牌堆对象引用均恢复。失败后同张牌可正常重试，且只推进一次。

新独立 Python oracle 不读生产 JSON、不导入 Lua、也不调用生产实现；精确整数解释 XS128→nextLong→Java48→Collections 和上述牌堆动作顺序。`python tools/oracles/sts1_combat_shuffle.py` 可重新生成固定向量，Node 门禁核生成器规范LF文本的 SHA256，兼容Windows工作树自动换行。7组 raw seed/floor 包含 room seed0、超16位、精度大整数、signed64两端溢出；初始牌组0/1/2/10/15张及重抽空堆、单张、旧堆先抽、过量、满手、最后一手牌容量、NoDraw、零数量均逐次比对牌序/双words/counter/每次randomLong。

6个新增 Lua 组还核初始化顺序、同房续流、不污染其他流、失败出牌原对象恢复、失败新房原子拒绝及 legacy 边界。legacy seed42 的原52a691c Combat 执行结果为 seed13745、手牌UID `2,9,8,7,4`；新增断言首次录入错误已用未改基线直接执行纠正，不改生产来迎合错误断言。

六个隔离负变异全部检出：跳过空/单张随机消费、改用 cardRandomRng、反转洗后数组、跳过旧 draw 先抽、洗牌前反转 discard、删除嵌套 RNG 回滚。变异只在 `.artifacts/shuffle-mutations/` 副本，生产源没有为变异改写。

原 runtime 的126构造向量原本排除洗牌，且空deck断言counter=0；经主线程批准，只将此断言迁为准确的空初始化counter=1，HP/AI/misc/构造轨迹断言不变，126向量继续通过。

## 实际验证与剩余边界

- `node --test tests/combat-shuffle.test.mjs tests/event-random.test.mjs tests/encounter-runtime.test.mjs`：8项全部通过，含98个新固定向量、6个新Lua组、126既有构造向量和实际Nodes事务。
- `combat.lua` 23、`atomic_play.lua`14、`draw_lock.lua`15、`artifact_no_draw.lua`6、`opening_relic_order.lua`20、`card_pool.lua`93：171组通过。
- 六个隔离负变异全部检出；`git diff --check`通过。
- 新树首次默认Node执行因沙箱spawn EPERM未跑；正常审批后基线及正式Node测试通过，没有改runner或绕过门禁。

没有运行完整 check、GUI、MCP、平台编译、写存档副本、官方导入或千星实机；没有 push/merge，不勾 TASK-16.1 父任务AC。cardRandom消费者、战后选牌/金币/遗物、完整共享钩子和整局同seed PC轨迹仍未完成。原本依赖旧正式起手/16位seed的自然路线必须由主线程用新组合重跑，不机械改golden制造一致。
