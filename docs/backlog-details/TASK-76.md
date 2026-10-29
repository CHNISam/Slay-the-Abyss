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

## 2026-10-28：完成拖牌后的 Click-only 动作边界

基线 `1f260a71972b03dae5b63e8d6f12d055973a4c83`。真实防御拖出后，完成手势留下的全局 `suppressClick=true` 只能由另一个 Down 清除；仅派发 Click 的结束回合、奖励入口等因此持续被拒绝。首版消费标记的修正另有已红回归：`endTurn Click(touch7)` 第一次被吞后清了标记，同触点第二个 Click 可以结束回合。

本切片把已完成/回手取消的拖牌屏障绑定到原手势，只在已有控件令牌门禁之后允许独立 Click 退役全局屏障。固定单个 `releasedDragTouch` 继续拒绝最新完成拖牌的具名触点，独立匿名或不同触点的 Click 不使它复活；该触点有效的新 Down 恢复输入，下次完成拖牌替换记录。没有触点历史集合、计时器、逐帧解锁或全局能力饱和开关。既有卡牌、动作、药水、敌人的单次释放令牌与布尔取消屏障不变。

### 明确的能力限制

- 官方 `CursorEventData` 声明 `touchId`，但没有本轮可据以区分事件代次的 nonce，也没有证据证明 Click-only 必然不带 touchId。最新同 ID 的新 Click-only 动作与尾随旧 Click 不可区分，故没有新 Down 时仍保守拒绝；这不是原生按钮兼容性已验收。
- 匿名拖牌的首个歧义 Click 被吞，之后允许明确重试；接口无法区分这个重试与第二个匿名 ghost，不能保证匿名重复跨控件 Click 全部安全。
- 只记录最新完成拖牌的触点，不能识别任意更早历史裸 Click；同控件、同 ID 且新 Down 后的旧包也不能据此识别。已有令牌仍保护其原本覆盖的旧卡槽/状态边界，不扩称全历史重放防护。

### 本轮离线验证

- 新真实处理器场景 15/15，Node 聚焦 2/2；保留原 30 秒单文件预算。包括 Up/EndDrag、同触点重复、两个连续拖牌后不同具名 Click-only 动作、最新同触点需新 Down、不同具名/匿名奖励入口与跳过、回手取消、活跃拖牌归属、busy/inactive Down、布尔缩放屏障及冻结雷电将军 V4 E。
- 历史逆向与 TASK-77 源层 4/4；新增层仅识别完整源码 `676abfb20f92539b4af8ed2692388d9d2fbb29176d1069931e3afb0926211cfa` 并精确恢复原 `3ad8ad013a4bcd67d29f4dcee30093819725088d78b9d53681df161d46de7e06`。旧 source/golden 身份不改，额外漂移、重复/遗漏片段仍拒绝。
- 同一最终源码串行相关 Lua 49/49（全部原 30 秒预算，最长 25.092 秒），包括原 `drag_input_boundaries` case 4；受影响历史 Node 层 27/27。`check:engineering`、`check:syntax`、`verify:backlog`、`check:network` 与 Python 表现层 65 项全部通过；架构 220 模块/1259 边，Luacheck 无新增诊断、73 条历史警告，432 项职责测量及四项关键变异全部通过。未跑完整 `npm run check`，本地聚焦验证不替代远端当前 SHA 的完整 Quality。

本轮未构建/写入候选、官方导入、取得原生派发轨迹或操作键鼠，也未发布。TASK-76 继续 High / In Progress / Furinya，原 0/3 验收不勾选；PR 集成与当前 SHA Quality、同候选原生回归仍独立缺项。

## 2026-10-28：PR315 接续批准稿 PR313

新基线 `cec690c1701af121e370facde5c1ca2ad9beb99e` 已改变真实药水入口：瓶子 Click 打开菜单，可见 Use 才使用。四处冲突只合成输入与历史身份层，不恢复旧直用路径、不回滚批准稿。旧 `302ddc06` 的独立审查/Full 绿灯保留为历史，不作为本组合的验证。

组合复核另外实证两项 RED：独立匿名瓶 Click 打开新菜单后，旧具名拖牌的 `Use/Discard Click(touch7)` 可越过新菜单的 Click-only 降级执行。两项均先失败；给弹窗增加可选指针适配：原 owner/generation/库存/回合门禁通过后的新 Down 才重新拥有触点，Click 在执行前经过既有 latest-origin/布尔取消/活跃手势屏障。Down 不调用关闭菜单的 `closeInfo`；原控制器入口与规则命令不变。

冻结源码：
- BattleUI `067b6761d5f02477ec2aeb848b2a00eb2b4191517d30096f7cb8dc84e3f0b382`，精确逆向恢复批准稿原 `a1d68a1fcba74fff54fb22cb4641cd400e4c76e2d3a7e22d69e352efeb8e7d91`。
- 药水弹窗 `c530888e8afe4c98120fa51b459b1724c7be93fa76f48334ac368031806e08bd`，精确逆向恢复批准稿原 `d50f03654abd678719f610bce920f67c5b7bc45656103231fae04f3c3761ceba`。

最新层位于无环依赖的独立测试 helper，先于批准 UI/PostNode 身份门禁；原 p0 导出保留兼容，原历史档案/fixture/golden 原字节不改，写前 Node 完整性检查不动。旧 `676abfb2→3ad8ad01` 完整见证仍可恢复；两份新 runtime 的所有批准稿字节均由完整源码恢复证明约束。除这两个输入文件外的 runtime、主题、数据和布局脚本均与新基线一致。

本轮同一冻结源：聚焦 Node 2/2、真实场景 15/15（25.352 秒，原 30 秒）；保留全部原场景并在原两组中覆盖匿名菜单/Use、旧 touch7 的重复 Use/Discard、同 touch 新 Down 的 Use 与 Discard、busy/inactive 旧 Down 不解锁。额外两组 RED 0/2→GREEN 2/2；适配后相关五个 Lua 脚本 5/5，最长 16.318 秒，覆盖真实药水菜单、宿主控制器、药水/目标所有权。原先无弹窗适配时的 12 个组合脚本通过日志单独保留，不冒充新增适配的复验。历史纯 Node 12/12、语法、架构 231 模块/1297 边、原静态 60 条历史诊断/零新增及 625 项职责测量、Backlog 与网络检查均通过；未跑本地完整 check 或完整 engineering 聚合。

证据在工作区 `task76-click-origin-evidence/refresh-approved-ui-cec/`：保留失败与成功原日志、失败时两份源码、`source-conservation.json`、最终聚焦/相关/历史与静态结果。仍须独立当前组合审查、当前 SHA 托管完整 Quality；无候选构建/官方导入/ready/键鼠/设备验收。三项原生身份能力限制不变，TASK-76 继续 High/In Progress/Furinya、0/3 不勾选。

## 2026-10-28：当前 CI 的旧尾随事件夹具身份

当前 `07e4b026` 的 Full run `40763454536` / rules4 job `123082084026` 在原 `battle_ui_slice_3.lua` 的 case40、support 第1089行失败，不是超时。先在同源真实处理器精确复现 RED（4.861秒）。隔离对照保留原断言：accepted cec 的旧全局布尔屏障吞掉无元数据 Click；当前有限协议把无元数据 Click 视为独立动作，合法打开敌人详情（`info.index=1`），下一次 Down 只关闭详情并吞掉该序列，所以未开始拖牌，头像边框59而非245。

夹具把该 Click 注释为“尾随释放”，但其拖牌事件始终具名 `touchId=0`，共享 `click()` 却没有传任何事件。修正仅将这一个模拟尾随事件发为同源 touch0，并增加无详情/手势/选牌/target/能量/手牌/第二敌人HP变化检查；原五条取消、HP、高亮、预览、目标2提交断言逐字保留。独立无元数据敌人 Click 的合法检查另放在既有取消场景：打开批准详情、下次新 Down 关闭详情、匹配 Click 被吞、真正重试可正常选牌。不能把匿名独立动作伪装成已知具名尾随事件。

修正 support 完整源码 `6adf9566320c60e8b68fb8854ccbf9dffb0eb34f7510d5a32309d4a3461d7590` 只经新增精确见证恢复旧 `874ad3cf102493953104fe3d556e6839b5599a249d37679b5a2fad862517375d`，再走原批准稿/视觉/53case历史合同；旧档案、whole-body hash、全部53case/6seed、runner与预算不改。两份生产源码继续冻结为 `067b6761…` / `c530888e…`，无生产、主题、数据、配置或布局改动。

当前修正验证：历史与冻结合同15/15，含原七片53case/6seed真实执行；聚焦Node2/2、15场景24.473秒，仍为原30秒。证据在 `task76-click-origin-evidence/ci-rules4-fixture-identity/`，保留精确RED、current/accepted逐状态对照、原support、完整历史及最终聚焦日志。旧07的CI失败和旧绿灯均保留；新完整HEAD仍待独立复核和托管完整Quality，不推送、不改PR元数据，不据此宣称原生输入验收或TASK-76完成。

## 2026-10-29：dot 本地逐职责组合（未发布、未做原生验收）

基于已离线验证的 `eb7d62ebe451f20605dcd60e18558748c495c7e2`（`0744c79` + PR312），将 PR315 的 `a39aa7c9d9bc8569adc1dc412009be7ee7e038e0` / `e80fe3579cb657662ab110450ac30754216c773d` 逻辑逐块移入311已有 owner：共享 `ownership.releasedDragTouch`、input_state 消费服务、card_gestures 终止标记、动作/药水/敌人最终Click门禁，以及既有批准弹窗可选适配。不把旧单体BattleUI覆盖回来，不改303回滚、313药水菜单、318最大生命、319预算或312检测策略。

原15场景在真实新底座先红（2通过/13失败）后绿；最终同一真实拆分处理器15/15，26.161秒且原30秒不变。原单体历史hash合同另行先红；新增精确16模块整体逆向，只投影完整本组合恢复原311/313完整见证，再恢复原315/53case历史身份。新增全16模块缺失/漂移、端口片段遗漏/重复等负对照，旧档案、fixture hash、原断言与预算不改。原53case/6seed仅本轮做完整元数据和负对照，不冒充重新实跑全部七片。

303回滚9组、318当前owner4组、批准药水菜单/宿主/瓶体与相关源码合同通过；312当前全量收集251模块、3840/3840测量，原硬门禁零新增诊断/37历史警告、792职责测量，架构251模块/1395边及语法/网络/Backlog通过。最终证据和本地head/tree由父线程独立复审冻结；托管Full/schema3预审、官方导入、ready、实体手机与PC自然流程仍独立缺项。

匿名Click可能合法打开详情，随后Down只关闭/吞掉该序列，完整重试才恢复；旧即时开始下一拖牌探针仍红。同latest ID/no Down、匿名重复和更早裸Click无法完整辨代。`abyss_card_input.release` 未改，手机无效释放/空目标回Idle合同仍由TASK-30承接；六条TASK-76 AC继续未勾。此组合不宣称原生/手机问题全部修复。父线程须保留随后PR322 `fd5d5b59` 的TASK-83与UI_DESIGN更正；本切片不触及这两个文件。
