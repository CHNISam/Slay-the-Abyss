# 战士第一幕遗物原池与依赖目录

本片只固定原池事实、来源与独立向量，不实现缺失效果。基线 `eb4e8af`。机器目录为 [sts1-relic-pool-catalog.json](evidence/sts1-relic-pool-catalog.json)，逐项包含原始 ID、类名、稀有度、合法来源、生成条件、机制分组、原类 hook 名、现有数据映射和缺项状态。未改 `data/relics.json`、生产 Lua、UI 或 Backlog 正文。

## 范围与缺项

按战士、A0、第一幕、非每日、非无尽、全部遗物解锁的普通单人配置盘点。下表是初始化队列容量；瓶装牌、黑血、营火数量与商店禁出等条件会影响某时刻实际可出成员，不能把容量当作当场均匀抽取概率。

| 原稀有度 | 原队列 | 已有本地效果/定义 | 缺项 |
| --- | ---: | ---: | ---: |
| common | 33 | 7 | 26 |
| uncommon | 30 | 1 | 29 |
| rare | 28 | 0 | 28 |
| shop | 17 | 1 | 16 |
| boss | 22 | 3 | 19 |
| 合计 | 130 | 12 | 118 |

另有初始 `Burning Blood`，以及 10 个第一幕专属/涅奥项：`Golden Idol`、`Odd Mushroom`、`WarpedTongs`、`Spirit Poop`、`CultistMask`、`FaceOfCleric`、`GremlinMask`、`NlothsMask`、`SsserpentHead`、`NeowsBlessing`。其中前 9 个来自事件，最后一个来自涅奥。共 141 个第一幕可涉及 ID，现有 13 项本地效果，缺 128 项。目录保留 8 个后续幕 SPECIAL 作为明确排除记录，不把它们混进第一幕池：`Bloody Idol`、`Enchiridion`、`Mark of the Bloom`、`MutagenicStrength`、`Necronomicon`、`Nilry's Codex`、`Nloth's Gift`、`Red Mask`。

全部 ID 与精确缺集直接读目录，不另维护一份缩减名单：

```powershell
$catalog = Get-Content docs/rules/evidence/sts1-relic-pool-catalog.json -Raw | ConvertFrom-Json
$catalog.relics | Where-Object { $_.scope -eq 'act1-queue' -and -not $_.projectId } |
  Select-Object id,tier,channels,dependencyGroups
```

现有 13 项仍标 `existing-local-effect-not-full-pool-parity`，表示基线已有局部效果及旧测试，不表示完整原池、所有交互或实机已验收。Tiny Chest/Juzu 已有问号选择器ownership参数接线，但没有数据定义、正式取得及完整持久化效果，目录保留该局部事实，仍计为交付缺项。新目录的实现、PC 二进制认证、实机证据均为 `pending`。扩池后必须更新机器清单与逐项验证，不能靠目录存在或数量变大关闭 TASK-14.1/TASK-13.1/TASK-47。

## 来源身份与顺序

固定 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0) 的社区反编译镜像，其声明版本是 `V2.3.4 (12-18-2022)`。这不是官方开源，也没有本轮持证 PC JAR/build 认证。记录的 204 个文件使用实际下载字节计算 SHA256 与 Git blob SHA1，见 [source identity](evidence/sts1-relic-source-identity.json)；不提交原方法体或长文案。

关键入口为 [RelicLibrary](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/RelicLibrary.java)、[AbstractDungeon](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java)、[Exordium](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java)。`sortLists` 排的是图鉴列表，正式 `populateRelicPool` 遍历 shared `HashMap`，再遍历 red `HashMap`。**正式队列不是字母序，也不是 RelicLibrary 注册顺序。** 其他颜色遗物不进入战士库，Prismatic Shard 也不改变这一点。

16 个相关遗物有账户解锁来源，目录逐项记录 `unlockSource`。本片全解锁是内容完整性的上界配置，不把未认证的账户进度当作排除理由。若产品保留锁定配置，先过滤锁定成员，再洗牌，种子轨迹与全解锁不同。

初始化按 `common → uncommon → rare → shop → boss`，每池各调用一次 `relicRng.randomLong`，交给新的 `java.util.Random` 供 `Collections.shuffle` 使用，共消耗 5 次包装计数。持有/模式排除在五次洗牌之后移除，不重排。保存恢复使用已经消耗的五个队列，不能从剩余已支持项重建。

普通获取取队首，商店取队尾，boss 即便调用尾部函数也取队首。候选生成时就出队，未买、未选、未领不退回。`canSpawn=false` 也先消耗该项，然后从**同一稀有度队尾**继续；因此一次正面抽取被拒绝后会换向。空池 common→uncommon、uncommon→rare、shop→uncommon 均从升级池**队首**取，不保留商店的尾向。rare 耗尽请求 Circlet；boss 耗尽请求 Red Circlet，但该镜像没有在库里注册 Red Circlet，最终由 `getRelic` 的缺键 fallback 得到 Circlet，目录明确保留此镜像差异。

宿主 JDK 17.0.18 的实际 HashMap/Collections.shuffle 生成 12 组向量：10 种 64 位种子，另有显式锁定掩码和洗牌后移除持有项的例子。这是独立源码解释和宿主容器执行，不是原游戏执行；HashMap 顺序不属于 Java 语言跨实现保证。后续 PC 认证要比对游戏的 Java 版本及完整队列；不能把这一步的固定向量冒称 PC oracle。

## 各来源的抽样与消耗

下表及机器目录 `acquisitionChannels` 固定来源语义。稀有度概率是入口层概率；生成条件、耗尽 fallback 和共享消耗仍需随后执行。不能删除不支持成员后重标权重或重新归一化。

| 来源 | 稀有度/随机流 | 出队与额外约束 |
| --- | --- | --- |
| 精英 | `relicRng` 0..99：50 common / 33 uncommon / 17 rare，82仍是uncommon | 队首。Black Star 额外再掷一次；额外项过滤 Girya/Peace Pipe/Shovel，拒绝项被消耗 |
| 普通宝箱 | `treasureRng` 先抽箱型50/33/17，再用同一个0..99结果决定金币与遗物稀有度 | 小箱75/25/0，中箱35/50/15，大箱0/75/25；金币概率50/35/50，与稀有度相关，不能独立再掷。普通遗物取队首 |
| 商店 | 前两槽各用 `merchantRng` 抽48/34/18；第三槽固定shop | 队尾；非每日每项另有价格浮动随机数。Courier、Smiling Mask、MawBank、Old Coin 的 `canSpawn` 禁止商店 |
| Courier补货 | 每次候选重新掷普通48/34/18，价格另浮动 | 即使买的是初始shop槽，补货也走普通稀有度；不能永远补shop项 |
| Boss宝箱 | 不掷稀有度 | 构造时连续产生3个boss队首候选，未选的也已消耗 |
| 涅奥 | common、rare或boss固定稀有度，不额外掷遗物稀有度 | 取队首；boss swap先失去初始遗物，Black Blood因此不能生成；NeowsBlessing直接发放，不占普通池 |
| 随机遗物事件 | 一次 `relicRng` 50/33/17 | Big Fish、Scrap Ooze、Dead Adventurer搜索、Wheel of Change、We Meet Again 用screenless抽取；瓶装三件/Whetstone消耗后在同稀有度继续 |
| Dead Adventurer战斗遗留奖励 | 一次普通50/33/17 | 普通队首函数，不能一概套搜索的screenless过滤 |
| Shovel | 一次 `relicRng` 50/33/17 | 普通队首奖励；需要独立营火Dig动作 |
| Calling Bell | 固定common/uncommon/rare各一，不掷稀有度 | screenless函数；先处理铃铛诅咒和确认，再创建3项奖励；过滤项照常消耗 |
| Matryoshka | `relicRng.randomBoolean(0.75)` 决定common或uncommon | 在普通非boss箱奖励前额外出队；限两箱。NlothsMask在奖励建好后移除一项，已出队项不退还 |
| Face Trader | `miscRng.randomLong` 洗牌尚未持有的5张脸 | 固定候选输入顺序见向量/目录说明；全持有才给Circlet，不混进普通队列 |

专属事件的前置决策保留：蘑菇选择战斗后给 Odd Mushroom；金神像选择取得遗物并承担后续代价；Bonfire 奉献诅咒才给 Spirit Poop；Accursed Blacksmith 的翻找同时给 Pain 与 WarpedTongs。Face Trader 第一幕可达；Nloth、Cursed Tome 等后续幕事件不能据全局注册误判第一幕可达。涅奥完整祝福选择还有前局进度条件，不能把其全部选项宣称每次开局都可见。

## 机制依赖与后续分工

先做唯一共享队列/随机流/存档底座，再并行效果。所有分组共用取得、移除、替换、计数持久化及有序hook协议。目录的 `sourceHooks` 盘点原类重写方法（省略描述/factory方法，保留update、计数与生成条件），不是完整调用链；Prayer Wheel、Singing Bowl、Prismatic Shard 等大量逻辑在宿主入口，不能因遗物类没有hook而标为无效果。

| 分组 | 必须覆盖的具体依赖 |
| --- | --- |
| 战斗hook | 开场/抽牌前后/回合/出牌类型计数、伤害与格挡修饰、敌人死亡、遗物取得顺序；Brimstone、Runic Dome、Velvet Choker等boss/shop代价同样必须实现 |
| 卡牌生命周期与生成 | Dead Branch、Mummified Hand、Strange Spoon、Chemical X、Blue Candle/Medical Kit、Snecko Eye、Runic Pyramid、Gambling Chip；费用临时变化、消耗/弃牌/保留、随机生成不能用有限卡表替代 |
| 跨职业 | **PrismaticShard必须保留shop池**。原`getRewardCards`按已掷稀有度进入全颜色库（含无色、所有职业已解锁合格卡），并给无球槽的非机器人1个球槽；涉及球、姿态、毒、弃牌、保留等完整下游规则。不能排除碎片或只让它显示无效果；它不开放其他颜色遗物池 |
| 地图/营火/问号 | **WingedGreaves（类WingBoots）**的3次合法跨边移动、计数与存档；Girya新增举重最多3次并转开场力量、Peace Pipe移除、Shovel挖掘；三件营火遗物总数达到2时第三件不能生成。Coffee Dripper/Fusion Hammer禁用动作、Eternal Feather/Regal Pillow/Ancient Tea Set和TinyChest/Juzu触发链 |
| 奖励/商店/药水 | Question Card +1和Busted Crown -2按有序hook改变选项数；Prayer Wheel只给普通战斗第二个卡奖；Singing Bowl独立放弃换+2上限；Egg预览/取得升级、Bottles选牌资格、Orrery/Cauldron/Calling Bell的多项奖励及递归领取；Potion Belt扩槽、Sacred Bark双倍、Sozu阻止取得、White Beast掉落保证 |
| 生命/金币/诅咒/事件 | 水果/Old Coin/MealTicket等即时取得、BloodVial/MeatOnTheBone/LizardTail/MagicFlower；Omamori/诅咒触发、Cursed Key、Ectoplasm覆盖所有金币入口；9个Act1事件专属与Neow次数、Boss替换后的后续战斗/节点效果 |

第一幕结束才取得的boss遗物仍保留完整22项；不能因本作品17层终点暂时无后续战斗，就删掉原候选或宣称能量效果自然验证过。Neow swap使大多数boss遗物有机会在第一幕实际生效，Black Blood另受初始遗物限制。

## 本片验证与复现

只运行 `node --test --test-concurrency=1 tests/sts1-relic-pool-catalog.test.mjs`，本轮8/8绿，见[短验证记录](evidence/sts1-relic-catalog-validation.json)。测试核对完整源事实成员、映射/缺项、不支持项删除或伪造实现状态的负例、12组队列向量、全部0..99稀有度边界、实际生成条件和前尾/过滤/耗尽消耗。当前生产概率与完整原池**仍未通过**：本片没有把现实现与oracle相等作为绿断言，118队列缺项也没有被掩盖。

Java向量可离线再生（先从已有独立RNG夹具输出每种seed前5个raw long）：

```powershell
New-Item -ItemType Directory -Force .artifacts/relic-catalog | Out-Null
node --input-type=module -e "import fs from 'node:fs';const v=JSON.parse(fs.readFileSync('tests/fixtures/libgdx-rng-source-vectors.json','utf8'));fs.writeFileSync('.artifacts/relic-catalog/input.tsv',v.seeded.map(r=>[r.seed,...r.case.raw.slice(0,5)].join('\t')).join('\n')+'\n')"
java tools/oracles/Sts1RelicPoolVectors.java tests/fixtures/sts1-relic-library-registration.tsv .artifacts/relic-catalog/input.tsv
```

本轮向量使用宿主JDK17；日常Node测试不要求机器安装Java。fixture保存生成器与源事实的规范LF SHA256。定向测试绿只说明目录/独立解释自洽；全原池实现、概率对齐、自然取得执行、候选导入和实机逐项证据仍待后续任务。
