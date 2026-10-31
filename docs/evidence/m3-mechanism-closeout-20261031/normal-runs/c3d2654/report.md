# c3d2654 正常规则自然流程批次

源码：`c3d2654beee31fdd011db0535228e063b657ab8a`。独立工作树 `/workspace/m3-natural-followthrough`，运行前干净。全部使用现有公开观察策略、生产Run/Nodes/Combat及原300秒/seed预算，无生产/地图/牌组/HP/库存/RNG/期望修改。

| Seed | 结果 | 层 | HP | 动作 |
|---|---|---:|---:|---:|
| 75 | defeat | 16 | 0 | 179 |
| 505 | defeat | 16 | 0 | 267 |
| 1 | defeat | 16 | 0 | 169 |
| 17 | driver_blocked | 3 | 88 | 38 |
| 99 | defeat | 16 | 0 | 218 |

本批4次真实战败、1次driver阻塞，全部保留；没有新增自然跨幕或两幕胜利，不能称第二种完整通关构筑。记录到21/75种永久获得、18/75种普通play动作打出，完整差集见current-cohort/card-coverage.json。

seed17第38动作的公开Living Wall初始forget带uid=1，生产返回invalid_event_choice。`abyss_living_wall.lua:48`禁止choose_card之前提交UID；初始forget应先不传UID推进阶段。当前helper因初始option带picker就提前选择UID，属于driver阶段协议问题；本轮冻结源码不修、不改策略绕过、不把它算战败。完整动作及失败前后状态在seed-17.json.gz。

current-cohort/保存本批原summary、5份gzip及现有coverage脚本原结果；source/与source-identity.json保存源码及四策略身份，current-artifacts-sha256.json固定产物字节。baseline-tracked/完整保留243ae1b旧3seed及历史开发失败文件，baseline-sha256.json可校验；未混称同源。

所有newRunConstructionResetVerified均为true，仅证明同seed新Run构造隔离，不是Host胜败重开。无官方导入/ready、PC或实体手机新证据；未提交、推送或改PR。产物目录及脏工作树均保留可恢复。
