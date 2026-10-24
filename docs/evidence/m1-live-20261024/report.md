# M1 本轮实机证据 · 2026-10-24

固定诊断副本 `01dd39274f42ddaccf73e68fdf7bcbe4986919f96c297e94e6d6c4483bef297a`，源码 `c0f20766519a248f1a02df60985f3a832aa529b1`，官方存档 `1073741841`，真实 run `ced168e4-7e7a-4699-97b4-4873610e0c41`。本轮已取得客户端日志订阅、原生画面及新日志：837条显式打印、ready、九状态完成和预览阶段均可核对，运行器期待4/4满足。运行器完成不等于全部画面验收通过。

| 项目 | 本轮独立审核结论与范围 |
|---|---|
| TASK-11.1 九状态 | 九类名称/数值、叠层与触发衰减或永久保持的详情画面通过诊断范围审核；54状态记录及54次整局只读断言具备新日志。实际保存43/54个独立详情阶段，缺失11项在审核原件逐项列出。 |
| TASK-10.7 确定数值 | 14个预览阶段记录未瞄准4、普通目标4、易伤目标6、取消恢复4、多段、群攻基础值、费用及整数资源；仅一次真实出牌，日志确认一次伤害6。历史真实红/负控证据已关联，并非本轮重跑旧原生客户端。 |
| TASK-10.8 意图与说明 | 原生画面确认复合行动、状态承担者及完整说明；悬停/长按/点按使用明确标记的生产回调合成事件，不认证物理鼠标或手机输入路由。 |
| TASK-4.1 格挡/血条 | **旧候选未通过**：飞行防御牌暂时覆盖角色HP数字及血条。运行器成功、无显式脚本fault不能覆盖该可见缺陷。后续修复必须另列新候选与二轮实机；本包不认证新修复。 |

状态主审核：[status-live-review.json](reviews/status-live-review.json)，新日志逐项核对：[status-live-log-review.json](reviews/status-live-log-review.json)。预览审核：[preview-live-review.json](reviews/preview-live-review.json)。实际失败、原帧与后续修复边界：[block-live-review.json](reviews/block-live-review.json)。这些是原审核记录的原始字节副本，打包器没有更改任务或勾选验收项。

原问题与既有红证据见 [TASK-10.7原问题记录](historical-red/TASK-10.7-original-problem.md)、[确定值旧红日志](historical-red/exact-damage-red.log)、[负控日志](historical-red/exact-damage-negative.log)、[整数资源旧红日志](historical-red/integer-resources-red-corrected.log)及[说明入口旧红日志](historical-red/status-help-red.log)。后续飞牌修复的本地红绿/回归保存在 `later-fix-local-only/`；它们不会改变旧run的失败结论。

官方43模块读回和完整UI身份复核见 [provenance-review.json](provenance-review.json)。原始官方读回以无损gzip保存；`manifest.json`分别记录原始SHA256与压缩文件SHA256。官方嵌入源码匹配不是独立的活动外部Lua运行文件审计。新会话原始日志为 [session-log.gia](session-log.gia)，MCP解码原件与期待结果来自 `run-final-result.json.gz`，可读导出为 [log-decoded.json](log-decoded.json)。

精选原始截图共68张，未改变像素，索引与原件路径见 [selected-screens.json](selected-screens.json)。全部高频帧保留在本地原run目录，其逐文件绝对路径和hash见 [raw-run-inventory.json](raw-run-inventory.json)；没有把数百帧全部提交。本包所有文件的完整性校验见 [package-integrity.json](package-integrity.json)，打包复现脚本为 [build-package.py](build-package.py)。

本轮使用明确的注入夹具与暂停的格挡时间线，不证明自然获取、正常敌人AI、整局通关、物理手机输入、实时节奏或音效。状态详情可读不代表常驻状态chip附近数字全部可读，主UI审核仍需保留该限制；全UI正式门禁和M1整体完成不由本证据包宣告。
