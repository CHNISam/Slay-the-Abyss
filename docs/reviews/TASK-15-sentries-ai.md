# TASK-15 哨卫与人工制品：首幕A0离线切片

2026-10-23，`feat/continue-sentries`，基线`0936c6e`。开发分阶段：Actor人工制品基础先独立红绿，再与Dazed状态牌接口组合，最后接真实ApplyPower调用。基础完成不代表三哨卫或实际卡牌/药水入口通过；未开原神、MCP、平台编译/副本写入/官方导入或实机。全部全池与平台AC保留。

## 固定来源与真实性

本轮实际完整只读取得固定社区镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。UTF-8内容SHA256如下；镜像未经目标正版PC构建号/二进制hash认证，不是官方开源或原作客户端观察，也不证明与其他反编译镜像独立。

| 文件 | SHA256 |
|---|---|
| [Sentry.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Sentry.java) | `5A3837CDF1B4EF4383FC7E1385C8C64A0C92BC04916C9C4F919D79080980ACB2` |
| [ArtifactPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ArtifactPower.java) | `7F0C3A5DF2F204C6F0FA3FB152A807895B330F26B0F0970F4EF060EE9B919AC7` |
| [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `F64CE8511F961A1990F1909E2C55654FA6DBF1DC2F4F1F3D3A7156C2EC2A9D47` |
| [StrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StrengthPower.java) | `20B05040EFE9D6AD693DD763A658C86DF9DB1B1AC365351C4C8D81C7F6CA08C9` |
| [DexterityPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DexterityPower.java) | `1FDC782315CAAD88C9B438684F12A6C55AC9C82070D9BFBD01B505048638275C` |
| [LoseStrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/LoseStrengthPower.java) | `062155ED7ACF49B9C60F1BF1B2583BBC060A762253C3F7A7246F42F995C7D1A1` |
| [Flex.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Flex.java) | `24F8427B9C45247A613D8925DC9CB793BA6AC0DA3DB0859DE7287B2025CA95EF` |
| [WeakPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/WeakPower.java) | `17072C70FFBF219440DEA75069910630D745654C4BF58CF528E937A7D747D973` |
| [VulnerablePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/VulnerablePower.java) | `354B0DFFA4F9763B9933266E3DFA96F561841B96C251F3F336693991A91DD191` |
| [FrailPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/FrailPower.java) | `9530396BE8C2E748A11FA9CFF66BE4B94C39A5FAD3BFCD52FA98FD1A76BA5C96` |
| [PoisonPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/PoisonPower.java) | `B4269EAFB2A23282142E9C5460510E4A876D7ABB3C62AE6D7A2211B5826AC6C2` |

没有复制、执行或提交上游程序。原作随机流、构建身份、完整power hooks/免疫和平台实测仍是独立验收项。

## Actor基础：真实ApplyPower与原始修改分开

新增`Actor.applyPower(state,target,id,amount,source)`，保留`status/addStatus`原始状态修改语义，不能把公共raw helper当作原作ApplyPowerAction。来源明确的当前分类只包括Weak/Vulnerable/Frail/Poison，以及传入amount<=0的Strength/Dexterity；按传入Power分类，不看目标叠加后的总值。ApplyPowerAction没有零层提前退出，故零Weak与零Strength/Dexterity也消耗一层Artifact。正力量等buff不消费，即使已有999上限使实际增量为0。

未知id、非法数值在消费前拒绝；死target取消应用；死source本身不取消给活target的已排队施加。拦截不写入目标减益或JustApplied，消耗事件复用现有`status`类型的artifact -1，附blockedStatus供取证。当前0层状态表示该Power已不存在，不引入“持有0层ArtifactPower对象”的特殊模型。

Flex源码先排Strength，再排LoseStrength（DEBUFF）；后者触发时再排负Strength与移除自身。本项目继续用temporaryStrength字段表达LoseStrength bookkeeping，真实入口调用`addTemporaryStrength(actor,amount,state)`：先正Strength，再独立拦截或记录LoseStrength；旧两参调用仍为raw setup，不自行制造ApplyPower。owner end负Strength走真实applyPower，清除bookkeeping不再被误当一次减益。因而Flex前Artifact可以挡LoseStrength，Flex后获得Artifact则可挡期末负Strength；已有LoseStrength的累积不被一次被拦新应用抹掉。

真实state路径由Actor发一次力量事件；桥接Effects时须移除原手动同事件，避免重复。无Artifact的既有帧表达与原地回滚保留。主题复用已批准状态图标103066，不改布局、配色或字号。

当前尚未引入source power的onApplyPower、Artifact以外免疫、halfDead/escaping或所有特殊Power类型。不能从这些有限分类扩推未实现能力；Dazed生成是卡牌动作，不走ApplyPower，不能被Artifact抵挡。

## 基础阶段验证

`artifact_power.lua`初始15组全红，首个明确失败为缺Artifact定义；实现后15绿，补死target真实Flex测试发现Artifact错误消耗，再修guard后16组绿。覆盖当前四类减益、重复/已有状态、signed stat负/零、零普通减益、cap后无效buff、非法输入/死target不耗、raw mutation不拦、dead source、两种Flex时间点与旧bookkeeping。

现有Flex16组与signed caps12组通过。此阶段尚未桥接Effects/Inventory，也未合Dazed实现，故不宣称真实卡牌/药水Artifact或三Sentry入口已通过。

## 三哨卫与真实Dazed接口阶段

已合独立Dazed基础提交`7b1236f`（本分支cherry-pick为`ad41d67`）；其固定MakeTempCard/Dazed/CardGroup来源及有限ABI见[DAZED_STATUS_CARDS](../rules/DAZED_STATUS_CARDS.md)，不是Weak替代。

Sentry A0为HP38–42，Beam基础9，Bolt生成两张Dazed；A8+HP39–45、A3+Beam10、A18+Dazed3不适用。预战Artifact1。首动按整个敌方列表的位置（Java零基偶数Bolt、奇数Beam），不是只数Sentry实例；后续两动作交替。getMove不看主roll，但每次rollMove仍消费一次主整数，Beam反伤致死时若有队友则保留排队roll，沿用已核共享调度。

新增独立`abyss_sentry_ai`，初始化扫描完整state.enemies位置、选择正确开场、给予Artifact；EnemyAI只增加分派与sentry queuedRoll白名单。数据保留Beam9，明确将旧Weak1替换为`makeTempCardInDiscard/card=dazed/value=2`，并加真实HP范围。AI schema要求Bolt确实生成Dazed，不能悄悄用Power替代。主题和原生打包均覆盖新依赖。

`sentries.lua`9组先全红，明确旧首轮27伤而非9；实现及真实Dazed组合后9绿。64种子×3实例覆盖全部HP端点/Artifact1；首动错位、混合敌人列表位置、三自然回合HP71/53/44与累计Dazed4/6/10、玩家Artifact不挡Dazed、roll0/99消费、Beam反伤死后roll/下一轮不复活、原始毒setup行动前致死，以及真实Run elite_sentries入口均通过。毒setup用raw helper作边界夹具，不冒充一次被Artifact允许的Poison应用；Run直接设合法层为入口，不声称完成地图路线。

Sentry/Dazed/schema/原生打包25项JavaScript通过，Dazed既有21组再次通过。当前阶段真实Artifact牌/瓶测试仍有3组红（对应尚未桥接），另已核BattleTrance NoDraw特殊Power缺口，后续独立桥接验证，不能把本阶段三敌绿扩推完整Artifact已接线。

生产仍使用共享16位LCG，HP/AI/洗牌相关、原版独立流/种子映射与同种子轨迹未对齐；setup事件中的预战Power表现次序未作原版动画队列认证。平台等独立AC保持。

## 真实Power桥接、NoDraw与只读意图

独立桥接将Effects的gainStatus/applyStatus/applyStatusAll（包括死source的已排队单目标段）与Inventory真实状态应用改为Actor.applyPower；Inventory忽略“被Artifact拦截”的false结果并成功结束使用，不把正常抵挡当成命令拒绝。Flex真实入口传state，删除原手动重复力量事件；清bookkeeping、事务快照和已排队状态/roll顺序保留。

另实际完整读取 [NoDrawPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/NoDrawPower.java)，SHA256 `3206760968D070DE2705010D8FD2718641D674B7571602E00C0D27933382D83A`，及 [BattleTrance.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/BattleTrance.java)，SHA256 `8A13E848B23AF5610B1BCF6A2D57B5E8777B19468B1C269C7ECEC099E5400BA3`。Battle Trance先抽牌再排NoDraw（DEBUFF）；ApplyPowerAction.update的“已有NoDraw则取消”位于Artifact gate之前。因此新增有限Actor.applyNoDraw：死亡/已有flag先取消，不耗Artifact；首次NoDraw才允许Artifact挡。没有把任意boolean字段或未支持Power纳入通用名单。

真实state的临时力量helper现在显式限制amount>0，0会在任何消费前拒绝；raw两参0保留兼容。这是候选ABI收窄，不是原版拒绝Flex0。源中LoseStrength(0)仍可能有对象存在并在轮末触发，本模型没有此存在位，也没有真正Artifact(0)对象；两种零对象语义均不宣称支持。正式Flex2/4不受影响。

库存语义由独立预审重新只读核对同提交PoisonPotion/其它六瓶、PotionPopUp与AbstractPotion：毒瓶排Poison6，使用后销毁瓶槽与后续ApplyPower是否被挡无关；view/canUse不因Artifact而禁用。其余六瓶为正buff或非Power。预审来源仍未认证PC身份，不能将镜像读取当原作实测。实际测试断言7瓶数值沿既有来源，不从当前JSON自生成Oracle。

Bolt原生意图曾实际显示“?”，新增makeTempCardInDiscard只读渲染分支后显示“晕眩 2”，详情说明将2张置入弃牌堆，沿现有debuff图标/配色/布局，不新建模板。完整生成控件树测试先见“?”红灯，再验证外侧/中央两轮标签、图标、Artifact状态文本、实际按钮伤害71→53；重复四次查看意图后整个combat状态与深拷贝逐项相同。

真实Artifact入口5组原有3红，桥接后全绿并扩到9组：Thunderclap同时耗三敌Artifact、后续Bash生效、Bash晚错误原地恢复所有引用/状态/事件、毒瓶被挡仍耗且第二瓶施加6、view连续预检不改live敌人/瓶/事件/seed、已有Poison4被挡不叠加且其tick不再耗层、其它六瓶及正buff封顶不耗、非法瓶效果和死/非法目标不耗层或瓶。NoDraw6组原5红后全绿，含实际Trance、重复flag特殊gate、死亡、只读canPlay与晚错误回滚。Actor基础零Flex新红例修后为18组绿。

完成桥接后顺序复跑15套必要Lua：Artifact基础18/真实入口9/NoDraw6、Sentry9/原生UI、Dazed21、Flex16、signed caps12、atomic play14、inventory11、potion slots6、queued status20/roll15、round debuffs17、card feedback10，全部通过；日志为本地`build/sentry-bridge-*.log`。不把这些有限分类、非事务endTurn、临时状态对象或source hooks扩大为完整原作能力队列认证。未跑本片全量check、未平台构建/导入/实机，交主线程统一组合验收。
