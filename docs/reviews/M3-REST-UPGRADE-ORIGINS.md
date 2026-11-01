# TASK-4.7 AC5：休息与升级来源离线验收

基线 `243ae1b`，2026-10-31。本切片只补测试，未发现需修复的生产缺陷，未改平衡、来源实现或 Backlog。

`tests/lua/camp_rest_upgrade_origins.lua` 复用现有 Fengari、GameUI 和原生控件夹具，标准默认 30 秒。前置场景用 `Map.choose` 回放合法路线，到生成地图已有营地前的快照，再通过生产 `Nodes.enter` 和 `NodeUI:press('campView/rest')` 休息；没有改地图节点类型或伪造来源记录。取得遗物使用生产 `Run.obtainRelic`，蛋牌使用 `Run.obtainCard`，小屋待领取状态使用生产 `BossRelics.claim('done')` 关闭。

两场景覆盖：

- 普通初始牌组持有帝王枕头，休息回血，但全部 UID、升级状态、级数、来源及当前取得收据不变，没有新来源。
- 同局实际执行毒素蛋取得新牌、小屋随机升级、战纹技能升级和磨刀石攻击升级。逐次记录 UID 和升级前后状态，断言小屋只升级一张、战纹/磨刀石各两张且类型正确、级数仅加一次；重复取得被拒且整个 Run 不变。随后休息保留四种独立来源；用真实牌组网格点击打开每张牌详情，休息前后文本一致且显示对应遗物、永久升级/获得时已升级，打开/返回/关闭保持 Run 只读。完成节点再次休息被拒且 Run 不变。

复现：

```sh
npm run build:data
npm run build:ui
node scripts/test-lua.mjs tests/lua/camp_rest_upgrade_origins.lua
node --test --test-concurrency=1 tests/camp-rest-upgrade-origins.test.mjs tests/card-upgrade-origins.test.mjs tests/card-origin-identity.test.mjs tests/card-origin-ui.test.mjs
```

本轮独立脚本通过，`CAMP_REST_UPGRADE_ORIGINS_PASS 2`，5952 ms。脚本逐卡输出 `REST_ORIGIN_STATE`，保留取得遗物和休息前后可比对的 UID/cardId/upgraded/upgrades。两项临时生产变异均被相同保留断言拒绝：在 `Nodes.rest` 给旧牌升级；在 `Nodes.rest` 把已有来源覆盖成营地。变异已恢复，无生产文件差异。

验收边界：这是受控前置快照下真实生产公开命令的离线回归，不能称作自然长跑取得遗物、官方 LuaHost 或当前候选 PC/手机证据。AC5 的运行时合同已有本测试与既有设备来源/零一两张候选/事务回滚测试支持；是否勾选应结合整合头复验和独审。若将 AC5 解释为必须复现用户当局或自然取得路线，则这些要求仍无证据，本切片不能宣称完全关闭。TASK-4.7 的设备相关 AC2/AC6 不因此完成，用户历史异常来源也未被追认。
