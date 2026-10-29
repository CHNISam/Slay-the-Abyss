---
id: TASK-76
title: 排查手机战斗和奖励页面输入阻塞
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 09:38'
updated_date: '2026-10-29 01:51'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-76.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
priority: high
type: bug
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
问题由手机实玩发现：拖牌后奖励或动作可能不能点击，关卡组后也曾无法操作。离线诊断复现混合Click抑制；卡组关闭后原生输入锁根因未确认。PC是否受影响待分别验证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 根因定位并最小修复
- [ ] #2 跨界面切回正常交互且不误触
- [ ] #3 回归通过并经PR合入develop
- [ ] #4 真实拖牌后奖励、结束回合及纯点击入口继续可用，无需退出确认恢复。
- [ ] #5 卡组关闭后战斗、奖励和地图首个合法操作正常，手机留证。
- [ ] #6 分别记录手机触屏和PC鼠标的复现或未复现条件；不能以离线模拟代替真实设备。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
追踪平台焦点与手势；最小实验验证；修复与回归；实机与PR集成。

新增丢失释放后再次点卡的真实处理器回归，并核对同指针恢复、多指归属与迟到事件不误出牌。

2026-10-28混合Click按钮切片（develop 1f260a71972b03dae5b63e8d6f12d055973a4c83）：
1. 先用真实防御拖出→结束回合、Bludgeon拖杀→奖励入口重现红灯，保留原始诊断及边界。
2. 沿用现有cardInputs单次释放令牌，将移动拖牌的抑制归属到原gesture；仅在该手势终止且原控件令牌已消费的边界退役，不清理其他取消抑制。迟到/重复/旧手势及多指不得借用新权限。
3. 新增聚焦真实Click-only动作/奖励回归；执行既有卡牌、动作、药水、详情、输入中断与冻结RaidenV4界面相关回归，保留原case/seed/hash与30秒预算；历史源身份只作精确逆向绑定。
4. 仅本地干净提交交接；PR311为BattleUI职责拆分，当前91904592与本切片同文件重叠，需根线程按行为切片先行/重放后严格复验，不复制或合入未通过功能。全TASK-76与原平台验收继续High/In Progress/Furinya，0/3不勾选。

边界复核调整：既有drag_input_boundaries明确要求同触点的跨控件尾随Click不能结束回合，首版在终止时直接退役标记未满足，未作为交付。改为完成拖牌保留原gesture标记；仅经过现有控件所有权门禁后的Click消费一次该标记，匹配原触点的尾随Click被吞掉，其他独立Click可继续。无touchId且没有Down的同ID重用无法区分新按压与尾随Click，保守消费首个歧义Click，后续明确重试可用；不添加计时器/逐帧清理，也不放宽原卡牌、动作、敌人或药水令牌门禁。布尔取消屏障与活跃gesture不在该消费范围。

真实双Click回归已证实：具名触点首个尾随Click清标记后，第二个Click可穿透Click-only动作。修正为完成拖牌保留触点墓碑，直到该触点新的有效Down；独立匿名Click可退役全局标记但不能使旧触点复活，匿名拖牌仍保守吞首个歧义Click后允许明确重试。补重复、取消、跨奖励动作回归；不增加计时器或放宽令牌门禁。

最终选用固定单个latest完成拖牌触点，不建历史集合或饱和锁：独立匿名/不同具名Click可退役全局抑制，latest具名触点重复Click仍被拒绝，其真实新Down恢复；下一次完成拖牌替换latest。官方事件无nonce，无法区分同ID的新Click-only动作与尾随旧Click；此有限安全边界不作为原生兼容或任务整体通过。

2026-10-28 PR315接续已合入PR313（cec690c1）：保留批准稿UI和药水瓶Click打开菜单/可见Use使用；只合成latest-origin屏障。精确TASK76逆向置于批准UI/PostNode完整身份检查之前，旧档案与golden不改；迁移药水两组断言并执行新基线相关回归/静态，旧302 Full绿灯仅作历史，不推送待独立复核。

PR315当前07e4b026托管rules4实证定位：case40拖牌touch0却用无元数据Click模拟尾随事件，实际合法打开详情，后续Down只关闭详情。先保留原RED与acceptedcec对照，再只修该fixture尾随事件身份为touch0，保留全部原断言并补独立匿名敌人Click检查；以完整精确fixture逆向保全53case旧整体hash，不改生产源码/预算，待新SHA独立复核。

PR315 hosted rules2 的新增15场景夹具于原30000ms超时（非断言失败）。仅按PR319已有registrar模式拆成连续1–7与8–15两组；逐字逆向校验原场景/断言/顺序，保留每子进程30000ms、raw及Node发现与独占调度；生产和历史inverse不改。完成本地精确校验后交根线程审查，暂不推送。

2026-10-29接续已合入PR311/develop 8a36c0d5：保留15职责模块与PR312质量配置，将已审latest完成拖牌origin逻辑最小重放到真实输入/手势/绑定owner和弹窗适配；保留原15输入用例两片、touch0夹具修正、原全部冻结来源和时限，先保留基线失败，再串行验证实际模块、22场景差分和精确逆向。仅本地干净提交交根线程独立审查，不推送；High/In Progress/Furinya、m-4与六项未勾选验收保持。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮隔离工作树 .worktrees/ui-focus-return，基线 origin/develop d2e0baa3。已读入口 abyss_ui、共享 GameUI、Controller、BattleUI、ChoiceUI、NodeUI 及平台官方客户端 API。入口仅启动/逐帧更新；官方生命周期未列窗口焦点回调，不能直接套用 Unity OnApplicationFocus。UI 根 showCursor/blockKeys/blockCursor 恒为 true。战斗 down 在 self.gesture 存在时不清 suppressClick；dragLayer 在 moving gesture 存在时启用 hit 并拦截穿透。因此丢失 Up/EndDrag 后残留手势/遮挡为待验证假设，尚无本轮实机证据，不能定为实际根因。选牌、地图、节点、菜单已有不同的手势所有权防护，不能粗暴清空所有输入或刷新整界面。已请求本轮10分钟键鼠窗口，未获确认，未发送输入。尚未修改生产代码、运行修复回归或创建PR。

用户补充：不切出也会突然无法选牌，点击退出本局等按钮后恢复；不再以窗口失焦为必要触发条件。继续离线排查丢失释放事件后 self.gesture 永久拒绝新 Down 的路径。

已用真实UI处理器红绿复现缺失Up导致卡牌永久锁定；最小修复18行及针对性回归已实现。候选只替换PR290底图的BattleUI模块，实机待用户自行验证。详细边界、测试与失败记录见附件。

2026-10-28队列复核（基线77c2d5e6）：中断按压修复已进入集成源码，但跨界面故障与同候选平台实测尚无完整验收；继续High/In Progress，原0/3验收保留。作为前两幕输入阻塞关联M4并列入排期，负责人统一Furinya，不把本地红绿或实验模块包当作用户故障已彻底解决。

双Click真实处理器回归先红（第二次同touch7结束回合）后绿。有限latest-origin修正保留原卡牌/动作/药水/敌人释放令牌门禁、取消同触点屏障和busy/inactive保护，不改规则/地图/角色/CI预算。已明确三项能力边界：同latest ID且没有Down的合法Click-only动作仍无法与ghost区分而保守拒绝；匿名首个歧义Click吞后，第二次既可能是新重试也可能是重复ghost，接口无法区分；比latest更早的裸Click身份不留历史。需要本轮原生派发轨迹再决定平台修复是否足够，当前无键鼠窗口，不做原生闭环声明。

2026-10-28有限Click-only兼容切片最终本地验证：源码676abfb20f92539b4af8ed2692388d9d2fbb29176d1069931e3afb0926211cfa；新增真实场景15/15、聚焦Node2/2、串行相关Lua49/49（均保留30秒，最长25.092秒）、受影响历史Node27/27；check:engineering、syntax、backlog、network、Python65项全部通过。独立只读审查review_click_origin_contract通过该完整源码/15case及精确inverse。证据在工作区task76-click-origin-evidence/final-latest-origin；不是完整npm check、远端当前SHA Quality或原生验收。未推送/合并/写候选/占用键鼠；0/3与High/In Progress/Furinya保持，交根线程线性集成及后续平台闭环。

PR315接续批准稿PR313/cec690c1，保留瓶Click菜单+可见Use；组合复核新弹窗Use/Discard旧touch7穿透两组实证RED0/2→GREEN2/2，可选指针适配在原owner门禁之后、act之前执行，原控制器不变。最终BattleUI067b6761/Popupc530888e均精确恢复批准稿原文件；旧档案/golden与其余runtime/data/layout不改。最终聚焦Node2/2与Lua15/15（25.352s<原30s）；新适配相关5/5、历史12/12、syntax/231模块1297边架构/static60旧诊断零新增625职责测量/backlog/network通过；旧302 Full/审查和适配前12脚本仅历史。证据task76-click-origin-evidence/refresh-approved-ui-cec；无本轮完整check/engineering聚合、托管当前Full或原生验收，不推送待独立复核，High/In Progress/Furinya与0/3保持。

当前PR315/07e4b026 Full rules4真实失败已精确RED复现（case40/support1089，4.861s）：拖牌touch0但“尾随”click()无元数据，按已定协议合法打开详情，下一Down只是关闭详情。acceptedcec隔离对照PASS且当前逐状态证据确认无几何/生产回退。只修该fixture尾随事件为touch0，逐字保留原五条取消/HP/高亮/预览/目标提交断言并加强无状态变化检查；既有取消场景补真实匿名敌人详情→新Down关闭/Click吞掉→重试选牌。完整精确fixture逆向6adf9566→874ad3cf保留旧53case/6seed/档案/hash/预算；生产067b6761/c530888e不变。最终历史15/15（含全部七片53case/6seed）、聚焦Node2/2/Lua15/15 24.473s<30s；证据ci-rules4-fixture-identity。待新HEAD独立审查/完整Quality，不推送或写PR元数据；High/In Progress/Furinya与0/3保持。

PR315/e80fe357 托管run40796443606 rules2 于30000ms超时，14场景已过、Raiden E末场未完成；原日志与旧源码/预算证据保留在task76-click-origin-evidence/ci-rules2-bounded-20261029。仅registrar拆成1–7与8–15，原始夹具完整逆向SHA256仍5068b6d6/git blob b3af0786；当前串行真实输入7/7=12.001s、8/8=14.367s，每子进程仍30000ms。13项原源码/执行/发现/调度/冻结inverse门禁、syntax与backlog通过；生产067b6761/c530888e及历史源/runner不变。一次干净rebase至6d7a2121，原PR315聚合patch逐字保留。尚无本轮完整Quality/原生手机或PC验收，不推送待根线程审查；High/In Progress/Furinya、m-4及六项未勾选验收保持。

PR315接续已合入PR311/8a36c0d5的离线模块化重放：仅七份既有Battle运行时文件改动，latest origin由真实input/gesture owner持有，保持已审popup c530888e、控制器、渲染/布局/数据与旧assertion。原15输入两片通过11.826s/11.761s<各原30s；聚焦源/22场景差分21/21、accepted popup/controller/owner Lua17/17、原七片53case/6seed和历史写入合同19/19、质量/调度合同35/35通过。新增六文件精确逆向和全部16模块缺失/漂移/跨路径负例通过，旧067/c530/touch0三份逆向逐字恢复；quality 246模块3754/3754测量、architecture、static零新增诊断（37项既有）、syntax/backlog/network通过。证据port-accepted311-8a36c0d5；保留全部失败调用。当前目标又推进至已接受Nodes/Run 58f72c2c，先提交本切片检查点再仅一次rebase，逐字保留运行时与夹具并复验最新源合同；未推送、无完整当前托管Quality或原生手机/PC验证，High/In Progress/Furinya、m-4及六项未勾选验收保持。

一次rebase已完成至58f72c2cc43a2833e9e1cdefe7c332ff0fd49243（接受Nodes/Run）；仅approved-node-ui-refactor的两项inverse同位置冲突，保留原core调用再接TASK76。七份Battle runtime、两片原15case、touch0夹具、worker/registrar来源与2460b2ab检查点逐字一致，runtime patch亦逐字一致；不重复重型Lua。最新基线源/缺失/未知/跨路径/部分hunk/调度合同54/54、quality255模块3884/3884测量（新增数值仍report-only）、architecture/static938职责测量及37既有诊断零新增、syntax/backlog/network通过；全部新Run/Nodes runtime及config/data/launch/core inverse不改。证据port-accepted308-58f72c2c；本轮只是本地干净重放，不是完整托管Quality、独立审查或原生手机/PC验收。未推送、未改PR元数据；High/In Progress/Furinya、m-4与六项未勾选验收保持，交根线程对最终HEAD另行独立审查。
<!-- SECTION:NOTES:END -->
