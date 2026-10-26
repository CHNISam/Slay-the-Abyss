# Tungsten Rod：独立复审与牌面失去生命修复

审查冻结头：`ff01ba077b5c61881b87c8bc3e4436793c728a0f`。作者树保持只读；修复树为 `m3-tungsten-card-hp-loss`，从该头独立创建。本片只修一个已复现 P2，不变更遗物目录、事件 API、减伤数值或队列规则。

## 发现与最小修复

公开 `Run.removeCard / obtainCard / obtainRelic / startCombat / play` 路径，真实 Bloodletting、Offering 和 Hemokinesis 的基本及升级版，持有真实 `tungsten_rod` 时仍分别失去 3、6、2 HP，应该为 2、5、1。使用数字种子 42；未注入 HP、能量或 RNG。源定义和原牌的伤害、能量、弃牌/消耗效果保留。

原因是 `abyss_effects.lua` 的 `op='loseHp'` 独立扣血路径只调用 Intangible 和 Buffer；原 Rod 只接入 Actor 和事件路径。这里不是 `Actor.loseHp` 的调用者，原来的通用 HP_LOSS 测试无法覆盖它。

修复在原扣血前，且仅 `source == state.player` 时调用现有 `RelicHooks.onLoseHpLast`。顺序为 Intangible → Buffer → Rod → 扣实际 HP → 原 HP-loss/Fairy 通知；不调用 Actor 的第二套通知，不重复扣减，不把玩家遗物用于敌人。保留原 Effects 事件、来源与后续动作语义。

## 固定源核证

独立逐字读取固定 ZIP `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`，归档 SHA-256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。原 `tests/fixtures/tungsten-rod-source.json` 的全部九个成员原始字节 SHA-256 均一致；该旧锁未改。

`Bloodletting.use`、`Offering.use`、`Hemokinesis.use` 生成 `LoseHPAction`；后者 `update` 第 36 行调用 `target.damage(new DamageInfo(source, amount, HP_LOSS))`。`AbstractPlayer.damage` 第 1416 行在三种 damage type 的共同路径调用遗物 `onLoseHpLast`；`TungstenRod.onLoseHpLast` 只将正值减一。不能因为是牌面失去生命而绕开遗物。

补充读取成员（均为该 ZIP 的 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0/` 前缀）：

| 成员 | 原始字节 SHA-256 |
|---|---|
| `cards/red/Bloodletting.java` | `8af1b938ea918e3d2c8cc99d104b8259ae71c310cc6534a583269523915b485e` |
| `cards/red/Offering.java` | `41daeb17f76e33cfb736c89b613e8e8534a535bf24ad4a7a6dc777b11b33bf76` |
| `cards/red/Hemokinesis.java` | `28729f7bc1e2d48d7cbdc45336126a93d454d9350d8c2f17eef42c5d6349b6c7` |
| `actions/common/LoseHPAction.java` | `50c9ea9f1aef4a02ff9177d59517f61b03941e9770a23bc50bed8e3d60d69670` |

## 实际红绿证据

固定 Node `F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe`。以下 Lua 均以导出的 `runLua(path,{timeout:5000})` 执行并检查真实 `result.status`；既有 runner/原断言和原预算没有修改。

| 用例 | 原 ff01 | 修复后 |
|---|---|---|
| 临时公开 Run 两例反例 | Bloodletting 3≠2、Offering 6≠5；status 1，1110 ms | 覆盖于永久用例 |
| `tungsten_rod_card_hp_loss.lua` | 六个基本/升级实际减伤断言失败；无 Rod 对照通过；status 1，3850 ms | 7/7，status 0，2242 ms |
| `tungsten_rod_card_hp_loss_edges.lua` | 新边界回归 | 6/6，status 0，1648 ms |
| 既有 `tungsten_rod_interactions.lua` | 此轮不重复跑旧头 | 4/4，status 0，1983 ms |
| `node --test tests/tungsten-rod-source.test.mjs` | 此轮不重复跑旧头 | 2/2，104 ms |

新边界涵盖 Block 不影响 HP_LOSS、Intangible 后 Rod 归零且不通知 HP 损失、Buffer 先消费、零值、敌人不借用玩家 Rod、致死与非致死 Fairy 物理库存，以及真实公开 Run 晚 `hpChanged` 抛错后完整值/原战斗/玩家/手牌/卡对象/RNG/永久牌组身份恢复和同 UID 重试。低 HP 和显式 Power 是组件边界，不冒充自然取得/自然通关；公开牌面六例和晚失败例没有注入 HP/能量/RNG。

新测试首次试跑的 `damagedThisCombat` 预期误写为损失数值，随后按既有 HP-loss 通知定义修为每次正损失计一次；六个核心减伤 RED 均在此断言前触发，修正不改变发现。

复现导出 runner（PowerShell，当前目录为本树）：

```powershell
$node='F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node --input-type=module -e 'import {runLua} from "./scripts/test-lua.mjs"; const t=Date.now(); const r=runLua("tests/lua/tungsten_rod_card_hp_loss.lua",{timeout:5000}); console.log(JSON.stringify({status:r.status,ms:Date.now()-t,stdout:r.stdout,stderr:r.stderr})); process.exitCode=r.status;'
& $node --input-type=module -e 'import {runLua} from "./scripts/test-lua.mjs"; const t=Date.now(); const r=runLua("tests/lua/tungsten_rod_card_hp_loss_edges.lua",{timeout:5000}); console.log(JSON.stringify({status:r.status,ms:Date.now()-t,stdout:r.stdout,stderr:r.stderr})); process.exitCode=r.status;'
```

工程检查：JavaScript syntax 通过；architecture 156 模块/900 边通过；固定 Luacheck 1.2.0 无新增诊断，保留原 105 条历史诊断，受控 UI 每函数 ≤15、主 battle render ≤10。本片没有修改诊断基线或任何豁免。

## 复审结论与边界

除上述一个 P2 外，本次未发现 Rod 新增的有证据 P1/P2。静读核对了 Buffer → Static 的正伤判定 → Rod → 最终 HP-loss 通知，NORMAL/THORNS/HP_LOSS、Block、Intangible、零值和多段的玩家归属；事件 hook 没有重复减伤，`eventNormalDamage` 只解除 Rod 缺口拒绝，Lizard 保留拒绝。真实 Rare 定义及现有商店/宝箱取得接线、原图回滚路径均有原作者定向证据；此轮只重跑必要 4 个交互例和 2 个 source/catalog 例，未重跑作者完整 16 例或 heavy gates。

既有支持池取得不等于完整原版遗物概率迁移。Buffer 的同步消层与源 TOP 动作的通用时序差异、Golden ledger 缺 mapping、旧 Orich 前置失败均不在本片扩大修复。未运行全 check、自然完整流程或平台/实机；父集成组合仍需验证 Orich 和晚 Run 包装等共享路径。
