# Sensory Stone 独立交付证据

任务单事件，独立树 `m3-sensory-stone`，基 `f2a75de3`（完整业务基 `d7c0a02e/052bb577`）。先确认 dirty 路径与依赖不重叠，再单独组合真实 Rod 原 `ff01ba077b5c61881b87c8bc3e4436793c728a0f` →本地 `da48726b1275f1900934940943ed57bb18c9cc7f`；该依赖不是本片重复实现。最终事件提交只含自身增量，以及 Root 明确授权原样携带的 TASK62 CLI更正；没有自行改任务状态/验收项。

固定规则见 [ACT3_SENSORY_STONE.md](../rules/ACT3_SENSORY_STONE.md)。实际来源67个原始 ZIP成员，35普通无色身份完整。独立 Python oracle不读生产helper，锁15个正常seed/组数的RNG及Java记忆shuffle，包括桶内重复、不同组同牌、HEALING与偏移保持/rare重置。源码明确先生成全部奖励，再HP_LOSS，不套普通战斗升级/Skip。

初始真实RED：新公开 Nodes fixture在 `Nodes.enter` 返回 `event_unavailable`。GREEN使用真实入口、持久流、卡牌定义与永久取得；没有对生产池做过滤或重抽。中间曾因新测试错误使用旧事件对象引用失败，改为成功事务后读取当前公开状态；没有改生产事务隔离来迎合测试。

| 最终专用Lua | 结果 | 耗时 |
| --- | --- | --- |
| sensory_stone_event | 三组先生成/任意组/Skip重开/真实UID/两个退出层级 | 896 ms |
| sensory_stone_rng | 15独立向量、完整35桶、两张Bandage UID、不可用续战不重抽 | 4529 ms |
| sensory_stone_natural | seed1完整七普通池抽中/单项移除/once和全部RNG字状态 | 1051 ms |
| sensory_stone_outcomes | 1/2/3组、致死前全部奖励、Fairy/Bloom/CeramicFish/未接owner拒绝 | 5210 ms |
| sensory_stone_rollback | damage/obtain晚throw和reject、缺定义、原引用/RNG和同源重试 | 4758 ms |
| sensory_stone_tungsten | 实际Rod定义/取得、HP_LOSS4/9、Fairy阈值 | 1644 ms |
| sensory_stone_ui | 名称/费用/完整规则、35文字适配、第四按钮与旧输入拒绝 | 1389 ms |
| sensory_stone_profiles | 四个实际Run工厂、相同无色流/永久UID/职业母池不变 | 1846 ms |

既有受影响UI回归：Golden Idol 2208ms、Winding 2671ms、Potion Event原2例1735ms全绿。所有Lua沿原每文件30秒，不改runner或旧断言。source/release JS20/20绿10.290秒；正式库存verifier为本事件通过真实Nodes Continue→three→逐组Open/Skip→Proceed取到全部21命令，未伪造只有stage的奖励夹具。

本树 data/UI构建、语法、内容、架构157模块/904边、固定Luacheck全部通过。历史警告105不变，14条NodeUI只按同file/原源行内容/column/code/message及引用源行内容一对一迁移；无新豁免，受管render≤10/函数≤15不变。原四个关键变异均 killed_by_assertion（4467/2846/2639/4281ms）。没有运行重型全矩阵或完整check。

边界保持：持有未接Question/Crown/Egg/Bowl奖励钩子会明确拒绝；Lizard仅付费分支拒绝；没有假实现遗物。seed139正式续战的现有 `act_content_unavailable` 已实际保留和锁定原图，另行Combat构造只证明永久UID映射，不作自然续战。Rod带来的既有Golden来源账本映射缺口由父/库存独立处理，本片没有顺带改账本，也未声称全工程旧8例均绿。

默认restricted-seven、第三幕完整七项资格/顺序和未实现项失败保持。此片不进入当前RC，不计整幕/整局通关、平台编译/导入、设备UI或实机完成。没有鼠标键盘/MCP/模型请求，没有推送或PR。
