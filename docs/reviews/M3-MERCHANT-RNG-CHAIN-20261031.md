# Merchant RNG 完整普通商店消费链

能力：`TEST_ADDED`。基线 `b4f88a1f574b403f4cc68d54ee37565f3012b5ad`，独立分支 `feat/m3-merchant-proof`。本补丁不改生产、平衡、原池或旧 golden。对应 TASK-13.1 #5 的货架/折扣/补货离线随机证明，以及 TASK-16.1 #6 的一个完整 owner 消费交点；不因此关闭含其他来源、全部交互或平台记录的整个 AC。

## 来源和独立期望

镜像固定为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。逐文件 URL、Git blob、SHA-256、字节数在 `tests/fixtures/sts1-merchant-sources.json`；只记录收据，未把反编译 Java 复制进项目。实际读取 Merchant、ShopRoom、ShopScreen、StoreRelic、StorePotion、AbstractDungeon、CardGroup、Random、AbstractCard/Relic/Potion 及折扣遗物方法体。

独立 Python `tools/oracles/sts1_merchant_chain.py` 不读取生产 Lua 或运行目录定义：

- 重用既有独立 Python XS128 `sts1_potion_pool.Stream` 和独立完整33瓶源序；float 用原始高24位，binary32 运算由 Python struct 的 IEEE754 单精度取整实现，未调用生产价格函数。
- 卡身份来自既有独立原版注册/HashMap/排序解释 `data/reference/sts1-card-pools/{pools,registration}.json`；类型池、无色稀有度池和相邻重复重选依据 Merchant/CardGroup。seed0 初始实际发生重复重选，cardRng 共14次而非通常12次。
- 遗物初始队列来自 `tests/fixtures/sts1-relic-pool-vectors.json` 的 seed0，以及 `tests/fixtures/economy-relic-seeds.json` 的会员卡 seed2 原 host-Java shuffle 向量；测试用正常 `Pool.new(seed,sourceCatalog)` 生成后逐项核对，未编辑/过滤生产队列。资格事实来自独立原版遗物来源账本，而不是生产 canSpawn 函数。
- 所有生成器/输入 raw SHA 写入 fixture；路径固定 POSIX；`.gitattributes` 对全部认证输入和生成器强制 LF，包含共享 Python 模型，不依赖 Windows 默认 autocrlf。

这仍是固定源镜像/OpenJDK8 库遍历的解释，不是官方 PC 二进制或其全局 MathUtils 历史认证。未把另一个镜像或旧候选的字节视作相同。

## 逐调用账本

A0、非 Daily、旅行者普通商店。原版 Merchant 先生成身份、ShopScreen 再定价；生产中独立 owner 调用可交错。本证据逐 owner 比较完整调用次序和状态，不虚构不同 owner 之间必须同一全局排序。

| merchant 调用 | 消费者 | 参数/作用 |
| --- | --- | --- |
| 1–7 | 5职业+2无色卡价 | floatBetween(0.9F,1.1F) |
| 8 | 特价槽 | int(0,4)，仅5职业槽 |
| 9 / 10 | 遗物1 | int(0,99)稀有度 / floatBetween(0.95F,1.05F) |
| 11 / 12 | 遗物2 | 同上 |
| 13 | 商店专属遗物3 | 仅价格 float；不多抽稀有度 |
| 14–16 | 三瓶药水价格 | floatBetween(0.95F,1.05F)；身份属独立 potionRng |
| 17 | Courier职业牌补货价格 | 身份用受控外部 MathUtils，稀有度用 cardRng |
| 18 / 19 | Courier无色牌补货 | float()决定稀有度 / floatBetween价格；身份属 cardRng |
| 20 | Courier药水补货价 | 身份属 potionRng |
| 21 / 22 | Courier遗物补货 | int稀有度 / floatBetween价格；身份取共享遗物队列尾 |

四个完整案例：seed0无折扣普通店、seed1持Courier、seed-1持Courier+Membership，以及seed42实际购买会员卡。后两条从初始货架连续执行四类补货，包含无色 rare（float=0.2933051586）与 uncommon（float=0.9243305922）两分支。每次每个 owner 的 kind、上下界、value、前后两words/counter全部来自独立向量，另比较每阶段完整7/3/3货架的来源身份/稀有度/价格/特价、遗物剩余队列和独立外部身份流 words。

seed42从真实初始商店第三遗物槽买到会员卡，先支付原价，再对整架现有报价半价取整，merchant/card/potion及外部流均零新消费；按折后价继续真实购买，并拒绝会员卡重复请求。

价差顺序按原方法：初始卡价浮点抖动后截断，无色先乘1.2F，特价整数除2；Courier和Membership逐次 round。补货卡保持 float 依次乘折扣直到最终截断；遗物/药水先 round 抖动价再逐次 round 折扣。没有合并折扣或把 float 采样替换为整数价格均匀抽样。

Courier 的四个禁止补货遗物在这个固定普通 ShopRoom 中已由原 canSpawn 的 excludeRoom=shop 排除；若落到这些候选，资格过滤消费队列项，不另耗 merchant 稀有度。本片不声称实际抽到了全部四个被排除候选。没有为覆盖表面 while 分支而篡改资格或伪称它在此上下文自然可达。队列耗尽回退未在这四条有限链中触发，复用原队列专项的独立回退证据，不以此片替代它。

## 公开事务与拒绝

使用实际公开 `Nodes.enter`、`Nodes.buyCardSlot/buyPotion/buyRelic`（项目购物公开接口，内部真实 Run.transaction/obtainCard/Potion/Relic）。不直接调用 Shop.afterPurchase 当作公开购买。前置仅控制资金、通过公开 obtain 持有折扣遗物、独立 relic seed0或2、外部 MathUtils seed6和导航：在真实生成地图上只选可达商店路线，跳过沿路战斗。不是自然取得，也不声称三种 owner seed 是单一自然同局轨迹。

核实际付款、永久牌组新增、库存增加；read-only view不改全Run。资金不足、非法槽、普通店售罄重复、已获得遗物旧ID重复均原子拒绝。Courier刷新后的同槽是新商品，不能把再次合法购买误称旧请求拒绝。

两个Courier案例各在已付款/暂存获牌之后，让真实补货价格调用抽数再抛异常：明确观察到一个私有merchant draw和一个card稀有度draw，然后核全Run/外部owner完全回滚，再合法重做并继续原向量。只丢弃测试观察器记录的失败私有尝试，不把它们当已提交公共调用；公共状态和下一合法值严格核准。入店会按原版重置房间misc；以开店完成后为基点，购物中的event/misc/treasure及遗物shuffle RNG保持不变，shop不修改card rarity offset。

精准负控在临时模块只删除 `R.randomInt(rng.merchant,4)` 售卖位消费。原向量必须以 `initial merchant exact draw count` 失败；不是只靠某价格碰巧不同杀死突变。生产文件不改。

## 执行与边界

5个薄JS入口，每个文件各自承载一个公开链或meta/负控，使用原Lua默认30秒，未新增/伪造Windows权重：

- `tests/merchant-chain-ordinary.test.mjs`
- `tests/merchant-chain-courier.test.mjs`
- `tests/merchant-chain-discounts.test.mjs`
- `tests/merchant-chain-membership.test.mjs`
- `tests/merchant-chain-meta.test.mjs`

命令：`node --test --test-concurrency=1 tests/merchant-chain-*.test.mjs`。逐文件实际进程耗时/日志在 `/workspace/cloud-reports/m3-merchant-proof/file-results.json`。生成器 `--check`、JS语法、Lua lint及diff检查另行记录。

未新增自然购物、官方导入/ready、PC/手机/手柄、真实全局视觉熵证据；不覆盖Daily/A16+/其他职业/无限模式或每个商店获得钩子的组合。既有价格向量、遗物/药水队列测试及冻结PR437不变。merchant这一普通商店消费者链的完整逐调用证明不能外推为所有随机owner全部消费者完成。
