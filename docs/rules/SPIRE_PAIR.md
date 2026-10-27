# 第四幕盾矛独立组件

固定来源为 `sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；ZIP成员及原始字节SHA256见 `tests/fixtures/spire-pair-source.json`。本片提供规则组件和独立向量；未接入Act4的Run/Combat/呈现，不代表终幕可达或自然通关。

## A0规则

构造和行动数组顺序为盾、矛。盾110生命，位置(-1000,15)；矛160生命，位置(70,10)。两者固定生命也各消耗一次monsterHpRng的0..0抽样。开战各获得1层人工制品；盾先给玩家包围。玩家初始朝右，盾在背后。

盾的Bash为12伤害后玩家失去1力量或集中。判断发生在takeTurn排队时：有充能球槽（包含空槽）才额外抽一次aiRng Boolean，true减集中，否则减力量；零槽不抽Boolean。Fortify按敌人顺序分别给予30格挡。Smash为34基础伤害，随后给予盾该次DamageInfo.output等量格挡；这是排队时冻结的修正后伤害，包含背刺，不是基础34或玩家实际损失生命。

矛的Burn Strike是5伤害两次，随后两张灼伤进弃牌堆；不能改成进抽牌堆或每堆各一张。Piercer按敌人顺序分别加2力量。Skewer为10伤害三次。重复伤害保持独立动作，不能合成一次伤害；已排队的临时牌和RollMove是否保留由共享源动作管理器处理。

每次getMove（包括初始化）先消耗random(99)，即使忽略num。盾的计数余数0额外抽Boolean：true防御、false Bash；余数1选择前次未使用的另一招；余数2 Smash。矛余数0通常Burn，若前次就是Burn则Piercer；余数1 Skewer；余数2额外Boolean：true Piercer、false Burn。每次计数增加。已排队的RollMove不因来源死于反伤而自动取消，仍有另一敌人时保留。

## 共享层合同

`register(catalog,copy)`只注册独立敌人与Power定义，重复定义拒绝。`resolve(source,tier)`仅接`Shield and Spear`精英；父线程负责Run Act4入口。`initialize/afterAction(state,enemy,random)`使用现有1起始整型adapter及真正的Boolean adapter，不把Boolean冒充random(99)。`preBattle(api,state,enemy)`需要`applyPower/isActive/removePower`；模块不依赖Actor，避免Actor死亡钩子的循环依赖。

`takeTurn(state,enemy,random,snapshotDamage)`返回冻结的动作描述数组，末项总是`kind='roll'`。`snapshotDamage(state,enemy,base)`返回普通DamageInfo.output（已经完成普通取整，尚未背刺）。动作kind为damage/power/block/discard/roll，含sourceId、targetId；damage带base value和normalAmount，power带status/value，discard带card/value，roll带捕获intentId。这不是通用卡牌effect ABI。共享层必须在takeTurn时整体创建，再按源动作顺序执行；不能交给原有不完整intent.effects直接运行。原有Effects门禁本片不放宽。

`faceTarget(api,state,target)`仅在合法玩家指定目标卡（ENEMY、SELF_AND_ENEMY）或指定目标药水排队时调用；AoE、无目标卡、随机命中、预览及拒绝请求不得调用。`refreshFacing`更新BackAttack标记；`backAttack`从包围和朝向推导伤害资格。已有Smoke的BackAttack拒绝可复用，但必须保持标记同步。

`actualDamage(state,enemy,ordinaryOutput)`在普通output取整后用binary32乘1.5再截断。`intentDamage(state,enemy,preFinal,finalReceive)`在最终修正前先乘1.5截断，再调用最终修正回调并向下取整。Weak+Vulnerable下盾Bash的普通output13、背刺真实19、意图20是原来源的不同计算路径，不能用同一值抹平。

`died(state,enemy,enqueue)`在原die位置调用：立即面向存活者，BOTTOM排队removeStatus描述（targetId/status）移除玩家包围和存活者背刺。已排队标记防止重复；不会自行执行队列。父层负责实际Power删除、动作中断、反伤源顺序和完整事务回滚。普通战斗、原创V4、最终Boss没有被本片接线。

## 验证边界

`tests/lua/spire_pair_component.lua`验证组件AI、动作快照、真实Actor修正数值和注入Power回调；不是完整Combat/Run流程。独立Python解释器不读取Lua或产品定义，8组seed×空槽情况、每组6回合锁定共享AI完整状态；JSON与Lua使用同一独立输出。源锁绑定组件、回归、向量和规则说明，避免只改产品后继续引用旧来源证据。

定向命令：`node --test tests/spire-pair-component.test.mjs`，Lua仍保持30秒上限。父组合必须补真实战斗、药水转向、Power/队列及失败回滚回归，之后再谈完整终幕和平台验收。

2026-10-28本片先以缺组件断言真实RED（250ms），实现后校准了真实Actor未持有新Power时为nil的夹具表示。最终10组组件GREEN（784.8ms）、Node2/2通过；独立8×6回合向量再生成与JSON/Lua逐字一致，两份Lua按5.3解析通过，新模块固定Luacheck1.2.0零告警，diff检查通过。未跑全量或任何GUI，未修改共享接线与门禁。
# 组合复审：自动牌的朝向

只有手动指定敌方目标的出牌和定向药水改变朝向。Havoc、Mayhem、复制等自动队列直接调用 useCard，不经过 AbstractPlayer.playCard 的转向入口。真实自动定向队列先复现错误翻转；转向移至手动 native 发牌入口，并在 advanced 入口排除 automatic 后，两个实际解析器与 Havoc 公开出牌路径均保留原朝向。免费手动牌仍按指定目标转向；原药水、取整、死亡及回滚回归保持，总10组。
