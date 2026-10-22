# TASK-10.1 · 图元角色肖像最小实验

日期：2026-10-23。分支 `feat/art-portrait-spike`，从 `develop` / `91ae349` 创建。

**复核结论：直接 Lua 拟合路线暂不进入正式头像候选。** 上游直接导出的 Y 坐标有 128 像素偏移；已增加导出输入坐标适配，并用模拟 API 逐一核验两档全部位置。但两档分别有 27 / 72 个椭圆越过 128×128 画布，而 Lua 没有裁切，不能把 PNG 当作实际显示效果。本实验不增加预算、不新增裁切框架、不批产。没有接入游戏 UI、导入存档或操作真机。

## 问题与退出条件

- Question：能否用现有工具把一个项目自制头像转换为基础图片控件，并量化低/高图元预算的离线成本？
- Success criterion：同一源图得到 64 / 256 图元 JSON、PNG、可解析 Lua；记录耗时、文件大小和图像误差；提供可替换的模板索引位置。
- Relationship：与战斗界面和图片编辑器路线正交；这里只提交研究及小样，不修改核心 Lua、主题数据或正式资源。运行路径最终由真机结果决定。
- Disposition：reject 当前直接 Lua 作为首发头像方案；保留诊断样本及研究结论。正式肖像画质、容量与移动端性能未回答，禁止据此批量生产。

## 来源、版本与许可

上游：[1475505/Miliastra-toolbox-primitive-shape](https://github.com/1475505/Miliastra-toolbox-primitive-shape)，固定提交 [`0526509e73d36b359d3c9bee1104718e4a600ed0`](https://github.com/1475505/Miliastra-toolbox-primitive-shape/tree/0526509e73d36b359d3c9bee1104718e4a600ed0)。查询 `releases/latest` 返回 404，故不声称存在正式版本号。已读 [tech.md](https://github.com/1475505/Miliastra-toolbox-primitive-shape/blob/0526509e73d36b359d3c9bee1104718e4a600ed0/tech.md)、[user_guide.md](https://github.com/1475505/Miliastra-toolbox-primitive-shape/blob/0526509e73d36b359d3c9bee1104718e4a600ed0/user_guide.md) 及实际 Python / Go 源码。

主项目 MIT，Copyright 2026 LiuL；第三方 primitive MIT，Copyright 2016 Michael Fogleman。生成 Lua 含上游运行时，因此本目录保留 [Shaper 许可](LICENSE-Shaper.txt) 与 [primitive 许可](LICENSE-primitive.txt)。许可说明不能替代角色素材本身的权利确认。

本实验输入 [source.png](source.png) 由 [reproduce.py](reproduce.py) 用项目自制几何绘制，没有使用上游 demo 或第三方肖像。只用金发、花饰、白蓝服装与主题岩金作为技术识别点；**不是用户批准的正式角色画质，也不改变 PR #19 视觉方向**。原型内没有可复用的独立岩荧肖像，主代理已同意此技术样本。该简单源图会低估真实立绘、表情、发丝与半透明边缘所需预算。

源码与上游二进制仅下载到根目录 `tools/vendor/primitive-shape`，不提交 vendor。网络 clone 未完成后改为下载固定 ref 的必要文件；没有安装新包或修改上游源码。`tools/primitive.exe` 的 Git blob 为 `5bf8b4a6acff6fa46107497befa265a20634a83a`，与上游目录记录一致；SHA-256 在 [measurements.json](measurements.json)。这只证明下载内容一致，不代表本机从源码完成可重复构建。

## 复用路径与本机依赖

实际复用 `primitive_backend.fit_image_with_primitive` → `fill_shaper.results_to_elements` → 项目样本的坐标适配 → `lua_export.build_lua_export_text`。适配只在导出输入副本里给 `center.y` 加图像高度，JSON 原始数据不变。这是一个样本脚本调用现有 API，不是新增框架。直接调用核心 API 还能指定两个 worker；`shaper_core.process_image_fill` 没有向后端透传 workers。

| 项 | 现状 |
|---|---|
| Python 3.12.10 | 项目工具链现有解释器，本实验可运行 |
| OpenCV / NumPy / Pillow | 现有安装，具体版本见 measurements.json |
| Flask | 本机 Python 3.12 未装；未运行 Web 服务或 server.py CLI，无需为本实验安装 |
| Go | PATH 未找到；复用仓库附带 primitive.exe，未编译 Go |
| GUI / MCP / 游戏 | 本分支完全未调用 |
| GIA | 未导出；上游构建器仅发布 `.pyc`，没有必要为 Lua 小样引入此依赖 |

上游 `AGENTS.md` 声称 Python 3.13+，但拟合与 Lua 导出这条公开 Python 源码路径在本机 3.12.10 已运行；不将该结果推广为 GIA 字节码兼容。`tech.md` 同时残留“替代 Go”与“调用 Go”两种历史说法，实际 `shaper_core.py` 必经 `primitive_backend.py` 调用 Go 可执行程序。

## 输入、参数与结果

128×128 不透明 PNG，背景来自主题 `backdrop #0F1117`，岩金来自 `geo #F0B850`。两档均为椭圆（`circle` → rotatedellipse mode 7）、`detail_scale=1.0`、`workers=2`、`output_alpha=1`，完整 JSON 参数和一次运行观测见 [measurements.json](measurements.json)。源图与拟合图全部以 128×128 保存。

![左：输入；中：64 图元；右：256 图元](comparison.png)

| 预算 | Lua 控件数 | 拟合耗时 | RGB RMSE（0–255） | PSNR | Lua 大小 |
|---|---:|---:|---:|---:|---:|
| 64 | 64 | 29.811 s | 16.462 | 23.801 dB | 10,626 bytes |
| 256 | 256 | 112.385 s | 13.934 | 25.250 dB | 25,906 bytes |

RMSE / PSNR 是源 PNG 与上游生成的**裁切后 PNG** 的全图 RGB 像素误差，不能覆盖画布外泄漏；不是人物识别率、真机画质或 GPU 性能分数。表内 Lua 大小为首次未经适配的原始导出记录；修订后的字节数为 10,693 / 25,754，见 [export-review.json](export-review.json)。只有一次运行、同一台共享机器，不是稳定性能基准。上游使用时钟随机种子且没有 seed CLI 参数，复跑不保证同一图元列表或同样秒数。

64 图元的金发、服装和花饰仍可辨，但眼部、嘴部和面部结构明显糊化，轮廓存在椭圆拼接痕迹。256 图元的轮廓和眼睛更接近输入、块面伪影减少，嘴部与发丝仍糊化。图元增加 4 倍、耗时约 3.77 倍，RMSE 降低约 15.4%，不能据此认为真机成本同倍率变化。正式肖像不能用这张简化源图验收。

导出样本：

- 低档：[Lua](portrait-64.lua)、[JSON](portrait-64.json)、[PNG](portrait-64.png)。
- 高档：[Lua](portrait-256.lua)、[JSON](portrait-256.json)、[PNG](portrait-256.png)。

## 复现命令

先获取上述固定 ref 的 `fill_shaper.py`、`primitive_backend.py`、`lua_export.py` 与 `tools/primitive.exe`。这四个文件足以运行本次路径；完整上游也可。遵守上述许可证。根目录示例：

```powershell
git clone --depth 1 https://github.com/1475505/Miliastra-toolbox-primitive-shape.git tools/vendor/primitive-shape
git -C tools/vendor/primitive-shape fetch --depth 1 origin 0526509e73d36b359d3c9bee1104718e4a600ed0
git -C tools/vendor/primitive-shape checkout 0526509e73d36b359d3c9bee1104718e4a600ed0
```

在本 worktree 根目录运行；会覆盖本目录的同一小样文件，无任何存档写入：

```powershell
New-Item -ItemType Directory -Force build/portrait-temp | Out-Null
$env:TEMP=(Resolve-Path build/portrait-temp).Path
$env:TMP=$env:TEMP
& 'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe' docs/experiments/art-portrait/reproduce.py --vendor 'F:/New folder/tools/vendor/primitive-shape'
```

本会话沙箱中 Python `TemporaryDirectory` 产生 ACL 拒绝（即使 TEMP 在工作区），经批准在沙箱外运行同一离线命令成功；没有通过修改权限绕过。无需在普通用户终端改上游代码。

等价 Go 参数由后端生成：`primitive.exe -i input.png -o output.svg -o output.png -a 0 -r 0 -s 128 -j 2 -bg ffffff -m 7 -n 64`；高档只将 `-n` 改成 `256`。Python 随后完成 SVG 转 JSON 与 Lua 导出。

## 两项评审复核及诊断导入挂点

1. **Y 坐标错误确认并修正**：`fill_shaper.py` 输出 `center=(cx,-cy)`，原点实际是原图左上、Y 向上；`relative` 已相对图像中心。上游 Lua 却把 center 当成左下原点再减半高。64 档第一个图元的 JSON `center.y=-71.9`、`relative.y=-7.9`，未经适配 Lua 输出 `-135.9`；本次适配后输出 `-7.9`。`OFFSET_Y=128*最终scale` 也能补偿单张图的偏移，但最终scale可能受 FIT_TO_CANVAS 改变，所以选择导出输入适配，不修改运行时或让人工猜补偿值。
2. **画布外泄漏确认，未用框架掩盖**：旋转椭圆精确轴对齐包围盒显示，64 档 27 个越界，总范围 `x[-67.749,223.498], y[-86.151,197.032]`（左上原点、Y 向下）；256 档 72 个越界，总范围 `x[-98.512,155.488], y[-76.799,195.196]`。PNG 输出只保留 128×128，Lua 图片不自动被宿主限制，模板关闭遮罩不等于宿主有裁切。

上游 `FIT_TO_CANVAS` 只按标称 128×128 和整屏画布计算缩放，不能约束椭圆实际包围盒；`SKIP_BACKGROUND` 只跳过标记背景，本样本标记背景数量为 0；`OFFSET_X/Y` 只能平移。以上开关均不能裁切。若主代理以后能证明平台**现有**父级矩形遮罩可用，才可另行评估；本轮不造裁切框架，不把它作为首发阻塞工作。

当前 Lua 头部已标注 `DIAGNOSTIC ONLY`，只允许用于隔离副本中的坐标/越界诊断，**不能直接接到正式头像槽位**。两份脚本使用相同位置：

1. 第 21 行 `local IMAGE_PREFAB_ID = 0`：改为真实客户端**图片控件模板索引 ID**。图片设为“仅存为模板”，关闭模板遮罩/羽化；这不会提供宿主裁切。
2. 第 23 行 `IMAGE_ID_BY_KIND` 是静态**图片资源**编号：矩形 `100001`、椭圆 `100002`、三角形 `100003`。本样本只实例化椭圆，不要把这些编号写成模板索引。
3. 第 25 行 `BASE_SCALE=1.0`；位置改 `OFFSET_X/Y`，Y 向上。诊断先保持默认值，不需要再加 128 像素补偿。
4. 挂专用空客户端容器节点，进入预览后 `OnStart` 绘制。上游指南要求专用宿主；本提交实际运行时只设置图片子控件尺寸，没有修改宿主尺寸。`OnDestroy` 清理；重复启动先清理再创建。

原始 JSON 坐标：原图左上为原点、X 右、Y 上；导出适配后的 Lua 数据才是左下原点。最终控件位置与 JSON `relative` 一致；椭圆直径传尺寸、中心轴心 `(0.5,0.5)`，Z 旋转为逆时针。`SetAsLastSibling` 按导出次序层叠。每个图元一次 `InstantiateClientUIControl`，两档新增 64 / 256 控件，未计宿主和模板；不能推断平台容量。

坐标回归可直接运行，不重新拟合：

```powershell
& 'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe' docs/experiments/art-portrait/review_exports.py --vendor 'F:/New folder/tools/vendor/primitive-shape' --fengari 'F:/New folder/.worktrees/ui-design/node_modules/fengari-node-cli/src/lua-cli.js'
```

脚本从已存 JSON 重新导出、计算越界，调用现有 Fengari 模拟 game API。两档未经适配都复现 `y 1` 断言失败；适配后全部 320 个位置与独立 JSON `relative` 对照通过，重复 OnStart 和 OnDestroy 的模拟销毁数量也通过。此验证不提供真实平台渲染或裁切证据。

## 验证边界与下一步

| 层 | 本分支结果 |
|---|---|
| Python 样本与拟合 | 已运行，两个预算结果见 measurements.json |
| JSON / Lua / PNG 导出 | 两档已生成；源图 SHA-256、JSON 图元数量/图片编号和原始 Lua 字节数已核对；修订 Lua 经模拟 API 逐位置与生命周期检查通过；PNG 不能代表未裁切 Lua 的效果 |
| 平台 Lua 编译 | 未做 |
| 写进存档副本 / 导入 | 未做 |
| 真机显示、帧时间与内存 | 未做 |
| 多次进入销毁 / 模板遮罩和层序 | 未做 |
| 手机 / 主机画布 | 未做 |
| 透明背景、矩形与三角形 | 未测，不能外推 |
| 正式岩荧肖像素材与画质 | 未验收 |

**首发建议：优先平台原生角色/肖像；若图库没有荧头像，用角色 3D 加原生岩元素徽章作为明确占位，并记录肖像缺口。** 另一可选路线是手工可控、边界以内的低图元构图，也必须经过视觉批准，不能把本技术头像冒充正式荧。

限时只读核查了本机 MCP 的 `src/scene/image-library/index.json`（其注释记载采集于 2026-10-13），没有角色头像分类；目视核对 `creature_00.jpg` / `creature_01.jpg` 的造物头像，未见荧；`play-colour_00.jpg` 中 `103005` 是原生岩元素徽章。这只能说明已装快照未找到荧头像，不证明当前游戏所有动态头像源不存在，也不证明玩家 3D 外观已设为荧。原生头像/3D角色可用性仍由主代理在当前客户端确认。
