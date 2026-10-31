# 四件遗物的公共触发链补证

基线 `ca838ef`，独立 `test/m3-relic-public-chains`。这是 **TEST_ADDED**：四件原效果已存在，新用例首轮在原生产实现通过，不宣称修复了生产缺陷或伪造生产RED。没有修改源码、定义、池、RNG、成本、runner或原30秒单夹具预算。

固定依据为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 `EternalFeather.java`、`LetterOpener.java`、`HandDrill.java`、`Brimstone.java`。本轮实际重新读取四份原文；SHA256、Git blob、字节数和方法事实见 `tests/fixtures/m3-relic-public-source-lock.json`。预期是独立字面量，不调用生产遗物hook生成expected。镜像不等于原作PC二进制认证。

`node --test --test-concurrency=1 tests/m3-relic-public-chains.test.mjs`：3/3通过、零skip，约12.6秒；三个Lua夹具分别约7.57/3.12/1.70秒，均沿用默认30秒。

| 遗物 | 实际命令与断言 | 明确受控的前置 |
|---|---|---|
| Eternal Feather | 真实`Run.obtainRelic`、`Nodes.enter`营地。0/4/5/9/10/14/15张牌分别回血0/0/3/3/6/6/9；反复view及拒绝重复enter不再回血；公开rest只另回血24，重复rest拒绝；Bloom同时阻止入场和休息回血 | 新Run的合法永久牌组数量、20/80生命、当前可用地图节点类型设为营地；不替换节点处理器或hook |
| Letter Opener | 真实`Run.play`三张技能对全部两敌各5伤；前两张不触发。真实`Run.endTurn`后先积2技能，再下一回合第1张不触发，证明部分计数重置。实际药水击杀、公开领奖/离开后同Run新战斗重新第三张才各5伤 | 10张Defend永久牌组保证手牌、真实已持有爆炸药水；使用现有敌人和原行动/能量/伤害，无直接调用遗物hook、改计数或强制结局 |
| Hand Drill | 真实Strike攻击：4盾时第一击只扣2HP，随后队列才施加2易伤，第二击扣9；20盾未破和0盾均不误触。无遗物对照破盾后第二击仍6 | 10张Strike永久牌组与敌人初始block=0/20/4；不改敌人HP、攻击、hook或伤害函数 |
| Brimstone | 真实开战和连续两次`Run.endTurn`后，玩家力量2/4/6、每个敌人1/2/3；无遗物对照初始无力量 | 固定seed42、真实双虱敌人；没有直接调用turnStartActions或修改力量 |

三个原始Lua入口为 `m3_relic_public_camp_skills.lua`、`m3_relic_public_hand_drill.lua`、`m3_relic_public_brimstone.lua`。原有direct-hook、Artifact/Bloom、计数及其他组合用例保留；本片不取代它们，不补造全153所有组合完成声明。

这是受控离线公共API覆盖，不是自然遇见/自然取得、官方导入、ready、同候选PC/手机或视觉/性能验收。源码独审和最终组合CI分别办理，冻结PR436未修改。
