# 自动合并启用实施计划

**Goal:** 独立审查完成后即可挂起 GitHub 原生 Auto-merge，等待完整 CI 自动放行，保留精确源码身份与合后验收。

**Architecture:** 保留四项原门禁，追加 `independent-review` 与 `full-quality`。现有 check 汇总作业在所有平台和 presentation 完成后发布 Full 状态，不增加作业。严格基线保护阻止旧组合沿用；暂停采用原生 disable-auto，hold 标签仅作启用前拒绝条件。审查授权 v4 与 Full 验收分开，历史 schema2/3 不改写。

**Tech Stack:** Node、现有 node:test、GitHub Actions/Rulesets、gh CLI；无新增依赖或常驻进程。

## 实施顺序

1. 重放 #496 到当前 develop，保留 Sprint 与所有既有门槛，登记 TASK-98。
2. 为 Full 发布器写负例：Fast、失败/取消/跳过/缺片、过期 run/attempt、错误 head/base/parents、发布失败均不能放行。验证 RED 后实现，仅 check 作业赋予 statuses:write；其余作业仍只读。
3. coordinator 的启用路径验证审查、精确组合、规则与前置，不等待 Full 成功。先读回自身 pending 审查门禁，再原生排队，复核准入与最新 CI 后放行；Full 已完成也走相同握手，无同步合并回退。挂起 v4 授权不能冒充 pr_passed；合后另采真实 PR Full 与 push Full，核对唯一父与树。
4. 增加 pause 命令：先取消 Auto-merge 并读回，再将审查状态置 failure；任何不确定状态显式失败。启用后若需要暂停，必须使用此命令或 GitHub 原生取消，不承诺标签能原子撤销。
5. 运行 auto-merge、delivery、CI shape/permissions、guidance/backlog 定向测试。独立深审绑定当前 SHA 后，可在该 PR 的 Full 仍运行时以新门禁完成首次原生挂起演练。
6. 清点在途 PR，先准备精确审查授权与 ci:full，再追加两个 Required contexts、strict=true，保留原四项及来源、原豁免与保护。保存更新前后 JSON 读回。
7. 将 #498 接续到新基线，独立复审后在 CI 未完成时实际挂起、暂停/读回、再次挂起，等待原生合并与合后完整验收。原 PR 只以成果接续方式关闭，不撤销功能或设计。
8. 全量核对开放 PR、远端与本地分支，脏工作树和独立提交保持可恢复；完成恢复清单后再移除旧引用。

## 验收边界

- 完整门禁继续拒绝 Fast；Fast 路径用于反馈，需要合并时用已有 `ci:full` 标签触发 Full。
- 启用前保存规则，原四项及来源不变；新增门禁生效后只用原生排队，不用 bypass。
- 原生 Auto-merge 不提供可变正文/标签的原子合并条件；依赖以启用时已纳入基线的提交为准，改变准入意图必须先暂停。
- 新 head 必须有新审查状态；strict 阻止落后的 head 自动合入，不自动强推或修改其他人的分支。
- 合后真实 Full、正常演练、分支收口分别取证，未完成不勾选 TASK-98。
