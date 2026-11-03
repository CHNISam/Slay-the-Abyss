# TASK-96 · 职业身份事实审计与最小方向（2026-11-03）

**结论：当前公开岩旅是 Ironclad 规则的旅行者表现适配，不能把星陨剑、岩潮叠嶂、余烬之心等换名视作自研职业机制。推荐下一版本复用既有雷电 V4，作为首局主推荐，同时保留岩旅入口；这是待 Owner 确认的提案。**

本轮提供 AC1 事实材料及 AC2 决策输入。AC1 待主控独审再决定勾选；AC2–4 均未完成。未授权新行为、视觉方向或正式开放。完整可重算快照见 [facts.json](../evidence/character-identity-20261103/facts.json)。

## 1. 审计身份与范围

- 基线/开始时远端 develop：`013535ae48198bd72616224a4729f90bb187ecd9`；分支 `feat/character-identity-audit-20261103`，工作树 `F:\New folder\.worktrees\character-identity-audit-20261103`，初始干净。
- 公开认领：[PR479 评论6597919043](https://github.com/CHNISam/Slay-the-Abyss/pull/479#issuecomment-6597919043)，本树只更新 TASK-96，负责人 Furinya。TASK-85 由另一执行者负责；本文只读其既有合同，不运行其测试或验收流程。
- 当前权威范围为 `docs/SCOPE.md:3–11,24–36`：比赛只有岩旅前两幕。雷电是 M7 下一版本候选，不能倒改成已获准的比赛双职业。`docs/ORIGINAL_V4.md:7–13` 解释冻结资产与接线；其中“四原创直接可用”的旧入口描述不能覆盖后来的白名单。
- 定向取证限于入口/装配链、相关 JSON、已有生成器、少量规则实现与固定来源；未通读全库、重建检索系统或导入旧试玩证据为本轮结果。

## 2. 当前生产事实（AC1）

### 2.1 正式入口与真正生效的身份

| 事实 | 精确入口/标识 | 判断 |
|---|---|---|
| 原生启动固定两幕比赛 profile | `src/lua/abyss_ui.lua:141–150`：`campaignProfile="competition-two-act"`，`production`/`competition-candidate` | 并非 full-source 八职业入口 |
| 白名单只有 `ironclad` | `src/lua/abyss_run_admission.lua:4–22`，同时检查 options.character、experimentalCharacter、characterId、originalV4Role | 雷电、其他元素及准备态身份不会因数据存在而获准进入 |
| 玩家显示为旅行者·荧 · 岩 | `src/lua/abyss_character_select.lua:4–21,58–60`；`ironclad` 的 options 返回 nil，保留默认 Geo loadout | 显示角色身份与底层规则身份分开 |
| 默认选角与开局 | `src/lua/abyss_game_ui.lua:600–633,669–679`：非 full-source 默认选 traveler，开局再查 admission | 选角页存在不等于有多个公开职业 |
| 开局读取原始牌组/规则并装配运行目录 | `src/lua/abyss_run_initialization.lua:16–51,83–128`；`src/lua/abyss_run_card_catalog.lua:183–264` | 运行目录可包含他职业定义，当前职业不随目录数量改变 |

本轮把生产 loader/serializer 的输出直接装入内存，在 Fengari 调用 Geo `Run.new(data,42,{campaign=true,experimental=true,campaignProfile='competition-two-act'})` 盘点：运行目录 **368** 定义，其中 **75 红牌、225 绿/蓝/紫牌、68 其余定义**；`runCardCharacter=ironclad`，`originalV4Role=nil`、`experimentalCharacter=nil`。其他牌定义服务共享获取/派生机制；不能把它们数成公开可选职业或岩旅独创资源。未走地图、未打战斗。

### 2.2 初始牌、完整牌池与表现换名

`data/cards.json#/starter_deck/cards` 是 **5 strike + 4 defend + 1 bash**。生成的初始牌面与固定原版身份：

| 本作 ID / 显示名 | Ironclad 身份 | 当前基础 → 升级规则 |
|---|---|---|
| `strike` / 普通攻击 | `Strike_R` / Strike | 1 费，6 → 9 伤害 |
| `defend` / 防御 | `Defend_R` / Defend | 1 费，5 → 8 格挡 |
| `bash` / 破防斩 | `Bash` | 2 费，8 → 10 伤害，易伤 2 → 3 |

定位：`data/cards.json:3–106`；`data/presentation/traveler.zh-CN.json:5–18`。后者只提供名称和从规则插值的文案模板，`tools/render_traveler_cards.py:43–98` 渲染费用/数值，`scripts/build-ui.mjs:120–125,140` 转成 presentation 模块；不是另一个职业规则表。

本轮实际生成并盘点，而非沿用旧“30/37张”描述：

- 原 JSON **91** 条 = **75** 张常规红牌 + **16** 条其他定义；75 张按稀有度为 **3 基础 / 20 普通 / 36 罕见 / 16 稀有**，按类型为 **32 攻击 / 29 技能 / 14 能力**。
- 75 个 `id`、75 个 `sourceId` 均唯一；每个 ID 都能在既有固定逐卡来源表 `docs/evidence/warrior75/sources.json` 找到来源。其 commit 是 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，与下文 aeubanks 人物/遗物镜像分别标识，不混成同一来源。
- `cards.sourcePools.reward`、`.src`、`.shop` 分别恰好覆盖 **72** 个非基础红牌，去重后也是 72，缺失/额外成员均为空；保留各自顺序，不据集合相等声称概率或随机轨迹一致。Run 装配后的三个池也均为 72。
- [facts.json](../evidence/character-identity-20261103/facts.json) 的 `geo.mapping` 保存全部 75 个 **ID → 原作 sourceId → 本轮生成中文名**。这是身份与呈现覆盖审计，不冒称本轮重验了 150 个牌面的全部数值/执行时序。

代表性“像旅行者”名称对应的仍是原规则：

| 本作显示 | 原作身份 / 当前定义锚点 | 分类 |
|---|---|---|
| 星陨剑 | `cleave` / Cleave，`data/cards.json#cards[id=cleave]` 群体伤害 | 换名，不是生成岩造物 |
| 岩潮叠嶂 | `whirlwind` / Whirlwind，`costMode=all_energy` 的 X 费群攻 | 换名，不是独立元素爆发资源 |
| 永世的磐岩 | `barricade` / Barricade，`gainStatus:barricade` 保留格挡 | 换名，不是新护盾体系 |
| 剑术精进、渐入佳境、剑意突破 | `inflame` / Inflame、`demon_form` / Demon Form、`limit_break` / Limit Break | 原力量构筑 |
| 孤注一掷、百折不挠、临机应变 | `corruption` / Corruption、`feel_no_pain` / Feel No Pain、`dark_embrace` / Dark Embrace | 原技能消耗及消耗收益循环 |
| 透支、舍身进攻、愈挫愈勇 | `bloodletting` / Bloodletting、`hemokinesis` / Hemokinesis、`rupture` / Rupture | 原付血换资源/受血损增力循环 |

对应底层接线还可定位 `src/lua/abyss_run_card_catalog.lua:33–39` 的 warrior/exhaust/strength/status/retrieval 适配链。自写 Lua、原子事务与原生输入是工程实现成果，不能据此把对应的 Ironclad 规则改称新职业设计。

### 2.3 生命、资源、遗物、状态

| 当前事实 | 本作锚点 | Ironclad 对照与身份结论 |
|---|---|---|
| 80 最大生命、每回合 3 能量、抽 5、起始 99 金 | `data/rules.json:3–12`，`Run.new` 实盘 80/80、99 金、10 牌 | 与固定镜像人物 loadout/energy 相符；不是岩旅专属新资源 |
| 手牌上限 10、3 药水槽 | `data/rules.json:7,12` | 共用系统参数；本轮未独立追查其完整原版方法链，不把这两项标作官方核验通过 |
| `burning_blood` 显示“余烬之心”，胜利后 heal 6 | `data/relics.json:201–210`；`src/lua/abyss_run.lua:60–67` 明确 `Burning Blood` 别名；`src/lua/abyss_run_settlement.lua:21–30,158–170` 败北提前返回，胜利结算后回血 | 与 BurningBlood.onVictory 的存活 heal(6) 对应；名称变化不是新遗物机制，也不是失败后回血 |
| 力量、敏捷、易伤、虚弱、脆弱、壁垒、消耗收益等 | `data/statuses.json` 中 `strength/dexterity/vulnerable/weak/frail/barricade/corruption/feel_no_pain/dark_embrace`；`data/rules.json:65–73`；`src/lua/abyss_actor.lua:77–112,574–577,721–738,884起` | 原作状态/能力家族；50%易伤、25%虚弱/脆弱、向下取整及通常回合清盾为共用规则，不是岩元素反应 |
| Geo 没有启用愿力/雷眼/一心 | `src/lua/abyss_combat.lua:2161–2163` 只在 `data.originalV4Role` 存在时调用 V4.init；本轮 Geo Run 的此标记为空 | 源码包含 V4 状态初始化函数不表示岩旅拥有这些机制 |

**真正差异边界：**旅行者命名、角色肖像/卡画/主题、千星交互与信息呈现属于本作表现和平台实现；本轮在生产 Geo 的选中身份、75 红牌和起始资源中没有找到替换 Ironclad 核心循环的独立职业资源。实现偏差、未验证的随机/时序、内容缺件不能自动算作“自研机制”。不据此宣称整个工程与原版逐帧/概率/二进制完全相等。

### 2.4 原作来源的可信边界

本轮另只读抓取并按原始响应字节计算：

- [Ironclad.java](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/Ironclad.java)：固定 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`，`EnergyManager(3)` 第56行，`getStartingRelics` 第72行、`getStartingDeck` 第80行、`getLoadout` 第101–102行；9585 字节，SHA256 `6fc9b761251a96f9e3a8e31adb3698f87dbaca07a7d3f0b931c9a9ea0bbcf132`。
- [BurningBlood.java](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/BurningBlood.java)：同提交，`onVictory` 第26–32行；1106 字节，SHA256 `8217a4a05a80474158ade3f7d77e51f802c9701512bbf1ab90321d7f74d5d65d`。

二者文件头明示 CFR 反编译，属于第三方固定镜像，不是官方开源，也未与正版 PC 二进制认证。75 卡沿用仓库固定来源登记，仅本轮核对身份覆盖；既有严格规则矩阵 `docs/reviews/TASK-16-warrior75-matrix.md` 不当作当前候选的新测试结果。所有 hash 只证明字节身份，均不证明官方导入、真实 ready、PC/安卓玩法或版权许可已验收。

## 3. 已有雷电 V4 能提供什么（AC2 输入，非完成声明）

冻结入口：`data/original_v4/cards_v4.json`、`rules_v4.json`；`scripts/build-original-v4.mjs:6–9,70–106` 校验 4×75 稳定 ID 和冻结原始字节。雷电标识 `raiden` ↔ `RD`（`src/lua/abyss_original_v4_profiles.lua:3–4`），75 张 `RD2-001..075` / 150 牌面，6 基础、26 普通、25 罕见、18 稀有；69 非基础牌由现有 profile 接奖励/商店，见该文件 `19–63`。本轮没有重新执行雷电行为。

下文 V4 表文件简写均相对 `data/original_v4/`，`abyss_*.lua` 简写均相对 `src/lua/`；`#RD2-004` 等锚点表示 cards 数组中相应稳定 ID，并非 Markdown 标题。

| 已有身份特征 | 冻结规则与已有实现锚点 | 与 Geo 的实质差异 |
|---|---|---|
| 付费军令积愿力 | `rules_v4.json#/RD`；`abyss_original_v4.lua:131–136,273–277`：实际支付≥1能量的 command 结算后 +1愿力；所有来源每回合最多+2，总量6 | 与可直接花掉的当回合能量分开的蓄积资源，且不是改名力量 |
| 雷眼有限次追击 | 同规则，`abyss_original_v4.lua:240–243,281–283`；有存量/有效期、实际直接扣血触发、每牌一次、不递归；新建雷眼不追击自身命中 | 出牌顺序和真实扣血条件改变当下决策 |
| 愿力拔刀→梦想一心→下回合返能 | `cards_v4.json#RD2-004`，需 `resolve3`、耗尽愿力，基础 `10+2R` 伤害；`abyss_original_v4.lua:266–279,306–317`：普攻首命中+3、最多3次/2结束阶段，实际扣血后每回合最多预订1能量，下回合到账 | 蓄积—爆发窗口—下回合安排的循环，不能写成当前回合无限返能 |
| 起始遗物稻光军印 | `rules_v4.json#/roles/RD`，profile 生成 `original_v4_rd`；`abyss_original_v4.lua:275–277` | 每战首张实际付费军令结算后固定2格挡；不是 Burning Blood，也不额外回能 |

雷电 IP、官方技能名不是本作原创 IP；这里称“自研”的是既有 V4 卡牌/资源组合规则。普通攻击/防御仍复用常见攻防底座，不因进入 V4 就变成全新基本动作。

### 首十分钟应感知的路径（建议验收目标，时点未实测）

初始 10 牌固定为 `RD2-001 普通攻击×3`、`002 防御×3`、`003 神变·恶曜开眼`、`004 奥义·梦想真说`、`005 重击`、`006 军令·整备`；72 HP、3 能量、5 抽牌、10 手牌上限。事实来自 `rules_v4.json:94–111,121–135` 及对应卡 DSL。

1. **0–2 分钟/出发前：**玩家能说出“付费军令蓄愿力，开眼后安排攻击，攒够拔刀”。初始六种牌及军印说明与实际规则一致，不把通用普攻/防御当唯一特色。
2. **首战前几轮/约2–6分钟：**自然抽到 `003` 或 `006` 后，看到愿力从0增长、军印首次格挡；`003` 建雷眼后再打实际扣血牌，能区分本牌直伤和有限次追击。能读出雷眼次数及剩余阶段。
3. **约6–10分钟：**观察至少一条愿力/雷眼决策；遇到合法拔刀条件时，能理解 `004` 的需≥3/耗尽愿力、一心普攻次数及下回合到账能量。优先让完整循环在自然试玩窗口内出现，以日志和玩家复述证明，而非只看华丽卡名。

**不能保证首次洗牌就可拔刀：**初始军令只有 `003`、`006` 两张，单次各付费使用只产生2愿力，`004` 要3；基础牌循环通常需要再抽到军令。初始不强制签名牌（`common.forced_signature_start=false`），愿力新战清零（`abyss_original_v4.lua:44–49`），短战可能在爆发前结束。本轮未测覆盖率/耗时；后续若自然首十分钟不能感知核心循环，应保留为体验缺口，交 Owner 决定引导/范围，不能擅加愿力、操纵抽牌、替换初始牌或修改冻结值。

## 4. 最小可行方向比较（均待 Owner 确认）

| 方向 | 最小产品切片与首十分钟 | 依赖/取舍 | 验证出口 |
|---|---|---|---|
| **A 推荐：下一版本以雷电为首局主推荐，保留岩旅可选** | 复用75张雷电 V4和上述军令—愿力—开眼—一心循环，保留两幕正常结算及岩旅历史/牌池 | 接 TASK-85 验收；增加下一版本正式准入与主推荐策略、必要身份素材和信息呈现。双入口信息成本较高，但保留原版对照且不要求新机制开发 | 同一新候选从公开入口选雷电，首十分钟辨认循环、自然两幕结算，PC/安卓分开留证；岩旅入口回归另按风险执行 |
| B：下一版本雷电单一正式首局入口，岩旅保留历史/full-source可恢复版本 | 同一套既有雷电循环；更少选角分岔，首次进入直接解释雷电身份 | 仍须 TASK-85 全部必要出口；Owner另行批准下一版本入口取舍，保存原旅行者版与研发内容，不能改写已发布岩旅版 | 除雷电同候选验收，核实历史岩旅保留、版本/入口标识不混淆；不据少一个选择免除玩法/美术/设备要求 |
| C：若 Owner 否决雷电路线，复用既有胡桃 V4 单职业切片 | `HT2-003/004/005` 与冻结蝶引、低血、血梅香循环；首次10分钟感知付血换窗口与标记收益 | `rules_v4.json#/roles/HT,/HT`、既有 profile/DSL 可复用；需新的等价角色验收归属、UI/素材与低血可读性验收，失去TASK-85现有并行优势；本轮仅数据/源码可行性提案 | 与雷电相同层级的公开入口、自然构筑/两幕、首局辨识和双设备证据；当前没有本轮通过结果 |

A/B 都只面向待批准的下一版本，不回溯扩大冻结比赛合同。C 不触发本轮实施。**仅继续把岩旅改名/换皮，虽可改善角色表现，却不能单独满足 TASK-96 的独立职业机制门槛。**

## 5. 推荐 A 的必要接入依赖（待批准后由对应任务实施）

- **正式准入**：当前只有 `competition-two-act` 的 Geo 白名单，不能只显示一个雷电按钮就算开放。下一版本须明确 profile/白名单与选择、确认、开局及准备态身份检查的一致性；复用 `abyss_run_admission`、`abyss_character_select`、`abyss_game_ui` 的既有链。如何新增 profile/改变推荐由 Owner 确认后设计，本文不决定实现。
- **保留既有玩法**：profile 已生成 `original_v4_rd`、69奖励/商店牌及75基础/升级定义；无须重做卡包，不重复扣军令格挡（`rules_v4.json#/RD/command_block_changes` 明示减2已在15项牌表处理）。UI只读状态并发命令，战间资源重置、永久UID/升级/库存与跨幕合同交 TASK-85 验收。
- **现成信息能力可复用**：`abyss_original_v4_display.lua:125–137,213–244,354–396` 已有关键词、卡面前提、愿力/次数/阶段/返能摘要；`abyss_card_display.lua:371–416` 有 V4 卡面接线。还需正式候选验证文字容量、状态入口可达性、触屏点选/长按、预览与真实结算一致；函数存在不等于玩家已看得到。
- **确实存在的说明接线缺口**：`abyss_original_v4_profiles.lua:55–56` 生成初始遗物只有名称、`trigger='original_v4'`、空 effects；`abyss_character_select.lua:24–29` 的 relicText 只认 description 或单heal/combat_end，因此当前生成资料不能从该函数得到军印规则摘要。后续应显示冻结规则的真实摘要，具体文案/视觉待确认；本轮不修代码。
- **身份资产**：`data/presentation/ui_theme.json:907–912,966–994` 的雷电大肖像 `105308`、半身/战斗肖像 `105315` 仍标 `placeholder`/非正式可玩；`scripts/official-portraits.mjs:7–16` 当前专属资源为 traveler-geo，不能当雷电素材证明。最少须核实雷电选角、战斗身份、关键初始/机制牌的合法素材绑定与信息可辨；卡画覆盖、具体样式、颜色/动效及平台降级由 Owner和现有批准稿约束，不在本提案擅定。

## 6. 分层验证出口与当前未完成边界

| 层级 | 后续必须取得的证据 | 本轮状态 |
|---|---|---|
| AC1 事实准确性 | 独立审阅75映射、资源/遗物及“表现/规则/未知”分类，确认无夸大 | 已提供草稿和重算事实；待主控独审，未勾 |
| AC2 决策与实施 | Owner选定方向；批准下一版本入口范围与必要呈现；实施后验收 | 只有3个方向提案，未批准/未实施 |
| 玩法源码/离线行为 | TASK-85已有执行者给当前SHA机制、交互、回滚、奖励/构筑/跨幕证据；主控独立接受 | 本轮未执行雷电测试，不把冻结hash或旧回归当通过 |
| 候选写入/读回 | 明确SHA/构建输入/候选hash与实际脚本、资源、入口绑定 | not_run |
| 官方导入与新ready | 同候选官方存档身份，导入后新订阅日志，真实ready/错误记录 | not_run |
| PC官方客户端 | 从正式入口、原始初始构筑、自然获取到两幕正常结算；首10分钟录屏/日志及玩家能复述特色 | not_run |
| 实体安卓 | 同候选上述玩法和文字/输入/性能实测；物理触控与PC结果分开 | not_run |
| AC4 身份辨识 | 同候选玩家在首10分钟明确区分军令/愿力/雷眼/一心，理解延后返能；保留失败与未出现片段 | not_run，未宣称独立职业体验交付 |

本轮没有 GIL、导入、ready、PC/安卓实测或完整CI结果；也未执行全量测试、TASK-85测试、发布、提交或合并。源码和序列化输出hash不等于官方验证。M7归属与后续提案不自动取代现行SCOPE。

## 7. 本轮重算方式与轻量检查

环境：Node `v22.22.1`，现有 Python 渲染器，父工作区现有 Fengari 依赖。所有计算无文件输出；内存模块使用生产生成器相同的头、return、换行。原始输入字节hash保存在 facts.json；生成值为：

| 内存生成模块 | 字节数 | SHA256 |
|---|---:|---|
| abyss_data.lua | 212620 | `c8dd7a050839a50b2e895787f6a72824187f9c6eaaea4002261f82f4ad0de9a4` |
| abyss_original_v4_data.lua | 577904 | `63e4983d6d80241f287e153087efd81e7ab287efbb15e195ef80ad90230fb2cb` |
| abyss_presentation.lua | 74514 | `d787983564fc6d1e3435fd55d0b97fe593d12b7b53b393ce4fbf298318449e0c` |

在本工作树 PowerShell 可用以下只读重算片段，校验输入字节、全部75映射和生产序列化身份（不写build/不执行雷电战斗）：

```powershell
node --input-type=module -e '
import {readFileSync} from "node:fs";
import {createHash} from "node:crypto";
import {spawnSync} from "node:child_process";
import {loadContent,validateContent} from "./scripts/validate-data.mjs";
import {toLua} from "./scripts/build-lua-data.mjs";
import {loadOriginalV4,originalV4ToLua} from "./scripts/build-original-v4.mjs";
const f=JSON.parse(readFileSync("docs/evidence/character-identity-20261103/facts.json"));
const hash=b=>createHash("sha256").update(b).digest("hex");
for(const i of f.inputs){const b=readFileSync(i.path);if(b.length!==i.bytes||hash(b)!==i.sha256)throw Error(i.path)}
const d=loadContent("data"),v=loadOriginalV4();
if(validateContent(d).length)throw Error("content validation");
const r=spawnSync("python",["-B","tools/render_traveler_cards.py","data/cards.json","data/presentation/traveler.zh-CN.json"],{encoding:"utf8",env:{...process.env,PYTHONUTF8:"1",PYTHONDONTWRITEBYTECODE:"1"}});
if(r.status!==0)throw Error(r.stderr);
const p=JSON.parse(r.stdout),shown=new Map(p.cards.map(c=>[c.id,c]));
const red=d.cards.cards.filter(c=>["attack","skill","power"].includes(c.type)&&c.rarity!=="special");
if(JSON.stringify(red.map(c=>[c.id,c.sourceId,shown.get(c.id).name]))!==JSON.stringify(f.geo.mapping))throw Error("75 mappings");
const modules=["-- Generated from validated JSON. Do not edit.\nreturn "+toLua(d)+"\n","-- Generated from frozen Original V4 JSON. Do not edit.\nreturn "+originalV4ToLua(v)+"\n","-- Generated from the checked Traveler presentation.\nreturn "+toLua(Object.fromEntries(p.cards.map(c=>[c.id,c])))+"\n"];
modules.forEach((s,i)=>{const e=f.generation.generatedModules[i];if(Buffer.byteLength(s)!==e.bytes||hash(s)!==e.sha256)throw Error(e.module)});
console.log("input hashes / 75 mappings / 3 in-memory modules: PASS");'
```

Geo Run 目录实盘的复算入口是同一内存 `toLua(loadContent('data'))` 加 `package.preload.abyss_data`，再按 facts.json `geo.runInspection.method` 调用生产 Run.new 并按 color 盘点；只是开局资料观察，不是战斗/自然试玩验收。

本轮收口检查（均为本工作树新结果）：

| 命令/观察 | 结果与边界 |
|---|---|
| 上述 `node --input-type=module -e ...` 重算片段 | exit 0；7项输入hash、75映射、3个内存序列化模块一致，`validateContent` 无错误、V4冻结校验通过 |
| 只读 Node 数据交叉核对 | exit 0；稀有度/类型数、初始牌/资源、三个72成员池、75来源覆盖、雷电初始两张军令及爆发前提与事实JSON一致；不是雷电执行测试 |
| 内存生成数据 + Fengari Geo Run 盘点 | exit 0；368/75/225/68定义，红牌 sourceId 与原输入差异0，三个72池；没有战斗结果或设备通过含义 |
| `npm run check:guidance` | exit 0，errors=[]；只检查仓库指引合同 |
| `npm run verify:backlog` | exit 0；队列、负责人、优先级及岩旅比赛范围合同通过，不认证运行时准入 |
| `git diff --check` | exit 0，无空白错误 |
| 分别对两份新附件的 `git diff --no-index --check -- NUL <文件>` | 均无空白错误输出，仅有Git既有LF/CRLF提示；原始退出码均为1（no-index相对空文件存在差异），不记作exit 0 |

任务正文只通过 Backlog CLI 更新。以上是事实核算和文档轻量检查，不是整套测试或TASK-85验证结果。

## 8. 只需 Owner 明确的一条决定

**是否批准方向 A：下一版本以既有冻结雷电 V4 作为首局主推荐、岩旅保留可选，完成 TASK-85 与同候选 PC/安卓及必要呈现验收后再正式开放？**

未确认前保持研究/提案状态；确认方向也不等于 AC2实施、AC3入口/设备或 AC4体验已经完成。
