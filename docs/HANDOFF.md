# 交接说明

更新：2026-10-23。最新状态与逐关口验收标准见 [MILESTONES.md](MILESTONES.md)。这是当前交接，早期快照已被本轮审计取代；历史可从 Git 查阅。

- **M0已完成**（TASK-1/7/22全部Done）。仅初步定位发布入口；正式表单/赛事资格仍在M4 TASK-18/19，投稿在M5 TASK-6。
- **唯一主冲刺M1**。本地战斗、卡组、UI与九状态已合并且本轮验收；TASK-8.3/9.1/10.4也已收口。
- M1剩余：TASK-2最小场景配置与导入、TASK-3.1完整UI候选导出、TASK-3.2官方导入、TASK-11.1九状态真实显示、TASK-3完整实战。不要将CI当实机。
- 平台实际尝试：副本配置和Lua写入完成；完整UI在第21步被MCP的60直接子控件限制拒绝。先修TASK-3.1超限容器分组和查找路径，复跑控件回归，再导出/导入/真实战斗。原存档hash未变，见 [平台证据](evidence/milestone-platform-audit.json)。候选原始文件保留在整改worktree的build/platform-audit，供继续使用。
- M2本地地图/七节点/库存TASK-12/13/14已Done，平台部分在TASK-12.3。M1关闭之后才转M2主冲刺；不依赖Lv4退出续玩。
- M3仍缺至少30张实际可玩牌、完整遭遇与原数据通关/正式结算。37条数据不等于37张可玩，当前合法奖励/商店池17张。PR37尚未合并。
- M4集中美术UI、多设备、候选完整复验、实际表单及物料；M5只保留成功投稿和版本记录。TASK-21投稿后研究及TASK-26跨区发行不阻塞首投。
- 已批准美术依据仍是PR19 / 91ae349，读docs/design/UI_DESIGN.md并复用共享ui_theme。必要平台差异需留证据，C档点选保留。
- 用户确认奇匠Lv2、实名认证/收益已开通。等级达标不等于文字已经实测。原神/沙箱/MCP路径以 [TOOLCHAIN.md](TOOLCHAIN.md) 为准；先读workflow/platform-rules，live write保持0，发布由人完成。
- 本轮隔离分支feat/milestone-cleanup基于origin/develop77744e2；根develop原未提交任务、vendor、既有worktree与开放美术PR全部保留。不要在根目录直接pull覆盖本地修改。
- 合并规则：PR当前SHA的Quality各项全绿后squash进develop。用户不要求分支保护，不将其作为未完成项。

验证：本轮npm run check通过，JS124通过/6权限跳过、Lua153通过、Python12通过/1权限跳过。基线develop远端Quality39860850079成功。具体任务/PR/平台证据和后续关口见MILESTONES.md；当前实时状态以Backlog CLI与GitHub为准。

上手：先读AGENTS.md、SCOPE.md、TOOLCHAIN.md及MILESTONES.md，运行backlog instructions overview，再查任务。Backlog变更必须用CLI，不直接编辑其Markdown。
