# 免费模型委派约定

Codex负责决策、集成和验收；适合的低风险短任务优先委派免费OpenCode。长任务拆成范围明确、上下文最少、可独立验收的小段，默认使用模型支持的最高推理档位。关键设计和高风险逻辑由Codex承担。

## 已验证的调用配置

2026-10-24验证环境为OpenCode CLI 1.18.24，模型`opencode/deepseek-v4.1-flash-free`，档位`max`；当次目录的输入、输出及缓存价格均为0。调用前只查询目标模型的当前定价和档位，不能把历史配置当作当前免费保证。

```powershell
$env:OPENCODE_CONFIG_CONTENT = '{"model":"opencode/deepseek-v4.1-flash-free","small_model":"opencode/deepseek-v4.1-flash-free","enabled_providers":["opencode"],"provider":{"opencode":{"whitelist":["deepseek-v4.1-flash-free"]}},"share":"disabled"}'
opencode run --model opencode/deepseek-v4.1-flash-free --variant max --format json '明确的任务范围和验收标准'
```

主模型、辅助模型和Provider白名单均锁定免费条目，禁止收费回退。沿用普通原生调用；只开放任务所需工具和路径。共享终端中须保存并恢复原进程配置。

核验有效配置时只输出模型、Provider白名单和必要权限字段，不打印可能含凭证的完整配置。权限拒绝先停止并修正配置，不换工具绕过。细节见[OpenCode配置](https://opencode.ai/docs/config/)、[权限](https://opencode.ai/docs/permissions/)和已提炼的[opencode-delegation技能](https://github.com/CHNISam/agent-skills/pull/7)。

## 执行与验收

- 先串行短切片；90秒无事件则停止，由Codex接管，不把无事件直接归因为限额。
- 依据真实工具事件、产物和Diff验收；退出码0、费用0或模型自报完成均不等于任务通过。
- Codex独立核对结果与原始输入；只有稳定产出降低监督成本后才扩大跨度或并发。
- 同范围的Backlog操作合成短批次并逐项读回，不并发修改共享任务库。

用户于2026-10-24明确报告免费路径限额，恢复时间未知。该路径保持暂停；没有明确恢复依据时不试探、不轮询额度、不切收费模型。获得恢复依据后，只用一个真实短任务验证，再决定是否继续。普通临时限流交原生CLI处理，不另建重试或额度管理系统。

## 保留证据

- [DeepSeek原始报告](TASK-51-REPORT.md)：一次文档审计完成5次真实工具调用，Codex复核核心发现成立，事件记录费用0；未证明长期稳定性或净节省。
- [当天用量脱敏聚合](../evidence/opencode-usage-20261024.json)：历史记录，不代表平台配额、重置时间或剩余额度。
- 本地原始事件及有效配置：根`.artifacts/opencode-delegation-retry/`；不提交凭证、数据库或完整会话。
- 已核对版本源码：[JSON运行事件](https://github.com/anomalyco/opencode/blob/57e80556975fca613a116447ddecc8dcbc1f33b2/packages/opencode/src/cli/cmd/run.ts#L781)、[原生重试](https://github.com/anomalyco/opencode/blob/57e80556975fca613a116447ddecc8dcbc1f33b2/packages/opencode/src/session/retry.ts#L42)。只作该版本行为依据。
