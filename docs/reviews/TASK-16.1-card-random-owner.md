# 持久卡牌随机流与稀有度偏移

本切片修复状态所有权，为完整原池抽取接线提供基础，不宣称卡牌奖励身份或原版概率已完成。

## 固定来源与当前实现

基线 `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。规则来自固定镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 AbstractDungeon、AbstractRoom、MonsterRoomElite、MonsterRoomBoss、ShopRoom 与 Exordium。镜像不是正版 PC 二进制认证；独立 oracle 的源 hash 与 Java 对照见配套记录。

- `abyss_card_random` 的 owner 是 `cardRng` 与 `cardRarityOffset`。初始偏移5；普通牌每槽减1，最低-40；稀有牌归5，罕见不变。Shop只读偏移。
- Base normal/elite/shop 的 rare 与 uncommon 阈值分别为3/40、10/50、9/46；先加偏移再比较。Boss也消费一次0..99整数，随后强制rare。
- 非rare升级分支即使第一幕A0概率0也消费float；rare短路不消费。完整奖励调用者必须先完成所有身份/重复抽取，再逐槽升级，不能交错这两轮。
- snapshot/restore/clone保留精确双64位words、signed32 counter与偏移。它们是值状态工具，不是授权回退已消费的Run进度或退出续玩接口。
- Run只持有一份正式 `run.cardRng`。旧 `shopRng.card` 不再创建；商店先在临时 `cardRandom` 上生成库存，成功进房后才交给Run并清除临时字段。
- Courier卡补货先克隆Run的卡流，准备成功并确认付款/授牌后才发布。非卡购买不推进卡流；药水奖励不会初始化第二份卡流。进房准备失败返回 `node_content_unavailable`，不更改地图和Run。

## 已验证范围

定向本地验证：状态/真实商店入口8组、原商店规则及价格/原子性夹具、重复卡牌点击归属15组、致死药水事务4组均通过。先前缺生成主题导致的夹具启动失败保留为准备失败；补运行正常build:UI后相关真实UI夹具通过。没有修改原超时预算。

独立只读复审未发现本切片确认的P1/P2。新增JS适配已让实际Lua核心逐步通过独立oracle：8个signed64种子、76个动作、228次原语与148次稀有度/偏移；同时核words、signed32 counter、offset、原始64位输出、float样本、拒绝采样及clone/restore。Python再生成精确匹配，来源oracle另以Java17复核。这里仍明确省略卡牌身份消费，不能声称完整getRewardCards或商店轨迹。与五瓶/活墙组合后的该2项及药水3项JS均通过；组合完整CI与后续平台证据分别记录。

## 剩余接线

战后当前仍用旧支持牌身份选择，商店仍是受限内容与旧身份/价格时序；它们不因本片新owner而成为完整源抽取。完整75红牌、35普通无色、合法跨色/诅咒依赖及完整有序池继续补齐；随后统一接rarity→身份/重复→升级流程和预览/获得钩子。不得缩池、跳过unsupported或重新归一化后声称原版概率。

Question Card、Busted Crown、Nloth's Gift、Prismatic Shard等完整遗物能力以及Courier红牌补货的MathUtils外部熵边界仍待各自正式接线。本片状态接口只认证无这些修饰的base调用。

未新建本片候选、官方导入或实机验收；9ae候选是此前集成源码，不含本片。
