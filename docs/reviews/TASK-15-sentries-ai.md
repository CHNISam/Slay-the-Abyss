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
