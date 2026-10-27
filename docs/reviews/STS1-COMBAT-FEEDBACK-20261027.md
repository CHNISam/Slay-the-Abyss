# 连续出牌保留未结束的画面反馈

基准为 `develop@c91f0d22`，只读参考 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。该社区反编译镜像不是官方源码授权或经认证的 PC 二进制；本次独立实现行为，没有复制其程序或素材。

## 方法依据与差异

| 固定参考方法 | SHA256 | 可核对的行为 |
|---|---|---|
| `actions/GameActionManager.java:update` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` | 当前 action 结束后调 `getNextAction`；无 action 且未使用牌时恢复 `WAITING_ON_USER`，不要求画面 effectList 为空。 |
| `actions/animations/VFXAction.java:update` | `66e4dfc9ec5b2195b289af792a1ad21d49592bfd9685fed8584a35d394a2f160` | 首次 update 将效果加入独立 effectList/topLevelEffects；action 只 tick 自己的 duration。 |
| `dungeons/AbstractDungeon.java:update` | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` | 独立遍历 effectList 更新各效果，仅移除其自身 isDone 的效果。 |
| `actions/common/DamageAction.java:update` | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` | 基础 duration 为 0.1 秒；结束时实际 damage，非 skipWait 且非 FAST_MODE 再将 0.1 秒 WaitAction 插入 TOP。 |

当前正式入口是 `GameUI → battleUI.perform → Run.play → feedback.begin`。原有 action gate 已经允许在飘字和 HP 残影结束前恢复输入，但 `feedback.start` 每次无条件 `reset`，所以此时立刻出下一张牌，会取消前一张在其他目标上尚未完成的反馈。

修复只在换 battle 时重置整组原生控件；同一 battle 的下一批次保留现有非阻塞效果及其时钟。每个目标仍复用原来的固定控件，新命中可以取代该目标的旧数字，不新增随事件创建的控件。取消、失败和替换 battle 继续完整清理；死亡标志从当前批次 before 帧重建，复活的单位不会继承旧死亡动画。

## 针对性回归与入口

- 新增 `tests/lua/feedback_continuous_cards.lua`：3 组；旧生产代码 2 组失败、1 组通过，修复后 3/3 通过。通过真实 host 手选牌、选敌及 Run.play，覆盖输入已恢复后继续出牌、两个目标独立 VFX 时钟、音效不重播、最终效果收束、取消和换战清理；后续画面更新前后完整 battle 状态递归相等。
- 原 `feedback_polish.lua` 17/17、`feedback_start_recovery.lua` 5/5 通过，保留原断言及 runner 的 30 秒预算。使用 Node 24.19.0 和仓库 Fengari；初次 sandbox 限制子进程（EPERM）为执行限制，放行本地 runner 后取得实际结果。
- 没有修改核心规则、数值、随机模块、卡面、主题或动作队列。未下载第三方图片音频，未操作键鼠、官方导入或发布；没有把控件替身测试记为实机体验验收。

## 本切片未完成的范围

原主题中的 `hitStop=0.05`、`hitStopHeavy=0.1`、重击阈值与蓄势曲线是项目自己的画面设计，不能当作原版参数。当前 damage 步骤等待主题 base 再加该停顿；它与固定 DamageAction 的精确等待边界仍有差异。当前也没有正常设置入口切换原版 FAST_MODE，未在本切片假造已接通。敌人逐招音效与 VFX/伤害的精确先后也须按对应 AI/action 调用链继续核对，不能由这次保留 VFX 的修复推断全部一致。
