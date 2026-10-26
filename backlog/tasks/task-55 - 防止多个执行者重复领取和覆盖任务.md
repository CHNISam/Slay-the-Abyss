---
id: TASK-55
title: 防止多个执行者重复领取和覆盖任务
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 02:00'
updated_date: '2026-10-26 09:33'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 94000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
本地和远端会话缺少共同执行所有权，独立工作树不能阻止重复开发与覆盖。保持Backlog负责任务管理，增加可运行的远端互斥和失权门禁。细节见 docs/backlog-details/TASK-55.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 同任务、父子任务、相交路径及共享模块的有效认领互斥。
- [x] #2 会话隔离、续租、到期接管和旧令牌失效可用，远端失败时关闭受控操作。
- [x] #3 本地、远端和子执行入口接入校验，现有在途工作安全隔离并可认领迁移。
- [ ] #4 真实双进程Git竞争及失败恢复测试通过，当前提交质量检查通过并合入develop。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保存最新远端、任务与工作树只读盘点。2. 先写真实bare remote双进程验收，再实现Node Git CAS、租约和generation。3. 接入受控命令、worktree和Git hooks，建立保守迁移隔离及adopt流程。4. 运行相关与串行质量检查，审查并通过当前SHA CI后合入，释放及清理本次工作树。

5. 修复已复现的TASK0映射与泛化隔离死锁：新增受控CAS reconciliation，按确认的HEAD/index/脏文件指纹保留旧记录，串行迁移指定执行者；源树只读、组外持有与未知记录不清除。先写真实Git失败回归，再实现、复审、当前SHA CI及受控合并。

6. 修复新session接管空闲迁移组的协议缺口，核验旧精确HEAD与source指纹；统一集成时保留全部测试和可恢复历史。

本轮用户授权仅V4受控登记及TASK55临时恢复。增加精确文件/指定session/显式旧隔离重叠确认的admission；不开放全局迁移，不清除旧记录，不越过活跃claim。先真实Git红绿回归，再当前SHA CI、受控合并、登记并释放协调权。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor=codex-local-p0，远端generation=1；独立coord/task-claims已非强制推送并读回。14工作树/26个本地In Progress记录的快照已保留，38项旧工作隔离；外部会话未知，迁移paused。首批8组真实Git测试通过，扩展的接收端竞争屏障、真实push、远端SHA授权和中断回收正在复验。免费委派沿用TASK-51限额暂停，无恢复依据，本轮由Codex实施关键协议。

冻结实现14组真实bare remote/独立clone/Node进程回归全部通过（213887.8317ms，失败/跳过均0）；含强制receive-pack竞争屏障、真实提交/推送/PR授权、子会话独立receipt及开发中断网终止。相关语法、Backlog唯一编号/排期检查和diff whitespace通过。全量质量门禁等待现有CI结束后在本PR当前SHA运行；AC4未提前勾选。全局迁移仍paused、38项未知隔离未消除，任务继续记录剩余迁移责任，不宣称所有入口已经迁移完成。

补齐真实上游冲突合并：新增回归先失败，修复后与普通commit/push两组通过（48910.9305ms）；15组完整套件交当前SHA CI。已通过sync-base在真实本任务树保留双方交接并合入c05332b，只有本任务13个文件相对上游变化。基线40153191516在两个全量作业同时运行时card_help_release 30s超时；保留原失败，作业空闲后同fixture原预算隔离31项通过，13010ms。未改游戏或预算。

PR201旧2999bc8在40155852981中ownership/check/presentation全绿，包含15组真实Git测试。收口核对发现新子树会沿用旧控制树基线，补断言先失败后修正：新分支从已fetch的origin/develop创建，已有分支用其自己的fork point；子执行/普通worktree/冲突同步3组通过56138.1491ms。已为保留脏根目录提供Git公共元数据中的稳定入口。该修复必须重跑新SHA CI，旧绿灯不作为最终证据。

第二代协调者在独立feat/task55-m3-reconcile恢复原完整bootstrap范围，修复TASK0/通用目录隔离导致的M3迁移死锁。新增受控CAS reconciliation、真实来源指纹和指定主线程阶段串行，保留所有旧隔离及源树。23组真实Git回归已分批覆盖：整套前16组通过后因远端Schannel续租握手失败被门禁中止；剩余7组在保持证书校验的进程级OpenSSL传输下通过，138675ms。完整单次运行未冒称通过，交当前SHA CI。源码/测试SHA及失败→修复证据写入既有验证JSON。独立只读复审完成；语法、Backlog、whitespace通过。已快进同步develop66f3afb，75卡及双方HANDOFF均保留。业务六源树、warrior75、根dirty未动，尚未登记业务迁移或解除外部未知。AC4继续等待当前SHA完整CI与实际合并。

2026-10-25 实际收口：PR203最终头1b94ec5的Quality40163823617三个作业全绿，23组真实Git回归随完整检查执行；已受控squash合入develop518299c（05:30:55Z）。运行时hash与安装副本相符，协调租约已释放；本线程干净树/分支在核对merged head与可恢复bundle后清理，证据归档.artifacts/task55-pr203-1b94ec5。用户随后明确授权本轮M3共享13路径独占写入、旧M2/工程树只读；六源树保持冻结，已由指定主线程在最新develop新树串行adopt事件→药水→遗物→主集成。paused、原38记录及其余unknown保留，不声称全部外部会话已迁移。此前本地分批通过与远端中断记录保留。

2026-10-25 后续真实修复收口：PR204的c37e384完整Quality40169360644全绿，合入ac51e002，修复Git hook继承当前索引导致冻结来源误报；PR205的5715df8完整Quality40172058510三作业全绿（JS1245pass/119skip/0fail，284唯一Lua fixture），已合入20aff96403729f57cb41905709e67af75d876a01。仅停放组的空闲未完成阶段可增补有依据精确文件，旧阶段/来源/执行者/隔离保留；25个真实Git协议用例随完整CI执行。已原生增补178卡面回归及用户新要求的桌面输入规则两文档，不更改外部unknown或开放并行。两个已合并运行时安装相符，协调租约已释放回M3。

2026-10-25用户要求新会话统一集成并清理全部旧分支；原生迁移组仍绑定旧session，本轮补migration-transfer：仅协调者可交接paused空闲阶段，核对干净树及本地/远端精确HEAD，保留来源指纹、原claim、阶段、旧session审计与外部unknown。新增真实Git回归先红后绿；完整26组单次通过496617.6971ms，0fail/0skip。已原生将旧TASK47 generation28交至新UUID，重新adopt取得generation32；最终源码纳入现有PR206的统一当前SHA CI，不复用旧receipt。

统一集成补受控新session交接，并修复归档评审的两个真实到期缺口：初次续租完成后重新确认；短命原生续租辅助进程使本地截止不被远端Git阻塞。两例先红后绿，真实子进程超过10秒初始租约仍正常续租，以及真实断网终止通过；当前实现的四项定向回归全过。最终完整29组协议与全仓CI交统一PR206，不复用旧SHA绿灯。

V4用户明确授权有限登记及原13路径TASK55临时恢复。仅修改登记脚本、测试、执行权文档及记录。真实Git原30组全过，最终新增边界2组全过，执行未修改的45ba918旧runtime验证推送授权/擦标签降级被新门禁拒绝。旧隔离/paused/externalUnknown保持。当前SHA CI与合入另验，不计为原创玩法完成。

用户确认仓库已公开，已由GitHub元数据核验public；本轮把Quality/check改为GitHub官方windows-latest与pwsh，保留全部检查、当前SHA门禁和串行组。运行中的旧自托管作业与新配置生效分开记录。

本轮按用户授权恢复后继续推进V4有界登记与官方托管runner；旧关闭记录保留，本轮当前SHA CI和合并尚未完成。为承接自身文件与已释放的67夹具，在干净已发布精确HEAD作原子交接，新任务继承完整范围且旧receipt立即失权。

最终V4收口：66与68均在干净发布头释放。仅以原13路径新会话恢复协调者，为新69完整继承两源并加入已复现阻塞全量的watcher_flow原生Vigor兼容文件及回归登记精确范围。保留paused/unknown/外部PR；不引入跨幕与许可改动，不改冻结数值。
<!-- SECTION:NOTES:END -->
