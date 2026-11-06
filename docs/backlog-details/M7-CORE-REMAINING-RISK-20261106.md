# M7 剩余复杂度与状态风险

本次独立只读清点绑定[D5同源机器清单](../evidence/m7-relic-lifecycle-20261106.json)的333份源码及配置。[逐项风险材料](../evidence/m7-core-remaining-risk-20261106.json)列出全部61个CC>30函数及61个长跨度，两表有重叠；每项保留准确函数、源码摘要、静态调用位置、测试位置、文件变更记录、状态owner和未审范围。它不是全分支、动态调用或设备安全证明。

未确认新的P0玩法缺陷。P1清单表示相关入口下一次改变时优先审查owner和行为，不能由高CC数字单独推导当前有多提交者错误，也不自动要求把61项全部拆分后才交付D5。未知分支没有改标为低风险；本材料不代替Owner接受残余或TASK-74.19/74.20的最终验收。

| 范围 | 高CC数 | 需保留的边界 |
| --- | ---: | --- |
| 既有V4执行 | 3 | Run.play外层savepoint，Combat内部效果/角色资源结算 |
| Inventory | 3 | 战斗候选、永久发布及健康adapter的owner一致 |
| Session遗物/待选/商店 | 3 | Run事务、token身份、嵌套失败与替换图后重取引用 |
| Catalog/Capability/Profile | 4 | 初始化私有图与运行时准入；能力判断不冒充纯数据 |
| 战斗规则派发 | 15 | 既有队列、选择暂停和继续执行 |
| AI | 3 | 动作与回合协议，未逐分支证明安全 |
| 事件 | 6 | staged永久状态及RNG；保留full-source历史合同 |
| UI/表现 | 20 | 控件、订阅、token与销毁；设备证据仍独立验收 |
| 地图/形成/来源/结局 | 4 | 准备值交原Session/Combat提交者；未知范围仍列明 |

文件Git频次使用2026-10-23至11-07的可达历史窗口，具体commit在机器材料中。Inventory13次、EnemyAI28次、Effects23次、DeckUI30次、Feedback23次、MapUI19次；这包含导入/squash，不能当作函数变更频次或未来预测。

Session剩余15成员的15处反向Run导入来自Boss9、CardRewards3、Choices/Pending/Uncommon各1。已核对的调用继续进入原Run事务或同staged owner的嵌套命令；没有通过另一个helper提交状态。跨多卡获得的晚失败、待选token、嵌套拒绝和图替换仍是具体风险。保持无adapter公开接口，不为得到SCC0引入动态注册或隐藏require。

下一最小候选为现有`abyss_original_v4.lua`内的`validateEffects`、`apply`、`executeRoot`三个职责，按实际effect与角色资源规则提取私有helper。它是工程候选，不批准新职业或M8内容实施。绝对出口为三入口及所有新/嵌套helper CC≤15；保持支付→唯一快照→效果→角色结算、resolvingEffects恢复与EnemyAI flush时点；完整状态/别名/RNG/事件/返回/错误/部分写入和回滚对照、原冻结卡向量及晚失败合同、来源新鲜性、精确独审与托管交付均保持。

Combat2275行仍是唯一超千行模块，其184个函数最大CC30；长RunRooms/Settlement安装函数内部最大CC15。仅凭总行数不另开框架；需要变更时按实际职责治理。当前清点和下一候选不表示这些余项完成，也不表示D5已实际合入。
