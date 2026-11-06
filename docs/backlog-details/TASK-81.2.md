# 安全 Fast PR 的原生队列准入

接续 #529 的 TASK-81.2 与 #307/#502/#508 已有能力，不新增回归平台、后台调度器或权限。原生 Backlog 仍记录验收状态；此附件保存实现和取证边界。

## 实现

- `pr-quality` 证明精确 PR 合成提交的安全 Fast 或完整 Full。原 `full-quality` 仅证明 Full，未更改为 Fast 成功；迁移前旧 Full Required 继续正常工作。
- Fast 必须同时完成 Windows/POSIX 全部受影响集合、impact、presentation 和治理汇总。Windows 上传不可变 checkout 与完整选测计划；读回绑定 HEAD/BASE、实际双父、run/attempt、artifact ID 和完整作业清单。显式纯文字白名单可零业务测试，其余拒绝零测。
- `merge:auto` 仅在 Strict、Squash/ALLGREEN 原生队列、Actions 来源的 `pr-quality`、原四项检查及独审保护均存在时接受 Fast。保留原精确 HEAD 与 pending 独审握手；保存独立 schema6 授权和 schema7 Fast 收据，不冒充 schema3 Full。
- 队列强制原全部 Full 分片，核 live 成员/授权/依赖/规则及每个 PR 最新 run/attempt。下载后重读；PR 失败、取消、正在新测、暂停或规则漂移均不能放行。组合 Full 成功才发布队列 `pr-quality`、`full-quality` 与准入状态。
- Fast 合后另外采集 schema8：实际 squash SHA 的队列 Full、不可变收据、Actions 发布状态和 inventory，随后独立核 develop push Full。旧 schema2/3/4/5 历史合同保持。

## 本地候选验证

固定 Node 24.18.0。原准入/Full/队列/交付/库存等相关合同 129/129；Fast 与入队后重读的组合回归 29/29。包含实际 publisher→artifact collector→原生 pending 握手→schema6→队列 Full/inventory→push Full 的完整模拟，以及下载期间取消、新 attempt、HEAD/BASE、ci:full、Draft、缺片、旧 SHA、最新 inventory 失败等负控。指引、Backlog、实际 JS 语法与 diff 检查通过。

新增测试按明确未知成本进入当前完整库存；历史 741/1401 观测、原分配、预算、安全分类和余量不变。没有再校准成本、增加 Full 分片或放宽时限。Backlog doctor 本机 CLI 扫描范围通过，不代表已解决其他版本递归扫描报告的历史归档碰撞。

## 切换与真实验收

实现必须先经旧六项 Required、独审、原生队列 Full 正常合入。之后保存远端 Ruleset 原快照，仅将 Required 的 `full-quality` 换为同 Actions 来源的 `pr-quality`，完整读回并重新绑定规则指纹。其他保护保持。最后用真实安全 PR 核双平台 Fast、原生队列、组合 Full、squash 及 develop push Full，失败演练与耗时分别保存；未有真实证据前 TASK-81.2 保持未完成。

当前附件只描述候选实现和本地验证，不宣称远端规则已切换或真实链路已通过。原 #529 与其分支保留可恢复历史，线性接续避免改写在途提交。
