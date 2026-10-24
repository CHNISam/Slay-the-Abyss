# TASK-10.6 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
真实 GameUI 在 Weak=2147483647、Artifact=1 且敌人施加虚弱时刷新报状态溢出；同一状态的真实核心可正常消耗 Artifact。属于受支持数值边界的只读意图预览缺陷，不声称普通实机频发，也不接管平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Artifact 可抵消的负面状态在支持数值上界不使 GameUI 意图预览报错
- [ ] #2 预览按真实状态门控顺序处理，核心本局保持只读；无 Artifact 的真实非法溢出不被静默掩盖
- [ ] #3 保留正常意图、状态详情与卡牌预览行为，真实宿主红例转绿并独立回归通过
- [ ] #4 现有 PR/CI 流程验证，不更改游戏数值、批准布局、其他任务认领或平台验收状态
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定 GameUI 与 core 对照负例；核查当前核心门控接口，最小修正 UI 副本预览而不新增规则或吞异常；增加 Artifact/多效果/边界/只读回归；独立评审与当前 head CI。

独立探针发现演出中间帧会重复预演已执行意图；仍限定 battle_ui 只读层：使用真实核心门控在副本上计算，已行动敌人当前阶段保持其意图事件显示，未行动敌人动态刷新；阶段/actor/换局/中断恢复清理，真实宿主演出断言不得触发恢复。
<!-- SECTION:PLAN:END -->
