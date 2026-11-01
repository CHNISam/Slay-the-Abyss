# 核心分支保护与基础设施应急

用户2026-10-26授权直接配置GitHub原生规则并在隔离场景验证。任务范围只有服务端规则、现有协作说明和证据；不改工作流、游戏代码、测试断言、其他工作树或成员角色。

## 实际规则

完整API读回和测试响应见[结构化证据](../evidence/branch-rules-20261026.json)，正常与应急操作见[CI流程](../CI.md)。

- Ruleset25870646覆盖master/develop，active，禁止non-fast-forward和deletion，bypass名单为空。
- Ruleset25870648覆盖master，active，必须PR并解决讨论，不绑定CI，不要求额外他人批准。
- Ruleset25870651覆盖develop，active，必须PR、解决讨论、GitHub Actions app15368的check/presentation/engineering-posix；strict=false。
- 后两份规则各只有User111138384（CHNISam）和User337201427（v5g95m7t8m-max），均为pull_request。没有RepositoryRole/Admin/Write或always豁免。
- 第二人角色仍为Write。新规则全部active并读回后才移除旧develop保护；无ownership遗留和双层规则死锁。master未删除或重建，未改核心分支内容。

## 实测

[PR220](https://github.com/CHNISam/Slay-the-Abyss/pull/220)使用只含probe.txt的孤立根提交，无生产祖先和工作流。Owner本轮请求已授权该安全场景；失败状态仅为隔离分支的safety-probe-required，不是故意破坏真实CI。

| 场景 | 实际结果 |
|---|---|
| 无匹配bypass时，Owner尝试合并失败检查的PR | HTTP405，Required status check is failing |
| 无匹配bypass及配置PR-only bypass后，直接更新/强推/删除 | 均HTTP422，状态失败/禁止强推/禁止删除 |
| 配置PR-only bypass后，提交错误HEAD SHA | HTTP409，Head branch was modified |
| 同一失败检查、精确HEAD、同步REST PUT /pulls/220/merge | merged=true，无需--admin |
| 单独复制master规则，无CI且没有PR，白名单Owner尝试快进 | HTTP422，Changes must be made through a pull request |
| 同一master规则的强推/删除 | 均HTTP422 |

批准测试HEAD为`e72bbdf1b5ee845a56e1a942f6757fc25d1fc3f4`，合并提交`39517c8a0f3e4ea51f95de68c078cd352f2ee20b`，执行身份CHNISam。已删除所有本轮隔离规则和测试分支；GitHub自动删除了已合测试head，清理先确认其不存在，再核对测试base的merge SHA后删除。真实PR220保留审计记录。

## 验证边界

本机仅有CHNISam的登录。没有使用第二人凭证，也没有第三个普通Write身份；未完成这两种身份的真实调用。无匹配豁免时Owner也被阻止，且服务端规则没有角色豁免，这是普通Write不能绕过的规则证据；不把它冒称第三账号实测。第二人的User/pull_request配置和Write角色均已读回，但其独立身份实际调用仍待具备该身份的Agent验证，不要求升级管理员。

GitHub无法判断聊天批准或基础设施故障。两个用户有常设的PR-only技术权限，Agent必须按CI.md把每次使用绑定Owner明确批准的PR、完整SHA及范围。正常开发依然核对三个作业实际success；GitHub原生Required Checks本身接受skipped/neutral，未为此另建Harness。

本轮不需要游戏客户端或桌面输入。文档变更走正常PR和完整Quality，不把本轮安全测试授权套用到生产文档PR的应急豁免。仓库完整游戏回归结果以该文档PR当前SHA的CI为准；本轮实际验证对象是原生规则的授权与拒绝行为。
