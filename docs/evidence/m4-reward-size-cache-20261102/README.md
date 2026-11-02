# TASK-4.21：奖励布局尺寸写入缓存

基线 `6aa3cf9`，Node `v24.22.1`，只做非视觉设计的原生提交去重。独立树 `feat/reward-size-write-cache`；不改布局、位置、可见性、行序、按钮、动效、玩法或 RNG。

## 可重放证据

- `node scripts/test-lua.mjs tests/lua/reward_size_cache.lua`：真实生产模块与生成 Theme，mock 原生 setter。首帧后300次同状态 render，6目标尺寸提交 **1800 → 0**；十组验证含普通/expanded、独立宽高变化、A→B→A owner、替换对象、部分写入后 false/throw、无 owner 兼容调用及其失败、dead handle。
- `node scripts/test-lua.mjs tests/lua/reward_size_host.lua`：真实 GameUI/BattleUI + 仓库原生 API mock。隐藏奖励区3次 render **18 → 0**；真实 Run.finishCombat → 原生奖励按钮 → picker 入场一次 update **6 → 0**。入场 rise 继续推进，完整 run/RNG 图保持身份和值，六目标及九按钮的尺寸、位置、可见性、交互字段、文字、回调与结构引用不变。最终约3.14秒，原30秒预算不变。
- 三个临时生产变异：保留旧成功缓存、删除 alive guard、忽略 owner，各自被原断言杀死；原文件已恢复。详见 `mutation-*.log`。
- `source-conservation.json`：仅逆掉尺寸缓存及 owner 接线后，两生产文件逐字等于基线，未改其他表现/逻辑。

## 相关验证

五项原 Lua 夹具串行通过：`mobile_render_write_cache`、`reward_flow_parity`、`looter_reward_stage`、`emerald_key_ui`、`ui_stable_writes`，完整输出 `related-lua.log`。

`build:data`、`build:ui`、`check:syntax`、`check:architecture`、`verify:backlog`、`git diff --check` 通过。首次 `check:lua-static` / `check:quality` 因工具缺失未完成（`quality.log`）；随后经授权只运行仓库 `setup:lua-static` 一次，固定 Luacheck 1.2.0 SHA256 校验通过。`node scripts/check-engineering.mjs` 的质量测量、架构与静态门槛全部通过（`engineering.log`），`check:native-ui-contract` 四项通过（`native-contract.log`）。关键四变异结果见 `test-strength.log`。

首次 Host 探针构造因 Lua 最后表达式展开多返回值失败，已加括号纠正；最初向单文件 Lua runner 传多个文件只显示 usage，随后逐文件串行执行。分别保留 `host-probe-construction-error.log` 与 `related-cli-usage-error.log`，不计为成功。

## 边界

这里只证明减少重复原生尺寸提交；不是手机卡顿根因、FPS、启动/P95、GPU 或原生客户端验收。没有 GUI、官方导入、实机、发布/master/Tag 操作。TASK-4.21 AC3继续未验，未关闭任务。未跑完整 npm check / 托管 CI，PR必须另有精确SHA完整CI；`test:related --plan` 因任务文件未映射要求 Full，本地上述聚焦结果不替代它。独立审查由 `/root/review_reward_size_cache` 完成并绑定最终提交。
