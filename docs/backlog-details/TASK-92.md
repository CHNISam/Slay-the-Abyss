# TASK-92 出牌忙态与规则禁用分离

基线为 PR432 `89349b1fd3b0b01b5d02203b8a9c7b37d6f3e2a3`。原报告及原作核查边界见 MOBILE-QA-20261029-SOURCES.md：未核原作逐帧表现，不声称原作从不出现红色提示。

真实宿主回归先红：能量为0时，零费「愤怒」与X费牌的 Combat.canPlay 为真，切到 busy 后原 card.enabled=false 却驱动 CardSkin 的禁用遮罩和「当前不可打出」。真实费用不足仍有独立的 insufficient_energy 原因；本修复不是扣费修复。

仅卡面适配器新增规则 playable，视觉使用该值；输入 enabled 仍受 active 限制，动作层 busy/active/手势守卫不变。真实能量不足、敌方回合等规则原因继续显示。未改费用、随机流、动画或新视觉设计。

`node --test tests/card-busy-visual.test.mjs tests/card-blocked-source.test.mjs` 最终4/4通过，无跳过，约4.5秒。新增断言覆盖零费、X费、真实费用不足红色、busy/overlay拒绝操作、敌方回合与恢复、完整Run快照不变；另经正常防御牌命令进入真实反馈帧，核对0能量期间零费/X费无伪禁用并最终解锁。新增测试在原实现于busy断言失败，保留原Core/节点遮罩合同。

未执行完整CI，由唯一集成方对最终组合运行；无官方候选、导入、ready、设备录像或手机验收。任务保持进行中，不将源码复现绑定到未知版本用户截图。
