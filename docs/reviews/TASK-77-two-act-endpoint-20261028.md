# TASK-77 · 前两幕比赛终点（本地实现证据）

## 边界

正式 `abyss_ui.OnStart` 显式传入 `campaign=true` 与 `campaignProfile="competition-two-act"`，保留第一幕接续第二幕。`Run.new` 校验该配置；`full-source` 是保留未来第三/四幕及既有测试的显式配置，省略配置的既有开发调用维持兼容。未删除未来章节、旧source规则或历史证据。

- `Run.advanceAct` 拒绝比赛配置的第二幕至后续幕转换；`Nodes.enter` 与 `Run.startRoomCombat` 也拒绝该配置下的第三/四幕。
- 两个Boss宝箱完成入口共用 `finishBossTreasure`：第二幕合法34层领取/跳过均为 `victory`、`ending="two_act_complete"`，不产生 `pendingAct=3`。第一幕仍按既有17层转换进入第二幕。
- 结果页为“双幕挑战完成”、明确本局前两幕结束；胜败层数分母均由第二幕定义推导为34。平台 `ABYSS_WIN` 只提交本局双幕挑战胜利，不代表source完整战役 `_WIN`。
- 比赛配置不读取Neow/Ending跨局历史、不产生 `_SPIRITS` session history，也不注册/写入source `_WIN`。不提供退出续玩、解锁或新存储后端。同局卡组、生命、金币、遗物、药水、随机流、事务和临时快照保留。重新启程新建一局；退出确认沿用“本局进度不会保留”的明确提示。
- 钥匙沿用source“最终幕不可用”的策略：无Recall/蓝钥匙、无燃烧精英选择及其额外buff。普通地图拓扑、战斗数值与原随机池不改。无关联蓝钥匙的宝箱不再显示蓝钥匙二选一提示。

## 受控测试不是自然通关

新增/更新回归通过真实 `OnStart`、Host.start、Nodes与Run命令串联第一/二幕及两种终点；构造真实首领战斗并用受控最终伤害完成，跳过中间房间的游玩。它证明接口和状态边界，不是自然通关、平台导入、ready或实机证据。测试覆盖重复/过期领取、非法换幕、奖励hook失败回滚、临时快照恢复、四source职业资源接续、四原创角色选择、胜败结算、重开和退出取消/确认。

**遗物池缺口仍未解决（TASK-14.1）**：当前正式source Boss随机池仍可抽到未实现遗物，UI会显示不可领取。原seed42端点领取测试因第二箱全部不可用而失败；seed3的第一箱包含Sozu，但第二箱为Pandora's Box、Calling Bell、Coffee Dripper，仍全部不可用。端点领取回归改用seed2（第二箱含已实现Sozu）；核心单箱受控回归用seed3。选seed只是取得一个合法可领取接口输入，不证明随机遗物池齐备。本patch没有缩池、替换奖励或修改概率来掩盖该既有M3发布缺口。

## 历史证明的精确增量

- 原公告退役压缩source归档、原strict native trace及其hash不改。
- 原生入口只逆转一个完整 `campaignProfile="competition-two-act"` 参数片段，先核对原accepted入口hash `4fdb5660…`，再沿用原campaign opt-in逆转与更早source hash。
- Host增加八个精确可逆片段，见 `tests/fixtures/competition-two-act-host-projection.json`；当前完整source身份先锁定，逆转后必须等于原退役Host hash `37b8c0b4…`。缺失、重复、结果/历史/交互及无关漂移均拒绝；旧hash不刷新。
- Sapphire旧BossClaim证明只把新的 `return finishBossTreasure(run)` 调度逆转为原四行完成逻辑，继续校验原完整frozen block hash；原奖励和资格断言不删。

## 验证层次

本地生成、相关回归、架构、固定Luacheck与JS语法检查分别记录。最终完整Quality、同一候选官方导入/ready、自然两幕通关、实机UI、投稿与发布均未在本切片执行，不以本地受控回归替代。Backlog与最终集成由主线程单独核对；本切片不修改Backlog。

### 本轮本地结果

- 数据、UI与主题生成通过；架构214模块/1238依赖边、固定Luacheck84条既有诊断/418项受治理函数测量通过，无静态基线豁免更新；JS语法与diff空白检查通过。
- 新比赛核心7组、正式OnStart领取/跳过/重开/胜败/退出、明确full-source旧场景与精确source逆转负例通过。
- 相关核心/跨幕/EndingHistory/Neow批次12/12通过；Ruby全部15组、Sapphire全部21组及Emerald map通过。
- 原79543与79757写strict trace重放通过；当前79689写、hash2034622601的strict live trace保持完全不变；原game_ui16组及startup/mock/exit/budget7项通过。
- 相关UI/历史批次25/26通过，唯一失败为**规划基线已有**的`CHANGELOG.md`历史source绑定：19f715aa规划说明改动使实际hash为`8f2e50de5a6a87c33fdc3bb771d499794ea651c0ce80a2d4e70c27710d3b8939`，原不可变证明仍期望`f0f2411ed93489ebc87496415675f323736d0b281e643d4dc6a88acf83b5add7`。e46bd5dd原文件与旧hash一致，19f715aa→a43f717c未再修改此文件。本patch未修改CHANGELOG或绕过该失败，主线程已获知需在规划侧精确处理。它不影响上述已实际运行的strict trace，但当前组合不能宣称完整Quality通过。

### 独立审查补正：OPEN时的Sapphire offer门禁

独立审查发现b49a3603的注入`endingUnlocked=true`防御回归只在房间创建后检查尚为空的奖励列表，漏掉`Treasure.open`才追加钥匙的实际时点。直接领取虽被Nodes拒绝，打开普通宝箱后仍会出现不可领的蓝钥匙项；这违反本切片已承诺的比赛UI和资格语义，并非自然历史provider已可接入的声明。

补正复用`Acts.isCompetition`，在真正OPEN的offer阶段统一以“非比赛配置且campaign/endingUnlocked可用”控制原钥匙校验和追加，不改抽奖、奖励、hook或事务顺序。加强后的同一核心回归在旧代码真实RED（OPEN后`sapphireKey`断言），修复后检查无key item、无linkedSlot；直接sapphire选择和外来key token均拒绝，Run与Map完整前像不变。显式full-source相同普通宝箱仍产生合法关联钥匙，treasure/card RNG与遗物池消费状态逐项相同。正式OnStart的真实floor9宝箱OPEN后还检查整棵可见NodeUI无“钥匙”提示。原Boss终点、跨幕及回滚回归继续保留；历史证明与冻结hash无新增改动。

补正验证：新核心/正式入口/full-source场景、Sapphire21组与独立source向量批次14/14通过；新增RNG/池状态等值断言再跑核心7组通过；独立审查原probe显示OPEN后Sapphire项为0并通过。架构214模块/1239依赖边、固定Luacheck84条既有诊断/418治理测量及diff检查通过。未改变原历史hash，未执行平台或自然通关。
