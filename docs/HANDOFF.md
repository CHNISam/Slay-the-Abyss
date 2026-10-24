# 交接说明

2026-10-24首发交付审计：TASK-49补齐正式装配、导入及实机责任，见[交付闭环](DELIVERY-CLOSEOUT.md)与[逐任务快照](evidence/delivery-task-audit-20261024.json)。25负责正式卡面/肖像/共享资产装配，25.2单样本、10.1.2实际容量；2.1导入景片交4.2验显示；34负责正式开启BGM候选；29/29.1负责真实演出与音效证据。2D背景方案单列待审，不把3D景片当插画。10.5.1已归M1并复用PR165同源真实详情截图收口，现M1为14/14 Done；M1归档保留、主冲刺转M2。15.14/15.15按PR164最新Done保留。运行 `npm run verify:backlog` 检查首发排期/责任，不能代替平台实机。本轮星陨剑尝试在前台切换前失败，无截图/日志；最终BGM候选已从包含PR165短按修复的3bd3afa完整源重建，40模块/UI/双true参数/图身份独立读回通过，路径和hash见[平台记录](evidence/delivery-platform-20261024.json)。仍未官方导入/试听，不当当前RC；源码或资产推进后须重新统一构建。

2026-10-24集中收口：M1的13项必要任务已全部Done，milestone m-2已通过CLI归档；最终集成与清理见本轮PR。TASK-2按用户本轮确认完成，TASK-3/3.2保留5165a78真实战斗领奖回图证据。官方1841/01dd副本的660秒实机取得837条新日志及独立截图复核，九状态、确定数值、意图说明和原格挡徽标问题完成验收。用户明确正常飞牌短暂遮盖不视作bug，不得扩成M1阻塞；额外层级优化已撤出，保留恢复历史，不再补跑1842。M1证据固定源c0f2076；随后develop已并行合入PR164酸液分裂和PR166背景登记，本轮已同步最新，但不把旧截图当作这些后续更改的实测。物理手机、整体UI品质和第一幕完整通关仍按后续关口处理。根旧改动及57条历史分支已归档核验后清理，独立工程与在途商店保留。详见[M1集中收口](M1-CLOSEOUT-20261024.md)。

任务首页使用日常中文，技术要求和旧记录查docs/backlog-details/；M0已归档。

2026-10-24路线图已重构：当前排期以[MILESTONES.md](MILESTONES.md)为准，历史交接中的M3通关/M4候选/M5投稿编号仅作历史。现在M2通关、M3首发内容齐备、M4正式品质、M5 RC冻结、M6人工投稿；最早未完成仍为M1。TASK-17/17.3负责M2闭环与实机，17.2负责M3 Boss规则，12.5负责严格节点平台验收。

2026-10-24路线图已重构：当前排期以[MILESTONES.md](MILESTONES.md)为准，历史交接中的M3通关/M4候选/M5投稿编号仅作历史。现在M2通关、M3首发内容齐备、M4正式品质、M5 RC冻结、M6人工投稿；最早未完成仍为M1。TASK-17/17.3负责M2闭环与实机，17.2负责M3 Boss规则，12.5负责严格节点平台验收。

2026-10-24 用户确认游戏正式更名为 **《杀戮原塔2》**。当前源码菜单/战斗标题、界面原型与发布文案采用新名；历史存档名称、截图及证据保留原样。此次更名尚未重新构建候选、官方导入或实机验证。玩法对标和首发范围仍按 SCOPE.md。

2026-10-24未知事件P0：TASK-13.1.1按用户批准交付六事件受限池与真实问号四类路由，范围、耗尽限制、来源和剩余P0 TASK-13.1.2见 [UNKNOWN_EVENTS_P0.md](UNKNOWN_EVENTS_P0.md)。不再以固定Purifier作为当前正常入口；本切片不关闭M1或TASK-12.3实机门禁，最终源码/候选证据以该专项记录和PR为准。

该切片已同步develop的PR121/122/124，游戏冻结源ba1c2fa、验证头02fa504（仅复用PR125的测试断言修复），新副本在根`.artifacts/unknown-events-p0-ba1c2fa/abyss-unknown-events-ba1c2fa.gil`。独立读回35模块/1695控件/max51/22节点完整结算载荷，静态0error16warning；组合完整check通过（JS637pass118skip、Lua92文件、Python16pass1skip）。旧96b80a7仅为首次切片历史。新副本未官方导入或实机；下文M1真实记录属于它自己的5165a78候选，不能混用。最终合并状态见PR123。
**2026-10-24当前实机结果**：固定源5165a78（PR109合入develop95ce2bd）的统一候选已官方导入为测试存档1073741838，真实完成一场战斗、胜利奖励选牌回图及商店/牌库访问。TASK3.2导入切片Done；TASK3三项最小实战AC有16图/64条新打印独立复核，仍等待九状态等必要关口。短run8f623503确认菜单取消及主动结束进入官方结算；900秒run9bb0abe3的到时中断不作退出成功证据。[当前完整报告](M1-LIVE-ACCEPTANCE.md)、[结构化证据](evidence/m1-live-5165a78.json)。

当前文件为根`.artifacts/m1-handoff-5165a78/abyss-m1-5165a78.gil`，SHA256 `8ff910c6772c729cf86cf26dd9d48f73c2de4ccffdf5fbc1b0029d9286f54288`。32内嵌/32外部Lua、1695控件和场景配置已官方读回匹配；官方重序列化的全图payload未认证。真实复苏、完整九状态、手机触控及正式UI总门禁仍缺，M1未整体完成。原神/沙箱为管理员权限，测试宿主必须同级；本轮已实证普通权限inputSent无页面变化、同级权限同Q操作成功。勿再反复让用户置前替代权限核对。

以下为保留的历史交接，不代表当前候选仍未导入：

> 2026-10-23 分支整合：PR109汇总规则、M1退出/构建、节点触摸、格挡动画、地图可读性与规则文档（来源PR51/116/118/119/120）。下列614、b76等文件均为各自冻结源的历史候选；最终组合尚未重新构建、官方导入或实机验收，不应将旧副本当作本次合并后的游戏。

2026-10-23 M1并行收口的新证据见 [M1-CLOSEOUT.md](M1-CLOSEOUT.md)：演出异常恢复TASK29.2、药水TASK41、回合/跳过奖励动作TASK43三项离线任务已独立复核Done。统一候选固定源b76b6cc（PR114分页/任务编号+PR118节点归属+主动退出），交付在根`.artifacts/m1-handoff-b76b6cc/`；30模块逐byte同源、1664控件、22节点完整载荷及23项场景/清单断言通过，0静态error/17既有warning。跨退出层误购已先红后绿修正，失败候选保留。614本轮日志已归档（345打印、4胜1败），旧文“缺新日志”只属历史。新候选未官方导入/实机/UI门禁；九状态、正确场景配置及同候选完整动作取证仍缺，M1不整体关闭。

历史候选记录（不代表本次组合候选）：

**用户最新要求：2026-10-23已可登录原神测试，停止扩张任务，收敛并交接。** 当前测试入口见[PLAYTEST_HANDOFF](PLAYTEST_HANDOFF.md)：根`.artifacts/handoff-20261023-61425e4/abyss-playtest-61425e4.gil`，固定源61425e4。完整检查JS595pass/116skip、全部Lua、Python16pass/1skip；32模块逐byte/1590树/max50/22节点结算图与完整载荷核对通过，static0error17warning，未官方导入/实机。原地图交叉修复1cf与拓扑候选1365只冻结交接，未加入此副本；SpikeM/Slimed未实施，不继续扩展。

第二批[PR102](https://github.com/CHNISam/Slay-the-Abyss/pull/102)已在head`0c3fd84`的两个[Quality作业](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39932782189)成功后squash合入`6014746`。合并时同时保留独立PR101的五份真实出牌/合法路线诊断文件；`src/data/scripts`与PR102 head已核对相同。后续离线集成在`.worktrees/continued-status`，不覆盖根旧develop。PR102及其三个已合源分支的干净工作树已清理，完整Git bundle和最终本地/构建日志先归档至根`.artifacts/continued-pr102-source-history`；含未提交证据的旧BGM树继续保留。

最新第二批普通副本固定源`11b901f`，已含Acid/Spike小软泥、Fat/Sneaky抽样及反伤致死后已排队选招/减益修正；[证据](evidence/offline-candidate-11b901f.json)。30模块逐byte同源，1590树控件/max50、六列模板、22节点启用结算图，BGM双参数false，静态0error/17warning。真实构建先抓到普通manifest漏注册BGM参数，已修并新目录重建，失败保留。完整规则源`d3e9d76`全量check exit0（JS643/528pass115skip、全部Lua、Python15pass1skip），参数/审计增量专项15过；最终head CI另见PR。Dazed/Sentry/Artifact在下一批，未计入此副本；未导入/开游戏/试听，严格关口仍未完成。下文139/cf候选作为历史证据保留，均不含第二批修正。

本轮继续离线推进：PR99（`1182814`）与PR100（`14979df`）均在各自当前head的两个Quality作业全绿后squash合入develop。PR100包含固定第9行地图宝箱、Nob/Blue Slaver A0选招、Weak/Frail/Vulnerable共享轮末及六件开战遗物顺序；各项严格/平台AC仍未勾。地图golden仍FAIL 0/12，原版RNG/拓扑/完整队列与Boss17宝箱事务继续保留，不能把已修某个缺口写成整项一致。

最新规则副本源`139de94`，28模块、1590树节点/max50、六列牌库及22节点启用结算图；[证据](evidence/offline-candidate-139de94.json)。另有显式开启BGM的试听副本源`cf6969e`（与合入`14979df`源码树相同）：29模块、22+83节点两图启用，参数实为true；[证据](evidence/offline-bgm-candidate-cf6969e.json)。两者真实MCP静态均0错误/17警告，独立读回匹配固定源，输入底图hash不变。路径/hash及分层状态见[P0-SMOKE](P0-SMOKE.md)。未开原神、未官方导入/实机/试听；普通构建仍默认关闭BGM。下一批Acid S、浮点包装候选和后续队列修正仍在独立分支，不计入这两个副本。

上一批源`085f499`的首次点牌修复与26模块副本保留为历史证据，见[P0-SMOKE](P0-SMOKE.md)和[历史证据](evidence/offline-candidate-085f499.json)。宿主15+6共21组与默认15秒预算保持；根旧develop及原有未提交内容不覆盖。

本批离线交付补充：PR66已关闭TASK3.1构建切片；PR69守护者排队转形、PR73祈火徒仪式、PR71原生只读牌库均已合入develop，PR67保护原本正确的IronWave顺序。最新整批副本的实际构建源为PR78固定提交022f22c，含24模块/1220控件/六列牌库模板/22节点结算图，静态0错误；文件与hash见[P0-SMOKE.md](P0-SMOKE.md)和[结构化证据](evidence/offline-candidate-022f22c.json)。源SHA与squash合入SHA分别保留，不冒充官方导入或实机通过。后续继续从最新origin/develop领取可离线任务，不在根旧工作树覆盖他人改动。

更新：2026-10-23。最新状态与逐关口验收标准见 [MILESTONES.md](MILESTONES.md)。这是当前交接，早期快照已被本轮审计取代；历史可从 Git 查阅。

- **M0已完成**（TASK-1/7/22全部Done）。仅初步定位发布入口；正式表单/赛事资格在M5 TASK-18/19，投稿在M6 TASK-6。
- **M1实机关口仍未完成；离线开发继续并行。** 用户2026-10-23明确暂不开原神，并要求已复审、当前SHA Quality全绿的可合并代码直接合入develop，然后继续领取下一批Backlog，不把全部离线开发挂在Draft等待实机。实机/原版一致性AC按证据独立保留，不因合并代码自动完成；发布仍由人执行。
- 当前最高优先级为 P0 真实主流程回归，复用 TASK-3/5/17。完整UI的60直接子控件限制、Color初始化和SetImage参数错误均已修复；v4已实机到15层Boss失败并重开，v5生命/意图修复、v6失败正式结算已实机确认。不要按早期失败快照重复排查已解决问题，也不要将CI当实机。
- 尚缺 Boss 胜利及胜利正式结算、本轮新客户端日志、九状态及跨层资源逐项实机账本。TASK-2配置核验和其他未完成关口保留；完整记录见 [P0-SMOKE.md](P0-SMOKE.md)，早期平台记录保留为历史证据。
- M2本地地图/七节点/库存TASK-12/13/14已Done，平台部分在TASK-12.3。M1关闭之后才转M2主冲刺；不依赖Lv4退出续玩。
- PR37已合并b1018b1：本地支持30张基本/升级牌（3基础+27奖励/商店），93组全池行为回归；原版逐项来源/算法与30牌平台验收未完成。PR57结算用时/胜场、PR60原生拖牌接线也已合并；拖放鼠标/手机及Boss胜利正式结算仍待实机。37条JSON不等于37张可玩。
- M4集中美术UI、音画和多设备；M5集中同一RC完整复验、实际表单与物料；M6负责成功投稿和版本归档。TASK-21投稿后研究及TASK-26跨区发行不阻塞首投。
- 已批准美术依据仍是PR19 / 91ae349，读docs/design/UI_DESIGN.md并复用共享ui_theme。必要平台差异需留证据，C档点选保留。
- 用户确认奇匠Lv2、实名认证/收益已开通。等级达标不等于文字已经实测。原神/沙箱/MCP路径以 [TOOLCHAIN.md](TOOLCHAIN.md) 为准；先读workflow/platform-rules，live write保持0，发布由人完成。
- 持续离线冲刺在`.worktrees/active-sprint`/`feat/active-offline-sprint`及各任务独立worktree；根develop较旧且有未提交任务、vendor及其他worktree，全部保留，不在根目录直接pull覆盖。开始新任务先fetch并从最新origin/develop隔离，不凭旧交接快照重复实现。
- 合并规则：PR当前SHA的Quality各项全绿后squash进develop。用户不要求分支保护，不将其作为未完成项。

## P0 实机冒烟进展

集成工作树 `.worktrees/p0-integration`，分支 `feat/p0-integration-smoke`。沿用 TASK-3、TASK-5、TASK-17；详情及证据见 `docs/P0-SMOKE.md`。v4 实际完成地图、战斗、奖励、商店离开，抵达第15层 Boss 后失败，重新启程正常。v5 用户已确认生命数字、意图及受伤更新正常。商店新版仍待实机验收。

第六版测试副本 `.artifacts/p0/abyss-p0-v6.gil` 已生成（产物位于仓库根目录），正式结算节点图已编译并写入；用户截图已确认失败后进入平台官方结算。Boss 胜利、完整资源账本及本轮新客户端日志仍缺证据；不能宣称完整通关通过。不要再要求用户手动反复勾选日志。保持 live write=0，不改正式存档、不发布。

早期里程碑审计的本地检查与CI记录仍见MILESTONES.md；P0合并后的最终检查以本PR当前SHA的Quality为准，当前实时状态以Backlog CLI与GitHub为准。

上手：先读AGENTS.md、SCOPE.md、TOOLCHAIN.md及MILESTONES.md，运行backlog instructions overview，再查任务。Backlog变更必须用CLI，不直接编辑其Markdown。
