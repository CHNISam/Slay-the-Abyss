# 交接说明

更新：2026-10-23。最新状态与逐关口验收标准见 [MILESTONES.md](MILESTONES.md)。这是当前交接，早期快照已被本轮审计取代；历史可从 Git 查阅。

- **M0已完成**（TASK-1/7/22全部Done）。仅初步定位发布入口；正式表单/赛事资格仍在M4 TASK-18/19，投稿在M5 TASK-6。
- **唯一主冲刺M1**。本地战斗、卡组、UI与九状态已合并且本轮验收；TASK-8.3/9.1/10.4也已收口。
- 当前最高优先级为 P0 真实主流程回归，复用 TASK-3/5/17。完整UI的60直接子控件限制、Color初始化和SetImage参数错误均已修复；v4已实机到15层Boss失败并重开，v5生命/意图修复、v6失败正式结算已实机确认。不要按早期失败快照重复排查已解决问题，也不要将CI当实机。
- 尚缺 Boss 胜利及胜利正式结算、本轮新客户端日志、九状态及跨层资源逐项实机账本。TASK-2配置核验和其他未完成关口保留；完整记录见 [P0-SMOKE.md](P0-SMOKE.md)，早期平台记录保留为历史证据。
- M2本地地图/七节点/库存TASK-12/13/14已Done，平台部分在TASK-12.3。M1关闭之后才转M2主冲刺；不依赖Lv4退出续玩。
- M3仍缺至少30张实际可玩牌、完整遭遇与原数据胜利通关。37条数据不等于37张可玩，当前合法奖励/商店池17张。失败正式结算已实机通过，胜利分支仍待验证；PR37状态以GitHub为准。
- M4集中美术UI、多设备、候选完整复验、实际表单及物料；M5只保留成功投稿和版本记录。TASK-21投稿后研究及TASK-26跨区发行不阻塞首投。
- 已批准美术依据仍是PR19 / 91ae349，读docs/design/UI_DESIGN.md并复用共享ui_theme。必要平台差异需留证据，C档点选保留。
- 用户确认奇匠Lv2、实名认证/收益已开通。等级达标不等于文字已经实测。原神/沙箱/MCP路径以 [TOOLCHAIN.md](TOOLCHAIN.md) 为准；先读workflow/platform-rules，live write保持0，发布由人完成。
- 本轮隔离分支feat/milestone-cleanup基于origin/develop77744e2；根develop原未提交任务、vendor、既有worktree与开放美术PR全部保留。不要在根目录直接pull覆盖本地修改。
- 合并规则：PR当前SHA的Quality各项全绿后squash进develop。用户不要求分支保护，不将其作为未完成项。

## P0 实机冒烟进展

集成工作树 `.worktrees/p0-integration`，分支 `feat/p0-integration-smoke`。沿用 TASK-3、TASK-5、TASK-17；详情及证据见 `docs/P0-SMOKE.md`。v4 实际完成地图、战斗、奖励、商店离开，抵达第15层 Boss 后失败，重新启程正常。v5 用户已确认生命数字、意图及受伤更新正常。商店新版仍待实机验收。

第六版测试副本 `.artifacts/p0/abyss-p0-v6.gil` 已生成（产物位于仓库根目录），正式结算节点图已编译并写入；用户截图已确认失败后进入平台官方结算。Boss 胜利、完整资源账本及本轮新客户端日志仍缺证据；不能宣称完整通关通过。不要再要求用户手动反复勾选日志。保持 live write=0，不改正式存档、不发布。

早期里程碑审计的本地检查与CI记录仍见MILESTONES.md；P0合并后的最终检查以本PR当前SHA的Quality为准，当前实时状态以Backlog CLI与GitHub为准。

上手：先读AGENTS.md、SCOPE.md、TOOLCHAIN.md及MILESTONES.md，运行backlog instructions overview，再查任务。Backlog变更必须用CLI，不直接编辑其Markdown。
