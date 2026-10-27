# Maw 与 Spire Growth 组合验证收口

本说明只收口 Maw、Spire Growth 两个普通遭遇的离线实现证据。最终组合版本为 `052bb57797e2882c3ec194fff47a66ddc58cc7bc`，由 `git rev-parse feat/m3-full-class-integration` 核实，父树当时无未提交文件。本次仅新增说明，不修改生产、测试、来源规则或 Backlog。

## 来源与红绿过程

固定来源仍为本地只读 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` ZIP；21个原始成员 SHA256、六条独立八行动向量及方法范围见[来源锁](../../tests/fixtures/act3-maw-growth-source-lock.json)和[规则说明](../rules/ACT3_MAW_GROWTH.md)。没有新增或改写来源数值。

| 阶段 | 版本与实际证据 |
| --- | --- |
| 公开入口最初红例 | 原母队列中的 Maw/Growth 返回 `act_content_unavailable`。没有裁剪完整遭遇池或借用其它怪物。 |
| 来源实现冻结 | `e6398c6edb8ec3fb6f4fd3dac3130e85cde7db2b`：保留18组全部断言，其中10组通过、8组因共享玩家轮末阶段尚缺而失败。Constricted 专属条件搬移原型已从生产移除。原规则说明及来源锁的待接线文字记录此时基线，不代表最终组合仍未接线。 |
| 正式共享阶段组件 | `3dc09134170103210675e1baeb9f12ed019cf859` 提供普通 Power 阶段与真实 source 对象载荷。inventory 在其环境只读加载 e639 源模块，18组全绿；本树固定3dc依赖组件验证亦全绿，8.308秒。这些不是完整 Shapes/300 卡组合验收。本地依赖接入 `8d9fe585` 不作为父树交付。 |
| 父树实际组合 | 冻结 `052bb57797e2882c3ec194fff47a66ddc58cc7bc` 功能合并正式阶段、完整300目录、Shapes与 Maw/Growth。原18组实际全绿，8.639秒，原默认30秒预算、向量和断言均未改变。 |

## 最终组合证据

真实日志位于 `F:/New folder/.worktrees/m3-full-class-integration/build/combined-act3-maw-growth.log`，结尾为 `ACT3_MAW_GROWTH 18 groups; 0 failed`、`8639 ms`。本代理只读复核日志和最终接线，没有在父树写文件或重跑重型测试。

18组覆盖真实 `Run.startRoomCombat`、HP与AI流完整状态、Maw整数连击与历史、Growth A0分支、Artifact、首次来源与叠层、死来源、THORNS算式、Burn/Combust/Ethereal次序、优先级、Host帮助、旧frame隔离、晚失败原引用回滚及同ID克隆来源拒绝。实际来源保存在 combat 根，player仅投影来源名称和ID原语；普通轮末队列捕获真实 actor 对象，不按ID或显示槽重找。

父树保留了 Shapes 的自毁、UNKNOWN wait 校验和两个派发器的 afterTurn 接线。Constricted 来源帮助迁至 `abyss_battle_info_content.ownedStatusText`，继续只读帧原语；提取后保留原 UI 每方法15的绝对门槛。本代理对此冻结源码的窄静态复审未发现新增实证 P1/P2。

父树相关定向日志也已只读核对：

- `build/final-owner_end_*.log`：8份普通轮末夹具，共39例通过。
- `build/final-act3_shapes.log`：17组通过，6.404秒。
- `build/final-act3_shapes_defect_integration.log`：正式 Buffer/Static Discharge 经最终 Exploder 伤害入口通过，1.001秒；没有在本片添加一次性 Buffer 消费。
- `build/final-run_turn_reward_rollback.log`：公开结束/选择及真实 WLP→Omega 暂停续跑的 throw/reject 六例通过，17.625秒。

父树另记录 Orb Walker 定向通过，以及工程156模块/897边、105项历史警告和四项语义变异通过；详见父树 [M3组合记录](M3-CLASS-INTEGRATION-20261027.md)。这些关联检查不替代后续完整冻结候选门禁。

## 证据边界

独立 Python 向量来自固定反编译方法，不是原版PC二进制执行。长算式夹具的1000HP只是明确的存活输入；真实 Run/Host 使用角色起始牌组和HP，没有将该夹具称为自然通关。共享阶段组件加载与父树正式组合分别记录，不把覆盖快照当完整基线。

本片没有新增整幕其它敌人、半死或Boss框架；未实现来源继续明确拒绝且保持原队列。上述结果是本地来源、生产入口、Host与定向组合证据，不是平台导入、实机UI验收、整幕自然通关、全Quality、发布或投稿证明。
