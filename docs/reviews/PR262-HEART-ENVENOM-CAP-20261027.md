# PR262：无敌归零时不得构造淬毒动作

复核基线为 `61b19351fbcd9b3528544dded6216c13e0f37490`，树 `b344a4335001a73d6049d960b16cc669370372ef`。相对前一头 `79e76774` 只有评审文档及界面夹具改动，相关战斗源码相同。

## 来源与真实缺陷

固定来源 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，已重新读取本地固定来源缓存并核对 SHA-256：

| 来源 | SHA-256 | 约束 |
|---|---|---|
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L608-L650) | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` | 先扣格挡及执行目标 `onAttackedToChangeDamage`，再调用来源 `onAttack`。 |
| [InvinciblePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/InvinciblePower.java) | `867243138178bfae4ed506bab3c4e013734efd96756b7e21ee347f3b576e9bb1` | 此回调返回额度允许的伤害并消费额度，零额度返回零。 |
| [EnvenomPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/EnvenomPower.java) | `f5624c590e288208e5517a0c02e586593bd9e7a9962134c53059e35fb42a534e` | 只有正伤害、非自身目标、NORMAL 才构造 PoisonPower/ApplyPowerAction。 |

现有 Combat 在 Actor 消费无敌额度前，把只扣格挡的正伤害传给 Envenom。真实公开 `Combat.play` 连续三张 Strike、额度依次设为 `0→1→1`、初始人工制品 1：

| 检查点 | 旧代码 | 修复后／来源预期 |
|---|---|---|
| 心脏生命 | `750 / 749 / 748` | `750 / 749 / 748` |
| 人工制品 | `0 / 0 / 0` | `1 / 0 / 0` |
| 中毒 | `nil / 1 / 2` | `nil / nil / 1` |
| 已构造淬毒动作累计数 | `1 / 2 / 3` | `0 / 1 / 2` |

因此不是显示问题：零伤害会错误消耗人工制品；没有人工制品时会错误施加中毒。

## 最小修复及验证

- 从现有 Heart `capDamage` 抽出纯函数 `incomingAmount`，保留原所有者限制、额度校验与零身份。Combat 仅用它为既有 Envenom 构造判断提供额度后的伤害；Actor 仍唯一实际消费额度。没有替换第四幕、Continue、地图或其他结算所有者。
- `node --test --test-concurrency=1 tests/heart-envenom.test.mjs`：新增四组通过；覆盖 native/advanced 两种真实用牌队列、`0→1→1`、零额度不构造 Poison、纯预览不消费及实际只扣一次、全格挡不消费人工制品／额度。
- 将 Combat 单独退回精确基线时，新回归在“零额度不能消耗人工制品”断言真实失败（541ms、退出 1）；恢复修复源码后 hash 一致。原始三步探针亦先红后绿。
- Heart 三个 Node 文件共 4 项通过（组件 8 组、真实 afterUse 8 组、新回归 4 组）；原 `card_triggers.lua` 的组件 29／真实用牌 21 组通过（9833ms）；`silent_poison_build.lua` 21 组通过（2539ms）。保留每份 Lua 原 30 秒上限。
- 架构通过：207 模块、1210 条边。固定 Luacheck 1.2.0 零新增诊断，84 条既有警告；受治理复杂度门槛通过。未改静态基线或测试时限。

外部原始日志与来源校验收据位于本轮工作区 `pr262-heart-envenom-evidence/`。根执行者另独立运行新增回归 1/1 通过。上述均为受控离线证据；新提交完整 Quality、合并、同源原生导入／实测及四职业自然四幕没有因此取得，不关闭 TASK-64 的现有缺项。未运行地图来源对抗探针。
