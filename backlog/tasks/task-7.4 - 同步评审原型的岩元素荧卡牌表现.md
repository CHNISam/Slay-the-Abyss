---
id: TASK-7.4
title: 同步评审原型的岩元素荧卡牌表现
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 16:37'
updated_date: '2026-10-22 17:03'
labels: []
dependencies: []
parent_task_id: TASK-7
priority: high
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
正式表现表已切换岩元素荧，但评审原型仍显示旧卡名，导致评审入口与正式内容不一致。只同步卡牌静态数据并防止再次漂移，不改布局或游戏逻辑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 原型37张卡牌的名称、费用及升级文案与正式渲染结果一致，ID、类型、稀有度不变
- [x] #2 标准库回归能检出卡名或数值漂移，现有Python与可独立执行的Node测试通过
- [x] #3 除按最新身份恢复TASK24标签外，CARDS以外页面字节不变；不新增外部依赖或改变原离线打开方式
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 对照正式renderer编写静态数据合同测试，记录旧版37名称失败。2. 同步CARDS名称，并按PR22已协调身份恢复TASK24/PR19引用，其他布局、主题、交互和数据字段不变。3. 复跑测试与变异负例，核对6文件范围，独立评审后正常PR/CI集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot / sync_geo_prototype_cards。隔离目录 slay-geo-prototype-sync-20261023；基线 f20cd90。只做静态数据合同验证，不代表浏览器、平台编译或实机通过。

本地验证：旧版静态合同测试失败37项；同步37个名称后 Python 12/12、Node数据测试48/48通过。费用漂移、重复ID、缺失ID三个变异负例均退出1；恢复后文件哈希已复核。ID、类型、稀有度、费用、基础与升级规则文案，以及CARDS以外页面字节均未变化。等待独立评审及PR/CI，任务保持In Progress；未运行浏览器/平台编译/游戏。

同时纠正父级PR24的过时身份说明：PR22已保留UI任务为TASK24、导出保护迁为TASK27。恢复UI正式TASK24引用并保留PR19交付链接，不撤销迁移、不改其他任务状态/依赖/AC，不触及批准布局与主题。

范围澄清：前述CARDS之外字节不变的本地验证指作者最初三文件候选。父级最终六文件候选另恢复了已说明的TASK24标签及相关引用；最新AC3明确该唯一页面标签例外，除此不改页面字节或新增依赖。

收尾核验（dot 独立评审）：PR #31 已合入 develop，merge=f832f286cf43199d643c2032542d2a6f33c6649a；head=6c765c7e178fc09fa40940ead57bcf455e03f75c。CI https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39817412506 completed/success，head 精确一致。独立复核远端六文件 Git blob 与已评审候选逐一相同；本轮重新运行 Python 12/12、Node 数据测试48/48。此前独立红绿：原HTML失败37项；名称、费用、重复ID、缺失ID、缺失声明五类变异均检出。AC1以真实renderer/源数据逐字段比较为证，AC2以红绿和变异为证，AC3以基线字节差异核对为证。未进行浏览器交互、平台编译、存档写入或游戏试玩，这些不属于本任务的静态数据同步交付；不可据此宣称UI或游戏验收通过。历史“等待PR/CI”记录已由本次实际合入证据取代。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已通过 PR #31 同步原型37张岩元素荧卡名并加入标准库数据合同回归；保留其余7字段及批准布局/主题/交互，仅恢复已说明的TASK24身份标签。独立静态评审、Python12/12、Node48/48与对应head的GitHub CI通过。交付：https://github.com/CHNISam/Slay-the-Abyss/pull/31 。浏览器及实机未验证，不属于本任务验收。
<!-- SECTION:FINAL_SUMMARY:END -->
