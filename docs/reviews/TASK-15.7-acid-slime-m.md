# TASK-15.7 · 中型酸液团的三招与污染牌

## 有限可玩缺口与实现

固定基线 `05aa11cfced32ab7bf23ba7ac6430d63bdc6c6e5` 已在 `medium_slimes` 合法遭遇中使用中型酸液团，但其原数据是固定29生命、7伤害/虚弱交替，缺普通10伤害和污染牌。本片只修这一个现有敌人的A0行为；不扩大卡牌、敌人、遭遇或职业池。

- 普通生成HP按28–32闭区间抽样；开场消费一次0–99主roll。HP抽样与开场选招均先于当前战斗的洗牌。
- 主roll0–29选择酸蚀攻击（7伤害，随后弃牌堆生成1张既有Slimed）；若前两次均为该招，则额外消费无参数Boolean，true改普通攻击，false改虚弱。
- 主roll30–69选择普通攻击（10伤害，不塞牌）；若上次已为普通攻击，则额外消费概率Boolean，成功改酸蚀攻击，失败改虚弱。普通攻击不能连续两次。
- 主roll70–99选择虚弱1；若前两次均为虚弱，则额外消费概率Boolean，成功改酸蚀攻击，失败改普通攻击。
- 两个概率Boolean都使用源代码的 `0.4f`，其精确binary32值是 `0.4000000059604645`，判断为严格小于。没有把无参数Boolean替换为该概率，也没有在不需要回退的分支额外消费随机数。A17的40/40/20与另一套连招限制不混入A0。
- 每次已执行动作末排一次主roll，再按必要条件排一个额外选择；独立敌人保留独立历史。沿用PR136已核对的damage→Slimed→roll队列：满格挡仍塞牌；荆棘反杀但有同伴时保留已排塞牌及roll，末敌死亡清队列；行动前被毒杀不执行或选招。没有扩大公共死亡来源接口。
- 保留原内部动作ID `_1`（酸蚀）与 `_2`（虚弱），仅增加 `_3`（普通攻击）；复用现有意图显示、状态牌与卡牌生命周期。没有新增玩家文案或美术。

## 固定来源与适用边界

只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。GitHub base64响应解码后的原始字节分别复算Git blob和SHA256，不给展示文本补换行。仅提取行为事实并独立实现；第三方源码不提交到本仓。该镜像未与正版PC发行二进制做hash认证，不是官方源码、原作客户端观察或千星实测。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/AcidSlime_M.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_M.java) | `b8d5ee4d71b7084624a19b73cf0c7b4df38a54d0` | `34fe1c1000d351ffd3ee1e5902a0af14ebb10fe3885bd181feeb75c1942cb400` |
| [random/Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | `c4b71d5645688f6e764c46c593223eb91a5249bc` | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |

`AcidSlime_M` 的普通构造、A0 `getMove` 与 `takeTurn` 对应HP、三招、边界、重复限制及排队次序。`Random` 区分 `nextBoolean()` 与 `nextFloat() < chance`，不把二者混为同一种抽样。共享 `AbstractMonster.init/rollMove/createIntent`、`Slimed`、`RollMoveAction`、`MakeTempCardInDiscardAction` 与末敌清队列来源沿用 [TASK-15.6固定来源表](TASK-15.6-spike-slime-m.md)，本片未修改这些共享接口。

当前运行适配器仍使用项目共享LCG：无参数Boolean映射两值域的第二值为true；概率选择映射16位格点 `(random(65536)-1)/65536`。这是已有项目RNG边界，不是原作RandomXS128的布尔/24位浮点分布或分流。新增HP、主roll和回退抽样会改变当前后续洗牌、奖励等轨迹。只声明受控输入下的决策及调用顺序；不声明同种子整局、精确总体概率或完整原作RNG一致。

大酸液团分裂生成的 `newHealth` 与中毒继承构造尚未接入；本片只覆盖现有普通遭遇的直接生成。该缺口和大型软泥分裂仍留TASK-15，不伪装成已实现。

## 回归与门禁

- 修改生产代码前，新Lua20组在基线为3过17失败，覆盖固定HP/首动、缺普通攻击、缺Slimed、错误循环和死后已排roll。新schema24项全部红。原始日志保存在交付工作区。
- 最终专项Lua21组通过，其中纯决策以13种独立历史×100个主roll×2个回退结果，共2600次输入核对结果和额外随机调用类型/次数。边界覆盖29/30、69/70；16位适配域26214/26215以及直接等于/低于精确0.4f的比较均验证。真实Combat覆盖HP端点、伤害/塞牌顺序、格挡、虚弱持续、队友/末敌反伤、毒死、实例隔离。
- 专项schema24项、相关JS共343项通过；验证缺失/错类型/错误引用、重复动作ID、无序/越界cutoff、非法概率和酸蚀攻击逆序/缺牌/错牌/额外塞牌。新模块通过实际候选脚本发现器唯一注册，总37模块；不是平台编译。
- 从完整远端树881项（未截断）逐项核对本地快照，并额外取回原来缺失的45个JS/Python执行文件，全部Git blob校验。所有远端原生Lua测试105份均在本地，加入本片后106份；所有4个Python测试文件均已取回。检查了数据/schema、生成器、原型与牌数精确断言，本片不增卡，未改旧期望来规避失败。
- 正确LUA_PATH与真实battle布局wrapper下，全106份native Lua fixture通过；初跑11份环境注入失败（10份搜索路径、1份缺布局全局）留有日志，修正测试启动方式后全部重跑。宿主为Lua5.4，不等同生产Fengari或千星运行时。
- Python实际发现并执行17项，全部通过，零发现不作通过。`build-lua-data`、`build-ui`、`map-ui-layout`、`build-ui-theme`、`validate-data`与JavaScript语法检查通过。
- 扩大JS检查曾发现4个 `build-lua-data.test.mjs` Lua桥接测试因本快照缺 `fengari-node-cli` 而失败；没有安装依赖或把这些记作通过。之后不依赖该桥的相关343项独立全绿。未执行完整 `npm run check`，准确发布SHA的完整Quality由主线程核验，远端CI不能用本地部分检查替代。

本片没有启动原神、MCP、沙箱、官方导入、存档写入、实机或发布。M1及其他平台关口、全池原版一致性与随机流精确一致均不关闭。独立复审及发布SHA的CI状态以对应PR为准，本文只记录已执行的离线检查。
