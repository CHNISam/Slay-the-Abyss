# 本轮合并后的 beta 稳定性修复

2026-10-30。基线 develop `ef7b3e80093dd737be5496627250269532da001c`，修复 PR #381；任务保持进行中，最终完整 CI、候选及实机分别验收。

## 已复现的问题与修复

- [Licenses 41048769101](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41048769101) 的真实错误为怪物目录来源哈希滞后。PR372 仅新增设计方向说明，原素材和来源类别未变；审查后更新对应哈希。许可证审计及原有 7 项检查通过，PR381 首头 inventory 通过。
- 正式构建真实拒绝入口 `script.nativeMonsterArtEnabled`，报告 `UNKNOWN_API`。参数已登记，但原生入口必须通过 `GetParam` 读取。修复保留 false 关闭、缺省或不可读取时开启的既有语义；新增实际 OnStart 的开/关/缺省/不可读检查。
- 本地完整回归复现 PR379 与 PR372 组合后历史源码回放身份不匹配。原 PR372、art/perf、UI 与最新 feature 证据均不刷新；新增组合层分别还原历史父版本与独立 feature379 来源。未知或部分源码不获得投影许可。
- 架构负对照原来假定首模块为 core；新增 UI 模块后它不再改变输入。现始终切换到另一层，保留原拒绝要求。构建输入保护矩阵补入生产已有的 `art-render-v2.json`，继续检查新输出的输入别名保护和确定性。

## 组合证据如何重建

`tests/fixtures/beta-integration-sources.json` 绑定 35 个完整源身份与逐位置 hunk。history 目标来自 PR379 父 `c42180c71c089bdc4251a3d6a138936ed25c670d` 的真实 Git blob，再进入原 PR372 逆层。feature379 目标从原 feature 基线 `1bfca6261044b92f8065bb83668c358b0a2627da` 正向应用最新 feature witness 的准确 hunk；架构文件 before 身份来自 `157cd1a2c9d3e1cb5c40e374a49840dda7e103f1`。每个 before/after 整体 SHA256 均独立核对，不以当前生产行为刷新历史黄金。

原 feature witness 从 c42180c7 原样归档为 `art-feature-source-layer-pre379.json`，新旧入口明确分流，各自校验 linked owner。真实入口 GetParam 修复在组合层还原到原 feature 记录的源码，当前入口另由真实 Lua 测试及候选平台检查认证。

新增 owner 清理同时保护固定 checkout 与调用方源码根；最外层删除前重新核对全部 beta owner，任一漂移会保留全部新旧文件。独立复审发现的根路径覆盖和部分删除风险已修，贯穿回归覆盖。

## 证据边界

本地日志保留在独立工作树的 `beta-check.log`、`build/beta-*.log`。原完整回归开始后又产生修复，因此它仅用于发现问题，不能认证最终提交；期间新增测试导致的文件枚举变化也不冒充生产回归。最终以冻结提交完整 Quality 与专项复验为准。

本机两个既有符号链接负例遇到 Windows EPERM，未删除或放宽测试，等待云端执行。不因局部通过宣称完整通过。首次正式候选失败保留在 `build/beta-20261030/full/6e77640e-07da-49e6-9650-a2c54f1417a0`，1 error / 247 warnings；不能交付为可玩 beta。后续重建必须使用新目录及独立读回。官方导入、真实 ready、输入、主流程、UI 与平台负载仍须本轮对应证据；发布由人完成。

## 后续统一整合说明

上述 beta 逆层属于 PR381 的历史修复证据。最新 PR377 已吸收事件和美术两条集成线，使用其统一 delivery-source-composition；原生怪物开关来自生成的五类 flags，不再访问不存在的 script 字段。未把旧 beta 逆层再次叠入。TASK-88 记录原样承接后，通过原生 CLI 续记本轮 CI 图片输入与回归修复；完整 CI、候选和设备验收仍分别待核。
