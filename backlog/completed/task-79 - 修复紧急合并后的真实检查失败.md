---
id: TASK-79
title: 修复紧急合并后的真实检查失败
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-28 11:33'
updated_date: '2026-10-28 14:21'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-79.md
priority: medium
type: bug
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
紧急合并后的develop完整检查出现跨平台UI集成失败；逐项核对真实日志，修正功能回归和合法设计变动后的测试合同，保留原预算及历史证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 当前develop相关失败逐项记录根因和修复映射
- [x] #2 完整Windows与Linux检查保持全部有效测试和原超时并通过
- [x] #3 修复精确PR头完整检查通过并由S0审查；合入后最终复验由S0负责
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

S0真实生成树发现本次数字上移后help仍80高，Guardian肖像顶84/help底68侵入16px。最小改为图标+数字框union：高60、底88、距自身肖像4px，单图标宽度包住68px数字框；仅用已算几何/主题。新增1/2/3图标与完整数字、own肖像/提示/药水红绿；自然7编组61项原意图计划对实际肖像检查成功。人工Cultist×5全三效果另有既有跨行拥挤红例（source2(200,114)对target1(100,100)），保留日志/坐标，未做整体UI验收。cardplay补原始自动discovery精确3条清单及缺片/额外入口负例；最终完整CI仍待。

帮助区最终复验：原Guardian探针/clearance/case23/StatusHelp与原目标确认片status0；自动发现+负例+历史逆层+调度17/17。完整工程门禁与语法exit0：220模块1259边，73原警告无新增，432职责，四语义变异杀死，两原生合同成功。原15条相同声明因新增2行迁移位置，精确身份记录docs/reviews/p0-intent-luacheck-remap.json，零新豁免。首次逆层顺序和历史诊断位置失败日志保留，修后已全项复验；本轮新完整CI仍待，暂不push等S0审查。

S0已独立验收精确源码头cd9b550a1cb423d36dd78247440b6f4f3e9da9ff全部17检查成功：Quality40701124600的8Windows、4POSIX、presentation与两个聚合共15作业全过，Quick40701124601、Licenses40701124627成功；原所有失败/取消前失败保留。AC3仅覆盖修复PR头与S0审查；本次收口元数据新头仍须完整CI，合后稳定develop由TASK80/S0最终验收。

收口门禁要求已完成任务不得占当前High队列；源码头17检查与S0验收完成后，本任务终态优先级置Medium，原P0 High执行历史与全部AC保留，TASK59恢复原High。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
修复Boss意图/帮助触摸回归、Quick精确base、平台模拟与历史合同，保留完整卡牌测试和原预算，局部索引恢复Silent连续来源预算。cd9源码头全部17检查真实成功并获S0审查；26历史源与黄金保留。后续收口元数据完整CI及合后develop验收仍由S0负责，平台/自然通关与人工跨行拥挤风险如实保留。
<!-- SECTION:FINAL_SUMMARY:END -->
