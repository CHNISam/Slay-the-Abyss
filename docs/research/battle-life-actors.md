# 角色待机与动作衔接：原版研究及本轮移植

本轮限定岩系旅行者第一、第二幕。`abyss_actor.lua` 是战斗算术与状态规则，保持原样；新的 `abyss_actor_motion.lua` 只提供四个数值的肖像变换，接入已有 feedback 的姿态、受击与死亡合成，不建立时间轴或第二套动画引擎。

## 实际读取的资料

读取本机固定 ZIP `.artifacts/sts1-fixed-source/sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`，SHA256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。这是社区反编译镜像，未认证原版 PC 二进制，也不是官方开放源码。产品只按行为事实独立实现，不复制 Java 方法体、Spine 动画或素材。

固定链接前缀：[aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。

| 文件与行 | 已读取的行为 | 本项目采用方式 | 文件 SHA256 |
| --- | --- | --- | --- |
| `characters/Ironclad.java:57–60,271–277` | 循环 Idle；受击播放一次 Hit 后回 Idle，Hit→Idle 混合为 0.1 秒；动画播放速度 0.6 | 不照搬 Spine；旅行者用小幅连续呼吸，已有受击动作优先，结束后自然恢复待机 | `6fc9b761251a96f9e3a8e31adb3698f87dbaca07a7d3f0b931c9a9ea0bbcf132` |
| `monsters/exordium/Cultist.java:67–69` | 循环 waving，并设置随机起始轨道时间 | 代表人形怪轻摆；按实际 actor ID 确定相位，完全不消费游戏 RNG | `93e6404234a9c57f794c1f98f7943b60c62e66c464dd19d7579913fd75ad7f4f` |
| `monsters/exordium/JawWorm.java:100–102,123–124` | 循环 idle；tailslam 一次后排回 idle | 代表兽形怪轻微压缩/舒展；软泥沿用压缩型，其余两幕敌人保守呼吸，不冒充逐怪重制骨骼动作 | `e0950443e76332942fe556687782e8e18d91ee683a6c22ca0eb2e5663d4a312e` |
| `core/AbstractCreature.java:219–287,326–334,699–749` | 统一动画枚举、计时器与局部偏移；攻击按朝向前冲再插值回零；开始动作清局部偏移；腾空时不触发 stagger/shake | 保留已有 feedback 方向、关键姿态、插值和回零；只补待机及显式抑制关系，不把额外对象或控件加入核心 | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| `monsters/AbstractMonster.java:165–170,845–859,934` | 常规动画、死亡、逃跑各更新；死亡推进淡出和清理；普通与加速死亡时长不同 | 沿用本项目已有死亡/逃跑以及加速事件时序；死亡和逃跑抑制待机，不重写规则层判死 | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |

本项目显式采用 `death > escape > hit > action > idle` 的合成优先级。这是适配原生肖像 UI 的本地策略，不宣称原版有相同显式优先级表。原版攻击曲线并未全部搬来；本项目已有关键姿态和命中时序，本轮继续复用。

## 接线合同（中控统一集成）

共享文件 `abyss_feedback.lua`、`abyss_battle_render_state.lua`、`ui_theme.json`、`config/architecture.json` 由中控修改，本分支仅交付模块及专用回归。

1. `config/architecture.json.layers.abyss_actor_motion` 分类为 `ui`。主题 `motion.actorIdle` 新增 `{period:3.6,scale:0.012,lift:1.2,sway:0.8,maxDelta:0.1}`，再运行 `npm run build:theme`。这些是本项目保守小样值，未声称由原版实测取得。
2. feedback 初始化 `idleClock=0`，`reset()` 清 shadow、idleClock、idle 绑定。不要在正常 finish 清除待机绑定；正常 finish 后仍应给玩家和活敌待机。
3. 新增 `bindIdle(battle)`：只有非 busy 时才绑定真实 battle 到 shadow（只读）；换 battle 时清理旧视觉身份。render_state 的 renderFrame 取到 battle 后，只有 `owner.active and fighting and not owner.busy` 时绑定；离开战斗/隐藏时取消绑定，不每帧重置时钟。
4. `update(dt)` 保持无 shadow/无活动效果时早退；有 idle battle 时即使队列为空仍执行。`idleClock=Motion.advance(idleClock,dt,T.actorIdle)` 与事件 `elapsed` 完全独立。该时钟在后台大帧只推进 0.1 秒，不拿它推进动作、结算或补消费事件。
5. paint 前取真实 actor、当前 posed/effect/dying/escaping，计算 `state=Motion.state(...)`。初值从 `Motion.idle(actor,id,idleClock,state,T.actorIdle)` 取 x/y/sx/sy，然后沿用现有 pose、paintMotion、paintDying。pose.age 正常推进、到期清理；若 state 为 hit/death/escape，不把旧 pose 的 px/ps 应用到肖像，避免攻击姿态压住高优先级反馈。
6. 有待机绑定时，把 player 和存在且存活的 enemy ID 纳入原有 paint 列表；死亡不重新显示，半死/逃跑禁用待机；保留 EnemyView 的槽位归属。只改 portrait，不改血条、意图、状态、box 或点击框。
7. 有活动姿态/命中特效时不叠加呼吸。普通完成回到当前确定相位的呼吸，幅度只有 1.2 像素/1.2%；取消、失败与换场仍走已有 reset，确保没有残留偏移/缩放。

## 已验证与未验证

先运行专用回归得到缺少模块的真实红灯，再实现采样器。`node scripts/test-lua.mjs tests/lua/actor_motion.lua` 通过 6 组：时钟合法性/后台大帧、优先级、旅行者/祈火徒/石颚兽/第二幕默认敌的幅度边界、非待机中性变换、稳定身份相位且禁止调用 RNG、不分配变换对象的 20000 次时钟更新。测试没有改规则状态、事件或随机流。

模块每演员每帧只返回四个数值，不创建控件、定时器、协程或变换表；存储仍由已有 feedback 的有限演员集合承担。离线循环能证明数值有界，不能证明手机帧率、平台非等比缩放、实机呼吸观感或音画品质。生产接线、取消/回位与同候选 PC/手机回归由中控统一验证，本分支未操作官方客户端与键鼠。

中央接线后的独立复核：从集成工作树运行本分支 `tests/lua/actor_idle_feedback.lua`，5 组真实 `GameUI`/`BattleUI`/`Feedback` 路径通过（约 2.8 秒）：初次进入且没有出牌事件也待机；肖像变化不改生命/意图/名称/点击框坐标及规则与各 RNG 流嵌套字段；后台 120 秒只推进 0.1 秒视觉时间；真实 strike 的事件队列完成后继续待机且解锁输入；已有 2x 攻击姿态不能覆盖受击和死亡；取消归零、隐藏残留动作停止、重新激活重新绑定。首轮夹具未将新局从地图带入战斗，按既有生产 setup 补上真实 `Run.startCombat` 后原断言通过，没有为测试放宽生产逻辑。此结果仅对应当时中央接线源码，最终组合门禁由中控重跑绑定候选。

## CI 回归修复：终局历史与视觉清理的边界

完整 CI 发现 Awakened One 与 Darklings 的原有终局断言失败：战斗转奖励时 `bindIdle(nil)` 的完整 reset 误清本战 `deaths`。本轮先复现三个旧 JS 文件的 3 项失败，并新增 `actor_feedback_lifecycle.lua` 得到“离开战斗丢失死亡历史”的红灯。最小修复只改 feedback 的 bindIdle/reset：解除 idle 绑定时保留本战身份和死亡账本，其余 shadow、时钟、姿态、命中、牌流和控件均清理；明确取消和换到另一战仍全清。新测试再验证退休后不继续绘制、同战重绑保留、下一战复用 ID 不继承死亡、cancel 清账本。

Summon 原功能回归另有连续待机预期变化：旧四项精确静止等式会拒绝任何正常呼吸。本轮按中控明确批准改为主题幅度上界检查，保留全部同槽身份、可见、生命、无旧数字及点击断言，并增加无死亡染色/透明度断言、死亡塌陷与击退必被拒绝的负控。没有投影旧源码或关闭新待机，没有修改冻结见证、时限或规则。三个旧 JS 文件修复后 7/7 通过；补强染色断言后单独 Summon 再过，旧 actor_idle_feedback 5 组及新生命周期专用测试也通过。最终源码变化需中控重新冻结严格 source-layer 身份和重新构建候选，先前审查记录不能冒充修复后 SHA 验收。
