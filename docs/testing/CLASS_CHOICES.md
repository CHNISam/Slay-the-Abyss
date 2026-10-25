# 战斗选牌控制器

本切片提供弃牌、占卜和手牌消耗／置顶的只读模态控制器。界面展示核心已经建立的选择，只在确认时调用宿主传入的规则命令，不计算伤害、不移动卡牌、不关闭规则选择。

## 接口

`ChoiceUI.new(root, presentation, clickEvent, platform, onConfirm)` 返回控制器：

- `refresh(run, enabled)`：跟随当前战斗的 `pendingDiscard`、`pendingScry` 或 `pendingHandChoice`；有效时显示。没有选择或 `enabled ~= true` 时隐藏，并清除界面的临时选择。
- `close()`：只隐藏界面，不取消或修改核心选择。重新显示时需要重新点选。
- `resize()`：使旧输入失效，保留本地选牌。
- `setPresentation(presentation)`：更换当前职业文案并使旧输入失效。
- `visible`、`generation`：供宿主判断遮挡和输入上下文。

确认回调为 `onConfirm(kind, orderedUids, token, combatGeneration)`；`kind` 为 `discard`、`scry` 或 `hand`。宿主应通过战斗演出命令入口调用相应的 `Run.chooseDiscard`、`Run.chooseScry` 或 `Run.chooseHand`，并返回原始 `ok, reason`。失败时保留同一选择的本地选中项，返回原拒绝原因；抛错时也保留原错误对象并显示中文失败提示。回调可以同步刷新同一选择，控制器不会在确认过程中误清空选中项。

若宿主在失败回调内调用 `refresh(run, false)`，它会按明确的隐藏语义清空本地选择；规则中的 pending 不变。失败后的正常刷新应使用 `refresh(run, true)`。成功后宿主可在演出期间隐藏，演出结束后再刷新。

## 控件约定

面板根节点包含 `blocker`、`title`、`hint`、`status`、`card1` 至 `card10`、`confirm`。每个卡牌与确认按钮包含 `hit`，其 `normal`、`hover`、`pressed`、`disabled` 四态都包含 `label`，可选 `border` 用于金色选中描边。每张候选显示对应卡牌名称、升级标记、核心提供的费用、类型和完整文案；动态数字由 `Combat.cardPreview` 和 `CardDisplay.format` 提供。

可选的 `before`、`after` 按钮用于十张以上候选分页，结构与确认按钮一致。候选超过十张而没有分页按钮时明确返回 `choice_page_controls_missing`，不会静默隐藏后续牌。当前已接卡牌的占卜最多五张、手牌最多十张。

弃牌必须选满核心指定数量；手牌消耗或置顶必须选一张；占卜可不弃牌，并按点击顺序提交弃牌 UID。必选流程没有伪造的“取消”。全局退出确认可以由宿主覆盖该面板，恢复后仍保留核心待选状态。

## 输入保护

确认前再次校验 Run、战斗、战斗代次、回合、pending 对象、选择 token、候选身份／升级／牌堆顺序。换场、重新显示、缩放、翻页和修改选中项都使旧输入失效。带指针的输入必须由同一触点完成 Down → Up → click，外来触点不能抢走已按下的按钮。观察过指针事件后，不允许退回裸 click。没有指针事件的宿主仍支持点击。

本地选择和翻页不写入规则。确认使用正在显示的身份快照；同步重入、旧 click 和重复确认不能提交第二次命令。

## 验证

命令：`node scripts/test-lua.mjs tests/lua/choice_ui.lua`。

`CHOICE_UI_PASS 19`：真实 Combat／Run 选择命令覆盖 Survivor、Prepared+、Third Eye+、True Grit+ 和 Warcry；另外覆盖零张占卜、顺序、升级显示、回调拒绝／错误、同选择同步刷新、触点所有权、换场／回合／代次／候选变化、隐藏／缩放、重复确认和分页。升级费用显示用隔离的卡目录值验证读取行为，不声称防御牌的原版费用为零。

### 实验 GameUI 闭环

追加命令：`node scripts/test-lua.mjs tests/lua/game_ui_class_choices.lua`。

`GAME_UI_CLASS_CHOICES_PASS 10` 使用真实实验 GameUI、BattleUI、`perform`、Run 和 Combat，不替换演出器或规则回调。六个牌例均从职业面板开始，点击真实战斗卡牌和出牌区域／敌人，建立规则选择；首段演出结束后出现选牌，点击确认后运行实际 `Run.choose*` 并完成后续演出。牌例为 Survivor、Prepared+、Cut Through Fate、Third Eye+、True Grit+、Warcry。

另外验证：

- 模态期间结束回合、出牌、牌库和药水入口均不能改变规则。
- 退出确认覆盖选牌，取消退出恢复同一个核心 pending；重置界面的本地选中项不取消必选流程。
- 故意使独立的 Scry serial 与 token 不符，由真实核心返回 `stale_scry_token`。演出命令的失败刷新保留选中 UID 和 pending，恢复 serial 后可真实重试。
- 修改选中项、打开／取消退出之后的旧物理确认失效；确认后演出期间的重复 click 和第二条选择命令不会再次提交。

测试把永久牌组设为指定牌的十二份副本以精确进入分支，这是界面单元入口，不是自然获取、来源概率、地图通关或构筑成型证据。没有改生命、能量或敌人数据。空选占卜若没有后续可视事件，其演出可能同步完成；验证演出期间的重复提交时选择一张牌以产生实际弃牌事件。

以上仍为控制器、规则命令和演出的离线验证。未导入平台候选、未做手机或电脑实机验收；原生布局、触摸派发和视觉审查仍需同候选平台证据。
