# 首发30张卡牌离线候选

2026-10-23，TASK-16。基线 `083d780`，复用 PR #37 / `ee98643` 的规则实现与回归；本轮只整合既有规则、补齐全池验证，不改卡牌数值、表现名称、主题或视觉方向。PR #37 保持 Draft，尚未合入 develop。

`data/cards.json` 的37条契约中，当前 **30张基本版和升级版可执行**：3张基础牌来自初始卡组，27张非基础牌可从战后奖励或商店获得。75张参考表仅保留来源，不是可玩池。

| 构筑作用 | 可用卡牌 ID |
| --- | --- |
| 基础攻防 | strike、defend、bash |
| 普通攻击与过牌 | cleave、clothesline、iron_wave、twin_strike、pommel_strike、shrug_it_off、thunderclap |
| 单牌复制、战斗内成长 | anger、rampage |
| 格挡与格挡反击 | body_slam、entrench、ghostly_armor、impervious、barricade |
| 力量与减益 | flex、uppercut、inflame、disarm、shockwave |
| 抽牌、能量与生命支付 | battle_trance、bloodletting、hemokinesis、dropkick、seeing_red、offering |
| 高费攻击 | carnage、bludgeon |

实际中文名称与文案读取 `data/presentation/traveler.zh-CN.json`；`data/cards.json` 的 `sts_name` 仅用于初代规则溯源。文案由项目模板生成，未引入他人图片、存档或程序。来源与适配边界见 [data/SOURCES.md](../data/SOURCES.md)，规则时序见 [data/README.md](../data/README.md)。

## 尚未开启的7张

以下卡牌保留数据供后续实现，但不能打出，也不会进入奖励、商店、营地升级选项：

| ID | 缺少的规则或交互 |
| --- | --- |
| clash | 手牌全为攻击牌的条件 |
| true_grit | 基础随机消耗与升级指定消耗手牌 |
| warcry | 选择手牌置于抽牌堆顶 |
| metallicize | 回合结束能力格挡 |
| whirlwind | X 费用按消耗能量重复攻击 |
| demon_form | 回合开始持续获得力量 |
| reaper | 按实际生命伤害恢复生命 |

不能去掉这些机制来把牌伪装成已支持。也没有把尚未支持的75卡参考表加入奖励池。

## 规则与验证边界

- 复制产生独立战斗实例，继承升级；战斗结束不进入永久卡组。
- 成长只属于当前牌实例，重洗牌保留，战斗后清理；手牌文案显示当前伤害。
- 生命支付绕过格挡与攻击修正，支付致死立即停止后续效果；保持失败判定。
- 临时力量在回合结束移除，抽牌封锁在下回合解除；条件收益依赖目标易伤。
- 格挡反击使用当前格挡作为攻击基础，仍受力量、虚弱和易伤修正；翻倍格挡直接增加现有格挡并遵守999上限。
- 多段攻击、虚无、消耗和能力牌移出本场牌堆仍由核心结算，UI只读状态并发命令。

`tests/lua/card_pool.lua` 有93组：明确列出30张基本/升级的独立预期结果（费用、实际伤害、格挡、抽牌、生命支付、状态、去向及复制/成长），30张经节点命令取得/营地升级后在下一战执行，并验证27张奖励来自**原始数据、真实初始卡组胜利**。同时固定检查支持池恰为30张、未实现7张不能进入可玩选项。各专项回归继续覆盖原子回滚、失败重试、目标、满手、跨战斗清理及反馈文案。

商店/营地测试是隔离节点集成夹具：用真实地图 API 准备前序导航、实际进入目标节点；金币设为商品准确价格，战斗设置高生命敌人与现有格挡，便于观察完整效果。它们证明事务与下一战效果，不代表已经走完同一局15层。奖励覆盖使用未改敌人或卡牌数值的真实初始卡组胜利。

离线命令：`npm ci --ignore-scripts`、`npm run check`；定向验证 `node scripts/test-lua.mjs tests/lua/card_pool.lua`。本轮未开启原神、未调用 MCP、未写入存档。平台编译、导入、30张卡实际显示/选择、营地升级后实机效果及完整15层通关仍待同一候选验收，TASK-16 保持 In Progress。

本轮完整门禁退出码0：JS 194项（180通过、14项Windows符号链接权限跳过）、Lua 24个脚本共716组通过、Python 16项（15通过、1项同类权限跳过）。没有失败或重试后才通过项。原始日志保存在工作树 `build/task-16-check.log`（生成目录不提交）。
