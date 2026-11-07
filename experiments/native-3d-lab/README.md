# 原生 3D 战斗实验（TASK-102）

本轮扩展已加入拼装怪物、原生战后选牌和官方素材，完整四幕覆盖与组合建议见 [扩展结果](EXPANSION-RESULTS.md)。仍是同一任务、分支和PR，正式游戏暂不迁移。

同一个 GIL 内用实验菜单切换；正式游戏暂不迁移。正式 Lua 规则、数值和卡池不变，实验只创建同种子战斗夹具并替换表现。

## 游戏内入口

进入即显示 seed=42 的真实卡牌战斗和实验菜单。左上可收起菜单，右侧显示当前候选、请求/回执、错误与结果；日志最多12行，自动测试结果留在画面内。

| 菜单 | 行为与边界 |
| --- | --- |
| 2D / 3D | 现有正式2D战斗和官方3D战场切换，保留手牌、HP、意图与点选靶区 |
| 怪物展示 | 遗迹守卫、大型风史莱姆、打手丘丘人；复用官方复杂造物和动画 |
| 动画 | 手动待机/攻击/受击/销毁，以及自动连续；仅守卫的受击clip有已核实目录 |
| 完整战斗 | 使用正式卡牌、能量、回合和伤害结算；原生技能只做表现 |
| 卡牌对比 | 正式卡牌与原生UI分组动效样张；真3D卡牌未找到可复用的文字/输入路线，菜单明确不可用 |
| 卡牌 Tween A/B | 同一张真实手牌横向归位，对照现有插值与官方原生Tween；屏内显示局部Lua调用和中断结果 |
| 性能配对 | 相同种子、相同8条实际卡牌/回合命令，分别预热后采样；轨迹或有效样本不符则作废 |
| 全部连续 | 自动切模型、动画、卡牌与性能；单项失败记录原因，其他项继续 |
| 停止 / 重置 | 取消队列、拒绝迟到回执并恢复2D；可重新开始同种子战斗 |

死亡实验调用 `destroyEntity`，名称为“原生销毁表现”。没有找到可直接播放的官方死亡clip，不能据此声称死亡动画控制已通过。玩家现成攻击clip也未接入，菜单中明确提示。

## 构建与复现

需要项目依赖与已安装的千星MCP（`MILIASTRA_MCP_ROOT`可指定目录）。所有存档写入均是工作区内副本，`MILIASTRA_ALLOW_LIVE_WRITE=0`，构建不会操作键鼠、打开存档或发布。

```powershell
npm ci --ignore-scripts
node scripts/build-native-candidate.mjs '<干净且已由7.1编辑器保存的底图.gil>' '.artifacts/3d-production'
node experiments/native-3d-lab/build.mjs '<上一步candidate.json>'
```

第二步输出不可变UUID目录内的 `native-3d-lab.gil` 和 `experiment.json`。导入只需该 GIL，额外JSON是开发取证材料，不要求玩家手动打开。生成器记录源提交、实际输入hash、基础候选、每次工具回执、动画/模型来源、最终脚本和UI读回以及最终GIL hash。

原生模型元件从工具自带官方“复杂造物”样本复制结构，再绑定已核实资产ID、自有决策图及技能。**离线结构兼容和编译已验证；官方客户端能否生成/显示这些模型仍需本轮导入确认。** 不把社区历史实测当成本候选结果。详见 [原生能力与来源](NATIVE-CAPABILITIES.md)。

## 开发验证

```powershell
npm run build:data
npm run build:ui
node experiments/native-3d-lab/native-scene.test.mjs
node experiments/native-3d-lab/tests/build.test.mjs
node experiments/native-3d-lab/card-tween.test.mjs
node scripts/test-lua.mjs experiments/native-3d-lab/tests/runtime.lua
node scripts/test-lua.mjs experiments/native-3d-lab/tests/production.lua
node scripts/test-lua.mjs experiments/native-3d-lab/tests/card-tween.lua
```

测试覆盖异步初始化/退场、重复序列、桥超时、停止重启、失败隔离、相同命令轨迹、原生图无伤害节点、官方模板副本不改输入以及原生UI编码误差边界。Fengari/mock桥证明规则与调度行为，不能证明官方动画实际显示。

## 如何解读结果

- 屏内FPS/mean/p95/p99为客户端 `OnUpdate` 回调间隔，不能替代GPU帧时间。脚本启动前的加载、GPU时间、内存、官方容量没有当前已验证接口，明确为不可获取；手机待实际设备测量。
- 配对样本必须经过原生退出/ready回执、预热、同样8条命令且演出队列清空。超时、丢回执、提前切模式或动作轨迹不同的组不得用于性能优劣判断。
- 同档包含两个表现方案，文件体积不代表迁移后的资源节省；当前只比较实际显示与脚本间隔。正式删除自制图元后能省多少资产、代码与官方负载，仍需单独测量。
- 原生技能不创建命中盒、不发原生伤害，模型同阵营且有无敌状态；玩家固定位置。卡牌HP、伤害与胜负唯一来源仍是现有Lua规则。

## 迁移判断

原生复杂造物已提供可复用模型、攻击和部分受击动画，值得优先进行这一轮实机验证。当前不建议直接迁移正式版本：死亡clip、玩家动作、模型结构实际兼容以及手机画质/流畅度/内存证据尚未齐全。只有这些结果和同内容维护成本对比通过后，才能确定下一代方案。

Tween最小场景减少了动画期间的位置写入，但增加了与现有手牌交接的代码，且两种曲线/时长不同；当前保留实验、不迁移正式手牌动画。单个Tween已足够，不为这一场景引入TweenSequence编排。详见 [Tween实验](TWEEN-EXPERIMENT.md)。

本轮构建、验证和独立复审结果见 [RESULTS](RESULTS.md)。
