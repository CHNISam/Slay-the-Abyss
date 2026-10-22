# 交接说明

更新：2026-10-23。内部提交硬线 2026-10-30；正式发布、赛事报名由人执行。

先读 AGENTS.md、docs/SCOPE.md、docs/TOOLCHAIN.md。每次会话先运行 `backlog instructions overview`，任务只通过 CLI 更新。

## 当前代码与分支

- 远端 https://github.com/CHNISam/Slay-the-Abyss；日常基线 develop，功能走 feat/* 和 PR，master 只接受带标签的正式 release/hotfix。
- 本轮功能集成分支 feat/backlog-sprint，工作树 `.worktrees/runtime-integration`。根目录旧 develop 有既有未提交 Backlog 改动，不要覆盖或强制重置。
- 先比较当前 HEAD 与 origin/develop，再领任务；旧工作树的领取记录与基线可能已经落后，不能据此重复开发。不要在多个 agent 中共享同一修改边界。
- 已批准美术基线是 PR #19；角色为荧（岩元素），保留单手剑。以 UI_DESIGN.md、原型、截图和 ui_theme.json 为准，不回退风元素旧方案。

## 已有功能与验证范围

- 六表内容基线：37 张运行契约卡、19 普通敌人变体、14 普通遭遇、3 精英、1 Boss、7 遗物、7 药水与9状态。完整75卡仅在 data/reference/warrior75.json 溯源，不能称75张可玩。
- Lua 战斗、初始十张卡、奖励入组和状态时序已有测试及独立复核。当前可售普通/罕见/稀有卡为17张，高级效果尚未全部支持；TASK-16 的30+目标仍未完成。
- 地图核心生成15层分支、合法导航、快照和恢复；view.complete 仅表示抵达Boss。
- 本轮原生控制器接起菜单→地图→七类节点→战斗/奖励→返回路线，以及失败重开和Boss胜利结果页。节点服务含营地回血/升级、商店买卡/遗物/按UID删牌、宝箱、最小金币/药水事件，实际修改本局资源并防重复领取。
- 随后已继续TASK-14：七遗物按combat_start/combat_end触发，七药水可消耗并生效。两场原数值战斗验证跨节点资源/永久卡UID保持、新遗物下一场生效和临时状态清除；为覆盖购卡，仅提高该测试的初始金币。最终本地门禁为99项JS（93通过、6权限skip）、120组Lua通过、11项Python（10通过、1权限skip）。日志在build/task-14-verification.log。
- 控件树、中文显示和主题由构建器生成；详细接线、测试范围与缺口见 CLIENT_UI.md。PR29整合已保留develop批准稿战斗卡面/扇形/C档/四态按钮，以及滚动地图/圆节点/图标/呼吸；旧手牌矩形面板和三页地图不再用于完整入口。节点和商店视觉、状态图标、完整动画等仍有缺口，平台美术验收尚未通过。
- 独立复核发现并修复荆棘反杀后仍推进死者意图；界面审查修复奖励阶段遗漏战后回血。地图和交易审查未发现额外缺陷。
- PR29 冲突整合随后同步 PR38 地图强制楼层校验（develop `e07757a`），最终本地检查：JS 130项（124通过、6权限跳过）、Lua 139组通过、Python 12项（11通过、1权限跳过）。清除 Lua 生成物后的独立 `test:lua` 也通过；最新全量日志为 `build/merge-latest-check.log`。药水目标与效果提示已按独立审查修复，真实平台验收仍未完成。

`npm ci --ignore-scripts` 后运行 `npm run check`。该命令检验JS、内容、Lua与Python表现；Windows缺符号链接权限时对应测试明确skip，Linux CI补足。生成物位于build，不入库。Node需22+，UI表现构建还需Python3标准库，可用ABYSS_PYTHON指定路径。

本地控件测试使用原生API测试替身，不能证明实际平台字体、触摸分发或设备预览。十五层流程测试降低测试数据敌人HP，仅证明接线；另有原数据初始卡组完整战斗测试。原数值通关与平衡仍须TASK-5。

## 接下来能做的任务

1. TASK-10 / TASK-11 / TASK-12：完成平台真实界面取证，尤其手机/主机文字排版和状态/路线可读性；按批准稿继续还原。
2. TASK-13：七节点规则和本地界面已有，平台流程仍须验收。
3. TASK-14：遗物/药水本地规则与入口已接通，继续做真实平台跨节点及重开验收。Lv.4退出续局不是首发前置。
4. TASK-16：补高级卡效果，确保30+实际可用及营地升级；TASK-15补完整遭遇表现/行为。
5. TASK-17：接平台正式settleStage，验证Boss胜利、失败、重开；现有本地结果页不等于平台结算。

TASK-24的批准原型与其落地状态分别记录，不因本轮功能面板存在就关闭美术任务。

## 工具链与人工核验

以TOOLCHAIN.md为唯一来源：原神 G:\Genshin\Genshin Impact Game\YuanShen.exe；MCP D:\MiliastraTools\genshin-miliastra-mcp。用MCP前必须读miliastra://workflow与miliastra://platform-rules；MILIASTRA_ALLOW_LIVE_WRITE保持0，只写副本。

TASK-1已有取证：名为“杀戮深渊”的本机超限模式存档由list_maps识别，mapId1073741825；收益功能及实名认证已由用户确认；奇匠Lv.2已由用户确认。赛事报名入口仍待人工核验，不能再把“无存档”“收益未开通”当当前阻塞。

本轮未进行平台编译、存档导入、实机试玩或投稿。平台编译通过、存档写入成功、游戏操作验证、正式投稿成功四项分别记录。发布步骤见PUBLISHING.md；投稿最多2次且不可更换，必须由人完成。
