# 战斗卡牌动态数值反馈验收记录

数字已按原版方式留在原说明句中，只有发生变化的数字及紧邻↑/↓局部红绿；原卡面图标、费用、排版和命中区保留。**PC受控渲染已验证；物理手机和全UI验收未通过，TASK-4.6仍在进行中。**

## 实现与来源

- PR：[194](https://github.com/CHNISam/Slay-the-Abyss/pull/194)，按当前SHA两项CI成功后才能合并develop。
- 初始develop `695d94d`，已同步 `35fc111`编号修复；生产运行源码冻结 `bd7620d8fa4adafe254cdeaddec93315c2c94b8e`，循环夹具为 `6e22f2028043d276087fa904363a8ff023a9fb9d`。后续证据提交不改运行源码。
- A档原生句内着色。1849探针确认颜色标签解析和箭头字形后才接入生产控件；不使用HTML/CSS，也不借离线图声称平台支持。
- `abyss_card_display.lua`只读比较本卡当前定义与同效果预览。战斗公式、状态持续时间、目标判定、结算和随机流：**未修改**。
- [实现契约](../../backlog-details/card-value-feedback.md)、[逐用例矩阵](test-matrix.csv)、[机器证据](evidence.json)。

## 功能与实机证据

| 场景 | 本地 | PC原生受控渲染 |
| --- | --- | --- |
| 无状态中性数字 | PASS | [PASS](native/neutral.png) |
| 脆弱防御5→3↓ | PASS | [PASS](native/frail.png) |
| 敏捷防御5→8↑ | PASS | [PASS](native/dexterity.png) |
| 虚弱打击6→4↓ | PASS | [PASS](native/weak.png) |
| 易伤目标瞄准/取消 | PASS，同手牌原生事件stub | [9↑](native/aim.png) / [恢复6](native/cancel.png)，夹具上下文；不认证物理拖动 |
| 混合效果逐项颜色 | PASS | [格挡7↑、伤害4↓](native/mixed.png) |
| 多段、Body Slam、升级、成长 | PASS | 部分呈现已观察；精确场景的未测范围见矩阵 |
| 不依赖颜色 | PASS | [原生截图灰阶模拟](native/mixed-grayscale-simulation.png)，不是手机灰阶设置 |
| 扇形/选中与输入 | 1/5/10牌及三种尺寸几何、控制器事件回归PASS | [十牌](native/ten.png)、[真实鼠标点牌选中](native/selected-mouse.png)；完整真实拖动/十牌选中/手机触摸未测 |

原生窗口物理3840×2160，导出画面1600×900。证据图片只遮挡底部UID区域；鼠标帧按等比缩小导出，未修改卡面/文字/颜色。十牌按批准稿扇形叠放，不能把它写成所有手牌全文同时无遮挡。

普通候选：根`.artifacts/card-inline-candidate/scenes/saves/abyss-card-inline-normal.gil`，SHA256 `5e8e5705a60cb6a39be5be017bce0499173d2f084855ecf14c0bc526141814cc`。独立审计49模块同源、2339控件一致、最大直属58、静态0错误32警告，音乐图/双true参数保留；输入副本hash未变。普通候选未作官方自然流程试玩。

PC专项为上述普通候选的独立夹具副本，入口和状态受控，SHA256 `f51581d390bd7c7cfbbd0cccb058f94e7a43520be8887827eb691e4686712e4f`。官方导入1851的50模块与UI树逐项匹配，官方快照hash `328e2f89b2f57d7888f1fb79b3e91a566c408e02f4ebb2388a0f140df608005a`。run `ccd6fe38-95ad-4d93-9d2d-5fca20f4bcc7`显式开启客户端日志；本轮33打印含init/viewport_ready/ready及各场景。**夹具不证明正常获取状态、物理瞄准/取消、完整通关或普通候选自然流程。**

## 自动化与严格门禁

| 验收层 | 结果 |
| --- | --- |
| build:ui / 只读模型 / 真实生成树 / 成长 / 夹具 / 布局 | PASS：模型10组、预览19组、成长11组、夹具8阶段、布局/对比度4项 |
| 本地新版JS | PASS：1226项，1108通过、118跳过、0失败 |
| 本地新版完整npm run check | **FAIL**：gremlin_gang.lua达到30秒上限；没有改超时或规则来刷绿 |
| 超时用例独立复跑 | PASS：29组、1680选择路径，19.332秒；具体超时原因未证实 |
| 实现提交6e22f20完整CI | [PASS](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40118154321)：check与presentation成功，180个Lua文件；不代替最终证据提交的当前SHA检查 |
| 新普通候选独立回读 | PASS，0错误32警告；不是官方导入/实机 |
| 1851夹具官方导入/PC渲染 | PASS，限上述受控渲染与一次鼠标选中观察 |
| 物理手机渲染/触摸 | **NOT_RUN**；1280×720、1560×720、1600×900仅本地几何回归 |
| 同普通候选verify:ui | **FAIL**，各屏仍为partial/pending；清单未改成pass |

完整UI未通过项：menu、map、battle、rewards、cardChoice、result为partial；camp、shop、event、treasure、deck为pending。本任务原生数字显示证据不能认证这些全屏检查。

## 剩余步骤

最终PR当前SHA CI成功后集成；保留手机/完整拖动和严格全屏门禁待测。普通候选若与后续游戏源码合并，须重新统一构建并核对，不用本次截图冒充未来组合实测。未发布或投稿。
