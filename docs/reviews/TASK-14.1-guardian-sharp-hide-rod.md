# Guardian Sharp Hide：复用真实 THORNS 路径

基线为独立卡 HP-loss 修复 `1b6c22902339f8a11543e107d197f6120144cc82`，其前置 Rod 为 `ff01ba077b5c61881b87c8bc3e4436793c728a0f`。本片是后续独立提交；没有改作者树、Backlog、Combat 队列、AI 意图/roll、旧来源锁或测试预算。

## 实证 P2

实际公开 Run：数字种子 42，公开删除初始牌、获得 Bludgeon 和 Rod，显式进入 boss floor 后 `startCombat('boss_guardian')`。首个真实 Bludgeon 造成 32 伤害，守护者从 240 降至 208，触发防御姿态；公开 `endTurn` 执行真实 Close Up，才获得 Sharp Hide 3。下一次真实攻击损失 3 HP，源义应在 Rod 后只损失 2。

独立临时公开反例 status 1，944 ms。永久 `guardian_sharp_hide_rod.lua` 在修复前同时复现“活 owner”及“攻击杀死末敌后保留的反伤”两个 3≠2；无 Rod 的 3 点对照通过，1944 ms。死 owner 由真实 20 次升级 Searing Blow 的攻击杀死，没有改敌 HP 或注入 Sharp Hide。

问题位于 `Guardian.afterCard` 的手动减 HP 分支，它绕过 Intangible、Buffer、Rod 和 `hpChanged`，虽然通知入口已有部分 Fairy 支持。

## 最小实现

`Guardian.afterCard` 按捕获的 id 查找原 owner（包括死亡 owner），调用现有 `Actors.retaliate`。Actor 只增加一个受限可选第五参数 `status='sharp_hide'`，复用原 `directDamage` 发出相同的 `status_damage` 证据格式；默认四参数仍使用 `status='thorns'`。不另发重复事件或 HP-loss 通知。

此路径使用原 Intangible → Block → Buffer → Rod → 实际 HP-loss/Fairy/遗物通知。保持 THORNS 忽略攻击修正、不会递归触发玩家 Thorns、不借此触发 Rupture；不增加活 owner 限制，也不改变捕获量、卡牌抽牌或反伤入队时点。

## 固定源

新增 `tests/fixtures/guardian-sharp-hide-source.json` 独立锁定 11 个原始 ZIP 成员 SHA-256，旧锁不变。固定版本 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`；本机只读 ZIP：

`F:/New folder/.artifacts/sts1-fixed-source/sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`

归档 SHA-256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。独立 Python 逐成员读取/计算后生成新锁；JS 校验新成员的固定 hash 以及复用成员与原 Rod 锁一致。

- `TheGuardian.useCloseUp` 176–183：A0 加 SharpHide 3；先 Mode Shift 不是立即持有 Sharp Hide。
- `SharpHidePower.onUseCard` 39–42：ATTACK 每张排一个 BOTTOM `DamageAction`，类型 THORNS，与命中数和是否造成正伤无关。
- `DamageAction.update` 60、65：THORNS 不因 owner 死亡而取消；83 调目标 damage，84–85 清理胜利后动作。
- `GameActionManager.clearPostCombatActions` 119–124：保留 DAMAGE，与 Heal/Block/Use 相同保留。
- `AbstractPlayer.damage` 1378–1416：Intangible 后 Block，Buffer 的 onAttackedToChangeDamage 先于 Rod 的 onLoseHpLast；实际正 HP-loss 才通知，最终致死按原 Fairy 逻辑。

## 实际验证

固定 Node24；新 Lua 显式使用 `runLua(path,{timeout:3000})` 并检查真实 status。旧 Lua 通过同一导出 runner 使用未修改的原默认预算。

| fixture | 结果 / 实际时间 |
|---|---|
| `guardian_sharp_hide_rod.lua` | 3/3，1847 ms |
| `guardian_sharp_hide_modifiers.lua` | 8/8，1237 ms |
| `guardian_sharp_hide_death_rollback.lua` | 7/7，2269 ms |
| 原 `guardian_ai.lua` | 原 24/24，2622 ms |
| 原 `guardian_death_tail.lua` | 原 5/5，983 ms |
| 原 `guardian_opening_roll.lua` | 原 14/14，1240 ms |
| `node --test tests/guardian-sharp-hide-source.test.mjs` | 1/1，101 ms |

新覆盖包括真实 Close Up、死末敌、双死 defeat 唯一结算、Fairy 保命后胜利、零伤攻击每张一次、Intangible、Buffer、完整/部分 Block、HP-loss 次数、THORNS 修正/不递归边界、默认四参数事件兼容、真实 Run 晚失败原 graph/UID/RNG/Sharp Hide owner 还原，以及 Fairy 已消耗后再失败的物理库存原引用还原/同 UID 重试。没有使用伪造适配器；低起始 HP/显式 Buffer 和攻击修正是公开标注的组件边界，Sharp Hide 本身始终由真实 Close Up 获得。

实际 Anger 产生真实弃牌副本后，Pommel Strike 从这些牌抽牌；Sharp Hide 的 detached frame 已含抽到的 Anger，证明反伤仍在抽牌之后。首次新断言曾查找引擎不存在的独立 `draw` 事件，随后改用已有 reshuffle 事件和实际 frame 手牌证据，没有改生产抽牌逻辑。

architecture：156 模块/900 边通过；固定 Luacheck 1.2.0 无新增诊断，原 105 条历史诊断/受控 UI 复杂度门禁保持。旧诊断基线未变。新 fixture 由既有全部 Lua 扫描自动登记；没有新生产模块或架构豁免。

本片没有运行全 check 或平台/实机；显式 boss 入口及高升级卡是组件边界，不称自然整局取得/通关。原完整遗物池迁移和其它尚缺 owner 仍是各自任务，不因本片宣称齐备。
