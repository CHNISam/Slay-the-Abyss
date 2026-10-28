# 仓库健康治理（TASK-79）

基线为 2026-10-28 的 develop `7a87de3aec83281221a3680b0d02aeb5b41aa2ba`。根目录有大量其他执行者的未提交改动，本轮使用独立工作树；不执行桌面输入、不改共享历史。

## 验收与根因

验收：逐个证明分支成果去向；删除已吸收且无独立内容的残留，保存独立提交、脏文件及唯一证据；最新 develop 的 check、presentation、engineering-posix 和 Licenses/inventory 全成功；不增加完整回归、超时或锁。

最近记录显示 #292、#294 已关闭，#286/#290/#295/#296/#297/#298/#299 先后直接或组合交付。源分支与集成分支反复合流，导致历史呈现证明、布局/交互 mock 与新界面脱节。Ruleset 允许 merge/rebase/squash，短命分支规范只有文字；Licenses 缺少同引用取消机制。多个 PR 在完整 Quality 仍失败或运行时已经合入；Owner 的 PR-only 豁免具有绕过能力，但正常开发规则并未授权以红灯代替验收。本轮不使用豁免。

最新基线 Licenses run [40679423982](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40679423982) 已成功。#299 已补 35 条离线 UI 证据记录，包含 22 张正式战斗图；每条绑定实际字节 hash、生成 HTML/脚本与设计说明，明确是离线渲染，不是官方导入或设备截图。本轮复核已有真实修复，不重复伪造来源，不把 inventory 成功当商用权利结论。

Quality run [40679423990](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40679423990) 的真实断言失败包括新战斗布局/状态背板/意图详情、共享卡框 Color mock、历史呈现源逆向以及新角色面板组合。保留原游戏断言、历史 golden 和预算，只修批准设计变化的对应关系及缺失 mock 接口；历史与当前显示证明分别验证。

## 最小机械约束

- 修改既有 develop Ruleset：仅 squash、线性历史、既有 inventory 必需；master 的发布合并方式不变，防强推/删除规则不改。
- Quality 现有一个分片增加完整 PR 提交历史检查，比较精确 SHA 并分页；拒绝跨 feature 合并提交及不完整读取。无额外工作流或完整测试重复。
- Licenses 加原生同引用 concurrency，取消已被新提交替代的运行。
- 原 PR 模板/AGENTS 补依赖先合 develop、短切片与合后安全收口。提交量与代码行数不设武断门槛；真正独立成果不强行合入或删除。

## 证据与收口

已安全移除40个已吸收的干净工作树、49条本地分支（含9条无工作树引用）；删除退役 coord/task-claims、已吸收 start-flow-polish/ui-focus-return 三条远端引用，删除操作以精确 SHA lease 防止误删随后推进。远端仅保留 develop、master 和独立未完工的 dedup 草稿。没有开放旧PR。

独立成果没有遗忘：#289去重草稿的435文件WIP尚未验收，不合入也不删除；`fix/pr260-room-fixtures` 的商品手柄Focus只读说明及六组严格回归尚未吸收，保留原树/分支，交由既有商店与手柄任务评估。25个盘点时脏树（包括本轮工作者当时的在途改动）不清理、不解决他人冲突。旧 source-port 扩展和 #284 调度为已退役替代方案，完整历史在恢复bundle，不假称逐字合入。

#292独有的工程、路由、证据13文件与最新develop完全一致；最终59960a17的三份既有bundle均verify通过。全引用84MiB恢复bundle先验证，后移除本地分支；各树的build/.artifacts、独有截图/日志/候选完整移至根 `.artifacts/engineering-health/preserved/<树名>-<sha>/`。详见[精简清单](../evidence/engineering-health-20261028.json)，完整逐提交patch/blob审计仍在本地，不将大审计库提交CI。

实际UI修复只有两处：未知召唤意图保留unknown主图；敌人整体下移20像素，使最高后排意图上沿204与原提示条下沿212保留8像素间隔。原53战斗用例、6回放种子、38地图用例保留；历史79543/79757/81392写入合同不改，当前73316写入独立逐序核对，严格源逆向与缺写/改值/乱序负例仍在。测试平台补Color接口，按批准新卡框/状态背板/意图详情迁移旧外观断言，不改游戏数值、随机或超时。worker仅补失败夹具路径/退出码摘要，原输出及失败传播不变，既有8项回归通过。

原始 PR、Ruleset、job 日志及本地全量盘点保存在根 `.artifacts/engineering-health/`，不提交凭证。当前完整CI和实际合后develop的结果在本PR/最终验收记录补齐；未取得最终CI证据前TASK-79保持进行中。平台导入/实机不在本次工程治理范围，没有占用桌面。
