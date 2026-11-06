---
id: TASK-75.3
title: 限制POSIX矩阵并发以减少完整检查排队
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 22:58'
updated_date: '2026-11-06 03:55'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
真实原生队列Full为33分05秒，实际develop推送30分03秒；13Windows与9POSIX同时竞争执行位置。六组已记录向量支持保留所有分片并限制POSIX同时6项的候选，模型不替代当前托管观测。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 保留全部当前Full作业和文件、原预算权重安全边界权限及交付协议；此并发切片仅限制POSIX最多同时6项，原13Windows与9POSIX基线及75.5后继扩容分别取证
- [x] #2 历史工作流仅逆投影精确批准的并发设置，原完整SHA与合同不刷新；错误值、位置、重复与其他门禁漂移仍拒绝
- [ ] #3 独立复审、精确候选来源和原生队列及实际推送Full通过，记录真实总时长排队与runner成本及目标差距，原交付验证器合后通过
- [ ] #4 PR525当前12并发候选保留全部16Windows与12POSIX工作量及原门禁，精确PR、队列与合后Full通过；真实墙钟、排队、失败重跑与runner成本支持保留或回退，不以单次通过宣称稳定提速
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.固定六组真实Full向量、cap6探索与Fast自然样本未知边界。2.只增加POSIX strategy max-parallel=6，保留13/9矩阵及全部原门禁。3.在原历史投影公共入口增加精确唯一批准逆投影，错误值位置重复与无关漂移负例。4.独立复审、真实新候选来源/原生队列/实际推送Full，原交付验证器及真实时长对比。

2026-11-06 Owner指定PR525接续：保持cap6历史和原验收不改，以当前16Windows/12POSIX候选实测max-parallel12；保留全部文件、原预算与Full33身份，补齐物理合同漏接，再独审及精确PR/队列/push Full，按原始排队和执行成本判断保留或回退。

本轮Full42155141007的Windows2在原30秒上限超时：joust_event六组仅完成前五组；该文件既有安全权重19.118秒、placement24.503秒，已属长用例独占，不能伪称短池并发问题。保持原种子/每组全部断言，以既有注册器方式将六组分为两个原30秒入口，完整原文/hash及执行编号并集保护；独审后用新HEAD完整验证，不加超时或伪造计时。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
仅POSIX max-parallel6已实现，原13/9矩阵和27作业及原预算/权重/权限/协议保持；15专项、40交付合同及独审14探针通过，旧完整SHA不变。模型仍非托管收益，新来源/原生队列/实际推送Full待，AC3不勾。

首轮真实Full与16条完整Host成本校准后，13槽即使理想均分也超过原30分钟含启动预算，不能靠cap6或重排解决。保留本任务cap6独立切片与全部原门槛；75.5按14槽单独实施和验收，不能把组合候选描述为仅有并发变化，AC3仍待。

PR525独审接续：固定Node24.18.0的8文件51合同通过；另查出现有ci-windows-shape-expansion仍硬编码cap6，真实3项中1失败，正在仅更新批准物理cap断言，原历史shape/hash/预算断言保留。当前Full仍排队，新增验收保持未勾。

漏接已按精确物理cap12修复，原历史形状与SHA断言保持；该文件从2通过1失败转为3通过0失败，连同前述51项为54项通过且0跳过。首次Node22两原生分片探针不支持参数及缺ESM依赖的环境失败已保留，改用现有固定Node24和本树锁文件依赖后通过；不改测试以兼容错误环境。

当前525自动合并已通过原入口暂停并读回autoMergeRequest=null。失败原始job127688135188日志已取证：joust_event.lua ETIMEDOUT 30037ms，前五组PASS、第六组尚未完成；其余Full继续收集失败，不将当前候选宣称通过。

Joust已按原文保真拆为1–2/3–6两入口，git原5275字节SHA256及原六组有序正文锁定，实际编号并集1..6恰好一次。主控固定Node24独验Joust/完整校准/Host校准11项通过0跳过，两VM16602/4855ms仍各30秒。新增raw仅显式列为未测，原1356文件/2712观测和timings不改；当前1357入口完整调度及原预算通过。独审session ses_e512f4c4fffeuyyAQjNkbjkNNI复核源身份、状态隔离及8负控通过，新候选托管Full待，AC不勾。
<!-- SECTION:NOTES:END -->
