---
id: TASK-10.8
title: 按原版区分行动意图和状态，并补齐解释
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-24 04:23'
updated_date: '2026-10-27 04:15'
labels: []
milestone: m-2
dependencies: []
documentation:
  - docs/backlog-details/TASK-10.8.md
parent_task_id: TASK-10
priority: medium
type: bug
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
敌人下一步行动与已生效状态容易混淆；现有说明标题被裁切。恢复批准稿的悬停、长按与点按说明。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 敌人头上表达下一步行动；已有状态显示在实际承受者身上。
- [x] #2 悬停、长按和点按能查看意图、状态及卡牌关键词，名称与层数可见。
- [x] #3 说明读取当前核心状态，不改变结算，不引入重复出牌或穿透操作。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
修复已复现的标题裁切和入口缺失，检查触摸归属与只读性；首领模式转换文案由用户调研，本轮不改。

整合81df9e1复合意图角标；保留59306e7的说明交互与非攻击数字语义，运行check:rules，重建候选并尝试新候选官方导入与中型酸液团/下颚虫截图取证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
现有说明标题裁切与悬停/长按入口已修；八组专项回归通过，完整检查进行中。平台实测仍待进行，首领文案由用户调研。

已将81df9e1整合为fc2c709；当前44c2296含原生cursorArea悬停崩溃修复及严格回归。保留59306e7的非攻击意图不显示层数、第三返回值badge、intentHit及播放缓存。UI专项52组通过，原生帮助/分裂专项重跑通过，JS927通过118跳过0失败，Python17项含1跳过。check:rules两次在acid_slime_l默认30秒处超时；独立诊断完整收集129文件，遗留split预览旧期望已修并专项通过，但未把诊断当默认检查成功。初版候选已官方导入1073741840并读回核对，实机暴露帮助热区interactable非法字段；修复版副本在根.artifacts/intent-compound/abyss-intent-compound-fixed.gil，静态检查无错误，尚未重新导入/取得下颚虫或中型酸液团角标截图。全UI验收门禁仍未通过，本任务保持In Progress。

2026-10-24统一诊断夹具覆盖中型酸液复合意图、下颚虫强化/防御角标、状态实际承担者与详情、真实生产注册回调的合成长按/悬停/点按与释放不穿透。只是离线回调和原生候选准备，不认证物理手机输入或本轮平台显示；前台切换阻塞保留。

2026-10-24官方1841/01dd真实run ced168e4的14阶段原生画面与新日志已独立审计。中型酸液意图显示攻击7及1黏滞；石颚下一行动力量3/格挡6，与其实际力量2、玩家虚弱2正确分开；长按/释放、关键词悬停、点按详情通过生产注册回调在原生userdata执行，标题名称层数完整。预览只读/RNG/释放不重复出牌断言通过，整个预览段唯一正常Strike匹配伤害6。明确使用合成事件，未认证手机物理触控；该边界留M4。证据docs/evidence/m1-live-20261024/reviews/preview-live-review.json。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
01dd副本实机确认行动意图、实际状态承担者和完整详情；原生生产回调的合成悬停/长按/点按只读通过，唯一正常出牌无穿透。物理手机和全UI品质仍单独未验收。
<!-- SECTION:FINAL_SUMMARY:END -->
