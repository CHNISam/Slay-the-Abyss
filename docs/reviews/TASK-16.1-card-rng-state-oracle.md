# 卡牌随机流与稀有度偏移：独立状态向量

2026-10-25，基线`9ae1aec`。仅新增独立Python解释器与固定JSON，不改生产、内容池或Backlog。固定社区镜像`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；不是正版PC二进制认证或PC执行oracle。

## 直接读取的来源

本轮从根`.artifacts/sts1-fixed-source/sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`提取以下原字节，只留忽略的`.artifacts/sts1-card-rng-oracle/source/`。URL模板为`https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/{path}`。

| path | 原字节SHA256 | 核对章节 |
| --- | --- | --- |
| random/Random.java | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` | 构造/计数、random(int)、randomBoolean(float) |
| dungeons/AbstractDungeon.java | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` | 383初始化；1403–1458奖励；1577–1598稀有度；1727–1731换层；2615重置；2753–2755偏移常量 |
| rooms/AbstractRoom.java | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` | 98–102基础3/37；138–168累计阈值及遗物钩子 |
| rooms/MonsterRoomElite.java | `c5207d745f383e1de615e613da8e5c8f832e237444c3b757d85a61f8b3f5ee3f` | 构造10/40；getCardRarity |
| rooms/ShopRoom.java | `f8cadde291ebe73918166aa05ba9f5006c4aec7b80add7a39e03eb469699e988` | 构造9/37；49禁用普通房遗物修改 |
| rooms/MonsterRoomBoss.java | `0e6e49235af6fbcfa3047c204ccde983f6152eac8fc845c47c2d36d63b0c8d21` | 35–37恒rare |
| dungeons/Exordium.java | `93808b9da69b76da6b8f0471cc3533fa113fa28298939bbc48eb55566a976c08` | 104第一幕升级chance=0.0f |

XS128数学沿用已固定原语依据`libgdx/libgdx@3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java`的seed0替换、Murmur3混合、无符号移位、bounded拒绝采样、高24位float；既有来源边界见`TASK-16.1-random-wrapper-candidate.md`。本Python重新独立实现整数/float运算，不import生产Lua或既有oracle，不用生产结果生成预期。

## 向量边界与协议

`tools/sts1-card-rng-oracle.py`生成`tests/fixtures/sts1-card-rng-state-vectors.json`。8个raw signed64 seed含0、负数、超16位、超binary64精确整数以及signed64两端。每个7个高层动作：normal3→shop3→checkpoint/克隆探针→elite3→boss3→恢复→elite3精确重放，共56动作；20个受控状态另核四个稀有度阈值、最低-40、Boss消耗、只roll不改offset、signed32回绕与bounded拒绝。

所有快照为`{version=1,cardRng={words={hex64,hex64},counter=signed32},cardRarityOffset}`，与核心计划的snapshot兼容。每槽`rarities`包含`rawRoll`、`adjustedRoll`、`rarity`、前后完整owner；每个实际wrapper调用的`primitive`另含前后words/counter、全部64位输出、result，float含精确binary32 bits。`controlledCases.action.op`为`rollRarity`或`rewardRarity`；shop使用前者，奖励使用后者。高层`reward`展开成全部rewardRarity，再按返回rarity逐槽upgrade；rare显式`skipped=true`不抽，其他在A0调用`randomBoolean(0)`并抽float。`floor`仅为跨房连续性标签，不参与cardRng初始化/重建。

**这是省略身份抽取的状态核心投影，不是完整getRewardCards或商店重播。** 真正源每次rarity后立刻抽身份，重复只重抽身份；这些调用插在后续rarity之前，会改变后续words。本向量刻意不生成身份、不消费身份索引、不用假池补抽，不认证真实奖励/商店消费轨迹。实际奖励集成须待完整池、原顺序与身份消费接通后独立验证。普通/精英/商店阈值为3/40、10/50、9/46；无遗物/模组改概率。Shop读但不改偏移；奖励common减1最低-40、rare归5，uncommon不变。Boss仍抽一次int再恒rare；全部槽后非rare升级chance0仍抽，rare不抽。

checkpoint保存的是完整words+counter+offset，恢复和克隆探针不修改源owner。它是项目的可恢复状态边界，**不是原PC seed+counter构造或存档格式**；原Random.copy创建无参对象会触碰MathUtils，项目detached clone没有这个视觉熵副作用。未纳入身份/重复、slot-changing遗物、PrismaticShard、预览钩子、商店价格/Courier及实际奖励接线。

## 验证

- `python tools/sts1-card-rng-oracle.py --self-test`：手算阈值分布、控制边界、seed0、回绕/拒绝、克隆不污染和checkpoint精确重放通过。
- 默认生成后`--check`完整逐byte再生匹配；generatorSha256按规范LF文本，CRLF检出时read_text归一化。
- 独立Java17整数溢出/float校验器（根忽略目录`VerifyCardRng.java`）核8个seed初态、228次wrapper的值/原始输出序列/双words/counter/float bits，以及148次rarity+offset结果，全部通过。该自写校验器没有执行原作或导入生产。
- 首轮Java比对发现shop动作缺少显式room标签，补`room=shop`后通过；只修向量传输元数据，未调整算法迎合生产。
- 未运行完整QA/GUI/MCP/平台或生产Lua；本片不声称核心API已通过这些向量，后续核心接入者负责消费本固定JSON验收。
