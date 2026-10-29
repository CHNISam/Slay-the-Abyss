# 七件缺定义遗物的可领取切片

基线 `1f260a71`。手机诊断中遗物源队列会正常抽中尚未定义的身份，导致普通宝箱和Boss宝箱无法领取。本片补白兽雕像、梨、芒果、古旧钱币、冰冻胎石、咖啡滤杯、聚变之锤七件；不删队列、不改变抽样概率、不重抽，不把剩余遗物做成空效果占位。

规则以固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 为依据，非官方开源或已认证PC二进制。本轮逐份读回 [WhiteBeast](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/WhiteBeast.java)、[Pear](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Pear.java)、[Mango](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/Mango.java)、[OldCoin](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/OldCoin.java)、[FrozenEgg2](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/FrozenEgg2.java)、[CoffeeDripper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/CoffeeDripper.java)、[FusionHammer](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/FusionHammer.java)。白兽保证药水沿用已有完整奖励钩子及四项奖励上限；水果+10/+14上限和治疗、钱币300金币、能力牌取得/预览升级、两个Boss永久能量+1及营地禁用均接现有owner。

冰冻胎石接齐后移除Library/追忆石碑对该遗物的历史拒绝，其余未实现依赖继续拒绝；前者验证20张真实候选能力牌预览与实际取得一致。咖啡/锤组合或咖啡且已无可升级卡时，营地允许无收益继续，禁止伪造休息/锻造；仍有合法操作（含未来Recall）时禁止该捷径。原生UI替身覆盖禁用解释与继续按钮。

本地 Node24.18.0：七组缺定义回归在原实现真实RED，补齐后GREEN。公开普通/Boss宝箱取得与重复拒绝覆盖岩系旅行者的Ironclad规则、真实原创V4雷电将军（`Run.new(...,character='raiden')`，验证`originalV4=true/role='RD'`和真实RD2初始牌组），另保留非首发Defect规则回归，合计21次。Defect不是雷电将军或当前比赛职业。宝箱队列使用保留全部身份的受控排序检查点，Boss经过实际入口/受控击败/领奖/完成节点；这不是自然种子或玩家完整通关证据。Library13组、追忆石碑结果矩阵、既有Boss6组、装备6组及营地UI3组通过，原30秒预算不变。data/UI/theme构建与launch-content清单验证通过（63定义）。新增核心模块为0。

图标明确沿用批准主题宝箱占位，专属美术、候选导出/官方导入、自然获得与后续幕实玩、PC/手机验收均未完成。手机诊断原Ironclad缺86件，本片只补其中7件；其余79件及Defect专属缺项仍保留，不能声称完整遗物池或TASK-14.1/M3通过。本轮未使用键鼠或GUI。
