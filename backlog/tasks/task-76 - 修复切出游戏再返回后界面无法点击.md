---
id: TASK-76
title: 排查手机战斗和奖励页面输入阻塞
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 09:38'
updated_date: '2026-10-29 01:12'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-76.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
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

2026-10-29 dot 隔离合流：在已验证 eb7d62e（074 + PR312）上逐职责移植 PR315 e80 的有限拖牌来源逻辑；保留 311 拆分、完整16模块逆向、303/313/318/319合同与六条未勾AC。先红后绿、原30秒及相关合同验证；不扩大匿名/原生修复，不操作客户端或发布。

PR315历史切片承接（原记录如下，不冒充本组合验证）：
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
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮隔离工作树 .worktrees/ui-focus-return，基线 origin/develop d2e0baa3。已读入口 abyss_ui、共享 GameUI、Controller、BattleUI、ChoiceUI、NodeUI 及平台官方客户端 API。入口仅启动/逐帧更新；官方生命周期未列窗口焦点回调，不能直接套用 Unity OnApplicationFocus。UI 根 showCursor/blockKeys/blockCursor 恒为 true。战斗 down 在 self.gesture 存在时不清 suppressClick；dragLayer 在 moving gesture 存在时启用 hit 并拦截穿透。因此丢失 Up/EndDrag 后残留手势/遮挡为待验证假设，尚无本轮实机证据，不能定为实际根因。选牌、地图、节点、菜单已有不同的手势所有权防护，不能粗暴清空所有输入或刷新整界面。已请求本轮10分钟键鼠窗口，未获确认，未发送输入。尚未修改生产代码、运行修复回归或创建PR。

用户补充：不切出也会突然无法选牌，点击退出本局等按钮后恢复；不再以窗口失焦为必要触发条件。继续离线排查丢失释放事件后 self.gesture 永久拒绝新 Down 的路径。

已用真实UI处理器红绿复现缺失Up导致卡牌永久锁定；最小修复18行及针对性回归已实现。候选只替换PR290底图的BattleUI模块，实机待用户自行验证。详细边界、测试与失败记录见附件。

2026-10-28队列复核（基线77c2d5e6）：中断按压修复已进入集成源码，但跨界面故障与同候选平台实测尚无完整验收；继续High/In Progress，原0/3验收保留。作为前两幕输入阻塞关联M4并列入排期，负责人统一Furinya，不把本地红绿或实验模块包当作用户故障已彻底解决。

2026-10-29 完整输入合同承接附件§2：真实拖牌及拖杀转奖励后，完整指针、混合Click动作和纯Click三种能力都能结束回合、领奖及跳过；迟到Click抑制只绑定原手势/有限消费，不泄漏后续动作，也不允许旧事件再次出牌。卡组关闭后战斗/奖励/地图首个合法操作可用，关闭不穿透、旧触点不复活；原生遮挡锁仍须真实命中控件与事件序列。奖励入口复现不能冒认录音Skip已复现；不每帧清标志或全局重建掩盖未知根因。

PR315历史切片承接（原记录如下，不冒充本组合验证）：
双Click真实处理器回归先红（第二次同touch7结束回合）后绿。有限latest-origin修正保留原卡牌/动作/药水/敌人释放令牌门禁、取消同触点屏障和busy/inactive保护，不改规则/地图/角色/CI预算。已明确三项能力边界：同latest ID且没有Down的合法Click-only动作仍无法与ghost区分而保守拒绝；匿名首个歧义Click吞后，第二次既可能是新重试也可能是重复ghost，接口无法区分；比latest更早的裸Click身份不留历史。需要本轮原生派发轨迹再决定平台修复是否足够，当前无键鼠窗口，不做原生闭环声明。

2026-10-28有限Click-only兼容切片最终本地验证：源码676abfb20f92539b4af8ed2692388d9d2fbb29176d1069931e3afb0926211cfa；新增真实场景15/15、聚焦Node2/2、串行相关Lua49/49（均保留30秒，最长25.092秒）、受影响历史Node27/27；check:engineering、syntax、backlog、network、Python65项全部通过。独立只读审查review_click_origin_contract通过该完整源码/15case及精确inverse。证据在工作区task76-click-origin-evidence/final-latest-origin；不是完整npm check、远端当前SHA Quality或原生验收。未推送/合并/写候选/占用键鼠；0/3与High/In Progress/Furinya保持，交根线程线性集成及后续平台闭环。

PR315接续批准稿PR313/cec690c1，保留瓶Click菜单+可见Use；组合复核新弹窗Use/Discard旧touch7穿透两组实证RED0/2→GREEN2/2，可选指针适配在原owner门禁之后、act之前执行，原控制器不变。最终BattleUI067b6761/Popupc530888e均精确恢复批准稿原文件；旧档案/golden与其余runtime/data/layout不改。最终聚焦Node2/2与Lua15/15（25.352s<原30s）；新适配相关5/5、历史12/12、syntax/231模块1297边架构/static60旧诊断零新增625职责测量/backlog/network通过；旧302 Full/审查和适配前12脚本仅历史。证据task76-click-origin-evidence/refresh-approved-ui-cec；无本轮完整check/engineering聚合、托管当前Full或原生验收，不推送待独立复核，High/In Progress/Furinya与0/3保持。

当前PR315/07e4b026 Full rules4真实失败已精确RED复现（case40/support1089，4.861s）：拖牌touch0但“尾随”click()无元数据，按已定协议合法打开详情，下一Down只是关闭详情。acceptedcec隔离对照PASS且当前逐状态证据确认无几何/生产回退。只修该fixture尾随事件为touch0，逐字保留原五条取消/HP/高亮/预览/目标提交断言并加强无状态变化检查；既有取消场景补真实匿名敌人详情→新Down关闭/Click吞掉→重试选牌。完整精确fixture逆向6adf9566→874ad3cf保留旧53case/6seed/档案/hash/预算；生产067b6761/c530888e不变。最终历史15/15（含全部七片53case/6seed）、聚焦Node2/2/Lua15/15 24.473s<30s；证据ci-rules4-fixture-identity。待新HEAD独立审查/完整Quality，不推送或写PR元数据；High/In Progress/Furinya与0/3保持。

2026-10-29 dot 只在独立本地树从 eb7d62e（074 + PR312）逐职责移植 e80fe357/a39aa7c9 的有限 latest-origin 逻辑，保留311拆分与原16模块/313冻结见证；原15场景实际基线2通过/13失败→本组合15/15（26.161秒，原30秒），原历史hash合同先红后绿。303单次回滚9组、318当前owner4组、313药水菜单/宿主/瓶体、纯Node逆向34项与原53case/6seed元数据2项通过；312全量质量收集251模块/3840测量、当前架构251/1395、静态37历史诊断零新增/792职责及语法/网络/Backlog通过。后续相关门禁与本地冻结结果见附件；无完整本地check或当前托管Full，无GIL/导入/ready/设备体验。匿名Click→详情→新Down吞序列的旧RED与same-ID/no-Down能力边界继续保留，不称全部手机故障已修。六条AC全部未勾，High/In Progress/Furinya保持。

本组合补充验证：批准UI/Node历史与复杂度负对照13/13、真实地图节点/药水头5/5、原case40与具名/匿名详情关闭重试2/2、原四项语义变异全部被对应断言捕获、原生能力mock2/2通过。旧匿名即时下一拖牌探针仍RED（2.715秒），未改契约或改称通过。严格16模块与popup/support/原15fixture来源守恒，全部其他生产输入/工具策略/预算不改；本地提交仅供父线程独立复审，不批准或发布。
<!-- SECTION:NOTES:END -->
