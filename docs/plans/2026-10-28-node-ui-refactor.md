# Node UI 专项重构实施与验收

**Goal:** 以 develop 1f260a71972b03dae5b63e8d6f12d055973a4c83 为旧行为基线，主文件≤1000行、构造器≤350行，保持正式界面和节点交易。

**Architecture:** 每个 UI 实例持有一个私有 ctx；ctx.self 是对外适配器，host 可以替换 self.run/self.map，模块每次命令仍读取它们。ctx 不导出、不缓存到模块全局。模块安装只注册闭包与原生监听，不执行节点交易；首轮 render 在全部安装完成后执行。

**Tech Stack:** Lua、原生控件、Fengari、Luacheck 1.2.0、Node test。

## 实施步骤

1. 从最新 origin/develop 建独立工作树，固定旧版 SHA；不带入根工作树在途修改。
2. 按下表拆分职责；保持原生路径、渲染顺序、迟到事件校验、声音触发点和 Nodes 命令参数。
3. 原有高复杂度函数继续拆成具名局部职责；保留全部提取函数≤15复杂度门禁，所有 Node UI 模块≤1000行、每个函数≤350行。
4. 原生交互、布局及旧新对照通过后提交独立 PR。Combat、Run、数据、布局和 .github 工作流均不修改。

## 模块边界

| 模块 | 责任 |
|---|---|
| abyss_node_ui | 公共入口、节点身份切换、页面路由、公共页脚与顶部资源 |
| abyss_node_ui_shop | 商人实例、商品选择、既有 ShopUI 组合、离店页脚 |
| abyss_node_ui_camp_actions | 营地休息/锻造显示、既有 CampUI 组合、Recall 原生所有权 |
| abyss_node_ui_events | 事件文案、动态选项、结果说明与阶段动作绑定 |
| abyss_node_ui_event_ownership | 事件的渲染期身份、原生父链、选项池与手势失效校验 |
| abyss_node_ui_treasure | 开箱、首领遗物分页、领取/蓝钥匙互斥与令牌所有权 |
| abyss_node_ui_rewards | 升级/移除/变换/恩赐/图书馆/捕梦网选牌、预览、必选状态同步与确认 |
| abyss_node_ui_faces | 共享卡面、遗物及药水说明；费用仍读取规则定义 |
| abyss_node_ui_feedback | 按钮视觉、按下/悬停状态、观察失效动作、原有动效及奖励详情实例 |
| abyss_node_ui_input | 原生监听合流、触点归属、迟到 Click、滑动吞点、长按检查、控制器绑定 |
| abyss_node_ui_lifecycle | 可见性/缩放/更新、命令重入保护、原有 Nodes 调度和提交后反馈 |

ctx 的共享服务由 host/职责安装器创建，模块不互相 require，因此没有循环依赖。手势捕获的是当时 action 对象；render 重新绑定后旧触点不能采用新命令。父链读取可能重入，最后一次原生读取之后仍重新核对所有权。交易声音只在 Nodes 接受命令后触发，演出失败不能撤销已完成交易。

## 验证命令

- npm run check:architecture
- npm run check:lua-static
- node --test tests/node-ui-refactor.test.mjs tests/node-ui-layout.test.mjs
- node scripts/compare-node-ui.mjs
- npm test

compare-node-ui 从固定 git 对象读取旧主文件，保持当前未修改的依赖模块，在独立 Lua 进程对旧新版本重放全部8个节点用例分片及手势回归。每个用例末尾以确定顺序比较完整原生控件树（含文本、颜色、可见性、坐标、缩放、监听事件键）、节点适配状态、核心资源/永久牌组/节点流程与地图快照；不序列化函数体和 parent 回环。用例原断言仍逐项检查命令返回与交易。SHA256完全相同才通过，不以截图近似或最终金币相同替代。

2026-10-28 用户明确授权仅同步 scripts/check-lua-static.mjs 的 Node UI 定位及新增行数门禁；≤15阈值不变，.github工作流不变。重构前未治理的渲染/输入大函数已继续拆分，不能靠移动函数避开门禁。

## 证据边界

本专项离线重构与行为对照不宣称官方导入、实机或正式UI验收通过；本轮未发送桌面输入。实机需另行协调输入窗口，不能复用旧截图/日志。
## 验证记录（本轮）

- 主文件245行，主构造器221行；全部Node UI函数≤350行，最大提取工厂309行。
- Luacheck 1.2.0：Node UI无新增诊断；13条旧Node UI静态豁免已移除。完整Node UI职责300项复杂度测量，最高15，阈值未放宽。
- 架构检查230模块/1291边通过；语法检查、Backlog治理和12项布局/检查器/规模回归通过。
- 完整本地npm test曾与对照重放同时执行，已主动停止以消除CPU竞争；该次不记完整通过。扩展手势曾在竞争下触及原30秒期限，仍保留原门槛，后续以串行复跑和PR当前SHA Quality为准。
- 旧新对照范围：固定基线的40组节点交互与本轮22组手势；九组快照及最终状态见docs/evidence/node-ui-refactor-20261028.json。
- 最终串行手势复跑22/22通过，17670ms，原30000ms期限未改；九组旧新快照全部一致。
## 合并前源码回归适配（2026-10-29）

Quality发现Recall/宝箱静态断言仍读旧主文件，历史表示层回放亦绑定旧整文件hash。已把静态断言定位到camp_actions/treasure/lifecycle，并验证公共入口确实安装对应模块；原生交互用例与命令断言全部保留。

测试专用逆投影以docs/reviews/node-ui-refactor-sources-20261029.json.gz保存固定develop原主文件和重构后11个职责文件的完整SHA256。读取当前源码时先逐文件验证完整身份，再恢复原固定源，沿既有逆投影链执行原始历史断言；不加载到游戏。历史原79543/79757次原生写入、旧源码回收hash和文案删改/重复/移动负例均保留，并增加每个提取模块的漂移负例。9项完整历史回放检查通过，Recall14组及蓝钥匙宝箱17组完整交互用例通过；运行时代码及CI工作流未改。
