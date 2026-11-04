# 卡牌定义适配与费用查询职责

基线为 `b4ac63145689b9dd632db100eee49087f6182b39`。目标 `M.cardDefinition` 与冻结组合 `d1cd30104efaff03af287b0902263b420641697e` 逐字相同，目标函数规范化SHA256为 `9238e05722ad7dbe21135743891f825de96351eb38477421377222934d0f3329`。本独立切片不修改d1分支，不接管M8的预览输入/实机验收。

仅将原查询主体按六个职责移入同模块局部函数，公共入口按原顺序传递返回对象。没有缓存、注册表、新模块或数据/平衡修改。

| 职责 | 实测CC |
| --- | ---: |
| 基础验证、目录复制、升级、Searing Blow、实例覆盖 | 14 |
| 原生Perfected Strike计数 | 9 |
| 有序职业适配 | 5 |
| Strike Dummy、Shiv、damageBonus | 13 |
| 持久/回合费用与Corruption | 14 |
| 目标、免费标记与遗物收尾 | 11 |
| M.cardDefinition编排 | 1 |

保留原合同：

- `copy(assert(...))`和每个升级字段独立复制不变；验证先后、零/nil/负费用哨兵及异常消息主体保持。
- `native`在基础覆盖后原位置只捕获一次；原生Perfected Strike不再进入普通Strength计数。没有重算或统一两条公式。
- 适配器可能返回新图，阶段必须承接该对象；两个独立的player判断仍分别读取，适配调用及延迟require不预绑定或提前执行。局外无player路径保留。
- Shiv先于damageBonus；Corruption与历史降费、回合覆盖、免费标记顺序不变。Necronomicon在后续freeAttack之前保存原费用快照；Medical Kit与Blue Candle仍在末尾原位置。
- `cardPreview`及其内部previews正文完全不变；普通预览和V4副本真实演算仍走原路径，不以全局禁用随机调用替代V4验证。

## 源码与验证证据

源码指标：[card-definition-source-20261105.json](../evidence/card-definition-source-20261105.json)。测试目标、完整旧源与独立VM证明见[测试附件](TASK-74.13-TESTS.md)。

固定Node24.18.0、Luacheck1.2.0。在本独立b4源码集上：

| 指标 | 旧 | 新 |
| --- | ---: | ---: |
| 公共入口CC / 行数 | 61 / 73 | 1 / 9 |
| 范围函数 / 总CC / Σ(CC−1) | 1 / 61 / 60 | 7 / 67 / 60 |
| 全库函数 / 完整测量 | 4779 / 5102 | 4785 / 5108 |
| CC>15 / CC>30 / 最大CC | 282 / 78 / 82 | 281 / 77 / 82 |
| 模块 / 唯一依赖对 / 调用点 | 323 / 1507 / 1876 | 不变 |
| 最大SCC成员 / 内部调用点 | 104 / 805 | 不变 |
| 精确静态告警 | 15 | 不变 |

总CC增加6来自六个新增函数基础路径，范围分支数不变；不是全库复杂度、耦合或性能下降的证明。最终d1后续组合必须另采集当前源码指标，不能混用本独立树的数值。

本轮机械展开六个实际调用、移除阶段return边界后，整个Combat源码逐字还原b4，规范化SHA256为 `2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a`。这是一次性变更证明，不给正常测试增加无关prefix硬锁。未改cardPreview/previews的正文SHA仍为 `d05aa784ab754e201cc7760ff2fe77afd9422fee46bc1c059f8ae613ea441e87`。

统一工程检查通过5108/5108完整测量、15历史告警无新增；公共入口及六个helper接入原CC15门禁。`git diff --check`通过。

本轮原六份预览相关回归全部在原预算内通过：`card_preview`、`explicit_target_preview`、`card_detail_preview`、`original_v4_contract`、`original_v4_face_native`、`original_v4_vampire_attack`。包含原明确目标/取消、详情隔离及V4副本真实play/RNG链；没有修改其断言。逐入口执行时间见源码机器证据。

另一执行者的[测试机器证据](../evidence/card-definition-tests-20261105.json)绑定当前源码SHA `5501bec075d05706b39f349a075c33d830738f3f605e5e18e0d03ab33dd75bbb`：四组24查询独立VM完整图及12个真实生产变异通过（专项5/5），原raw四组10925毫秒；原职责模拟14项通过；原八份定义/费用回归全部通过。保留适配器返回新对象、两次player读取、native捕获、费用快照与零/nil/X、输入图/RNG不变和异常优先级；无player时既有nil相等的selfRetain行为也显式保留。测试作者不代替后续独立复审，不将上述本机结果当Full或实机证据。

本轮按主控约定不并发改Backlog、不自行暂存、提交或推送。精确组合HEAD独立复审、Full和实际合入push分别待验；无候选、官方导入、ready或设备实测，不声明工程阶段整体完成。
