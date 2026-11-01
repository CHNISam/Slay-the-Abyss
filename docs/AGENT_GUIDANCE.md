# 指引维护与机械门禁

默认上下文只保留入口和无法由仓库工具完整执行的边界。操作流程按需读已有文档；历史决定留在 Git、任务与专项证据，不再追加到 AGENTS。

| 要求 | 已有执行机制 |
| --- | --- |
| 模块职责、函数规模、依赖与静态告警 | config/architecture.json、check:architecture、check:lua-static |
| 测试有效性与原生 UI 合同 | check:test-strength、check:native-ui-contract |
| 任务范围、负责人及优先级 | verify:backlog |
| 候选身份、截图与 UI 检查项 | verify:delivery、verify:ui；按各自接受的证据范围判定 |
| 许可、流量、PR 历史及合并检查 | Licenses/inventory、check:network、Quality、GitHub Rulesets，见 CI.md |
| 默认指引保持精简且入口可用 | check:guidance；在 npm run check 和 Quality impact 中执行 |

check:guidance 将 AGENTS 限为 80 行 / 5000 个 Unicode 字符，Claude 及 Cursor 适配器各限 16 行 / 1000 字符；检查 Markdown 本地链接不越出仓库且目标存在、npm run 命令存在、适配器链接 AGENTS，拒绝额外二级规则章节。新规则优先加入现有检查或回归测试，再用一个入口指向其事实来源。预算只约束默认加载文件，不限制产品或技术文档；不通过拆分成默认必读附件规避预算。

这些检查不能证明自然语言承诺已被遵守。键鼠窗口必须由用户本轮明确授权；实机体验与设备覆盖需对应候选证据；应急合并仍遵循 CI.md 的指定 PR/SHA 批准流程。保留这些短边界，不声称它们已被自动化。
