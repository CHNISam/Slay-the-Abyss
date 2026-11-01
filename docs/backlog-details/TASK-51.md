# 免费模型委派约定的验证记录

用户于2026-10-24确认采用“Codex决策和验收，OpenCode免费DeepSeek优先执行低风险任务”的日常分工。本次只增加项目AGENTS.md的简短约定，不安装skill、不开发调度框架、不修改全局配置。

用户追加要求：考虑Flash模型在长任务中的能力限制，默认使用支持的最高推理档位；当前已验证Max。长任务拆成短步骤，每段单独给范围、必要上下文和验收，验证与交接后再推进下一段；关键设计和高风险逻辑仍由Codex承担。

后续按用户授权已提炼为跨项目用户级[opencode-delegation skill](https://github.com/CHNISam/agent-skills/pull/7)，通过原有分发工具安装到共享skills目录。源码在技能源仓库，不将该skill复制到本游戏。项目规则仍自包含，skill可用时按其原生CLI细节执行。

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

## 实际收益与质量复核

| 切片 | 实际交付与验收 | 对协作方式的结论 |
| --- | --- | --- |
| DeepSeek Max文档审计 | 5次真实工具调用、完整报告、核心发现复核通过；事件费用0 | 证明这一条执行路径能够完成有价值的短任务 |
| OpenRouter免费Flint | 读取成功，但length终止，没有报告；事件费用0 | 未通过，不能因为免费或退出0而计入产出 |
| 两路隔离文档编辑 | 第一轮相对路径权限匹配错误，执行者重复尝试被拒调用；修正后重试无事件推进，已停止，未采用文件 | 并发实际收益尚未成立，不作为默认能力，不扩大并发数 |
| 地图导航首段代码委派 | 固定免费DeepSeek Max，但5分钟以上无事件或文件改动，停止后由Codex接管 | 不能宣称代码已被模型完成，启动/首响应的卡点未定位；不据此推断模型编码智力 |

本轮协调、权限调试、失败重试和接管增加了耗时；没有测得Codex额度节省或净效率提升，不能把零推理费用当作净收益。后续先串行、短切片、90秒无事件停止、独立验收，在原任务备注中记录结果，只有稳定的合格产出降低监督成本后才扩大任务跨度与并发。地图实现由TASK-4.3单独交付，不计入DeepSeek产出。

## 2026-10-24限额反馈与策略调整

用户亲自试用后报告已触发限额，但不确定是每日还是五小时窗口。这是受限路径应暂停的新依据，不是早先所有无事件调用的已证实原因。本轮不再发模型请求，不用新试跑消耗额度。官方[模型说明](https://opencode.ai/v2/docs/console/models/)确认该DeepSeek条目为限时免费，但本次查阅未得到该账号的额度、重置窗口或剩余量；免费定价不能解释成无限可用。

只读查询本机OpenCode SQLite，统计2026-10-24 00:00至23:46:19（UTC+08:00），脱敏聚合见[当天用量](../evidence/opencode-usage-20261024.json)。不提交数据库、原始日志、提示词或凭证。

| 范围 | 本地assistant记录 / 会话 | 非缓存输入 | 缓存读取 | 推理 | 输出 | 记录总token |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| OpenCode免费DeepSeek，游戏目录 | 35 / 12 | 67,629 | 342,016 | 34,253 | 3,892 | 447,790 |
| 同模型，其他目录 | 2 / 1 | 21,029 | 2,048 | 0 | 9 | 23,086 |
| OpenRouter免费Flint，单独统计 | 5 / 2 | 39,506 | 0 | 33,380 | 189 | 72,793 |

DeepSeek合计470,876个记录token，其中344,064为缓存读取、34,253为推理、3,901为输出。总数已经包含各分项，不能再相加；本地assistant记录含未完成及错误，不等于成功请求数，更不能据此推算“每天约47万”或“五小时约47万”的平台限额。所有这些记录费用字段为0，但不是账单审计，也没有测得Codex额度节省。

独立算术复核发现Flint的分项合计73,075，与原记录total 72,793相差282；原值分别保留，不自行归一，也不混入DeepSeek统计。DeepSeek分项与total逐组相符。

DeepSeek真实工具记录为13次completed、21次error（read 16、bash 3、edit 2）；Flint另有5次completed，但此前因length没有可验收报告。工具完成不等于任务验收。DeepSeek的3条已保存API错误为早期401一次、403 FreeTier两次，未记录能确认本次限额窗口的429/重置证据；失败原因不混算。另一次Backlog登记试跑在117.6秒后停止，事件文件0字节，实际工具调用0；Codex随后通过CLI完成TASK-53。不能把该次无事件确定归因为限额，也不能拿它评价模型是否能操作Backlog。

根据这一天的实际记录，策略调整为：

1. 用户报告或平台明确限额后，暂停该受限路径，Codex继续交付；有明确reset/Retry-After再按其安排，窗口不明就保持未知，不假定午夜或五小时后可用，不轮询试额度。恢复依据出现后，只用一个真实短任务确认，不另发“测试能否回复”请求。
2. 优先消除已出现的权限错误和重复上下文。权限拒绝先停止、核对真实工具/路径，一次聚焦修正；不让执行者换工具绕过权限或反复试错。今天错误计数说明编排成本值得先压低，不能归结为模型智力不足。
3. 将同一范围的Backlog查重、建任务、补备注合成短批次，逐项读回，不并发修改共享任务库。每项都单开会话并加载大段上下文未必省额度；极小的机械操作可由Codex直接完成，有限免费额度优先留给有独立验收价值的小模块、修复和成批维护。
4. 继续默认最高推理档位，靠收窄任务和输入节省额度，不擅自降档。免费主/辅助模型锁定、禁止收费回退、真实Diff/工具验收规则保持有效。
5. 后续分别记录限额反馈、权限错误、原因未明的无事件和质量失败；统计注明日期时区、范围与token口径。不建立新的调度框架或全局配置，不把未知剩余额度、重置时间及净节省写成已测事实。

这次只修订项目规则和Backlog记录；未修改游戏逻辑，断网恢复仍是TASK-53待确认能力后的候选工作。

### 沿用官方实现，不自建额度管理

按用户追加要求，核对已安装OpenCode 1.18.24对应官方标签，固定提交`57e80556975fca613a116447ddecc8dcbc1f33b2`。以下是该版本源码事实，不能当作任意新版或服务端免费配额的承诺。

| 官方现有能力 | 已核对的行为 | 本项目采用方式 |
| --- | --- | --- |
| [原生stats](https://github.com/anomalyco/opencode/blob/57e80556975fca613a116447ddecc8dcbc1f33b2/packages/opencode/src/cli/cmd/stats.ts#L97) | days=0从本地午夜筛选当天更新过的会话；days=1是过去24小时。筛选后的会话按整段消息汇总，不能冒充精确当天请求或平台配额 | 日常优先用`opencode stats --days 0 --models`，不新增持久用量计数器；本次按消息时间限定的只读审计另标口径 |
| [错误分类与延迟](https://github.com/anomalyco/opencode/blob/57e80556975fca613a116447ddecc8dcbc1f33b2/packages/opencode/src/session/retry.ts#L42) | 优先读取retry-after-ms，再读retry-after（秒或HTTP日期），否则带抖动指数退避；无响应头时单次等待上限30秒，策略有5次重试上限；区分FreeUsageLimitError和GoUsageLimitError | 普通临时限流交原生CLI处理，不在外层再套循环；明确耗尽后停止受限进程并接管。服务器等待时间是重试依据，不保证额度届时恢复 |
| [JSON运行输出](https://github.com/anomalyco/opencode/blob/57e80556975fca613a116447ddecc8dcbc1f33b2/packages/opencode/src/cli/cmd/run.ts#L781) | session.error会输出JSON error；session.status只在idle时退出，没有把retry状态输出到JSON流 | 继续保留事件/stderr与必要脱敏错误证据；90秒零事件作为外层交付时间上限，原因仍写未知，不推出未发请求或一定限额 |

本轮实际运行原生`opencode stats --days 1 --models`作交叉核对：DeepSeek显示37条模型消息、输入88.7K、输出38.2K、缓存344.1K，记录费用0；Flint显示5条模型消息。源码将模型表的output与reasoning合并，所以38.2K对应本次分列的3,901+34,253，而非只有最终输出。后续按自然日查询改用days=0；上述数字是展示取整值，不替代精确明细。

免费和Go是不同错误分支，不把Go的小时窗口套给免费模型。官方仓库中[免费额度重置时间议题](https://github.com/anomalyco/opencode/issues/52894)仍有未明确窗口的用户反馈；这是旁证，不是该账号配额证据。没有取得本账号的结构化错误或控制台重置时间前，继续记录“窗口未知”。未增加依赖、代理、探测服务或重试调度代码，未修改全局OpenCode设置，也未发送新的推理请求。
