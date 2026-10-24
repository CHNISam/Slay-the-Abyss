---
id: TASK-4
title: M4 批准稿UI打磨、战斗反馈与多设备验收
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-24 02:02'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies:
  - TASK-29
  - TASK-29.1
  - TASK-30
  - TASK-34
  - TASK-25
  - TASK-38
  - TASK-42
  - TASK-36.1
  - TASK-38.1
  - TASK-4.1
  - TASK-2.1
  - TASK-10.1.2
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-10-23决定：首发纳入内容严格对齐初代Slay the Spire PC正式版Ascension 0数值/机制/算法/概率/结算顺序，仅名称/背景/元素表现可包装，禁止自创或凭感觉调平衡。主冲刺按最早未完成成果关口推进，离线工作可并行。PR #51已合并，现有实现以最新develop与专项证据为准。10/30内部准备、11/02比赛截止不变。 M4只精修表现/体验，承接TASK-29基础队列及TASK-30拖放，不重做M1。参考原版出牌、命中、受击、伤害数字、音效、动画停顿与反馈节奏，在千星独立实现，禁止搬运第三方受保护代码/素材/声音/逐帧动画。维持PR19视觉基线，表现不改规则/RNG/结算。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 打击/受击/格挡/状态生效均有特效与音效反馈
- [ ] #2 editor_preview_interface 手机与主机画布 UI 不出屏
- [ ] #3 战斗界面信息可读：血量、格挡、能量、敌人意图
- [ ] #4 承接TASK-10手机安全区与TASK-24前端/主题统一：按PR19逐页核对实际战斗/地图/七节点/结算，正常、禁用、结果状态齐全，差异留截图与降级理由
- [ ] #5 按原版PC观察逐动作记录操作确认→释放→命中→伤害数字/受击→死亡/回合收尾的时序、停顿/音效/节奏参照，标录像时间点/条件；未经测量的时长标待核实，不捏造原作精确值。
- [ ] #6 独立表现覆盖攻击/格挡/自损/群攻/多段/持续伤害/反伤/死亡，声音实际听验；同候选鼠标/触摸/主机与性能反馈有录像和结果，平台限制单列，不修改核心规则结果及随机流。
- [ ] #7 数据完成、独立原版预期自动测试、平台编译/副本导出、官方导入和千星实机分层报告，附SHA/hash/种子/日志和截图录像，不能互相替代。
- [ ] #8 按批准稿和ui-acceptance.json逐屏实机核对并运行npm run verify:ui -- <同一候选.gil>；战斗动画、打击/受击/状态、敌人死亡音效、BGM、UI与手机/电脑交互达到用户批准标准。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
卡组查看切片：按 PR19 openDeck 提取主题布局；使用有文档的 grid + 卡牌模板与 RefreshItems；在 GameUI 跨地图/战斗/节点接入口并屏蔽底层命令，取消现有拖牌；用真实控件夹具验证滚动刷新、UID/升级文案、状态和随机数不变及输入恢复；离线生成并编译副本，交主线程复审。

整合 PR #75、#77、#79：保留 develop 的卡组查看和叙事接入，逐项解决界面与测试冲突；运行完整 npm run check，核对各 PR 当前 SHA 双 CI 成功后按 squash 合入 develop。实机验收状态保持原记录。

节点按钮 P2 切片（feat/task4-node-button-states，ed39f46）：保留 nodeLayout 全部既有 GetChild 路径与 C 点选，用官方 CursorEnter/Exit/Down/Up/EndDrag 与 SetLocalScale 实现 hover/pressed/0.96 整体按压；增加主题 hover/pressed token 和视觉层，不改规则/RNG。真实原生树控件夹具覆盖悬停→按下→抬起/离开、禁用与已选结果、隐藏/切页/交易重绘复位、触点隔离和事件仅绑定一次；跑节点与宿主针对性测试。平台真实编译/副本/设备实机留主线程集成验证，不勾平台 AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
未来M4打磨集中在本任务；M1必要文字/点击由TASK-3保留，不把基础可玩后移。承接TASK-24原AC2-4，有限范围为首发八类页面，不要求持续无限优化。

TASK-29已在M1立即实现事件队列与原生UI基础反馈，验收衔接TASK-3.2/TASK-3。本任务M4继续承接正式岩元素技能粒子、角色动作/命中/死亡精修、正式音效与节奏、多设备预览和性能体验；不重复实现基础队列。详见docs/COMBAT_FEEDBACK.md。

2026-10-23 /root/deck_view 在 feat/task4-deck-view 离线推进批准稿卡组查看（六列滚动网格、只读永久卡组、输入隔离）；不启动原神，设备预览与音效/实机 AC 保持未验收。

卡组查看已实现：原生六列 grid + 只读卡牌模板、永久卡组 UID/升级/X费用/真实文案、单项回调校准索引、重复开关和过期回调隔离、地图/战斗/节点入口。真实控件夹具验证底层出牌/结束回合/药水/奖励/营地命令均被拦截，关闭后恢复。完整 npm run check 一轮通过，补充永久与临时成长区别/奖励防穿透的针对性回归通过。原神未启动。离线副本编译发现 MCP colour 仅接受 RGB，遮罩现拆为主题 RGB + opacity，继续复验。

最终离线验证：npm run check exit 0；JS 214 项（200 pass/14 环境 symlink 权限 skip），全部 Lua 套件通过（GameUI 16 项），Python 16 项（1 symlink 权限 skip）。固定 source-base SHA256 6e82decf...a432 从零构建成功；完整候选上 replace UI/模板读回，控件 ID/模板索引/22节点结算图/信号/实体挂载相等。scene_check_client 0 errors/15 跨模块 UNKNOWN_METHOD warnings，无 signal 未监听警告。最终候选 SHA256 512959f6...f680，证据 docs/testing/task4-deck-offline.md。早期派生 original.gil 调查不作验收证据。未开原神、未导入、未预览、未试玩，不勾 TASK-4 实机 AC；交主线程复审。

2026-10-23 feat/node-ui-polish（PR 见分支）：节点四屏按 PR19 批准稿原生重构——商店单屏货架（5 卡面+价格、删牌服务格先选后确认、遗物行、红价/灰牌/售罄）、营地休息/锻造双选项与升级前后真实卡面对比、净化神龛/圣职者左右结构与灰态原因及结果页、宝箱开合与奖励行；营地/事件结果停留至「继续」。只读 Nodes.view、只发既有命令，未改规则/RNG/定价（未用 PR #64 候选），未实现第17层Boss宝箱。验证：npm run check 全绿（节点 Lua 18 项、宿主全流程、布局 6 项）；离线对照截图 docs/design/node-preview/。平台实机：未测，验收保持 pending。

本批代码已合develop fac093c（药水PR78），实际离线构建源022f22cf；git diff确认src/data/scripts与合入代码完全一致。完整check及各PR当前SHA Quality全绿，实际gil独立核实24模块源文、1220控件/六列模板/22节点启用结算图，客户端静态0error/15条已定位自定义方法warning；内存重注入与候选字节相同。候选SHA256 a6d839d45753af0e536142bba7a3cd2322155dda38a67cbcc220bce7b6c8e114，正式底图hash前后相同且liveWrite=0。证据docs/evidence/offline-candidate-022f22c.json及P0-SMOKE。未开原神、未官方导入/实机，所有剩余平台/全项AC保留原状态。

新版节点/菜单/结果与反馈的真实平台副本：源7013641，首次a76导出17个RGBA colour被拒，nativeControls.plate统一RGB+独立opacity后全check JS297pass/14skip、全部Lua、Python15pass/1skip；真实MCP从零导出0error/16自定义方法warning。独立actualgil核24模块逐字、1552控件/max50、六列模板/graph22启用挂载、17个veil为RGB+0.8，内存重注入字节一致，原底图hash不变。副本60ca982ef78f3e095b1c572f2f414bc5e32e8cd0a26e10eea8a323d328c43517，docs/evidence/offline-candidate-7013641.json。未原神/导入/实机；节点hover/pressed/0.96按压仍P2缺口，不声称完整视觉通过。

节点按钮 P2 切片 feat/task4-node-button-states（ed39f46）完成离线实现：保留全部直属 GetChild/hit 路径和 C 点选，通过官方 CursorEnter/Exit/Down/Up/EndDrag + SetLocalScale 增加 hover/pressed/0.96 整体按压，主题读取颜色/缩放。禁用与已选结果优先，拖出/EndDrag/异触点、重绘/切页/关闭重开均复位，表现回调不发命令且监听只绑定一次。红测基线缺 enter 监听；实现后节点 Lua 25 项、针对性 JS/主题/宿主 20 项通过，节点每容器≤50。证据 docs/testing/task4-node-button-states.md。本切片真实MCP编译/副本/设备实机未做，交主线程最终集成验证；未开原神，不勾平台AC。

节点按钮hover/pressed/0.96源码切片已在PR91全绿合入；默认点击路径、禁用/选中优先及取消复位保留。最终组合ec455f6完整check退出0(JS469pass115权限skip/Lua全套/Python15pass1skip)，真实MCP副本26模块/1590控件/max50/38按钮状态层/六列模板/22节点图，0error17warning（16自定义方法+未接线unknown）。副本hash a4f90ebb7230201989e89fbb270a98ec601c8f05861fd078bf81617453ffb9bc；正式底图hash不变。设备、颜色/缩放/失焦事件和导入/实机AC未勾，见P0-SMOKE及offline-candidate-ec455f6.json。

宿主UI默认15秒预算的测试整理：原20组按14+6拆分，202块内+9helper断言逐字保留，独立两脚本4.656/1.913s及Node双入口/LORE6.107s通过，默认timeout不变。同步PR93新增跨战斗首次点牌回归后实际15+6共21组，旧20块迁移审计保留，新回归不丢。运行时代码按最新develop保留，候选ec455f6早于PR93不可冒充该点牌修复平台验收。

已从085f499实际重建含PR93首次点牌修复的副本：26模块/0error17warning、UI1590/max50/38状态层、六列牌库与22节点图，正式底图hash不变。副本b22a876a752d923fa3211dedbeceace74548dfb0ba3acc98590b8243c937b95a，P0-SMOKE/结构化证据已分开历史全检和当前21组定向验证，最终head完整CI仍待绿；未官方导入/实机，不勾设备或完整视觉AC。

2026-10-23 feat/ui-legibility-map-combat 合并复核：同步 develop cf5f030，保留蓝色格挡数字芯片与节点横向分页；合入既有 PR118 的节点卡片触点归属修复，防止退出/取消后误购。新增地图拖动回归先复现 overlay 后旧拖动仍滚动，现于隐藏/缩放/地图替换取消旧拖动，第二触点不能抢占；地图 Lua 18/18 通过。完整 check 与当前 head Quality 待最终核对；未构建本分支新 gil、未导入或实机，不勾 UI/设备 AC。
<!-- SECTION:NOTES:END -->
