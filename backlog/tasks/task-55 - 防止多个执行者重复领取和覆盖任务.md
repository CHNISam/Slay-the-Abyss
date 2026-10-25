---
id: TASK-55
title: 防止多个执行者重复领取和覆盖任务
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 02:00'
updated_date: '2026-10-25 06:16'
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
- [x] #4 真实双进程Git竞争及失败恢复测试通过，当前提交质量检查通过并合入develop。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保存最新远端、任务与工作树只读盘点。2. 先写真实bare remote双进程验收，再实现Node Git CAS、租约和generation。3. 接入受控命令、worktree和Git hooks，建立保守迁移隔离及adopt流程。4. 运行相关与串行质量检查，审查并通过当前SHA CI后合入，释放及清理本次工作树。

5. 修复已复现的TASK0映射与泛化隔离死锁：新增受控CAS reconciliation，按确认的HEAD/index/脏文件指纹保留旧记录，串行迁移指定执行者；源树只读、组外持有与未知记录不清除。先写真实Git失败回归，再实现、复审、当前SHA CI及受控合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor=codex-local-p0，远端generation=1；独立coord/task-claims已非强制推送并读回。14工作树/26个本地In Progress记录的快照已保留，38项旧工作隔离；外部会话未知，迁移paused。首批8组真实Git测试通过，扩展的接收端竞争屏障、真实push、远端SHA授权和中断回收正在复验。免费委派沿用TASK-51限额暂停，无恢复依据，本轮由Codex实施关键协议。

冻结实现14组真实bare remote/独立clone/Node进程回归全部通过（213887.8317ms，失败/跳过均0）；含强制receive-pack竞争屏障、真实提交/推送/PR授权、子会话独立receipt及开发中断网终止。相关语法、Backlog唯一编号/排期检查和diff whitespace通过。全量质量门禁等待现有CI结束后在本PR当前SHA运行；AC4未提前勾选。全局迁移仍paused、38项未知隔离未消除，任务继续记录剩余迁移责任，不宣称所有入口已经迁移完成。

补齐真实上游冲突合并：新增回归先失败，修复后与普通commit/push两组通过（48910.9305ms）；15组完整套件交当前SHA CI。已通过sync-base在真实本任务树保留双方交接并合入c05332b，只有本任务13个文件相对上游变化。基线40153191516在两个全量作业同时运行时card_help_release 30s超时；保留原失败，作业空闲后同fixture原预算隔离31项通过，13010ms。未改游戏或预算。

PR201旧2999bc8在40155852981中ownership/check/presentation全绿，包含15组真实Git测试。收口核对发现新子树会沿用旧控制树基线，补断言先失败后修正：新分支从已fetch的origin/develop创建，已有分支用其自己的fork point；子执行/普通worktree/冲突同步3组通过56138.1491ms。已为保留脏根目录提供Git公共元数据中的稳定入口。该修复必须重跑新SHA CI，旧绿灯不作为最终证据。

第二代协调者在独立feat/task55-m3-reconcile恢复原完整bootstrap范围，修复TASK0/通用目录隔离导致的M3迁移死锁。新增受控CAS reconciliation、真实来源指纹和指定主线程阶段串行，保留所有旧隔离及源树。23组真实Git回归已分批覆盖：整套前16组通过后因远端Schannel续租握手失败被门禁中止；剩余7组在保持证书校验的进程级OpenSSL传输下通过，138675ms。完整单次运行未冒称通过，交当前SHA CI。源码/测试SHA及失败→修复证据写入既有验证JSON。独立只读复审完成；语法、Backlog、whitespace通过。已快进同步develop66f3afb，75卡及双方HANDOFF均保留。业务六源树、warrior75、根dirty未动，尚未登记业务迁移或解除外部未知。AC4继续等待当前SHA完整CI与实际合并。

2026-10-25 实际收口：PR203最终头1b94ec5的Quality40163823617三个作业全绿，23组真实Git回归随完整检查执行；已受控squash合入develop518299c（05:30:55Z）。运行时hash与安装副本相符，协调租约已释放；本线程干净树/分支在核对merged head与可恢复bundle后清理，证据归档.artifacts/task55-pr203-1b94ec5。用户随后明确授权本轮M3共享13路径独占写入、旧M2/工程树只读；六源树保持冻结，已由指定主线程在最新develop新树串行adopt事件→药水→遗物→主集成。paused、原38记录及其余unknown保留，不声称全部外部会话已迁移。此前本地分批通过与远端中断记录保留。
<!-- SECTION:NOTES:END -->
