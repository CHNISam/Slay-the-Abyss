# TASK-13.1 商店与节点规则对照

核对日：2026-10-23。目标是初代 Slay the Spire PC 正式版 Ascension 0。当前证据来自初代 Wiki 页面；本轮没有启动原作、原神、MCP 或编辑存档，没有原作客户端版本号、二进制审计或玩家操作录像。因而以下“来源已查”只表示公开资料交叉核对，不等于整个 PC 版本严格一致性验收。

本轮可执行修复：**每个商店只出售一次删牌服务**。原实现付款后立即以递增价格开放第二次，UI 回归也允许删除第二张；现在核心交易用 `nodeFlow.removalUsed` 记已购买状态，成功后 UI 所有剩余删牌入口禁用，旧 UI 请求仍由核心再次拒绝。无效 UID、金币不足、仅剩一张等失败不消费服务；购买其他商品和离店仍可用。`shopRemoveCount` 保持同局跨店累计，新局归零。

## 已查来源

- [初代 The Merchant，固定页面修订 oldid=34207](https://slaythespire.wiki.gg/wiki/The_Merchant?oldid=34207)：Card Removal Service；Items；Relic Interactions。2026-10-23 通过网页检索读取当前初代页面，返回检索内容明确标注上述修订链接。该页与二代同名页面区分。
- [初代 Map Locations](https://slaythespire.wiki.gg/wiki/Map_Locations)：Merchant 节明确每店一次；Monsters/Boss 节列奖励范围。
- [初代 The Cleric，页面修订 oldid=55508](https://slaythespire.wiki.gg/wiki/The_Cleric?oldid=55508)：Options 与出现条件；2026-10-23 检索读取初代页面。A0净化是50，页面括号75仅A15+，不能拿来当A0价。
- [初代 Purifier](https://slaythespire.wiki.gg/wiki/Purifier)：全幕神龛，Pray移除所选牌、Leave无事，未列金币前置；2026-10-23检索读取。[Events](https://slaythespire.wiki.gg/wiki/Event) 表明事件与神龛有独立选择流程；当前固定内容不实现该随机过程。
- [初代 Rest Sites](https://slaythespire.wiki.gg/wiki/Rest_Sites)、[Chests](https://slaythespire.wiki.gg/wiki/Chests)、[Unknown Location](https://slaythespire.wiki.gg/wiki/Unknown_Location)：后续核对入口，本轮未据此改变算法，不能标已核实。

## 可复核账本

| 项目 | 来源值/算法/顺序 | 实现位置与当前差异 | 验收输入 → 预期 | 本轮状态 |
|---|---|---|---|---|
| 删牌次数 | Merchant / Card Removal Service：每店仅一次；先选永久牌再成交 | `abyss_nodes.removeCard` 用节点标记防重；`abyss_node_ui` 只读 `removeAvailable` | 同店资金充足，删 UID A 再删 UID B → 第二次拒绝，金币/牌组/计数/随机状态不变 | 已修，本地回归 |
| 删牌递增 | 初次 75，每在商店购买一次增加 25；非每进入店增加 | `rules.shop.removeCard/removeCardIncrement`；`run.shopRemoveCount` 跨店 | 同局第一店花 75，第二店花 100；新局恢复 75；失败不累计 | 配置与机制已对应；既有跨店集成回归加入一次性断言 |
| 删牌修饰 | Smiling Mask 固定 50；Membership Card 半价但 Mask 覆盖；Courier 八折及组合 | 当前纳入的七遗物没有上述三件，未实现对应修饰；后续纳入时必须另加顺序回归 | 未纳入内容不可出现在供应池或被当作已实现 | 不计严格全项通过 |
| 删牌末张限制 | 本轮来源没有证明原版禁止空牌组 | 当前 `last_card` 是 `Combat.new` 非空牌组前提，仍有差异 | 一张牌时拒绝且不收费；买卡后仍可用服务 | **保留已知偏差，待空牌组战斗支持** |
| 职业牌库存 | Merchant / 5 Colored Cards：2攻击、2技能、1能力，随机一张五折；另有2无色牌 | 当前遍历可玩池全部上架，没有原版抽取/无色供应/折扣 | 必须有稀有度、偏移、类型约束、随机流与折扣边界证据再改 | 未修 |
| 职业牌价格 | Merchant：普通45–55、罕见68–83、稀有135–165；无色加20% | 当前固定50/75/150；不能只按范围做均匀整数采样冒充原版浮点+取整分布 | 固定随机源上下界、半整数取整、折扣前后顺序 | 精确采样/取整代码待核实，未修 |
| 遗物供货/价格 | Merchant：3件，右侧为shop；另两件common50%/uncommon33%/rare17%；common/shop143–158、uncommon238–263、rare285–315 | 当前所有未持有非初始遗物均售固定150；未建立原版遗物池消耗与商店尾端抽取 | 不可把内容支持池直接均匀抽样声称原版概率 | 待核实算法，未修 |
| 药水供货/价格 | Merchant：3瓶；common65%/uncommon25%/rare10%；价格48–53/71–79/95–105 | 当前商店不售药水；纳入池无rare，不能把rare10%偷分给已有药水 | 保持原版稀有度概率需明确完整池或未支持内容处理，及槽满原子拒绝 | 已定位，未凭空补全 |
| 战后金币 | Map Locations：普通10–20、第一二幕Boss95–105 | `rules.rewards` 固定15/100；精英、Boss顺序与独立随机流需进一步核对 | 可控随机上下界；不得把中值视为原版分布 | 未修 |
| 战后卡牌/药水 | 需核对稀有度偏移、升级概率、药水动态计数及随机流；原文完整算法本轮未取得 | `abyss_run` 当前均匀支持牌池且过滤条件/X牌；暂无药水掉落 | 计数累积/重置、重复领取、满槽与领奖顺序 | 待原作证据；不改其他agent边界 |
| 圣职者入口与治疗 | Cleric：仅第一幕，至少35金币才出现；治疗付35，回复最大HP25%向下取整 | `rules.events.cleric` / `Nodes.enter` / `chooseEvent`；仅当明确eventId/config指定Cleric时进入，没有完整事件池抽取 | 明确Cleric的34金币入口拒绝且地图/RNG不变；35可进入；83最大HP治疗20；临近满血封顶 | 本地修复/回归；非全事件概率验收 |
| 圣职者净化与离开 | Cleric：A0付50删所选牌；Leave无事 | `Nodes.purifyEvent`/`chooseEvent`；净化不计商店次数、不改变UID分配；末张牌限制仍是已知平台核心差异 | 49金币拒绝，50成功删除指定重复牌UID，`shopRemoveCount`不变；离开不改资产；失败后可离开 | 本地修复/回归 |
| 净化神龛与低资金路径 | Purifier：祈祷移除所选牌，没有金币代价；或Leave无事 | `rules.events.purifier.removeCost=0`；命令按明确事件身份区分pray/purify；末张牌限制仍为核心偏差 | 零金币可进入、祈祷或离开；连续两层所有下一节点都是事件仍可Leave推进，不消费随机数；重复领取拒绝 | 本地修复/回归 |
| 未知房/事件池/宝箱/营地 | 原版有未知房动态概率、事件选择条件、箱型池、回血取整与升级限制 | 自创金币/药水事件已删除；`rules.events.encounterId=purifier`是固定支持内容，**不是原版事件/神龛抽取算法**；不按金币不足换roll、不实现动态转类；普通箱及营地仍待全项核对 | 不可把固定Purifier内容或两个已纳入事件当作原版全池概率；明确Cleric资格不符则原子拒绝；production固定Purifier无此资金软锁 | **未修完整抽取，不计全项通过** |

价格资料还存在边界差异：[旧Fandom Merchant](https://slay-the-spire.fandom.com/wiki/Merchant) 给罕见牌上界82及普通药水上界52，当前Wiki.gg则为83/53。它们都不能替代PC目标版本的随机浮点及取整实现证据；本轮没有据此制造均匀整数价格。

## 本地验证边界

`tests/lua/nodes.lua` 覆盖失败不消费、重复同/不同 UID、单店用尽后仍可购卡/离店、view不能重置服务、跨店计数、新局复位。跨店测试使用低血敌人和充足金币的显式事务夹具，只验证状态传递，不作为平衡通关证据。`tests/lua/node_ui.lua` 覆盖禁用状态、切换分类后仍禁用、其他调用已消费服务时旧 UI 请求由核心拒绝。未引入新随机抽样，因此无需统计样本；全量快照拒绝断言覆盖既有随机种子不变。

不勾 TASK-13.1 全部验收项；原版严格全项、平台交易账本、真实机验收继续待办。

事件切片由 `tests/lua/cleric.lua` 独立覆盖Cleric六组和Purifier/低资金路径两组场景；节点UI回归覆盖治疗、资金不足、离开、分页UID净化、选牌前取消、陈旧资金重验及零金币神龛两选项。`tests/lua/inventory.lua` 原本依赖虚构事件赠药的夹具已改为Leave，继续验证真实携带药水跨节点保留/消耗，不再制造额外药水。
