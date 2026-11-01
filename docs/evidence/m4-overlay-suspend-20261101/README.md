# M4：覆盖页保留同战斗怪物容器

基线 `4f42212`，承接 TASK-4.21。仅显式临时覆盖暂停保留当前战斗的怪物容器；默认 `setActive(false)` 仍卸载。GameUI 只允许牌组、药水、菜单/路线/退出确认等覆盖，排除已请求/正在结算、禁用和开场覆盖。仍执行原输入失效、`bindIdle(nil)`、空行/inactive 意图同步；释放原生粒子输出，隐藏保留容器。换战斗、死亡、终态、默认卸载和禁用仍释放，隐藏失败清理并报告，不吞错误。

## 可重复离线事实

同一 cultist 战斗，菜单→只读地图→一次返回，重复10轮：

| 原生替身调用 | 基线 | 改后 |
|---|---:|---:|
| actor instantiate | 10 | 0 |
| actor destroy | 10 | 0 |
| 模板 mock 控件构造 | 350 | 0 |

`baseline.log` / `after.log` 由同一 `loading-diagnostic.lua` 产生；旧探针按 #446 的一次返回行为更新。未出现的调用计数键为0。**日志中的 ms 是带探针开销的单次云端 Fengari 耗时，不是基准、手机耗时、FPS 或改善比例。** 普通构建原生怪物美术开关关闭；这些数值仅证明容器/模板复用，不证明启用图元资源的加载/绘制成本或完整手机卡顿根因。

## 验证

- 新 `battle_overlay_surface_retention.lua`：10轮0建/0毁、完整 run 对象图身份及值（包括随机流/事件队列）不变、同对象恢复、默认false卸载、已暂停再次无参false、覆盖换战斗、结算请求和禁用清理。
- 新 `battle_overlay_surface_safety.lua`：旧Down→覆盖→旧Up/Click不出牌，恢复后新操作有效；暂停idle时钟；隐藏返回false/抛错清理并可恢复复用；覆盖中死亡只退役对应怪物，终态退役余下怪物。
- 基线负控：当前回归加载4f42212的原 `abyss_battle_render_actors`，在“temporary overlay must retain actor identity”失败；原始输出保存在 `baseline-negative.log`，不是测试基础设施失败。
- 既有 `monster_intent_particle_game_ui`、`actor_feedback_lifecycle`、`monster_engine_teardown`、`monster_intent_cleanup_failure` 通过；`player_death_exit_lifecycle` 8项、`menu_input_boundaries_current` 3项通过。
- 原生启动/控件生命周期合同4项通过；JavaScript语法、架构318模块1838边、Backlog/diff检查通过。官方固定Luacheck1.2.0按现有安装脚本下载并验hash后，工程5018/5018测量、无新增诊断、战斗render≤10/受管函数≤15通过（`engineering.log`）。
- `test:related -- --base 4f42212 --plan`要求完整回归，未以局部通过替代；精确PR提交完整CI另验。

复现：`npm run build:data && npm run build:ui`，随后 `node scripts/test-lua.mjs tests/lua/battle_overlay_surface_retention.lua`、`node scripts/test-lua.mjs tests/lua/battle_overlay_surface_safety.lua`，计数用 `node scripts/test-lua.mjs docs/evidence/m4-overlay-suspend-20261101/loading-diagnostic.lua`。

没有新GIL、官方导入、ready、实体PC/手机或启用怪物图元的通过证据；TASK-4.21设备AC保持未勾，不声称手机更快。
