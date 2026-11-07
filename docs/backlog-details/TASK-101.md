# TASK-101：仓库与构建成本首轮证据

## 历史证据身份

以下首轮观测与独审记录属于 #522 原始来源，不是当前 c685409d 合入核心后的重新测量。原始 JSON 与独审文件逐字保留，历史 15 项结果不代表下述接续候选的 21 项回归；当前接续状态见文末。

## 交付范围

本切片增加 `scripts/repository-costs.mjs` 和定向回归，建立可复跑的离线成本基线。不改运行时、构建器、CI、缓存策略、冻结历史输入或许可；不删资源、不重写 Git 历史。TASK-101 保持 In Progress，三个 AC 均未勾选。

本轮从 `develop@dedb9ed5` 建独立分支，承接 #521 的任务定义后用 Backlog CLI 领取 TASK-101。测量基线为 `7f11f4bfa994c4d3fa8ad7b677bf7aba4359bbf2`，其运行时和构建器与 dedb9ed5 相同。机器摘要见 [本轮证据](../evidence/task101-repository-costs-20261106.json)，包括工具/测试 SHA256、实际源树摘要、版本、完整命令和产物身份。

## 已测事实与保留决定

- 当前提交有 7,138 个 blob 路径，Git 文件内容按路径合计 **236,778,859 B**，按 OID 去重 **226,921,854 B**。重复路径 **9,857,005 B** 已共享 Git 对象，不能说删除副本就能省同量下载或 Git 存储。
- 140 个 LFS 指针对应 140 个 OID，声明 payload **216,647,536 B**。本隔离副本全部仍是指针，本地已认证 payload 为 **0 B**。这不证明远端对象不可读；没有下载或探测远端对象，因此网络传输字节保持 `null`。
- 所有 LFS 全部展开时，文件逻辑字节为 **453,407,942 B**。这个理论值不是 Git pack、下载流量、磁盘分配或官方候选包。官方候选大小保持 `null`。
- `build/` 没有跟踪文件。大文件包含冻结背景 Lua/JSON、pr323 历史归档和反向补丁、原生怪物输入。它们被构建/历史 oracle/完整性验证消费，不作为可删除的缓存。现有六张审核 PNG 与四张运行时 preview 继续使用 `ci-reviewed-lfs.mjs` 的精确 OID/大小和按需下载合同，不扩大 LFS pull。
- 三组配对默认构建（data → UI → theme）共六次成功；每次 **21 文件 / 12,209,660 B**，逐文件 SHA256 相同。冷 P50/P95 **729.10/768.52 ms**；暖 **765.07/797.82 ms**。三个样本只作本环境描述，不支持“缓存命中”或速度提升结论。

因此本轮保留现有资源和构建安全校验，不为制造收益删除历史证明、放宽别名防护或增加未经验证的缓存。默认离线构建不到一秒，现有证据不足以把它认定为完整 CI 的主要成本。

## 复跑

在仓库根目录执行：

```sh
node --test tests/repository-costs.test.mjs
node scripts/repository-costs.mjs
node scripts/repository-costs.mjs --builds --rounds=3
```

普通调用只读本地 Git 对象和 LFS 文件，写 `build/repository-costs.json`。不会 fetch、pull、清理历史或下载素材。`--builds` 才执行现有默认构建，每组用新建隔离输出目录，再在同目录重复构建；不复用或覆盖已有生成目录。必要输出缺失、失败、源树变化或产物变化均不能形成成功耗时摘要。

“冷”仅指新生成目录和新子进程，没有清空 OS 页缓存或依赖缓存；“暖”仍是新子进程，不表示应用级增量缓存。默认 UI 关闭美术开关，不能代表 art-enabled 原生候选构建。输入摘要覆盖跟踪及非忽略的未跟踪路径/字节，不读取 symlink 外部目标，不认证 ignored 依赖或完整 Python 环境。原样保留这些边界。

## 验证与后续

- 定向回归覆盖 Git/LFS 去重、二进制与特殊路径、真假材料、缺失/损坏/指针、必要产物、输入/输出变化、失败、轮数约束与 symlink 边界；保留失败先行日志。15/15实现侧和15/15独立复审通过，原生Backlog范围及指引门禁、语法与diff检查通过；见[冻结独审记录](../evidence/task101-independent-review-20261106.md)。相关测试规划因构建器字面量引用选出较大传递集合，本地只执行本切片定向回归；未把该规划或局部绿灯当作Full通过。
- 新 CLI `backlog doctor` 只读发现五组既有 active/archive ID 碰撞，未修无关历史；TASK-101 不在碰撞中，原生命令可正确读写。不能把该诊断称为全库 doctor 通过。
- 跨平台实际运行、远端 LFS 可读性、真实 checkout 传输、启用美术的候选构建、精确 PR Full 和实际合后验收仍未完成。没有重复启动本地 Full，不把本切片当作整个 TASK-101 或 M7 收口。

## 2026-11-06：从实际 develop 线性接续

- 集成基线：`c685409d7d34d91cae79e917090fe4299184ca8b`；来源：#522 `cf46596bcf9423a4190db982f1c99a2e3e6b2813`。仅接续仓库成本脚本、测试、原证据与本任务进度，不覆盖 #521 的任务、HANDOFF 或运行时，不纳入 #523/#526。
- 纳入已审跨轮 P2 修复：除了每轮 cold/warm 必须相同，各轮也必须与第一轮 cold 的完整产物清单相同；漂移返回 failed、summary=null。新增反例保留每对内部相同、输入不变而跨轮不同的证据，不能以同轮一致代替三组同源配对。
- 修后脚本 SHA256：`779fd89b7328d97d0734fb1c762ab1dbfea976b539cbd109df4017b61f1843ec`；测试 SHA256：`7c8b8c94d2773e62a186d06d7c5859c67bee75aaf1cf88a7909303bdf85b5a61`。不刷新原测量 JSON 中的旧源码摘要。
- CI 库存验证将冻结 741 JS / 1401 Lua 与当前 742 / 1401 分开。唯一新增 JS 为 repository-costs；历史观测、精确预测及收据保持，当前新增文件按未知成本、每文件恰一次、原 17/13 分片与原预算加 60 秒余量验证；不修改 timings、workflow、安全分类或阈值。
- 本轮只运行 21 项 repository-costs 与 8 项库存合同，共 29/29 通过，0 失败/跳过。依赖仅从锁文件逐字相同的隔离目录复制，未安装或改依赖。未重跑真实三组构建或本地 Full；Windows/macOS、网络、正式候选和精确托管/合后 Full 仍待。
- 本候选仍需独立整片深审与原生准入。TASK-101 保持 Furinya / In Progress，全部 AC 未勾；历史冻结独审不冒充本候选独审。
- 本轮 `verify:backlog`、`check:guidance`、`check:syntax` 与 `git diff --check` 通过。Backlog CLI 1.55.3 的只读 doctor 退出 1：既存五组跨归档 ID 冲突，未修复无关历史，不声称全库 doctor 通过。

## 当前最终接续：实际 develop 67793786

#530 已合入后的实际基线为 `67793786f82db4059e9de463674bd40e4be38932`。本次仅接续 #522 七文件，不携带旧 TASK-74/74.19/74.20、Sprint 或 M7-DELIVERY 交付记录，不覆盖并行 #531 核心工作；上节 c685/742 库存与验证属于先前隔离候选。

当前为 **743 JS / 1401 Lua**，冻结 #521 收据仍为 **741 / 1401**。postPlacementJs 仅登记 runtime-path-baseline 和 repository-costs；历史测量、精确预测、timings、unknown 成本、17/13 分片及原预算/60秒余量保持。旧三组真实构建报告与原独审逐字保留为历史身份，不重新测量或冒充当前性能证据。

本次继续只推进既有成果，不扩展成本实验；当前候选的精确独审、托管 Full 与实际合后验收仍待，TASK-101 保持 Furinya / In Progress、全部 AC 未勾。

本次在上述实际基线的隔离树运行仓库成本21项、库存8项、runtime6项，共35/35通过，0失败/跳过。该定向结果不替代Full或新三组性能测量。

本轮 `check:syntax`、`verify:backlog`、`check:guidance` 和 diff 检查通过；精确候选独审与托管/合后 Full 仍待。

## 2026-11-07：接续当前 develop

Owner 明确恢复 M7 剩余工程治理和现有 PR 集成。本轮从 develop `de218e5c4d8a8f71c9641e3499c8d6943c0b82ea` 线性接续 #533 `74eec3e66e78b9f2f84e0a861c5b354aac6f4445` 的五份专属工具、测试及附件；原两份冻结证据逐字保留。任务由 Backlog CLI 接续，不回带旧核心或交接状态，不改写旧分支。

唯一集成冲突是 `postPlacementJs`：取当前 m7-core-final、pr-quality-evidence、runtime-path-baseline 与 repository-costs 的并集；保留历史 741/1401 来源、未知成本、现行分片与全部预算。本轮没有重新性能采样，原耗时仍只属于其历史源码和环境。当前组合定向检查、独立复审及远端正常 Full/队列/合后验证分别记录；尚未完成的 AC 保持未勾。

本轮固定 Node 24.18.0 执行 repository-costs、ci-complete-calibration、runtime-path-baseline 三文件：35 项中 32 通过、3 项按既有 Windows 符号链接权限条件跳过，0 失败；POSIX 对应边界继续由正常远端 Full 验证。指引、Backlog 范围、两份新增 JS 语法和 diff 检查通过，本机 Backlog doctor 也通过；此结果不改写历史 CLI 的碰撞记录。独立代码审查未发现阻断缺陷，待精确提交绑定和正常远端交付。

最终同批还接续 #532 六控件可见性切片及其本轮一次性同源验证、#534 未执行美术实验协议，并补 Bonfire 晚失败回滚保护，共用正常完整回归；当前库存为 746 JS / 1402 Lua。可见性证据见 TASK-100-VISIBILITY-CURRENT-20261107，Bonfire 证据见 docs/evidence/bonfire-rollback-20261107.json。不启动 TASK-94、不变更其准入或正式美术策略。安全 Fast 链路使用独立 CI 指引切片验证，不与本工具批次混淆；上述历史 743/1401 段保持原身份。
