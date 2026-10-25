# 观者姿态：首个离线切片

本切片在877c4af基础上独立实现姿态、能量事件和伤害倍率接口，后续接入六张明确的基础姿态卡；未实现观者完整职业、真言或平台接入。未提交、推送、导入或实机验证。远端迁移仍暂停，本轮独立树开发依据用户针对本轮隔离开发的明确豁免，不解除认领协议。

## 固定依据

以仓库既有的社区反编译源 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)核对方法语义后独立实现，没有复制方法体。镜像不等于官方开源或正版二进制认证。2026-10-25只读下载核对，文件原始字节SHA256如下。

| 文件（均相对固定提交） | 规则 | SHA256 |
| --- | --- | --- |
| stances/WrathStance.java | NORMAL造成和受到伤害各乘2，其他伤害不变 | f7533a1aff6ffe67bc16ab710fc6e45a8ca6016b44a5a41fcc4d110d4bc2b691 |
| stances/CalmStance.java | 退出时队尾排入2能量 | e2bbe0b48317ea4033ef497d4285c5ca48ae47d7fff768ecdba781ef5c9b8981 |
| stances/DivinityStance.java | NORMAL造成伤害乘3；进入队尾排入3能量；下个自身回合开始排入退出 | 7363a98527c6009ba491fd9d3f6c1dfbaffc833972211218ebf8bfeb34c3fce7 |
| actions/watcher/ChangeStanceAction.java | CannotChange提前结束；同姿态不重复；能力→遗物钩子→旧姿态退出→新姿态进入 | 47392dbaacb9627f88f047008cbe7fb90b550acae1f491099470f1d2d080e877 |
| relics/VioletLotus.java | 退出平静时由遗物钩子先排入额外1能量 | d54d310e5c81c5e95f9256a167e95c740bbfac45f182ebc6896c82d2ffe214b5 |
| powers/watcher/MantraPower.java | 暂不支持，见下文边界 | a28abb19643bcce1c9899e1ac72f0f8bf966da4b2644de1c130e32c8986fa5af |

真言镜像只在stackPower达到10时执行一次扣10并队首排入神格；构造/首次施加没有同一阈值逻辑。初次直接10、一次增加20和已处于神格再次达到阈值，均需独立核实调用链和实测；本模块不猜测实现，也没有把它改成while循环。

## 接口与接入契约

- `state.player.stance`：Neutral、Wrath、Calm、Divinity；未初始化视为Neutral。`reset(state)`不触发姿态退出收益，清除残留能量事件。
- `change(state,id,options)`执行一个已经轮到的切姿态动作。`options`只允许布尔`cannotChange`和`violetLotus`，由拥有者从已验证状态/遗物映射。相同姿态、禁止切换或终局返回false，不产生收益。
- `state.stanceQueue`暂存有序能量事件；紫莲花1先于平静退出2，神格进入3在后。`flush(state)`在共享动作队列轮到这些事件时应用到真实`state.energy`，逐笔发出energy事件和真实Combat帧；死亡/终局清除队列。总能量溢出在任意部分写入前拒绝。
- `startTurn(state,options)`只执行已经轮到的神格退出，不自行flush。集成必须把它安排在下一次自身回合开始的正确时点，不能在本回合结束提前退出。
- `damageMultiplier(state,source,target,fixed)`只返回倍率。在共享Actor.attackAmount的最终floor前乘入，且只乘一次；不可预乘base后让Strength再次独立叠加。fixed=true一律倍率1；模块不执行伤害、格挡、反伤或死亡逻辑。

姿态模块工作者未修改共享Combat/Actor。主线程后续已同步共享接入到本树，真实Combat使用`enableStances=true`启用姿态；未启用时保持旧行为。第一阶段15组测试中的普通伤害倍率验证为接口检查，第二阶段卡牌测试则已通过真实Combat.play和普通伤害入口验证旧姿态伤害计算、后置姿态切换及退款。完整状态/遗物映射仍未接入，不宣称全部姿态相关遗物或能力可用。

当前Combat并非通用原版动作调度器；本切片不假造一个平行战斗引擎。对于切姿态动作之后但能量收益之前已有其他排队动作的复杂卡牌，必须由未来共享队列保证FIFO，不能在每个change内部立刻flush。尚未支持一般能力姿态钩子、姿态遗物、弃牌触发、Rushdown等卡牌回手或同姿态统计，只有已核紫莲花能量钩子。因而不可把此模块称为完整ChangeStanceAction复刻。

## 本轮验证

在独立树执行`npm ci --ignore-scripts --cache /workspace/.npm-cache`、`npm run build:data`和`node scripts/test-lua.mjs tests/lua/watcher_stances.lua`。15组定向回归覆盖倍率、fixed入口、同姿态、禁止切换、能量排序/帧、神格下一回合退出、真实卡牌费用、战后清理、终局/死亡、非法输入及原子溢出；均通过。未运行完整check，未做自然获取、整局通关或平台验收。

## 六张基础姿态卡片（下一切片）

`abyss_watcher_cards.withFoundationCards(data)`返回独立拷贝并追加六张明确的测试候选定义；不改变原始数据、职业初始牌组、常规奖励或商店池。重复追加同ID会拒绝。英文名称暂为来源识别用，不是已交付的原生中文表现资源。

固定提交同上，以下路径均位于`cards/purple/`。本轮逐份只读核实费用、属性、use内动作次序和升级方法后独立写数据。

| 卡 | 基础→升级 | 动作次序及特殊属性 | 原始文件SHA256 |
| --- | --- | --- | --- |
| Eruption.java | 2费→1费，9伤不变 | 先伤害后愤怒 | 709cb1c7fd941984124d4cdaf6dc7d317c622c2b9c1beb1dc1d0442648bc083f |
| Vigilance.java | 2费，8→12格挡 | 先格挡后平静 | c5fbc16bc8ffc2850b89156fa0ed74607673f8ed62ccf1fdf4e174161e348b99 |
| EmptyFist.java | 1费，9→14伤 | 先伤害后退出姿态 | ab6b4ae4cff1bb618ef4c8deea4070237f55293e96cd222456b5926dceebd6a3 |
| EmptyBody.java | 1费，7→10格挡 | 先格挡后退出姿态 | 07c8bd36d99af514b2c0c1e6161576139583a521479e3359ed9695e2c317f9ec |
| Crescendo.java | 1费→0费 | 保留、消耗，进入愤怒 | b76fde380d0f96a314e30a97b91d0ebac5425b50cebea02dc943469670ed99c0 |
| Tranquility.java | 1费→0费 | 保留、消耗，进入平静 | 89ad313be3f7140a38ea28b32c562924b62dcd0eef175fb78d80688df4c77815 |

测试`tests/lua/watcher_cards.lua`使用真实Combat.new/play/endTurn，覆盖全部基础/升级、费用、旧姿态伤害、退出平静能量、末敌死亡取消后续姿态、保留及满手容量。先在未接入共享效果时观察到Eruption能力检查红例；主线程同步共享`changeStance`效果和`selfRetain`生命周期后，使用明确`enableStances=true`运行12组全部通过（`WATCHER_CARDS_PASS 12`）。随后重跑15组姿态定向回归也全部通过，`git diff --check`通过。

这证明六牌在独立显式数据夹具中经真实战斗入口可执行，不能替代正式职业开局、自然获取/升级、中文表现、全职业回归或平台实玩。保留仅支持卡牌自身`selfRetain`，不是任意保留能力、Runic Pyramid或Equilibrium的实现。

## 能力与循环接入

固定319009核对并实现Rushdown、MentalFortress、InnerPeace。`state.stancePowerOrder`记录相对获得顺序，能力动作先于姿态能量入队；共享Combat在使用牌完成处置后调用`flush(state,Combat)`。Mental Fortress的固定能力格挡不套用敏捷/脆弱；Rushdown在进入Wrath时抽牌。`watcher_powers.lua`保存原始源文件SHA256、有限10轮真实循环和能力顺序/回滚回归。原先“通用能力钩子尚未接入”的说明只剩其他未支持能力，不能据这三张牌声明整个职业完整。
