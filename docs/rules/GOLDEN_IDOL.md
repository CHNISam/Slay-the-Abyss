# Golden Idol 单遗物与第一幕事件

本片接真实 SPECIAL 遗物、第一幕 Golden Idol 事件、普通战斗 GOLD 奖励及同一持有者向 Moai 献祭。不是全部遗物、第一幕事件齐备或跨幕自然通关；默认事件模式仍为 `restricted-seven`。开发 campaign 的完整来源池只新增正式映射，原资格、顺序、随机消费与未实现项失败保持。

## 固定来源与规则

固定 PC A0 来源 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`；[新来源锁](../../tests/fixtures/golden-idol-source.json)记录本地审计 ZIP 的23个原始成员及 SHA256。没有修改任何旧来源锁，也没有执行原作 PC 二进制。

- `GoldenIdolEvent` INTRO 显示拿取/离开。拿取当次就经 `Run.obtainRelic` 写入 canonical `golden_idol` owner，再进入不可免费退出的陷阱。重复持有会实际获得 Circlet；继续重复只增加真实 Circlet counter，不重复遗物槽。SPECIAL 不进入普通宝箱或商店候选。
- 陷阱顺序是 Injury、普通伤害、减最大生命。构造时缓存 `truncate(f32(f32(maxHP)*.25f))` 伤害、`max(1,truncate(f32(f32(maxHP)*.08f)))` 最大生命损失；这里是 Java 正数截断，不能用 Moai 的 round。合法 Fruit Juice 后仍用缓存代价作用于当前 owner，上限前后显示当前值。
- Injury 使用现有 `Run.obtainCard`，产生新的永久 UID，保留原卡与UID；Omamori 阻止时不占 UID。NORMAL/null-owner 伤害复用 `Run.eventNormalDamage` 与 Fairy，不假借历史 combat；Torii 不触发。直接减上限先最小1、再夹当前HP，不治疗、不触发 Fairy。致死在此前已取得 Idol，正式 Nodes 转 defeat；本代价事务失败仍整体回滚至已持 Idol 的陷阱页。
- 每个初始或代价结果停在 RESULT，下一次 Leave 才回地图；旧 handler 和旧 Down/Up/Click 不会串用新阶段。取遗物失败/缺定义、取得诅咒或伤害晚失败/抛错、无效 health/UID/阶段保持全部状态和随机流。
- `RewardItem(GOLD)` 在非 TreasureRoom 创建 offer 时，冻结 `base + JavaRound(f32(f32(base)*.25f))`。额外部分单独取整，例如10→13、14→18、98→123；不是对总数乘1.25后截断。真实正常/精英/首领金币原 RNG 和原范围不变。领奖不重算，之后失去/获得 Idol 不改变已生成 offer。
- `STOLEN_GOLD`、TreasureRoom 和直接 `Run.gainGold` 不加成；Ectoplasm 在领奖时仍阻止实际加金。Moai 移除同一 owner 后给333，不能变416。金币辅助函数只接入 `Run.finishCombat` 的普通 GOLD 创建位置，没有改通用 gainGold。

## 证据与边界

最初真实 RED：`Nodes.enter` 返回 `event_unavailable`，`Run.obtainRelic` 返回 `relic_content_unavailable`。新增专用 Lua 覆盖 INTRO/陷阱/RESULT、三个代价、独立 float32 截断、大整数、两个真实 Circlet 重复取得、Fairy/Omamori、Fruit、无效与晚失败事务、原生指针，以及完整来源池。

seed16、完整第一幕来源11个普通事件/神龛/once 不删项；边界设为未知事件房间，不设置 eventId。真实抽中 Golden Idol，只移除该项，神龛/once 不变。独立 Python 整数解释器确认未知 roll `.9665967226028442`，selection roll `.8865886926651001`，资格后9项的 index2；eventRng 为 `ccb954bc7af860a2 / 2ab98db97070fe1b, counter1`，selectionRng 为 `b83dec7de1ade519 / 4e3c229549c53a82, counter3`。这是来源选择组件，不是整条自然地图路线。

`golden_idol_channels.lua` 经公开 Nodes 拿取→实际起始牌组、真实 source enemy/HP/energy 打赢下一战（无击杀、能量或手牌注入）→冻结金币/显式领奖→同一 Run owner 跳到 Act3 边界后 Moai 献祭333。没有再次注入 Idol；Act3 边界跳转明确不作为完整跨幕通关证据。金币测试另有33个受控 source RNG 边界，属于确定性组件向量。

固定 Node24，本树离线依赖；沿用每文件30秒原预算。执行时必须检查 `runLua` 的 `status`，不能只用上游CLI退出码。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/build-lua-data.mjs
& $node scripts/build-ui.mjs
& $node --input-type=module -e "import {runLua} from './scripts/test-lua.mjs'; for(const n of ['event','costs','rollback','rounding','gold','natural','ui','channels']){const r=runLua('tests/lua/golden_idol_'+n+'.lua'); process.stdout.write(r.stdout); process.stderr.write(r.stderr); if(r.status!==0)process.exit(r.status??1); }"
& $node --test --test-concurrency=1 tests/golden-idol-source.test.mjs tests/act3-moai-source.test.mjs tests/launch-content.test.mjs
& $node scripts/validate-data.mjs
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

未完成依赖仍明确拒绝而不近似：持有 `tungsten_rod`/`lizard_tail` 时普通伤害选项拒绝；持有 `darkstone_periapt` 时 Injury 拒绝，等待真实共享钩子。本片不使这些未完成遗物正常可获取。其余陷阱选项不因此被禁用。默认全事件开放、完整 campaign、平台编译/导入/实机 UI 与自然执行尚未验收。

视觉沿现有布局，源名 Golden Idol 未猜译；遗物图标暂复用已存在金币 glyph `105077`，theme 明记 placeholder。专用遗物美术及设备验收属于 M4 未完成项。工程检查不能替代UI实机门禁。
