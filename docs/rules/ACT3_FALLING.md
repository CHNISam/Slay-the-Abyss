# 第三幕 Falling 本地切片

本切片实现一个第三幕事件，不代表第三幕内容齐备或正式 campaign 开放。普通发布入口仍使用第一幕受限池；完整来源池遇到其它未接事件时仍明确拒绝，不能删池或重抽。没有平台导入、实机或自然通关证据。

## 固定规则

来源为本地固定 `319009d5df0a82d9fb0f23cc22322286c6a87ec0` ZIP。新锁 [act3-falling-source.json](../../tests/fixtures/act3-falling-source.json) 记录 Falling、CardHelper、CardGroup、Random、TheBeyond 的实际 ZIP 成员和逐字节 SHA256；旧来源锁未改。锁定的是审计镜像方法语义，未运行原作 PC 二进制。

- 构造时按永久牌组原顺序分组；三种瓶装标志任一为真即排除。只按攻击/技能/能力类别筛选，不套用商店删牌费用、最低牌组数量或泛化的可移除规则。
- `CardHelper.returnCardOfType` 按攻击→技能→能力依次消费新房间 miscRng。非空类别抽 `random(size-1)`，单张也消费一次，空类别不消费。
- INTRO 先继续。CHOICE 固定显示技能→能力→攻击，显示被抽中的真实卡牌及升级；缺类禁用。只有一类仍须点击，不自动选择。三类全缺才有逃脱选项；存在候选时没有免费离开。
- 选中后删除原永久 UID，仅删除该实例；保留结果到离开。重复卡、升级/misc 与瓶装标志不通过复制或泛化删牌重写。保存的候选与永久对象不再一致时拒绝陈旧输入。
- Nodes 的完整事务覆盖入房、来源池、Run/Map 和全部 RNG；删除后的失败或异常也不能留下部分提交。只调用既有 `Run.removeCard`，没有 Combat 或职业卡改动。

## 专用验收

使用仓库 Node24；先离线安装依赖并在本树运行 `scripts/build-lua-data.mjs`、`scripts/build-ui.mjs`、`scripts/build-ui-theme.mjs`。每份 Lua 仍沿用原 30 秒预算，没有增加时限。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/test-lua.mjs tests/lua/act3_falling_event.lua
& $node scripts/test-lua.mjs tests/lua/act3_falling_ui.lua
& $node scripts/test-lua.mjs tests/lua/act3_falling_natural.lua
& $node --test tests/act3-falling-source.test.mjs tests/launch-content.test.mjs
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

初始 RED 是公开 `Nodes.enter` 返回 `event_unavailable`。GREEN 使用真实生产命令；不是直接注入事务结果。seed42、房间35的新 misc seed77，三次二选一分别选择 UID101/202/302，完整状态为 `58ecdcb139ff8c6b / 4654e3216996cb9f, counter3`；独立 Python 整数解释器给出索引0/1/1。

来源抽取夹具使用真实 seed8、第三幕第一节点的未知房间入口，不设置 eventId；为隔离事件把边界节点类型设为 event，未走完整地图路线。真实未知概率、来源池抽样和公开 Nodes.enter 得到 Falling，原七普通事件只移除 Falling。eventRng 为 `68ecf1cacb69f37b / 7c8ee6a72ed52f5f, counter1`；selectionRng 为 `f107e54fd91cce9b / de1e7ecfdfa8f298, counter3`，由独立整数解释器核对。不存在受限池替换或重抽。

原生 UI 夹具用实际布局、Nodes.view 和按钮回调，覆盖三类牌名/升级、缺类禁用、单类/全缺、结果后离开、旧回调和重复触点拒绝。该证据属于离线适配器，不是平台 UI 验收。既有 Act1 原生事件 UI 的11例保持通过。

release 清单将 Falling 单独列为 Act3；库存相对默认 Act1仍记 explicit-only，并记录开发 campaign 的本地抽取证据。验收器按事件所属章节构造真实 Run/Map，另核对全缺候选的逃脱分支；没有提高其它事件或平台状态。新增模块登记 core 架构。Luacheck 的111条历史警告未增，仅重新映射受插入行影响的14条既有 UI 诊断位置。
