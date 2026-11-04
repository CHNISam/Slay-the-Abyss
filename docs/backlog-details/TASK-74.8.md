# 战斗构造与开局职责

固定基线 `2107aeda9a8fca4b219b9281f2ddecd22f1b05b6`，完整旧 `abyss_combat.lua` Git blob 为 `3aae3311fc5635d3077e20774fba4e17320a6781`。旧源 gzip 固定在 `tests/fixtures/combat-constructor-before.json`，正常测试不依赖 Git 历史。变更只在原模块构造区，已审原生开回合及其前面的代码保持逐字相等。

构造入口现在依次调用同模块职责：选项默认和验证、状态所有权、机制检测、各独立随机流、开发资源、永久 UID 和卡牌实例、敌人与开局牌序、牌及 misc 流、Emerald 和两次开局回调。没有新的动态加载、全局 locator、跨模块 API 或玩法规则。

保留注册返回新 bundle 时采用其私有 sourcePools、已注册调用者数据再复制池的区别；保留 rules 原局部引用用于 opening stage。选项只在原条件下做浅复制，Formation 回调和 roomStreams 不深复制。卡牌先写入 draw，再读取 bottled 标记和做二次 Searing Blow 校验；prepared actor 仍 adopt 后再初始化。AI 初始化→洗牌→opening stage→敌人 preBattle→独立牌/misc 流→Emerald→beforeFirstTurn→额外 Innate 抽牌→beforeOpeningDraw 的顺序保持。

单片固定 Luacheck 的绝对数值见 [combat-constructor-20261104.json](../evidence/combat-constructor-20261104.json)：

| 指标 | 旧 | 新 |
| --- | ---: | ---: |
| M.new 圈复杂度 | 82 | 4 |
| M.new 跨度 | 139 行 | 21 行 |
| 新同模块职责函数 | 0 | 13，最高 CC12 |
| 构造区全部函数 CC 和（含两个匿名 callback） | 85 | 99 |

总和增加包含每个新 helper 的基础路径及 Emerald 返回值显式检查，不声称总分支减少或运行时提速。所有 helper 及嵌套 callback 都由主控加入原 CC15 门禁；最终多模块组合的全库复杂度、依赖及 SCC 由主控统一测量，此单片不能代替它。

本轮固定 Node24.18 验证：

- 11 类场景独立旧/新 VM 双跑，完整图包含 caller data/options、catalog、rules、sourcePools、prepared input、RNG、事件、回调观察和共享引用；最终 trace **5602387 字节**，双方 SHA256 均为 `b0e353467782c0692c81a1688029ab5c72235b7d41408a6ec4203235e8acb88e`。没有省略 data/catalog。仅消除 Lua 断言诊断的文件行号前缀；函数以类型标记表示，回调时机、拒绝、异常对象身份及不进入存档另有行为断言。
- 实际覆盖 nil/default 和显式 false/0 选项、新注册/已注册 pools、源流 clone、prepared adopt 与坏身份、非单调永久 UID 及重复 UID、Searing Blow count-only/零值/bottled、额外 Innate 与两次回调、回调拒绝和 table 异常、Defect 资源默认、Emerald 和无效边界。
- **8 个真实源码变异**均被带 `[COMBAT_CONSTRUCTOR]` 的行为断言拒绝：显式 false 默认、调用者随机流隔离、UID 推进、bottled 标记、首回调拒绝、prepared 身份、第二回调保留及 sourcePools 所有权。解析错误或 runner 失败不计通过。
- 原回归：room_shuffle 6 组、opening_hand 10 组、opening_relic_order 20 组、emerald_combat_hooks 5 组、run_prepared_v4_compatibility 四职业及 class_common_relic_constructor 4 组均通过。原入口 timeout 未改。

初版 trace 5434339 字节尚未加入同场景中的坏 prepared.version 调用；不能与最终不同 fixture 版本直接比较，也不能将变化归因于其他并行切片。

重放：先 `npm run build:data`，再 `node --test --test-concurrency=1 tests/combat-constructor.test.mjs`。完整差分每个 VM 保留原 30 秒预算，输出缓冲显式为 32 MiB；普通 raw fixture 不打印大 trace。独立复审、精确 HEAD Full 和合后验证另记，未构建候选、官方导入、真实 ready 或设备取证，不提前勾完成。
