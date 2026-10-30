# 美术突破实验（feat/art-breakthrough-experiment）

## 路线
千星 UGC 不能导入自定义贴图，所以用「Teyvat 式多面低多边形」：
- 立绘/插画用 Delaunay 三角剖分，每个面片 = 1 个官方三角图元 100003（尺寸 + rotZ + 单轴 rotX/rotY 压扁成任意三角）。
- 卡框只用官方库精灵（104007/104008 角花、106033/106039 宝石框、106038 名牌、102005 岩元素徽记等）着色拼装。
- 整张卡是一个容器，选中/移动只改容器 Pos/Scale/Rot，不逐面片更新。
- 代码：`art/spikes/art-breakthrough/`（lowpoly.py → card.mjs/scene.mjs → gen-lua.mjs → run-sim.mjs）。

## 证据（`.artifacts/art-breakthrough/`）
| 项 | 文件 | 控件数 |
|---|---|---|
| 精品卡 | card/card-v6.png，compare-card-before-after.png | 框 37 + 插画 1076（手牌 LOD 284） |
| 立绘半身 | hero/bust-v1.png | 2010 三角 |
| 背景 | bg/land-lp.png（land300） | 361 |
| 模拟器真实 Lua 运行 | sim3-*.png，sim3-demo.gif | 场景共 3993 节点 |
| 旧路径对照 | 现卡 spike 15 控件；官方风景 rect 路径 13201 rect / 7.5MB Lua | — |

模拟器：beyond-simulator Lua runtime 构建 3993 节点约 0.4 s；每帧 0.1–1.2 ms（只动 5 个卡容器）；卡选中上抬/缩放/置顶动画正常。

## 包
`pack/sta_art_scene.combined.gia`（服务端控件组 + 客户端模板 IMG/TXT/BOX + Lua，模拟器导出）、`sta_art_scene.lua`、`sim-project.save.json`、`sta_art_scene_pack.zip`。

## 结论
- 更好看：是，明显接近提瓦特卡牌冒险的面片质感；比 13k rect 少一个数量级。
- 更快：构建一次性 ~4k 控件；多卡移动顺滑（容器级动画）。
- 推广：建议推广到几十张卡——每卡插画用 284 面 LOD，检视时再换 1076；立绘按需加载。
- 模拟器 vs 官方客户端差距：单轴 rotX/rotY 压扁在 PC 有观察记录；混合 rotX+rotY（立绘中 190/2010 面）仅为模拟器策略；~4k 控件真机性能、GIA 官方导入、模板索引（IMG/TXT/BOX_PREFAB）均未验证。

## 阻塞
需在官方编辑器导入 combined.gia 并在真机截图验证；若混合旋转不正确，改用 lowpoly.py 只拆分不混合（面数略增）。
