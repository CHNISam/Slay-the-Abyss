# TASK-4.21 fresh单槽药水查询（私有计划）

2026-11-02 root 02:52明确批准无缓存替代。基线fresh develop `6aa3cf90f0a0734514e8a7dbc29988e628a5c74d`。独立树 `/tmp/m4-potion-popup`，分支 `feat/potion-popup-fresh-view`。不改465、不push；TASK-4.21与API检查器共享文件协调后再集成。

拒绝方案：跨hover缓存、跨约20 native渲染调用传先前frame.potions、全模型revision改造。缺失模型变更合同且合成重入已有真实Run.play负控；原始探针在同级m4-potion-profile-20261102。

实施：现有完整row构造原样抽private potionRow，完整potionView仍按原槽位顺序遍历；新增potionSlotView只校验槽位后走相同候选规则/全敌人target搜索。仅popup actions.item使用fresh单槽；popup每次open/render/act都重新查询，BattleActions.usePotion完整重验保持。没有缓存、busy旧cache复用或布局/动效/玩法修改。

验证：34定义slot与full row深等/完整run与RNG图不变；空/非法/第五槽/outside/unknown/automatic/event受限；独立effects；同run同turn原地变更立即影响结果；前目标失败继续后目标；实际Host三药水单render候选6→4、busy不查询且关闭popup、无refresh旧Use拒绝与恢复真实Use、native setter注入Run.play后的fresh禁用。保留原实现RED与临时错误变异、按原30秒预算串行跑必要回归。

API检查：只追加精确potionSlotView:['run','slot']，不修改原expected；TASK81另agent负责路径输入显式化，后续依root集成顺序保留双方。
