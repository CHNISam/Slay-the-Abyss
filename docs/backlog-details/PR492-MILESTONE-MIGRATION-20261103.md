# PR492 原生里程碑重排与 CLI 记录

当前顺序是 M7/m-7 工程、M8/m-8 体验、M9/m-9 内容。只修正排期身份和接续说明，不改变任务验收实质。TASK-96 的旧 M7 产品门槛按当前 M8 理解；TASK-97 正文及未勾 AC4 的旧 M7 体验/UI 也按当前 M8 理解，原文和勾选状态保留。

## 可核对的 CLI 执行

首轮以 develop `2f829579672e61a91374a2d8a0281d5cac4ca7fc` 为基线，重新读取任务后，用 Backlog 1.53.0 的 `task edit <IDs...> --milestone <id>` 重放 40 项字段。TASK-96/97 的当前编号说明使用 `--description` 和 `--append-notes`；三份导航使用 `doc update`。实际参数、退出码、完整输出，以及 doctor/milestone list/两项任务 readback，保存在 [CLI 记录](../evidence/pr492-cli-20261103.json)。任务原 notes、AC、状态、负责人和依赖按基线保留；历史 m-5 的另外 14 项不迁移、不关闭。

CLI `milestone --help` 只提供 list/add/rename/remove/archive；rename 仅能改标题、任务引用及 due date，add 只能分配新 ID。当前版本没有修改既有 milestone 原生 ID 或 description 的 setter。上述实际 help 输出在同一记录中。不能把 rename 标题冒充原生 ID 交换，也不能先删后建并声称保留原身份。

PR #487 随后由原负责人合入 develop `a96cd9306643df5a84f05c25693aed6b07c6c43d`。本轮从该已接受基线恢复 TASK-38.3/4.18/74，再通过 CLI 只重放 m-8/m-8/m-7；相关实际命令、输出及 doctor/readback 追加于同一 JSON。保留 #488 与 #487 的全部计划、notes、退出 AC2 已验状态及手机 AC3 未验边界。

## 本次有限例外的处理

用户已要求原生编号与执行顺序相等，并在本轮明确授权处理、上传 #492 的既定候选；12:21:07 UTC 的确认问题明确说明上传该候选至公开仓库 CHNISam/Slay-the-Abyss、更新 #492，12:21:34 用户答复“全部允许，全部允许。”。本次按该已授权候选的边界处理 CLI 无法表达的三份 registry ID/描述交换，使用可审阅的 Git 树差异；不再声称这些 registry 变更具有无法补证的 CLI-only 历史。

例外仅覆盖本 PR 的 m-7/m-8/m-9 registry 重排与一处描述编号笔误，不扩展到任务、AC、状态或未来 Backlog 操作，也不修改 AGENTS 的常规 CLI-only 约定。M0–M6 文件和历史证据不变。原 PR 历史已保存可恢复 bundle；独立复审核对三份 registry 的完整映射、任务身份及保留字段。doctor/readback 证明当前结果可读、无重复或依赖环，不能倒推历史写入方式。

## 验证边界

旧 head `6351c314e1e4c407a72cc5e6ede2873dbc2e7fdd` 的完整 Quality、Licenses、Quick feedback 已成功。本轮增加编号说明、执行记录并保留新基线的已交付 notes；新 head 仍须独立复审及精确 SHA 的必需 CI，旧绿灯不替代它。#487 已由既有负责人合入，本轮逐项保全 TASK-38.3/4.18/74 的全部有效 notes/AC；设备证据继续按原任务取证。
