---
id: TASK-81
title: 按改动运行快速检查并保留完整回归
status: In Progress
assignee:
  - Codex
created_date: '2026-10-28 15:30'
updated_date: '2026-10-28 21:03'
labels: []
dependencies: []
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
方案与真实Runner证据见docs/CI-FAST.md。普通PR消除重复回归，保留高风险完整检查。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通PR按影响选测；高风险及develop和发版完整回归
- [ ] #2 保留断言与Required Checks；失败取消缺失均拒绝
- [ ] #3 真实Runner Fast P50≤5分钟、P90≤10分钟；Full≤30分钟
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
采集基准与保护；实现影响计划和稳定汇总；负例与真实Runner验收。

针对当前及历史Full中两项原30秒宿主夹具超时，独立cec基线仅拆药水失败7组为1–4/5–7、连续出牌反馈9组为1–5/6–9；原正文、失败语义、seed61真实获取与全部模拟时间循环不改。药水注册缝先精确逆转再进入既有冻结UI校验，旧黄金hash不更新；静态正负例证明完整覆盖，四片仅本地串行原预算实跑，不在普通Node重复启动Lua。

同一PR314运行又证实rules4作业123073106427的potion_targeting.lua原30秒超时：仅追加此第三夹具，5个原注册组拆为1–4/5（前段6次、后段保留完整9种生命周期构造），不改其原循环和断言，沿用同一静态逆向/覆盖合同。

PR31694e82cd5实际Full又证实game_ui_exit.lua原30秒超时，仅追加此第四项：15组分1–7/8–15，保留原直接fn失败即中止、双过渡及全部400步循环；同前缀swipe独立入口保留。此前六片证据不重复运行。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR307；固定Node24.18.0专项32项通过，后续手动诊断输入与门禁9项通过。YAML/Bash语法通过；规则集证据已保存，无保护修改。当前远端Quality40716938768仍排队，未完成Full/Fast性能验收。创建时发现未合入审计工作树已占TASK80，改用TASK81；误建草稿6/7未提交。

PR307头11ff8b98真实Windows8片失败：原ci-downloads负例将第一个npm安装重试改99，但检查器只审旧rules作业，新增impact未纳入。最小修复将npm限制扫描扩展到整个Quality工作流，并逐安装步骤变异拒绝99重试。原失败与新负例本地Node24.18.0均通过，不删除原断言，不提高预算。

7058fb85真实Win4暴露原pr-history顺序断言失败：impact安装先于旧rules历史检查。将历史API检查前移到impact首次npm之前，移除rules和metadata重复调用；原顺序断言保留，调用计数加强为全文精确一次。全部CI合同（含Git真实下载/分片/冻结工作流/历史/快反馈）38/38通过0skip，Node24.18.0耗时42.3秒。两份原始失败日志已保存根.artifacts/ci-fast-pr307，不追认旧运行。

PR314 cdb08af2的Full40760764598/rules8作业123073106473对同源cec夹具出现ETIMEDOUT：药水失败6/7、连续反馈8/9完成后到原30000ms。PR306 a679/40735462500/rules6作业122986042683在18:02:44Z也有药水失败同样超时，早于PR313合入；不得将累积预算耗尽归因于313引入。共享worker早已将两夹具独占串行，现有开放PR（含312）没有对应修复。本轮仅本地测试注册拆分与精确逆向组合，不改预算/worker/权重或玩法，不勾选TASK81性能验收。

第三项实际失败为potion_targeting.lua，accepted与314原blob5605f22c901f7636b023ed90fd343053e1c7fc47及SHA2563dcadb807b990be2621b12ff85677749cf63b5ffcf06fa6a38bd6ff6c14d7fcc一致。日志在30082ms超时，P01/P02、P03、P04、P05四组通过后进入最后9种生命周期组；标签P01至P08不等于8个注册组。该入口不在现有冻结UI/main-potion映射内，shared potion_gesture_fixture保持不变。仅按整个原注册组拆两片；现有同前缀commit/help独立入口仍保留，广义发现显式核对其身份，不当作新片或删除。第一轮四片通过证据保留，不重复长测。

第四项为PR31694e82cd5/Full40762136486/rules5作业123077911552，game_ui_exit.lua在30062ms超时，原1–14组完成后进入第15组反馈恢复。accepted/316源blobf986addd094b95e234464e7bb48401d305e1515b与SHA256986c6a694f51d13dccf121ccba1a93fbb9e9d84f3f30bf7d0ae11d7360fdbf2d相同；无冻结入口映射，无需新增逆向层。按既有本地注册器范围选择拆两片，不引入pcall或改原fail-fast行为。仅此次有真实超时的第四夹具，未扩展为无依据全库扫改；PR315断言失败不在本切片范围。

本地最终验证：四项有实际超时日志的夹具共八个原30000ms进程全部通过，实际CASE联合分别精确1–7、1–9、1–5、1–15。药水失败1–4/5–7耗时12.327/9.757秒；连续反馈1–5/6–9耗时10.469/11.163秒；药水目标1–4/5耗时9.023/12.478秒；退出1–7/8–15耗时16.796/7.715秒（Node24.22.1，本地，不冒充Windows24.18.0）。最初四片、追加两片、退出两片分别存树外bounded-host-fixtures-evidence-20261028/04-raw-slices.json、08-third-raw-slices.json、11-exit-raw-slices.json，未重复执行已通过片。

新静态合同先在原单体上RED；药水加入注册缝后旧冻结UI校验真实2/2失败，加入精确逆向组合后恢复，旧manifest/黄金hash未改。最终新合同/既有UI与Node逆向/药水分片/worker与Task77等36/36，加原Battle静态源保护2/2，共38/38通过0skip；新普通Node合同无runLua调用，不重复执行Lua。JS语法、Backlog、diff检查通过；所有生产、数据、配置、workflow、共享setup、runner、worker与权重文件无改动。仅本地实现，当前组合尚待独立审查和新SHA完整Quality；不将focused通过写成合并/Windows/实机或TASK81性能AC完成。
<!-- SECTION:NOTES:END -->
