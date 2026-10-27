# TASK-20 开发附件

## 当前约定

2026-10-27 用户要求补齐轻量版本管理与原生更新公告。原先“正式首发 v0.1.0”约定已被替代：Alpha 使用无后缀 `0.x.x`，未来正式参赛首发目标为 `v1.0.0`。10 月 22～27 日的 14 个源码版本已按提交历史回溯整理，当前代码版本目标为 `0.10.1`。历史 Tag 表示源码切点，不冒充旧 Alpha 已发布记录；详细目录见 [版本一览](../versions/README.md)。

使用 `CHNISam/agent-skills` 的 release-please / git-workflow，保留现有 develop/master 分工。Release Please 仅手动产生版本提案与 CHANGELOG，不因日常合并创建 Tag、GitHub Release 或发布游戏。版本事实、静态公告时间边界、下一次 Alpha 与正式首发步骤统一见 [发布操作单](../PUBLISHING.md#版本与公告2026-10-27-起)。

## 实现与验收范围

- 主菜单常驻「更新公告」，默认查看当前包中的最新源码版本，支持历史切换、关闭和返回。空记录明确展示空状态；有平台发布凭证时显示发布日期，否则只显示版本日期。
- 复用 Lua 原生 UI、主题和现有构建。公告正文与 Alpha 历史直接来自 CHANGELOG；真实平台发布凭证仍仅由 `data/release/publications.json` 关联；不增加联网接口、数据库、存档、已读状态、小红点或自动弹窗。
- 测试版本一致性、空记录、历史切换、关闭/返回、输入隔离和更新数据后的构建结果；当前 PR 完整 Quality 成功后集成。离线测试与平台原生实测分开报告。
- 本轮不修改战斗、地图、存档或 master，不向平台发布或报名，不建立重复任务。

## 发布收口仍待真实证据

## 2026-10-27 版本管理收尾证据

- PR #247 的最终 HEAD `f09549a29ae32f87120af6f6b92de3ca320ab360`：Licenses inventory 与完整 Quality（四个 rules 分片、presentation、engineering-posix、check）全部 SUCCESS。2026-10-27 17:08（北京时间）已 squash 合入 develop，实际提交 `fa93ac9ff23e7e5cbcf74813d1f9fa776219a314`。
- [版本索引](../versions/README.md)中 14 个节点均核对主线祖先关系、北京时间日期；13 个历史注释 Tag 指向索引原提交，`v0.10.1` 指向 `fa93ac9`。原子推送后用 `git ls-remote --tags origin` 核对全部 14 个 Tag 对象及 peeled SHA；没有覆盖 Tag，也没有创建 GitHub Release 或平台发布记录。
- 沿用 release-please / git-workflow Skill。配置 `versioning=default`、`bump-minor-pre-major=true`、`bump-patch-for-minor-pre-major=false`；对照 [Release Please v17.6.0 策略源码](https://github.com/googleapis/release-please/blob/v17.6.0/src/versioning-strategies/default.ts)，`0.10.1 + feat → 0.11.0`，仅 fix → `0.10.2`。这里只核对策略与配置，没有调用线上版本提案。现有回归验证 workflow 仅 `workflow_dispatch`、目标 develop、`skip-github-release: true`；普通提交不会触发发布。
- `npm run build:data` 后执行 `node --test --test-concurrency=1 tests/release-notes.test.mjs tests/release-notes-ui.test.mjs tests/native-audio-release-provenance.test.mjs`：32 通过、0 失败、6 项 Windows 符号链接权限跳过。Lua 宿主 9 组含实际 14 版公告双向切换、每版逐页往返、首末边界、关闭重开及旧菜单输入隔离；另有触摸/手柄取消与长 Unicode 回归。最终 UI 专项重跑 4/4 通过。Backlog 门禁通过。
- 本轮未占用鼠标键盘，未构建/导入千星奇域候选，也没有真实设备日志、截图或手机触控证据。原生平台公告显示、切换、分页、关闭、输入隔离仍须按本轮授权窗口实测；不以离线宿主测试替代。TASK-20 保持 In Progress，平台交互及实际发布凭证相关验收项保留未勾选。

## 正式发布归档边界

TASK-6 依赖保留用于正式投稿凭证，不阻塞本轮已授权的离线工具和公告实现。实际发布验收项保持未完成，直到用户完成发布并取得作品/投稿成功证据。届时版本号、交付提交、构建 hash、说明与作品身份必须一致，注释 Tag 指向已验收的原交付提交，不指向事后凭证提交；发布后不移动 Tag、不复用版本号。
