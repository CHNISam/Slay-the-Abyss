---
id: TASK-59.3
title: 让比赛版正确选择已验收角色
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 06:32'
updated_date: '2026-10-29 03:23'
labels:
  - required implementation-gap
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-59.3.md
parent_task_id: TASK-59
priority: medium
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已有八种角色选角实现保留供显式full-source开发测试；本次比赛正式入口只开放岩系旅行者，雷电将军留到下一版本。历史八形态离线证据不替代本轮单角色候选或设备验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 正式原生入口统一显示五名角色及旅行者四元素，选择时只更新详情与单选高亮，确认后仅创建一次正确的Run。
- [x] #2 返回、取消、重开、鼠标触摸与手柄输入隔离通过离线回归；默认不播放旧序章，Neow、地图及战斗兼容。
- [ ] #3 原生构建与现有必要门禁通过，最新develop同步后提交并合入PR；实机和设备未验收范围如实记录。
- [ ] #4 正式比赛版只显示岩系旅行者，其余七种角色及其公开配置入口不可进入；显式full-source开发配置保留八种角色，雷电留到下一版本。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对319009d5七份原版源码及现有数据；复用职业适配构建只读选角信息和正式原生选择页；拆分选择/元素/确认并保留输入代次；补八形态和旧序章退役回归；同步PR267后跑门禁、构建、PR合入及清理。

本轮接手PR290：从80874f8核对后续4aba86bc，复验冻结来源逆变换与真实OnStart；同步最新develop，逐项修复Windows/POSIX失败且保留原断言/视觉；完成定向回归、完整Quality和离线原生构建，核对合并窗口后squash及清理。官方导入/设备实测仍单独未验。

2026-10-28独立切片（基线432eebb1）：先补真实两角色正例与六形态/预适配配置绕过负例，记录RED；集中轻量角色准入规则，接入选角模型、显隐/输入谓词、确认及Run早期检查，保留full-source与省略profile的旧八形态行为；GREEN后串行相关回归与严格历史源码逆变换负例。只交稳定本地patch供独立审查，不推送/合并/发布，不占键鼠。#308尚未合并，后续Run初始化抽取需窄hunk移植；#313需保留GameUI/历史源层。

2026-10-28 PR317 Full rules3真实失败接续：先在46a57e5d原始raw入口复现game_ui_classes_failure:73，再只对该夹具区分比赛与full-source历史职业场景；保留原六个失败/生命周期用例和全部断言，补合法岩主比赛强制选牌失败保护，并纳入现有competition-roster JS包装。保持生产准入、原时限与raw发现入口不变，定向RED→GREEN后仅本地提交交主线程审查。

2026-10-28 PR313已合入cec690c1后的PR317窄合流：本地线性重放已审两角色准入；保留批准稿Host药水/控制器/卡组显示与全部既有UI/历史源fixture。仅新增统一精确roster外层逆变换（Host/View/architecture）置于accepted UI层之前，保留old0a9审查为历史，按原预算串行定向回归和源码守恒收据，独立新审后再由主线程决定推送。无实机或键鼠操作。

2026-10-28 已接受PR319（48cb48ce，父cec）后的PR317同步：仅本地线性重放，保持7d9所有准入/源码逆变换/测试blob不变；逐一证明与已接受319的20个路径互不覆盖，复验严格交付/源契约及静态。仅更新本任务CLI说明，不重复无交互的重Lua整组，不把旧7d9 Full/预审沿用为新组合，待独立新head/base复审后由主线程决定推送。元数据修改继续保持禁止和待用户授权。

2026-10-28 accepted303/develop03b11fa5组合真实回归修复：先线性同步两角色准入并复现run_choice_transactions的Act1/2 Watcher准入RED；仅将这两个真实Omniscience/Empty Fist来源房间回滚夹具明确标为full-source，保留实际获取、奖励随机流、全图alias、异常值、重试及单次提交断言。生产比赛白名单、303回滚和319拆片/源码逆变换不改。原30秒预算串行复验事务与准入/源合同，记录守恒及新head/base独立审查；只本地提交，不推送，不勾平台/原生验收。

2026-10-29 dot隔离集成修复：在ab0e742已审查运行模块基础上保留fd5d输入规格/未完成状态及6d7训练营文档，以原作者和-x接续PR317三提交。先保留prepared Silent经真实选角/原生点击/手柄进入预览适配的RED证据，再仅补选择修改与预览前的实际来源准入；增加严格最外层配置组合证明，保留原全部hash、fixture、断言和时限，并串行验证相关317/303/313/318/315及312工程门禁。仅本地分支供主线程复审，不推送、不改PR322、不占键鼠；负责人Furinya及AC3/4未完成状态保持。

2026-10-29用户确认本次比赛只开放岩系旅行者，雷电将军保留全源码开发/未来版本；本轮在accepted develop e22a443e上重放PR322并保留选择前、适配前和取种子前身份拒绝，复原PR315原15项有界拖牌回归及accepted324探针；单角色公开入口和full-source八角色分别验证，只本地提交待根线程审查，不发布或实机。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已完成正式原生选择/确认分离，八形态真实初始数据、Neow、结果手势和故障恢复专项通过。Node24.18.0下逐行证明旧79475条渲染写入全部保留，新增1703条仅选择页、无Run菜单重绘与隐藏choicePanel；12项历史/负例/当前轨迹门禁通过，30秒原预算保留。Node22部分全量记录含两项不支持test-isolation参数的环境失败，未冒称完整通过。未启动子代理/OpenCode，未占用键鼠。完整CI、GIL读回及最终集成待完成。

完整Quality实际发现旧Start即建局断言和冻结原文绑定不兼容。已保留原哈希/全部断言/原预算，添加仅开局步骤的精确可逆迁移；7项定向门禁与3组28项重开旧输入回归通过。当前原生角色/元素按钮共12项通过。PR290持续收口，未将旧头失败冒称最新通过。

按用户最新明确要求停止扩项并尽快合入。已同步e46bd5dd，保留全部卡框/拖牌/战斗UI与正式campaign入口；解决5处冲突。组合原79689条原生写入全部保留，仅新增1703条，16项组合合同通过。原生启动生命周期单独通过；整组本地冒烟末段60秒超时保留，不放宽预算。此前GIL及221模块读回通过仅属于合流前版本；合流后未重新打包或实机。完整CI与最终合并记录随后以PR290为准。

PR290接续：隔离候选已合入develop d2e0baa3；复核4aba86bc全部有效修复并新增当前正式入口漂移负例，原锁定hash/视觉/三幕及第四幕权限断言保留。Node24.18.0定向21/21零跳过。完整最终SHA Quality及本轮离线副本读回仍执行中；无官方导入、实机或键鼠占用。

2026-10-28队列复核（基线77c2d5e6）：正式开局源码已随PR290合入2ee2f401，当前源码接入阻塞已解除，移出High；组合候选原生构建/读回及必要最终证据仍需补齐，保持In Progress和原2/3验收，不把合并代码当作整体完成。负责人按项目约定统一Furinya。

2026-10-28新比赛决定覆盖旧正式入口范围；既有已勾选项仅是历史离线实现证据。

用户本轮明确确认比赛只保留岩系旅行者与现有冻结V4雷电将军、前两幕；此前已勾选八形态条款仅保留历史离线证据，不代表本次比赛准入或实机验收完成。父TASK-59/47全内容与自然/平台验收不变；本任务AC3保持未勾。

2026-10-28本地运行时切片（base432eebb1）完成待集成：共享轻量准入规则接入模型/显隐/控制器/确认与Run；正式competition-two-act只准岩主和冻结V4 Raiden，Alpha/Dev省略或full-source保持原行为。真实RED确认旧入口可启动HuTao、prepared Silent可绕过；独立复审又发现raw catalogue误拒Raiden与Host拒绝前消费seed，分别补真实RED后修复为GREEN。最终Node24.22.1：7/7准入/严格源逆变换、30/30原生OnStart/两幕与完整历史轨迹通过；六份旧Lua入口（八形态选择、职业续选、prepared兼容、controller、V4跨幕/获取）通过，旧30秒预算不变；此前冻结V4数据及300目录相关37/37组合回归通过。架构231模块1294边；固定Luacheck1.2.0零新增、60历史告警、625职责测量；规划门禁和diff检查通过。独立只读源码审查PASS；仅其后文档/本备注更新，受审src/config/tests身份不变。未跑完整check/托管CI，未生成或导入候选，未实机、未占键鼠、未推送/合并/发布；AC3/4及父59/47自然/平台要求继续未完成。#308初始化抽取和#313GameUI/历史源层仍需按实际合流基线窄hunk重放与复验。

PR317 Full 40739581097/rules3(job123004776107)实际失败已本地复现：raw game_ui_classes_failure.lua:73仍从正式competition入口选择Watcher，前三项成功、第四项被正确白名单拒绝；不是环境或超时，也不能用既有JS成功替代该raw失败。此文件此前没有JS包装引用，本次增加现有competition-roster包装的直接绑定并先复现同一RED。测试限定修复保留原六个启动/失效/选牌/反馈/退出用例及断言，将四个历史职业生命周期场景显式置于full-source，同时断言真实原生入口原本给出competition-two-act；新增合法岩主Warcry强制选牌的比赛故障保护。原始raw入口GREEN7/7(9960ms)，含包装/准入/严格源绑定及真实原生两幕/full-source八形态入口的Node组合10/10(39625ms)，零skip；Lua原30秒预算、发现入口、生产准入和冻结机制均未修改。Backlog及diff检查通过；仅本地提交交审，不推送/合并，不据此重记Full CI或原生/实机验收通过。

2026-10-28 PR313合入cec690c1后已在本地线性重放PR317，未推送：保留批准稿Main/Map/Card及Host药水范围、控制器、卡组计数；两角色模型/View/Run策略及9份既审准入/生命周期用例与0a9一致。仅在测试入口preIntegratedNodeUiSource增加统一精确roster外层，先恢复cec的Host/View/architecture，再进入原post-Node/approved-UI历史层；50份受保护原fixture/历史来源保持逐字不变。真实源逆变换RED→GREEN；作者纯源12/12及正式入口源4/4、原预算串行两幕/完整历史/批准Main回归41/41通过（119309ms，含79543/79757/81392逐写证明）；独立复审另实跑源与roster15/15。测试输入已按当前批准UI重建，非GIL候选；架构232模块1300边，固定Luacheck零新增/60历史告警/625职责测量；规划和diff门禁通过。源码守恒及逐命令日志留在工作树外reconcile-cec690c1证据目录。旧0a9审查与旧Full绿灯只保留历史，不提升本次head；新精确head仍须独立绑定和完整Quality。未占键鼠、未官方导入/实机、未发布，AC3/4保持未完成。

2026-10-28 PR319已由Owner合入48cb48ce（父cec）后，PR317仅本地线性同步：零冲突，无新增机制。守恒证明本PR17份非任务blob与已审7d9逐字相同、接受319的20个路径原样保留且双方路径无交集；src/config/data/.github树不变，src/config/tests patch仍为2ed72f1e8821b7c71cbb7f9c8ff7fd51d1d97bed4b2a55a0e51144b3533dc855。三个roster逆变换仍逐字恢复新base源码，manifest的cec仅保留原来源身份，无须改写。纯JS交付/预算/源契约46/46、roster源1/1、正式入口源4/4通过；架构232模块1300边、Luacheck零新增/60历史告警/625职责测量、规划及diff检查通过。没有重新创建build/lua，也没有重复无交互的重Lua套件；7d9 Full及旧独立审查/预审只作历史，不能证明新base组合。新的精确head/base等待独立复审及当前Full；未推送、未批准或合并，PR元数据更新继续DENIED且未重试，实机/导入及AC3/4保持开放。证据在工作树外reconcile-48cb48ce目录。

2026-10-28 accepted303/develop03b11fa5真实组合回归：干净线性重放PR317，准确复现Full40785892649工程POSIX3/4同一RED：原false/throw两组通过，Act1/2 Watcher在Run准入前被正确拒绝。仅修run_choice_transactions.lua九行差异（5增4删）：明确两个来源房间为保留full-source Watcher组件场景，改构造及匹配profile断言并澄清标签；真实Omniscience/Empty Fist获取、药水/房间、奖励RNG、完整图alias、原异常值、回滚/重试/单次提交全部保留。原30秒预算下串行事务五片及准入/启动9/9通过，零skip，总57.9秒，pile片12.55秒；纯源/交付/319拆片预算45/45通过。机器守恒证明接受319全部20路径逐字不变、接受303六个其他路径逐字不变，Run去掉唯一准入assert即逐字恢复303，来源夹具四个声明逆变换即逐字恢复303；此前317其余16份非任务非Run文件不变。架构232模块1301边；固定Luacheck零新增/60历史告警/625职责测量，Backlog与diff通过。本轮已重建测试用Lua数据/UI，不是原生GIL候选；未Full/托管CI、未官方导入/实机/键鼠，未推送/批准/合并/元数据修改，AC3/4保持开放。精确新head/base待独立复审；证据位于工作树外reconcile-03b11fa5。

2026-10-29独立审查RED：当前PR317在prepared Silent来源选择雷电时，直接命令、真实原生点击和手柄确认均先调用Original.prepare一次并抛character data already prepared；种子未消费、Run未创建，但未满足适配前拒绝。原始复现与日志已冻结，正在本地隔离分支修复，不能记准入或实机验收完成。已保留PR306比赛范围、Furinya和未勾AC3/4；旧八形态证据只作历史。

2026-10-29 dot本地隔离修复：先保留原317三入口适配前拒绝失败、配置投影失败及RD来源展示Geo错配的RED，再修为显式比赛UI身份检查（select前与canConfirm）；M.options/Run/Admission/beginRun工厂语义未改。当前27情景复验通过（22.60秒，原30秒预算），覆盖三类不准入来源与RD→Geo三入口拒绝、来源在预览后变化、零适配/seed/Run、选择和来源图不变，以及一致marker与直接Run无options/full-source legacy兼容；raw catalogue→Raiden和默认岩主由原专项保留。25项严格历史/配置/16-Battle-owner源码合同通过，253注册字段1012类变异受检；旧fixture/hash/断言与预算不变。原生两幕与full-source八形态/Act3及受限Act4、菜单、启动/mock再验通过；303五类完整回滚、318及315在未改动的对应运行模块上已通过，四个关键语义变异均被原断言杀死。最终源码collector和本地分支交主线程复审，未运行最终整体Quality或设备/自然通关，不改AC3/4及Furinya/In Progress，不推送/合并/发布。实际主线后续308初始化抽取须由主线程保留新facade/helpers并在prepareProfile适配前移植317早期准入，不回写旧Run覆盖已合工作。

2026-10-29单角色范围同步：用户本次确认覆盖旧两职业公开要求。AC1/2勾选仅原有历史离线证据原样保留，不是本次公开入口验收；AC3/4保持未勾。雷电冻结V4与全源码八形态留开发/未来版本，不冒充本次候选、实机或自然通关通过。

2026-10-29本地组合基于accepted develop e22a443e，线性重放PR322截至813c84c2的有用实现，跳过其探针替代方案并逐字保留accepted324两份原排序basename/cwd测试。315七份运行模块、原15用例有界两片及JS/worker登记逐字恢复5ef4a37a；完整16-owner和历史逆变换保留。公开competition-two-act只允许ironclad；适配、选角突变和取seed前拒绝Raiden/RD及所有prepared不符身份，显式full-source保留八角色/冻结V4雷电及原MaxHP安全拒绝。新增公开Raiden/已准备Raiden拒绝先红后绿；聚焦29/29零skip（真实拖牌7+8例，preparedUI33情景28.11秒/原30秒，正式两幕终点及full-source八形态/Act3/锁定Act4，活动MaxHP完整回滚）、严格逆变换23/23、范围30/30通过；架构257模块1425边，Luacheck零新增/37历史/941测量，语法/数据/网络检查通过。尚无本组合Full托管CI、原生GIL、官方导入/实机或自然通关；只本地提交交根线程独立审查，不新增验收勾选，不推送或合并。
<!-- SECTION:NOTES:END -->
