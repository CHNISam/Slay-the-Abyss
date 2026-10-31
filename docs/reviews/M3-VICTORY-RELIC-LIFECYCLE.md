# 胜利生命周期 F1 / F2 源差异

基线 develop `06366f7821dd91eb089ff8139056132981fa039c`，独立树 `/workspace/m3-victory-relic-counters`。不改已合PR437/root树/远端/Backlog；CLI在环境不可用。独审最后的道具差集先按F1独立提交，随后按root明确授权处理F2。没有扩大池、改概率或预算。

## F1：七件战斗计数的公开结算清理

独立重新读取固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 原文：LetterOpener、Kunai、Shuriken、OrnamentalFan、StoneCalendar、CaptainsWheel、Pocketwatch各onVictory设counter=-1；AbstractPlayer遍历持有遗物调用onVictory（玩家存活），AbstractRelic只显示>-1计数。新 `victory-relic-counter-source.json` 保存13份Java原始SHA256/Git blob双哈希及固定资格，不存方法体。额外读取SmokeBomb、AbstractRoom、AbstractMonster、MonsterGroup：Smoke动画及所有敌人逃离同样进入room.endBattle→player.onVictory，不能额外按allEscaped拒绝清理。固定字节来源清单有LF属性及严格SHA校验，没有OS动态路径键。

本轮复跑原公共探针，七件在reward/map仍显示计数，下一战已重置。新增更深公开路径先RED：真实取得五张小牌组和七件遗物，Neow真实令敌人1HP，Defend→DeepBreath（让永久Sundial真实到1）→Strike，胜利后LetterOpener仍为2。RED日志 `/workspace/cloud-reports/m3-victory-counter-red.log`。初稿eventDamage用于地图时被正确拒绝，已改为明确的40HP起始边界；不是生产RED。

修复增加Uncommon四件onVictory清理，公共RelicHooks.onVictory复用既有Rare三件hook。实际胜利的finish事务在publishBattleResult拷贝counter前调用；Smoke在其暂存battle中调用并发布candidate counter。败北不调用。不普遍清零Sundial、InkBottle、HappyFlower、Incense、Neow或全局充能。

回归通过真实Run reward→map和下一战检查七件隐藏/重新计数；下一战四件及Pocketwatch为0，Calendar/Wheel经过真实第一回合后为1。永久计数保持各自实际非零值，充能不变。40HP获胜仍严格Meat12→BurningBlood6→Cleric1，最后59HP/81maxHP；未重排治疗。正式source-room晚期奖励抽样后抛错，完整原Run图、所有原引用、计数/治疗/随机进度均恢复，重试只提交一次；重复finish不再触发。实际Looter正常逃离、Smoke和败北另验，source资格明确，不以旧残留当原版期望。

两个临时模块精准负控分别删公共胜利分派及Uncommon清理，均必须被公开七件隐藏断言拒绝，不能以任意错误冒充kill。五个JS入口各低于整入口10秒，Lua沿用30秒；根完整CI与fresh独审另外绑定。

F1阶段刻意只改计数；正常Smoke缺失胜利治疗已由审计确认是独立F2。F1里Smoke旧40HP断言只是保留该阶段资源现状，**不是固定源认可**；下一独立F2提交将改为正确源预期，而不把已知错误保成golden。
