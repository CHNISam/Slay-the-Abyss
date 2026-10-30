# 美术技术实验：首轮可运行探针（未达最终美术验收）

基线 origin/develop a5cb4bb6，独立分支 feat/art-tech-lab。没有修改生产 Lua、战斗规则或 Grok UI。TASK-93 保持进行中。

## 交付

- sample.save.json：beyond-simulator 0.5.2 完整存档。用 Web 编辑器打开即可运行；点击任一卡放大，再点击隐藏。
- sample.png / selected.png / played.png / mobile.png：真实模拟器 Host PNG；手机图只是画布模拟。
- import/：服务器控件模板 GIA 与脚本 GIA。两份均需导入，脚本须重新挂载到 ArtLab。尚未在官方编辑器实际导入，不是可直接开局的完整关卡 GIL。
- build.mjs / interaction.lua / run.mjs / verify.mjs：可复现生成、实际 Lua 运行、截图及检查。
- verification.json / timings.json / export-receipt.json：数据与导出警告，不能忽略警告宣称正式可交付。

## 结果

| 内容 | 既有精细候选 | 最新已有压缩候选 | 本实验 |
|---|---:|---:|---:|
| 打击插画 | 2610 矩形 | 918 矩形 | 1 原生图库图片 |
| 防御插画 | 2577 | 835 | 1 原生图库图片 |
| 痛击插画 | 2556 | 916 | 1 原生图库图片 |
| 原背景 | 13201 | 4500 预算版 / 2379 compact | 换成原创几何布景 |

本样品每张完整卡 16 控件，全场景 103 控件，含三卡、敌人及几何背景。**不同美术内容，不能称为同画质压缩。** 单图片路线节约数量，但图标不能代替精致角色画；山形背景仍明显属于技术探针，不满足用户要求的最终高质量背景。没有取得新旧同源视觉与加载对照，不宣称画质胜出。

本轮 Host 启动约 233ms，首次 PNG 请求约 120ms，重复 PNG 请求约 100ms（以 timings.json 为准）。其中包含 RPC、Lua/快照和软件光栅；素材缓存可能已热，首次截图不等于首次网络加载。不是客户端加载、GPU 渲染时间或 FPS；没有完成 1/5/10 卡平台性能矩阵。

实际迭代：首图发现颜色编码错误，修为 ARGB；随后发现树的前后层序，修为前置子控件在前；点击回调向量形式改为仓库同款数字参数；手机画布增加 0.8 缩放。最终四张截图均无 assetWarnings，日志有 ready/select/play；verify.mjs 检查日志、截图回执和两份 GIA 封装。

## 技术判断与限制

1. 优先推广**官方原生纹理＋共享卡框＋独立动态文字**用于适合图库内容的卡牌、道具、怪物。避免把高分辨率图片先降成低分辨率图元。使用本次实见的 StaticReference 资源 ID，模拟器运行无缺失，但官方视觉仍待验证。
2. 大型自定义角色立绘仍没有找到一张任意 PNG 直接成为原生纹理的可验证链路。不能用图标替代角色后宣称问题解决。当前项目的 compact/budget 已经存在，应作为下一轮同源实验基线，不能当作本次新成果。
3. 检查的 genshin-miliastra-mcp 场景接口依赖官方模板资源 ID、变换和组件；未发现自定义顶点、UV、材质纹理载荷接口。因此**本次没有证实 Blender 自定义模型与贴图能导入**。Blender 出图后图元化仍然是图元路线；用官方物件重建也不等于自定义 mesh 导入。不将客户端模型替换工具 GIMI 混为千星 UGC 可交付工具。
4. Primitive Shape 与 Image Editor 是成熟的几何拟合/编辑/导出工具，但不会自动赋予平台任意位图纹理或任意网格加载能力。尚未完成三角形/旋转图元对同源立绘的预算质量曲线，不能断言这条路线已失败。
5. AI 已完成本轮模拟器运行、截图观察及三次针对缺陷修正；尚未进行浏览器 GPU 帧率或官方实机测试。

## 来源与复现

- 官方图库 ID：100001/2/3、102014/50、104001、107003、111075、112003；图片预览来自模拟器白名单 https://oss.070077.xyz/images/ 。仅为千星内容制作测试，不重新许可官方图片。
- 模拟器 https://github.com/1475505/miliastra-beyond-simulator ，源码核对提交 3dff619528b1ad3689e2f96b6bcbb0c0c0e735f2；执行 npm 发布包 beyond-simulator-mcp 0.5.2。工具 GPL-3.0，不把该许可扩大到官方资源或项目全部内容。
- Primitive Shape https://github.com/1475505/Miliastra-toolbox-primitive-shape ；编辑器 https://github.com/1475505/Miliastra-image-editor-webui 。本轮没有复制其转换器代码。
- 卡牌名称、费用、说明从本工作树 data/cards.json 构建读取；UI 色彩沿用岩金/深蓝方向，未替换正式主题。

在仓库根目录执行以下命令；独立目录安装模拟器，未增加正式项目依赖：

```powershell
npm install --prefix .artifacts/art-lab-runtime beyond-simulator-mcp@0.5.2 --ignore-scripts --no-audit --no-fund
node experiments/art-tech-lab/build.mjs
node experiments/art-tech-lab/run.mjs
node experiments/art-tech-lab/verify.mjs
```

已有安装可设置 ART_LAB_MCP_ENTRY 为该安装的 dist/index.js 绝对路径。只检查已保存证据时可单独运行 verify.mjs，无需安装模拟器。sample.save.json 在模拟器中运行，GIA 是手动导入素材，不是完整关卡。

尚需：独立审查；完整战斗装配；精细同源插画/角色路线；原生导入、挂载、新 ready、官方容量、真实设备。完成这些之前保持未验收，不合并、不作为发布候选。
