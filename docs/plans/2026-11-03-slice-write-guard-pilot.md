# M7｜零模型调用的代码切片写入边界：首轮试验

## 目的

验证“把冲突预防变成机械约束”，而不是再建立一个 AI 调度服务。**Backlog 定义目标，切片边界决定允许写入的文件**。仍保留原 `develop` PR、独立复审、完整 CI、合并后当前 SHA 验证。

## 首轮唯一新增约束

- 仅对命名为 `slice/<lane>/<slug>` 的新 PR 生效；原有 `feat/` / `fix/` PR 不受影响。
- `scripts/check-slice-scope.mjs` 使用已存在的本地 Git diff、固定代码所有权清单进行确定性校验；不调用模型、不读取 GitHub API、不创建新 Runner/完整 CI。
- 三个试验性 lane：`actor-damage`（伤害结算）、`battle-hotpath`（战斗 UI 热路径）、`ci-cost`（CI 开销测量）。每个 lane 的精确写入文件列于脚本，且同一个文件不得属于两个 lane。
- 对已声明的 lane，越界修改、未经授权的共享 Backlog/文档/配置/CI 修改、跨 lane 重命名均在现有 Quality impact 作业中失败。修改清单由集成者统一处理；切片 Agent 仅把证据留在 PR 描述及测试中。
- 新文件或其他公共接口不自动获准：先由集成者审查写入边界，再扩充 lane / 执行集成 PR。不要靠放宽匹配符号绕过。
- 新增测试由现有 `tests/*.test.mjs` 自动纳入原回归，无第二套门禁。

## 使用示例

```text
slice/actor-damage/extract-steps   → 仅允许 actor 与对应测试
slice/battle-hotpath/hand-cache    → 仅允许 UI 热路径与对应测试
slice/ci-cost/runner-profile       → 仅允许成本测量脚本与测试
```

当前单一代码库、现有 Lua `require` 路径、原 CI 运行时和严苛的合并证据合同保持不变。

## 边界和未解决问题

1. 这是 **opt-in 的文件写入边界试点**，不是自动任务拆分器，也不能防止两个 Agent 同时领取同一个 lane。并发领取仍由已有协调者安排；如果必须允许完全自治的竞争领取，需要另加原子分配，不应伪称静态边界能解决。
2. 不同文件的修改仍可产生接口/行为冲突。必须通过契约、回归、独立审查和合入后验证发现，不能把 Git 无文本冲突当作玩法正确。
3. 不恢复已退役的 Remote Task Claim 全局锁；不把历史 PR 自动标记为已符合本规则；不自动发布或修改 master。
4. 只有 GitHub Actions 真正运行且对应 Required 检查成功，才能声称远程门禁通过。本地单测和计划不能替代当前 SHA 的 CI。

## 成本与下一步判定

- 运行期模型调用：0；额外独立 CI job：0；新增操作为已有 impact 作业内一次本地 `git diff`。
- 先用 2–3 个明确互不重叠的实际切片检验：越界写入拒绝、共享任务文件零修改、集成返工与 CI 时间无明显上升。
- 若大多数任务天然需要共享修改，说明模块和接口边界仍不成熟：优先调整架构，而不是引入 Agent 调度平台或扩大任务锁。
