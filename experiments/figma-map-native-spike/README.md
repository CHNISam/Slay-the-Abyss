# Figma Make → 原生地图实验（非正式 UI）

参考：[PR468](https://github.com/CHNISam/Slay-the-Abyss/pull/468) `5ac67abfbc7e6ea3ec79c0127f3ec2c59eaba8e0` 四个实际 TSX/CSS 文件与[发布预览](https://app-spill-35276825.figma.site/)真实截图；参考源码见[固定提交目录](https://github.com/CHNISam/Slay-the-Abyss/tree/5ac67abfbc7e6ea3ec79c0127f3ec2c59eaba8e0/experiments/figma-make-map/source/src)。生产主题、入口和默认开关未修改。

## 入口

在本目录，设置 `ABYSS_ROOT` 为已核实的完整项目源码根：

```sh
# 先在项目根安装锁定依赖并运行 npm run build:data、npm run build:theme
ABYSS_ROOT=/path/to/checkout node build-probe.mjs
ABYSS_ROOT=/path/to/checkout FIGMA_SCENARIO=real-wins node build-scene.mjs
node --test tests/*.test.mjs
node /path/to/checkout/scripts/test-lua.mjs tests/scene.lua
# 复用已有 Simulator；每次用新的证据目录
ART_LAB_MCP_ENTRY=/path/to/beyond-simulator-mcp/dist/index.js \
  node tools/capture-scene.mjs scene.save.json evidence-local/run1
sh tools/encode-capture.sh evidence-local/run1
# 同一源码的手机画布闭环（仍是软件 Host，不是实体机）
ART_LAB_MCP_ENTRY=/path/to/beyond-simulator-mcp/dist/index.js \
  node tools/capture-mobile.mjs scene.save.json evidence-local/mobile1
```

普通 Git checkout 记录实际 HEAD、tree、dirty 与224个业务模块输入SHA；可用 `--source-manifest=/path/to/source-manifest.json` 强校验独立快照的输入/生成文件。本轮使用核验的 develop `de5607ba8edc0701c2545a587c85aefd499281b4`，不是未合并工作树。

- `sample.save.json`：贝塞尔/虚点/原生图库探针；`probe.generated.lua` 与内联脚本一致。
- `scene.save.json`：地图主视图技术切片，真实 Run / Map / Nodes，含原生输入所有权和只读返回。
- `presentation.attach(existingMapUI, root, options)`：实验装饰层；必须同时显式装配实验控件树。**当前只支持第一幕，非生产通用插件**。
- `FIGMA_SCENARIO=start`：全新真实局；`real-wins`：seed42实际 Run.play / endTurn 通关前两场，领取真实金币、跳过卡牌，无 HP、地图、RNG、结果强制写入。它是自动测试局，不冒称玩家存档。本轮自动准备在第2层停止（下一层没有直接可用普通战斗）；随后由真实指针选择第3层事件 `f3_l2`，不是又赢了一场战斗。
- 节点提交调用 Nodes.enter，.8秒表现后进入房间说明页。该页不是战斗 UI；查看地图只读，返回保持同一个真实房间/战斗对象，不假结算或解锁。

`scene.generated.lua` 是 Simulator 单文件封装（约2.5MB），不是官方客户端脚本容量/导入证据。未来GIL应沿项目模块装配链路，不能原样宣称可导入。

## 测试和证据

仓库根 `tests/figma-map-native-spike.test.mjs` 由现有 `npm test` / CI 分片自动发现。正常 `build:data`、`build:ui` 前置后也可单跑 `node --test tests/figma-map-native-spike.test.mjs`。wrapper 在临时目录从源码重建 probe / real-wins scene，执行全部实验 JS 与三组 Lua 断言并清理；不安装或启动 Simulator，不联网，不信任现成 save，不写 checkout。不调整工作流门槛；手动 Host 视频取证与该纯回归分离。

`tests/scene.lua` 对应上述 `real-wins` 构建。使用项目已有 `fengari-node-cli` 跑 `tests/{curve,presentation,scene}.lua`。`node --test tests/probe.test.mjs` 核对探针控件数量/单父60/内联一致。scene测试覆盖真实节点提交、重复拒绝、17层滚动不改整个Run/Map/RNG、房间预览返回对象不变。

Simulator实测涵盖 probe→连续曲线修正→整屏→实际点选/只读/返回及手机画布。每次保存固定save/hash、日志、无缺图回执；旧图不能证明新改动。采样脚本遇任何 `error`/`lua-error` 或资源警告即失败，动画只编码真实Host帧，不补间。MCP pointer坐标左下原点，PNG左上原点：`pointerY = canvasHeight - pngY`。截图时间不等于GPU FPS。

实测发现的约束已入测试：LuaHost无 `coroutine`（fixture用有界逐步状态机）；READY必须使实际原生根可见；层数文字24号需50高而非被裁掉的35高；返回按钮和提示须同stage缩放；采样pointer须应用所有祖先变换；鼠标事件 touchId=-1 不能当成触屏拒绝；每步 dt≤.1，不能把一次 step(.4) 误称界面前进400ms。

## 本轮按原型补齐的部分

- 原图的420/380虚线/300/210圆、48刻度、两个方形、34px连续回纹、26个微光；不是另起美术方向。
- 真实当前/已走/可选/未来/封路层次；真实可用的飞靴分支及后继参与视觉可达性，点击准入仍由原MapUI/Nodes负责。
- 图例计数与过滤、紧凑HUD、金菱形、短dash/空心进度与红色首领标记。
- 鼠标hover缩放、信息板与路线高亮；手机点按未达节点只查看信息、不越权前进；菜单只提供确实实现的继续/图例/说明，不放空卡组跳转。
- .75秒token/cubic-bezier与逐段金路、.6秒picked、.8秒spark、.36秒拒绝摇动。业务提交同步完成，镜头不再提前跳；原地图滚动/拖动/只读返回继续复用。
- 真实1560×720手机画布不再整体缩至.8：HUD14px/提示12px、实际画布锚点和viewport，未通过拉伸截图伪装修复。

## 预算和已知差异

- 固定1536个路径形状、256个辉光衬层，当前4319控件；单父≤60，不每帧创建控件。超过路径池会报错，不默丢正式路线。
- 256是**新增装饰动画API写入预算**，不是整屏总帧预算：不包括现有MapUI写入与状态/滚动的整次重绘。先保证路线与图标，spark/余烬按剩余预算让位；0..256剩余预算及48可见图标+新路径的反例已机械覆盖。未据此宣称全种子/全设备性能达标。
- 当前用原生控件近似渐变、金属层次与blur；没有已验证的网页字体/CSS混合/噪声等价渲染。Noto Serif/Cinzel字体、精确纹理/软阴影、雾漂移/柱纹视差与远处hover整路线的连续流动尚未等价实现；不能把这些剩余差异伪称一模一样。
- 依用户最新确认：节点、HUD与药水继续使用原神官方图标本体；呼吸、悬停、picked、光晕等只作非破坏性显示效果，不重画、不换成Figma的SVG本体。这是有意保留的差异；正式17层/7列真实图替代演示15层生成器是机制约束，不能为了像截图而改玩法。
- 控件命中、菜单modal、触屏只读信息、frame0不闪满路径、旧camera回调与resize均有回归；窄屏<900/<640代码断点不是实体手机验收，实际软件采样覆盖1600×900和1560×720横屏。
- HUD真实数值已接入，但完整战斗/卡组/药水页面不在此独立地图切片；Winged Boots非拓扑跳跃没有专用金路动画。
- 官方负载、GIL模块装配/导入、实机触控与持续FPS仍未验。模拟器单文件bundle约2.5MB不能直接拿来声明官方容量合格。

本轮结果摘要与原始产物SHA见 `evidence-summary.json`。完整交互桌面/手机图及短片绑定 `2fbafb9f…5073`；等价计算/查找优化后的最终源码为 `09d5148e…a81c1`，单独记录其取证，不混用哈希，不拿旧PR/旧CI成功认证未推送变更。审美由实际对照图判断，不自授9分。参考网页仍使用自身演示数据，明确视口和15/17层差异，不篡改网页再冒充原作。

CI收尾曾触及30秒子进程上限：未删断言或放宽门槛，改为最多64种平移不变曲线弧长缓存、复用既有控件索引避免每次render遍历全树；两项均红→绿回归，优化后根wrapper实测18.64秒；补官方图标本体约束后14项JS＋3组Lua再测20.21秒。

最终09d5另做桌面/手机各29真实帧闭环取证，33张截图回执均无assetWarnings；同状态初图与R10逐字节一致。完整hover/菜单/spark录像仍标注R10源，不挪用为最终源。独立160组旧/新曲线差分误差0，缓存65种形状触发淘汰。


## 顶栏与微光限定精修（2026-11-02）

- 卡组不是只核对 `105046`：正式 `scripts/deck-ui-layout.mjs` 的入口为36px金属盘、三张13×18扇叠卡背和9px官方中心图标。直接复用该组件 normal 视觉子树，撤掉实验中的裸19px替代；不引入另一枚官方图标或原型SVG。
- 原型数字为14px/700 Cinzel、HP上限为暗色 `#9e8c72`。本轮分开当前值与上限，用实际Host支持的 `<b>` 字重，金币图标到数字6px、胶囊组间8px，随真实数字长度排布。Host没有font-family选择，**Cinzel字形并未还原；官方富文本粗体待实机**。
- 保留参考26粒、9–23秒独立周期、负相位和±60px横漂。连续线性上浮不是改成新风格；纠正原实现4/26轮转产生的停顿。每个普通帧推进26个位置，alpha只写发生变化的整数通道，spark用剩余预算；若关键路线占满而不足26写则整组装饰暂缓，不丢路线、不提高256预算、不用游戏RNG。
- 顶部仍是17个**楼层**进度点，遵照用户最新澄清未改成4幕。
- 上节09d5/R10结果是历史已验版本，不是本轮粗体/间距/粒子精修证据。受102044官方素材访问拒绝，本轮先以明确独立的顶栏/背景局部原生探针验效果，不能把局部无图标场景称完整地图通过。

本轮原生局部首图已验证完整 `72/80` 与 `131`、原卡组组合和暗分母；首次拆框出现裁字，已按Host真实4px水平内边距修正并加对齐回归。根CI入口16项JS+3组Lua通过（24.53秒，子进程限时仍30秒）。24秒、20Hz、480张真实Host连续帧已录制，483张局部截图回执无缺图警告；不重播4秒片段，不代表完整地图素材齐全或实机FPS。源/投影/视频SHA分别在摘要中记录。
