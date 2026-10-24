# TASK-38.1 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
菜单与结算界面的开始、提交按钮直接执行Click，退出弹窗取消后旧触摸仍可重新开局或提交结算。仅保护这些宿主动作的触摸归属，不修改结算规则、按钮外观或平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 遮挡、退出取消、模式或本局切换、缩放后旧触摸不能重新开局或提交当前结算。
- [ ] #2 外来触点和重复回放不能执行动作；新有意触摸与仅Click宿主保持可用。
- [ ] #3 增加先红后绿真实控件回归并独立复审，保留结算单次请求规则；当前头CI与平台实测分开报告。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定95ce2bd复现开始和结算控件过期触摸。2. 最小绑定触点与当前本局/模式及界面代际。3. 回归结算和退出主流程，独立评审后提交正常PR。

4. 当前CI连续在既有UI套件超时，停止盲重试；先修正测试runner丢弃失败子进程输出的问题以取得定位证据，保持全部预算和失败语义。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定95ce2bd候选新增20组菜单/结果控件回归：基线19失败1通过，修复20/20；全量91个Native Lua套件通过。仅复用退出控件既有指针归属机制并加入菜单/本局代际，三个旧测试的重开准备改为完整Down-Up-Click而原有卡片/药水/结束回合断言不变。多数结果状态为显式隔离夹具直接设置phase，不冒充自然游戏流程；独立评审另核查公开动作到达失败结果的实际路径。未运行本地npm全检/安装或平台验收。

PR122初头空白门禁失败已删EOF额外空行修正。c72ac997正式CI先battle_ui 30秒超时，单次重试又在JS入口game_ui 15秒超时；未合并。独立核查Node test并发已经为1且runLua同步，不应再虚构并发过高原因。正在独立复审仅保留timeout stdout/stderr的诊断补丁，不增加门限、不删测试或把Native Lua当Fengari通过。
<!-- SECTION:NOTES:END -->
