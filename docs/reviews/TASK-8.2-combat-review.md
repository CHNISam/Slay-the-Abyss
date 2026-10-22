# TASK-8.2 独立战斗核心审查

审查者：`/root/content_review`，未参与核心或工具实现；日期：2026-10-22。初审基线：`962ce135c80c73d06ca2902b9bf850a55faac170`；最终复审基线：`bdef54a30831cc9b22e9f0f73a14419caa5f33f9`。分支：`feat/task-8-2-review`。

结论：**当前 TASK-8 基础核心范围无剩余阻断，可进入后续卡牌、状态和界面实现。** 初审发现一项抽牌契约阻断、一项跨战斗对象所有权缺陷，均由作者修复并独立复验。以下结论仅针对离线 Lua 核心与工具，不代表 37 张全部可用、平台编译、导入存档或游戏验收。

## 独立验证

读取 `src/lua/abyss_combat.lua`、`tests/lua/combat.lua`、`scripts/test-lua.mjs`、`scripts/build-lua-data.mjs` 及其 JS 测试。独立运行 `npm ci --ignore-scripts` 和 `npm run check`：53 项 JS 测试、六表校验、生成数据模块、15 项真实 Lua 测试全部通过。

另外创建系统临时目录下的 Lua 探针，以 `node scripts/test-lua.mjs <临时文件>` 执行，未修改生产代码或既有测试：

| 探针 | 初审结果 |
|---|---|
| 同一抽牌动作不得重抽本次溢出牌 | 失败，exit 1，观察到 2 次溢出牌重洗 |
| 一场战斗的 catalog 修改不影响其他战斗及输入 | 失败，exit 1，其他战斗及输入同变为 999 |
| 错误 target 类型/范围、未知 uid、unsupported 牌 | 通过，递归比较命令前后完整 state 相同 |
| 敌方格挡保留至玩家攻击、下次自己行动才清空 | 通过 |
| 禁用 package/io/load/loadfile/dofile 后核心执行 | 通过 new/play/endTurn 冒烟 |
| 同种子 10,000 次 RNG 比较及种子范围检查 | 通过 |

复审后完整重跑 `npm run check`：53 JS + 15 Lua、语法与六表校验全部通过。上述两个初审失败文件未经修改，分别重跑返回 `status:0`、空 stderr；其余原子性、格挡、受限全局与 RNG 探针全部保持通过。另补独立敌人 catalog 所有权断言：修改 a 的敌人定义不影响 b 或输入，测试通过。审查者只修改本报告和任务 CLI，生产修复由核心作者提交。

错误 target 探查包括 `false`、字符串 `"1"`、table、0、-1、1.5、99、nil；unknown uid 为 table。原子性检查包含牌堆、能量、敌我状态、事件、种子和 catalog，较既有仅抽查部分字段的断言更强。

## 初审问题与最小复现

### B1：单次抽牌重新洗入本次满手溢出牌（阻断）

`M.draw` 满手时直接将牌加入 `state.discard`，抽堆耗尽后又立刻洗入弃堆；因此当前动作刚溢出的牌会被本动作再次抽取，违反 README“该牌进入弃牌堆且不再次抽取”。有限循环避免了无限循环，但没有满足这项语义。现有容量测试只断言最终手牌数和总实例数，所以在此缺陷存在时仍然通过。

运行环境先设置模块路径并加载核心和生成数据，然后执行：

```lua
local C = require("abyss_combat")
local d = require("abyss_data")
local deck = {}; for i = 1, 15 do deck[i] = "strike" end
local s = C.new(d, {deck=deck, enemies={"jaw_worm"}, seed=42})
C.draw(s, 20)
local n = 0
for _, e in ipairs(s.events) do
    if e.kind == "reshuffle" then n = n + 1 end
end
assert(n == 0, "overflow-only discard recycled inside same draw: "..n.." reshuffles")
```

初始手牌 5、抽堆 10、弃堆 0。动作结束手牌 10、弃堆 5，但记录 2 次 reshuffle，均来自本次生成的溢出弃牌。独立断言真实失败，runner 返回 exit 1。

建议由作者修复：当前动作的溢出牌先隔离，动作结束后再并入弃堆，或采用等价机制；不能只修改测试预期掩盖 README 契约。

复审结果：**已解决**。`M.draw` 新增局部 overflow，循环结束才合入弃堆；原始最小失败例转绿。既有容量测试补充“本次没有重洗”断言，因此不再仅以最终数量判断通过。

### B2：catalog 与输入及其他战斗共享可变引用（中风险）

`M.new` 对规则及敌人实例复制，但 `index(data.cards.cards)` 和敌人定义索引直接保留输入条目的引用。牌实例升级逻辑虽然使用复制，但一场战斗对 catalog 的修改仍能污染其他战斗与全局输入。这使“独立状态”保证不完整，后续牌实例/生成/升级逻辑很容易误触。

```lua
local a = C.new(d, {deck={"strike"}})
local b = C.new(d, {deck={"strike"}})
a.catalog.cards.strike.effects[1].value = 999
assert(b.catalog.cards.strike.effects[1].value == 6,
       "battle catalogs alias across states")
assert(d.cards.cards[1].effects[1].value == 6,
       "battle catalog aliases immutable data input")
```

初审时两处实际值均变为 999，第一个断言失败，exit 1。建议复制进入战斗的 catalog，或以明确不可变 API/所有权隔离保证替代；单纯要求调用者不改局部状态并不能阻止跨状态污染。

复审结果：**已解决**。`M.new` 对 cards/enemies 两类目录条目深拷贝后再索引；原始最小失败例转绿。既有独立状态测试新增 catalog 跨实例与输入不变断言，审查者额外检查敌人 catalog 也通过。

## 拆分复审

作者同时将伤害、格挡、状态与 actor 回合钩子移入 `abyss_actor.lua`，效果支持列表及派发移入 `abyss_effects.lua`；core 保留状态与牌堆编排。逐函数重读确认事件结构、状态公式、目标选择和结算次序没有因机械拆分改变。core 通过可用的 require 加载两个普通模块，effects 以参数接收 combat API，无循环 require，也没有新增 package/io/load 等依赖。全部行为和失败探针在拆分后重跑通过。

## 工具、平台与范围判断

- 数据单源成立：构建器读取并验证六份 JSON，再生成忽略于版本控制的 `build/lua/abyss_data.lua`；核心不维护第二份手写数值。无效或缺失输入会在写输出前拒绝，既有输出保留，相关真实 Lua 加载与 UTF-8/控制字符回环测试通过。
- runner 使用 Fengari 的 `-e dofile(...)` 路径，避免上游 CLI 位置参数错误退出码问题。独立缺陷断言返回非零；已有测试覆盖语法错误、缺文件、运行错误与死循环超时，没有发现吞错造成的通用假绿。B1 属于行为断言覆盖不足。
- 核心未引用 package、io、load、loadfile、dofile、os、平台全局、文件系统或 JS API；require 只在测试侧使用。Lua 5.3 常规语法与受限全局冒烟支持离线兼容判断，但 Fengari 不等同于官方客户端。未执行 MCP/GUI 或官方平台编译。
- 当前可支持 starter 和基础 damage/damageAll/block/draw/energy/状态增减；未知 advanced op、条件及 X 费用在 `play` 改状态前拒绝。逐张对 37 张基础定义以 999 能量探查，20 张接受、17 张明确拒绝，复审前后相同。其余持续能力、药水、遗物、完整状态框架与 37 张全部可用属于后续 TASK-9/11 范围，本轮不能宣称完成。
- UI 获得的敌方 intent 是复制，显示后执行该索引再推进，死亡敌人不行动；已有测试与额外格挡探针支持该结论。同种子序列可复现，乘积维持小整数范围，未依赖 math.random。

后续状态与高级效果实现时，应补致死出牌余下效果、多段反伤/同时死亡和状态清理验收；本轮只评价当前支持范围，未以未实现效果的缺失扩大阻断。
