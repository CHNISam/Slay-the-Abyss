# 六种动态编组的可调用绑定

2026-10-24，TASK-15。基线`0540431`与已合PR182的`b91a461`在src/data/scripts无差异。本片只新增源组装配模块与Combat显式入口，不接队列、Run、Nodes，不调整地图、旧内容池或界面。

## 来源与流边界纠正

固定社区反编译镜像`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，并非正版PC二进制认证。重新读取本地已封存的[MonsterHelper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L403)，SHA256为`e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1`。本轮另取14个敌人构造方法固定原字节，全部哈希见[机器记录](../rules/evidence/sts1-encounter-formations.json)。原文本仅在根`.artifacts/sts1-encounter-bindings-source/`作研究证据，不部署第三方代码。

旧队列审计把bottom的X/Y偏移归入misc流，**此处纠正**：[MonsterHelper:600–605](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L600)明确使用`MathUtils.random(-20f,20f)`。颜色与候选索引使用`AbstractDungeon.miscRng`；偏移属于独立MathUtils边界。不能为了看起来统一，把四次偏移塞进misc。敌人构造内的动画MathUtils取样也由构造回调负责，不能把本模块的四次偏移当作完整MathUtils全局轨迹。

[LouseNormal:45–66](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseNormal.java#L45)及[LouseDefensive:48–69](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseDefensive.java#L48)：A0构造先抽HP，再用monsterHpRng抽Bite5–7；CurlUp3–7在后来的preBattle动作中抽取。其他12个本片可构造类型各有一次HP抽样。discarded候选也已经执行其构造，保留HP/Bite消耗；它们不参加后续整组AI初始化或CurlUp。

## 装配契约

`abyss_encounter_formation.assemble(sourceName, boundary)`只接受下表六个**源组名**，从不将`medium_slimes`当作Lots。边界为普通函数，不接收隐含self：

```lua
local actors = Formation.assemble("Exordium Thugs", {
    misc = {
        boolean = function() return Random.randomBoolean(stagedMisc) end,
        integer = function(lo, hi) return Random.randomIntBetween(stagedMisc, lo, hi) end,
    },
    visualFloat = function(lo, hi) return stagedMathUtils(lo, hi) end,
    construct = function(id, x, y) return constructActor(id, x, y) end,
})
```

misc回调严格校验Boolean和含上界整数，MathUtils偏移单独提供，偏移加法按binary32舍入。构造回调**立即**调用，返回实际候选对象，选择时保留对象身份；不能先选ID再只构造选中者。回调由调用者提供私有暂存流；本模块不会也不能回滚外部闭包的副作用，失败时调用者应丢弃整份暂存请求。

| 源组 | 槽序及构造 | misc调用 | 构造HP流调用数（含Bite，不含稍后CurlUp） |
| --- | --- | --- | --- |
| 2 Louse | 每槽独立Boolean，true红/false绿；每次Boolean后立即构造 | 2次Boolean | 4 |
| 3 Louse | 同上，保留源三槽坐标和顺序 | 3次Boolean | 6 |
| Large Slime | 一个组，Boolean true大型酸液/false大型棘刺 | 1次Boolean | 1 |
| Lots of Slimes | 有序多重池：棘刺S、棘刺S、棘刺S、酸液S、酸液S；每槽抽一项、只删该项后立即构造 | index上界4、3、2、1、0，最后一项也抽 | 5 |
| Exordium Thugs | 先弱野生候选Louse、SpikeM、AcidM，全部构造后抽一项；再人形候选Cultist、随机Slaver、Looter，全部构造后抽一项 | Louse Boolean、index0..2、Slaver Boolean、index0..2 | 7 |
| Exordium Wildlife | 固定两槽：先构造Fungi/Jaw后抽一项，再完整弱野生候选后抽一项 | index0..1、Louse Boolean、index0..2 | 6 |

Thugs/Wildlife每个槽位进入候选辅助方法前，依次取X、Y两个MathUtils偏移，合计4次。源`bottomWildlife`把`numMonster`固定为2，三槽分支不可达，本片没有臆造第三槽概率。所有候选保留，不按当前已实现类型筛池或归一化。

## Combat入口与剩余接线

`Combat.new(data, {sourceEncounter=源组名, encounterBoundary={misc=..., visualFloat=...}, ...})`使用既有`makeEnemy`立即构造所有候选，再只对选中对象赋连续的现场ID、执行AI初始化/抽牌/preBattle。保留`sourcePosition`作原槽位来源，不改变当前界面布局。该入口与`options.enemies`互斥，未知组拒绝而不回退Cultist。默认显式敌人数组的原构造路线保持不变，新模块由现有普通部署发现器收录。

**该Combat桥仍用当前共用LCG处理HP/Bite/AI/牌序，不是原版独立monsterHpRng/aiRng实现。**完整源流调用可通过Formation的构造回调注入；本片没有完成生产房间重建流或同seedPC重播。Run/Nodes仍走原数组/Boolean/小魔选择，旧数据中的固定虫色、两个大型ID、wildlife例子及无原版依据的medium_slimes均未被静默改写。新队列后续接线须显式选此入口并处理旧池迁移；机器记录标为可调用但生产未接，TASK-15整体验收不勾。

## 验证范围

- 独立模块7组：2/3虫的全部4/8种颜色序列；Lots全部120条原项有序抽样路径（首棘刺72、首酸液48）；Thugs36种和Wildlife12种潜在分支；逐调用记录misc、MathUtils和构造交错；弃选Louse仍保留HP与Bite。
- 真Combat4组：六源组均能构造合法战斗；保留候选对象和连续现场ID；弃选候选构造的7次HP/Bite请求先于所选两敌AI，弃选虫不会触发CurlUp；默认数组与未知/冲突请求边界。
- 两项真实红例：模块缺失；旧Combat忽略源组请求而返回Cultist。原输出封存于`.artifacts/formation-red.json`及`formation-combat-red.json`。
- 五个独立突变均被拒绝：改变重复权重、略过最后0..0抽样、不构造弃选候选、将偏移误计misc、调换弱野生池顺序。
- 仅跑相关Lua与数据/部署测试，最终计数见任务备注和机器记录；不跑完整check，无GUI/MCP、候选构建、导入或实机。

本轮按主线程指示直接Codex实现，未重试已被自动审批拒绝的外部免费模型，不作额度节省估计。
