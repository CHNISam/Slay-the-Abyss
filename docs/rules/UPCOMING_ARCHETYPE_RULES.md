# 后续构筑规则核源检查点

以下是后续需求依据，不代表当前实现。对应主工作区Backlog：TASK-56.1、57.1、58.1、59.1。

固定社区反编译镜像：[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。未认证正版PC二进制；不复制方法体。

## 毒流

Catalyst的Double/TriplePoisonAction在动作执行时读毒P，再ApplyPower新增P/2P；Artifact挡新增而不清原毒，无毒时不误耗Artifact。现有毒叠层不能套用PoisonPower构造器9999限制。BouncingFlask2费，3/4次各3毒，独立cardRandomRng，单候选仍消费一次；下一目标在当前Apply执行前预抽。NoxiousFumes1费Power，2/3buff叠层；玩家回合抽牌后触发，出牌本回合不立即加毒。NoDraw不阻止post-draw能力。SnakeSkull等联动另验收。

来源：cards/green/{Catalyst,BouncingFlask,NoxiousFumes}.java；actions/unique/{DoublePoisonAction,TriplePoisonAction,BouncingFlaskAction}.java；powers/{PoisonPower,NoxiousFumesPower}.java。

原字节SHA256：

- Catalyst：710f945951fa80cece3975afd8e1daf60b680f96d122f9b4e05f6fa8fca2a553
- DoublePoisonAction：2fa089c6c33a13d85789a704f02c4561beeb56395d34849aa80712633dabd2cf
- TriplePoisonAction：dce256cac6efb137ecba050ae892ce79a293d0ead281ea3eb4eda473e3b1a5ad
- BouncingFlaskAction：3dd61c8b76ce1894284d814cb4b66fd652caee959b10fd3167d41df9e958c096
- NoxiousFumesPower：add060dc8068d0b706b5503f52f72b73be92a70870e38d3587a98eabd7403559

## 集中、减益与球位

Capacitor1费增加2/3球位，逐个增加、上限10。Consume2费先集中+2/3再减少最后球位，不唤起；0位仍得集中。Reprogram1费幅度1/2，顺序负集中、正力量、正敏捷。BiasedCognition1费先集中+4/5，再Bias1。

Focus入站>0为BUFF，<=0为DEBUFF，先处理Artifact再叠层。首次创建不钳制；已有实例stack才钳[-999,999]，叠为0排队头移除，初次0不自移除。Bias本身可被Artifact挡住而保留先前正集中；每次后续回合的整笔-Bias也可被一层Artifact挡。集中必须成为单一状态来源，不能由orbs.focus与玩家Power分别写入。当前正数Defragment切片不等于这些生命周期已齐备。

来源：cards/blue/{Capacitor,Consume,Reprogram,BiasedCognition}.java；powers/{FocusPower,BiasPower}.java；actions/common/{ApplyPowerAction,RemoveSpecificPowerAction}.java；characters/AbstractPlayer.java。

原字节SHA256：

- FocusPower：266d04b57ccb01daaff326346c21b2935caa82158eaf2a12f6291ba453491da4
- BiasPower：35a183a0b16abc9c95d135fa4873d74ee9fdb7395b16ea57da06caaf399abc6a
- ApplyPowerAction：f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47
- Reprogram：f959fcb8321d364784df5a78e54ebee32004d7a817ae10f39e1a6cdb46c6f757

## 占卜及暂停结算

ScryAction从draw尾端（顶部）窥min(N,#draw)张，不因不足重洗；选择可为空，按点击序移到discard，未选牌保留原相对顺序；不触发手动弃牌。非终局先触发onScry，再查空堆，所以空堆/0数量仍有能力钩子。GoldenEye在构造时+2。

CutThroughFate1费：伤害7/9、Scry2/3、Draw1。ThirdEye1费：格挡7/9、Scry3/5。JustLucky0费：先Scry1/2，再格挡2/3，再伤害3/4。Nirvana1费，onScry把固定格挡3/4排到现有动作队尾。因此CutThroughFate顺序是伤害→选择→原生Draw1→使用牌处置→Nirvana格挡，不能先处置使用牌，也不能确认即给Nirvana盾。

共享基础需可串行化pendingPlay（实例、目标、剩余原生动作、处置阶段）与pendingScry（代数、token、候选UID和快照）。恢复不重放此前伤害，选择失败只恢复当前阶段，终局执行原有保留/取消规则。Weave的triggerOnScry及后续回手、选择期间药水消费后延迟效果，都需统一队列另验收。

来源：actions/utility/{ScryAction,UseCardAction}.java；cards/purple/{CutThroughFate,ThirdEye,JustLucky,Nirvana}.java；powers/watcher/NirvanaPower.java；screens/select/GridCardSelectScreen.java。

原字节SHA256：

- ScryAction：a22d8875a9ac3a4b6c445abad65a6ca4defa8fb309d1f6a6e51506a8e3b55147
- CutThroughFate：4272d2efb273ef4783037a9355378fdb1188d8fbcca831734212500d9e36a4a8
- JustLucky：4ffc7870d841075d6a7ffebf01cc825f71465b09b7612cb35229fdc44040d07b
- NirvanaPower：d1d0c348c75c619d75a69397bfe440c09a009b73fe0eb3af37e88431ee5d6dae
