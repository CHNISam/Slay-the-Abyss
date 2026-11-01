---
id: TASK-8.5
title: M1 纠正最终格挡未封顶999
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 23:34'
updated_date: '2026-10-22 23:42'
labels: []
milestone: m-2
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L412-L438
  - >-
    https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/core/AbstractCreature.java#L507-L508
documentation:
  - docs/reviews/TASK-8.5-block-cap.md
parent_task_id: TASK-8
type: bug
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户要求沿用初代STS数值规则而非新创平衡。两份标注V2.3.4的非官方反编译镜像均显示Actor最终格挡上限999；旧测试将大整数运算保护错误扩展成无限最终状态。仅纠正最终写入，保留计算精度及PR48荆棘修复。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 玩家和敌人普通及fixed增挡最终不超过999，modifier取整顺序与blockAmount大整数精度不变。
- [x] #2 验证真实出牌、敌人意图及库存fixed入口均经Actor，无新增直接增挡旁路；壁垒及荆棘不回退。
- [x] #3 记录可核验来源与非官方认证限制、红绿及本地回归；不宣称平台导入或实机通过。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先纠正stress最终状态断言并新增边界及合法入口用例看红；再只在Actor.block写入处取min(999,原浮点累加)；回归本地套件并交父级独立审查和正式CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot；基线develop 1eaba2c；独立目录slay-block-cap-fix-20261023。已查重任务和开放PR，999无现有修复任务；不碰平台/UI共享文件、PR46工具或PR37候选。父级已核对最小设计。

红绿：旧Actor下5个状态组失败，库存原版药水988+12溢出999失败。最小最终封顶后状态35与库存11绿。当前1eaba2c完整系统Lua11文件175组通过，已含原子14；Python13绿；syntax/data/build:data/build:ui/build:theme/diff-check绿。真实npm run check退出1，JS132/139通过，7项缺Fengari依赖；未声称正式CI通过。来源及生产路径审计详见docs/reviews/TASK-8.5-block-cap.md。保持In Progress/AC待独立审查，父级处理CI和集成。

独立评审通过：复跑状态35/库存11；独立矩阵1622字段断言全绿，原基线负对照预期999实1190失败，三个代码/测试文件hash一致。报告slay-block-cap-review-20261023/REPORT.md。AC按已核验本地证据勾选，仍In Progress等待正式Fengari CI与集成。父级在最新develop b4c552cf迁移本任务5文件，保留PR46工具保护和他人成果。

真实集成收尾：PR50已合并develop，merge 7fee95e12e14537271e20324ef3e61bfdd734aeb，已审查head 7d9d185。正式Quality CI39873188503两项success，JS179通过/0失败/14个文件软链权限跳过，状态35/库存11通过（父级核实）。保留全部AC与历史，不把CI当平台实机验收。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
恢复最终格挡999上限，保留modifier精度、合法生产入口与PR48荆棘。红绿、独立1622字段断言和正式CI通过，PR50已真实合并7fee95e12e14537271e20324ef3e61bfdd734aeb。平台/实机验收不在此任务范围。
<!-- SECTION:FINAL_SUMMARY:END -->
