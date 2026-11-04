---
id: TASK-98
title: 启用独立评审后的原生自动合并并收口遗留PR
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 02:34'
updated_date: '2026-11-04 19:59'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/496'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/498'
documentation:
  - docs/evidence/m7-native-queue-post-511-20261105.json
priority: medium
type: chore
ordinal: 140000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner确认保留并启用PR496的自动合并目标，修复当前冲突、完整回归与准入边界；同时接续PR498设计稿并清理遗留分支。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 审查通过后可在完整CI未结束时启用原生Auto-merge，Fast或缺失失败取消的Full回归不能放行
- [x] #2 新HEAD或过期基线不能沿用旧审查授权；暂停能真实取消Auto-merge并读回
- [x] #3 当前精确HEAD完整CI、独立复审、Ruleset读回与真实PR自动合并演练有对应证据
- [x] #4 PR496和498成果完成合并接续，旧PR及无新工作分支收口，未提交内容完整保留
- [x] #5 原生Merge Queue保留六项Required及来源、Strict和无bypass，真实PR验证入队、组合Full、失败剔除、重新授权自动合并及合后收据
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 接续PR496并补Full放行与严格基线、暂停合同。2. 定向负例和独立深审。3. 正常CI合入启用规则。4. 用PR498设计稿实测自动合并并核对合后Full与清理清单。

启用前先将独立审查门禁置pending并核对状态ID，显式原生排队后复核最新CI与基线再success放行；取消全部同步合并回退。首个接续PR502也可在Full进行中实测。

仓库转移后以固定ID1429751262解析当前canonical，修复coordinator owner硬编码；历史授权保持原文，以独立迁移见证及原文SHA256衔接合后验收。新提交触发迁移后的完整CI，不借取消的旧event重跑。

按本轮Owner要求接续原生Merge Queue：508完整CI及正常合入后精确追加队列规则，用511验证真实入队、受控失败剔除、重新授权与自动合并，合后分别验收Full和收据；未完成演练保持AC5未勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已重放PR496并修复冲突；Node24上64项授权/验收定向测试通过；新增Full发布器保留27作业、严格基线与显式pause。CI历史投影保留旧hash，当前仅余汇总命令提取适配，尚未远端启用。

独立深审已修旧run写状态覆盖、master适用范围及真实GitHub合后空PR关联三项问题，并补同run attempt下界。Node24授权/交付/Full发布器70项全过，另CI汇总历史合同3项通过；schema2/3原验证保持。

PR502首轮Windows第6片：Sapphire冻结21组中15-21片在原30秒总预算内超时，已按15-18/19-21重新分片，冻结正文hash和所有21组不变。另按gh2.96官方源码核验，pending路径改为显式GraphQL enablePullRequestAutoMerge，避免--auto在CLEAN/UNSTABLE时改走直合。新路由21项、原生请求/分片32项通过，完整Sapphire预算实测在途。

Sapphire全部21组本轮7+4项合同回放通过；分片3/5原始入口8596/6105ms。卡牌全部11组分为1-3/4/5-8/9-11，原body hash与30秒不变；原始入口6909/7565/14159/9583ms通过。路由/源合同93项通过。所有auto请求显式enable；CLEAN兜底须fresh Full、原生六项、inventory Actions最新run/attempt/HEAD再验证，71项相关合同通过。

独立深审指出同步兜底无法抵御Owner PR豁免下的基线竞态，已完全删除。改为pending审查门禁握手后原生队列放行；Full发布同时下载校验不可变checkout收据，避免绿灯元数据与实际attempt不一致。73项授权/交付/Full定向合同通过，等待最终SHA复审与真实演练。

PR502已原生自动合入67493f1a，PR Full41771126698及push Full41775894289均27项通过。随后仓库归属转FurinyaWorks，ID1429751262不变；PR504原1667轮取消（head/base未变），已显式暂停并保留原证据。CLI canonical变化导致旧授权repo字符串不能验收，继续修复身份衔接而不重写旧收据。

固定ID/登记别名/原文hash迁移适配74项合同通过，guidance/backlog通过；候选验证器用502原授权与真实两轮Full、不可变收据验证merged_passed（76224ac7），旧preflight repo仍CHNISam，原文件SHA256一致。尚待本次新HEAD独立复审与Full，未宣称迁移修复已合入。

已接入PR505严格继承修复，并保留PR506的TASK98.1及附件，避免两套迁移实现；按numeric canonical补review/waiver/pause三个CLI路由与旧review不可升级负例。组合83项通过。使用501原preflight及真实attempt2 API/不可变收据，候选验证得到merged_passed（eec92e2f），未改原jobs或receipt。

本轮M7收口核对：502/504已合入，505/506关闭并由504接续；develop=c1cf79df。504原授权真实合后验证为merged_pending，push Full 41794339270仍在执行，不提前完成。508精确HEAD7eea66ca/basec1cf79df独立复审codex:/root/queue_review:7eea66ca通过，98/98定向通过；Full41796102717尚未完成，merge:auto只读预检在impact路由前拒绝，未写授权。已保存25870651原规则和仅追加单PR/SQUASH/ALLGREEN的候选，待508完整CI正常合入后启用及真实PR演练；六项Required/Strict/无bypass保持。

508受控挂起首次最终读回未确认，失败关闭并成功撤销；第二次记录完整API边界后原握手成功，原生squash Auto-merge已确认（08:10:59UTC），授权build/delivery/auto-merge-508-7eea66caaf97.json，仍待Full41796102717。规则候选独立复审仅追加merge_queue，通过；未启用。510真实CRLF负例问题已独审修复132a96c2快进原PR，等待当前Full。

504真实合后验收已通过merged_passed，摘要docs/evidence/pr504-merged-delivery-20261104.json；TASK99完成。另上线审计发现queue状态readback/catch缺少已入队处理，已暂停508读回paused且auto_merge=null，原PR最小修复在途；远端Queue仍未启用，绝无绕过。

508最终675ce59f已于09:50UTC正常自动合入a73e6a8f，PR Full41804489286、push Full41810232029及不可变收据均通过，verify:delivery=merged_passed（86b86945）。510全部有效增益随508接续，原分支/提交保留并关闭PR。原生Queue已真实启用：MQ_kwDOVThF3s4ABTCP，SQUASH/ALLGREEN，build/merge/min1，wait0/timeout120min；PUT502后只读精确确认已提交，未盲重试。原六Required/Strict/no bypass及25870646完整快照不变。511当前1a24acf1/basea73独审通过，原生等待握手成功，Full41818991963执行中；真实入队/失败剔除/自动合并尚未验收。

本轮只读复核496/498为CLOSED，502/504/508为MERGED，505/506/510为CLOSED并有接续来源；git ls-remote确认496/498及502/504/505/506/508旧feature refs已不存在，无新工作。510原132a分支按承诺保留恢复历史。父任务仅AC5真实原生Queue演练保持未完成。511的1a最新Full仅历史UI slice2触原30秒，真实暂停读回auto_merge=null且无entry；原body/11组/预算不变的359修复已独审141项+五原CLI全组通过，新Full41823316178执行中。

359最终PR Full41823316178已完整成功并真实自动入队。首次组20d6/41827310450经现有admission实测通过；仅给该组合Required审查门禁注入明确controlled failure后，GitHub原生事件actor=github-merge-queue/reason=failed_checks自动剔除，发生在任何手动dequeue之前，PR与BASE均未变。第二组7f5/41828183215已实际测试pause/dequeue与双面空读回，原生事件reason=manual。随后全新授权最终组05cc/41828843134，admission真实通过，完整Group Full仍执行；AC5待自动合并和合后收据，不提前勾。首次/第二/最终授权原文分别保留，原规则六Required/Strict/no bypass未动。

组合组05cc的Full41828843134回归全部通过，最终check发布器因只读GITHUB_TOKEN的ruleset API隐藏bypass_actors而失败；原生队列于12:51:50UTC再次failed_checks剔除，PR仍未合并。管理员读回保护仍active/[]，官方API文档确认字段仅向规则写权限可见。准备以已有coordinator显式空bypass核验+规则版本摘要绑定当前HEAD/BASE授权修复，不新增CI权限/令牌/作业，不把缺失字段直接当空。AC5继续未完成，保留原组日志与授权。

真实发布器修复已正常快进原511至944575c8，独审independent-agent:/root/review_rules_visibility:944575c8通过，113项门禁和19个自构造负例拒绝均实跑通过；管理员/匿名规则摘要同一9a80615f，时区规范化，当前admin/id/enqueuer及版本绑定，无新权限/密钥/jobs。已新SHA授权并真实读回原生waiting，Full41836216986进行中。前359授权已pause；原失败/取消与成功CI成本分开记，成功359 Full27.4min不替代新SHA。AC5仍待真实成功组合及合后验收。

944当前精确PR Full41836216986成功（27.633min/27jobs），不可变收据验证pr_passed=387a9689。GitHub自动入队b4ac6314，entry MQE_lQDOVThF3s8AAAABMwfM_M4ABTCPzgO30CA，组合Full41840544490执行中；真实公开redacted规则+管理员身份/当前成员授权实测admission通过，但不冒充workflow令牌发布已成功。AC5保持未勾。

原生Queue成功：b4ac6314组合Full41840544490完整27jobs成功，真实workflow令牌发布器及Metadata权限通过，原生于14:13:32UTC自动将同一队列组合提交合入develop。不可变组合收据验证native_group_full_passed，artifact13329164326；单父a73且tree精确匹配944授权。GitHub mergedBy归属CHNISam=enqueuer，不伪称queue bot；期间无root direct merge请求。组合wall30.667min，≤30目标仍有超标样本。合后push Full41845430335在途，父AC5待merged_passed再勾。

原PR511精确944575c8的源码Full41836216986与实际b4合后Full41845430335 attempt2已由原验证器复验为merged_passed。旧14:33快照和原失败记录保留；其中headFull旧编号在新附件显式纠正。原attempt1收据按真实有效执行身份继承，不重写为attempt2。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
原生队列入队、失败剔除、显式暂停、重新授权和自动squash均有实证；原PR511的精确合后收据终验通过。M7性能和设备验收独立保留。
<!-- SECTION:FINAL_SUMMARY:END -->
