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
## 集成接续记录

本切片由 PR #504 接续：当前入口从固定仓库 ID 解析 canonical，同时校验 settings、PR head/base 和排队读回的仓库 ID。历史迁移通过独立 witness、原授权文本及 SHA-256 衔接，不重写旧收据；补充 review、waiver、pause 三个 CLI 入口的真实函数路由及无效身份不写远端负例。原 PR #506 的构想与审查记录保留在上文，源 commit 保留恢复引用。当前组合定向测试83项通过，精确 HEAD CI 和实际合入另验。

## PR506 剩余覆盖接续（2026-11-04）

PR504已将实现与三条CLI入口回归合入 `c1cf79dfa8e81189546d95277d3bb891d831ba6e`，原PR506以接续完成关闭。本轮从该develop新建短分支，只修当前门禁配置链接及应急命令路径，补未逐例吸收的测试，不重新提交旧实现或改写历史别名/收据。

- 44组review/waiver/pause的canonical、settings、PR head/base元数据负例：缺失ID、字符串ID、缺失/错误full_name；生产main真实调用被注入读回，逐组确认实际命中、拒绝且没有POST/GraphQL/gh pr写入。
- 新canonical授权中的run/currentRun旧仓库名，缺少合法迁移见证时拒绝；原合法witness正例及历史证据保持。
- 新文档回归在原路径复现1项失败；两处路径修复后，三组86/86，连同治理与分支历史共130/130通过。
- 临时独立副本分别放宽ID比较、删除full_name比较、删除run owner比较，三项均被新断言检出；正式生产脚本未修改。doctor、verify:backlog、check:guidance及diff检查通过。

这些是本轮定向与负对照证据，不替代新接续提交的Required CI、独立复审或合后验证；TASK-98.1 AC3保持未完成。

## PR510 Windows CRLF 接续修复

独立复审在 `6f0b873a421557b294a099e5d4f5385ec953e3cc` 复现：文档测试直接按 LF 标题分割，Windows CRLF checkout 使 setup 为空。新增 LF/CRLF 与缺标题负例后，旧分割实现为34通过/2失败；将原断言抽为共享 helper，仅先规范化 CRLF 后，三组定向87/87通过。原路径、历史别名及标题存在断言均保留，生产脚本不变。guidance、verify:backlog、doctor 与 diff whitespace 检查通过；本地提交仍待独立复审、精确 HEAD Required CI 和合后验证，不提前完成 AC3。

## PR508 统一接续

从 `208eeb63d1a530be1891c91d14b0644659fb0fa9` 接续 PR510 原提交与 CRLF 修复，保留现有原生队列逻辑及 TASK98/98.1/99 验收记录。TASK98.1 AC3 已由 PR504 合后证据勾选；上文未完成说法为对应历史时点，不撤销该验收，也不扩大为新增覆盖已合入。五组定向107/107通过（admission 6、queue 6、auto-merge 44、Full 14、delivery 37），guidance/backlog/doctor/diff 通过。当前整合仍待独立复审、精确 HEAD Full 与实际合入；PR510 保留，待 PR508 合入后接续关闭。
