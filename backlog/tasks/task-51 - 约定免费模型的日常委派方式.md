---
id: TASK-51
title: 约定免费模型的日常委派方式
status: Done
assignee:
  - '@codex'
created_date: '2026-10-24 09:15'
updated_date: '2026-10-27 04:15'
labels: []
dependencies: []
documentation:
  - docs/backlog-details/TASK-51.md
modified_files:
  - AGENTS.md
  - docs/backlog-details/TASK-51.md
  - docs/backlog-details/TASK-51-REPORT.md
priority: medium
type: docs
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户希望把本轮验证过的免费模型委派方式作为日常默认分工，以减少Codex额度消耗，同时保留可靠验收和费用边界。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实文档任务由免费DeepSeek完成并经Codex复核
- [x] #2 项目规则包含分工、免费锁定、失败处理和验收要求
- [x] #3 保留已有修改，不新增调度框架或全局配置
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 验收本轮CLI真实工具记录和文档报告。2. 在AGENTS.md加入简短默认分工与调用边界，附最小证据。3. 检查Diff与规则文件，通过现有PR流程交付。

2026-10-24额度反馈修订：只读聚合本地当天用量，区分限额反馈和无事件未知原因；调整仓库委派策略与附件，保留断网TASK-53，通过校验和当前SHA CI后PR合入develop。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DeepSeek普通原生CLI + Max成功：1次bash、4次read均completed，完整报告核心发现经Codex对照工具快照复核，退出0，3个step_finish费用合计0。带pure调用403；Flint免费路径工具读取成功但length终止无报告，未验收通过。根CLAUDE哈希/原tracked diff保留，并发文档更新按实际read快照核查。规则检查exit0（通用英文检查器未识别中文保留改动规则而警告），git diff --check及报告链接检查通过。

按用户追加要求明确默认最高推理档位（当前Max），长任务分成短步骤逐段验证和交接；关键设计与高风险逻辑留给Codex。

后续按用户要求提炼用户级opencode-delegation skill并推送agent-skills PR7；独立并发编辑未通过（路径拒绝后重试无事件），地图代码首段超过5分钟无事件/改动，停止并交Codex实现。实际净节省未测且本轮协调成本上升，规则加入90秒无事件停止与质量/耗时/返工记录，默认先串行。

2026-10-24用户反馈亲自试用发现限额，日限或五小时窗口未明；明确将Backlog CLI查重、建任务和补备注列为可委派杂活。本轮只读审计当天本地记录：DeepSeek合计470876记录token，含344064缓存读取、34253推理；真实工具13完成/21错误。另一次Backlog试跑117.6秒零事件后由Codex接管TASK-53；不能确定其原因就是限额。已更新AGENTS及附件：限额后暂停受限路径，不猜重置、不轮询；恢复依据出现才用一个真实短任务验证，短批次合并Backlog操作、先修权限错误，极小机械操作可直接处理，保留Max与免费锁定。明细、口径及边界见docs/backlog-details/TASK-51.md和docs/evidence/opencode-usage-20261024.json。没有模型新请求或收费回退，净节省未知。

按用户要求学习现有实现：核对OpenCode v1.18.24官方固定提交57e8055的stats/retry/run源码，采用原生stats、错误分类及Retry-After/有界退避，不新增额度管理或外层重试。确认JSON不透出retry状态，零事件原因继续未知；Flint记录total与分项相差282，保留原值不混算。源码链接和实际原生stats交叉核对已加入附件。

2026-10-24用户明确将Backlog查重、建任务、补备注作为可优先委派的杂活。本轮真实尝试让OpenCode免费DeepSeek Max通过原生CLI登记断网丢进度：当次目录输入/输出/缓存价格均0，进程级锁定主/辅助模型与Provider，经debug config核对；仅授权相关Backlog命令，未加pure。超过90秒无输出或工具事件，停止匹配本次命令行的进程后，Codex通过CLI接管并创建TASK-53，读回核对通过。没有可验收委派产出、没有实际工具调用和step_finish费用事件，不能声称本次模型费用实测为0或已节省Codex额度；节省未知。本地事件、脱敏配置、起止时间及复核结果在.artifacts/opencode-backlog-disconnect/。本次失败属于调用无事件推进，尚不能判断模型执行Backlog的能力；不回退收费模型。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已完成免费DeepSeek真实文档委派和Codex验收，并将默认分工、进程级免费锁定、失败接管和真实工具验收写入AGENTS.md；调用说明与原始报告放附件。没有新增框架或改全局配置。
<!-- SECTION:FINAL_SUMMARY:END -->
