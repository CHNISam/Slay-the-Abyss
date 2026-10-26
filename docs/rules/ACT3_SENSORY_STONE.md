# Sensory Stone 单事件切片

按固定 PC A0 来源接第三幕 Sensory Stone 的公开 Nodes 事务、35普通无色卡奖励与原生界面。不是第三幕事件全部齐备、完整自然通关、平台或实机验收。本片属于当前 RC 之后的独立内容批次。

## 来源与准确顺序

新锁 [sensory-stone-source.json](../../tests/fixtures/sensory-stone-source.json)记录本地固定 `319009d5df0a82d9fb0f23cc22322286c6a87ec0` ZIP 的67个原始成员及实际SHA256，其中包含35张普通无色牌的已审来源。没有修改旧来源锁，没有运行原作 PC 二进制。

- `SensoryStone.buttonEffect` 先 INTRO Continue，再显示1/2/3组选择；不是在入场时抽候选。选择时先 `getRandomMemory`：消耗房间 miscRng 一个 randomLong，以 Java Random 对四段记忆 shuffle。源名未批准译名，界面保留 Sensory Stone，以记忆编号记录来源结果。
- 接着 `reward(num)` 一次创建全部1/2/3个 `RewardItem(COLORLESS)`，清除当前房间旧奖励，打开专属奖励列表，并把事件置 LEAVE；不额外混入普通职业战后奖励。然后2/3组分支才执行 null-owner **HP_LOSS** 5/10；1组没有 damage 调用。最初计划中的 NORMAL 表述已经由父线程 CLI 更正，不沿错误计划实现。
- `AbstractDungeon.getColorlessRewardCards` 每组默认3张。每个槽先持久 cardRng 的 binary32 30% rare roll，再从按 source cardID 大小写精确排序的15 rare/20 uncommon桶抽 index。组内同一来源对象重复仅重抽该稀有度桶 index，不重抽稀有度；跨组允许相同牌。RARE 将持久 rarityOffset 重置5；其它结果保持原偏移。没有普通战斗奖励的随机升级循环，第三幕也不额外花升级 RNG。全部35普通无色保持，包括 Bandage Up/HandOfGreed 的 HEALING；4张 SPECIAL 不进入本奖励池。
- 奖励列表可按任意顺序打开尚未领取的组。取牌经 `Run.obtainCard` 创建一个真实永久 UID，再移除该组。SkipCardButton 只是关闭选牌页：回到列表、保留同组候选，重开不抽牌、不改变RNG。不能复用会消费该条目的普通战后 Skip。全部领取后也需显式 Proceed。
- `ProceedButton.update` 的 EventRoom 分支关闭奖励列表并返回事件 LEAVE 页，下一次 Leave 才打开地图。源 ACCEPT 分支不会在此再生成第二批，因为 `reward` 已把 screen 改成 LEAVE。Proceed 可以放弃剩余组，此后不能从事件页重开奖励。
- 用本事件的 `intro→choice→rewards→cards→result` 私有状态机承接两个界面层级，不引入通用多奖励框架，不写入历史 `run.rewards` 或历史 combat。取卡、退出、阶段及候选组编号都由 Nodes 命令验证；旧回调和迟到指针仍走现有 view/owner/touch guard。

## 伤害与未接依赖

复用 `Run.eventDamage` 的当前 owner HP_LOSS/Fairy 事务。实际 Tungsten Rod 组合依赖为原 `ff01ba077b5c61881b87c8bc3e4436793c728a0f`，本树仅依赖 cherry-pick `da48726b1275f1900934940943ed57bb18c9cc7f`。没有重实现 Rod，没有把 HP_LOSS 改成 NORMAL，也不借用陈旧战斗的 Block/Powers/药水状态。

真实 Rod 定义/取得后，两付费选项实际失血4/9；HP5承受标称5时保留1HP且不消费 Fairy，HP1承受更大失血仍在所有奖励生成后由 Fairy 复活。致死无复活时保留已经生成的奖励/RNG状态，正式 Nodes 进入 defeat，不能领取牌；生成并不等于取得，永久牌组/UID此时不变。

持有尚未实现的 canonical `lizard_tail` 时付费分支明确拒绝，免费1组仍可用。`question_card`/`busted_crown` 奖励数量、`toxic_egg`/`molten_egg`/`frozen_egg` preview/obtain升级、`singing_bowl` 替代跳过效果尚未接齐；持有这些 owner 时明确原子拒绝，不伪造钩子或缩池。不存在这些 owner 的正常完整35池入口可执行。Ceramic Fish 的真实获得牌+9金币复用已有 shared hook；跳过不触发它。

## 独立向量与验收

独立 Python [oracle](../../tools/oracles/sts1_sensory_rewards.py)只读已审卡注册与既有独立 XS128 整数解释器，不导入生产 Lua或读取生产 helper输出。固定15组正常种子/组数向量，含重复 index 重抽、偏移保持/重置、HEALING结果、组间重复及 Java shuffle 的完整字状态；JSON与Lua向量由 `--check` 同核。实际两个 Bandage Up领取拥有不同永久UID，真实 Combat 构造组件保留相同 deckUid。该 seed139 下一正式第三幕来源房间尚未实现，公开入口明确拒绝且保持队列/资源；没有重抽或换房来制造自然续战证据。

四个实际 Run 工厂各完成免费组生成/取牌/退出，持久卡流一致，所选职业的正式奖励母池原样保留。seed1、第三幕首房间边界不指定 eventId，真实完整七事件池抽中 `SensoryStone`，只删第五项、神龛与once历史保留。eventRng 为 `7d6e4ac38b2b1be2 / b722f2631cb7b14d, counter1`；selectionRng 为 `ab89235541870f7d / 2d25c9924d25b67b, counter3`。这不是完整地图自然通关证据。

原生UI使用既有事件布局：列表最多3组+Proceed，选牌3张+Skip；展示完整批准卡名、费用（包括X）、类型、稀有度与真实规则。35种文字全部通过既有680×40/14px槽的保守排版检查，不降低最小字号。没有新美术或新视觉方向；此检查不替代设备显示和正式UI验收。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/build-lua-data.mjs
& $node scripts/build-ui.mjs
python tools/oracles/sts1_sensory_rewards.py --check
& $node --input-type=module -e "import {runLua} from './scripts/test-lua.mjs'; for(const n of ['event','rng','natural','outcomes','rollback','tungsten','ui','profiles']){const r=runLua('tests/lua/sensory_stone_'+n+'.lua');process.stdout.write(r.stdout);process.stderr.write(r.stderr);if(r.status!==0)process.exit(r.status??1);}"
& $node --test --test-concurrency=1 tests/sensory-stone-source.test.mjs tests/launch-content.test.mjs
& $node scripts/validate-data.mjs
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

原每文件30秒预算、断言与旧门禁不变。默认第一幕模式仍为 restricted-seven，完整第三幕七母池原资格/顺序不变；没有缺项过滤、重抽或占位牌。M3、TASK-62、默认全事件准入、完整三幕自然接续及平台/实机证据继续保持未完成。
