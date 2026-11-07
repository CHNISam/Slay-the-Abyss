# CardCapability 准入职责

基线：develop `2ad07111e3d5b5cb52b4229860b3b780941e29a9`。延续 TASK-74.20 中 Catalog/Capability 的现有风险排序：奖励、购买与升级共同依赖完整卡定义准入，不能把定义存在误当作实际可执行。主控分配本空闲切片，已与 Colorless/CombatCatalog worker核对不重叠；`task:pick` 返回原任务 In Progress 的 HOLD，未重复领取或改状态。

## 产品边界

只修改 `abyss_card_capability.lua`：在原模块内分开 OriginalV4 ID 绑定、条件/X费用激活、状态卡生命周期和普通卡准入。保留原支持实现及提交者，不增加动态注册、缓存或模块层。全部 require、公开 supported 的动态读取与原短路字段顺序不变。

- OriginalV4 的 `effect.raw.id == card.id` 是 ID 绑定，不升级为引用相同；缺 raw 的 nil、无单效果的 false、支持 API 的对象值不强制转 boolean。
- curse 查询直接尾返回，保留多值和 nil 空洞；普通 Effects 查询继续只接受精确 true。
- Wound、Dazed/Void、两套 Burn 格式、Slimed 和不可打出的 Tactician/Reflex/Deus 保持各自原生命周期条件。未新增职业或开放原来不允许的定义。

## 同口径实测

[机器证据](../evidence/m7-card-capability-responsibilities-20261107.json)绑定前后全部333模块源码摘要、完整函数测量及SCC成员。

- `isImplemented` CC57→8；模块10项函数/初始化测量最高11，全模块及未来helper/匿名函数/初始化块均进入既有CC15硬门禁。冻结完整旧源真实触发57超限拒绝。
- 全库测量5386→5393，CC>15为237→236，CC>30为58→57；最大75保持。没有把尚未合并的 #543 数字当作本片主线结果。
- 完整SCC仍81/15；内部引用623/62、唯一对400/41均保持。本片不是解环成果。
- 架构、静态、语法、指引、Backlog范围和doctor通过。14旧静态告警无新增；没有改静态基线、算法、预算或历史实测。

## 测试与独审

新专项10/10通过：1739个完整图检查点，每侧3,246,966字节逐字相等。包含发布卡库、四套实验职业库及其升级、600份固定V4版本、状态/激活边界、nil/对象返回、getter读序、动态require/支持API和错误对象身份。所有图字段、元表及同图别名均保留；每侧独立512MiB/30秒VM，完整图写本工作树临时文件后比较并清理，stdout仍限制1MiB。

独立审阅另做12路径×51故障位置共612对旧新小探针，覆盖effects连续读取、长度元方法、raw两次读取、activation重读、每个可达访问点的同一错误对象及尾返回数量；已纳入永久回归。超过实际访问长度的位置比较正常完成，不冒称全部612例均抛错。

四个真实可解析语义负控由具名行为断言检出：实验激活、状态消耗、精确true准入、原始raw绑定。第一轮raw绑定负控存活，原因是两条路径的stub都返回nil；补入ID不符/缺raw的独立断言后检出，产品代码未因此改变。首失败保留于本树build日志。

既有launch准入/职责/完整CI库存25/25与三份RunCardCatalog真实Lua回归通过，覆盖默认/四职业、完整私有图/别名以及Foreign Influence实际候选和双随机。CI仅登记本片1份新JS为未测文件，保留 #539 并集、旧测量、unknown成本、17/13布局及预算。未改任何旧source archive/oracle；本源不在已注册来源逆桥Owner集合内，不为本次提取新增无关逆桥。

正式提交独审与主控统一集成交付另行绑定。本片未开PR、未触发Full、未合并；任务AC未勾。官方导入、ready、设备和性能验收均未执行。
