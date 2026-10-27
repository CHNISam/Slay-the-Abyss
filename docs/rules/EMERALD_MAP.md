# 燃烧精英地图接线

TASK-64，基于[源组件及固定member身份](EMERALD_ELITE.md)。本片只接地图层，不改变Run、Nodes、Host、Combat、UI、配置清单或Backlog；不能把地图标记或测试构造的强化当作绿钥匙自然取得。

`Map.generate(data,seed,act,trustedContext)`的第四参是调用者可信的**本幕出生上下文**，仅有布尔字段`endingUnlocked/emeraldOwned`。旧nil、无资格、已有绿钥匙，以及第四幕都保持旧图逐值不变，不新增字段，不额外抽样。上下文字段错误明确拒绝。

符合资格且未持钥匙的前三幕，在`Rooms.generate`完成路径与房型分配后，从既有`randomState`恢复同一流并调用源组件选点。原来的`topologyState/randomState`保留原值；新增`emeraldSelection`、独立持续流快照`mapRng`，且只有选中节点拥有`hasEmeraldKey=true`。选择按源y/x排序并消费一次mapRng；地图生成不提前抽强化。

`Map.prepareEmeraldBoost(map,nodeId)`只接受当前合法可用的燃烧精英节点，返回包装对象及独立nextRng快照，输入图和流不变。不可用节点连私有强化抽样也不准备。包装内容是：

```lua
{
 version=1, runSeed=map.runSeed, mapSeed=map.mapSeed,
 mapSignature=map.sourceSignature, nodeId=nodeId,
 beforeRng=map.mapRng, afterRng=nextRng,
 effect={version=1,act=act,nodeId=nodeId,x=x,y=y,roll=roll}
}
```

以上字段均为脱离调用者输入的值副本。父流程必须将`boost.effect`传给源组件apply；不能把整个包装混入严格四强化描述。真正应用强化仍应在源怪物预战斗动作之后、首次抽牌之前。

父事务确认战斗准备成功后，先`Map.choose`，再`Map.commitEmeraldBoost(map,nodeId,boost)`。commit重算原流的唯一强化，逐值校验runSeed、幕地图seed、签名、节点、before/after流及effect；要求当前节点、楼层和path末项均已选择该节点，拒绝错owner、未知额外字段及重复提交。仅成功时写入脱离调用者的`emeraldBoost`及推进后的`mapRng`，失败不改图。

`Map.restore(data,snapshot,trustedContext)`用调用者可信的出生上下文重生成，不读取快照自报资格。重放路径时，在燃烧节点choose之前准备、之后commit一次强化，最后与完整snapshot严格比较。已经过燃烧节点但未提交强化、伪造选择、错RNG或错roll均拒绝。获得钥匙后恢复本幕时仍须传本幕最初的上下文，不能改用当前`keys.emerald=true`；下一幕生成才使用新的出生状态。本片不实现完整Run存档或平台持久化。

2026-10-28验证：预写六组用例先真实RED（缺Map boost边界239ms），实现后全部GREEN（7.136秒）；原有12份完整A0地图黄金、完整signed64输入继续通过（9.356秒），原始seed和严格v3恢复用例通过（1.564秒）。均使用既有fixture预算，未改旧用例/门禁/超时。Map固定Luacheck零诊断，`git diff --check`通过；没有运行真实战斗、自然路线或平台测试。
