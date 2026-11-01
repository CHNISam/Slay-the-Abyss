# Courier 补货的独立身份随机源

2026-10-25，TASK-16.1 / PR #196。修复职业卡补货错误消耗 `run.cardRng` 抽身份的问题，不代表商店全部内容或平台验收完成。

依据固定镜像的 `ShopScreen` 补货、`AbstractDungeon.getCardFromPool` 和 `CardGroup.getRandomCard(type,false)`：稀有度走共享 `cardRng`，按原 cardID 排序的职业类型池身份走全局 `MathUtils`；允许与刚买的牌或另一槽相同。无色身份仍走 `cardRng`。libGDX 官方 [MathUtils 固定版本](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/MathUtils.java#L104-L108) 使用独立 `RandomXS128`，整数上界包含在内。

`abyss_external_random` 提供会话级状态，首次使用从客户端允许的 `os.time/os.clock` 取宿主熵，与战局 seed 无关，`Run.new` 和普通初始货架不重置它。复用已有独立实现的 XS128 算术，不复制第三方实现。显式 `setReplayState` 仅供自动化复现外部输入，游戏界面不调用。普通 seed 不足以确定原版全局 MathUtils 的外部历史，不能据此宣称原 PC 同 seed 轨迹一致；原版视觉、其他系统的 MathUtils 消耗也没有模拟。

补货在现有商店暂存事务内抽取外部状态副本，全部补货成功后才提交；资金不足、非法旧请求、身份已抽取后报价失败均不推进外部状态。提交检查版本，拒绝陈旧事务。卡牌奖励继续与初始商店及补货稀有度共用正式 `run.cardRng`。

验证：`tests/lua/warrior75_courier.lua` 六组固定契约（含公共购买入口、真实类型池和价格），`shop_card_identity.lua` 十五组重复卡槽与陈旧触摸断言，既有 `shop.lua` 交互及报价回归通过。seed42 初始货架后 cardRng 计数12；一次职业补货仅消耗稀有度，成为13。显式外部状态6补出 Clothesline、状态1补出 Wild Strike，均普通36金币，后续 cardRng 完全相同。真实重复卡槽为36与42金币，按点击槽位扣款。

这些结果属于代码已实现和专项本地测试通过。固定源仍未认证目标 PC 二进制；原作外部会话历史、平台商店购买与自然取得 Courier 的实玩链路待验。
