# 前两幕事件交付收口（2026-10-30）

基线 `1fcd321ca9d6f79b4e5bbdfede48069119f5ed52`。复用已独立审查的私有提交 `0c53969a3e6e7308a00db0fecedd5ce799cb210d`，不重新发明原版事件规则。来源为既有固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 镜像，源码身份/方法证据保存在对应测试合同；不是原版 PC 二进制认证。

## 本轮实际接线

- Dead Adventurer、FaceTrader、Designer、Knowing Skull、N'loth、Colosseum、Masked Bandits、Cursed Tome、Forgotten Altar、Drug Dealer、Vampires 共 11 个缺失身份接入真实 Nodes/Run 事务。保留全部原池、顺序、资格、随机流与同局一次性生命周期，不缩池、不重抽、不替换奖励。
- 保留当前主线 Match 与 Duplicator，不装回旧树版本。Designer/Drug Dealer 多选采用既有批准控件，选择顺序、过期回调与失败重试有原生 mock 回归；Duplicator 继续当前单卡选择入口。
- 三种事件战斗复用正式战斗、原生敌人动作与真实奖励事务。竞技场第一战重新打开事件、第二战及强盗奖励可完成回图；受控战斗/药水输入不冒充自然获取或正常两幕通关。
- 新增 11 件事件 SPECIAL 遗物和 Necronomicurse，保留 PR357 的 130 件普通池绑定、选择所有者、持有顺序与实际钩子。Nilry/Codex 与现有 Calendar 共享队列的暂停、恢复和致死行为有联合验证；耗牌按固定来源 `Relic.onExhaust → Power.onExhaust → card.triggerOnExhaust`。
- 遗物移除不是获得效果的逆运算；原金币、最大生命与药水槽等一次性收益保留。Nloth 测试逐项使用当前 130 个合法遗物，不缩候选。

## 验证界限

本轮有代码生成、内容清单、架构/静态检查以及受控真实命令/原生 mock 专项。完整当前 SHA 的 CI、严格历史来源逆层、自然通关、候选写入/读回、官方导入、新 ready、PC/实体手机和正式负载证据分别验收，不能以此文件宣称已通过。

旧未实现事件的无重抽/完整回滚负例继续保留；合法已实现事件另有正向完成验证，不能把“正确拒绝”当作可玩。源码目录覆盖 42 个当前合法身份仅是映射/分派检查，不等于逐项自然或平台通过。

复用 TASK-13.1.2 / TASK-61 / TASK-14.1。当前执行环境 Backlog CLI 不可用（127），未手改任务文件，未把父任务标 Done。没有桌面输入、发布、后端或 Lv.4 持久存储变更。
