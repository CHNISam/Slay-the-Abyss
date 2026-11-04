# TASK-98.1：迁仓后的自动合并身份校验

## 事实与范围

2026-11-04 05:25 UTC 通过 GitHub 只读接口核对：仓库 ID `1429751262` 的规范名已为 `FurinyaWorks/Slay-the-Abyss`；develop 为 `67493f1a707dd5332788b4081adb3c3ce6e46761`。`allow_auto_merge` 与 `allow_squash_merge` 均启用。规则 `25870651` 仍 active、严格更新基线、仅 squash、线性历史、解决讨论；六项必需门禁及原 Actions 来源保持。

开放 #504/TASK-98 承接架构设计，#505/TASK-99 处理重跑继承收据，#503/TASK-87 处理轻量指引，#498 保留原设计稿；本切片不接管这些内容。已查重，通过 Backlog CLI 创建 TASK-98.1、task:pick ALLOW 后认领 Furinya，独立分支 `feat/repository-migration`。

生产脚本中的旧仓库名仅见 `scripts/arm-auto-merge.mjs` 的白名单和启用/暂停CLI入口。交付验证器、Full发布器及Quality工作流使用实际仓库参数或GitHub环境，不需要放宽。计时数据与历史证据中的旧URL保留。

## 修复与信任边界

- 启用、暂停及文档豁免入口使用新规范路径；仓库API读回必须同时匹配完整规范名与数值ID，旧路径、同名异仓、缺失ID均拒绝。
- 保持规则ID和全部原准入合同，不接受任意动态owner，不把重定向当作身份。
- 旧review.repo或旧run.repository不改写成新证据；跨迁仓记录须重新采集并核验，无法证明的保持未通过。
- 未修改工作流、交付收据逻辑或其他人的分支；未发远端状态、启用/暂停真实PR、合并、发布或变更规则。

## 本轮验证

- Node `v24.22.1`；基线 auto-merge / delivery / full-quality 三组 `73/73` 通过。
- 仅加入迁仓夹具和新增正负例、生产源码仍旧版时，auto-merge `8/33` 通过、`25/33` 失败，复现旧路径阻塞及暂停身份缺口。
- 修复后同三组 `77/77` 通过，覆盖正常授权、暂停、文档豁免CLI、规范路径/固定ID、旧评审与旧Full证据、失败撤销和严格基线。
- 独立只读复审已覆盖生产脚本和测试，独立重跑三组 `77/77` 通过，无阻断项；治理两组 `41/41`、Backlog doctor、verify:backlog、check:guidance及diff检查通过。
- 定向测试使用注入式GitHub响应，不是远端真实自动合并演练；完整Required CI、最终SHA复审绑定及合后验证另行记录，当前不得宣称完成交付或发布许可。

来源：[当前仓库](https://github.com/FurinyaWorks/Slay-the-Abyss)、[develop规则](https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870651)、[基线](https://github.com/FurinyaWorks/Slay-the-Abyss/commit/67493f1a707dd5332788b4081adb3c3ce6e46761)。
