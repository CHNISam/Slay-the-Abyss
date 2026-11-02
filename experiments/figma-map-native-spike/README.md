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
```

普通 Git checkout 记录实际 HEAD、tree、dirty 与224个业务模块输入SHA；可用 `--source-manifest=/path/to/source-manifest.json` 强校验独立快照的输入/生成文件。本轮使用核验的 develop `de5607ba8edc0701c2545a587c85aefd499281b4`，不是未合并工作树。

- `sample.save.json`：贝塞尔/虚点/原生图库探针；`probe.generated.lua` 与内联脚本一致。
- `scene.save.json`：地图主视图技术切片，真实 Run / Map / Nodes，含原生输入所有权和只读返回。
- `presentation.attach(existingMapUI, root, options)`：实验装饰层；必须同时显式装配实验控件树。**当前只支持第一幕，非生产通用插件**。
- `FIGMA_SCENARIO=start`：全新真实局；`real-wins`：seed42实际 Run.play / endTurn 通关前两场，领取真实金币、跳过卡牌，无 HP、地图、RNG、结果强制写入。它是自动测试局，不冒称玩家存档。本轮自动准备在第2层停止（下一层没有直接可用普通战斗）；随后由真实指针选择第3层事件 `f3_l2`，不是又赢了一场战斗。
- 节点提交调用 Nodes.enter，.8秒表现后进入房间说明页。该页不是战斗 UI；查看地图只读，返回保持同一个真实房间/战斗对象，不假结算或解锁。

`scene.generated.lua` 是 Simulator 单文件封装（约2.5MB），不是官方客户端脚本容量/导入证据。未来GIL应沿项目模块装配链路，不能原样宣称可导入。

## 测试和证据

仓库根 `tests/figma-map-native-spike.test.mjs` 由现有 `npm test` / CI 分片自动发现。正常 `build:data`、`build:ui` 前置后也可单跑 `node --test tests/figma-map-native-spike.test.mjs`。wrapper 在临时目录从源码重建 probe / real-wins scene，执行全部实验 JS 与三组 Lua 断言并清理；不安装或启动 Simulator，不联网，不信任现成 save，不写 checkout。本轮云端约17.4秒，未放宽现有 CI 超时；手动 Host 视频取证与该纯回归分离。

`tests/scene.lua` 对应上述 `real-wins` 构建。使用项目已有 `fengari-node-cli` 跑 `tests/{curve,presentation,scene}.lua`。`node --test tests/probe.test.mjs` 核对探针控件数量/单父60/内联一致。scene测试覆盖真实节点提交、重复拒绝、17层滚动不改整个Run/Map/RNG、房间预览返回对象不变。

Simulator实测涵盖 probe→连续曲线修正→整屏→实际点选/只读/返回及手机画布。每次保存固定save/hash、日志、无缺图回执；旧图不能证明新改动。采样脚本遇任何 `error`/`lua-error` 或资源警告即失败，动画只编码真实Host帧，不补间。MCP pointer坐标左下原点，PNG左上原点：`pointerY = canvasHeight - pngY`。截图时间不等于GPU FPS。

实测发现的约束已入测试：LuaHost无 `coroutine`（fixture用有界逐步状态机）；READY必须使实际原生根可见；层数文字24号需50高而非被裁掉的35高；返回按钮和提示须同stage缩放；采样pointer须应用所有祖先变换。

## 预算和已知差异

- 固定1536个路径形状、256个辉光衬层；不用每帧创建控件。越界报错，不默丢路线。
- 256是**新增装饰动画API写入上限**，不包括现有MapUI节点更新，也不包括滚动/状态变化的整次重绘；不能称整屏总帧预算。当前生成控件数见 `scene-inventory.json`，仅分组单父≤60。
- 首轮16段逐段图库辉光出现“链条”；真实Simulator截图发现后改为连续低alpha宽线衬层，无新增粒子。它是CSS blur近似，不是等价阴影。
- 椭圆分层/细线圆环替代CSS渐变与SVG；尚缺 hover整路线预览/tooltip、精细仪式刻度与方形构图/柱纹、完整HUD操作、噪声、精确字体/混合模式；曲线有放大分段误差。**没有达到原型的忠实完成或9分验收，不是正式UI替换**。
- Winged Boots等真实准入由Nodes.available保留；非拓扑跳跃尚未专门绘制金色路径，不改业务来掩盖。
- 全种子池容量、触控实体机、官方负载、原生导入/GIL、持续FPS均未验证。截图无assetWarnings是素材加载证据，不是视觉品质或发布许可。

本轮结果摘要与原始产物SHA见 `evidence-summary.json`。最终桌面动图/只读返回截图对应同一 `372d534a…` 场景；手机画布截图来自修正底部返回布局前的 `7f31d141…`，不把不同构建混称同候选。
