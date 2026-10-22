# TASK-10.1 · 图元角色肖像最小实验

日期：2026-10-23。分支 `feat/art-portrait-spike`，从 `develop` / `91ae349` 创建。

**结论：可以直接复用上游拟合后端和 Lua 导出器，暂不能决定正式肖像预算，更不能批产。** 本实验只做一个自制几何头像、两档图元数的离线拟合，没有接入现有游戏 UI、导入存档或操作真机。真机结果由主代理独立记录。

## 问题与退出条件

- Question：能否用现有工具把一个项目自制头像转换为基础图片控件，并量化低/高图元预算的离线成本？
- Success criterion：同一源图得到 64 / 256 图元 JSON、PNG、可解析 Lua；记录耗时、文件大小和图像误差；提供可替换的模板索引位置。
- Relationship：与战斗界面和图片编辑器路线正交；这里只提交研究及小样，不修改核心 Lua、主题数据或正式资源。运行路径最终由真机结果决定。
- Disposition：continue，仅保留可评审的小样和研究结论；正式肖像画质、容量与移动端性能未回答，禁止据此批量生产。

## 来源、版本与许可

上游：[1475505/Miliastra-toolbox-primitive-shape](https://github.com/1475505/Miliastra-toolbox-primitive-shape)，固定提交 [`0526509e73d36b359d3c9bee1104718e4a600ed0`](https://github.com/1475505/Miliastra-toolbox-primitive-shape/tree/0526509e73d36b359d3c9bee1104718e4a600ed0)。查询 `releases/latest` 返回 404，故不声称存在正式版本号。已读 [tech.md](https://github.com/1475505/Miliastra-toolbox-primitive-shape/blob/0526509e73d36b359d3c9bee1104718e4a600ed0/tech.md)、[user_guide.md](https://github.com/1475505/Miliastra-toolbox-primitive-shape/blob/0526509e73d36b359d3c9bee1104718e4a600ed0/user_guide.md) 及实际 Python / Go 源码。

主项目 MIT，Copyright 2026 LiuL；第三方 primitive MIT，Copyright 2016 Michael Fogleman。生成 Lua 含上游运行时，因此本目录保留 [Shaper 许可](LICENSE-Shaper.txt) 与 [primitive 许可](LICENSE-primitive.txt)。许可说明不能替代角色素材本身的权利确认。

本实验输入 [source.png](source.png) 由 [reproduce.py](reproduce.py) 用项目自制几何绘制，没有使用上游 demo 或第三方肖像。只用金发、花饰、白蓝服装与主题岩金作为技术识别点；**不是用户批准的正式角色画质，也不改变 PR #19 视觉方向**。原型内没有可复用的独立岩荧肖像，主代理已同意此技术样本。该简单源图会低估真实立绘、表情、发丝与半透明边缘所需预算。

源码与上游二进制仅下载到根目录 `tools/vendor/primitive-shape`，不提交 vendor。网络 clone 未完成后改为下载固定 ref 的必要文件；没有安装新包或修改上游源码。`tools/primitive.exe` 的 Git blob 为 `5bf8b4a6acff6fa46107497befa265a20634a83a`，与上游目录记录一致；SHA-256 在 [measurements.json](measurements.json)。这只证明下载内容一致，不代表本机从源码完成可重复构建。

## 复用路径与本机依赖

实际复用 `primitive_backend.fit_image_with_primitive` → `fill_shaper.results_to_elements` → `lua_export.build_lua_export_text`。这是一个样本脚本调用现有 API，不是新增框架。直接调用核心 API 还能指定两个 worker，避免占满所有 CPU；`shaper_core.process_image_fill` 没有向后端透传 workers。

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

RMSE / PSNR 是源 PNG 与上游生成 PNG 的全图 RGB 像素误差；不是人物识别率、真机画质或 GPU 性能分数。只有一次运行、同一台被共享的机器，不是稳定性能基准。上游使用时钟随机种子且没有 seed CLI 参数，所以复跑不保证同一图元列表或同样秒数。

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

## 给主代理的导入挂点

两份 Lua 使用相同位置：

1. 第 19 行 `local IMAGE_PREFAB_ID = 0`：改为真实客户端**图片控件模板索引 ID**。图片设为“仅存为模板”，关闭模板遮罩/羽化。
2. 第 21 行 `IMAGE_ID_BY_KIND` 是静态**图片资源**编号：矩形 `100001`、椭圆 `100002`、三角形 `100003`。本样本只实例化椭圆，不要把这些编号写成模板索引。
3. 第 23 行 `BASE_SCALE=1.0`。批准稿玩家肖像 132 时可试 `132/128`；位置改 `OFFSET_X/Y`，Y 向上。
4. 挂专用空客户端容器节点，进入预览后 `OnStart` 绘制。上游指南要求专用宿主；本提交实际运行时只设置图片子控件尺寸，没有修改宿主尺寸。`OnDestroy` 清理；重复启动先清理再创建。

坐标：原图左下为原点，X 右、Y 上，椭圆直径传尺寸、中心轴心 `(0.5,0.5)`，Z 旋转为逆时针。`SetAsLastSibling` 按导出次序层叠。每个图元一次 `InstantiateClientUIControl`，两档分别新增 64 / 256 控件，未计宿主和模板。不能据此推断平台控件上限。

## 验证边界与下一步

| 层 | 本分支结果 |
|---|---|
| Python 样本与拟合 | 已运行，两个预算结果见 measurements.json |
| JSON / Lua / PNG 导出 | 两档已生成；源图 SHA-256、JSON 图元数量/图片编号和 Lua 文件字节数核对通过；用现有 Fengari `loadfile` 分别解析通过，仅代表 Lua 5.3 语法 |
| 平台 Lua 编译 | 未做 |
| 写进存档副本 / 导入 | 未做 |
| 真机显示、帧时间与内存 | 未做 |
| 多次进入销毁 / 模板遮罩和层序 | 未做 |
| 手机 / 主机画布 | 未做 |
| 透明背景、矩形与三角形 | 未测，不能外推 |
| 正式岩荧肖像素材与画质 | 未验收 |

主代理优先在副本中导入 64 档，验证模板索引、静态图片、颜色、旋转、尺寸、层序和关闭后销毁；再切 256 档比较载入耗时及手机帧时间。**只有真机给出可接受的画质和控件成本后，才能确定正式图源和预算，再决定是否批产。** 若 256 也无法保持肖像关键五官，先优化图源/手动编辑，不把增加图元数当作既定方案。
