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

原主题中的 `hitStop=0.05`、`hitStopHeavy=0.1`、重击阈值与蓄势曲线是项目自己的画面设计，不能当作原版参数。敌人逐招音效与 VFX/伤害的精确先后仍须按对应 AI/action 调用链继续核对，不能由这次保留 VFX 的修复推断全部一致。

## 后续：动作等待与快慢模式

在同一现有 feedback 边界内，将 damage gate 改为固定 `DamageAction` 的 0.1 秒和普通模式额外 0.1 秒；自制 hit-stop 继续画面冻结但不再增加输入阻塞。`DamageAllEnemiesAction` 的默认 base 是 `Settings.ACTION_DUR_FAST=0.25`，快模式只移除额外 0.1；没有用统一倍速缩短所有动画。

`WhirlwindAction` 每轮明确使用 `DamageAllEnemiesAction(isFast=true)`，因此 base 为 0.1，每轮各有等待和音效。原分类把整张旋风的多轮合为一个群体，已改为每次目标序列重复开始新轮，保留每轮一次 cue。`Brilliance.use`、`FlechetteAction.update`、`BarrageAction.update` 明确使用 superFast DamageAction，这三种普通模式同样不追加 0.1 后等待。

新增 API 为 `feedback:setFastMode(boolean)`；每批 begin 将模式冻结在 `playbackFastMode`，中途切换在下一命令生效。主 session 持有正式 `battleUI.fastMode` 与设置入口，接线是在普通 `perform` 调用 `feedback:begin` 前同步 `self.feedback:setFastMode(self.fastMode == true)`；本工作树只验证真实 host 出牌和 adapter API，设置按钮本身的验收由主 session 集成后完成。

新增回归扩展为 8 组，实际全部通过。源时长断言覆盖普通/快模式、重击、Cleave、三轮 Whirlwind、上述三个 superFast 来源、模式切换；原 `feedback_polish` 的全部 17 组保留，只将三个“等待时间必须额外加项目 hit-stop”的错误预期改为更严格的固定源 0.2 秒上下界，视觉冻结断言仍保留。以旧生产 feedback 独立运行这些新源区间断言时，原普通、重击、致命三组实际失败；新代码通过。原 startup recovery 5 组通过，未变更超时或 runner。

新增核对文件的 SHA256：

| 固定参考 | SHA256 |
|---|---|
| `actions/common/DamageAllEnemiesAction.java` | `3562ea16a19d0951b36198a4191fd48358c7cb408595ef2c503fc4b7763ec123` |
| `actions/unique/WhirlwindAction.java` | `80438c28161227043e2a489cd9da373947d1d6d2646fa07e41b2c4ad902aa96e` |
| `cards/purple/Brilliance.java` | `6ce900f30a94f7c99cf44fc022f2c2e5da5bda4c35638d00f304e4a531150a26` |
| `actions/unique/FlechetteAction.java` | `a23ddc4092aae1d031c24e7596e2f92ba9ea7be9257f5f75c492a23f3836ee62` |
| `actions/defect/BarrageAction.java` | `b8a842b45ca8fee18daad81758ad218c6d337646ef80ccd2aceb74ce4f0923fe` |

仍未声称完整原版时间轴：当前 `play` 飞牌段继续采用批准主题的 0.2 秒；其他卡的专属前置 WaitAction、VFX 先于 HP 改变的准确帧、非 damage 事件的动作 provenance、球与药水专属 action flag 等尚需逐链补齐。完整 UI/音画实机仍未验收。

## 后续：Bludgeon 的显式前置等待

`Bludgeon.use` 是零等待的 `VFXAction(WeightyImpactEffect)` → `WaitAction(0.8)` → `DamageAction(NONE)`；`WaitAction` 在 FAST_MODE 下将大于 0.1 的等待截为 0.1。本次在已有只读表现列表中、该牌首个玩家 damage 前加入 `action_wait`，普通 0.8 / 快速 0.1，使用前一张快照而非提前展示扣血。没有向核心动作队列或核心事件写入额外内容。

新增第 9 组回归通过真实 host 出牌，测量两个模式的完整前置等待、显示旧 HP、延后现有 contact cue、保持完整已提交状态和核心事件身份/数量、正常一次消费。上个提交实际结果为原 8 组通过、第 9 组在“缺少原版前置 WaitAction”断言失败；修复后 9/9 与原 polish 17/17 通过。主题飞牌的 0.2 秒仍单独保留，未把这个项目动画段算作原版 WaitAction。

来源 SHA256：`cards/red/Bludgeon.java` 为 `c056710affefba665c41a77dd95b8ec937632b5026a55374a5077676bd5a1915`，`actions/utility/WaitAction.java` 为 `6e19a09e368f720698b713be7e6226111f1a02d6c9fe465aa32d53959258a045`。原 WeightyImpact 的独立 1 秒坠落效果、0.8 秒冲击钩子及 1 秒声音仍未逐帧移植；现有岩系特效/音效不得据此宣称是原版 WeightyImpact。
