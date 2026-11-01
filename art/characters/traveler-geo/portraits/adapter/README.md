# 荧头像：资产本地原生导出适配

仅维护本目录及调用产生的独立肖像输出。此配方不拟合图片、不重造导出器、不修改大立绘或 UI 实现，也不调用客户端、导入、试玩或发布。先做 **avatar96 一个离线候选**；battle133 只是另一个图像基准，未放行第二个原生 B1 或批量装配。

## 工具与来源

复用现有缓存 `starfall-offline-export/export_candidate.py` 的 `load_upstream()`。适配器先核验该加载器和源文件清单的 SHA256，再由它核验固定编辑器 `1475505/Miliastra-image-editor-webui@103025f9095d8089e3f9bf097f4d0c5fe039d546` 的17个 Git blob 和历史输入。加载后禁止 socket 连接/监听、子进程及系统命令；不安装依赖、不访问网络。

真实调用既有 `import_scene(JSON)`、`export_json`、`export_lua`、`export_png`，不是自制 SVG/PNG/Lua 转换器。保持缓存源和依赖只读；使用缓存 Pillow11.3.0，不使用宿主 Pillow12。缓存加载器 hash 变化会失败，须明确核验新证据后再调整，不自动接受未知版本。

输入是标准 Image Editor scene JSON：`canvas`、`elements`，每个图元有稳定唯一 `id`、`type`、中心坐标 `x/y`、`width/height`、颜色、透明度、旋转和 `zIndex`。本切片只支持二维 rectangle/ellipse/triangle，必须在画布内，无文字、元件图片、Lua 蒙版数据或画布遮罩。不得为得到PNG偷偷删除已有遮罩；不符合此范围时直接失败。

## 单头像导出

在仓库根目录，使用**全新输出目录**（不会覆盖既有证据）：

```sh
CACHE=/workspace/scratch/c1a4970a76e0/starfall-offline-export
ADAPTER=art/characters/traveler-geo/portraits/adapter
python3 "$ADAPTER/export_portrait.py" --cache-root "$CACHE" \
  --kind avatar96 \
  --scene art/characters/traveler-geo/portraits/avatar96/editable.scene.json \
  --source-image art/characters/traveler-geo/portraits/avatar96/source.png \
  --crop 0 0 1254 1254 \
  --output art/characters/traveler-geo/portraits/avatar96 --into-existing-asset-directory
node "$ADAPTER/check_lifecycle.cjs" "$CACHE" \
  art/characters/traveler-geo/portraits/avatar96/native-art.lua \
  art/characters/traveler-geo/portraits/avatar96/native-art.json \
  art/characters/traveler-geo/portraits/avatar96/vm-report.json
```

源图实际1254²时按该真实尺寸登记；若确实采用源图裁切，可加 `--crop left top right bottom`。该参数只验证/记录裁切范围，**不处理图片，也不证明重绘与源像素相等**。全图来源应明确记录 `[0,0,1254,1254]`，不能编造历史裁切。

输出包含真实 canonical JSON/Lua/PNG、脱离编辑器快照解析的 `literal-drawing.json`、逐文件字节与 SHA256、许可原文及来源。连续导出两次必须逐字相等；真实 Lua 行逐项与 JSON 顺序、几何、颜色、透明度比较，考虑固定上游4位小数及float32编码。不把末尾编码快照作为唯一自证。

`--into-existing-asset-directory`允许输出到已有资产目录，但仅新建固定生成文件，任一目标已存在便失败，不覆盖来源、提示词、资产清单或历史证据。以后复跑使用新目录。`preview-native-4x.png`只是canonical 1x PNG的最近邻放大，不是4倍原生分辨率或设备截图。

保留完整 `native-art.lua` 和可编辑 JSON；另存 `runtime-no-snapshot.lua`，仅去掉末尾编辑器注释，代码/数据前缀逐字不变、实际绘图表相等。报告原始Lua字节差；不据此宣称GIL或上传减少同样字节，更不据此批准20MB预算。

模板索引保持 `IMAGE_PREFAB_ID=0`，故不能直接运行原生图。VM仅在内存注入1234；不把它写入资产或当成真实模板。原生适配必须从该副本的 `scene_add_client_template` 返回结果取得索引，并挂专用空子容器，因为既有 Lua 会重设宿主尺寸、位置、锚点和缩放。

## 验证与边界

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s art/characters/traveler-geo/portraits/adapter -p test_adapter.py -v
node --check art/characters/traveler-geo/portraits/adapter/check_lifecycle.cjs
```

测试的三图形夹具只是适配器技术测试，不是正式荧图像。VM复用固定上游 checker 的精确 `vm()` helper；不改 checker、不加假文字。检查真实图片属性、缺模板失败关闭、缺宿主、3轮×3次重启、重复销毁、实例返回nil和图片setter失败的清理/恢复。当前无蒙版原运行时直接销毁子控件；不套用旧B2的宿主级联假设。未验证同步重入；无蒙版上游运行时没有重入锁。实际模板默认显隐/激活、手机与PC显示、真实资源回收和性能均未验证。

几何合同：avatar96为 `[0,96]²`、居中坐标 `[-48,48]²`；battle133为 `[0,133]²`、居中坐标 `[-66.5,66.5]²`。当前战斗板标称133.333²，但已有图片槽只117.333²；133资产接该槽需缩放0.8822055137844612。96只是美术规范目标，尚无接入槽。不得为接线抢改其他执行者的 UI。

**离线导出与VM通过不等于平台 B1。** 真实干净 BaseGIL 和完整 SDK/官方编译环境未提供，官方编译/写入/导入/显示以及平台 B0/B1 增量均 `not_run`。1880字节JSON测试夹具不是真实GIL。内容图元、额外蒙版、一个专用宿主、一个模板定义分别记录；图形数、Lua/JSON/PNG字节不是上传量，也不是20MB安全保证。未测出真实平台增量前不批量装配全部角色。任何桌面输入另须本轮明确窗口。

导出器GPL-3.0和所含 primitive runtime MIT 许可按原字节复制到每个输出；上游源码与准确Git blob记录在报告。角色图像来源和商业权利另由资产主清单登记，不以工具许可代替角色权利。
