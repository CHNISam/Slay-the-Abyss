# GIL 按需构建与不可变候选晋级：交付设计

> 2026-10-31 研究方案。**仅规划，不改变现有 CI/构建、平台发布或 GitHub Release**；当前发版优先。实施分独立小 PR，先验证可行性。
> 基线：develop `96411b6c74349f25e3434509dd922e423b47c45f`。现有交付约束仍以 `AGENTS.md`、`docs/CI.md`、`docs/ENGINEERING.md`、`docs/PLATFORM_LOAD.md`、`docs/PUBLISHING.md` 为准。

## 决策：不要“改一下、打一个完整 GIL”

采用成熟的 **Build once, promote the exact artifact（只构建一次，原样晋级）**。日常高频反馈和昂贵的原生 GIL 构建必须脱钩：

| 阶段 | 触发 | 交付 |
| --- | --- | --- |
| 开发/PR | 已有 fast / related + 必需 Quality/Licenses | 测试报告，**零完整 GIL 构建** |
| 候选冻结 | 主控明确选定 **已集成且经完整质量检查的 40 位 Git SHA**，按需人工触发 | 从受信基础 GIL 构建**一次**，得到 `candidate.gil` 和不可变收据 |
| RC 验收 | 直接取回**同一 GIL** | 官方导入、ready、PC/手机、负载和人审；证据全部绑定 GIL SHA256 |
| 正式发布 | Owner 授权，且符合既有平台流程 | 原样晋级已验产物；真实平台发布取证后才归档版本/Tag/Release |

- **绝不**在每个 push、PR、合并或小修复时自动重打完整 GIL；不定时全量打包。`develop` 继续前进也不自动替换已冻结的候选。
- 不为“自动化”重新写一套构建器；不重复全量 Quality、不新增额外测试矩阵、不设任务锁、不恢复日常 self-hosted CI；让现有轻量反馈与完整门禁保持原样。
- 候选有缺陷：先基于该 GIL 取证定位、在源码上用局部测试快速修；等修复**成批集成**、完整门禁通过后，再冻结下一份候选。无法避免的重建属于**新候选**，不得覆盖原 RC。
- 平台正式发布仍由人操作，不能将 CI 绿灯、GitHub Release、旧 Alpha 的发布记录冒充新 GUID 的千星奇域发布或赛事报名。

## 仓库已有能力与真实缺口

- `.github/workflows/quality.yml` 等已有受影响检查、分片 Quality、Licenses、报告 Artifact；`release-proposal.yml` 已有手动 Release Please 提案，明确 `skip-github-release: true`。
- `scripts/build-native-candidate.mjs` **已经具备**源存档复制、Lua/UI 生产生成、MCP 写入/读回、候选 GIL、`candidate.json`、`sourceCommit`、`sourceDirty`、`payloadDigest`、`buildId`、SHA256、失败证据；直接复用这些合同。
- 构建目前需要受信 `base.gil` 与外部 `genshin-miliastra-mcp`。现有 Windows 本机工具路径不能当作 GitHub-hosted runner 的能力；首步应**在隔离托管 Windows 环境做小样 Spike**，核对编码依赖、工具许可、运行条件、基础存档授权。不能先写“云端构建已可用”。
- 构建器使用随机 UUID/`buildId`；两次相同输入的 GIL **不保证逐字节一致**。身份必须绑定真实产物 SHA256，选择**复用已有 Artifact**，不能通过重复构建来“复用”。
- 核查时仓库有 14 个历史源码注释 Tag、GitHub Release 列表为空；`data/release/publications.json` 是真实平台发布证据账本，不能据它为空就推断从未有过 Alpha 发布。
- 核查基线的 Quality [运行](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41184409466) 为失败，后续冻结时**必须核对对应精确 SHA 的真实完整门禁**，不得借用旧 SHA 绿灯。

## 极简交付工作流：有界、去重、可追溯

**只有云端 Spike 实际成功后**，再新增独立的候选构建 `workflow_dispatch`；普通 push/PR 的原 Quality 不触发它。

1. 入参限定：40 位源码 SHA、明确的目标作品配置（旧 Alpha / 新参赛作品，独立 workKey）、受信基础 GIL 的版本/摘要、确定的美术开关。拒绝任意 shell/path/URL 注入与未审查外部资源；只允许可信操作者请求。
2. 先验证该 SHA 的 Quality/Licenses 必需检查在原有合同下成功，源码干净、工具链/基础 GIL 可定位；不**为了检查**重复运行整套门禁。
3. 以源码 SHA + 工具链精确版本/提交 + 基础 GIL SHA256 + 功能开关 + 版本/作品配置等构成构建请求身份；已有**未过期、真实可下载且 hash 经核验**的相同候选就复用，否则一次新构建，绝不凭缓存命中冒充产物。构建 ID 与最终 GIL Hash 另行记录。
4. 复用现有 `scripts/build-native-candidate.mjs`，固定依赖；一份独立工作区、一名构建执行者，不动真实平台存档，`MILIASTRA_ALLOW_LIVE_WRITE=0`，默认无 GUI/`--playtest`。
5. 上传 **GIL + candidate.json + SHA256SUMS + 必需脱敏日志**；记录 SHA、基础包/工具链身份、`buildId`、源码干净状态、实际静态检查与读回结果；故障明确失败并保留可诊断收据。GitHub **Cache 仅存依赖/中间物**，Artifact 才能当交付候选。
6. 使用独立的请求去重/并发控制限制构建次数与网络；正在构建的指定 SHA 不受后续 develop push 自动取消。短期 Artifact 按项目规则保留，RC 在验收期间明确保留；过期/损坏必须标记不可晋级，绝不静默再构建并假装旧 RC。
7. **禁止上传未经审核的基础 GIL、专有素材、玩家信息、凭证、个人路径或含敏感数据的调试日志到公开仓库 Artifact/Release。** 私有输入需确认合法、可信来源和访问控制；安全与许可不满足时停止公开托管，不以冒险上传换速度。
8. 平台导入/ready/实际设备/负载与发布都要绑定**同一个 GIL SHA256**；正式 Release 可从已验候选复制附件，但不得重新编码。遵循既有 Tag 与人工平台发布时序；旧 Alpha GUID 和新参赛 GUID 必须分别登记。

**流量/成本纪律**：禁止 `git lfs fetch --all`、无界重复下载、每个 Agent 各自触发完整 GIL/Quality；复用仓库当前 LFS 受控清单、npm 缓存、现有受影响测试策略，按实际运行度量网络传输/Runner 分钟/构建次数再优化。缓存不足时失败要透明，**不能为了省流量删除有效测试或放宽关口**。目标是每个已批准候选至多一次重型构建（除故障/显式新候选），PR 日常零重型构建，不凭空承诺数值节省率。

## Agent Skills：只选有来源的、尽量不新造轮子

**默认直接复用用户现有的** [`CHNISam/agent-skills`](https://github.com/CHNISam/agent-skills/tree/master)：
- [`git-workflow`](https://github.com/CHNISam/agent-skills/blob/master/git-workflow/SKILL.md)：分支/PR、Conventional Commits、源码历史；但**以本仓库既有 develop/master 规则优先**。
- [`release-please`](https://github.com/CHNISam/agent-skills/blob/master/release-please/SKILL.md)：版本/CHANGELOG **人工审阅提案**，不直接驱动平台发布。
- [`install-skills-global`](https://github.com/CHNISam/agent-skills/blob/master/install-skills-global/SKILL.md)：如需向 Codex/Dot 等分发，**从 canonical 源做 dry-run 再应用**，不可手改生成副本。没有必要创建全新“CI/CD 总控 Skill”。

**建议受控引入的外部辅助 Skills**（已读取 `SKILL.md` 主体，来源为 GitHub 组织维护的**社区贡献内容**，不代表经 GitHub 官方审计）：

| 用途 | 选型 | 规则 |
| --- | --- | --- |
| **主 Skill：减少 CI 浪费** | [`github-actions-efficiency`](https://github.com/github/awesome-copilot/tree/5269f7ea2d6c3a9bfda5ed878b6726cf509121fd/skills/github-actions-efficiency) | 先量测、再按有证据的收益优化；不可削弱 required checks |
| 辅助安全审查 | [`github-actions-hardening`](https://github.com/github/awesome-copilot/tree/5269f7ea2d6c3a9bfda5ed878b6726cf509121fd/skills/github-actions-hardening) | 最小 token 权限、固定 Actions SHA、不可信输入和公开仓库/自托管边界 |
| **不采用** | [`github-release`](https://github.com/github/awesome-copilot/blob/5269f7ea2d6c3a9bfda5ed878b6726cf509121fd/skills/github-release/SKILL.md) | 针对普通 GitHub 库的发布操作，会与当前 GIL、原生平台、人工审核/Tag 时序冲突 |

安装属于**后续小型单独 PR**：先审 `references/` 和所用脚本，锁定上游完整 commit SHA `5269f7ea2d6c3a9bfda5ed878b6726cf509121fd`，只安装所需 1 个主 Skill（hardening 可按需审查，不要求全部 Agent 安装），做 dry-run/行为验证，再采用现有分发器定向部署；**本设计 PR 不安装、不覆盖 Agent 全局目录**。

## 独立实施与验收（不阻断本次发布）

1. **Spike PR（最先）**：检查基础 GIL 的合法可复用来源及外部 MCP 条件；在干净 hosted Windows 上**只试一次**最小可行样包，证明 SHA/收据、读回正确；不动真实客户端、不上传敏感原始资产。失败就记录阻塞和最小替代方案，不强行引入本地自托管日常构建。
2. **Artifact PR（Spike 通过才做）**：单独受控 `workflow_dispatch`，冻结 SHA、复用已过 CI、生成/核验 GIL 收据、同输入候选去重。测试失败、错误 SHA、版本/开关变化、过期/篡改、重复申请、缺工具、取消/重试；保留旧原生构建命令作为应急手动后备。
3. **晋级 PR（官方验收合同成熟后）**：原样下载并核对 SHA；同一候选完成官方导入/ready/PC/手机/负载、人审；**真实平台发布成功**再按已有 SOP 归档 Release、Tag 与 `publications.json`。不自动点击发布，不把 CI 当平台验收。

本次范围止于**可执行设计、经核实的 Skill 选型和后续验收条件**；不与正在发版的 PR、CI 分片或用户桌面争抢资源。

## 原始技术依据

- [GitHub Actions — Store and share data with workflow artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [GitHub Actions — Dependency caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [GitHub Actions — Workflow syntax / workflow_dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Actions — Security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [Google Release Please](https://github.com/googleapis/release-please)
- [GitHub awesome-copilot（按 SHA 读取并审阅）](https://github.com/github/awesome-copilot/tree/5269f7ea2d6c3a9bfda5ed878b6726cf509121fd)
