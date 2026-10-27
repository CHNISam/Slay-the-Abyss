# Host、宝箱与遗物领奖回归收口

基线 `b6cc545`。本切片只修改测试和记录，不覆盖 GameUI/BattleUI/Run 的生产文件，不改超时、规则、池、断言门禁或原版哈希。

## 宝箱与原路线

远端 `game_ui.lua:181` 的失败来自旧测试把一次 Take 当作整个宝箱完成。现有生产入口已是明确 Open 后分别领取各 item，未实现的原版身份保留 unavailable。

保留原 15 个逻辑组、同一生成路线、全部真实出牌/敌方动作、Boss16、独立宝箱17、永久 UID、归属和原结局断言。只迁移宝箱操作：先证明未开、点击 Open、证明已开；按当前真实列表逐项领取可用奖励，每次断言 pending item 数确实下降；剩余全为不可用原身份才离开，且不能获得替代金币或遗物。没有重抽或移动路线，也未修改原有显式 4 HP 流程夹具；该夹具不是原版 A0 平衡通关证据。

`node --test tests/game-ui.test.mjs tests/potion-help-layout.test.mjs` 实际 7/7，通过原 GameUI 15、Deck 6、Prologue 10 组及其呈现/文案检查。原每个 Lua 文件的时限不变。

## 药水说明容器

原 `potionHelp` 8 个控件逐个精确保留检查，另验证新增的 `relicReward1/2`，总数 10。新增两行分别校验默认隐藏、原主题位置/尺寸、最小触控面积、完整四态、原生标签和行高；原药水说明的全部避边、不重叠和字号断言保留。

## 更新说明的真实生产缺陷

原 `game_ui_release_notes.lua` 前 6 组通过，第 7 组在 185 行失败：标题初始手柄焦点原应为 Start，新 speed 控件因同优先级且先注册而抢先获得焦点。原断言正确，未修改。

共享 GameUI 唯一写入负责人将 Start 注册置于 speed 之前。本树只临时 overlay 这两行顺序，原 `tests/release-notes-ui.test.mjs` 4/4，通过原全部 7 组、四份 readability 快照、完整 Unicode 分页和手柄 Cancel；`finally` 恢复本树完整生产源。该修复须由生产负责人一起集成，不能把旧基线当作已通过。

## 精英遗物领奖边界

新增 `tests/lua/elite_relic_reward_ui.lua` 6 组，实际 18.760 秒全部通过，沿用 30 秒 runner。测试明确把两件已实现遗物、金币、卡牌和药水 offer 作为 **staged 奖励边界输入**，不是自然精英胜利、掉落概率或完整章节验收。

覆盖公开 `Run.claimRelicReward` 和正式生成的两个奖励控件：

- 遗物、金币、卡牌 picker、药水独立领取，重复拒绝；原永久卡 UID 不变且新增 UID 合法。
- 无效索引、不可用身份、非 reward 阶段拒绝时，完整状态和所有既有 owner 引用不变。
- 获得遗物并执行挂钩后再拒绝/抛错，金币、遗物、cardRng、claimed 状态完整回滚，同一 offer 可重试。
- Proceed / Reopen 保持剩余奖励与战斗 owner；替换奖励 owner、原地改变 sourceId、模态、busy 和不可用行的旧触点不可领奖，新手势可正常领取。

新脚本由已有完整 Lua discovery 自动发现，没有添加调度器或重复全套检查。自然精英掉落、同候选原生导入/音画/键鼠实玩仍由原任务承接；本切片没有实机操作或发布。
