# 卡牌点击间歇失效排查

用户补充：不切窗也会出现，打开退出本局等面板后恢复。因此窗口失焦不是必要条件。

## 已证实的代码缺陷

真实 GameUI/BattleUI 处理器中，卡牌 Down 建立 `gesture`，未收到 Up/EndDrag 时，后续卡牌 Down 因已有 gesture 直接返回。即使同一鼠标下一次完整点击另一张牌也不能恢复。打开其他面板使 battleUI inactive，渲染清除旧 gesture，解释了该恢复路径。若旧 gesture 已移动，dragLayer 的透明 hit 还会拦截输入。

新增 `card_interrupted_recovery.lua` 在修复前失败于 `interrupted press permanently blocks fresh card click`；修复后通过。修复在新 Down 的归属边界终止同指针旧按压，清除对应 token；不同触点不抢占。旧拖拽层上的新按压只取消旧捕获，不重放到底层，避免误出牌或领取。没有模拟 Esc、重建界面或按帧刷新整个界面。

这证明丢失释放后的永久锁定是实际代码缺陷，但尚未取得用户故障当时的原生事件轨迹，不能声称已证明平台为何丢失释放，或已覆盖所有偶发失效原因。

## 验证

- 新增回归：中断后再点另一张牌、匿名鼠标、其他触点、迟到旧事件、拖拽遮挡层取消及不误触、战后奖励选择。
- 相关旧回归：拖牌边界 7 项、源输入行为 6 项、地图所有权 35 项通过。
- 完整 `npm run check` 未通过；Act2 意图、Act3 Maw/Growth 等 Lua 子进程超出原 30 秒预算。独立 Act2 意图仍超时，未延长预算、删测试或宣称通过；后续需核对当前 SHA CI。
- 商店、事件共用 NodeUI，地图/节点/菜单没有使用 BattleUI 的 gesture 锁；相关手势测试仍需与本轮平台观察分开报告。
- 实机尚未验证；由用户自行导入候选。任务保持 In Progress，PR 暂不宣称整体验收。

## 人工候选

`F:\New folder\.worktrees\ui-focus-return\.artifacts\task76-module\candidate.gil`

以用户前一轮收到的 PR290 候选为底，只替换 `abyss_battle_ui`；它是实验候选，不冒充当前 develop 全量重建。保留 patch.json 和独立 audit.json，正式存档未修改，live write=0。手工需覆盖战斗、战后选牌、地图、商店、事件和菜单，分别测试正常按压、界面边缘释放、切出切回，确认无需打开其他面板恢复且无误操作。
