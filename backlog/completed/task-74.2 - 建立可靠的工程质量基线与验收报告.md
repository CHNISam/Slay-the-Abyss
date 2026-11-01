---
id: TASK-74.2
title: 建立可靠的工程质量基线与验收报告
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-28 15:47'
updated_date: '2026-10-28 23:12'
labels: []
dependencies: []
references:
  - docs/ENGINEERING_QUALITY.md
parent_task_id: TASK-74
priority: medium
type: chore
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有工程检查缺少统一基线，长构造器与未治理热点容易被局部通过掩盖。先报告真实债务，重构验收后再逐项启用新硬门槛。只维护检测工具与必要规则，不重构生产玩法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 所有Lua模块的行数、函数跨度、复杂度、完整依赖环与静态告警变化均有可复核报告
- [x] #2 缺失或重复测量、基线口径不符和扫描遗漏能被检测并失败
- [x] #3 新增指标保持报告模式，已启用工程门禁及静态告警规则不削弱
- [x] #4 工具回归通过，固定基线与后续启用硬门槛的步骤有说明
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按用户批准方案1，详见docs/plans/2026-10-28-engineering-quality.md。仅修改质量检测工具、规则和必要回归；先报告真实基线，保留原门禁，新增数值门槛待重构证据齐备后另行启用。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地验收：76项工具/CI/交付合同回归全过、0失败0跳过；完整check:engineering通过，4个真实语义变异均被原断言杀死、2个原生UI合同通过。verify:backlog、check:network、check:syntax通过。真实缺失基线CLI非零且落盘failed，随后正常运行恢复reported。220模块、3369函数、3589/3589测量、73告警无增减；完整图76模块SCC/496内部调用点按report-only保留。src/lua和data相对1f260a71无diff。证据docs/evidence/engineering-quality-20261028.json；未执行GitHub完整跨平台Quality、官方导入或实机。本地工具切片可验收，不关闭TASK-74主任务或工程热点重构。免费委派沿用暂停，未探测或收费回退；Codex节省未知。

合并PR312首轮完整CI在Ubuntu4和Windows1真实失败，原始job日志均指向同一package.json历史回放哈希断言。本地先复现旧断言及新负例双红，再仅为本次新增命令及门禁接线增加精确逆变换；保留旧冻结哈希、黄金数据和未审查漂移拒绝。没有文件排除、白名单增加或玩法改动；新HEAD须重新独立审查和完整CI。

合并整合至develop48cb48ce，复用PR319已有5/5职业选择分组与旧完整哈希守卫，移除重复本地6/4分组。原1f观察快照不刷新；活动规则身份仅绑定主线已审查的Enum所有者迁移，完整逆名后配置hash仍等于原基线，无新增许可/忽略/排除。Codex执行：当前231模块、3710完整测量、60告警，相对初始精确坐标31增44减；完整本地工程门禁、64项工具/路由/交付回归通过，25项CI/分组合同通过。新HEAD仍须完整CI和合入复核；父任务不关闭。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
新增全量质量报告与冻结基线，复用现有AST、Luacheck及架构边；逐函数核对测量并报告模块/函数/依赖/告警增减。新增数值门槛保持报告模式；原门禁不变。76项回归、完整本地工程门禁及失败路径验证通过；跨平台CI/平台实测未执行。
<!-- SECTION:FINAL_SUMMARY:END -->
