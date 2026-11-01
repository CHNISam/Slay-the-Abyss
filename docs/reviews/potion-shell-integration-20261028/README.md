# 药水外壳纠偏：源码与离线证据

本轮不是视觉验收完成。用户拒绝上一轮自创药水外观，依据仍为
`docs/design/ui-canvas/Main.dc.html`、`Map.dc.html`。官方瓶图 ID 不重画；离线渲染器里的实心圆瓶代显不能证明官方瓶形或原生像素。

## 身份与范围

- 接入前精确源：`26614cb7872b1a30f09ec2bd6e02524a07e69b92`，保全分支 `backup/dot-ui-pre-potion-20261028`。
- 远端 develop 只读确认：`1f260a71972b03dae5b63e8d6f12d055973a4c83`。它的治理/CI 15 路径与前一轮 UI 五提交零重叠；已无冲突线性 rebase 到 `8d216ad7b279db1e0069c0c6c4a4da92b3f1b50c`，没有 merge commit。
- 仅叠加共享药水壳体、两个所属主题对象及 Main/战外真实状态刷新；没有改药水规则、库存身份、命令、RNG、官方图 ID 或其他 UI 几何。
- Main 保留隐藏的 `border`/`plate` 兼容路径与隐藏 `label`，消费 helper 的全部七个顶层控件。空槽、普通药水、火焰药水、真实菜单/瞄准选中态分离；先退役失效 popup owner 再涂色。
- Map 整排仍是原来的管理入口，不新增单槽直接使用操作。

## 第一阶段（单 soft-disc；已被评审要求继续修正）

`new-tests-red.log` 在旧源真实失败：Main 缺少 emptyShell；源树缺少 empty/filled 分离。
原子接入 Map helper/主题字段和 Main runtime 后，`shell-first-green.log` 7/7；
`main-map-input.log` 40/40、零跳过（45.77s），包括真实 Lua Main/host、地图 repaint、详情/能量及原输入夹具来源保护。
这些通过不认证后续梯度修正源。

独立评审发现第一阶段亮部只是小斑，没有还原原稿覆盖整个圆面的径向色场。因此不能以本阶段测试全绿结束本轮。

`tree-conservation.json` 对接入前后整棵 battleLayout 做 strictDeepEqual，仅移除五槽各态的壳体子树后完全相等；药水位置/尺寸与其他控件均不变。第一阶段生成树 2603→3243 节点，最大直接子控件仍 60；Game 树 10331。只是静态资源计数，不是设备性能认可。

该阶段完整串行 27 个 Lua 文件另存 `first-phase-lua-regressions.json/log`：原 53case/6seed、5host、11 药水 target 边界及原 38 地图组均在原预算内通过。哈希绑定单 soft-disc 阶段，不冒充下述最终梯度源的结果。

## 最终源码阶段（双 soft-disc 拟合；完整门禁待运行）

已按独立评审仅增加所属主题字段和每个 filled/fire 壳的一张既有 soft-disc：整内圆居中的中色层，加内切的上方亮层；normal 的 base/mid 为 `#2C231E/#312722`，fire 为 `#33221D/#3B251F`，均来自各自原稿明暗端点插值，而非另创配色。

可移植的 `tests/potion-shell-fidelity.test.mjs` 直接读取两个原 HTML 的端点、焦点和尺寸，并使用实际 helper/theme；没有绝对路径、环境开关或替代 helper。旧单小斑源 2/2 红，新拟合 2/2 绿。每类采样 7837 点；仅在既有离线线性 soft-disc 模型下，whole-face RGB MAE 从 8.809/10.253 降为 1.288/1.478，最大通道误差仍 4.601/7.335。2/255 与 8/255 是防退化的离线工程界限，不是用户 UI 验收标准，不证明官方纹理像素。

`final-short-green.log` 9/9：上述源场检查、空槽 alpha/18 段虚线、实际 Main 菜单/瞄准/消费/丢弃/失效 owner/第五槽、真实 Map 稀疏容量 repaint 均通过；`final-exact-inverse.log` 6/6。最终 inverse 摘要 `39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a`，原历史链不变。架构 221 模块/1265 边；最终静态仍 73 条历史诊断、零新增、原复杂度预算通过。

`final-tree-conservation.json` 再次证明其余战斗树 strictDeepEqual，最终 battle 为 3283 节点（接入前 2603，+680），Game 为 10411，最大直接子控件仍 60。隐藏 preset 的分配量不等于同时可见图像；不删四态、dash 或兼容路径来刷预算。

完整 `npm run check` 将在该最终源码阶段串行运行。此前 focused 与历史 replay 不充当完整 check；实际全门禁结果需单独保留。

## 历史与静态合同

`static-relocations.json` 逐一绑定 18 条既有诊断与声明引用的相同源行，73→73，零新豁免；静态检查沿用原 render≤10、辖域函数≤15。`static-green.log` 保留本阶段实际结果。

附加的 58 源 inverse 仍先恢复精确 `53fa164a9914dd8a7a5849ff741925dd3131f5e4`，再进入原 26 源层。原 26 源 gzip、原逐写轨迹、golden、case/seed 与 runner 预算均不更改。
`exact-inverse.log` 6/6 包含全源哈希、完整历史物化和拒绝局部/重复/移动/无关漂移；后续真实 Lua 与最终源绑定另列，不把来源核对当运行时通过。

## 集成边界

开放 PR311 的 battle 重构与本候选在 `abyss_battle_ui.lua`、架构/静态基线及历史接层交叠；PR310 的 node 重构与本候选在 `abyss_node_ui.lua`、架构/静态基线及历史 materializer/test 交叠。未把它们拉入本树、未替别人改 PR；由主线程协调后续顺序。

完整仓库 check、精确新 SHA 的托管 Quality/inventory、官方导入/ready、同候选 PC/实体手机 UI 与性能验收仍缺。没有推送、PR、合并、发布、用户 Codex、客户端或键鼠操作。
