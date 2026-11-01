# TASK-20 开发附件

## 当前约定

2026-10-28 用户确认不再维护游戏内自研更新公告 UI，统一使用千星奇域「奇域信息」原生更新日志。主菜单只保留当前版本号，不显示 Git SHA。此决定替代下方历史记录中的公告交互要求，不把历史实现或回归误记为当前产品验收。

Alpha 使用无后缀 `0.x.x`，正式参赛首发目标 `v1.0.0`。沿用 `CHNISam/agent-skills` 的 release-please / git-workflow 和 develop/master 分工；版本提案仅手动发起，日常合并不创建 Tag、Release 或平台发布。已有 14 个源码 Tag 保持不变；新正式版本 Tag 须内容冻结、必要验证及候选交付后创建，本轮不创建 `v0.11.0` Tag。玩家文案保留在 CHANGELOG，版本与工程历史保留在 [版本目录](../versions/README.md)。

## 实现与验收范围

- 删除自研公告入口、弹窗、历史分页、专用模块/主题/输入隔离及专用测试；菜单显示经过现有版本一致性校验的当前版本号，不携带 SHA 或公告正文载荷。
- 保留 CHANGELOG、package/lockfile/manifest 一致性、候选源码及说明 hash 绑定、真实 publication 证据校验。`data/release/publications.json` 只登记实际有证据的官方发布，不填源码回溯记录。
- 玩家文案供人工填写官方原生日志，潜在「奇域更新速报」曝光不保证。减少重复界面/分页/输入/同步/测试的维护成本，将参赛时间用于核心玩法与品质；决策与四点理由见版本索引。
- 旧面板内的源码公开及许可短文随面板移除，不新增页面/链接/营销主张。仓库许可与版本历史保留。
- 串行验证菜单、开始/退出、手柄和触控以及版本/候选溯源；正常集成仍要求精确 HEAD 完整 Quality，平台导入/实机与实际发布分别留待证据。本轮不改战斗、地图、存档、master 或已有 Tag，不建重复任务。

## 发布收口仍待真实证据

> 以下为保留的历史执行证据，其中公告 UI 交互与展示待办已由 2026-10-28 的移除决定替代，不再要求继续开发或实测旧公告。

## 2026-10-27 版本管理收尾证据

- PR #247 的最终 HEAD `f09549a29ae32f87120af6f6b92de3ca320ab360`：Licenses inventory 与完整 Quality（四个 rules 分片、presentation、engineering-posix、check）全部 SUCCESS。2026-10-27 17:08（北京时间）已 squash 合入 develop，实际提交 `fa93ac9ff23e7e5cbcf74813d1f9fa776219a314`。
- [版本索引](../versions/README.md)中 14 个节点均核对主线祖先关系、北京时间日期；13 个历史注释 Tag 指向索引原提交，`v0.10.1` 指向 `fa93ac9`。原子推送后用 `git ls-remote --tags origin` 核对全部 14 个 Tag 对象及 peeled SHA；没有覆盖 Tag，也没有创建 GitHub Release 或平台发布记录。
- 沿用 release-please / git-workflow Skill。配置 `versioning=default`、`bump-minor-pre-major=true`、`bump-patch-for-minor-pre-major=false`；对照 [Release Please v17.6.0 策略源码](https://github.com/googleapis/release-please/blob/v17.6.0/src/versioning-strategies/default.ts)，`0.10.1 + feat → 0.11.0`，仅 fix → `0.10.2`。这里只核对策略与配置，没有调用线上版本提案。现有回归验证 workflow 仅 `workflow_dispatch`、目标 develop、`skip-github-release: true`；普通提交不会触发发布。
- `npm run build:data` 后执行 `node --test --test-concurrency=1 tests/release-notes.test.mjs tests/release-notes-ui.test.mjs tests/native-audio-release-provenance.test.mjs`：32 通过、0 失败、6 项 Windows 符号链接权限跳过。Lua 宿主 9 组含实际 14 版公告双向切换、每版逐页往返、首末边界、关闭重开及旧菜单输入隔离；另有触摸/手柄取消与长 Unicode 回归。最终 UI 专项重跑 4/4 通过。Backlog 门禁通过。
- 本轮未占用鼠标键盘，未构建/导入千星奇域候选，也没有真实设备日志、截图或手机触控证据。原生平台公告显示、切换、分页、关闭、输入隔离仍须按本轮授权窗口实测；不以离线宿主测试替代。TASK-20 保持 In Progress，平台交互及实际发布凭证相关验收项保留未勾选。

## 2026-10-27 开发透明小切片

- 展示位置为主菜单「更新公告」面板底部、分页/返回按钮上方；静态展示「开发透明 · 源码公开」、用户最终确认的一句介绍「代码已公开到开源社区。」及原创代码的非商用许可。复用原主题和公告构建，不新增页面或输入行为。正文由每页七行改为五行，仍完整分页，不裁切历史条目。
- 根目录 `LICENSE` 实为 PolyForm Noncommercial License 1.0.0；源码公开不等于完全开源或允许商用，第三方内容仍遵循各自授权。
- 保守省略 GitHub 地址、外链按钮和「欢迎查看」邀约。官方[《千星奇域创作者中心服务协议》](https://act.mihoyo.com/miliastra_wonderland/agreement?mhy_presentation_style=fullscreen&id=156266)（2026-08-17）第五条第一款第（3）项限制擅自通过第三方账号、链接等方式诱导用户访问第三方产品或服务。本例未取得静态源码地址的明确许可；这是风险未获确认时的保守选择，不宣称官方全面禁止源码地址，也不提供替代检索暗号或二维码。
- 官方[《奇匠创作守则》](https://user.mihoyo.com/sdk/ugc-agreement.html#/ugc_proto?lang=zh-cn&channel_id=1&app_id=4&biz=hk4e_cn)（2026-08-12）第二条（三）1（2）亦限制违规外部引流、外部诱导及跳转非官方平台；未给本例静态源码地址明确豁免。
- 仅离线构建与宿主回归，不代表官方导入、实机显示或设备验收通过；不创建版本号、Tag、Release 或平台发布，不关闭 TASK-20 原平台/投稿验收项。

## 正式发布归档边界

TASK-6 依赖保留用于正式投稿凭证，不阻塞本轮已授权的离线版本管理及公告移除。实际发布验收项保持未完成，直到用户完成发布并取得作品/投稿成功证据。届时版本号、交付提交、构建 hash、说明与作品身份必须一致，注释 Tag 指向已验收的原交付提交，不指向事后凭证提交；发布后不移动 Tag、不复用版本号。
