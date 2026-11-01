# 合法依赖牌五项精确效果补证

独立39项效果审计发现 Deep Breath、Impatience、Metamorphosis、Secret Technique、Violence 仅有完整目录执行烟测，缺各自对象/数值合同。原补证 `d2b5869` 基于 develop `b4f88a1`，当时只增加测试；随后独审发现 Deep Breath 的单洗牌预期错误，原“仅测试、没有生产差异”结论对该牌不成立。下文原28场景及11/11记录保留为历史，不能作为该牌已独立通过的证据；其余四项经独审认可。

期望来自 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的五张牌及六个具体 Action。原文逐份从固定 GitHub contents 接口读取，原字节 SHA256 与 Git blob SHA1 均实核；路径、长度、双哈希及链接保存在 `tests/fixtures/colorless-five-source-contract.json`，原文取证保留于工作区 `m3-dependency39-source/`。数值期望直接取原版合同，未调用生产效果计算期望。

`tests/lua/support/colorless_five_effects.lua` 共28个受控场景：

- 深呼吸（原d2历史，已被独审否决其洗牌预期）：基础/升级抽1/2；原测试仅核有弃牌后counter+1及对象守恒，遗漏先洗弃牌再洗完整抽牌堆的第二次long与onShuffle入口；新修复见下文。
- 急切：无攻击抽2/3，有攻击零抽；真实牌堆顶对象移入手牌，未洗牌、未克隆。
- 蜕变：基础/升级生成3/5张非治疗攻击，花2能量且消耗；唯一新 UID，生成牌永久0费，清除临时费用后仍为0。
- 秘技：无技能按原版 canUse 拒绝；单技能自动移入，多技能只允许技能 UID，非法/旧选择拒绝；基础消耗、升级弃牌，选择移动原对象。
- 猛袭：基础/升级只取3/4张攻击；空/不足/充足与合法十张起手边界，先填最后一个空位，余下选中攻击弃置；技能保留、牌堆和全部 UID 守恒。

五个临时模块变异分别删除合并洗牌、删除手中攻击限制、生成3改2、技能筛选改攻击、取3改2，均由对应实际结果断言杀死。变异仅在临时模块加载器内执行，不修改磁盘生产源码，不将异常/超时当作预期数值差异。

本地验证：`node --test --test-concurrency=1 tests/colorless-five-*.test.mjs` 共11/11、零跳过，7.94秒；每个独立入口低于10秒，Lua沿用30秒。初次环境未构建 `abyss_data`，随后执行正常 `build:data`；秘技空技能夹具初稿曾期待无效果成功，核读原版 canUse 后改为正确拒绝。两者均为夹具/环境修正，不是生产缺陷证据。

公开生成渠道、完整75牌与既有34项依赖效果证据可以按标准实例合同组合；本片只补上述五个具体消费合同，不声称所有随机消费者、自然全池获取或同候选官方导入、ready、PC/手机已通过。独立复核与最终候选完整CI另行绑定。

## Deep Breath 源差异修复（以d2b5869为基线）

独立重取固定319009的 DeepBreath、EmptyDeckShuffleAction、ShuffleAction、CardGroup、Soul、SoulGroup、Sundial、Abacus 八份原文，原始 SHA256/Git blob双哈希放在新增 `tests/fixtures/sts1-deep-breath.json`。旧11份来源锁和旧 golden不改。`EmptyDeckShuffleAction` constructor先调用全部onShuffle；update先洗弃牌（第一long），从group索引0依次移除。`SoulGroup.shuffle` 转给 `Soul.shuffle`，后者立即调用 drawPile.addToTop；CardGroup.addToTop是ArrayList末尾追加，因此保持洗后弃牌遍历顺序地追加到原抽牌堆。Soul.update只处理动画与清除Powers，不二次移动或倒序。随后 `ShuffleAction(draw,false)` 再洗完整抽牌堆（第二long），不再触发遗物。

新独立Python模型复用已固定的XS128/Java48 shuffle解释器，不用生产clone或采样器预期。实际 `Combat.play` 的原生产单洗实现先RED：在混合牌堆中第一次shuffle的beforeCards实际UID5，源模型应先洗弃牌UID2。日志 `/workspace/cloud-reports/m3-deep-breath-red.log`，587ms。最小生产修复仅在Deep Breath分支增加一次constructor位置回调、先洗弃牌，然后按原方向追加并保留第二次洗完整抽牌堆；root旧helper只将错误+1纠正为+2，其余四牌实现与断言不动。

种子7/42/-1各核基础与升级，空弃牌、有旧抽牌+弃牌、全弃牌、单张弃牌，共24场景。独立预期逐次核before/after所有实际UID顺序、rawLong、两个64位word和counter；核最终手牌/抽牌堆/弃牌堆、原对象守恒。真实Inventory opening绑定Sundial（受控初counter2）与Abacus，观测原callback函数并调用真实实现，要求仅在第一次洗牌前调用一次，实际能量+2、格挡6；无弃牌零回调，第二次洗不重复回调。

两个临时模块变异分别删除第一洗和倒序Soul转移，均被新 `Deep Breath independent shuffle sequence` 断言拒绝；不会仅凭counter+2放过错误顺序。原源码不被变异写入。

三个种子各独立JS入口，实际进程1414/1325/1571ms；元数据/两个精确负变异/Windows与POSIX路径/真实CRLF checkout另入口1628ms。保留JS整入口10秒/Lua30秒。原五项标准11/11修后通过8431ms，39来源身份3/3通过，架构与历史整源恢复单case通过；未出现新的source guard失败，因此没有额外逆投影层。源码/模型/fixture均精确LF认证，source identity用POSIX路径，未放松hash。

状态改为 `PRODUCTION_FIXED`（Deep Breath真实RED→GREEN）；其余四项仍为 `TEST_ADDED`。本修复不触及根工作树/主PR/远端/Backlog，也不据离线顺序模型声称已核准PC动画帧/global MathUtils或实体设备。独审Important的关闭应绑定本次独立复验及最终集成CI。

### 928ec0c 后续：实际遗物效果必须在首洗与抽牌前结算

后续独审进一步否决了928对回调效果时序的证明：928只观察callback在第一long前、最终能量7/格挡6，没有观察实际效果何时执行。原版 `DeepBreath.use` 构造 `EmptyDeckShuffleAction` 时，Sundial/Abacus已先addToBot其效果，再将EmptyDeck/Shuffle/Draw加入队列；而928在执行Deep Breath动作时BOTTOM追加效果，排到了既有draw/dispose后。新增真实 `Combat.draw` 只读观察先RED：入口能量5/格挡0，源应7/6；663ms，日志 `/workspace/cloud-reports/m3-deep-breath-effect-order-red.log`。该问题不能只用最后的计数放过。

后续最小修复先按当前持有遗物正序调用两个受支持的onShuffle，收集真实效果。专用 `deepBreathShuffle` 延续动作先插TOP，再将收集效果反向插TOP；实际执行仍保持原持有顺序，且所有效果在第一洗与抽牌前完成。`Shop.onShuffle(state,effectsOnly)` 新增仅返回效果的可选模式供该入口使用；不传参数的旧调用仍按原方式BOTTOM入队，其它洗牌调用不变。两次洗牌与Soul转移算法不改。

原24向量的所有数值、牌序、随机流及Java来源hash不变，只增加持有顺序/实际效果顺序字段与新生成器hash；基础牌测Sundial→Abacus，升级牌测Abacus→Sundial。新只读观察在首shuffle和真正draw入口均核7/6，并核原callback调用顺序、实际action执行顺序都与持有顺序一致。新增精确“反向TOP插入错误”和“效果仍放BOTTOM”变异，分别在实际效果顺序和首shuffle状态断言处被拒；保留前两项首次洗牌与Soul方向负控。四个标准新入口各1.31–2.67秒，预算不变。旧Shop12项通过（3627ms），包含旧默认Abacus入口；架构通过。最终独审与本批完整CI继续单独绑定，不能引用928旧批准状态掩盖本次真实源时序修复。
