# 两张 AI 美术样本：转换交付与实机待验

2026-10-23，TASK-25.2，`feat/ai-art-samples`，基线 `develop / 1217abb`。本轮只处理用户 ZIP 中的两张图，没有重新生图。**当前已交付可测试资产；官方导入和实机显示尚未通过，不放行首发或批量生产。**

## 交付与结论

| 输入 | 推荐测试文件 | 当前结论 |
|---|---|---|
| 荧／岩系立绘 | [B2 Lua](../../art/processed/ai-samples/lumine/B2/asset.lua)、[可编辑 JSON](../../art/processed/ai-samples/lumine/B2/asset.json)、[离线预览](../../art/processed/ai-samples/lumine/B2/asset.png) | **需要后续精修**。头肩、花饰、发型与双眼比整图拟合清楚，仍有笔触块面、眼部简化、局部接缝；不能称高质量首发立绘已落地 |
| 星陨剑插图 | [完整卡面 Lua](../../art/processed/ai-samples/starfall/B/card.lua)、[卡面 JSON](../../art/processed/ai-samples/starfall/B/card.json)、[离线预览](../../art/processed/ai-samples/starfall/B/card.png) | **仅适合卡牌候选**。缩小后保留琥珀冲击和落点；剑锋与碎岩仍呈圆形块面。需游戏内确认可读性与成本后再决定首发可用 |

超限 GIA 备用：[角色 B](../../art/processed/ai-samples/lumine/B/asset.gia)、[卡图 B](../../art/processed/ai-samples/starfall/B/asset.gia)。GIA 是上游旧 class15 图片素材组；**不是已实测可导入的客户端控件模板**。B2 面部局部裁切只交付 Lua，不能去掉局部蒙版后冒充等价 GIA。完整卡面也用 Lua，保留原生文字与插图区局部蒙版。

所有版本在 `art/processed/ai-samples/`；A 是未裁切对照，B 是裁切简化版，`lumine-face/B` 仅是同一角色原图的面部中间件。`primitive.lua` / `fit.raw.json` 是中间诊断文件；安装使用 `asset.lua` 或 `card.lua`。中间 primitive Lua 没有补上 Go 拟合使用的不透明白底，不能直接拿它的显示替代最终资产。最终导出已补回白底。

本机测试副本在 `build/ai-art/abyss-ai-{baseline,lumine,starfall}.gil`；具体路径、返回模板索引与检查结果在 `build/ai-art/candidates.json`。GIL 和含账号的原始截图保留本机，不推 Git。

## 来源与固定工具

- 原图：[lumine_geo_portrait.png](../../art/source/lumine_geo_portrait.png)，1086×1448、RGB；SHA-256 `5a8287ed5c1d1825b9068534df985cf14067596e37eef530f5d2a6ab1ba26854`。
- 原图：[starfall_sword_art.png](../../art/source/starfall_sword_art.png)，1448×1086、RGB；SHA-256 `2a42eae75955b9c75f0813b9b4f009580026f46758ad04b2718e8266422e5f53`。
- 用户提供已生成图，本轮只裁切、缩小、调色板简化和图元编辑；角色是荧／岩元素。卡牌关联 `data/presentation/traveler.zh-CN.json` 的 `cleave → 星陨剑`，费用与伤害来自 `data/cards.json`，没有改机制。
- Primitive：沿用 [既有固定提交](../experiments/art-portrait/README.md) `0526509e73d36b359d3c9bee1104718e4a600ed0` 的本机核心和 Go 二进制。调用 `fit_image_with_primitive → results_to_elements → build_lua_export_text`；复用已有 Y 坐标适配。
- Image Editor：本机 checkout `103025f9095d8089e3f9bf097f4d0c5fe039d546`，调用与网页相同的 `import_scene / export_json / export_lua / export_gia / export_png` 后端。**没有网页交互或网页预览成功的验收声明**，没有重写转换器。
- 许可证保存在 [licenses](../../art/processed/ai-samples/licenses/)：编辑器 GPL-3.0、Primitive 运行时 MIT。沿用现有项目的来源记录；新增脚本是调用配方，不是复制一套框架。
- Python、MCP、官方客户端路径以 [TOOLCHAIN.md](../TOOLCHAIN.md) 为准。拟合用现有 Python 3.12；导出复用 Image Editor 已有 venv。

## 两条路线与局部精修

### A：整图 PNG → Primitive → Lua / GIA

保持整图比例，最长边缩为192，256个椭圆，`detail_scale=1 / workers=4 / transparent_output=false`。角色输入144×192；卡图192×144。原始结果、参数、预览和最终导出分别保存，不覆盖源图。

角色 A 的脸只剩模糊色块，衣装和岩石争抢预算；**不适合角色**。卡图 A 保留大致斜向剑光，但缩入宽扁插图区会进一步丢失落点。A 不加边界裁切，只作为失败对照；其 PNG 受画布自然裁切，Lua 的越界部分会继续显示，不能用 PNG 证明边界正确。

### B：裁切与简化 → Primitive → Image Editor 编辑 → Lua / GIA

裁切为确定的图像预处理；图元导入、蒙版编辑和格式导出由 Image Editor 后端完成。坐标都是源 PNG 左上角像素，框格式 `[left, top, right, bottom]`。

| 项 | 角色 B | 卡图 B |
|---|---|---|
| 裁切 | `[250,40,880,800]` | `[20,400,1420,1022]` |
| 目的 | 花饰、头发、双眼、肩线；舍去下半身与大部分背景 | 保留剑落点、斜向剑光、碎岩和冲击；舍去上方空场 |
| 缩放 | 252×304，精确等比0.4 | 288×128；放入批准稿144×64插图区时缩放0.5 |
| 简化 | 48色调色板 | 48色调色板 |
| 拟合 | 768椭圆 | 256椭圆 |
| 边界 | 111个越界图元加上游矩形蒙版 | 74个越界图元加上游矩形蒙版 |

保持图元原来的中心、旋转、颜色与层序，蒙版窗口统一落在画布边界，不通过缩小图元“修复”越界。Lua 复用编辑器的透明图片父控件蒙版；GIA 用素材组根蒙版。两者仍需分别实机验证。

角色 B2 进一步将同一原图 `[570,190,790,390]` 缩为88×80，256椭圆拟合面部；主体使用 B 的前512个图元，将面部贴在主体画布 `[128,60]`。图元总预算仍为768，另有两张白底与169个局部蒙版，共939控件。面部中间件记录独立参数与耗时，没有重新生成脸。当前是带背景的矩形半身样本，不是透明抠出的独立人物。

### 观测成本

| 版本 | 图片/文字内容控件 | 额外蒙版 | 运行时资产控件 | 拟合墙钟秒（单次） |
|---|---:|---:|---:|---:|
| 角色 A | 257 | 0 | 257 | 44.55 |
| 角色 B | 769 | 111 | 880 | 133.07 |
| 角色 B2 | 770 | 169 | 939 | 复用 B + 面部37.13 |
| 卡图 A | 257 | 0 | 257 | 53.04 |
| 卡图 B | 257 | 74 | 331 | 34.24 |
| 星陨剑完整卡面 | 269（含4原生文字） | 74 | 343 | 复用卡图 B |

控件数未包含测试界面的底色、标题、按钮、指标和宿主；不能当成整屏总数。拟合秒数是离线工具耗时，**不是游戏加载或运行性能**。上游随机种子来自时钟，重新拟合不保证逐图元相同；已保存原始输出供稳定回放。

## 已验证与尚未验证

已执行：

- 两图各 A/B 的 GIA、Lua、JSON、PNG 输出；B2 Lua 和星陨剑完整卡面。
- [verify-ai-samples.py](../../scripts/art/verify-ai-samples.py) 从 Lua 绘图表还原坐标、尺寸、旋转、蒙版；不靠末尾编辑器快照自证。六个资产版本通过。
- GIA 实际二进制长度、模式、图片记录数和根蒙版由上游独立解析器读回。四个 GIA 均有558个模板历史空引用，集合与固定上游 `image_template.gia` 完全一致；这是继承问题，**没有清空或改写上游转换器**。实际图片记录分别为257/769/257/257；官方接受与否待测。
- 上游 `check_textbox_lua.cjs` 对星陨剑完整卡面通过：269内容控件 + 74蒙版，检查模板缺失、蒙版布局、文字、层序、重复启动和清理。它的输出行写269，额外蒙版在内部另计；不是设备显示测试。
- 基线、角色B2、星陨剑卡面分别写入工作区 GIL 副本，`scene_check_client` 均0错误0警告。保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`。

未通过的真实尝试：

1. `playtest_start` run `7d2d59df-823b-4011-ad4c-69a77c52630f`，导入前报“无法把窗口切到前台：game”。原结果在本机 `build/ai-art/play-baseline.status.json`。
2. 标准 UAC 启动已安装的 `playtest_runner.py` 后，焦点已能取得；游戏仍在上一轮试玩结算页，执行器误判为编辑器，报“菜单里找不到试玩”。保存了 `00-no-level-menu.jpg`；没有导入、没有本次美术显示。
3. 首次启动逐步管理员 MCP 客户端被自动审批拒绝；**用户随后明确回复“允许”**，客户端已按该授权启动。当前游戏进程/窗口与上一轮不同，重新发现后已成功聚焦并发送一次全屏切换。临时脚本位于本机 `build/ai-art/mcp-ui-host.mjs`，不进入仓库产品代码。
4. 新基线 run `5675094a-e147-4087-b48a-c41f8e06c1db` 在导入前报“没能打开千星奇域菜单”，截图是编辑器草地。期间共享桌面记录出现另一个工作树 `combat-feedback` 的试玩 run `49a81efb-1911-404b-922f-35001a793e82`。这不是本次美术显示证据。**用户要求先让另一个会话完成**，本会话停止游戏输入并关闭临时客户端，等待共享窗口交接；此前授权仍保留。

因此：**官方导入未成功；游戏显示、五官/轮廓、卡牌可读性、加载耗时、dt和清理循环均未验收。** 截到旧试玩结算页或草地不算本次资产的实机证据。手机/主机亦未测。Backlog 保持 In Progress，不勾上述验收。当前阻塞是共享GUI交接，已不再是管理员客户端授权。

## 复现与继续实机

在本分支根目录运行，`<primitive>` / `<editor>` 指本机已有固定版本 checkout：

```powershell
# 分别对 lumine / starfall，路线 A / B 执行；不需重新生图
& '<Python312>' scripts/art/process-ai-samples.py fit lumine B --primitive '<primitive>'
& '<editor>/backend/.venv/Scripts/python.exe' scripts/art/process-ai-samples.py export lumine B --editor '<editor>'
# 角色面部精修
& '<Python312>' scripts/art/process-ai-samples.py fit lumine-face B --primitive '<primitive>'
& '<editor>/backend/.venv/Scripts/python.exe' scripts/art/process-ai-samples.py export lumine B2 --editor '<editor>'
# 卡图 B 的导出同时生成现有卡框版本 card.lua / card.json / card.png
& '<editor>/backend/.venv/Scripts/python.exe' scripts/art/verify-ai-samples.py --editor '<editor>'
node scripts/art/prepare-ai-samples.mjs
```

准备脚本读取本机 `build/ai-art/maps.json`（来自 MCP `list_maps`），只从已确认干净测试底图复制；没有这份清单时先列出存档并选择合适底图，不能猜模板编号。它创建图片/文字模板，从返回结果绑定真实索引，挂专用宿主，再检查。已有源资产可直接重放，无需重跑随机拟合。

实机验收顺序：离开当前结算 → 导入 `abyss-ai-baseline.gil` 为新测试存档 → 16秒试玩、取1/3/10/15秒截图、12秒点击；依次测试 `abyss-ai-lumine.gil` 和 `abyss-ai-starfall.gil`。对照同底图基线，记录首张可见、10秒客户端dt均值/p95、异常/提前结算、三次进入退出后的清理。不得覆盖原始存档或发布。卡图检查实际144×64插图区、标题、费用和说明；角色检查双眼、嘴、发型、半身边界与接缝。后续设备验收必须注明编辑器画布预览或真实设备性能，二者分开。

## 批量生产建议（尚未放行）

| 类别 | 后续优先路线 | 放行前条件 |
|---|---|---|
| 角色立绘 | B裁半身 + 面部局部预算；重要轮廓可在Image Editor精修 | 本次939控件仍高，先过画质与性能；整图A不推荐 |
| 卡牌插图 | B按实际插图区裁切，保冲击/符号，编辑器再简化 | 单张343控件不能外推十张；应继续降低图元或复用原生图标，先实测 |
| 事件图 | 优先原生素材组合；需原图时按焦点裁切再走B | 大面积高细节图片先测一张，不能照搬卡图预算 |
| Boss图 | 官方原生造物/肖像优先；静态头像才考虑B局部裁切 | 先验独立头像与战斗同屏成本，不把2D拟合当3D模型 |

这些是依据本次离线结果的候选方向，不是“实机实验通过后的量产流程”。完整参数、文件哈希和控件数见 [verification.json](../../art/processed/ai-samples/verification.json)。
