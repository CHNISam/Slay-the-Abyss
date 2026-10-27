# Host 菜单初始化性能修复

保留原 game_ui_phase_four 的26例、全部断言和默认30秒。CI run40381585084/job121778939690在第23例之后超时。按 performance-oracle 先测量再修，仅移除标题页未使用的预览 Run/Map；未改规则、分片或 runner。首批 UI 基717750d7，本树计划基a913dd59。

## 实测热点

ignored build/host-init-profile.lua 临时包装 GameUI/Run/Map/Profile/Presentation、Events.frame、C.copy、F.control，运行原完整26例。表为 inclusive 秒，父子调用相互包含，不能累加。exclusive 明细见机器证据。

| 调用 | before 次数/秒 | after 次数/秒 |
|---|---:|---:|
| GameUI.new | 26 / 3.886874 | 26 / 0.291270 |
| 菜单内 Run.new | 26 / 1.116413 | 0 / 0 |
| 菜单内 Map.generate | 26 / 1.930342 | 0 / 0 |
| 真正 Start 的 Run.new | 26 / 2.830478 | 26 / 2.522139 |
| 真正 Start 的 Map.generate | 26 / 1.765656 | 26 / 1.533622 |
| Profile.prepare（Run内） | 26 / 2.089283 | 26 / 1.833401 |
| Presentation.prepare | 26 / 1.000610 | 26 / 0.844740 |
| F.control根构造 | 78 / 0.887910 | 78 / 0.760583 |
| Events.frame根调用 | 932 / 0.124736 | 932 / 0.111071 |

标题页26份未使用 Run和26份Map直接测得3.046755秒。frame/控件复制不是此初始化热点，没有引入缓存或 caller 隔离豁免。同一临时仪器 before wall20.902秒、after14.476秒，均26/26；无仪器原文件按默认30秒通过26/26，wall16.269秒。此本地单次对照有环境与仪器开销差异，不等于当前SHA的CI承诺。

## 实现与语义验证

GameUI 仍构造 MapUI/NodeUI 控件和监听，仅将其初始绑定为空 owner 的隐藏状态，未绑定时 render/导航/确认拒绝，不创建假 Run/Map。原 Start 完整调用私有 Run、Presentation、Map 工厂，全部成功后按原顺序发布。没有旧Run/Map复用、输入identity缓存或数据复制豁免。

新增测试旧实现真实RED为 `menu constructed unused Run/Map owners`。GREEN1.413秒，覆盖两个菜单零工厂调用、退出取消、resize/update、Run/Map分别失败重试、结束后的重启失败保持旧Run/Map/控件 owner、成功后新owner、Start前caller编辑仍生效，以及 caller/两Run/两战斗深层字段隔离。性能目标没有改写成松动的wall-clock断言。

既有 classes_failure6例2.138秒、seed/restart7例4.100秒、chapter-map3例3.698秒、prologue10例2.989秒全部通过。原26例文件未改，Git LF与工作树CRLF各自hash及归一化比对保留在[机器证据](../evidence/m3-host-init-perf-20261027.json)。

架构139模块/681边通过。固定Luacheck保持107条历史诊断；31条只迁移位置(GameUI15/MapUI10/NodeUI6)，按原文件/诊断源行/列/代码/消息一对一匹配，shadow owner引用只更新行号，无新增豁免。Battle主render≤10、每个受管函数≤15的绝对门禁保留并通过。TASK74不重开；最终CI由父线程负责，不声明整M3或平台验收。

## 本地命令

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/test-lua.mjs tests/lua/game_ui_owner_initialization.lua
& $node scripts/test-lua.mjs tests/lua/game_ui_phase_four.lua
& $node scripts/test-lua.mjs tests/lua/game_ui_classes_failure.lua
& $node scripts/test-lua.mjs tests/lua/game_ui_seed.lua
& $node scripts/test-lua.mjs tests/lua/map_ui_chapters.lua
& $node scripts/test-lua.mjs tests/lua/game_ui_prologue.lua
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

原始仪器和输出保留于本独立树 build/host-init-*，不加入生产或常驻性能框架。没有平台、前台、键鼠或GIL操作。
