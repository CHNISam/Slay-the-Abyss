---
id: TASK-50
title: 战后选牌改为居中独立界面
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 07:42'
updated_date: '2026-10-24 08:30'
due_date: '2026-10-28'
labels:
  - ui
  - art
milestone: m-5
dependencies: []
references:
  - docs/evidence/reward-pick-ui/reward-pick-hover.png
  - docs/design/PLATFORM_PARITY.md
  - docs/DELIVERY-CLOSEOUT.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/169'
priority: high
type: enhancement
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战斗结束后的奖励选牌仍沿用底部手牌布局，容易和出牌混淆。改成参考原版《杀戮尖塔》的居中选牌：三张大牌横排、清晰标题、跳过按钮、悬停/入场反馈。不改卡牌数值、奖励生成和战斗逻辑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 战斗手牌仍在底部，战后奖励卡牌位于屏幕中心区域，一眼能和出牌状态区分
- [ ] #2 悬停放大不遮挡相邻卡牌，点击一次只领取一张，可正常跳过，选完后不残留界面
- [ ] #3 实机截图或录屏确认长说明卡牌完整可读（电脑鼠标和手机触屏各一次）
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
集成收尾：审查 feat/reward-card-pick-ui 与最新 develop 的兼容性；运行完整本地检查并核对 PR 当前 SHA 的全部 Quality 作业；通过后 squash 合并并清理分支。平台导入、电脑与手机实机及正式 UI 门禁仍按原验收项继续。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
【Claude 交接 · 分支 feat/reward-card-pick-ui，未开 PR，未合并】
改了什么：
- data/presentation/ui_theme.json 新增 layout.rewardPick（选牌台位置、卡牌间距 268、缩放 1.38、悬停 1.5/抬起 12、缓动、入场参数、跳过按钮位置），按 npm run build:theme 生成 abyss_theme。
- scripts/ui-layout.mjs：新增 rewardStage（框线面板 + 标题『选择一张卡牌』+ 副标题），跳过按钮改名『跳过』并移到选牌台下方。
- src/lua/abyss_battle_ui.lua：奖励阶段改用 placeReward 居中横排（不再走手牌弧线）；悬停放大并发光、其余牌不动；入场从 0.88 倍、下沉 28 上浮到位（OnUpdate 缓动）；选牌时隐藏战斗能量/牌堆；悬停监听并入已有 bindHelp（平台不允许同一事件重复监听）。点一下领取、跳过、领取校验、触点归属逻辑未改。
- tests/lua/battle_ui.lua：更新旧断言，新增 2 组（居中布局/悬停/一次领取、跳过不可重复）。
- docs/design/PLATFORM_PARITY.md 奖励/选牌行已补现状。
对照设计稿：docs/design/screens/pick.png（1.38/1.5 倍沿用；批准稿的『先选中再确认』未做，仍一击即领，保持原有误触防护与流程）。
验证层级：Lua 离线测试通过（npm run test:lua）；docs/evidence/reward-pick-ui/ 为按生成控件树渲染的离线预览（图标为占位方块，非平台截图）。**编译/导入/实机均未做。**
非战斗选牌核查：节点页的升级/移除选牌（pickerView）是独立居中网格，商店是货架，均不沿用手牌布局，无同类问题，未改动。
待接手：1) 后端/集成同学导入候选并实机截图（电脑鼠标+手机触屏），确认悬停监听、长说明、缩放后的点击热区；2) 视情况跑 npm run verify:ui；3) 平台不支持悬停的设备上只有点击，无放大预览（可接受降级，需实机确认）。

2026-10-24交付审计补齐承接：正式集成与平台验收负责人为@Codex，M4/10月28日。当前代码留在feat/reward-card-pick-ui工作树，尚未PR/合入，不覆盖独立改动；先审查并提交本任务既有代码，再按批准稿逐项导入新候选，电脑及手机实测长文、缩放热区、一次领取/跳过/清理及C档降级，保留SHA/hash/本轮截图日志并交TASK-4/5。离线预览不是实机；实现、集成、导入和实测分别记录。

2026-10-24 Codex 集成接手：用户明确要求合并 feat/reward-card-pick-ui。已核对实现提交 06b95ac，创建 PR169（https://github.com/CHNISam/Slay-the-Abyss/pull/169），与当前 develop 53a52bb 可无冲突合并。最终合并与当前 SHA 的 Quality 结果以该 PR 为准。本轮仅进行源码集成，不宣称编译候选、官方导入、电脑/手机实机或 UI 总门禁通过；任务保持 In Progress，原验收项继续保留。

最新状态：PR169已squash合入develop e3310bc，前文未开PR/未合入是历史交接。源码集成已完成；本任务仍由@Codex负责新候选官方导入及电脑/手机三项AC，交TASK-4/5。离线预览与源码CI不作为实机通过。
<!-- SECTION:NOTES:END -->
