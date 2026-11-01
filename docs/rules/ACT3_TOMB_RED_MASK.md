# 红面具领主之墓与 Red Mask

基线 `680c423a`（业务 `2349400c`）。本片仅接第三幕 Tomb of Lord Red Mask 的全部分支，以及必要的单件 Red Mask。未接其它事件/怪物/遗物，不修改伤害、回合末或职业牌，不改变概率母池。

## 固定来源

来源为本地固定第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方源码/正版PC执行。`tests/fixtures/tomb-red-mask-source.json` 锁定 ZIP SHA256 和 12 个原始成员；旧来源锁、149 个注册序、130 个遗物队列成员及第三幕七项事件母池均保持。

| 固定方法 | 实际合同 |
| --- | --- |
| TombRedMask constructor / buttonEffect | 已持面具：戴面具直接获得222金币，不消耗面具；无面具：禁用戴面具，支付点击时当前全部金币获得固定 Red Mask，0金币合法。拿取后只有结果页 Leave；初始 Leave 直接返回地图。 |
| TheBeyond.initializeEventList / AbstractDungeon.getEvent | 第三幕普通事件，无额外金币或HP门槛。只移除选中的事件，不删缺项或重抽。构造/选择不额外抽取随机流。 |
| AbstractPlayer.gainGold/loseGold | 222为直接入账，受 Ectoplasm 阻止，不是 GOLD RewardItem，不吃 Golden Idol 奖励加成。事件支付不触发商店 onSpendGold；固定源无遗物覆写 onLoseGold。 |
| RedMask.atBattleStart / WeakPower | SPECIAL，来源ID为 `Red Mask`；每战按所有敌人顺序 BOT ApplyPower Weak1，WeakPower 的 isSourceMonster=false。Artifact 按实际持有顺序抵挡；首轮攻击受弱化，轮末清除。 |

新增纯事件模块委派现有 Act3/Nodes 事务，未增加普通卡/药水选择状态。固定 named obtain 复用 `Run.obtainRelic`，不抽遗物池。开战在既有 `Inventory.opening.afterDraw` 计划中登记本件 hook，沿用实际持有顺序；不扩建队列框架。节点原生 UI 只读选项、状态和结果。

## 来源入口与独立预期

`tools/oracles/sts1_tomb_red_mask.py` 仅复用独立整数 RNG 模型，不导入生产 Lua/数据。锁定六个金币边界和完整 Act3 源选择：seed `'14'` / floor35，第六项 Tomb，eventRng counter1、selection counter3、房间 misc counter0，均核对完整 words。选择后只去掉 Tomb，once/shrine 原样；支付固定面具不耗 relic/misc RNG。

真实 `Run + Map + Nodes.enter` 在原树 RED 为 `event_not_implemented`，1.531秒；原资源/七项池不变。接入后自然入口 GREEN，最终新增完整 words 断言为1.320秒。这里用实际完整七项池，但从受控第三幕房间边界开始，不是整幕/完整游戏自然通关。

双战组件使用 seed9，第一场 Orb Walker、第二场3 Shapes。该前缀另用固定 TheBeyond 原始方法和独立 `sts1_chapter_queues` 整数模型核对；不移走不支持的遭遇。早期测试误以为 seed4 第二场已支持，实际为3 Darklings，已改测试种子而未改源池/重抽。末敌1HP和初始敌 Artifact1为明确效果边界，不作为自然生存或神器取得证明。

## 本地验证

7份专用 Lua 分别通过，默认每份30秒未改；未为避开Root长例并发而提高限时：

- `tomb_red_mask_natural`：完整七项来源、精确随机 words/移除、实际支付得面具、固定 obtain 不抽遗物池。
- `tomb_red_mask_event`：0/99金币、持面具222、Ectoplasm0；禁用分支、结果和重复命令。此脚本3.894秒，其余均小于3秒。已有面具使用永久库存命令设置分支；Ectoplasm为既有金币 hook 的受控持有ID，不宣称它的自然取得。
- `tomb_red_mask_guards`：点击前新增金币仍支付全部；Maw Bank进房12也计入，不误触发商店停用；初始离开、非法选项/UID/章节不改变资源。
- `tomb_red_mask_rollback`：扣金币后缺固定遗物、222已入账后异常、全池构造晚异常，完整数值/外部地图与原事件/库存/牌组/池/RNG对象恢复，并可重试。
- `tomb_red_mask_opening`：真实事件取得后，面具与 Bag of Marbles 持有两种顺序消耗 Artifact，BOT 在常规抽牌后；与仅移除被测遗物的同房间对照，手牌及HP/AI/cardRandom/shuffle/misc流一致。首轮弱化后消失，跨领奖后的第二场重新对全敌施弱。
- `tomb_red_mask_opening_rollback`：实际下一来源房间已施弱后抛错，Run/地图/节点/牌组/遗物/遭遇队列/RNG原图恢复，重试成功。
- `tomb_red_mask_ui`：实际原生节点模块的无面具禁用、0金币说明、支付/222结果、一次性按钮、旧callback/新Run/隐藏面板拒绝。仅 headless 假控件，无窗口输入。

Python oracle `--check`、3项新来源JS断言、原8项完整遗物目录/源队列断言共11项通过。数据与离线UI构建通过。Architecture 158模块/917边通过；固定 Luacheck 1.2.0 无新增诊断，105条历史警告，UI函数≤15/render≤10原阈值。

NodeUI只新增1行文案，父明确批准14条历史诊断严格迁移。`docs/evidence/tomb-red-mask-diagnostics.json` 记录原/新行、原源行trim文本、column/code/message及upvalue源行映射；没有新增/删除诊断、扩宽豁免或调整阈值。当前遗物账本从全bindings重算：本地45、注册44、fallback1；第一幕missing98及queueMissing91不因本件后幕SPECIAL而改变。

## 未验与依赖边界

保留 Orichalcum、Tungsten Rod、Transient、Sensory 的既有实现，没有复制其它代理的Toxic Egg文件。未重跑已经通过的整批旧用例、重型矩阵或全量CI；完整launch组合门禁由父线程按Root窗口复验。未宣称其它遗物/事件全齐。

Red Mask 当前实际来源只有 Tomb；原作 Masked Bandits 路径仍未实现，不登记为已可获。持面具分支不是“由第一幕自然走完整游戏”的证据。专属遗物美术暂用明确占位图标；正版PC认证、完整自然关卡、平台编译/导入、设备UI与实机证据均未验，父AC不勾。
