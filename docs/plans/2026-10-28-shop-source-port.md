# 商店陈列与选取移植

本轮随后按用户截图与追加要求扩展到 TASK-4.8 宝箱开箱/领奖、TASK-4.9 休息/锻造；三项均以最终平台效果验收，不能用代码合入或离线预览关闭实机标准。

用户已明确选择先移植原版、再逐步调整。本轮采用该方向，不重新设计购买规则。

**目标：** 五张职业牌在上排，两张无色牌在下排左侧，遗物、药水和删牌服务在右侧；鼠标悬停有清楚的放大与价格反馈；触屏选取后确认购买。

**架构：** `abyss_shop_ui` 负责商品陈列、悬停和触屏选择，`abyss_node_ui` 保持输入所有权及命令分发，交易仍由 Nodes/Shop 完成。主题数据统一保存坐标和交互参数。

**来源：** [ShopScreen.java](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/shop/ShopScreen.java)，固定社区反编译镜像；核对 initCards、updateCards、update、renderCardsAndPrices。上排职业牌、下排无色牌；鼠标直接购买、触屏选择并确认；悬停时价格跟随大小避让卡面。本轮将这些行为移植到平台 Lua，保留岩金配色和平台图库。

**步骤与验证：**
1. 修改 `data/presentation/ui_theme.json` 和 `scripts/node-ui-layout.mjs`，补双排布局及放大边界测试。
2. 修改商店与宿主，补鼠标悬停、触屏确认及中断/补货回归；读回真实状态，确认没有预览扣款。
3. 运行构建、相关 Lua 和布局检查，生成离线预览。平台导入、鼠标/实体手机实测和 verify:ui 独立保留，不用离线结果替代。

**本轮复盘约束：** 商店规则来源对齐不能代表展示效果已移植。今后陈列与交互必须单独列出来源方法、实际控件反馈和验证层次。

宝箱：核对 AbstractChest.open 的声效/开箱/打开 CombatRewardScreen，以及后者的纵向奖励行。普通箱奖励改为全部可见的直接领取列表，金币独立，蓝钥匙与遗物互斥。两次晃动、爆开和分批出现是用户明确追加的演出；不是上游原本的两次晃动代码。

营地：核对 RestOption.useOption、CampfireSleepEffect.update 和 SmithOption.useOption。升级用十二槽分页网格选择，再单独显示 1.5 倍升级前后对比；取消预览返回网格。休息、升级已提交后播放短反馈，再显示结果。平台 Lua 不运行 Java/LibGDX；规则和一次性事务继续由既有核心负责。
