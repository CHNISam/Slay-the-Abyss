# 同优先级死亡能力保序

固定来源：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，社区反编译镜像；未认证为授权 PC 二进制，也没有本轮原作或平台实测。

`AbstractMonster.die` 遍历已排序能力；`AbstractPower` 默认 priority=5，同优先级保持获得顺序。`StasisPower.onDeath` 和 `CorpseExplosionPower.onDeath` 都追加到现有动作管理器的 BOTTOM。

组合差异：Actor 固定先调用尸爆，再调用第二幕死亡钩子；尸爆直接写 native 队列，Stasis 则进入实际动作拥有者。原生路径固定尸爆先，advanced 路径固定 Stasis 先，均抹掉获得顺序。先 Stasis 后尸爆且尸爆击杀最后队友时，原生路径丢失本应先归还的扣押牌。

实现只调整已有死亡边界：Actor 按实际 powerOrder 分发这两个原版 priority=5 能力；二者均进入现有 enqueueReaction 拥有者。Boss 子类死亡行为仍在能力之后分发，保留 TOP Suicide，Spore 的 TOP 反应保持原状。已排队的尸爆伤害保留原版胜利后 DAMAGE 行为。

新回归 `death_power_order.lua` 使用真实 Strike、Bronze Orb/Stasis、Corpse Power 和公开 Run.play；包含两种动作拥有者、正反获得顺序、致死/不致死、故障后引用/随机流/能力历史回滚及同 UID 重试。11组原预算30秒，无随机池调整或断言删减。旧生产副本：6/11通过、5/11真实顺序断言失败；修复后11/11通过。原始红例日志保留在独立执行树 work/death-order-red/output.log，不充当实机证据。

来源全文身份仅用于只读依据核对，不在本仓库复制第三方实现。

| 来源文件 | SHA256 |
| --- | --- |
| `monsters/AbstractMonster.java` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| `powers/AbstractPower.java` | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| `powers/StasisPower.java` | `294790c903c94558dcdb5e4ebb9e2eba57c48cc6abf54428d09d1e3de3314870` |
| `powers/CorpseExplosionPower.java` | `7da1db8b92cbe48cdda233f0cd3575fde953c0540e9d62e22e8ad2b0e31ab4dd` |
| `powers/SporeCloudPower.java` | `c46ccba50ce667bf5d9a00c8ade4c190bacace7a9a2a7f3a9bf43adc14cd05bd` |
| `monsters/city/TheCollector.java` | `c8a4a7e564cd1f0612758a546eb9bd703ec447f88c0f571ccd826a4a94123bfe` |
| `monsters/city/BronzeAutomaton.java` | `e05adeb2dcbcf1259e83e9123daf193c7357360d9a502795feefd3a337ebc8ea` |

针对性验证：新11组与Node包装通过；原 Plated49、Act2敌人34、Transient19组通过，Silent final runtime/edges 两份原夹具通过。固定 Luacheck 实际执行，四个生产文件均零诊断；未修改静态基线。初始只读审查时还通过 Shapes17、Sharp Hide边界6、Sharp Hide真实TOP抽牌、回合弃牌4、Shapes Defect组合、Maw/Growth18。该独立树固定于9f45d5f，架构检查因父线程尚未在此快照登记Joust模块而失败；父线程已在自己的后续接线中登记，新修复不新增模块，完整架构/Quality由最新整合SHA继续验证。
