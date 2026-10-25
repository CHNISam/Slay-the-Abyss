# 第四批规则的GameUI点击验证

`node scripts/test-lua.mjs tests/lua/game_ui_phase_four.lua`在根线程sts-flow最新runtime/theme基线上26组通过，耗时约20秒。真正交付仅该测试与本文档；源码、主题及build产物只是同步的测试基线，没有在本切片修改或交付。

这是离线GameUI控制器、真实Run/Combat与布局控件夹具的联合验证。职业按钮、战斗牌面、目标/出牌区域、选牌分页/确认、状态图标/详情、退出/取消均调用实际注册的点击处理器，规则结算与生成结果没有替换为mock。遭遇通过真实Run.startCombat启动；永久牌组和起始牌堆是明确控制的分支夹具，不是自然获取、自然抽牌或正式开局概率证据，也不是平台客户端实机证据。

## 当前Profile

逐职业验证实验Profile中的非状态、非诅咒、非特殊牌数量：战士66、静默61、故障机器人56、观者55，共238。辅助状态牌、奇迹、飞刃等不计入该数量。

## 四种检索选择

Headbutt、Hologram、Seek+、Exhume均通过实际牌面点击进入真实pendingPileChoice，各有14个候选，经过10张一页的真实分页控件选到第二页。测试检查候选卡中文说明与费用，跨页保留选择；Seek+还检查点击顺序保留为回手顺序。确认后按模式验证原UID进入抽牌堆顶/手牌，使用牌按实际规则进入弃牌/消耗堆，pendingPlay及队列清理完毕，反馈完成后选择层关闭、战斗重新激活。

退出按钮覆盖强制选择时，结束回合和打开牌组不能修改核心状态；点击取消退出会恢复同一个pending对象，视图选择清空而核心选择仍在。旧Run generation通过实际BattleUI→Run命令拒绝；另只改变独立Core generation，让真实核心返回stale_pile_choice_generation，确认失败后仍保留原选中UID与pending，修复该stamp后可在同一视图重试成功。没有替换perform/choose回调。

物理指针用例先选足Seek+两张牌，实际按下/抬起确认按钮，再翻页或打开并取消退出。延迟到达的旧touch确认必须拒绝；新的完整点击仍能提交。失败前后引用图检查覆盖核心所有已有表的引用与值，而非只比较JSON或牌堆长度。

## 新状态的实际显示

17个实际施加与点击详情用例覆盖：Evolve、Fire Breathing、Flame Barrier、Blur、Choke、Predator的下回合抽牌、Lock On、Battle Hymn、Collect、Fasting的能量降低、Like Water、Study、Talk to the Hand、Simmering Fury的愤怒标记与下回合抽牌、Vigor、Mark。

每例从真实职业界面开始，使用该职业合法源牌的固定牌组，经实际卡牌点击施加；目标由真实canPlay判断，玩家身上的状态也可能来自攻击牌，例如Predator仍要先选择敌人。测试不直接添加被测状态，不伪造生成的能力或结果。

随后实际点击玩家或敌方状态chip，检查：

- 核心statusView包含被测ID且数值正确。
- Theme中有显式正整数图标映射，状态chip及详情使用该ID，chip可见且计数准确。
- 详情中的中文名称、效果关键词、实际数值及持续阶段可见，不接受仅把裸数字作为时效的通用fallback。
- 下回合愤怒是内部presence标记，验证其真实愤怒语义，不要求把内部1写成伤害或抽牌数。
- 打开与关闭详情不会改变核心引用、数值、事件或牌堆。

初始旧基线在第10组Evolve实际打出后的反馈渲染中，因缺少status icon，在BattleUI.unit→picture→控件SetImage处明确失败。根线程补齐18项新状态图标与精确数值详情、重建theme后，完整26组通过。该真实红例日志保存在本次执行环境的`/tmp/game-ui-phase-four-first.log`，绿色复跑见`/tmp/game-ui-phase-four-current.log`；临时日志不是长期实机证据。

本文件未覆盖原30项Power全量回归、正式奖励获取、平台资产显示质量或客户端触摸验收；这些由各自验证任务负责。本轮独立发现的零球位影响nextEnergy类型选择问题已反馈根线程，未通过修改本测试或runtime来掩盖。
