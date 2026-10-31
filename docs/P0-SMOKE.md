# P0 完整游戏集成冒烟

## 实测前先约桌面操作窗口

先说明本轮候选、要操作的客户端/沙箱、目的和预计占用时长，等用户明确让出鼠标键盘后，才可启动或激活应用、抢焦点、自动导入、发送模拟输入或开始会占用前台的实机测试。历史实机授权和一般“继续测试”不替代本轮输入窗口；没有回复不能开测。先检查工具及其后台子进程的副作用，不能因使用CLI/MCP就当作不会抢占输入。

已约定窗口内按计划操作，不反复询问每一步；用户要使用电脑、窗口结束或焦点失败时停止输入/前台切换并终止自动重试，重新协调后再继续。所有子代理服从同一窗口，只留一个桌面操作者。未约定时可继续离线构建、静态检查和候选审计，官方导入/同候选试玩记未验证。具体协作要求以AGENTS.md“桌面输入与实机测试窗口”为准，下文历史授权不覆盖此规则。

## 当前 Production v1.0.0 冒烟（待逐项执行）

本节是当前检查清单，不是通过记录。范围以 [SCOPE](SCOPE.md) 为准：仅岩系旅行者、第一幕与第二幕；保留完整构筑、奖励、商店、事件、遗物、药水及同局跨幕状态，不开放第三/四幕和其他职业。下方旧候选、15层单幕步骤及当时缺口仅属历史，不作为本版完成标准。

### 固定候选与验证层次

- 由唯一集成方冻结干净源码 SHA、`1.0.0` 版本与完整必要 CI，记录 buildId、payloadDigest、最终含音频 GIL 的 SHA256、配置及构建收据。Production 使用独立于旧 Alpha 的作品 GUID，分别记录测试存档 ID 与正式作品身份；不把 Alpha 包改名或复用旧发布凭证。
- 复用现有完整入口：`npm run build:native -- <独立Production底图.gil> <新输出目录> --release-candidate --work-key=<正式作品键>`。作品键必须显式指定且不是默认 `alpha-test`，美术开关沿用已批准候选；保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`。工具前提见 [TOOLCHAIN](TOOLCHAIN.md)，版本和人工发布边界见 [PUBLISHING](PUBLISHING.md)。
- 源码/Node/Fengari、Simulator 截图与交互、GIL 构建/读回、官方导入/本轮 ready、PC 与实体手机分别记结果。模拟器画布不等于手机，CI 绿灯不等于官方导入或自然通关；不存在本轮证据的项记“未测”。
- 复用 `npm run verify:ui -- <候选.gil>` 与 `npm run verify:platform-load -- <最终candidate.json> <official-load.json>`。官方关卡≤20MB、服务器≤3MB分别核验，16MB为内部关卡预警；静态/动态负载、高峰战斗、复杂手牌、多敌特效和重复进出均须同候选证据，不能以 GIL 文件大小替代官方读数。

### 人工路径与回归重点

1. 导入独立测试存档，核对候选身份及新日志中的构建标记、ready 和运行错误；菜单不串屏，版本与操作说明可读，仅能选择岩系旅行者。不使用旧日志补齐，不操作发布/赛事报名。
2. 首战记录 HP、金币、卡组、遗物和药水；出攻击/防御牌，测试选目标、取消、无效拖动后恢复，并点击右下角结束回合，核对敌人行动、生命和格挡。
3. 查看牌组及抽牌/弃牌/消耗牌堆：轻点查看详情，滚动不误开详情，关闭详情返回原列表后仍能滚动、再次点选；返回战斗后出牌/目标/结束回合正常，不残留弹窗或输入占用。
4. 胜利后领取/跳过卡牌，领取金币、药水且不能重复领取；回地图核对资源与合法路线。覆盖营地回血/升级、宝箱、精英和事件的选择/退出。商店先点商品查看详情，再确认购买；覆盖金币不足、取消、购卡/遗物和删牌，核对扣款与所得只发生一次。一次路线未覆盖的分支另开一局补测。
5. 使用正常数值完成第一幕并进入第二幕，核对卡组 UID/升级、HP、金币、遗物、药水及随机流连续；逐节点保存路径、入/出状态与日志，不以重建新 Run 替代跨幕继承。完成第二幕 Boss 后正常本局结算，不出现第三幕入口；另验失败、重开与平台重新挑战的状态重置。
6. 在 PC 与实体手机分别验证首局与上述关键交互。在**目标 iOS 实体设备（记录测试机型和系统）**上，检查本局用时初值、跨分钟显示、战斗/选路/奖励期间推进、跨幕连续、终局停止及新局重置；保留短录像和对应日志，核对真实耗时与当前计时语义，不以旧 `OnUpdate(dt)` 历史说明代替回归。记录切后台/恢复后的表现，不凭模拟时钟宣布手机已修复。
7. 检查文字裁切、触控命中、音效/BGM、切屏和重复进出后的控件/输入清理与负载。任何缺陷记录候选 hash、设备、步骤、预期/实际和日志；修复后生成新候选，先重跑最小闭环，再补受影响全程与同候选验收。

每项分别标“通过 / 缺陷 / 未实现 / 观感问题 / 未测”，写明证据所在与验证层次。发布、报名及真实回执仍由用户完成；此清单不创建 Tag、不登记发布成功，也不改变任务验收状态。

## 历史候选与验收记录（不认证当前 Production）

2026-10-24 M2已验收并归档：正常17层通关保持本轮原生日志，失败结算和退出复用各自冻结候选的既有实测；用户本轮明确确认重开与重新挑战已亲测，本地退出/结算/重置60组和布局3项复验通过。详见[M2验收](M2-CLOSEOUT-20261024.md)。下文“失败/重开仍缺”是人工确认补齐前的历史状态，不改写旧自动日志覆盖范围。后续候选和最终RC继续按各自版本取证。

2026-10-24 M2新增：固定源522e547的显式正常数值自动测试副本已在官方1843完成17层、Boss宝箱Sozu和正式胜利结算。bd08本轮4032打印、ready和266成功动作完整，新25号日志在工具真正离开官方结算后延迟落盘；原runner logFile:null历史保留。见[M2证据](evidence/m2-live-20261024/README.md)。失败/重开/重新挑战仍缺，后续独立居中选牌组合不冒用旧候选截图。退出必须验证画面实际离开和新日志存在，不能只依据发送计数或left-playtest步骤。

任务沿用 TASK-3（构建、导入、最小闭环）、TASK-5（真实第一幕回归）、TASK-17（Boss正式结算）。用户2026-10-24已授权实机验收，固定5165候选导入1073741838；完整最小战斗和奖励回图run9bb0abe3、独立主动退出run8f623503已取证。[当前报告](M1-LIVE-ACCEPTANCE.md)与[原图/日志/读回](evidence/m1-live-5165a78.json)分别保留900秒自动中断与真正主动结算，M1整体仍未完成。游戏 GUI/MCP 由主 Agent 独占；保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`，不发布。以下各节为按固定源保留的历史记录，不代表当前仍未导入。

## 当前规则与BGM离线候选（未导入/试玩）

新增显式离线图载荷审计已实际复核`11b901f`副本：完整NodeGraph按同SHA重新编译、内存重注入后匹配，双方decode/encode均无损；只排除明列布局坐标，原candidate hash未变。报告根`.artifacts/graph-payload-audit-11b901f/graph-payload-audit.json`及其SHA已补[同源证据](evidence/offline-candidate-11b901f.json)。这在原只读源/UI/挂载审计之外单独补证，不认证图外信号定义、stage/prefab、编译器语义或实机。

PR102当前head`0c3fd84a46f9feca6436f78ef69665a9249072f6`的[Quality双作业](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39932782189)已SUCCESS，squash合入`601474649373c85dd4daad8650a7d01bf3c37b3b`。同时保留PR101新增的真实牌/合法路线诊断，生产`src/data/scripts`与PR102 head相同；副本仍按实际构建源`11b901f`标记，不能用后续squash号替换。

第二批最新普通副本：`.artifacts/continued-rules-11b901f/wmvkrqkgh-0/working.gil`，固定源`11b901f8b4ff0c91762ee6e2e46affcc88dc033a`，SHA256 `4f5de8f2ae0c1bfec4a86963cf77ec44cf99a2ad8b6dcb1c420254732560c70b`。已含Acid/Spike/Fat/Sneaky抽样和死后排队选招/减益；30模块逐byte同源、1590树/max50、六列模板、22节点结算stage启用、BGM双参数false、静态0error17warning。首次构建d3源因普通manifest漏BGM参数真实失败，补注册false后新目录重建成功，保留原失败响应。[结构化证据](evidence/offline-candidate-11b901f.json)和根`.artifacts/continued-rules-11b901f-audit`保留全部hash/读回。规则源d3e9d76完整check exit0（JS643/528pass115skip、全部Lua、Python15pass1skip），参数/审计增量15专项过；最终head CI另记。Dazed/Sentry/Artifact不在此副本，未导入/试玩/试听，发布关口未通过。下列139/cf固定候选不含本批修正。

PR99默认关闭的原生BGM候选已合`1182814`；PR100规则批已合`14979df`。两PR当前head的两个Quality作业均SUCCESS。规则完整组合在源`139de94`实际运行`npm run check`退出0：JS603项（488通过/115既有条件skip）、全部Lua、Python16项（1个既有权限skip）。合入独立BGM代码后图/打包6项、BGM/宿主5组通过，最终`cf6969e`的[Quality](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39926170680)全绿；`cf6969e`与squash合入`14979df`源码树已实际确认相同。

| 副本 | 固定源 / SHA256 | 实际只读复核 |
| --- | --- | --- |
| `.artifacts/continued-batch-139de94/wmvkpu9f0-0/working.gil` | `139de949b173c8343d628ce6ba036097a9ff954e` / `a3dc885af8a42ec1c51ce529809c3a27d2ba75e8909bd42abfec9cb828e6b90f` | 28模块同源；1590树节点/max50；六列模板；22节点结算图stage启用；静态0错误/17警告 |
| `.artifacts/continued-bgm-cf6969e/wmvkq4e3z-0/working.gil` | `cf6969e768a6102a726948742dd327642043c2ab` / `474516d219689b1e2355023427b2cb74ade1c4f8f6ddf39504ea7730fe516eee` | 29模块同源；同UI/模板；22节点结算与83节点BGM图均stage启用；脚本BGM参数双记录均true；静态0错误/17警告 |

真实MCP编译/写副本完成后，另一agent独立从固定git源重建五个生成模块并读回gil。生成模块逐byte相同；源码允许Git LF与工作树CRLF换行差异，规范化后全文一致，原始hash分别保留。UI和模板逐name/kind/子顺序同源匹配；1590是控件树计数，1592包含两个界面壳节点，初版审计误混口径的更正也已留档。详细证据：[规则](evidence/offline-candidate-139de94.json)、[BGM](evidence/offline-bgm-candidate-cf6969e.json)，原始响应和验证脚本在对应`.artifacts`目录。

底图hash前后仍为`6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`，BGM叠加也未改变规则输入副本。17条静态警告分别为16条已定位的项目自定义方法名称识别及1条尚未生产接线的unknown reducer，不是运行正常证据。没有官方导入、客户端ready/本轮游戏日志、真实操作或音频录像；六条BGM曲目均未试听。默认完整游戏构建仍不启用BGM，专用试听命令见[NATIVE_BGM](NATIVE_BGM.md)。

地图严格golden本轮仍FAIL 0/12（11差异、1完整64位seed不支持），成功导出的11样本额外随机宝箱错误降为0；交叉边/拓扑/RNG等仍未对齐。后续发现的死后排队选招消费差异、完整动作队列及Boss17宝箱事务继续由规则任务推进，不以此批代码或副本关闭全项AC。下一批未合入切片不得计入上述固定副本。

## 历史首次点牌修复候选（085f499，未导入/试玩）

真实构建源`085f499418e0d3eb7a8a556893c389222af487b6`，在ec455f6全部规则/UI/打包修复之上加入PR93：跨战斗重置失效目标与选择，同一战斗刷新仍保留有效选择。原20块宿主UI回归与新增首点回归共21块逐字保留，拆为15+6，Node双进程及LORE检查通过；默认每脚本15秒未变。历史完整本机check属于ec455f6，当前完整门禁以本修复PR最终head的Quality为准，不混用源SHA。

实际副本`.artifacts/offline-sprint-085f499/abyss-sprint-offline.gil`，SHA256 `b22a876a752d923fa3211dedbeceace74548dfb0ba3acc98590b8243c937b95a`。真实读回26模块/0error/17warning、1590控件/max50、38按钮状态层、六列牌库和22节点启用结算图；无测试向量。正式底图hash保持`6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`，liveWrite=0。[结构化证据](evidence/offline-candidate-085f499.json)区分当前副本/定向测试与历史全检。未开原神、官方导入或实机，所有上述未完成关口仍保留。

## 历史规则与按钮候选（ec455f6，未导入/试玩）

真实构建源`ec455f6b56efcab3deed4ac688676eba58c8a73b`。包含已合PR82力量/敏捷cap、83支持池Boss稀有奖励、84生成输入保护、85群攻后逆序反伤、86三类敌人数值与动作、89Wizard蓄能、91Jaw生产AI/节点按钮状态，以及62地图证据/纯问号reducer；87/88/90仅独立证据或候选，不代表生产算法已切换。

完整`npm run check`退出0：JS584项=469通过/115个Windows符号链接权限skip，全部Lua通过，Python15通过/1权限skip。新增101个symlink skip来自PR84，不计入已覆盖的通过项。Boss奖励保留128种子及全部断言，拆分为四个默认15秒预算的真实Lua脚本；CI失败与后续修复记录在对应PR。

后续CI在`game_ui.lua`整文件15秒预算超时，没有断言失败；同源本机完整检查通过。原20组宿主UI回归拆为14组主流程+6组牌库，全部202条块内断言和9条helper断言原样保留，每例仍新建真实控件树，默认15秒预算未改。两脚本实测4.656/1.913秒，Node入口运行两份并合并全部LORE文案检查；[逐例迁移审计](evidence/game-ui-split-audit.json)记录原/新20块相同SHA。随后同步的PR93新增跨战斗首次点牌回归也保留，因此当前实际计数为15+6共21组。ec455f6副本早于PR93，不能用该副本声称新增点牌修复已平台验收；最终远端CI以PR当前完整head为准。

中间源54e8eef曾真实装入测试生成的`sts1_unknown_vectors.lua`，为27模块/18warning。构建器现只选5个明确的生成运行时模块，全部源模块保留，工具写入前拒绝缺失或同名；新副本为26模块/0错误/17warning，已不含测试向量。17warning分为16条既有跨模块自定义方法，以及1条未接生产的`abyss_unknown`未挂载提示，不能说警告为0或问号分派已实现。

- 实际副本：`.artifacts/offline-sprint-ec455f6/abyss-sprint-offline.gil`。
- SHA256：`a4f90ebb7230201989e89fbb270a98ec601c8f05861fd078bf81617453ffb9bc`。
- UI1590控件、最大50直接子；19个框式按钮各增加hover/pressed层（38层），六列牌库与22节点结算图启用挂载真实读回。
- 正式底图SHA256前后均为`6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`；liveWrite=0。
- [结构化证据](evidence/offline-candidate-ec455f6.json)保留源SHA、完整检查统计/日志hash、模块检查、UI/模板/图读回和副本hash。

没有开原神、官方导入、设备预览、听验或真实平台试玩。原版独立RNG/拓扑/问号分派、Weak轮末justApplied调度、Boss第17层遗物箱、TASK2物理配置及胜利正式结算等仍未完成；原版地图Golden0/12与10000结构种子0通过的严格失败报告在W1文档，普通CI与副本成功不能替代。

## 历史新版节点与结果界面候选（7013641，未导入/试玩）

真实构建源`701364102983dee19be840be0c54e4d12a06c66a`，包含PR75节点页、PR77菜单/结果页、PR79战斗反馈及先前牌库/AI/固定药水槽位。完整`npm run check`通过：JS297通过/14个既有权限skip，Lua全套、Python15通过/1个既有skip。

首次从a76cab4构建被平台拒绝：17个节点遮罩直接传八位RGBA。统一转换为RGB+独立opacity后从零真实构建成功；失败与成功输出分别在仓库根`.artifacts/offline-ui-a76cab4/build.log`、`.artifacts/offline-ui-7013641/`。

- 实际gil内24模块逐份对照源文，静态0错误/16个自定义跨模块方法warning；新增`holding`已追到`abyss_node_ui`定义。
- 实际UI1552控件，最大50直接子；六列牌库模板和22节点启用结算图均真读回，ABYSS_WIN/LOSE监听引用存在。
- 17个节点遮罩实际读回等价RGB`#0f1117`+0.8透明度，无重复乘alpha；源主题颜色未改。
- 独立内存重注入得到相同字节；正式底图SHA256前后保持`6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`，liveWrite=0。
- 交接副本：`.artifacts/offline-ui-7013641/abyss-ui-offline.gil`，SHA256 `60ca982ef78f3e095b1c572f2f414bc5e32e8cd0a26e10eea8a323d328c43517`。结构化记录见[新版UI候选证据](evidence/offline-candidate-7013641.json)。

没有启动原神、调用playtest、官方导入或发布。节点hover/pressed/按下缩放仍有P2缺口；原生字体/图库/滚动和多设备仍待实机。TASK2物理配置、Boss17宝箱/完整第一幕/胜利正式结算等规则与平台关口保留，不能用这个构建关闭。

## 本批集成候选（022f22c，未导入/试玩）

真实构建源为`022f22cf600de140527acb32774c997ea2be17d4`（PR78固定提交，包含Guardian、Cultist、牌库、叙事和药水固定槽位）。PR78已squash进develop `fac093cffb0403b3ab1ffc5479bd61011a95232b`，独立`git diff`确认两者`src/data/scripts`完全相同；中间PR70只新增两份回归。保留实际构建SHA，不用squash提交号替代。完整`npm run check`退出0，JS284通过/14个既有Windows权限skip，Lua全套通过，Python15通过/1个既有skip；各PR的当前SHA Quality和独立复审另按PR记录。

- 实际写入副本的24模块静态检查0错误、15条跨模块方法warning，全部模块非空。
- 精确读回1220控件，最大50直接子，四主面板及牌库入口/遮罩面板存在；`abyss_ui`根绑定存在。
- `AbyssDeckCard`模板根索引1073741845，实际grid引用该模板且列数6。该编号只属于本候选，不能硬编码到运行时。
- 结算服务端图22节点，启用挂载到关卡实体；编译/副本写入完成，胜利正式结算未实测。
- 原底图SHA256构建前后均`6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`，liveWrite=0。
- 交接副本：仓库根`.artifacts/offline-integrated-022f22c/abyss-integrated-offline.gil`，SHA256 `a6d839d45753af0e536142bba7a3cd2322155dda38a67cbcc220bce7b6c8e114`；原始输出、模板/UI读回和校验位于同目录。

独立复核直接解析实际gil：24份模块源文逐份相等；重跑客户端检查并追溯15条warning的真实自定义方法定义；模板/网格/挂载与正式原件hash均核实。另在内存把本轮编译main.gia重注入构建器保存的原件，结果与实际候选逐字节一致，验证编译→写副本链。

结构化证据见[本批候选记录](evidence/offline-candidate-022f22c.json)。未调用playtest、未开原神、未写正式存档、未官方导入。本候选不补足TASK2物理场景/镜头出生、不实现Boss17宝箱事务，也不能替代TASK3.2/3/11.1/12.3或M3/M4实机AC。

## 上一离线候选（be5093f，未导入/试玩）

已合 PR63 的代码提交 `be5093f541724405154c4ee1c656fccc08e329e1` 经 `build:data`、`build:ui`、真实 MCP 副本写入与结算图编译完成。只读正式底图1073741825后复制到工作区；正式文件 SHA256 构建前后均为 `6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`。

- 客户端静态检查非空21模块：0错误、12警告。警告为跨模块控制器方法的静态识别限制，未据此宣称游戏运行无错误。
- 实际副本读回1178控件，最大50直接子；菜单/地图/战斗/节点面板及`abyss_ui`根脚本绑定存在。
- 服务端结算图真实编译写入：22节点、编辑计数72，启用挂载到关卡实体。编译/挂载不等于官方胜利结算实测。
- 候选 SHA256：`3e450284ff5b8096ea5836a1e12639ff702775e301788cf6e40b39e57e1ecb6a`。路径、完整检查列表及原始输出定位见 [结构化证据](evidence/offline-candidate-be5093f.json)，工作区 `.artifacts/m1-offline-be5093f/`。

**本轮官方导入：未执行；原神/沙箱试玩：未执行。** 物理场景/镜头出生等TASK-2、TASK-3.2导入与TASK-3实机仍分别保留，不能用本构建记录替代。以下各版历史现场证据继续保留，不能与这个新候选混用。

## 本轮实测记录（2026-10-23）

基线：远端 develop `77744e2`。完整候选包括18个Lua模块，以及菜单、地图、战斗、七类节点和奖励控件，原始底图为存档1073741825；所有构建输出都在工作区副本。

| 检查 | 实际结果 | 证据 |
|---|---|---|
| 完整客户端数据/UI构建 | 通过 | `.artifacts/p0/build.log` |
| 首次完整UI写入 | 失败：地图直接子控件超MCP每层60个限制 | `scene_add_client_ui-SlayTheAbyss.json` 首次失败记录；后续同名记录为修复后结果 |
| 分组修复后完整副本写入 | 通过，18模块，MCP静态检查0错误/9警告 | `.artifacts/p0/scene_check_client-result.json` |
| 自动打开候选 | 失败，14秒报无法切游戏前台，未进入编辑器 | `.artifacts/p0/open-status.json`，run `1dcd9bd1-4bd5-4ee7-b749-212faba58cbb` |
| 人工导入首版 | 通过，新增测试存档1073741828，名称abyss-p0-full-game | `.artifacts/p0/maps-after-import.json`；用户现场确认 |
| 首版菜单实际显示 | 部分显示，标题和启程可见，顶部透出其他面板文字；说明为空 | 用户截图留存 `.artifacts/p0/menu-broken.png` |
| 首版启程 | **失败**，点击无反应 | 用户现场反馈；正式日志确认abyss_map_ui:23初始化断言中断 |
| 第二版初始化修复 | 实机顶部串画面消失，启程仍无响应；新存档1073741829，代码已核对 | `.artifacts/p0/menu-v2-broken.png`、`official-v2-scripts.json`、`official-v2-ui.json` |
| 第三版无日志自诊断 | **实机通过诊断显示**，启动仍失败；直接显示SetImage参数数量错误 | `.artifacts/p0/menu-v3-diagnostic.png` |
| 第四版SetImage修复 | **实机菜单说明正常、可启程进入地图**；用户确认可以选路 | `.artifacts/p0/menu-v4-working.png` |
| 第四版实际战斗 | 主Agent截屏已见真实胜利及三张卡奖励，生命80/80、金币114、本场金币+15、牌组10 | `.artifacts/p0/first-battle-victory-v4.png` |
| 首战、奖励、回图、后续节点 | **功能实机通过**：用户确认出牌、敌人行动、领奖/跳过、商店离开后继续多战 | 胜利截图、卡组10→11截图及人工反馈 |
| 15层到Boss、失败摘要与重开 | **实机通过到达与失败分支**：15/15、0/80、金币4、卡组14、遗物4；重开正常回新局 | `.artifacts/p0/floor15-defeat-v4.png`及用户重开确认 |
| 第六版正式失败结算 | **实机通过**：第1层失败摘要点“结束并结算”，进入平台官方“失败”页，显示“离开/重新挑战” | `.artifacts/p0/defeat-result-v6.png`、`official-defeat-settlement-v6.png` |
| 原数值击败Boss及胜利正式结算 | **未测/未完成** | 失败结算通过不能代替Boss胜利分支 |
| 本轮完整客户端日志 | **缺失**，仍只找到06:29:31首版启动故障 | 不用旧日志冒充第四版完整运行 |

Color缺陷已用带静态方法的可调用对象复现：原地图控制器硬性要求 `type(Color)=="function"`，会在完整宿主绑定启程按钮前抛错。官方API提供 `Color.FromRGB/FromRGBA/ToRGBA`，应接受平台可调用对象。修复移除错误类型限制；并将非菜单面板初始隐藏，避免启动期间串画面。第二版运行仍需平台确认，不把本地修复当作实机已通过。

已归档正式日志 `.artifacts/p0/official-first-fault.gia` 和解析结果 `official-first-fault.json`。源文件 `2026-10-23_06-29-31_4_217122260.gia`，SHA256 `0fdaed600a95cd30a2842cb4f962488a09faf7508994552332d45f441e96fc83`，开局第1秒实际报错：

```text
abyss_map_ui:23: in function 'new': map UI needs client Color and imageSource
stack traceback:
    abyss_map_ui:23: in function 'new'
    abyss_game_ui:18: in function 'new'
    abyss_ui:11: in function 'OnStart'
```

第二版可人工导入文件：`F:\New folder\.artifacts\p0\abyss-p0-v2.gil`。
SHA256：`C2DC61791A6DA56C247A3FA660FD645A9A5ED2D516B47EAB8D98CED38CED7470`。

本地第二轮 `npm run check`：125项JS通过，6项跳过；Lua全部通过（地图UI含可调用Color回归15项）；13项Python测试，1项权限相关跳过。MCP静态警告是对项目自定义控制器方法的名称检查，不能据此确认运行正常。没有节点图编译结果，本版本使用客户端Lua；不写成write_graphs通过。

第四版完整检查为126项JS通过/6项跳过；Lua宿主6项、地图UI15项及其余全部通过；Python13项/1跳过。第四版文件 `F:\New folder\.artifacts\p0\abyss-p0-v4.gil`，SHA256 `CF3EF983BB210350E95241E3CA9521EE0B453B53FEE6335DE671E4BB4D06D5D5`。用户当前使用这一版继续真实流程，不因后续小文案修复重置这局。

实机文案缺陷：战斗标题仍写“战斗演练”。源码已改“杀戮深渊 · 战斗”，尚未进入第四版运行产物，下次候选统一纳入。

第五版针对用户指出的重大信息缺陷修复：单位名称、HP/MaxHP、格挡、状态和卡牌类型保留批准字体及中心位置，把过短原生文字框扩至主题 `nativeText.lineHeight=40`；意图只显示紧凑数值，点选敌人显示完整当前状态修正说明；商店恢复五卡一排和独立价格，但下排/删牌构图等差异继续留账。`npm run check`129项JS通过/6跳过、Lua战斗20项及其余全部通过、Python13项/1跳过。`.artifacts/p0/abyss-p0-v5.gil`，SHA256 `0472AA395B919F9197CCDD483033AB9E1FDD9FB51F3237DD65F0BDCA71A6BCFC`，**用户已实机确认生命数字与意图正常、受伤会更新；商店新版仍待实机验收**。

第三版现场暴露第二个启动缺陷：`bad argument count to 'SetImage' (3 expected, got 4)`。根因为Lua的 `assert(value, message)` 返回两个值，地图在原生方法最后一个参数中直接调用assert，将message也传入。修复为先取局部iconId再SetImage；地图、战斗与完整宿主测试替身均严格校验参数数量，已验证旧代码会失败，避免宽松替身再次漏报。

## 防重复失败机制

用户指出反复手动开启日志不可接受，保护落在项目脚本和测试层，不增加全局技能或修改正式存档。平台是否提供跨新存档永久订阅开关尚无证据，不能声称已改平台设置。

- 原生入口在保护范围内加载模块、初始化和更新。测试模式发生异常时直接显示原因并隐藏无响应按钮；第三版已实机验证，即使沙箱无日志也能取得错误。发布模式不显示技术细节。
- 构建脚本加 `--playtest` 会显式传 `clientScriptLog: true`，每次由已有MCP流程确保客户端订阅。脚本检查本轮订阅步骤、本轮目录内的新日志、`ABYSS_UI ready`和客户端异常；任一缺失都失败。Windows自动试玩仍受阻，**这条自动订阅路径尚未实机验收成功**。
- `native-playtest-evidence.test.mjs`覆盖未订阅、缺日志、过期日志、其他运行日志、无ready、运行故障及焦点失败；不得把旧日志拿来填补本轮缺失。
- 不再把重复手开日志作为用户每轮职责。自动化受阻时依靠界面诊断推进问题修复，保留日志缺失的真实状态。
- 用户指出这是整套实现与批准稿的偏差，不是孤立漏字。跨屏审计见 `docs/design/PLATFORM_PARITY.md`；`npm run verify:ui -- <候选.gil>` 要求逐屏批准稿、当前候选hash、实机截图、审查人与核心信息检查项。已用缺HP、缺截图、错版本和缺审查注入验证会拒绝验收；当前UI门禁确实失败，不能把源码修复或本地check当作UI验收完成。

## 可重复构建

在本分支工作树中先运行：

```powershell
npm ci --ignore-scripts
npm run build:data
npm run build:ui
$env:MILIASTRA_ALLOW_LIVE_WRITE='0'
$env:MILIASTRA_MCP_ROOT='D:/MiliastraTools/genshin-miliastra-mcp'
node scripts/build-native-candidate.mjs '<原始底图.gil>' '.artifacts/native-candidate'
# 自动导入/试玩时自动请求客户端日志，不需用户记住勾选：
node scripts/build-native-candidate.mjs '<原始底图.gil>' '.artifacts/native-candidate' --playtest
```

脚本先读取workflow/platform-rules，校验控件分组上限，把全部运行模块和同源生成模块写入候选，再写完整控件树并运行scene_check_client。`candidate.json`只声明写副本与静态检查，不声明官方导入或试玩成功。已经用实际MCP执行此脚本生成第二版。

## 历史单幕人工主流程与取证

以下15层流程保留原始口径；当前两幕 Production 执行上方清单，不以本节旧层数或旧通关记录替代。

1. 游戏“我的奇域”存档列表选择“导入存档”，选候选gil；确认新增独立测试存档，打开编辑器。不编辑原始底图或正式存档。
2. 自动入口负责客户端日志订阅及校验；人工回退直接试玩并保存画面，测试诊断不得依赖用户反复开日志。若本轮已采集日志，需要看到 `ABYSS_UI init Color=…`、`ABYSS_UI viewport_ready`、`ABYSS_UI ready`；没有本轮日志则记录缺失，不能借用旧日志补齐。
3. 菜单必须只有菜单信息；说明可见；点启程进入地图。记录候选hash、官方测试存档ID、窗口分辨率、截图及日志时间，避免混用卡牌实验。
4. 地图点可达白色节点，进入真实原数值战斗。记录战前生命、金币、卡组、遗物、药水；出攻击牌、出防御牌、至少一次结束回合，核对敌人行动及生命/格挡变化。
5. 取胜后领取金币、药水、卡牌；不能重复领取。回地图后核对资源变化及下一层解锁。此处通过才算最小闭环。
6. 从第1层使用原数值完成15层，逐层记录路径、节点类型、入/出生命、金币、卡组UID/升级、遗物、药水及截图/日志。途中覆盖营地回血/升级、商店购卡/遗物/删牌与拒绝交易、事件、宝箱、精英；一次路线未覆盖的节点另开一局补测，不能宣称单条路线覆盖所有分支。
7. 击败Boss，核对胜利摘要及结算；另开失败路线检查重开后资源和地图重置。任何Bug记录触发步骤、预期/实际、候选hash，修复后重新导入独立候选，先重跑最小闭环再做15层。
8. 每个项目只使用“通过 / 缺陷 / 未实现 / 观感问题 / 未测”之一；截图看不到不能直接归因为等级或平台限制。自动导入/焦点失败一次后转人工流程，不无限排查。

## 历史已知缺口（2026-10-23，非当前范围清单）

2026-10-23 离线结算补充（TASK-17）：客户端同局记录 `elapsedSeconds` 和胜场；结果摘要显示 `分:秒`、抵达层数、胜场、生命、金币、卡组及遗物数量。用时累计有效 `OnUpdate(dt)`，包含选路/节点/奖励与战斗操作；不包含启程前菜单或终局后的等待，战败规则生效后即停止（不额外计入失败动画）。这是客户端更新时长，不是服务端比赛计时；客户端暂停更新的时间不会计入。重新启程创建全新统计。真实平台布局、Boss胜利结算、正式重新挑战仍待验证，本补充不改变 v6 的历史证据。

- v6 正式失败结算已实机通过；Boss胜利、胜利正式结算和平台“重新挑战”的资源重置仍未测，复用 TASK-17。
- 当前商店可售卡池17张；37张数据表不代表37张可玩，30+卡池仍由TASK-16验收。
- 奖励专用弹窗、营地升级前后对比、批准稿商店货架、完整状态图标与动画/音效未完成；节点仍用过渡清单布局。
- 官方素材ID实际观感、卡牌长文字、跨层资源、七遗物/七药水、手机/主机布局均需真实试玩逐项取证。

本文件是执行规程及进行中的证据账本。**第四版功能最小冒烟、15层到Boss失败及重开已有实机证据；第五版生命/意图及受伤更新已获实机确认；完整胜利通关、日志采集、商店新版、Boss胜利及胜利正式结算尚未完成；第六版正式失败结算已实机通过，不恢复非必要并行开发。**
