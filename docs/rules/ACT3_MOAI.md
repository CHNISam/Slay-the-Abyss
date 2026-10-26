# 第三幕 Moai Head 本地切片

按 PC A0 实现 Moai Head 的公开 Nodes 事务和原生界面，保留完整第三幕池。此切片不代表第三幕齐备、正式 campaign 开放、平台 UI 验收或自然通关。

Golden Idol 后续独立切片现已接实际定义、第一幕事件即时取得及普通战斗 GOLD offer 的25%加成，见 [GOLDEN_IDOL.md](GOLDEN_IDOL.md)。新增同一 owner 实际取得→真实起始牌组战斗领奖→Moai 献祭333的组件链；原本片 held-owner 夹具及旧源锁保留历史，不再作为唯一取得证据。仍未走完整跨幕 campaign 或平台验收。Mark of the Bloom、Magic Flower 的 owner 效果通过当前已有 Run.heal/Fairy 边界验证，也不据此宣称其正常获取完成。

## 固定规则

来源是本地审计 ZIP 的 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`。新锁 [act3-moai-source.json](../../tests/fixtures/act3-moai-source.json) 记录十个原始成员及实际 SHA256；没有修改旧来源锁，没有运行原作 PC 二进制。

- MoaiHead 构造按 `f32(f32(maxHealth) * .125f)`，再 Java 正数 round，缓存损失值。没有 HP≤50% 资格。满血也能触碰，单独测试0.5向上与输入先转 f32；`16777219` 对应损失 `2097153`，直接 double 比例会错误得到 `2097152`。
- 选项顺序为触碰、献上 Golden Idol、离开。缺 Idol 只禁用第二项，其余两项始终保留。正常数值下的触碰不是伤害：直接减 maxHealth、先夹当前生命、再将最大生命最低限制为1，最后调用 `heal(maxHealth)`。
- 保留既有 `Run.heal` 的 Bloom 禁疗；禁疗只阻止治疗，不阻止上限降低或当前生命先被夹到新上限。Magic Flower 只在 COMBAT 房间生效，此事件不走战斗治疗；不会调用 damage/Fairy 或消费药水。保留的历史 combat、药水快照和状态不参与本次事件。
- GoldenIdol 继承空 `onUnequip`。事件精确移除 canonical owner 中唯一的 `golden_idol`；保持其它遗物顺序、永久牌组 UID 及其它状态。然后调用现有 `Run.gainGold(333)`；Ectoplasm 时仍失去 Idol，实际金币增加为0。未扩展通用遗物失去/获得框架。
- 三条初始选择都先留下 RESULT，下一次离开才回地图。旧回调及复用同一触点不能把结果页自动变成离开。最大生命输入非法、Idol 已失去、非法 UID/阶段输入会拒绝；合法 Fruit Juice 变化使用进入时缓存损失，不阻止选择；heal/gainGold 在修改后失败或抛错、金币溢出、入场数据异常均由公开 Nodes 整体回滚。

## 验收命令与证据

固定 Node24，依赖使用离线 npm ci，构建写本独立树。Lua 沿用原30秒上限，没有降低断言或增加超时。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/build-lua-data.mjs
& $node scripts/build-ui.mjs
& $node scripts/test-lua.mjs tests/lua/act3_moai_event.lua
& $node scripts/test-lua.mjs tests/lua/act3_moai_ui.lua
& $node scripts/test-lua.mjs tests/lua/act3_moai_natural.lua
& $node --test tests/act3-moai-source.test.mjs tests/launch-content.test.mjs
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

初始真实 RED：Nodes.enter 返回 `event_unavailable`，0.935秒。GREEN 使用实际模块和公开事务，不注入领取结果。UI 测试使用真实布局与 Down/Up/Click 完整指针序列，另测旧 handler 和迟到 Click 拒绝；没有实机输入。

自然来源选择夹具使用 seed32、Act3 floor35、满血 owner，边界节点设为未知 event 类型，不设置 eventId。真实 eventRng 和完整来源池抽中 `The Moai Head`，只删除原七普通事件的第三项，神龛及 once 历史保持。eventRng 完整字状态 `1cca48eb804a9c6a / 575093616d9669c0, counter1`；selectionRng 为 `3e5aca543a2af754 / d9bce1fd0d24cd51, counter3`；新房间 misc seed67 保持 counter0。随机向量由独立 Python 整数解释器核对，不是生产 helper 自报结果。这是未知房间来源选择的组件证据，未走完整地图路线。

release inventory 相对默认 Act1 仍记 explicit-only，另记 Act3 本地来源选择与 GoldenIdol 未接依赖；不改完整池/资格、once 历史、默认正式入口或平台证据。新模块登记 core 架构；Luacheck 的111条历史诊断只重新映射14条既有 UI 行位置，无新增豁免。受影响的 Falling 原有专用回归单独复验。

合法 Fruit Juice 与缓存损失的修复及原生旧触点回归见 [本轮纠正](../reviews/M3-EVENT-FRUIT-CACHED-COST-20261027.md)。显示 before→after 使用当前 owner 最大生命。
