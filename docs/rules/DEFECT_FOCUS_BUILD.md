# 集中、偏差与球位构筑切片

采用 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0) 固定社区反编译来源。镜像版本字段V2.3.4/2022-12-18；不视作正版PC二进制认证，规则独立编写，无源实现或素材复制。

## 固定源事实

相对路径可接到上述blob URL。SHA256对应本轮下载原字节。

| 文件 | SHA256 |
| --- | --- |
| cards/blue/Capacitor.java | 1e4763bab6df45ad0dfcd6ff26385dcd3a3053f9e9674866e16837ec1ebe02dd |
| cards/blue/Consume.java | 10bb0b85abc7f782d6360bbd5d28d0762c7d3c9b05ecd79128f10a3187b174ea |
| cards/blue/Reprogram.java | f959fcb8321d364784df5a78e54ebee32004d7a817ae10f39e1a6cdb46c6f757 |
| cards/blue/BiasedCognition.java | 47ae9c26c9892156666ff813057dff8f31f8faf4b273e93fe13b3bd92a0c4dfe |
| powers/FocusPower.java | 266d04b57ccb01daaff326346c21b2935caa82158eaf2a12f6291ba453491da4 |
| powers/BiasPower.java | 35a183a0b16abc9c95d135fa4873d74ee9fdb7395b16ea57da06caaf399abc6a |
| actions/common/ApplyPowerAction.java | f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47 |
| actions/common/RemoveSpecificPowerAction.java | c6262b3ce8528f75045f9610026d524a8ae63c526547593e4549f7c5a01a1ad8 |
| characters/AbstractPlayer.java | 2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95 |
| actions/defect/IncreaseMaxOrbAction.java | 8669c5d0b8b95b4f11c4f941e8116dd4329fc9d1513c14db7972f7154329ee13 |
| actions/defect/DecreaseMaxOrbAction.java | d66239f75ba9548dab498592d7cb7a3e30f140fb579dbcb34017c17a17bc705b |

Capacitor为1费能力球位+2，升级+3；Consume为2费技能先集中+2（升级+3）再失去1球位；Reprogram为1费技能依次集中-1、力量+1、敏捷+1，升级三个幅度均2；Biased Cognition为1费能力先集中+4（升级+5），再施加Bias1。

FocusPower构造器直接赋值，不钳制；amount>0为BUFF、amount<=0为DEBUFF。ApplyPowerAction以入站类型判断Artifact，发生于查找同名Power叠层之前。因此原集中+5也可挡入站-1，原集中-5不挡入站+1，入站0也可被挡。首次0实例存在；已有Focus叠到0才排TOP移除。已有Focus叠层夹在[-999,999]，首次创建不夹。

Bias自身是DEBUFF，可在施加时消耗Artifact而被挡，之前的集中收益保持。Bias在后续每个玩家回合开始排一笔集中负数，大小为Bias层数，因此Bias2的tick只消耗一层Artifact。当前回合打出不立即衰减。偏差本身不会因为某次衰减被挡而消失。

球位增加Action逐个调用+1以限制到10；减少删除末槽，末槽有球则无声移除，不唤起，不消费球效果或RNG。0球位Consume仍获得集中。

## 实现边界

`abyss_focus`以`state.player.statuses.focus`为唯一数值事实：nil表示没有Power，0表示存在0层Power。`orbs.focus`仅派生兼容镜像，不是可独立写入的规则状态。球计算每次读取玩家真值，Dark储伤不会随集中变化被重算。底层fixture setter `Orbs.setFocus`同步玩家状态，不用于生产ApplyPower替代。

API：`ensureDefinitions(state)`在现有catalog注册focus/bias而不擦旧状态；`apply(state,actor,amount,source)`处理首次/叠层和Artifact；`remove(state)`删除玩家Focus；`startTurn(state,api)`执行一笔Bias负Focus应用；`value/sync`供球逻辑读取。不会递归Actor.applyPower的focus分流；仅Bias tick通过该公开入口。

源中归零后通过TOP动作移除；当前支持的卡牌动作边界没有可插入的同轮回调，所以本实现于此边界先emit叠层，再立即remove并emit移除，再处理下个映射动作。没有宣称实现原作通用Power队列、任意第三方钩子、Loop与Bias复杂优先级交错或Orange Pellets等未接入清除入口。添加这些内容时必须重新验证此等价条件。

玩家死亡后Focus/Bias不继续应用。数值接口限当前signed32安全子集。Defect卡helper附加15张派生定义，不直接修改默认生产卡池或所有职业获取概率。

`Orbs.gainSlots(state,count)`/`loseSlots(state,count)`不唤起，分别钳制10与0；后者只删除超过新容量的末位填充球。新增球位/集中/Bias效果的整牌回滚依赖共享Combat.play保存actor.statuses和orbs嵌套对象；当前所有写入都属于该事务。

本切片替代DEFECT_ORBS.md历史记录中“尚不支持负集中/Bias/球位增减”的旧边界，仍不表示Loop/全部清除钩子已经支持。

验证：`node scripts/test-lua.mjs tests/lua/defect_focus_build.lua` 28组通过；保留旧场景并升级signed-Focus语义后，球模块27组、原六卡20组、扩展五卡17组均通过，共92组。测试包含真实Combat.play基本/升级费用、跨真实endTurn的Bias衰减、多层单次Artifact消费、Focus nil/0生命周期、Capacitor上限、0槽Consume、不唤起的末槽删除，以及失败卡牌恢复Focus/Bias/球位/RNG和原引用。未运行全量check、未提交、未平台导入或实机试玩。
