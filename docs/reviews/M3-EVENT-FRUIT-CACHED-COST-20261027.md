# 合法 Fruit Juice 与事件缓存成本

本轮Golden Idol源审计暴露此前Moai/Winding交付中的P2：源码构造只缓存各成本，后续不要求当前maxHealth仍等于入场值。事件中可以通过原生药水面板真实使用Fruit Juice。旧guard把合法资源变化当成陈旧输入；Winding三项都会拒绝，导致无法离开。该错误与此前固化它的断言一并纠正。

公开命令先RED：真实进入Winding→Continue→获得并使用Fruit Juice，max85，再max_hp返回stale_event_health；应使用缓存4，得到当前85→81。专用回归另证旧Moai显示仍是入场before/after，未反映当前owner。

修复只移除相等性要求，保留正整数/范围/当前生命输入校验。Moai保留原hpLoss；Winding保留原hpDamage/healAmount/maxHpLoss。显示before→after使用当前maxHP和缓存代价，并用整数显示。未重新计算成本，未复制药水、治疗或伤害规则。

真实回归以max89开始，喝Fruit后当前94：Moai缓存11，得到83而非重算损失12；Winding缓存伤害11/治疗22/最大生命4，三项分别得到原当前35→24、35→57、94→90。另以真实NodeUI/Down-Up-Click验证80→85后显示Moai85→75/Winding85→81；旧handler和用瓶前按下的旧触点拒绝，新的触点正常完成。没有用阻止合法药水代替输入保护。

旧Moai/Winding回归保留全部断言，将原“最大生命81即拒绝”的错误前提改为“最大生命0非法必须拒绝”；原UID、重复输入、失去Idol、晚失败回滚等保护不删。代码没有改entry缓存值、随机算法、正常池、默认药水能力、caller隔离或输入身份机制。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/test-lua.mjs tests/lua/act3_event_fruit_costs.lua
& $node scripts/test-lua.mjs tests/lua/act3_event_fruit_ui.lua
& $node scripts/test-lua.mjs tests/lua/act3_moai_event.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_rollback.lua
```

修复在Golden树单独提交，stage只包含两个既有事件模块、这四份测试及本说明/两个事件规则纠正；不包含正在实施的Golden Idol数据、schema、事件、金币hook、UI标题、source-lock等内容。无全check/平台结论。
