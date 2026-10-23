# 开战遗物队列：独立负向证据

## 结论

2026-10-23，在 `develop@ed39f4653ddb555391c0dfe5a4507d1f58387171` 通过真实 `Run.startCombat` 读取既有事件帧，发现 TASK-14.1 尚未核实的开战顺序与固定资料不符：

- 裂岩杵、光滑岩片、铜鳞应在普通起手抽牌前施加能力，并按持有列表的逆序执行；当前在抽牌后按正序执行，能力事件帧已含 5 张手牌。
- 启程灯的首回合能量应先于上述能力，当前也在抽牌后处理。
- 石锚和备战袋属于队尾动作，应保留相互顺序并在普通抽牌后执行；这两个控制例当前正确。

**现有六件遗物的最终手牌、格挡、能量和能力数值仍符合既有测试；本次没有证明当前支持内容产生不同的最终玩法结果。** 此处是中间队列／事件帧的一致性缺口，不称作已证实的玩家可见或平衡缺陷，也不添加未支持的抽牌触发内容来制造失败。

## 来源链

以下主证据均来自只读反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。它不是官方源码或已认证 PC 二进制；项目此前记录其自报 2.3.4，本次不据此认证版本。顺序是由方法体推导，不是原作运行录像；未安装、执行或复制镜像实现。

1. **持有顺序。** [AbstractRelic.obtain / instantObtain，L240–280](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/AbstractRelic.java#L240-L280) 将普通取得的遗物追加到列表。指定槽位重载 L207–239 可以替换，所以准确说法是“持有列表顺序”，通常才等于取得顺序。
2. **准备阶段。** [AbstractPlayer.preBattlePrep，L1546–1590](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1546-L1590) 清空手牌并调用 energy.prep；[EnergyManager.prep，L20–23](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/EnergyManager.java#L20-L23) 将可用能量归零。
3. **开战调度。** [AbstractRoom.update，L220–249](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L220-L249) 等此前准备动作排空，依次把基础能量加入队尾、调用战前抽牌钩子、把普通抽牌和启用操作加入队尾，然后调用开战、回合开始及抽牌后等钩子。此阶段先完成入队，尚未执行新动作。
4. **列表遍历。** [AbstractPlayer 分派，L1874–1910](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1874-L1910) 对各钩子正序遍历持有列表，不按遗物 ID 排序。
5. **开战队首能力。** [Vajra，L27–31](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Vajra.java#L27-L31)、[Oddly Smooth Stone，L27–31](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/OddlySmoothStone.java#L27-L31)、[Bronze Scales，L26–29](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/BronzeScales.java#L26-L29) 在开战钩子中将能力加入队首，因此三者实际按列表逆序执行，且早于普通抽牌。
6. **启程灯。** [Lantern，L45–59](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Lantern.java#L45-L59) 在准备阶段重置 firstTurn，在稍后分派的首回合钩子中把能量加入队首。因此它不受自身列表位置影响，先于上述能力；能力执行时可用能量为 1。GainEnergyAction.update 与 GainEnergyAndEnableControlsAction.update 都是加能量，后续基础能量不会覆盖这一点。
7. **开战队尾动作。** [Anchor，L28–33](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Anchor.java#L28-L33)、[Bag of Preparation，L26–30](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/BagOfPreparation.java#L26-L30) 追加队尾，保留两者相对持有顺序，晚于普通抽牌。
8. **实际出队。** [GameActionManager，L78–89](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L78-L89) 将 nextCombatActions 追加队尾；addToTop 在 L128–132 插入索引 0，getNextAction 在 L174–178 取出索引 0。因此队首／队尾确实决定执行顺序。

交叉核对：[fadedwind 固定镜像 AbstractRoom，L292–317](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/rooms/AbstractRoom.java#L292-L317) 与 [Vajra，L23–31](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/relics/Vajra.java#L23-L31) 支持对应两环；不宣称两镜像来源独立或完成所有规则交叉验证。

例如持有顺序为“石锚、裂岩杵、备战袋、启程灯、光滑岩片、铜鳞”时，忽略纯视觉动作，推导顺序为：启程灯 +1 能量 → 铜鳞 → 光滑岩片 → 裂岩杵 → 基础 +3 能量 → 普通抽 5 → 石锚格挡 10 → 备战袋抽 2。当前则先完成基础能量／抽牌，再按持有顺序执行全部遗物。

## 复现

独立脚本：`tools/parity/opening_relic_order.lua`。它只配置持有遗物夹具、调用真实开战入口并读取既有帧；没有替代调度器、函数注入或战斗状态篡改。持有夹具不等于自然获取／奖励概率验证。

可在仓库复用的标准复现命令（需已有项目依赖）：

    node scripts/build-lua-data.mjs
    node scripts/test-lua.mjs tools/parity/opening_relic_order.lua

本次实际执行使用预存系统 Lua 5.4 库及本地保留的 `run-lua.py`。该辅助脚本不随本次提交；以下仅记录本地验证命令，不是仓库复现入口：

    python run-lua.py tools/parity/opening_relic_order.lua

结果：**3 组通过、11 组失败，退出码 1**。

- 三件能力遗物：事件帧手牌实际 5，预期 0。
- 三件能力的六种排列：均未按队首规则逆序执行。
- 启程灯前后两种位置：能力帧能量实际分别为 3、4，预期均为 1。
- 控制例通过：石锚→备战袋的格挡帧手牌 5；备战袋→石锚为 7；无遗物保持普通起手与能量。

同基线既有 `inventory`、`inventory_parity`、`potion_slots` 共 11+10+6 组通过。40 个原始输入文件与固定提交 Git blob 一致；完整输出 `evidence/opening-red.log` 和校验记录 `evidence/base-verification.log` 仅作为本地验证文件保留，不随本次提交。仓库交付仅含本文与 `tools/parity/opening_relic_order.lua`。

脚本位于 `tools/parity`，**不纳入普通 CI 自动发现**；缺口未修复时返回非零是预期诊断结果，不把失败包装成通过。

## 未完成

- 没有修改生产代码或 Backlog 状态；TASK-14.1 整体验收仍未完成。
- 系统 Lua 5.4 结果不替代 Fengari、当前提交正式 CI、平台编译／导入或原作实测。
- 修复须与当前 Run／Combat 负责人协调。不能简单倒序全部遗物、把全部效果挪到抽牌前或只强设启程灯最终能量；队首能力、首回合能量、队尾遗物、基础能量与抽牌需分别处理。本证据不主张扩大为全面调度器重写。
