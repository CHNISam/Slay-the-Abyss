# TASK-4.21：敌人意图几何同值提交

基线 `fafcc29f35c5c0b7e08f28a98c1397e8f45ed2f6`，独立树 `feat/intent-geometry-cache`，Node `v24.22.1`。已核对 PR473 分工并在评论 `6591476184` 认领；不触碰 PR476 的两份架构文件或配置、主题。

## 最小改动

仅替换 `abyss_battle_render_actors.lua` 中图标、数值、点击区的六次尺寸/位置 setter。两份弱 native 键缓存使用每次 `install` 新建的无回指 token；相同 native 对象的 A→B→A writer、重绑、新对象均重新提交。成功返回（包括 nil）后才缓存；false 与 throw 均撤销旧承诺。

setter 可能在应用前或后重入另一个 renderer。pending identity 检测重叠写；重叠完成顺序不明确时不缓存。`pcall` 只保证外层 throw 之后清除内层成功承诺，随后用 `error(result,0)` 重新抛出原错误，不吞异常。`alive=false` 仍进入原生验证。首帧保持原调用顺序（图标 size→position、数值 size→position、点击区 position→size）；非几何写入原样保留。

`source-conservation.json` 实际证明：逆掉六处 setter 替换、两个局部 helper 和 binding token 后，生产源码逐字等于上述基线。没有改布局值、色彩/透明度、可见性、图片/文字、粒子、动画、输入、玩法或 RNG。

## 可重放的 RED → GREEN

先 `npm run build:data && npm run build:ui`。均执行真实生产 Lua 与生成 Theme，原生 API 是仓库 mock，不是手机。

| 场景 | 基线 size / position | 修后 size / position |
| --- | --- | --- |
| 1敌，300帧，含首帧 | 900 / 900（各897同值） | 3 / 3（0同值） |
| 2敌，同上 | 1800 / 1800（各1794同值） | 6 / 6 |
| 3敌，同上 | 2700 / 2700（各2691同值） | 9 / 9 |
| 4敌，同上 | 3600 / 3600（各3588同值） | 12 / 12 |
| 5敌，同上 | 4500 / 4500（各4485同值） | 15 / 15 |
| 真实 Host 挂载 BattleUI，首帧之后300次 update | 900 / 900 | 0 / 0 |

- `node scripts/test-lua.mjs tests/lua/intent_geometry_cache.lua`：21组覆盖位置、宽高、位数/乘号、portrait后备、隐藏返回、owner与重绑、替换对象、六目标 false/throw 及恢复旧/新值、死亡原生 guard、setter 应用前后重入、嵌套成功后外层 false/throw、首帧写序。见 `module-green.log`。
- `node scripts/test-lua.mjs tests/lua/intent_geometry_host.lua`：Host 创建真实 BattleUI 后驱动该组件 update；完整 run/RNG 对象图的身份与字段不变，idleClock仍前进，三轮真实牌库覆盖返回保持暂停/同actor，几何、可见性、文字、点击回调和父子结构不变；默认卸载、新战斗及 disable 释放实例。见 `host-green.log`。
- 基线重放使用 `git show <基线>:src/lua/abyss_battle_render_actors.lua` 注入独立 Fengari 进程的 `package.preload`，运行同一最终夹具，不改生产文件。见 `module-red-final.log`、`host-red.log`；均因真实重复提交而非零。
- `node --test --test-concurrency=1 tests/intent-geometry-cache.test.mjs`：7/7通过，包括上述两入口和五项精确变异负控：忽略owner、移除alive、缓存false、缓存重叠写、外层throw保留内层承诺。变异各有唯一锚计数、非零与指定失败断言，临时入口退出即删除，并复核生产文件未变；`targeted-tests.log`。

## 相邻与工程验证

`adjacent-lua.log` 八份原入口串行通过：`mobile_render_write_cache`、`intent_face_clearance`、`monster_intent_particle_game_ui`、`monster_intent_particles`、`battle_overlay_surface_retention`、`battle_overlay_surface_safety`、`original_monster_death`、`original_monster_escape`。包含正常/精英/Boss 1–5怪意图边界、原粒子顺序/重入退休、死亡与逃跑、覆盖页暂停/旧输入/恢复；没有改变测试阈值或超时。

固定 hash Luacheck 1.2.0 通过仓库 `setup:lua-static` 恢复后，`node scripts/check-engineering.mjs` 通过：320模块、5036/5036测量、1853依赖边、15条历史告警且零新增，原复杂度硬门槛保持。`npm run check:native-ui-contract` 6/6通过。`check:syntax`、`verify:backlog`、`git diff --check` 通过。日志仅规范化制表符与行尾空白，内容分别见 `engineering.log`、`native-contract.log`、`basic-checks.log`。

`test:related -- --base origin/develop --plan` 因 Backlog 文件未映射要求 Full，见 `related-plan.log`；本轮遵照范围不重复完整CI。没有运行完整 `npm run check` 或 `check:test-strength`，不将本地定向检查当作精确SHA的全部托管Quality/Licenses；独审与发布由主控另验。

## 保留的失败与边界

初版夹具把点击区 position→size 的失效错误误归为size未触发，已分离早一步setter；原 `module-red.log` 保留，最终基线重放以 `module-red-final.log` 为准。首次Host探针用 `GameUI:update` 会按既有合同推进 `run.elapsedSeconds`，因此完整图断言失败；改为驱动真实已挂载的 `BattleUI:update`，没有删除字段断言。alive负控初锚误覆盖原图片缓存第三处，已缩窄为本切片两处精确锚。两项构造失败保留于 `test-construction-errors.log`，不计通过。

Backlog CLI 初始缺失；按主控明确授权，从官方npm恢复固定 `backlog.md@1.53.0` 至 `/tmp`，读取 overview/execution/finalization 并仅追加 TASK-4.21 notes，Furinya/状态/优先级/未勾AC3均保留。首次npm默认cache目录不可写，改用 `/tmp` 缓存后成功；没有手改任务或安装未知工具。

仅证明冗余原生几何提交消除，不证明手机FPS、P95、冷载、GPU成本或玩家全部卡顿根因。没有用户桌面/Codex、GUI、官方导入、实机、发布、master或Tag操作；本地提交未push/开PR/合并，AC3继续未验。
