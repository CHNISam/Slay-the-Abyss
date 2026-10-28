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

原始 PR、Ruleset、job 日志及本地全量盘点保存在根 `.artifacts/engineering-health/`，不提交凭证。原始统计与最终清理、当前 SHA 和耗时在验收后补齐；未取得最终 CI 证据前 TASK-79 保持进行中。
