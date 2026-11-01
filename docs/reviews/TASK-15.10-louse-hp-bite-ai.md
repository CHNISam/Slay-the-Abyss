# TASK-15.10 · 红绿虫生命、咬击与选招

## 有限范围

基线 `dabaaf1b60fa38212079c4cac8b2e57aa732e306` 的合法赤甲虫/青甲虫仍为固定13生命、6咬击和攻击/辅助交替。本片只修正现有两个变体的HP、每实例咬击与A0选招，不新增遭遇、牌池或自创数值。

- 赤甲虫普通生成生命10–15；青甲虫11–17，均为闭区间。静态13保留为范围内代表值，运行时不再固定为13。
- 每只虫在自己的HP抽样之后立即抽一次5–7咬击，之后才构造下一只敌人；所有敌人构造完再进行各自开场主roll。该值只写入已复制的演员意图，不改全局数据、该局目录或其他实例。之后出招/重绘/取意图不会再抽咬击。
- 开场和每次已执行动作后各消费一次0–99主roll。0–24选择辅助，25–99选择咬击；如果前两次均是所选动作，则改选另一招。A0允许连续两次辅助，不能误套A17辅助不连发的分支。
- 既有辅助效果保持赤甲虫力量+3、青甲虫虚弱2，伤害仍经过共享力量、虚弱、易伤和格挡算法。实际UI意图显示采样后的值及核心修正，查看不更改战斗状态。
- 行动中被荆棘反杀，有存活同伴时继续其已排主roll；末敌清队列、行动前毒死不行动不roll。复用既有有限队列契约，不重写动作管理器。

## 固定来源和真实性边界

只读核查社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。GitHub base64响应直接解码原始字节，并独立复算Git blob/SHA256；未给展示文本补换行。只提取规则事实并独立实现，不提交第三方源代码、图片、音频或原文案。该镜像未与正版PC发行二进制hash认证，不是官方源码或原作客户端/千星实机证据。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [LouseNormal.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseNormal.java) | `f56e24b37816f256bd058184c1b54a49584092a7` | `b9a875b240236ac28e5c427584f56af1751604b7781bc6c1a5535fa888f9775f` |
| [LouseDefensive.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseDefensive.java) | `83dc2dad1247ef33c5ef76ec5ca5cdbc5ced8def` | `48a0b5c54a745c1842d10f61754edf0ea28efeb676816efa5a131bce1a7a5bd0` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` | `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50` |
| [CurlUpPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CurlUpPower.java) | `5bbbfd5b627b6cab2b5aa3e7c11411692c156351` | `82ae7c5809cd06d58c0280a0ceebf642977635e0fe2d2d33f85006c552b4116d` |

两构造器均先 `setHp`，再从 `monsterHpRng` 抽取咬击；`AbstractMonster.setHp` 给出生命抽样事实。`init/rollMove` 与两个 `takeTurn/getMove` 分支确定主roll及历史限制；无隐藏的条件Boolean抽样。`RollMoveAction` 本身没有拥有者死亡guard，末敌/毒死清理沿用已有 [队列来源账本](../rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md)。

## 明确未完成

**Curl Up尚未实现，不能据此称两只敌人完整一致。** 两虫 `usePreBattleAction` 还会各自从 `monsterHpRng` 抽取3–7并施加一次被动；本片没有这个额外抽样、被动状态、首次非致命普通攻击后的排队格挡、移除/重复触发防护及其UI。后续须单独核查其与多段/范围/致死/反伤/动作队列的边界，不能用预先加盾或每回合加盾替代。

生产仍为共享16位LCG，不是原版独立HP/AI流或RandomXS128。新增HP、咬击和主roll会改变后续洗牌/奖励等轨迹；本片只声明当前受控输入下的有限调用顺序和决策，不声明完整构造/开战随机流、种子映射、精确总体概率或整局一致。A2/A7/A17分支不纳入A0。

## 可复验输入与结果

- 修改生产前，真实Combat/Run26组为3通过/23失败，schema33项全失败。红例包含固定HP/伤害、构造抽样顺序、24/25边界、两招连续限制、反伤死后的主roll和真实双虫辅助。不是先改实现再补预期。
- 修复后26组通过，包括两变体各8种历史×100主roll的1,600次独立预期、128种子HP/咬击端点、每个演员HP后Bite的请求序列 `6,3,7,3,100,100,4,3,2`（最后三次为四牌洗牌）、同色实例和目录隔离、普通修正/格挡、真实Run与失败出牌原地回滚。
- 新schema33项及相关JavaScript共408项通过。校验缺失/错型/额外字段、整数范围、动作引用/种类、不同动作、咬击单一普通伤害载荷，候选发现器独立确认新模块恰好一次。
- 全部远端测试清单已核对：基线109份顶层Lua、4份Lua支持模块、59份JS、4份Python均存在且未遗漏；新增后111份顶层原生Lua全部通过。新真实生成UI测试显示5/7独立咬击、HP以及力量/虚弱后的8/5，查看不改状态，真实结束回合玩家损失13HP。
- 完整原生回归首次发现Jaw死亡夹具仍把赤甲虫当作不消费随机的同伴。仅将该夹具的同伴替换为开场后SetMove的护盾小魔，保持毒死无roll和反伤已排roll的原有断言；未关闭新AI、削弱生产行为或取消测试。最终111/111通过。
- Python实际执行17项全部通过，不以零发现冒充通过。数据、界面、地图布局、主题生成，数据校验和JavaScript语法检查通过。
- 扩展JS主题组412项中411通过、1失败：`built theme loads in Lua with converted colours and without the design note` 缺少现有环境的 `fengari-node-cli/src/lua-cli.js`。该失败如实保留；另一个不依赖该桥的408项受影响组全部通过。没有安装依赖或执行完整 `npm run check`。原生宿主是Lua5.4，不等同Fengari/千星运行时，完整发布SHA的Quality由主线程核验。

独立复审和当前SHA CI结果以PR为准。本片未启动原神、沙箱或MCP，未编译/写入平台存档、官方导入、实机或发布。全池原版规则、完整随机流、Curl Up和全部平台关口继续保留。

## 2026-10-24 M1 集成测试成本修正

以上为原切片的历史边界。本节只记录固定 `166972b` 的测试拆分，不改生产规则或已完成任务状态。

PR162 的 Quality run `40068392599` 中，原 `tests/lua/louse_ai.lua` 在默认30秒上限超时：红色全部通过、绿色前七组通过，进入绿色800决策组时尚无断言失败。相同固定源在本机为26组全部通过、22.3秒；不能用较快本机结果否认真实CI失败。

按已有独立变体拆分，每项仍用完整Data、真实Combat/Run和原30秒上限：

- `louse_red_ai.lua`：赤甲虫11组，保留128种子端点和8历史×100主roll的800次独立决策；本机12.1秒。
- `louse_green_ai.lua`：青甲虫同样11组、128种子和800决策；本机10.7秒。
- 原 `louse_ai.lua`：保留4个构造顺序、同色实例隔离、真实Run双虫和失败出牌回滚场景；本机0.7秒。
- `support/louse_ai_fixture.lua`：仅抽出原公共辅助和整个颜色测试体，由两色各自调用。支持目录不会被顶层Lua发现器当作另一项测试。

原颜色测试体（含全部循环和断言）、所有公共辅助及4个共享测试体已与 `166972b` 逐字节核对；26个PASS名称合并后与原脚本完全同序。没有裁剪目录、换数据、跳过case、减少决策/种子、放宽超时或修改通用运行器。现有顶层Lua自动发现会同时运行三项，仍为26组、每色800决策。

原始基线日志、三项默认上限下的结果和机械等价核对脚本位于根 `.artifacts/m1-louse-test-cost/`。正式当前PR SHA的完整Quality仍由主代理统一执行，不把本地专项或先前134项全过冒充新SHA正式CI通过。未操作游戏或平台。
