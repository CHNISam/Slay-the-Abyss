# TASK-40 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-26 用户将手柄支持提高优先级，确认方案1：优先复用平台原生导航，覆盖战斗、地图和各类房间；随后明确要求核对初代《杀戮尖塔》反编译实现并移植可用部分。没有设备不再阻止开发和离线验证，真实设备完整游玩仍单独验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 确认平台手柄输入能力并记录按钮映射、焦点导航及按键提示规范
- [ ] #2 手柄可完成战斗出牌、目标切换、确认取消与结束回合，以及地图和各节点主流程，无焦点陷阱
- [ ] #3 在实际手柄设备上记录完整游玩验证结果；无设备时明确标记未验证，不宣称已支持
<!-- AC:END -->

## 本轮实现

`abyss_controller` 接入官方 Focus、Confirm、Cancel 事件与焦点 API。当前页面控制可选项；弹窗启用隔离并暂时关闭背景控件的可选状态；隐藏、禁用和已售出项目不能保留焦点。取消瞄准回到原手牌；同一更新中的重复确认及其伴随 CursorClick 不会重复提交。

战斗选牌后进入选敌或明确的无目标确认区域；药水同样先瞄准再提交，取消不耗瓶。结束回合、奖励领取/选牌、地图可达节点、商店购买/删牌、营地升级/休息、事件、宝箱、卡组、药水管理、退出确认均绑定既有命令。四职业选择与战斗选牌弹窗也接入导航；强制选牌不能直接取消。

牌库在手柄输入下按两行分页，保留原有六列卡面。上一页、下一页和页码提示使用共享主题；键鼠/触屏继续使用原生滚动。分页和设备切换更新回收控件的代次，旧页面回调不能覆盖新页。新增按钮的设备安全区、控件容量与视窗无重叠检查已通过。战斗瞄准、地图及序章采用“确认／返回”语义提示，具体物理键由平台配置决定。

## 原版来源与移植对应

固定社区反编译镜像：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。本轮读取以下文件并核对内容 hash；镜像不是官方开放源码，未用正版 PC 二进制认证其版本。这里交付的是选择/取消算法及交互规则的 Lua 适配，原版的 LibGDX 光标和设备调用由平台 API 承接。

| 原版文件/方法 | 当前迁移 | 原文 SHA256 |
| --- | --- | --- |
| [CardRewardScreen.updateControllerInput](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/CardRewardScreen.java) | 默认首张、左右越界回绕；当前有效牌列表映射到原生导航目标 | `6883c6684c11f15b6e3a10466813b01354b05a41d33379e6a084da3ada429aae` |
| [AbstractPlayer.updateSingleTargetInput / releaseCard](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | 选牌与提交分开、选敌阶段、取消清理与返回手牌；焦点改变刷新目标预览 | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [MapRoomNode.update](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/map/MapRoomNode.java) | 地图当前页面中确认节点；可达性仍由本项目 Map/Nodes 核心校验 | `58d8b19c4d8154de5743df4a359eacdda49b5e46f628c9af7ab0915001bf94f7` |
| [CInputHelper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/controller/CInputHelper.java) | 设备及光标层不适配 Lua；使用原生 SetControllerFocus/SetControllerNavigation | `2ab56f540bf422fd8654a7623d4fe31a8d43565d5a8e2b71eedf634825664292` |

原始读取副本在根 `.artifacts/controller-source-319009d/`，不随功能分发。没有导入第三方 Java 包或其依赖；不将社区镜像描述成拥有可分发原作源码的开源许可。平台调用依据官方[客户端 API](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhtakr07vej4)、[客户端脚本指南](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhbgxf0nynww)和[手柄适配课程](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhjobxrdykym)，本机工具已有的 `focusable/navigation` 配置及 `examples/clientvars` 用于核对存档表达。

## 验证与边界

- `tests/lua/controller.lua`：默认焦点、循环导航、同帧去重、弹窗隔离、恢复、隐藏/禁用、设备切换和停用。
- `tests/lua/controller_host.lua`：真实 GameUI/Run 的菜单、地图进入战斗、先有指针再用手柄、目标牌取消/出牌、无目标牌、牌库/退出弹窗、结束回合、药水取消/使用、奖励选牌、序章跳过及强制多选的返回/确认。
- `tests/lua/controller_rooms.lua`：真实商店购买和移除、已售项目、营地选牌取消和休息、事件离开、宝箱返回、药水管理、超过两行的牌库分页、末页回收及延迟回调隔离。
- `tests/deck-ui-layout.test.mjs`：弹窗导航隔离、所有设备安全区、分页不遮挡牌库；既有牌库与退出布局回归保持通过。

以上为离线测试与原生配置证据。尚未构建新的 `.gil`、官方导入、实际手柄游玩或按键图标/摇杆手感/物理主机及移动手柄画布验收。TASK-40 的真实手柄验收保持未勾选，不能据此宣传完整支持；UI实机门禁状态不变。本轮未占用鼠标键盘。

## 2026-10-27 当前源码整合

按既有 PR229 的精确源码逐项迁移，不以旧分支整文件覆盖当前实现。保留当前无预览 Run/Map 的标题启动、卡牌 UID 与持续选敌、右键取消、动态敌人显示槽与核心索引、共享卡面和原生导出默认配置；NodeUI 的事件、钥匙选择与 BackToBasics 行为不回退。章节地图先保留现有标题和空绑定构造，再叠加章节签名/版本安全检查；旧地图焦点不能跨未确认的上下文提交。

`controller_current.lua` 补充持牌切换到手柄返回、延迟指针事件、右键取消、动态敌人槽位和旧地图焦点回归。初轮当前组合的28个离线检查阶段通过，包括现有卡牌/药水/选牌/节点所有权、BackToBasics、章节地图与四项关键语义变异；没有将这些结果写成平台手柄验收。

历史 PR229 的 `phase_four_presentation.lua` 原文件实际执行21项（17个单独调用加4职业循环），不是26项；当前已有的17项语义与4项渲染拆分均原样保留，每份仍用30秒预算，602个基础/升级卡面变体不减少。另用未修改的历史原文件做诊断：加入导航字段的替身初版超时30.037秒；未加手柄整合的当前父版通过27.682秒。将新增的三个导航替身方法放到共享原型、避免复制到每个控件后，历史21项和602变体在28.004秒通过；未改断言、测试选择、超时或生产玩法源码。上述耗时只是本次离线进程记录，不代表真实设备性能保证。

本轮没有远端发布、分支/标签删除、官方导入、实际手柄输入或实机画面验收。最终发布仍须检查新HEAD的完整Quality；真实手柄验收和UI实机关口保持未验证。

## 立项时范围（历史保留）

以下为当前父版附件保留的原始立项记录；后续用户批准离线开发的变更与本轮验证见上文，不据此删除原验收边界。

> 用户希望后续支持手柄，但目前本人没有手柄，无法实机测试。先纳入Backlog，暂不安排实现或作为本次发布承诺；手机与电脑键鼠优先。启动本任务前需落实可用手柄或测试人员，并确认平台输入能力。
