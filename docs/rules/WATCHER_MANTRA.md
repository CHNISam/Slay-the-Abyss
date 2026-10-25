# 真言与虔信：独立实验切片

本切片交付仅为`src/lua/abyss_mantra.lua`、`tests/lua/watcher_mantra.lua`和本说明。未修改共享Combat/Effects/Actor/Stances、既有卡牌helper或Backlog。测试所需共享基础文件从主线程实验树复制至私有树；复制文件不属于本切片新交付。没有提交、推送或运行全量测试。

## 固定来源和证据边界

统一采用仓库既有的社区反编译镜像[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。逐份只读核实方法语义后独立实现，没有复制Java方法体。该镜像不是官方开源、正版二进制认证或本轮原版实测。

| 文件（相对上述固定提交） | 原始字节SHA256 |
| --- | --- |
| powers/watcher/MantraPower.java | a28abb19643bcce1c9899e1ac72f0f8bf966da4b2644de1c130e32c8986fa5af |
| powers/watcher/DevotionPower.java | 310834768f7cb09fe0bd59826a1074ddc1871910c634bc8ee68135841853dc1d |
| cards/purple/Prostrate.java | dcd92d3b8ce53cd913dfc3f6c08bce7168ee664327dccf2f8a62bf4ce9b40cb7 |
| cards/purple/Worship.java | fb14d3bf2515d52e0773c4b37ac6b2c26b922a63e1ae605fb3a30b0d50388235 |
| cards/purple/Devotion.java | 47c98bd437d097448f2816b1ca685fc2a6a47d72a4fb363a5f7bf370653d6933 |
| powers/AbstractPower.java | 37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f |
| actions/common/ApplyPowerAction.java | f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47 |
| actions/GameActionManager.java | a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3 |
| characters/AbstractPlayer.java | 2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95 |
| stances/DivinityStance.java | 7363a98527c6009ba491fd9d3f6c1dfbaffc833972211218ebf8bfeb34c3fce7 |

## 已核实语义

MantraPower构造时直接保存传入amount，并增加`GameActionManager.mantraGained`累计；明确类型BUFF。ApplyPowerAction首次添加时调用的onInitialApplication继承空实现；只有已有同ID能力时调用stackPower。AbstractPower.stackPower直接相加，Mantra覆写随后检查>=10，**只减10一次**，并把ChangeStance(Divinity)插入TOP。余数<=0时再插入TOP的RemoveSpecificPowerAction，因此队列实际先移除零层真言、再切神格。

这意味着9+3得到2余数并进入神格；已有5+20得到15余数、只触发一次，不能擅自改成while循环。已经神格再达到阈值仍消耗真言，但同姿态ChangeStance不会重复获得进入能量。BUFF不受Artifact阻挡，也不消耗Artifact。`mantraGained`在构造时累计，不是扣去10后的现存层数；后续Apply被清理也不能撤销已经发生的构造计数。原累计在战斗重置时归零。

**首次直接施加>=10的边界**：镜像构造/首次onInitialApplication没有阈值检查，不能假定会自动进入神格。本模块明确拒绝此直接输入`unsupported_initial_mantra_threshold`，不把证据有限的异常首次施加包装成已认证行为。常规Prostrate、Worship单次2/3/5不触及此拒绝。

DevotionPower提供了独立且重要的补偿路径：在`atStartOfTurnPostDraw`，如果**没有Mantra且Devotion层数>=10**，直接队尾排ChangeStance(Divinity)，不创建Mantra、不保留超出10的余数，也不增加mantraGained；其他情况才构造新的MantraPower并队尾Apply。即使Devotion=12，此特殊路径也不能擅自变成“剩2真言”。已有0层Mantra对象与没有对象不同；本模块用nil表示不存在，0表示待移除/真实零层对象。

神格的退出在下一次自身回合开始排队，Devotion在**该回合抽牌之后**再触发；两者不能合并成回合开始立即直接加层，也不能在打出Devotion当轮立即生效。多个post-draw能力之间的通用优先级调度不在本模块新增范围。

## 模块API与共享接入

- `withCards(data)`：返回独立拷贝，追加三张卡和mantra/devotion的BUFF intensity/none定义，不改变获取池、初始牌组或既有卡牌helper；重复追加拒绝。
- `prepareGain(state,amount)`：对应`new MantraPower`构造时点，立即计入`state.mantraGained`，返回纯效果`{op='applyMantra',value=amount}`。共享层应在源卡`use`构造初始动作时，将`gainMantra`转换成此效果，并把整个过程置于出牌事务内。
- `apply(state,amount,Queue)`：对应已经轮到的ApplyPower，不再次计数。使用共享Actor状态接口，阈值时pushTop神格变化；余数0时再pushTop`{op='removeMantra'}`。共享Queue必须有相应effect处理器；返回false的拒绝须中止当前事务，不能当作成功。
- `remove(state)`：只移除剩余0的真言。避免删除后来已经变为正数的层数。
- `applyDevotion(state,amount)`：共享Actor BUFF叠加，源卡效果为`gainDevotion`。
- `postDraw(state,Queue)`：宿主每个自身回合正常抽牌后调用一次；按上述Devotion特殊分支或普通构造/Apply顺序排队。队列中只保存数据，不保存回调。

队列只有effect/useCard两种kind。Prostrate排入gainMantra→4格挡→UseCard；达到阈值时的TOP移除/神格必须先于这张牌后续格挡；神格进入产生的能量及Mental Fortress等BOTTOM收益仍须保留已有源队列顺序，不能在切姿态内部提前执行。构造和施加分离也使已存在的纯数据暂停/恢复及原引用事务可复用。

所有整数溢出、负数、小数、NaN和无穷输入拒绝；不模拟Java整数溢出。`apply`不能替代`prepareGain`，否则累计会错误地拖到实际应用时才发生。单独调用模块不提供整张卡片事务，宿主必须为构造、执行及恢复包装原引用图快照。

## 三张牌数据

| 卡 | 基础 | 升级 |
| --- | --- | --- |
| Prostrate | 0费技能，先获得2真言，再4格挡 | 真言3，格挡仍4 |
| Worship | 2费技能，获得5真言 | 仍2费5真言，增加自身保留 |
| Devotion | 1费能力，每个自身回合post-draw排入2真言 | 3真言，费用不变 |

不包含Pray/Insight生成依赖，不声明完整真言卡池或所有跨色/遗物交互齐备。

## 当前验证

`node scripts/test-lua.mjs tests/lua/watcher_mantra.lua`包含13组模块契约检查和6组真实Combat.play/endTurn接入检查。模块检查使用真实Combat状态与真实Queue，验证Artifact、阈值移除TOP顺序、余数、单次减10、已神格不重复能量、构造累计与取消、首次>=10明确拒绝、Devotion>=10特殊分支、普通及已有零层Devotion的post-draw、下回合退出/重入、输入溢出和独立数据。

共享层已接入gainMantra构造计数、纯数据TOP阈值动作、姿态收益BOTTOM队尾与Devotion抽牌后触发。19组全部通过，包含真实Prostrate/Worship/Devotion、Mental Fortress先于神格能量且在UseCard后、下回合先退出再进入神格、NoDraw阻挡正常抽牌仍触发供奉。三牌已进入实验Watcher Profile并覆盖界面显示；未做这三牌自然获取、完整通关或平台验收。
