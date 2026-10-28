---
id: TASK-79
title: 修复紧急合并后的真实检查失败
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 11:33'
updated_date: '2026-10-28 13:38'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-79.md
priority: high
type: bug
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
紧急合并后的develop完整检查出现跨平台UI集成失败；逐项核对真实日志，修正功能回归和合法设计变动后的测试合同，保留原预算及历史证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前develop相关失败逐项记录根因和修复映射
- [ ] #2 完整Windows与Linux检查保持全部有效测试和原超时并通过
- [ ] #3 修复精确PR头完整检查通过并由S0审查；合入后最终复验由S0负责
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先读全部失败日志并复现；分别修共享mock、合法UI合同与历史逆投影；验证定向负例和工程门禁；提交独立PR、等待完整CI并交S0验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已固定最新7a87de3a完整失败日志并分类：真实Boss/五敌意图遮挡和Quick浅克隆base缺失已最小修复；模拟Color与合法视觉合同更新保留全部场景/原时限/精确逆转原hash。25项历史/空间/原生契约、原七片53场景/六种子及通用runner18项通过。完整PR头CI与S0审查未完成，保持In Progress；详见附件。

PR302首头036ce0de真实CI仍失败：Quick昏眩主图标预期错误；历史逆层抢占旧层中间witness；Sapphire补参未逆转；selector把条件历史分发传播给无关wrapper。本轮逐项修复，旧黄金/时限保持；另主动扫描补齐三个NodeUI平台Color模拟。Node24当前16项来源/原体/正式入口、四raw批次全部status0、selector/Quick100项全过；首轮失败与取消均交S0审计，未宣称036通过。

PR302 d2757fc9 的 Windows 真实失败已逐条取证：phase-four 退出菜单、Wizard 蓄能面、CardPreview 中性状态图标、双史莱姆分裂面、StatusHelp 削弱面、Controller 菜单和 Exit 确认路径。8个原生Lua入口均先按原脚本复现非0，再保留原状态/详情断言修正界面合同后status0。冻结phase-four源加入完整SHA+唯一hunk逆投影，PR238原26场景/黄金不改；专项合同7/7、语法与mock合同3/3成功。silent_final_sources的30秒超时仍未解决，由S0独立诊断；本轮尚不认证完整CI。

S0独立定位Silent原30s超时：RelicRewards.context对每张牌重复扫描卡表，改为每次调用内惰性首定义索引，不改Run/RNG/池/原fixture。成本门禁旧2080读取RED，新64读取GREEN；原71奖励→同一Run71购买13754ms内完成；六份相关Lua各status0、PR250原字节保护3/3、架构/Luacheck门禁通过。新的完整精确头CI仍待。

bcca9de5完整Quality仍失败：Win1为phase-four第169行第二个退出场景遗漏菜单放弃入口，Win6为原card-play完整入口30秒超时；其余6Win（含Silent）、4POSIX、聚合、presentation、Quick及Licenses成功。补齐phase budget5真实exit1→0，精确源逆层保留旧黄金；卡牌11个独立测试/24个场景按3入口机械分片，原体完整SHA与覆盖负例保持，每入口原30秒且独占调度。三片status0、相关合同15/15与语法通过；新完整CI未跑，S0意图帮助触摸区复核待结论，任务保持In Progress。
<!-- SECTION:NOTES:END -->
