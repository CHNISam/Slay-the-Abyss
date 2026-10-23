# 真实指令回归与种子42路线诊断

本次只补测试和可复跑证据，不改生产数值、规则或其他执行者的任务状态。轮末修复、AI及地图改动由PR100原执行者实现。

## 易伤回归：补真实出牌路径

[新回归](../../tests/lua/guardian_vulnerable_transition.lua)使用受支持的三张普通Strike隔离卡组，仅调用Combat.new/play/endTurn，不注入HP、状态或意图；不是完整初始卡组通关。

前两回合各出三牌，第三回合等待Vent Steam；第四回合一张受虚弱影响的Strike触发防御阶段，再经过Close Up和翻滚。翻滚必须造成 `floor(9 × 1.5)=13`，而非9。

- 旧develop `52f35dd6b07e467397a5a8d29f72b6d671261031`：退出1，实际9，玩家余39血。
- PR100头 `cf6969e768a6102a726948742dd327642043c2ab`：同一脚本退出0，实际13，玩家余35血。合入提交为 `14979dfb94fc6a7a5f714acb927293a6e96f809b`。
- 作者、独立审查者均用系统Lua5.4复跑；源调度与边界沿用 [ROUND_DEBUFF_DURATION](../rules/ROUND_DEBUFF_DURATION.md)，不另建规则账本。固定社区反编译镜像不是认证PC二进制或原客户端实测。

测试加入默认Lua回归。对照仍通过：连续虚弱后的Strike各4伤害、未转形旋风28伤害、当前软泥施加脆弱后的Defend3格挡。不据此宣称所有状态/AI均已原版一致。

## 合法路线：同一脚本，不调值求胜

[诊断脚本](../../tools/diagnostics/core_route_seed42.lua)使用公开Run/Nodes/Map命令。种子42、固定策略、不搜索种子、不调策略；未直接注入或篡改血量、卡组、敌人、RNG或数据。上限17节点、每战100回合、每回合30次出牌命令。偏好非战斗节点与攻击，不代表熟练玩家策略或原版地图分布。

- [旧基线账本](../evidence/core-route-seed42-before.json)：到第16层时69血/69金币/7牌/5遗物；Boss第7回合玩家战败，Boss余16血。战败推进被拒绝，新局资源复位。
- [PR100账本](../evidence/core-route-seed42-after.json)：第16层Boss第8回合被击败，领取稀有卡Bludgeon；最终35血/199金币/12牌/2遗物/6胜，20战斗回合、32次出牌。随后进入第17层得到 `boss_treasure_not_implemented`。
- 两次路线从第2层即开始不同，遇敌、奖励和卡组均改变。因此不能把胜负归因于单项修复，也不是平衡、胜率或原版一致性通过。
- 两套基线各重复运行得到相同日志。当前没有自然药水来源是既有缺口，未伪造药瓶；完整17层与官方胜利结算仍未通过。

## 复跑与证据边界

```sh
npm run build:data
node scripts/test-lua.mjs tests/lua/guardian_vulnerable_transition.lua
node scripts/test-lua.mjs tools/diagnostics/core_route_seed42.lua
```

诊断脚本退出0仅表示正常记录结束，不表示整局通关。标准命令复用已有Fengari runner；本次云端实际使用系统Lua5.4，未将命令示例冒充Fengari执行结果。当前提交CI结果另在PR记录；未启动原神、未编译/写入存档、未官方导入或实机试玩。

冻结哈希：脚本SHA256 `8757e8367100225a0cecd4e690bfce386d2af09e9d67288d512cf0fa0e827290`；旧原始stdout `2cf140e34d72ebf126797741bf9ab6a122a8b87fcffa4d2e685f985f2a8920e6`；新原始stdout `19efa431949ec70ee9459804582efa1224b48c46f79ddccf3a8e7d8120287ded`。JSON的stdout_lines保留每行原内容（含空字段制表符），按换行连接并依trailing_newline补末尾换行即可还原原始stdout；JSON文件本身不使用这两个哈希。相关runtime/data逐blob核对对应提交，不声称临时目录整体一致。
