# 原生开回合编排

固定基线为 `b4ac63145689b9dd632db100eee49087f6182b39`。本切片只在 Combat 同模块中提取临时能力清理、按应用顺序入队能力、普通/首回合抽牌、抽牌后能力四项职责。保留 `p=state.player` 捕获位置、两处能量检查、callback 拒绝/异常、finish/drain/event 顺序；实验协议未改。没有增加模块、动态加载或公共 API。

## 本轮测量

机器证据见 [native-turn-orchestration-20261104.json](../evidence/native-turn-orchestration-20261104.json)。固定 Node24.18、Luacheck1.2.0、luaparse0.3.1；当前全量 `check-engineering` 采集全部323模块，旧 Combat 完整源码另由同一 Luacheck 与 AST 测量替换当前模块，其他源码未变。复杂度之和只统计函数，不含模块块。

| 指标 | 前 | 后 |
| --- | ---: | ---: |
| 开回合入口 CC / 行跨度 | 22 / 57 | 12 / 37 |
| 四项新职责 CC | — | 2、4、5、3 |
| 全库函数 / 全部函数与模块测量 | 4779 / 5102 | 4783 / 5106 |
| 函数 CC 总和 | 29376 | 29380 |
| CC>15 / CC>30 | 282 / 78 | 281 / 78 |
| 全库最高 CC / 最长函数跨度 | 82 / 1004 | 82 / 1004 |
| >1000行文件 | 2 | 2 |
| 唯一依赖对 / require位置 | 1507 / 1876 | 1507 / 1876 |
| 全图 SCC / 成员 / 内部调用位置 | 1 / 104 / 805 | 1 / 104 / 805 |
| 精确静态告警 | 15 | 15 |

函数 CC 总和增加4来自四个新函数的基础路径，原分支未删除。收益是入口职责清晰和可执行局部门槛，不宣称减少全局分支或运行时加速。结束回合、长构造器与104成员依赖环仍需独立治理。

## 可重复验证

先按工具链生成 data/UI/theme/map 布局。固定 Node24.18 执行：

```powershell
node --test --test-concurrency=1 tests/native-turn-orchestration.test.mjs tests/responsibility-complexity.test.mjs
node scripts/test-lua.mjs tests/lua/native_turn_orchestration.lua
node scripts/check-engineering.mjs
node scripts/check-test-strength.mjs
npm run check:native-ui-contract
npm run verify:backlog
npm run check:guidance
backlog doctor
```

- 差分固定完整旧源gzip与SHA256，正常CI不依赖Git历史。旧新分别在独立VM执行12场景，比较状态、别名、队列、RNG、事件及返回/异常；只省略既有trace合同的catalog/rules/sourcePools/statusDefinitions四类目录，其他键均访问。追踪只在差分driver开启，普通Lua入口保留全部断言而不输出大型轨迹。
- 场景含普通/首回合/originalV4、Power应用顺序、Brutality、Toolbox/innate、post-draw与Evolve、callback拒绝/抛错、两处溢出、已结束/开回合致死。5个生产源码变异（漏消耗innate、颠倒Brutality、拒绝后继续、普通回合错误追加innate、post-draw提前）均须由带标记行为断言拒绝。
- 协调者复验差分与复杂度17项通过；五个已有Lua入口 warped_tongs、statuses、original_v4_contract、watcher_mantra、class_mechanics_integration 全部通过。工程门禁通过；M1–M4全部 killed_by_assertion；原生启动/mock/lifecycle 6项通过。任务、指引与doctor通过。
- 独立审查另以“删除清理调用”负对照验证 rage 必须清除；最终精确提交身份与完整CI另记，不以dirty树预审代替。

没有构建候选、官方导入、真实ready或设备性能取证。完整托管CI、合并与合后push仍待；任务保持In Progress，不把局部整理或本地测试写成M7整体完成。
