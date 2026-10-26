# 战斗代次回归夹具修复

PR210 继承的 develop 基线在 `tests/lua/louse_colors.lua` 完整状态比较中失败。该分支仅修改执行权登记脚本，未修改生产战斗。Linux 使用当前源码及 JSON 也能复现，因此不是 Windows 换行或数值差异。

逐字段比较 `Run.startCombat` 生成的实例和独立 `Combat.new` 参考实例，`louse_pair` 与 `cultist_solo` 的唯一差异均为 `combat.combatGeneration`：实际为 1，参考实例缺少该字段。

`2291de41` 已让 Run 在成功构建战斗后赋予并递增代次；`45ba918` 的参考夹具手动补入了遗物信息，但遗漏该 Run 所有的字段。修复属于测试夹具，不改变生产队列、随机流、战斗或数值。

## 修改边界

所有调用该参考构造器的场景都从全新的 Run 开始且只启动一次战斗。因此先分别确认运行实例和实际战斗实例的代次均为 1，再给独立参考实例设置固定预期 1。继续逐字段比较完整状态，不排除代次、不删除断言，也不从未经验证的实际字段推导预期。

仅修改已有 `louse_colors.lua`。其他十六类遭遇的完整状态断言就在该文件第五部分，无需创建新的 `encounter_groups.lua`。

## 验证

- 缓存优先安装依赖并重新生成当前 JSON 对应的 Lua 数据。
- 第一部分覆盖颜色选择分支与真实分组构造；第五部分覆盖其他遭遇的完整独立状态。
- 在临时副本删除新增参考字段，确认原完整状态断言恢复失败；错误代次也必须被新增固定值断言拒绝。
- 不执行全量检查，不与已有 CI 全量任务竞争；该回归不构成游戏实机验收。

本轮本地结果：数据重建成功；`node scripts/test-lua.mjs tests/lua/louse_colors.lua` 为 52 通过、0 失败；`node scripts/test-lua.mjs tests/lua/louse_colors_slice_5.lua` 为 53 通过、0 失败。`npm run verify:backlog` 通过。

两份临时副本验证了断言敏感性：删除新增参考代次字段后，原第一部分完整状态比较恢复 4 个失败；把实际战斗代次改成 2 后，新增固定值断言明确拒绝。临时副本运行后删除，生产源码及仓库测试未用于保存变异。当前 SHA 的 CI 和受控合并仍需分别确认。

执行者为 `codex-v4-regression`，独立 session `7794f8ea-6cff-4711-af80-204c3be2f669`，TASK-67 通过受限登记 `original-v4-67` 领取。Assignee 保持 Furinya，不改其他执行者或迁移隔离记录。
