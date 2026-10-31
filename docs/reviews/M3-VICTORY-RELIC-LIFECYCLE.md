# 胜利生命周期 F1 / F2 源差异

基线 develop `06366f7821dd91eb089ff8139056132981fa039c`，独立树 `/workspace/m3-victory-relic-counters`。不改已合PR437/root树/远端/Backlog；CLI在环境不可用。独审最后的道具差集先按F1独立提交，随后按root明确授权处理F2。没有扩大池、改概率或预算。

## F1：七件战斗计数的公开结算清理

独立重新读取固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 原文：LetterOpener、Kunai、Shuriken、OrnamentalFan、StoneCalendar、CaptainsWheel、Pocketwatch各onVictory设counter=-1；AbstractPlayer遍历持有遗物调用onVictory（玩家存活），AbstractRelic只显示>-1计数。新 `victory-relic-counter-source.json` 保存13份Java原始SHA256/Git blob双哈希及固定资格，不存方法体。额外读取SmokeBomb、AbstractRoom、AbstractMonster、MonsterGroup：Smoke动画及所有敌人逃离同样进入room.endBattle→player.onVictory，不能额外按allEscaped拒绝清理。固定字节来源清单有LF属性及严格SHA校验，没有OS动态路径键。

本轮复跑原公共探针，七件在reward/map仍显示计数，下一战已重置。新增更深公开路径先RED：真实取得五张小牌组和七件遗物，Neow真实令敌人1HP，Defend→DeepBreath（让永久Sundial真实到1）→Strike，胜利后LetterOpener仍为2。RED日志 `/workspace/cloud-reports/m3-victory-counter-red.log`。初稿eventDamage用于地图时被正确拒绝，已改为明确的40HP起始边界；不是生产RED。

修复增加Uncommon四件onVictory清理，公共RelicHooks.onVictory复用既有Rare三件hook。实际胜利的finish事务在publishBattleResult拷贝counter前调用；Smoke在其暂存battle中调用并发布candidate counter。败北不调用。不普遍清零Sundial、InkBottle、HappyFlower、Incense、Neow或全局充能。

回归通过真实Run reward→map和下一战检查七件隐藏/重新计数；下一战四件及Pocketwatch为0，Calendar/Wheel经过真实第一回合后为1。永久计数保持各自实际非零值，充能不变。40HP获胜仍严格Meat12→BurningBlood6→Cleric1，最后59HP/81maxHP；未重排治疗。正式source-room晚期奖励抽样后抛错，完整原Run图、所有原引用、计数/治疗/随机进度均恢复，重试只提交一次；重复finish不再触发。实际Looter正常逃离、Smoke和败北另验，source资格明确，不以旧残留当原版期望。

两个临时模块精准负控分别删公共胜利分派及Uncommon清理，均必须被公开七件隐藏断言拒绝，不能以任意错误冒充kill。五个JS入口各低于整入口10秒，Lua沿用30秒；根完整CI与fresh独审另外绑定。

F1阶段刻意只改计数；正常Smoke缺失胜利治疗已由审计确认是独立F2。F1里Smoke旧40HP断言只是保留该阶段资源现状，**不是固定源认可**；下一独立F2提交将改为正确源预期，而不把已知错误保成golden。

## F2：正常Smoke的共同胜利治疗及健康发布

在F1提交后，按root明确授权独立重取MeatOnTheBone、BurningBlood、BlackBlood、FaceOfCleric、MagicFlower、MarkOfTheBloom及room/player/Smoke调用链。新增独立LF字节认证清单 `smoke-victory-healing-source.json` 保存9份原始双hash，不改F1清单或旧golden。固定source的room.endBattle无smoked治疗排除，Meat先触发，再存活玩家按持有列表onVictory；Flower要求房间仍为COMBAT并按1.5倍四舍五入，Bloom返回0。

新增公开Run六项低20HP场景先真实RED：只有BurningBlood的Smoke实际仍20/80，源应26/80。其余固定源预期为Black32/80、Meat+Burn38/80、Cleric+Burn27/81；Flower+Meat+Burn47/80、Bloom+Meat+Burn20/80。`m3-smoke-victory-healing-red.log` 记录该红例（1040ms）。在复用共同治疗后，另加实际retained combat actor检查再次RED：Run已26而combat.player仍20；记录于 `m3-smoke-victory-actor-red.log`。两项都是真实可见状态差异，不能仅以Run标量通过。

最小修复仅把既有event分支里的 `combatEndHealing` 移到活玩家Smoke共同暂存入口，仍用原Meat优先/持有顺序/倍率函数，不增加第二次event治疗；在提交前按既有outside-potion健康发布形式同步candidate最终HP/maxHP到escaped battle.player。F1中旧40/80的Smoke现状断言明确改成源正确59/81；Smoke金币、胜场、无奖励、map/实际event重开合同均不改。败北仍0HP/原maxHP、无胜利治疗或Cleric成长。

真实Colosseum公共event入口测20→39/max81并只出现Meat12→Blood6→Cleric1一次，完成后旧瓶位/finish重放不重疗。普通Smoke在第二次实际治疗之后注入失败，完整原Run图/引用和瓶均保持；恢复后重试只提交一次。真实GameUI夹具读map原始HP HUD为27/81，retained actor亦27/81；再公开进入下一战仍27/81，未将错误combat快照藏在标量断言后。

新增精准临时模块负控分别漏掉共同Smoke治疗、重复event治疗，只能由对应源数值/一次性断言拒绝。每个JS入口保持10秒、Lua30秒，正常六项入口约5.4秒，其余约2秒；原Smoke与eventSmoke/bridge专项通过，未修改其旧golden/断言。F1/F2需由非作者对最终commit统一窄审，再绑定精确HEAD完整CI；本记录不是平台或设备验收。
