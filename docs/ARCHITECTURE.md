# 模块与生成物导航

当前进度与阻塞见 [HANDOFF](HANDOFF.md)，产品范围见 [SCOPE](SCOPE.md)，平台工具和输入协调见 [TOOLCHAIN](TOOLCHAIN.md)。本页用于定位源码职责；实现、离线检查、官方导入和实机验收分别取证。

## 手写源码与职责

Lua手写源保存在平铺的 [src/lua](../src/lua/)；模块名用于 `require`、离线加载和候选打包，整理职责时应保留现有加载路径。

| 职责 | 主要入口 | 修改边界 |
|---|---|---|
| 平台生命周期 | [abyss_ui.lua](../src/lua/abyss_ui.lua) | 连接平台全局、控件、输入与启动诊断，注入界面需要的API |
| 游戏界面编排 | [abyss_game_ui.lua](../src/lua/abyss_game_ui.lua) | 串联菜单、地图、节点和战斗界面；将用户动作交给核心命令 |
| 输入与表现 | [abyss_controller.lua](../src/lua/abyss_controller.lua)、[abyss_battle_ui.lua](../src/lua/abyss_battle_ui.lua)、[abyss_node_ui.lua](../src/lua/abyss_node_ui.lua) | 焦点、回调和视图状态归界面；战斗子视图、节点子页及表现helper按职责拆分 |
| 一局状态与节点事务 | [abyss_run.lua](../src/lua/abyss_run.lua)、[abyss_map.lua](../src/lua/abyss_map.lua)、[abyss_nodes.lua](../src/lua/abyss_nodes.lua) | 持有局内状态、路线与合法操作；奖励、商店、事件等规则在核心提交 |
| 战斗结算 | [abyss_combat.lua](../src/lua/abyss_combat.lua)、[abyss_action_queue.lua](../src/lua/abyss_action_queue.lua)、[abyss_effects.lua](../src/lua/abyss_effects.lua)、[abyss_actor.lua](../src/lua/abyss_actor.lua) | 出牌、动作队列、效果、伤害和状态；职业、敌人及遗物规则通过对应模块协作 |
| 内容与表现源 | [data](../data/README.md)、[主题](../data/presentation/ui_theme.json)、[设计依据](design/UI_DESIGN.md) | 数据和核心决定规则，界面读取状态；主题及批准稿决定视觉，不使用原型演示数值替代玩法数据 |

模块逐项分类与延迟导入审查在 [config/architecture.json](../config/architecture.json)。[架构检查](../scripts/check-architecture.mjs)要求手写模块显式分类：`core`只依赖核心层且不直接访问平台全局，`ui`不依赖`platform`模块，平台API由入口注入。检查还拒绝未知/动态加载和未经审查的循环；函数内导入例外不能绕过层次限制。

## 生成物与构建入口

[scripts](../scripts/)保存构建与工程工具，[tools](../tools/)保存渲染、参考验证和诊断等辅助工具。`build/`按[忽略规则](../.gitignore)保存本地生成物；应修改下表的源并重建，避免手改生成Lua或把旧输出混入候选。

| 命令 | 手写源 / 生成器 | 默认输出 |
|---|---|---|
| `npm run build:data` | [data](../data/README.md)、[build-lua-data.mjs](../scripts/build-lua-data.mjs)；另调用[原创角色生成器](../scripts/build-original-v4.mjs) | `build/lua/abyss_data.lua`、存在原创角色数据时的`abyss_original_v4_data.lua` |
| `npm run build:theme` | [ui_theme.json](../data/presentation/ui_theme.json)、[build-ui-theme.mjs](../scripts/build-ui-theme.mjs) | `build/lua/abyss_theme.lua` |
| `npm run build:ui` | [build-ui.mjs](../scripts/build-ui.mjs)及其布局、地图、主题、文案和卡面渲染依赖 | `build/lua/`中的UI JSON、主题/地图/文案/卡面Lua，以及供离线测试使用的控件树Lua |
| 候选构建 | [build-native-candidate.mjs](../scripts/build-native-candidate.mjs) | 独立候选目录、GIL及实际输入/产物摘要收据；打包集合由`generatedRuntimeModules`声明 |

候选的生成模块集合与UI构建的全部输出用途不同；测试用的`abyss_map_controls`、`abyss_ui_layout`和`abyss_ui_templates`不因存在于输出目录就自动进入正式打包集合。[测试选择器](../scripts/test-affected.mjs)另记录这些生成节点的依赖，用于离线选择相关测试。

## 验证入口

测试位于 [tests](../tests/)，Lua用例位于 [tests/lua](../tests/lua/)；[Lua执行器](../scripts/test-lua.mjs)通过Fengari加载`build/lua`和`src/lua`，构建失败或Lua错误必须传播。

- 小改动先运行`npm run test:fast -- --base origin/develop --plan`或`npm run test:related -- --base origin/develop --plan`查看计划，再去掉`--plan`执行。未知或基础设施改动会保守回退完整检查。
- `npm run check:engineering`执行架构、Lua静态、指定变异和原生UI契约检查。复杂度硬门槛只覆盖[静态检查器](../scripts/check-lua-static.mjs)声明的渲染及职责范围，其他热点保留诊断。
- `npm run check`与当前提交的完整Quality用于合并验收；定向测试不能替代它们。安装依赖、固定工具、交付收据与UI实机门禁见[ENGINEERING](ENGINEERING.md)。

模块数、静态基线和复杂度结果以当前配置及本轮`build/architecture.json`、`build/lua-static.json`、`build/ui-complexity.json`、`build/responsibility-complexity.json`为准；存在源码或通过离线检查不等于内容、平台或实机验收完成。
