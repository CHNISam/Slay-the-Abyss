# 原创角色合并前置

用户明确要求完整 V4 实施并合并 develop，随后确认仓库已公开、runner 使用 GitHub 官方免费实例。仓库元数据 visibility=public 已验证。

本树承接干净已发布源：TASK-55 `787e4c0b971634b8bfdb43ccc3d65f255873312c` 与 TASK-67 `6f67ae97c1f17f5aac60e5fcdd63005b6c955735`。旧 PR210/212 保留历史并关闭，未冒充已合并。旧 self-hosted 作业收到 shutdown，未视作通过。

`original-v4-68` 在一个 CAS 中完整继承协调者原范围并释放旧 receipt，使用新 session、新分支和独立 worktree；67 已先在干净发布头释放。其余活动 claim 仍互斥，全局 paused、externalUnknown 和全部旧 reservation 保留。本前置不接管 V4 业务源码或旧执行者。

Quality/check 改用标准 `windows-latest`、`pwsh`，其他作业继续 `ubuntu-latest`，未用 larger runner，保留全部命令、每项截止、75分钟全量预算、串行组、当前 SHA 所有权、Git增量引用与大小上限。牌表和旅行者规则均未改。

夹具只补首次独立遭遇的固定战斗代次，继续完整逐字段状态比较。原始执行权32项真实Git测试全部通过；独立复审和有界交接回归通过；夹具105项定向断言和两项退化敏感性检查通过。当前合成头的 CI 必须另验，不复用来源绿灯。随后只通过受控 integrate 合并 develop；真实游戏候选与实机验收由 V4 业务切片另行记录。
