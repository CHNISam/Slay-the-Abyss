---
id: TASK-74.20
title: 治理阻碍角色扩展的高风险复杂度
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-06 02:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-CORE-LIFECYCLE-20261106.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已合Host切片后仍存在最大CC75及67个CC超过30函数；现有任务未逐项界定Combat、Actor、MapUI及RelicHooks对内容迭代的风险。按真实职责治理，避免无限拆分或搬移指标。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前全函数含匿名及初始化块机器清单列出CC超过30、最长函数及超千行文件，并按调用链、变更频次和测试风险识别P0/P1
- [ ] #2 已确证P0/P1职责达到CC15或以完整行为对照及明确分层接口证明安全，所有新增helper计入硬门禁；旧新随机、回滚、别名和失败轨迹保持
- [ ] #3 首份机器清单审查后确定绝对出口，公布最终分布与经Owner接受的残余范围；独立深审及实际合后Full通过
- [ ] #4 首批Actor.status/applyPower/addStatus/endTurn及Combat.damage/draw六职责和全部新增helper受CC15硬门禁；完整旧新状态别名随机事件返回错误轨迹相等，真实语义负控检出，首批完成不代表其余61热点已验收
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用固定Luacheck和完整AST清单，以dedb9ed5列高CC及长函数。2.按M8扩展调用链、变更频次和现有差分测试识别高风险职责，与依赖审查交叉核对。3.首份机器清单确定绝对出口后治理具名职责，全部helper计入原门禁，行为对照和独立深审后完整交付。

4.首批落实Actor.status/applyPower/addStatus/endTurn及Combat.damage/draw六职责，先固定完整旧新轨迹，再按真实生命周期阶段拆分；六旧热点及全部新增helper/匿名回调/初始化块CC≤15，其他源码不变时>30为67→61。其余热点保持待分级，不视为已接受残余。

5.首轮同模块提取令Actor增至1039行，提交前继续提取无外部依赖的Power校验与堆叠规则叶模块；Actor保留状态提交及动态公开接口。Actor/叶模块1000行硬门禁与叶反向依赖门禁先红后绿，来源升级四源精确epoch并保留旧布局/新鲜读取合同。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮固定Luacheck及完整AST复采328模块/5283测量：CC>15为258、CC>30为67、最大75、最长580，Combat2240行。正按真实状态owner及近期变更频率整理有限P0/P1治理出口；未实施重构，不勾AC。

完整审计附件已落盘并引用328源码摘要、67高CC与39长函数机器清单。首批六职责属于核心状态/Power及伤害抽牌协调，先于MapUI/RelicHooks/Feedback后续批次；尚未实施，无AC勾选。

六入口与纯Power叶模块本地验证完成：Actor996行、leaf62行；329模块5314完整测量、CC>30为67→61、CC>15为258→252。旧新差分、函数/错误别名、6+4真实语义变异、相关回归、四源桥51专项及原raw预算通过。独立c48b6a35深审PASS；组合接续本人PR521，当前Full/实际合后未验，所有AC仍不勾，余项风险未接受。
<!-- SECTION:NOTES:END -->
