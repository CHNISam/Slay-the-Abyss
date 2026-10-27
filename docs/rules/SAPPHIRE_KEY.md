# 蓝钥匙：当前单遗物宝箱核心与本地界面

本地实现只接入当前实际支持的普通宝箱：既有生成器先给出一个未持有的普通遗物，或在无遗物可选时回退金币；Sapphire 自身不改写这一生成规则和随机消耗，**不等于原版完整宝箱随机规则**。本地 v2 另行接合 Darkstone 时，仅为新遗物增加已审查的目的楼层≤48候选条件；传入 node.floor 而非旧 run.floor，原生成片段/hash保持固定并通过精确逆变换验证其余字节，Boss准备/领奖块仍逐字不变。

## 固定来源与选择语义

来源为第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方开放源码或原作二进制执行证据。九份已核验精确字节的树路径、Git blob、大小和 SHA-256 在 `tests/fixtures/sapphire-treasure-source-contract.json`；Java原文和游戏素材不进入产品。

- [`AbstractChest.open`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/chests/AbstractChest.java) 的顺序是：先 `onChestOpen`，再金币/特殊宝箱诅咒和本体遗物，随后为最后加入的本体遗物绑定蓝钥匙，最后 `onChestOpenAfter`。不能把绑定顺序说成早于所有开箱钩子。
- [`AbstractRoom.addSapphireKey`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) 和 [`RewardItem`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/RewardItem.java) 建立双向互斥链接。选遗物会获得该遗物并作废对应钥匙；选蓝钥匙会作废该遗物，不会顺带领遗物或金币。
- [`ObtainKeyEffect`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/ObtainKeyEffect.java) 的 BLUE 结算只置蓝钥匙标记。当前核心事务直接提交这一游戏状态结果；未实现动画/音效时序。
- [`BossChest.open`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/chests/BossChest.java) 覆盖普通开箱流程，不提供蓝钥匙。现有 Boss 三选一领奖完全保留。

## 当前核心合同

`endingKeyEligible` 被 Ruby Recall 和蓝钥匙共用：必须是已有显式实验 campaign、有效章节、`endingUnlocked == true`，且三钥匙 owner 为严格布尔字段的普通表；已有蓝钥匙时不再提供。`endingUnlocked` 的真实历史产生与持久化仍未接线，命令不创造资格。

普通遗物宝箱准备时才建立 `reward.sapphireKey.relicId` 链接；金币 fallback、Boss 宝箱和开箱后才新增的资格不产生钥匙。`Nodes.view` 仍返回 detached 状态。

当前 NodeUI 在普通宝箱已打开且核心提供来源时，使用 `Nodes.treasureSource(run,map)` 获取 detached token；现有 take 领取遗物，根 confirm 页脚领取蓝钥匙，两者均调用 `Nodes.chooseTreasure(run,map,token,'relic'|'sapphire')`。token 绑定真实当前地图、路径末端、房间楼层/签名/种子、章节、`roomGeneration` 和该遗物身份。领奖先检查原 owner，再在 `Run.transaction` 私有图中重验；拒绝、异常及嵌套永久命令失败均不能留下部分资源或替换公共 owner。

为保持既有 API，`Nodes.claimTreasure(run)` 仍表示领取当前展示的遗物；成功获得遗物后在同一事务作废钥匙链接。它**不是新增 token 保护的 API**，不将既有所有回调统称为已加固。新蓝钥匙没有无 token 入口。

## 明确前置与未完成项

原版 [`Matryoshka.onChestOpen`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Matryoshka.java) 的额外遗物先于本体奖励加入，蓝钥匙只换本体遗物，不应吞掉额外遗物；[`CursedKey.onChestOpen`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/CursedKey.java) 在开箱而非领遗物时发出诅咒。来源目录保留这两件遗物的元数据，但当前产品没有可获得的运行时定义/实现。要支持这些交互，必须先建立独立奖励列表、一次性开箱和前/后开箱钩子的完整事务，再接源随机、诅咒与多遗物结算；不能把当前单奖励整房间完成机制冒称为已支持。新 token 入口遇到多奖励/未知字段会拒绝，避免静默吞奖。

本地 NodeUI 接合已通过生成控件树与模拟原生调用回归：只复用现有奖励行、take 和 confirm，明确选择蓝钥匙将放弃的遗物；私有渲染来源绑定原 owner/action，旧手势、观察到无效后修复、隐藏/脱离、缩放、取消和 native GetChild 同步重入均拒绝旧语义。默认两态、Boss 与金币 fallback、既有 Ruby 页脚不改。此处不证明真实客户端事件派发、字体或触控验收。真实历史产生/持久化仍未接线，完整宝箱 RNG/前后钩子/多奖励事务、原生导入/实机和四职业自然连续通关仍未验收。测试显式布置前置导航/历史资格，成功蓝钥匙本身通过公开命令获得，不直接注入；不证明资格已自然解锁或 M3/TASK-64 整体完成。
