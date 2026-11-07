# 官方 Tween 与真实手牌的有界对照

实验候选变换器 `instrumentCardTween(source)` 只替换候选内的 `abyss_battle_card_view`，正式 `src/lua/abyss_battle_card_view.lua` 保持原样。运行时模块为 `abyss_3d_card_tween`。

菜单通过 `start(view,'manual'|'tween')` 选择一张已经稳定归位的真实手牌，横向偏移72单位后归位；`cancel(view,reason)` 中断，`status(view)` 提供屏内文本，`result(view)` 返回结构化样本。对象可传GameUI或其BattleUI。未进入战斗、仍有抽牌/拖牌/结算，或原生Tween接口缺失时明确返回原因，不改变规则。

A使用原有 `advancePose` 指数插值和 `applyHandPose`；B使用官方 `game.Tween(box,{anchoredPositionX=target},0.24):SetOnComplete(...):Play()`。仅x变化，原有y、缩放、角度、命中盒的局部位置/大小/反旋转不变，命中盒跟随父卡牌自然平移。B拥有期间原逐帧位置写入停止，每帧只读取当前原生x并同步真实的 `entry.current`、`cardPositions`；正常重绘在布局未改变时保留该位置。新布局目标、拖拽、视口变化、战斗切换、手牌移除、停止或销毁会 `Kill(false)` 并读回当前位置，交还原路径。迟到完成回调没有所有权时不再写卡牌。

统计只覆盖这一张卡的位置驱动：原位置重绘每次含7次Lua原生setter尝试；B记录Tween创建、完成回调注册、播放/中断控制调用和x读取，并包含初始/完成时的位置重绘。其他卡牌、文字和整个UI的调用不在该计数内。失败样本标为无效；不把异常之前预记的setter尝试当作成功写入。

两种归位曲线和时长不同：A保留项目原有行为，B固定0.24秒，因此总调用数不能当作同等时长的性能跑分。屏内同时注明OnUpdate回调间隔均值/P95、实验Lua驱动耗时与桥调用量；这些数据不能替代GPU帧时间、原生Tween内部成本、手机功耗或画面流畅度。完成A和B后屏内保留两次实测调用量。

官方来源：[客户端控件API](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhtakr07vej4)。本机离线官方文档明确将 `anchoredPositionX` 标为Tweenable，并定义 `SetOnComplete`、`Play`、`Kill(false)`；已有千星社区工具的pairs示例用TweenSequence完成翻牌动画。这里只复用这些能力，不制作新的手牌动画系统。

定向验证：

```powershell
node experiments/native-3d-lab/card-tween.test.mjs
node node_modules/fengari-node-cli/src/lua-cli.js -e "dofile('experiments/native-3d-lab/tests/card-tween.lua')"
```

JS检查候选变换锚点与Lua5.3语法，Lua mock检查真实位置读回、命中盒局部几何不变、重复回调所有权、拖拽/resize/换战斗/销毁/stop/移除中断、缺接口和失败恢复。它们验证本实验的交接逻辑，**没有验证官方引擎实际动画与手机表现**。

当前判断：官方Tween能减少这类单轴稳定归位期间的Lua位置写入，但为了与现有手牌生命周期正确交接，实验本身增加了适配代码。现有证据不能证明迁移完整手牌系统更简单或更流畅；保留这个有界实验，暂不迁移正式手牌动画。
