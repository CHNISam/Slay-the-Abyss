# 实验室与蓝衣女子生产切片（2026-10-26）

组合基线为本事件分支36f5903，加父线程已验证药水依赖1a60f36与56a8a62（本树cherry-pick为6db668b7/34ccb7b9）。本切片不重复交付其依赖改动。

固定事实来源 aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0 ZIP；Lab.java SHA256 `ee96331834cec864f662e2a1dfc542c2902e8cbd77de5d6feb5f63ede54e4e5a`，WomanInBlue.java `48f154a3ec9b78abf43c5390b678ac982a43ee3af54aa5cae120e9f6cb3fbd69`。同时核对PotionHelper的无参数getRandomPotion、RewardItem的药水构造/领取、AbstractPlayer.obtainPotion。镜像不是正版PC二进制认证，不提交其实现代码。

正式源Lab→lab，唯一初始选项take后生成3瓶；The Woman in Blue→woman_in_blue，保持原gold>=50自然资格及buy_1/buy_2/buy_3/leave四选项，支付20/30/40生成1/2/3瓶，A0拒绝购买不受伤。每瓶直接从当前职业完整源池均匀抽一个索引，只花一次共享potionRng，不套战后稀有度、不影响掉落补偿、不重抽缺定义。seed42独立Python原oracle均匀前三槽为SteroidPotion/Fire Potion/ColorlessPotion，流终态words=e60fca8540413235/42ce675251912b41,counter3，与生产一致。

奖励逐项claim_1/2/3，填第一个空物理槽，满背包拒绝且保留待领奖项；可用真实药水背包丢弃后返回重试。领取成功一次，重复命令拒绝。leave放弃剩余后保留完成说明，再leave回图。Sozu照源仍生成所有奖励，点击某项会将该项消费但不获得瓶子，不因其阻止就少抽。缺任意被抽定义，整个选项的金币、流、事件/库存owner原子回滚。职业瓶未实现时同样明确拒绝而非混入战士瓶。

原生界面曾只有3选项，新增主题第4行y=-298，其余三行、原字号和40行高不变。四选项页与完成confirm共享空间但互斥可见：实际生成控件回归验证第四项可见时confirm隐藏，完成后第四项隐藏再显示confirm。静态同时显示模型只豁免该精确互斥配对，安全区、所有其它重叠、40行高、原逐字文案门禁仍保留且通过。完整四选项没有静默省略；尚未实机验证该新增行。

红绿证据：核心先红于无Lab映射，修后5组；33槽正式购买/领取及3职业分池共36项通过，原生Host→事件→药水背包腾空→重试领取2组通过。既有LivingWall UI4及Act1 UI11通过。Node布局/文案10项通过；架构121模块586边通过；Luacheck1.2.0无新增诊断，111条历史警告，既有诊断只同步位移。新模块已登记architecture。

默认完整25事件门禁和首发清单由父线程负责，本树仍不扩restricted-seven。不宣称自然遇到、候选构建、官方导入、同候选实机或总UI门禁完成。全程离线，无游戏/MCP/桌面输入。
