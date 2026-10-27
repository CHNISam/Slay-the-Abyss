# 腐化之心胜利后的继续页

TASK-64，后端基线`7382aef99ca47fecc3f496f3b297ee5cc1ac91e5`，规则与真实Run事务见[终幕路线](../rules/ENDING_ROUTE.md)。本片只改Nodes、NodeUI、Host及专用NodeUI辅助模块；没有修改Run、Actor、Combat、地图节点身份、工程门禁或Backlog。

真实Heart胜利进入`ending_proceed`后，Host显示独立等待页，复用已批准的eventView外观和黄金继续按钮。页面标题“腐化之心已击败”，正文“继续进入真结局。”，没有事件选项、奖励条目或库存数字；卡组、药水入口也不显示。它不是随机事件，不进入EventPool，不创建reward bundle，底层55层地图节点和nodeFlow仍为boss。继续前不会显示胜利结果或自动提交平台结算。

Nodes只用Run冻结的Act4出生资格做完整Map.restore，核对55层固定boss节点、当前path、地图签名、原boss flow及同一胜利owner，再将原对象直接交给`Run.proceedEnding`。没有额外事务复制owner；拷贝owner、旧Run、错误地图和重复继续拒绝。NodeUI捕获run/map/view/flow及原始owner身份，检查当前控件祖先，并在观察到身份失效后永久退休旧回调；修复原值不能复活旧Down/Up/Click。普通重绘后的新回调仍可执行合法继续。

成功继续后才显示“真结局 · 深渊已被封印”、真结局说明和55/55；原普通胜利标题与文案保留。结算仍由用户主动操作，不因展示真结局自动发起。

2026-10-28实际验证：预写Nodes fixture真实RED（缺可信Map Proceed边界443ms）；合入真实Run API后，Nodes三组GREEN 3.620秒，严格生成Host三组GREEN 5.654秒。覆盖完整地图恢复及四种地图损坏、复制owner/旧Run拒绝、真实Heart构造后的受控胜利、无奖励等待页、控制器继续、ABA身份修复后旧手势拒绝、遮罩旧回调失效、最终胜利及原普通文案保留。每份使用原30秒预算，未运行桌面或原生平台。没有为测试放松产品守卫。

新增helper固定Luacheck无语义诊断，全部辅助函数复杂度最高10；受影响现有职责测量均≤15。13项既有NodeUI诊断仅位置移动，精确身份与四文件LF hash见[静态交接](../evidence/heart-proceed-ui-static-20261028.json)。最终集成模块分类、诊断位置对齐与当前SHA完整CI由父集成执行，未新增豁免。

fixture明确构造历史资格和三钥匙、跳过52至54房间，并以真实队列消费记录此前精英；实际55层仍通过Nodes.enter/Run/Combat构造Heart，再将敌方HP设零隔离胜利边界。这不是自然取得钥匙、完整战斗通关或平台验收证据；M3与TASK-64整项仍未完成。
# 组合复审补充

组合复审发现 `Map.snapshot` 会通过复制抹去调用者原始地图的元表，可能使伪造末尾节点通过恢复校验。公开 `Nodes.proceedEnding` 的真实回归先在 root `__pairs` 伪装下失败；改为将原始地图直接交给只读的 `Map.restore` 后，根、节点数组、最终节点三层元表都拒绝，原 Run 引用、owner 和原地图字段均保持。Nodes 现4组及严格 Host 原3组串行通过，共9.642秒，未改30秒单文件预算。这是离线拒绝边界，不是自然或平台验收。
