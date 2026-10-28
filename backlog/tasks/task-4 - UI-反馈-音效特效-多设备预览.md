---
id: TASK-4
title: 把界面、音画和操作打磨到正式作品水平
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-28 20:43'
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
  - TASK-4.2
references:
  - docs/backlog-details/TASK-4.md
  - docs/backlog-details/TASK-4.2.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/reviews/NATIVE-UI-PARITY-20261028.md
priority: medium
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按批准设计打磨前两幕首局UI、输入、音画与性能，优先前10分钟上手、信息可读性和短程完整肉鸽闭环。四职业及已批准原创角色仍覆盖；同候选PC与实体手机实测不省略，第三幕/隐藏第四幕/真结局及跨局存档不列比赛品质范围。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 攻击、受击、格挡和状态变化都有合适的画面与声音。
- [ ] #2 手机和主机的界面不会超出屏幕。
- [ ] #3 生命、格挡、能量和敌人意图清楚可读。
- [ ] #4 战斗、地图、各类房间和结算符合批准的设计；有区别的留图说明。
- [ ] #5 出牌、命中、掉血、受伤和死亡衔接自然，参考原版节奏，不编造测量结果。
- [ ] #6 群攻、多段、中毒、反伤和死亡等表现完整，实际听过声音并检查设备性能。
- [ ] #7 保存同一个版本的测试与试玩记录，分清本地做好和游戏里验过。
- [ ] #8 按已定界面检查表逐屏验收，音画和手机电脑操作达到你批准的标准。
- [ ] #9 本任务负责人核对所有已交付首发资产与本地切片的正式装配、平台导入和实机结果；占位或缺测均有承接任务、责任人和下一动作，不用子任务Done代替整体验收。
- [ ] #10 四职业及已批准原创角色覆盖第一幕、第二幕的开局、地图、房间、战斗、同局换幕、胜败和重开品质；优先前10分钟UI、输入、音画与性能，逐屏记录同候选PC及实体手机证据，未实测不计通过。
- [ ] #11 完整精修候选在真实手机中完成最坏合法战斗同屏、选角切换、打开卡组及返回战斗验收；视觉清晰、交互可用、无持续累积实例，结果有同版本记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
PR171整合切片：保留develop最新商店原子交易和战后独立选牌界面，解决开场与商人对话冲突；对话框避让全部商品价格；完整本地检查和当前SHA双Quality通过后squash合入develop，保留平台实机验收。

地图金币缺失修复：复用节点页顶栏的生命/金币图标与位置，在地图常显真实局内资源；补选路前可见、归图更新及布局避让回归，记录本地与实机边界。

2026-10-28逐屏还原：按Map/Controls画布及批准原型核对地图、商店、营地、锻造、宝箱、事件、奖励、牌库、菜单/退出，复用PR260功能和PR290/292选角；本地与设备验收分层，完整记录见docs/reviews/NATIVE-UI-PARITY-20261028.md。

最终集成保留#292、正式战斗、共享卡框、公共UI、失焦与开局美化全部来源，按现行用户两幕范围验收12屏1280×720原生UI。用户本轮紧急授权先合并后并行CI；不恢复PatchNotes，不新增玩法或插画，实机缺证据不勾PASS。

dot本轮已切换53fa164主线新隔离树：保留PR302全部生产安全修复、26源历史隔离、原runner和断言；仅逐块移植仍缺地图去圈/卡面/详情/能量/Main原稿纠偏，旧7a合流树只作历史保全，不整笔cherry-pick。共享主题与新增严格逆向由单执行者维护，重Lua串行协调，当前不推送PR或合并。

2026-10-28药水纠偏：在dot独立云树线性接续1f260a7，原子叠加Map共享empty/filled/fire/selected壳体与Main真实状态刷新，保留官方瓶ID及主线安全保护。逐字段主题合并、真实Lua/render及历史精确逆向重验；不推送，等待独立视觉审查；不把离线代显或旧绿灯当还原/设备通过。

2026-10-28发布续接：按用户已授权提交PR要求，将批准稿UI六提交线性接续PR307（0763d2e），保全原UI/历史哈希；仅提交本功能分支的单个Draft PR，以精确head托管Full Quality/inventory完成全量验证。本地两次完整check均因执行会话中断无结论，不再第三次重跑；不改AC/Done，不代替官方导入/ready及PC/实体手机验收。PR310/311/312重叠由主线程协调顺序。

2026-10-28 PR313合后收尾：从实际cec690c独立续接，只处理potion_targeting、game_ui_exit、feedback_continuous_cards三个原30秒夹具的单文件预算脆弱。先用原日志核实独占调度，建立原完整源码SHA/Gitblob及raw/JS/CI唯一发现红测，再复用既有精确注册分片保留全部原case体、seed与顺序，原runner/30秒/断言/权重不改；串行真实短测、独立复审后提交单个Draft PR，最终精确head完整Quality与schema2 delivery preflight后交主线程合并。不改负责人/状态/AC/Done，不操作设备。

2026-10-28 root限定同根因新增第4项battle_ui_potion_target_failures：实际PR313合后29233ms、PR314作业30071ms原30秒超时；仅此项精确分1–3/4–7，保原7组完整body/seed/顺序与runner/权重，先红后绿合同及原30秒两片实测。等待root一次尾部审计决定，不自动继续扩fixture；与既有PR314交付工具修复按root指定三SHA精确原样组合，当前head全量CI独立采证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24用户明确删除首页层数流程及拖牌教学两行；源码e116ca7已修，15组界面回归和4组布局/控制器检查通过，修正版副本独立读回通过，尚未导入。原计划及记录完整保存在本轮Git stash与.artifacts/m1-live-sprint/backlog-changes-preserved.patch。

PR171开场与商人离线整合：已接上最新商店按槽买卡、药水交易及独立选牌台；修复价格行遮挡和新局同编号商店不播旁白。JS全量950通过/118环境跳过，商店Lua35项与开场10项回归通过；完整检查与最终SHA Quality继续核实。平台导入、电脑手机及UI门禁未验收。

用户第9层截图确认地图漏显示金币与生命。已在地图左上补真实资源，复用房间顶栏主题；两项新回归及药水栏两项避让检查通过，语法通过。完整check进行中；尚未新副本/官方导入/实机，保持整体验收未勾。

修复PR187（a03d633）：地图资源专项2项、药水避让2项、宿主6项通过；新增UI门禁回归7通过2环境跳过，源码语法通过。完整本地check在无关build-ui-input-protection的大目录重复复制中长时间无输出后停止，不记全绿；最终SHA的Quality仍排队/运行，未合并。新增实机门禁要求地图gold与hpAndMaxHp，尚未游戏导入。

手机横屏左右露底按P1在TASK-38推进，共享背景层修复；正式发布前须核对所有主要页面。离线几何、候选读回、官方预览、真实手机和性能证据分开记录，未经本轮输入时间协调不启动GUI测试。

2026-10-27同类范围审计：承接已批准四职业与第一至隐藏第四幕完整范围及原创角色责任，纠正仅第一幕总验收口径；原验收证据保留，本轮新增要求均未勾，不声称新增实机通过。

2026-10-27正式精修美术必须在同一个真实游戏候选中验证：选角、手牌最多10张、玩家、合法最多敌人、场景、奖励/卡组覆盖层，测显示、操作、加载和资源清理；安卓真机基线与精修版对照并连续试玩30分钟，不能用PC压测或离线画图冒充。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
原AC10（仅保留历史要求，不再作为当前比赛必做）：四职业及已批准原创角色覆盖第一至隐藏第四幕的地图、房间、战斗、换幕、普通结局和心脏真结局品质，逐屏记录同候选PC与实体手机证据，缺项不以第一幕切片代替。

2026-10-28 PR295：地图雾气/令牌/路径层次、原生操作说明、牌库40高选择反馈和标题遮挡已补。39项UI回归、最后9项、工程门禁、34状态零文字裁切及#292选角组合8项通过；13张离线图和逐屏对照见docs/reviews/NATIVE-UI-PARITY-20261028.md。不改规则/卡框，不恢复公告。没有GIL/官方导入/ready或本轮设备实机，verify:ui未跑，整体AC不勾。比赛设备验收按PR291前两幕范围执行。免费只读审计197.73秒，19工具完成/1权限拒绝，两建议接受一项，事件费用0，输入69293/缓存读745984/输出1972/推理14681，Codex额度节省未知。

最终集成68d25c77的完整计划和历史记录已与最新两幕范围合流，双方原始任务快照保存在docs/reviews/ui-merge-task-history-20261028.json.gz；逐屏要求/控件/实现/测试见docs/reviews/UI-FINAL-ACCEPTANCE-20261028.md。保留新菜单、只读地图、三意图、状态角标、输入保护和RGB导出修复。最小原生3项/构建/语法/架构通过；完整CI、原生预览和手机仍未全验。

合后CI收尾：保留战斗线程晚到两笔测试/候选交接；修renderEnemies33、退出前景17/16超过原门禁的问题，各helper仍受10/15原上限。Luacheck73条明确历史诊断/零新增，432项职责度量通过；原生控件、选角、牌库、退出定向13/13过。静态基线11个过时项与23个移行均有逐条源文证据，未放宽预算。全量CI和历史source/trace迁移仍不声称通过，设备未验。

本轮53fa隔离合流已完成地图去圈、卡面两批、详情A/能量的逐块源码合成；卡面26路径冻结hash一致。保留PR302提示/意图安全修复、遗物索引、原runner和26源gzip原字节，新增15路径精确逆向恢复53fa。新层/原53case+6seed元数据7项及纯JS布局35项通过；data/UI/theme构建、220模块/1259边架构和JS语法通过。独立只读接层审查无严重问题，实际临时新增文件删除补强2项通过。Main未交、完整Lua/完整Quality/官方导入/设备验收均未获本轮证据；状态/负责人/AC不改，不推送。

2026-10-28 dot 隔离UI合流阶段：53fa基线已逐字段合地图三批、卡面两批、详情/能量/Main，58源精确逆向保留旧26源/全部golden/原预算。最终53case+6seed、Main/详情/能量15项、相邻详情19入口、3逐写trace、38地图组、5完整host均实测通过。当前为离线候选，完整托管Quality/inventory与同候选官方导入/ready/设备UI验收未完成；未推送/PR/合并。fresh远端1f260a7(PR305)仅治理路径、与UI零重叠，待根线程决定基线吸收。Owner/状态/AC不改；证据docs/reviews/APPROVED-UI-CURRENT-INTEGRATION-20261028.md。

2026-10-28药水新纠偏源：原子接入空/普通/火焰/真实选择态及Main失效owner先退役；保留官方瓶ID。独立评审修正单小亮斑为原稿端点插值的双内切soft-disc；可移植原HTML whole-face离线模型先红后绿，新源短测9/9、精确58源逆向6/6、架构221/1265、73条历史诊断/原复杂度预算通过。Battle3283/Game10411节点仅静态计数，不是手机性能证据。原阶段27 Lua文件（原53case/6seed、5host、11target、38map组）均通过，明确不冒充新梯度源完整门禁。随后串行完整npm run check；不推送，待root最终diff审查。docs/reviews/potion-shell-integration-20261028/README.md；视觉/官方导入/ready/设备/完整Quality仍缺，AC不勾。

2026-10-28 16:59 UTC：rebase后便携CI合同12/12、最终药水/Main/Map及inverse入口11/11、完整inverse6/6；网络/语法/221模块1265边架构/73条旧静态诊断及原复杂度门槛通过，25个冻结源和历史哈希不变。一次CI短测14通过1失败已定位为云缺pwsh（spawnSync ENOENT），不安装、不跳过，交托管真实执行。d6a0881两次完整check分别16:37与16:42启动均无终态，重试最后heartbeat16:54:23且16:59:19锁FREE，不算PASS或代码FAIL。完整原日志、同状态离线壳体对照与产品未测边界见docs/reviews/approved-ui-publication-20261028/。本条只记进度，不勾整体验收，不代表已推送/CI通过。

2026-10-28 PR313续接PR310：保留真实Node根入口与10拆分模块，批准视觉仅移faces；新增精确完整源逆向与写前负例，不改原58/26档案、golden、runner及预算。旧新9个Node夹具输出SHA一致，原3逐写通过；最终原生21项、live action8/target7及新增ownership9/Curl/duplication定向通过，便携架构231/1297、60旧诊断/625测量通过。完整历史组合曾20/21，仅错误文本regex已补回并单项重验，不伪报全绿。仅准备更新同Draft PR并等待新精确HEAD完整Quality/inventory；无第三次本地全量、无官方导入/ready/设备或性能证据，状态/负责人/AC不改。证据docs/reviews/approved-ui-publication-20261028/PR313-NODE-INTEGRATION.md。

2026-10-28 19:00 UTC：PR313精确7a4910b托管inventory/presentation已绿，POSIX4绿，POSIX1发现唯一frozen glyph theme接层漏识别；先从与旧4211字节相同的不可变fixture/原formal位置hunk独立证明f88fac及992e，再只在theme路径接回这两个旧身份。系统只读审计确认无其他直接frozen旁支；新正链/单字节漂移/错path和原live根/faces写前拒绝通过，相关28项/JS语法绿。其余矩阵仍运行，待收齐后同PR一次推修复并重验当前SHA完整Quality，不豁免业务红灯，不改整体AC/Done。

2026-10-28 19:11 UTC：继续收当前7a4910b真实CI失败。rules8 Drag旧oracle将raw变换分数坐标与实际target中心强行逐位等同；最小探针证明stale前后各自坐标不变。迁为严格比较真实reticle/目标ID前后，保留原gesture/preview/energy/hand并加完整core图快照，原30s整组10/10（16.746s），root独立读diff认可。rules1 class_choices原30s最后第10组超时，同源26.590s无足够托管余量；复用既有机械拆片1–5/6–10，原8973字节整body/seed/assert及Gitblob精确可重建，runner/30s不变，raw/JS/CI唯一发现合同先红后绿2/2，两片原30s各5组实测11.357/13.425s，CASE1..10各一次，root独立逐文件认可。完整矩阵尚未终态，先收齐再更新同PR并重验精确head；不勾整体AC/Done。

2026-10-28 19:23 UTC：当前7a4910b最后补读rules4唯一potion_belt_ui旧help可见假设，迁真实瓶长按/独立4与5槽potionId+标题/详情关闭+菜单Use；保留容量/补位/库存/能量+2/Strength2/商店奖励全部原断言，最终5组13.206s。targeting_help旧隐藏控件假可达先加visibility断言实测红，再真实瓶长按，原文案/完整快照/target/S13/P12保留，最终3组9.867s。系统扫描无其它Use/旧enemyRow实时输入漏项；已授权的remaining/flex_speed/sustained三可见性盲点只保留原隐藏存储和可信core设置，新增真实可见长按信息检查，原6/2/3组9.799/3.899/5.034s通过。扫描到此停止扩范围；不改生产/runner/golden/预算，等待当前矩阵终态后同PR一次push并重验精确head全量Quality。

2026-10-28 PR313合后预算收尾：实际cec690c与原PR绿灯同tree；三原30秒raw夹具在合后ETIMEDOUT，既有权重已独占，不归因双worker。只精确分片potion 1–4/5、exit 1–5/6–15、continuous 1–4/5–9，原29组case体/seed/assert/order完整逆向SHA与Gitblob保留，runner/30秒/权重不改。红测后源码/漂移拒绝/raw/JS/CI发现及旧class合同7/7；六片原runLua实测12.013/13.702、15.315/11.027、10.536/13.769秒，原29组markers各一次。JS语法与diff检查通过；独立复审、当前head完整托管Quality及schema2 delivery预审待采证，不补造PR313旧收据，不改负责人/状态/AC/Done，不含设备实机。证据docs/reviews/ui-postmerge-budgets-20261028/。

2026-10-28第四项预算收尾：battle_ui_potion_target_failures原7组精确逆向SHA47565faa/Gitblob5faa5cf，含原up/endDrag注册循环均保留。新两片原30s实测9.720/13.009秒，原CASE1..7各一次；累计4文件36原组/8入口，源码/范围/固定注册器恶意双改与发现合同8/8过。此前6入口真实workers=2 pool原权重路径也全部过，unknown10秒默认仍独占，不以调权阈值刷绿。仍无托管组合绿灯或设备实机，不改状态/负责人/AC/Done。
<!-- SECTION:NOTES:END -->
