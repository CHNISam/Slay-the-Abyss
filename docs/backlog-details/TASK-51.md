# 免费模型委派约定的验证记录

用户于2026-10-24确认采用“Codex决策和验收，OpenCode免费DeepSeek优先执行低风险任务”的日常分工。本次只增加项目AGENTS.md的简短约定，不安装skill、不开发调度框架、不修改全局配置。

## 原生CLI调用

OpenCode CLI 1.18.24；Provider `opencode`；模型 `deepseek-v4.1-flash-free`。目录声明输入、输出、缓存读写价格均为0，variants包含`max`。本次实际使用`--variant max`并成功返回。

PowerShell最小费用锁定示例（在当前进程设置；实际任务另加所需工具和路径权限）：

```powershell
$env:OPENCODE_CONFIG_CONTENT = @'
{
  "model": "opencode/deepseek-v4.1-flash-free",
  "small_model": "opencode/deepseek-v4.1-flash-free",
  "enabled_providers": ["opencode"],
  "provider": {"opencode": {"whitelist": ["deepseek-v4.1-flash-free"]}},
  "share": "disabled"
}
'@
opencode run --model opencode/deepseek-v4.1-flash-free --variant max --format json '明确的任务范围和验收标准'
```

调用前运行`opencode models opencode --verbose`，从中只提取目标模型；运行`opencode debug config`时在进程内解析，仅输出model、small_model、enabled_providers、模型白名单和所需权限字段，不能原样打印可能含凭证的配置。定价和档位必须按当次目录核验。

示例在独立子进程中使用最方便；若在共享终端运行，应先保存原OPENCODE_CONFIG_CONTENT，结束后恢复原值（原来不存在则移除），避免影响后续交互会话。

本次只开放四份指定文档的read工具及`backlog instructions overview`，禁止编辑、网络工具和再次委派。权限按合并后的顺序匹配：全局配置与进程配置合并后，末尾的通配`"*": "deny"`曾隐藏所有工具；改用显式工具限制，并让文件/命令规则先deny再allow具体目标后，真实工具调用成功。不能只看原始JSON，必须核对有效配置和JSON工具事件。

两次带`--pure`的OpenCode调用返回403 FreeTierError；相同免费模型在用户交互式CLI及后来的普通`opencode run`成功。去掉`--pure`是成功条件的关键差异之一；本轮也修正了工具权限，未做单变量复测，故不宣称已证明403的内部原因，也不归因于“免费套餐不可用”。默认沿用已成功的普通原生调用。

## 真实任务与Codex验收

- 任务：读取AGENTS.md、HANDOFF.md、MILESTONES.md和M1-CLOSEOUT-20261024.md，核查当前交接摘要的重复及状态矛盾，交付行号、依据和最小修订建议；不修改源码或Backlog。
- 成功会话：`ses_e92d165bfffeOoHlhz1uhLQ3wo`。真实执行1次bash规范查询和4次read，均completed；最终step_finish为stop，CLI退出码0，3个step_finish费用合计0。
- Codex对照read工具返回的带行号快照复核：[DeepSeek原始报告](TASK-51-REPORT.md)中的核心发现成立：HANDOFF第9/11行重复且仍称M1未完成；第18/20行旧候选被写成当前状态；MILESTONES第92行“只有M0符合归档条件”与开头M1已归档冲突。
- 这些行号对应当次读取快照，后续文档可能移动；本次不应用修订建议，不把历史候选hash、实机结果或UI/手机验收边界改成通过。核查报告是独立可验收交付，并非已修复文档。
- 本地原始事件、有效配置、报告及独立验收保存在根`.artifacts/opencode-delegation-retry/`；只在仓库提交必要的脱敏报告和摘要，不提交凭证或完整会话。
- 本次不存在收费模型调用，事件费用为0；没有读取账单后台，Codex本身仍消耗额度，单次通过也不等于已经证明长期稳定性或量化节省比例。

工作区核验：已有CLAUDE.md内容哈希和根目录tracked diff保持不变；HANDOFF/MILESTONES在并发工作中更新过，不能声称两文件始终不变。根Git reflog记录其他会话快进develop，故报告按各read事件的实际快照验收，未将初次读取的旧行号当作当前行号；本次执行者仅有5次只读工具调用，规则修改在独立工作树完成。

OpenRouter按用户后续授权另试`recursive/flint-v1.0:free`，固定主/辅助模型、仅开放该Provider/模型，设置零价格上限并禁止Provider回退。修正权限后真实执行1次bash及4次read，但最终`reason=length`、无核查报告，故未通过验收；记录费用0。目录里的DeepSeek V4.1 Flash 1017为收费条目，未调用。目录“零价”不保证auto等路由最终免费，不能用作收费回退。

官方配置与权限语义参考：[OpenCode配置](https://opencode.ai/docs/config/)、[OpenCode权限](https://opencode.ai/docs/permissions/)；OpenRouter当次定价参考[官方模型目录](https://openrouter.ai/api/v1/models)。有效配置及实际事件优先于界面默认模型或模型自报。
