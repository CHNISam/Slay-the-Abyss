# 无色牌动作职责整理

固定旧源：`b4ac63145689b9dd632db100eee49087f6182b39`，完整模块冻结于 `tests/fixtures/colorless-actions-before.lua`，LF 归一 SHA256 为 `0e27a235638b74f9390fb9ef3f51e8e4b50df4234c55a892fa99dc41ae980806`。正常测试直接认证完整旧文件，不依赖 Git 历史，也不重写旧黄金。

只调整 `abyss_colorless_cards` 的动作执行分派。每种动作仍由同模块局部表精确选择，选择类沿用原 `select`；击杀判断、金币奖励和匕首成长分别承接原主体。入口捕获的 `kind` 显式传入击杀处理，保留伤害回调改写 effect 时的原分派。非选择动作仍无返回值；选择动作沿用原返回协议。没有新模块、全局注册或玩法规则。

机器证据：[colorless-actions-20261104.json](../evidence/colorless-actions-20261104.json)。

| 同一源码集口径 | 旧 | 新 |
| --- | ---: | ---: |
| apply 圈复杂度 / 行数 | 82 / 106 | 2 / 6 |
| 新增具名职责 helper | 0 | 21，最高 CC9 |
| 入口及上述 helper 的 CC 之和 | 82 | 82 |
| 全库模块 / 函数 | 323 / 4779 | 323 / 4800 |
| 全库 CC>15 / CC>30 / 最大 CC | 282 / 78 / 82 | 281 / 77 / 82 |
| 唯一依赖对 / 调用点 | 1507 / 1876 | 1507 / 1876 |
| 最大 SCC 成员 / 内部调用点 | 104 / 805 | 104 / 805 |
| 精确静态告警 | 15 | 15 |

这次拆清职责并消除长条件分派，不宣称整体复杂度总量、依赖环、游戏性能或全库热点已解决。原有描述与选牌等热点仍保留报告。21个新 helper、入口及其匿名回调纳入现有 CC15 门禁；缺入口、缺测量及逐个具名/匿名函数超限均有负例。

固定 Node24.18.0 本轮验证：

- 三个独立旧/新 VM 分组，23场景、46个完整动作边界逐字相同；覆盖回合状态、全部队列/事件、RNG、对象别名、返回个数与动态状态定义。仅省略 catalog/rules/sourcePools 的大块目录，报告明确该限制。轨迹摘要与字节数见机器证据，完整输出保存在 `build/colorless-parity/`。
- 七项真实源码变异：Madness拒绝采样、Deep Breath第二次洗牌、Violence洗牌、Greed召唤物排除、Greed捕获kind、Ritual别名去重、Ritual永久UID，均由 `[COLORLESS_ACTION]` 行为断言杀死。类型/加载错误不算kill。伤害异常另核对同一错误表引用。
- 原五牌行为/源身份/Deep Breath独立向量、共享池与职责门禁共52项通过，0失败/0跳过。原九份Colorless相关Lua通过，含78个基础/升级真实生产出牌、28个伤害展示场景、78个展示变体与永久成长/获取组合。
- 正常 raw Lua 回归不打印大轨迹；只有显式差分驱动启用 `ABYSS_COLORLESS_TRACE=true`，原30秒和1MiB预算不改。追加默认完整23场景输出上限合同，防止Full原始入口因为差分日志溢出。
- 统一 `scripts/check-engineering.mjs` 通过：5123/5123完整测量、323模块/1876依赖、15历史告警无新增。`git diff --check` 通过。

复验入口：先按原脚本生成 `build:data`、`build:ui`、`build:theme`，并安装固定 Luacheck；随后用 Node24 执行 `node --test --test-concurrency=1 tests/colorless-action-responsibilities.test.mjs tests/colorless-five-mutations.test.mjs`。前者自行启动独立旧/新 VM 和真实变异。旧 Deep Breath 变异仅把条件锚点从原 elseif 移至同一动作函数，原变异内容与行为断言均保留。

初次展示回归缺少独立树生成的 theme/presentation；按原构建入口补齐后通过，未修改生成器或放宽断言。精确 HEAD 独立复审、Full、实际合入提交 push CI 仍待，TASK-74.7 保持 In Progress；无候选构建、官方导入、ready 或设备实测。
