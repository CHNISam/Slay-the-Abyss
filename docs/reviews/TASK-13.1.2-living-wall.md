# Living Wall 独立事件实现

基于 PR193 合并提交 `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。本片新增正式事件 handler `living_wall` 和原生事件/永久牌选择接线，**没有加入现有 restricted-seven 概率池**，不代表完整事件池、全部卡牌或平台验收。

## 固定原版对照

直接读取用户指定的 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` ZIP。这是固定社区反编译镜像，不是已认证 PC 二进制。[完整文件 SHA256/Git blob 与 ZIP 身份](../evidence/living-wall/source-identities.json)。

- `LivingWall` 构造器按 Forget、Change、Grow 排列；仅 Grow 在没有可升级牌时禁用，没有独立 Leave 选项。
- Forget/Change 的组来自 `getGroupWithoutBottledCards(masterDeck.getPurgeableCards())`：排除 Necronomicurse、CurseOfTheBell、AscendersBane 和三个瓶装标志。`CardGroup.addToTop` 实际执行 `group.add(c)`，保持永久牌组顺序。
- Grow 的目标来自 `getUpgradableCards()`，可以选瓶装牌；但 `buttonEffect` 打开升级组前也检查同一可移除且非瓶装组。该组为空时，即使有可升级瓶装牌，也直接进入结果且不改牌。
- 选择按钮后锁定选项；非空组必须选一张当前合法 UID。空组正常进入结果。变换/移除可以删掉最后一张，不创建替代基础牌。
- Change 先删除旧卡，再 `transformCard(c,false,miscRng)`，通过 `ShowCardAndObtainEffect` 获得全新未升级卡。本实现保持新 UID、追加位置和单次领取，原子提交牌组/nextDeckUid/misc。无效 UID、资格变化、缺内容、无效新 UID 均保留原牌和全部 RNG。
- 变换选择器复用已验候选 API：有色牌顺序为当前 common + srcUncommon + srcRare；无色为 srcColorless；诅咒为 CardLibrary.curses 枚举顺序，排除原牌与四个特殊诅咒。只调用一次有界 misc 包装，不加稀有度抽样或重抽。

## 与完整池父线的接口

`Nodes.enter` 接受显式事件 `living_wall`。选择调用 `Nodes.chooseEvent(run, 'forget'|'change'|'grow')`；返回 `choose_card` 时保留当前节点并锁定选项，随后 `Nodes.chooseLivingWallCard(run, uid)` 或带同一 choice/uid 的 chooseEvent 完成事务。原生面板直接调用这两个正式命令，支持结果确认。

变换由完整池 owner 显式提供 `run.transformContext`：

```lua
{
  pools = {common=orderedSourceIds, srcUncommon=orderedSourceIds,
           srcRare=orderedSourceIds, srcColorless=orderedSourceIds,
           curses=orderedCurseLibraryIds},
  cards = { [localId] = {sourceId=originalId, category='colored'} },
  sourceToLocal = { [originalId] = localId }
}
```

category 还可为 `colorless` / `curse`。候选数组必须是完整且当前正确的源数组，不能从现有可玩卡定义反推或缩池；映射只解析抽样结果，不参与过滤。当前未自动初始化该上下文。未提供上下文、抽到缺定义或能力未实现的牌时 `event_content_unavailable`，不删牌、不消费流、不重抽。这是暂未齐备守卫，不是该分支最终可玩验收。

初版漏检：只检查定义存在，错误地接受了Clash等7个已有定义但战斗未实现的原型，原夹具也用同一‘有localId’条件认定成功。此P2在合并前补查发现，前次‘无P1/P2’对该守卫的判断已撤回。现在 `abyss_card_capability` 是变换、旧奖励/商店资格和升级共用的能力判定；不根据能量、回合或目标等临时能否打出来做判断。合法不可打的Regret/Dazed等已注册生命周期例外仍可用，未知诅咒/状态不一概放行。能力单测由独立首发清单核33项包含和7项排除；72槽变换另强制抽中每个排除项并核全部旧引用、UID、RNG不变，不重抽。

共享选择器位于 `src/lua/abyss_transform_card.lua`；`tools/candidates/transform_card.lua` 保持原 `select` API 的兼容入口。

完整池父线仍须接齐：75 红牌及无色/诅咒定义；永久升级模型对 Searing Blow 的可重复升级；移除钩子 `onRemoveFromMasterDeck`（例如 Parasite 的最大生命变化）；获得时 `onObtainCard` / `onMasterDeckChange`、Egg/Ceramic Fish/Darkstone/Omamori 等完整遗物钩子。本片没有扩卡牌效果、生命上限模型或遗物系统，不能把直接删表/追加新卡说成全卡钩子已齐备。

## 本地证据

- `tests/lua/living_wall.lua`：正式 Run+Nodes 显式事件入口，原版三选项、最后一牌、三个特殊诅咒/瓶装排除、Grow 瓶装/空组 guard、UID 失效、重复领取、完整 72 红牌槽逐一向量，以及缺内容/nextDeckUid 失败回滚。修复后27个实际已实现结果完成变换，45个保留整笔内容守卫；原先34/38的定义存在判定记录只作失败历史，不作可玩证据。红例10组1失败，修后10组全通过（9846ms，原30000ms预算）。
- `tests/lua/living_wall_ui.lua`：生成的原生树，真实注册点击→三种选牌→永久事务→结果；空组无死选择器，Grow 显示禁用态。
- 原候选 20 组与 empty_permanent_deck 8 组通过。一次 unknown_events 相关回归在原 30 秒预算超时，仅前四组有完成输出，未改预算、未当断言通过，也未运行全量套件。
- 原始红绿输出、耗时和最终结果 JSON 归档于根 `.artifacts/act1-living-wall-20261025/`。未构建/导入游戏候选、未桌面或平台实测，最终 CI/完整池统一接线由父线处理。
