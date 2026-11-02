# TASK-81 Run API 相关选测漏边

基线：develop `6aa3cf90f0a0734514e8a7dbc29988e628a5c74d`；Linux Node 24.22.1；不操作 GUI。

## 已证实与最小修复

`run-governance.test.mjs` 真实解析 Run 主模块及五个职责模块，校验公开方法及参数名。原动态拼接文件名未形成选择器依赖边；六模块的 related 选集漏掉该测试。修复只把原六个实际读取路径改为完整字面量，保留遍历、expected、所有断言和执行顺序。选择器生产代码、阈值及 CI 不变。

`selection.json` 使用当前仓库源码，旧版本只在内存还原两个测试文件；六个输入各自仅新增该 integration 测试，fast/Lua 选集不变，原选集无删除。无关 `scripts/evidence-files.mjs` 选集逐项不变；未知路径继续 Full。核心改动的完整 CI 仍由既有高风险规则强制 Full。

## 实际验证

- 新 selector 合同配旧 consumer 先红：`src/lua/abyss_run.lua` 没有静态映射；修复后六个输入全部进入 integration。隔离模块只用于验证真实 consumer 的六条读取边，不把测试端注册表当依赖。
- 临时副本只将 `Run.new(data, seed, options)` 的参数改成 `unintendedOptions`：原治理测试失败；修复后的治理测试仍失败。还原源码，两版均通过。原失败为参数列表比较，不是启动或依赖缺失。
- 原版基线/负控耗时约 116/103ms；新版还原后约 114ms。这只是本机单测试取证，不是 CI 整体性能收益。
- `node --test --test-concurrency=1 tests/test-affected.test.mjs tests/run-governance.test.mjs tests/ci-impact.test.mjs`：106通过，0失败、0跳过，12.026s。
- Backlog doctor、`npm run verify:backlog`、`npm run check:syntax`、`git diff --check` 通过。
- 独立复审 `/root/review_governance_selection`：两项独立定向测试通过（约237ms）；另从真实仓库核验六组全选集只加 governance，deleted/data/shared infrastructure 继续 Full，结论 PASS、无阻断。独立日志 `/tmp/task81-independent-review/`，精确提交绑定另记。

原始探针日志保留 `/tmp/m4-task81-governance-probe/`。本切片仅修 related 漏选，保留 integration 分类，未将该测试纳入 fast；未完整远端 CI、未推送、未合并，不勾 TASK-81 性能验收。
